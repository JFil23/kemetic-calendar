#!/usr/bin/env python3
"""Fail-closed verification for exact Cloudflare Pages release artifacts.

This verifier never uploads, rebuilds, retries, promotes, or rolls back. It
classifies every declared payload entry using one versioned contract, verifies
every retrievable response body, and treats Pages controls separately.
"""

from __future__ import annotations

import argparse
import dataclasses
import hashlib
import http.server
import json
import re
import threading
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any, Callable, Mapping, Sequence

import web_release_pipeline as release


CONTRACT_PATH = "config/web/cloudflare-served-contract.v1.json"
VERIFICATION_AUTHORITY_PATHS = (
    "config/web/cloudflare-served-contract.v1.json",
    "scripts/deploy_cloudflare_pages.sh",
    "scripts/served_artifact_verifier.py",
)


class ServedVerificationError(RuntimeError):
    """Raised when a served deployment diverges from the sealed payload."""


@dataclasses.dataclass(frozen=True)
class HttpResult:
    status: int
    headers: Mapping[str, str]
    body: bytes
    url: str


Fetcher = Callable[[str], HttpResult]


class _NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def fetch_once(url: str) -> HttpResult:
    request = urllib.request.Request(
        url,
        headers={
            "Accept": "*/*",
            "Cache-Control": "no-cache",
            "User-Agent": "kemet-served-artifact-verifier/1",
        },
    )
    opener = urllib.request.build_opener(_NoRedirect())
    try:
        with opener.open(request, timeout=30) as response:
            return HttpResult(
                status=int(response.status),
                headers={key.lower(): value for key, value in response.headers.items()},
                body=response.read(),
                url=response.geturl(),
            )
    except urllib.error.HTTPError as error:
        return HttpResult(
            status=int(error.code),
            headers={key.lower(): value for key, value in error.headers.items()},
            body=error.read(),
            url=error.geturl(),
        )


def exact_origin(value: str, *, allow_local_http: bool = False) -> str:
    parsed = urllib.parse.urlparse(value)
    allowed_scheme = parsed.scheme == "https" or (
        allow_local_http
        and parsed.scheme == "http"
        and parsed.hostname in {"127.0.0.1", "localhost"}
    )
    if (
        not allowed_scheme
        or not parsed.netloc
        or parsed.path not in ("", "/")
        or parsed.params
        or parsed.query
        or parsed.fragment
    ):
        raise ServedVerificationError(f"Expected an exact permitted origin: {value!r}")
    return f"{parsed.scheme}://{parsed.netloc}"


def load_contract(path: Path) -> dict[str, Any]:
    value = release.load_json(path)
    if not isinstance(value, Mapping):
        raise ServedVerificationError("Served contract must be a JSON object.")
    release.require_exact_keys(
        value,
        (
            "schema_version",
            "pages_controls",
            "pages_control_sha256",
            "redirect_only",
        ),
        label="served contract",
    )
    if value["schema_version"] != 1:
        raise ServedVerificationError("Served contract schema version is unsupported.")
    controls = value["pages_controls"]
    control_hashes = value["pages_control_sha256"]
    redirects = value["redirect_only"]
    if (
        not isinstance(controls, list)
        or not controls
        or len(controls) != len(set(controls))
        or not all(isinstance(item, str) for item in controls)
    ):
        raise ServedVerificationError("Pages-control classification is invalid.")
    if (
        not isinstance(control_hashes, Mapping)
        or set(control_hashes) != set(controls)
        or not all(
            isinstance(digest, str)
            and re.fullmatch(r"[0-9a-f]{64}", digest)
            for digest in control_hashes.values()
        )
    ):
        raise ServedVerificationError("Pages-control hash authority is invalid.")
    if not isinstance(redirects, list) or not redirects:
        raise ServedVerificationError("Redirect-only classification is invalid.")
    seen_manifest_paths: set[str] = set()
    seen_request_paths: set[str] = set()
    for item in redirects:
        if not isinstance(item, Mapping):
            raise ServedVerificationError("Redirect contract entry must be an object.")
        release.require_exact_keys(
            item,
            (
                "manifest_path",
                "request_path",
                "status",
                "destination",
                "canonical_body_path",
            ),
            label="redirect contract entry",
        )
        manifest_path = item["manifest_path"]
        request_path = item["request_path"]
        if (
            not isinstance(manifest_path, str)
            or not manifest_path.startswith("web/")
            or not isinstance(request_path, str)
            or not request_path.startswith("/")
            or request_path in seen_request_paths
            or manifest_path in seen_manifest_paths
            or item["status"] != 308
            or item["destination"] != item["canonical_body_path"]
            or not str(item["destination"]).startswith("/")
        ):
            raise ServedVerificationError("Redirect contract entry is invalid.")
        seen_manifest_paths.add(manifest_path)
        seen_request_paths.add(request_path)
    if set(controls) & seen_manifest_paths:
        raise ServedVerificationError("Pages controls overlap redirect entries.")
    return dict(value)


def validate_pages_controls(
    *,
    release_dir: Path,
    manifest: Mapping[str, str],
    contract: Mapping[str, Any],
) -> dict[str, Any]:
    expected_hashes = contract["pages_control_sha256"]
    for path, expected in expected_hashes.items():
        if manifest.get(path) != expected:
            raise ServedVerificationError(
                f"Pages-control hash drifted for {path}: "
                f"expected={expected} actual={manifest.get(path)}"
            )

    redirects_path = release_dir / "web/_redirects"
    try:
        lines = redirects_path.read_text(encoding="utf-8").splitlines()
    except (FileNotFoundError, UnicodeDecodeError) as error:
        raise ServedVerificationError(
            f"Pages _redirects control cannot be parsed: {error}"
        ) from error
    rules = []
    seen_sources: set[str] = set()
    for line_number, raw_line in enumerate(lines, start=1):
        stripped = raw_line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        parts = stripped.split()
        if len(parts) != 3:
            raise ServedVerificationError(
                f"Invalid _redirects rule at line {line_number}: {raw_line!r}"
            )
        source, destination, status = parts
        destination_url = urllib.parse.urlparse(destination)
        if (
            not source.startswith("/")
            or source.startswith("//")
            or source in seen_sources
            or not destination.startswith("/")
            or destination.startswith("//")
            or destination_url.scheme
            or destination_url.netloc
            or destination_url.query
            or destination_url.fragment
            or status != "200"
        ):
            raise ServedVerificationError(
                f"Unsafe or unsupported _redirects rule at line {line_number}: "
                f"{raw_line!r}"
            )
        seen_sources.add(source)
        rules.append(
            {
                "line": line_number,
                "source": source,
                "destination": destination,
                "status": 200,
            }
        )
    if not rules:
        raise ServedVerificationError("Pages _redirects control has no rules.")
    return {
        "hashes": dict(sorted(expected_hashes.items())),
        "redirect_rewrite_rules": rules,
    }


def expected_alias_origin(*, project: str, branch: str) -> str:
    if not re.fullmatch(r"[a-z0-9][a-z0-9-]*", project):
        raise ServedVerificationError("Cloudflare project name is invalid.")
    if not re.fullmatch(r"[a-z0-9][a-z0-9-]*", branch):
        raise ServedVerificationError("Cloudflare preview branch is invalid.")
    if branch == "production":
        return f"https://{project}.pages.dev"
    return f"https://{branch}.{project}.pages.dev"


def validate_deployment_target(
    *,
    receipt: Mapping[str, Any],
    project: str,
    branch: str,
    alias_url: str | None = None,
) -> str:
    expected = expected_alias_origin(project=project, branch=branch)
    receipt_origin = exact_origin(str(receipt["site_origin"]))
    if receipt["environment"] == "staging" and branch == "production":
        raise ServedVerificationError(
            "A staging artifact cannot target a production Pages branch."
        )
    if receipt["environment"] == "production" and branch != "production":
        raise ServedVerificationError(
            "A production artifact cannot target a preview Pages branch."
        )
    if receipt_origin != expected:
        raise ServedVerificationError(
            "Cloudflare target does not match the sealed artifact origin: "
            f"receipt={receipt_origin} target={expected}"
        )
    if alias_url is not None and exact_origin(alias_url) != expected:
        raise ServedVerificationError(
            f"Supplied stable alias does not match the declared target: {alias_url}"
        )
    return expected


def validate_immutable_project_origin(
    *,
    immutable_url: str,
    project: str,
    alias_url: str,
) -> str:
    immutable_origin = exact_origin(immutable_url)
    alias_origin = exact_origin(alias_url)
    expected_origin_pattern = re.compile(
        rf"^https://[0-9a-f]{{8}}\.{re.escape(project)}\.pages\.dev$"
    )
    if (
        not expected_origin_pattern.fullmatch(immutable_origin)
        or immutable_origin == alias_origin
    ):
        raise ServedVerificationError(
            "Immutable deployment origin must use Cloudflare's exact "
            "8-lowercase-hex deployment host for the declared project: "
            f"{immutable_origin}"
        )
    return immutable_origin


def verification_authority() -> dict[str, str]:
    root = Path(__file__).resolve().parents[1]
    return {
        path: release.sha256_file(root / path)
        for path in VERIFICATION_AUTHORITY_PATHS
    }


def request_path_for_manifest_path(manifest_path: str) -> str:
    if not manifest_path.startswith("web/"):
        raise ServedVerificationError(
            f"Payload path is outside the web root: {manifest_path}"
        )
    relative = manifest_path.removeprefix("web/")
    if not relative:
        raise ServedVerificationError("Payload contains an empty web path.")
    return "/" + urllib.parse.quote(relative, safe="/._-~")


def classify_manifest(
    manifest: Mapping[str, str],
    contract: Mapping[str, Any],
) -> dict[str, Any]:
    controls = set(contract["pages_controls"])
    redirects_by_manifest = {
        item["manifest_path"]: item for item in contract["redirect_only"]
    }
    missing_contract_paths = sorted(
        (controls | set(redirects_by_manifest)) - set(manifest)
    )
    if missing_contract_paths:
        raise ServedVerificationError(
            f"Contract paths are absent from the payload: {missing_contract_paths}"
        )
    body_paths = sorted(set(manifest) - controls - set(redirects_by_manifest))
    classified = controls | set(redirects_by_manifest) | set(body_paths)
    if classified != set(manifest):
        raise ServedVerificationError("Payload contains unaccounted entries.")
    return {
        "pages_controls": sorted(controls),
        "redirect_only": [
            dict(redirects_by_manifest[path])
            for path in sorted(redirects_by_manifest)
        ],
        "body_paths": body_paths,
        "unaccounted": [],
    }


def _require_body(
    *,
    origin: str,
    request_path: str,
    expected_sha256: str,
    fetcher: Fetcher,
    cache: dict[str, HttpResult],
) -> dict[str, Any]:
    url = origin + request_path
    response = cache.setdefault(url, fetcher(url))
    if response.status != 200:
        raise ServedVerificationError(
            f"Expected body status 200 for {url}; received {response.status}."
        )
    actual = hashlib.sha256(response.body).hexdigest()
    if actual != expected_sha256:
        raise ServedVerificationError(
            f"Served body hash mismatch for {url}: "
            f"expected={expected_sha256} actual={actual}"
        )
    return {
        "request_path": request_path,
        "status": response.status,
        "sha256": actual,
        "bytes": len(response.body),
    }


def _require_redirect(
    *,
    origin: str,
    rule: Mapping[str, Any],
    expected_sha256: str,
    fetcher: Fetcher,
    cache: dict[str, HttpResult],
) -> dict[str, Any]:
    request_url = origin + rule["request_path"]
    response = cache.setdefault(request_url, fetcher(request_url))
    if response.status != rule["status"]:
        raise ServedVerificationError(
            f"Redirect status mismatch for {request_url}: "
            f"expected={rule['status']} actual={response.status}"
        )
    location = response.headers.get("location")
    if not location:
        raise ServedVerificationError(f"Redirect lacks Location: {request_url}")
    resolved = urllib.parse.urljoin(origin + "/", location)
    parsed = urllib.parse.urlparse(resolved)
    resolved_origin = f"{parsed.scheme}://{parsed.netloc}"
    if resolved_origin != origin:
        raise ServedVerificationError(
            f"Redirect escapes the expected origin: {request_url} -> {resolved}"
        )
    if (
        parsed.path != rule["destination"]
        or parsed.params
        or parsed.query
        or parsed.fragment
    ):
        raise ServedVerificationError(
            f"Redirect destination mismatch for {request_url}: {location!r}"
        )
    canonical = _require_body(
        origin=origin,
        request_path=rule["canonical_body_path"],
        expected_sha256=expected_sha256,
        fetcher=fetcher,
        cache=cache,
    )
    return {
        "request_path": rule["request_path"],
        "status": response.status,
        "destination": rule["destination"],
        "canonical_body": canonical,
    }


def _decoded_json_body(
    *,
    origin: str,
    path: str,
    cache: Mapping[str, HttpResult],
) -> Mapping[str, Any]:
    response = cache.get(origin + path)
    if response is None:
        raise ServedVerificationError(f"Identity body was not verified: {path}")
    try:
        value = json.loads(response.body.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise ServedVerificationError(f"Invalid served JSON at {path}: {error}") from error
    if not isinstance(value, Mapping):
        raise ServedVerificationError(f"Served identity at {path} is not an object.")
    return value


def verify_served_origin(
    *,
    origin: str,
    manifest: Mapping[str, str],
    contract: Mapping[str, Any],
    receipt: Mapping[str, Any],
    fetcher: Fetcher = fetch_once,
    allow_local_http: bool = False,
) -> dict[str, Any]:
    origin = exact_origin(origin, allow_local_http=allow_local_http)
    classification = classify_manifest(manifest, contract)
    redirect_manifest_paths = {
        item["manifest_path"] for item in contract["redirect_only"]
    }
    cache: dict[str, HttpResult] = {}
    body_results = []
    for manifest_path in classification["body_paths"]:
        body_results.append(
            _require_body(
                origin=origin,
                request_path=request_path_for_manifest_path(manifest_path),
                expected_sha256=manifest[manifest_path],
                fetcher=fetcher,
                cache=cache,
            )
        )
    redirect_results = []
    for rule in contract["redirect_only"]:
        manifest_path = rule["manifest_path"]
        if manifest_path not in redirect_manifest_paths:
            raise ServedVerificationError("Redirect classification drifted.")
        redirect_results.append(
            _require_redirect(
                origin=origin,
                rule=rule,
                expected_sha256=manifest[manifest_path],
                fetcher=fetcher,
                cache=cache,
            )
        )

    version = _decoded_json_body(origin=origin, path="/version.json", cache=cache)
    runtime = _decoded_json_body(origin=origin, path="/env.json", cache=cache)
    if version.get("build_id") != receipt["build_id"]:
        raise ServedVerificationError("Served build identity is wrong.")
    if version.get("environment") != receipt["environment"]:
        raise ServedVerificationError("Served environment identity is wrong.")
    if runtime.get("APP_SITE_URL") != receipt["site_origin"]:
        raise ServedVerificationError("Served site-origin identity is wrong.")
    if version.get("inputs", {}).get("config_sha256") != receipt["inputs"][
        "config_sha256"
    ]:
        raise ServedVerificationError("Served configuration identity is wrong.")
    if version.get("inputs", {}).get("icon_set_sha256") != receipt["inputs"][
        "icon_set_sha256"
    ]:
        raise ServedVerificationError("Served icon identity is wrong.")

    return {
        "origin": origin,
        "build_id": receipt["build_id"],
        "environment": receipt["environment"],
        "classification": classification,
        "body_results": body_results,
        "redirect_results": redirect_results,
        "verified_retrievable_entries": (
            len(classification["body_paths"])
            + len(classification["redirect_only"])
        ),
        "pages_controls": classification["pages_controls"],
        "unaccounted_entries": [],
    }


def verify_deployment(
    *,
    release_dir: Path,
    expected_archive_sha256: str,
    immutable_url: str,
    alias_url: str,
    project: str,
    branch: str,
    wrangler_version: str,
    upload_result_path: Path,
    contract_path: Path,
    fetcher: Fetcher = fetch_once,
) -> dict[str, Any]:
    if not re.fullmatch(r"\d+\.\d+\.\d+", wrangler_version):
        raise ServedVerificationError("Wrangler version must be exact.")
    immutable_origin = validate_immutable_project_origin(
        immutable_url=immutable_url,
        project=project,
        alias_url=alias_url,
    )
    alias_origin = exact_origin(alias_url)
    if immutable_origin == alias_origin:
        raise ServedVerificationError("Immutable and alias origins must be distinct.")
    if not upload_result_path.is_file():
        raise ServedVerificationError("Wrangler upload result is missing.")

    receipt = release.verify_release(
        release_dir,
        expected_archive_sha256=expected_archive_sha256,
    )
    expected_alias = validate_deployment_target(
        receipt=receipt,
        project=project,
        branch=branch,
        alias_url=alias_origin,
    )
    if immutable_origin == expected_alias:
        raise ServedVerificationError("Immutable and alias origins must be distinct.")
    payload = receipt["payload"]
    manifest = release.parse_manifest(release_dir / payload["manifest_file"])
    contract = load_contract(contract_path)
    control_validation = validate_pages_controls(
        release_dir=release_dir,
        manifest=manifest,
        contract=contract,
    )
    immutable = verify_served_origin(
        origin=immutable_origin,
        manifest=manifest,
        contract=contract,
        receipt=receipt,
        fetcher=fetcher,
    )
    alias = verify_served_origin(
        origin=alias_origin,
        manifest=manifest,
        contract=contract,
        receipt=receipt,
        fetcher=fetcher,
    )
    return {
        "schema_version": 1,
        "archive_sha256": payload["archive_sha256"],
        "payload_manifest_sha256": payload["manifest_sha256"],
        "source": receipt["source"],
        "environment": receipt["environment"],
        "build_id": receipt["build_id"],
        "config_sha256": receipt["inputs"]["config_sha256"],
        "icon_set_sha256": receipt["inputs"]["icon_set_sha256"],
        "verification_authority": verification_authority(),
        "pages_control_validation": control_validation,
        "cloudflare": {
            "project": project,
            "preview_branch": branch,
            "immutable_url": immutable_origin,
            "stable_alias": alias_origin,
            "wrangler_version": wrangler_version,
            "upload_result_sha256": release.sha256_file(upload_result_path),
        },
        "immutable_verification": immutable,
        "alias_verification": alias,
        "automatic_actions_after_mismatch": [],
    }


class _LocalPagesHandler(http.server.BaseHTTPRequestHandler):
    server_version = "KemetLocalPages/1"

    def do_GET(self) -> None:
        request_path = urllib.parse.urlparse(self.path).path
        redirect = self.server.redirects.get(request_path)
        if redirect is not None:
            self.send_response(redirect["status"])
            self.send_header("Location", redirect["destination"])
            self.send_header("Content-Length", "0")
            self.end_headers()
            return
        manifest_path = self.server.bodies.get(request_path)
        if manifest_path is None:
            self.send_response(404)
            self.send_header("Content-Length", "0")
            self.end_headers()
            return
        body = (self.server.web_root / manifest_path.removeprefix("web/")).read_bytes()
        self.send_response(200)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format: str, *args: object) -> None:
        return


def verify_local_release(
    *,
    release_dir: Path,
    contract_path: Path,
) -> dict[str, Any]:
    receipt = release.verify_release(release_dir)
    manifest = release.parse_manifest(
        release_dir / receipt["payload"]["manifest_file"]
    )
    contract = load_contract(contract_path)
    validate_pages_controls(
        release_dir=release_dir,
        manifest=manifest,
        contract=contract,
    )
    classification = classify_manifest(manifest, contract)
    bodies = {
        request_path_for_manifest_path(path): path
        for path in classification["body_paths"]
    }
    redirects = {
        item["request_path"]: item for item in contract["redirect_only"]
    }
    for item in contract["redirect_only"]:
        bodies[item["canonical_body_path"]] = item["manifest_path"]

    server = http.server.ThreadingHTTPServer(
        ("127.0.0.1", 0),
        _LocalPagesHandler,
    )
    server.web_root = release_dir / "web"
    server.bodies = bodies
    server.redirects = redirects
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        origin = f"http://127.0.0.1:{server.server_port}"
        return verify_served_origin(
            origin=origin,
            manifest=manifest,
            contract=contract,
            receipt=receipt,
            allow_local_http=True,
        )
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=5)


def preflight_deployment_target(
    *,
    release_dir: Path,
    expected_archive_sha256: str,
    project: str,
    branch: str,
    contract_path: Path,
) -> dict[str, Any]:
    receipt = release.verify_release(
        release_dir,
        expected_archive_sha256=expected_archive_sha256,
    )
    manifest = release.parse_manifest(
        release_dir / receipt["payload"]["manifest_file"]
    )
    contract = load_contract(contract_path)
    controls = validate_pages_controls(
        release_dir=release_dir,
        manifest=manifest,
        contract=contract,
    )
    alias = validate_deployment_target(
        receipt=receipt,
        project=project,
        branch=branch,
    )
    return {
        "schema_version": 1,
        "archive_sha256": receipt["payload"]["archive_sha256"],
        "payload_manifest_sha256": receipt["payload"]["manifest_sha256"],
        "environment": receipt["environment"],
        "build_id": receipt["build_id"],
        "source": receipt["source"],
        "config_sha256": receipt["inputs"]["config_sha256"],
        "icon_set_sha256": receipt["inputs"]["icon_set_sha256"],
        "project": project,
        "branch": branch,
        "expected_alias": alias,
        "pages_control_validation": controls,
        "verification_authority": verification_authority(),
    }


def record_upload_attempt(
    *,
    release_dir: Path,
    expected_archive_sha256: str,
    project: str,
    branch: str,
    wrangler_version: str,
    upload_result_path: Path,
    upload_status: int,
    contract_path: Path,
) -> dict[str, Any]:
    if not re.fullmatch(r"\d+\.\d+\.\d+", wrangler_version):
        raise ServedVerificationError("Wrangler version must be exact.")
    if upload_status < 0 or upload_status > 255:
        raise ServedVerificationError("Wrangler exit status is invalid.")
    if not upload_result_path.is_file():
        raise ServedVerificationError("Wrangler upload result is missing.")
    preflight = preflight_deployment_target(
        release_dir=release_dir,
        expected_archive_sha256=expected_archive_sha256,
        project=project,
        branch=branch,
        contract_path=contract_path,
    )
    return {
        "schema_version": 1,
        "preflight": preflight,
        "wrangler_version": wrangler_version,
        "upload_exit_status": upload_status,
        "upload_result_sha256": release.sha256_file(upload_result_path),
        "upload_result_bytes": upload_result_path.stat().st_size,
        "automatic_retry_or_recovery": [],
    }


def extract_immutable_origin(
    *,
    upload_result: str,
    project: str,
    alias_origin: str,
) -> str:
    pattern = re.compile(
        rf"(?<![A-Za-z0-9.-])"
        rf"https://[0-9a-f]{{8}}\.{re.escape(project)}\.pages\.dev"
        rf"(?![A-Za-z0-9.:-])"
    )
    matches = {
        exact_origin(match)
        for match in pattern.findall(upload_result)
        if exact_origin(match) != exact_origin(alias_origin)
    }
    if len(matches) != 1:
        raise ServedVerificationError(
            "Wrangler output must identify exactly one immutable deployment URL; "
            f"found={sorted(matches)}"
        )
    return matches.pop()


def command_verify(arguments: argparse.Namespace) -> None:
    result = verify_deployment(
        release_dir=arguments.release_dir,
        expected_archive_sha256=arguments.expected_archive_sha256,
        immutable_url=arguments.immutable_url,
        alias_url=arguments.alias_url,
        project=arguments.project,
        branch=arguments.branch,
        wrangler_version=arguments.wrangler_version,
        upload_result_path=arguments.upload_result,
        contract_path=arguments.contract,
    )
    release.write_once_or_identical(
        arguments.receipt,
        release.canonical_json_bytes(result),
    )
    print(f"verified_immutable_url={result['cloudflare']['immutable_url']}")
    print(f"verified_alias_url={result['cloudflare']['stable_alias']}")
    print(f"served_receipt={arguments.receipt}")


def command_extract_immutable(arguments: argparse.Namespace) -> None:
    print(
        extract_immutable_origin(
            upload_result=arguments.upload_result.read_text(encoding="utf-8"),
            project=arguments.project,
            alias_origin=arguments.alias_url,
        )
    )


def command_verify_local(arguments: argparse.Namespace) -> None:
    result = verify_local_release(
        release_dir=arguments.release_dir,
        contract_path=arguments.contract,
    )
    content = release.canonical_json_bytes(result)
    if arguments.receipt:
        release.write_once_or_identical(arguments.receipt, content)
    print(content.decode("utf-8"), end="")


def command_preflight_target(arguments: argparse.Namespace) -> None:
    result = preflight_deployment_target(
        release_dir=arguments.release_dir,
        expected_archive_sha256=arguments.expected_archive_sha256,
        project=arguments.project,
        branch=arguments.branch,
        contract_path=arguments.contract,
    )
    print(release.canonical_json_bytes(result).decode("utf-8"), end="")


def command_record_upload_attempt(arguments: argparse.Namespace) -> None:
    result = record_upload_attempt(
        release_dir=arguments.release_dir,
        expected_archive_sha256=arguments.expected_archive_sha256,
        project=arguments.project,
        branch=arguments.branch,
        wrangler_version=arguments.wrangler_version,
        upload_result_path=arguments.upload_result,
        upload_status=arguments.upload_status,
        contract_path=arguments.contract,
    )
    release.write_once_or_identical(
        arguments.receipt,
        release.canonical_json_bytes(result),
    )
    print(f"upload_attempt_receipt={arguments.receipt}")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)
    verify = subparsers.add_parser("verify")
    verify.add_argument("--release-dir", type=Path, required=True)
    verify.add_argument("--expected-archive-sha256", required=True)
    verify.add_argument("--immutable-url", required=True)
    verify.add_argument("--alias-url", required=True)
    verify.add_argument("--project", required=True)
    verify.add_argument("--branch", required=True)
    verify.add_argument("--wrangler-version", required=True)
    verify.add_argument("--upload-result", type=Path, required=True)
    verify.add_argument("--receipt", type=Path, required=True)
    verify.add_argument(
        "--contract",
        type=Path,
        default=Path(__file__).resolve().parents[1] / CONTRACT_PATH,
    )
    verify.set_defaults(handler=command_verify)

    extract = subparsers.add_parser("extract-immutable-url")
    extract.add_argument("--upload-result", type=Path, required=True)
    extract.add_argument("--project", required=True)
    extract.add_argument("--alias-url", required=True)
    extract.set_defaults(handler=command_extract_immutable)

    local = subparsers.add_parser("verify-local")
    local.add_argument("--release-dir", type=Path, required=True)
    local.add_argument("--receipt", type=Path)
    local.add_argument(
        "--contract",
        type=Path,
        default=Path(__file__).resolve().parents[1] / CONTRACT_PATH,
    )
    local.set_defaults(handler=command_verify_local)

    preflight = subparsers.add_parser("preflight-target")
    preflight.add_argument("--release-dir", type=Path, required=True)
    preflight.add_argument("--expected-archive-sha256", required=True)
    preflight.add_argument("--project", required=True)
    preflight.add_argument("--branch", required=True)
    preflight.add_argument(
        "--contract",
        type=Path,
        default=Path(__file__).resolve().parents[1] / CONTRACT_PATH,
    )
    preflight.set_defaults(handler=command_preflight_target)

    attempt = subparsers.add_parser("record-upload-attempt")
    attempt.add_argument("--release-dir", type=Path, required=True)
    attempt.add_argument("--expected-archive-sha256", required=True)
    attempt.add_argument("--project", required=True)
    attempt.add_argument("--branch", required=True)
    attempt.add_argument("--wrangler-version", required=True)
    attempt.add_argument("--upload-result", type=Path, required=True)
    attempt.add_argument("--upload-status", type=int, required=True)
    attempt.add_argument("--receipt", type=Path, required=True)
    attempt.add_argument(
        "--contract",
        type=Path,
        default=Path(__file__).resolve().parents[1] / CONTRACT_PATH,
    )
    attempt.set_defaults(handler=command_record_upload_attempt)
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    parser = build_parser()
    arguments = parser.parse_args(argv)
    try:
        arguments.handler(arguments)
    except (
        ServedVerificationError,
        release.ReleaseInputError,
        OSError,
    ) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
