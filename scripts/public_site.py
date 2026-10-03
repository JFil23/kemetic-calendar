#!/usr/bin/env python3
"""Validate, seal and verify the isolated Hꜣw public site; never deploy it."""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
import tempfile
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from html.parser import HTMLParser
from pathlib import Path
from typing import Callable, Mapping

ORIGIN = "https://haw-info.pages.dev"
PROJECT = "haw-info"
ROUTES = {"/": "index.html", "/privacy": "privacy.html", "/terms": "terms.html",
          "/support": "support.html", "/delete-account": "delete-account.html",
          "/404": "404.html"}
ALIASES = {"/about": "/", "/about/": "/", "/about.html": "/",
           "/account-deletion": "/delete-account", "/account-deletion/": "/delete-account"}
FILES = frozenset((*ROUTES.values(), "_headers", "_redirects"))
SCRIPT = "scripts/public_site.py"
MAX_BODY = 1_000_000


class PublicSiteError(RuntimeError):
    pass


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def canonical_json(value: object) -> bytes:
    return (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise PublicSiteError(message)


def safe_css(value: str) -> None:
    compact = re.sub(r"/\*.*?\*/", "", value, flags=re.S).lower()
    require(not re.search(r"url\s*\(|@import|expression\s*\(|behavior\s*:|-moz-binding|\\", compact),
            "Only inline CSS without resource loads or executable behavior is allowed.")


class StaticHTML(HTMLParser):
    TAGS = frozenset("html head meta title style body main nav footer header section article "
                     "h1 h2 h3 h4 p a ul ol li strong em b i span div br hr blockquote "
                     "code pre small time dl dt dd table thead tbody tr th td".split())

    def __init__(self, text: str):
        super().__init__(convert_charrefs=True)
        self.ids: set[str] = set()
        self.links: list[str] = []
        self.counts: dict[str, int] = {}
        self.in_style = False
        self.doctype = False
        self.feed(text)
        self.close()
        require(self.doctype and all(self.counts.get(tag) == 1 for tag in ("html", "head", "title", "body")),
                "Each page requires one HTML document, title, head and body.")

    def handle_decl(self, decl: str) -> None:
        require(decl.lower() == "doctype html", "Only an HTML doctype is allowed.")
        self.doctype = True

    def handle_pi(self, data: str) -> None:
        raise PublicSiteError("Processing instructions are forbidden.")

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        require(tag in self.TAGS, f"Non-static or unsupported HTML tag: {tag}")
        self.counts[tag] = self.counts.get(tag, 0) + 1
        values = dict(attrs)
        require(len(values) == len(attrs), "Duplicate HTML attributes are forbidden.")
        allowed = {"id", "class", "lang", "role", "title", "dir"}
        allowed |= {"href", "rel", "target"} if tag == "a" else set()
        allowed |= {"name", "content", "charset"} if tag == "meta" else set()
        allowed |= {"datetime"} if tag == "time" else set()
        for name, value in attrs:
            require(name in allowed or name.startswith("aria-"), f"Unsupported HTML attribute: {name}")
            require(value is not None, f"Attribute {name} requires a value.")
        if "id" in values:
            identifier = values["id"]
            require(bool(identifier) and identifier not in self.ids, "Empty or duplicate HTML id.")
            self.ids.add(identifier)
        if tag == "a":
            require(bool(values.get("href")), "Every link requires a nonempty href.")
            self.links.append(values["href"])
        if tag == "meta":
            require(values.get("charset", "").lower() == "utf-8" or values.get("name") in {
                "viewport", "description", "robots", "google-site-verification"}, "Unsupported metadata.")
        self.in_style = tag == "style"

    def handle_startendtag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        self.handle_starttag(tag, attrs)
        self.handle_endtag(tag)

    def handle_endtag(self, tag: str) -> None:
        require(tag in self.TAGS, f"Unsupported closing tag: {tag}")
        if tag == "style":
            self.in_style = False

    def handle_data(self, data: str) -> None:
        if self.in_style:
            safe_css(data)


def validate_controls(bodies: Mapping[str, bytes]) -> None:
    rules: dict[str, str] = {}
    for line in bodies["_redirects"].decode().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        fields = line.split()
        require(len(fields) == 3 and fields[2] == "308", "Only declared 308 aliases are allowed.")
        source, destination, _ = fields
        require(source not in rules, "Duplicate redirect rule.")
        rules[source] = destination
    require(rules == ALIASES, "Redirect aliases differ from the closed public-site contract.")
    headers: dict[str, dict[str, str]] = {}
    current = None
    for line in bodies["_headers"].decode().splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if not line[0].isspace():
            require(line not in headers, "Duplicate header path.")
            current = line
            headers[current] = {}
        else:
            require(current is not None and ":" in line, "Malformed header control.")
            name, value = (item.strip() for item in line.split(":", 1))
            require(name.lower() not in headers[current], "Duplicate header field.")
            headers[current][name.lower()] = value
    expected_paths = {"/", "/index.html", "/404.html"}
    expected_paths |= {path for route in ROUTES if route not in {"/", "/404"}
                       for path in (route, route + ".html")}
    require(set(headers) == expected_paths, "Header paths differ from the static-page contract.")
    for values in headers.values():
        require(values == {"cache-control": "no-store, must-revalidate",
                           "content-type": "text/html; charset=utf-8"}, "Unsupported public-site headers.")


def internal_link(route: str, href: str) -> tuple[str, str] | None:
    require(not re.search(r"[\x00-\x20\\]", href), "Whitespace, controls or backslashes in link.")
    parsed = urllib.parse.urlsplit(urllib.parse.urljoin(ORIGIN + route, href))
    require(not parsed.username and not parsed.password, "Credentials in link URL.")
    if parsed.scheme == "mailto":
        require(bool(parsed.path) and not parsed.netloc, "Invalid email link.")
        return None
    require(parsed.scheme == "https" and bool(parsed.netloc), "Only HTTPS and mailto links are allowed.")
    if parsed.netloc != urllib.parse.urlsplit(ORIGIN).netloc:
        return None
    require(not parsed.query and parsed.path in ROUTES, f"Noncanonical or missing internal link: {href}")
    return parsed.path, urllib.parse.unquote(parsed.fragment)


def validate_payload(folder: Path) -> tuple[dict[str, bytes], dict[str, StaticHTML]]:
    require(folder.is_dir() and not folder.is_symlink(), "Static source must be a real directory.")
    entries = list(folder.iterdir())
    require({entry.name for entry in entries} == FILES, "Payload must contain exactly six HTML pages and two controls.")
    require(all(entry.is_file() and not entry.is_symlink() for entry in entries),
            "Directories, symlinks, functions and other non-files are forbidden.")
    bodies = {name: (folder / name).read_bytes() for name in sorted(FILES)}
    documents = {}
    for name, body in bodies.items():
        require(0 < len(body) <= MAX_BODY, f"Empty or oversized static file: {name}")
        try:
            text = body.decode("utf-8")
        except UnicodeError as error:
            raise PublicSiteError(f"Invalid UTF-8: {name}") from error
        require(not re.search(r"-----BEGIN [^-]*PRIVATE KEY-----|GOCSPX-[\w-]+|"
                              r"eyJ[\w-]+\.eyJ[\w-]+\.[\w-]+|"
                              r"(?i:(?:client_secret|service_role_key|SUPABASE_SERVICE_ROLE_KEY|"
                              r"access_token|refresh_token|DATABASE_URL)\s*[=:]\s*[\"']?\S+)", text),
                f"Credential-like content is forbidden: {name}")
        if name.endswith(".html"):
            documents[name] = StaticHTML(text)
    validate_controls(bodies)
    for route, name in ROUTES.items():
        for href in documents[name].links:
            target = internal_link(route, href)
            if target:
                target_route, fragment = target
                require(not fragment or fragment in documents[ROUTES[target_route]].ids,
                        f"Missing internal anchor: {href}")
    return bodies, documents


def git(repo: Path, *args: str) -> bytes:
    return subprocess.check_output(["git", "-C", str(repo), *args], stderr=subprocess.PIPE)


def source_identity(repo: Path, bodies: Mapping[str, bytes]) -> tuple[str, str]:
    commit = git(repo, "rev-parse", "HEAD").decode().strip()
    require(bool(re.fullmatch(r"[0-9a-f]{40}", commit)), "Invalid source commit.")
    tracked = git(repo, "ls-tree", "--name-only", "HEAD:public-site").decode().splitlines()
    require(set(tracked) == FILES, "Committed public-site must contain exactly the static allowlist.")
    for name, body in bodies.items():
        require(git(repo, "show", f"HEAD:public-site/{name}") == body,
                f"Commit public-site/{name} before sealing.")
    tool = (repo / SCRIPT).read_bytes()
    require(git(repo, "show", f"HEAD:{SCRIPT}") == tool, "Commit the sealing tool before sealing.")
    return commit, sha(tool)


def seal(repo: Path) -> Path:
    bodies, _ = validate_payload(repo / "public-site")
    commit, tool_hash = source_identity(repo, bodies)
    releases = repo / "dist/public-site-releases"
    require(git(repo, "check-ignore", "dist/public-site-releases/").strip() != b"",
            "Public release output must be ignored by Git.")
    core = {"schema_version": 1, "project": PROJECT, "origin": ORIGIN,
            "source_commit": commit, "tool_sha256": tool_hash,
            "files": {name: sha(body) for name, body in bodies.items()}}
    digest = sha(canonical_json(core))
    receipt = {**core, "seal_sha256": digest}
    destination = releases / digest
    if destination.exists():
        verify_seal(destination)
        require(json.loads((destination / "receipt.json").read_bytes()) == receipt,
                "Existing release has a different receipt.")
        return destination
    releases.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".sealing-", dir=releases) as temporary:
        candidate = Path(temporary) / digest
        payload = candidate / "payload"
        payload.mkdir(parents=True)
        for name, body in bodies.items():
            (payload / name).write_bytes(body)
        (candidate / "receipt.json").write_bytes(canonical_json(receipt))
        verify_seal(candidate)
        candidate.rename(destination)
    return destination


def verify_seal(release: Path) -> tuple[dict, dict[str, bytes], dict[str, StaticHTML]]:
    require(release.is_dir() and not release.is_symlink(), "Release must be a real directory.")
    require({path.name for path in release.iterdir()} == {"payload", "receipt.json"},
            "Release contains unexpected files.")
    receipt_path = release / "receipt.json"
    require(receipt_path.is_file() and not receipt_path.is_symlink(), "Receipt must be a regular file.")
    receipt_bytes = receipt_path.read_bytes()
    receipt = json.loads(receipt_bytes)
    require(receipt_bytes == canonical_json(receipt), "Receipt must use its sealed canonical encoding.")
    require(isinstance(receipt, dict) and set(receipt) == {
        "schema_version", "project", "origin", "source_commit", "tool_sha256", "files", "seal_sha256"},
        "Invalid public-site receipt schema.")
    require(receipt["schema_version"] == 1 and receipt["project"] == PROJECT and receipt["origin"] == ORIGIN,
            "Receipt targets a different site or schema.")
    require(isinstance(receipt["source_commit"], str) and bool(re.fullmatch(r"[0-9a-f]{40}", receipt["source_commit"])),
            "Invalid source commit in receipt.")
    require(isinstance(receipt["tool_sha256"], str) and bool(re.fullmatch(r"[0-9a-f]{64}", receipt["tool_sha256"])),
            "Invalid tool digest in receipt.")
    core = {key: value for key, value in receipt.items() if key != "seal_sha256"}
    require(sha(canonical_json(core)) == receipt["seal_sha256"] == release.name, "Seal identity mismatch.")
    bodies, documents = validate_payload(release / "payload")
    require(receipt["files"] == {name: sha(body) for name, body in bodies.items()}, "Sealed payload hash mismatch.")
    return receipt, bodies, documents


@dataclass(frozen=True)
class HttpResult:
    status: int
    headers: Mapping[str, str]
    body: bytes
    url: str


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def fetch_once(url: str) -> HttpResult:
    request = urllib.request.Request(url, headers={"Accept": "text/html", "Cache-Control": "no-cache",
                                                  "User-Agent": "haw-public-site-verifier/1"})
    try:
        response = urllib.request.build_opener(NoRedirect()).open(request, timeout=30)
    except urllib.error.HTTPError as error:
        response = error
    with response:
        return HttpResult(response.code, {k.lower(): v for k, v in response.headers.items()},
                          response.read(MAX_BODY + 1), response.geturl())


def curl_once(url: str) -> HttpResult:
    # Explicit alternative for Cloudflare clients that reject urllib's TLS stack.
    # No -L, no retries, no insecure flag. HTTP errors remain inspectable results.
    with tempfile.TemporaryDirectory(prefix="haw-public-http-") as temporary:
        headers, body = Path(temporary) / "headers", Path(temporary) / "body"
        result = subprocess.run(["curl", "--disable", "--silent", "--show-error", "--max-time", "30",
                                 "--proto", "=https", "--max-filesize", str(MAX_BODY),
                                 "--header", "Accept: text/html", "--header", "Cache-Control: no-cache",
                                 "--user-agent", "haw-public-site-verifier/1", "--dump-header", str(headers),
                                 "--output", str(body), "--write-out", "%{http_code}", url],
                                check=True, capture_output=True)
        blocks = re.split(rb"\r?\n\r?\n", headers.read_bytes().strip())
        fields = {}
        for line in blocks[-1].decode("iso-8859-1").splitlines()[1:]:
            if ":" in line:
                key, value = line.split(":", 1)
                fields[key.lower()] = value.strip()
        return HttpResult(int(result.stdout), fields, body.read_bytes(), url)


def verify_live(release: Path, origin: str = ORIGIN, *,
                fetch: Callable[[str], HttpResult] = fetch_once) -> dict:
    receipt, bodies, documents = verify_seal(release)
    origin = origin.rstrip("/")
    require(origin == ORIGIN or bool(re.fullmatch(r"https://[0-9a-f]{8}\.haw-info\.pages\.dev", origin)),
            "Live verification is restricted to haw-info and its immutable deployment receipts.")
    checked: dict[str, int] = {}

    def read(path: str) -> HttpResult:
        url = origin + path
        result = fetch(url)
        require(result.url == url, f"Transport followed a redirect for {path}.")
        require(len(result.body) <= MAX_BODY, f"Oversized response for {path}.")
        checked[path] = result.status
        return result

    def exact(path: str, name: str, status: int) -> None:
        result = read(path)
        require(result.status == status, f"Wrong status for {path}: {result.status}, expected {status}.")
        media = result.headers.get("content-type", "").split(";", 1)[0].strip().lower()
        require(media == "text/html", f"Wrong content-type for {path}.")
        require("location" not in result.headers, f"Unexpected Location on HTML response: {path}")
        require(sha(result.body) == receipt["files"][name], f"Wrong live HTML body for {path}.")

    for route, name in ROUTES.items():
        exact(route, name, 200)
    redirects = {"/index.html": "/", **ALIASES}
    for route in ROUTES:
        if route != "/":
            redirects[route + ".html"] = route
            redirects[route + "/"] = route
    for path, destination in sorted(redirects.items()):
        result = read(path)
        require(result.status == 308, f"Wrong canonical redirect status for {path}: {result.status}.")
        target = urllib.parse.urljoin(origin + path, result.headers.get("location", ""))
        require(target == origin + destination, f"Wrong canonical redirect destination for {path}.")
    missing = ["/__haw_public_missing_" + receipt["seal_sha256"][:12],
               "/main.dart.js", "/flutter_service_worker.js", "/env.json", "/version.json"]
    for path in missing:
        exact(path, "404.html", 404)
    # Every internal href was statically resolved against the sealed documents;
    # now every target has also passed its exact live HTML and fragment check.
    for route, name in ROUTES.items():
        for href in documents[name].links:
            target = internal_link(route, href)
            if target:
                require(checked.get(target[0]) == 200, f"Unverified internal link: {href}")
    return {"origin": origin, "seal_sha256": receipt["seal_sha256"], "source_commit": receipt["source_commit"],
            "verified_paths": dict(sorted(checked.items()))}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    for name in ("validate", "seal"):
        command = sub.add_parser(name)
        command.add_argument("--repo", type=Path, default=Path(__file__).resolve().parents[1])
    command = sub.add_parser("verify-live")
    command.add_argument("release", type=Path)
    command.add_argument("--origin", default=ORIGIN)
    command.add_argument("--transport", choices=("urllib", "curl"), default="urllib")
    args = parser.parse_args()
    try:
        if args.command == "validate":
            bodies, _ = validate_payload(args.repo / "public-site")
            print(f"Validated {len(bodies)} isolated public-site files.")
        elif args.command == "seal":
            release = seal(args.repo)
            print(f"release={release}\npayload={release / 'payload'}\nreceipt={release / 'receipt.json'}")
        else:
            result = verify_live(args.release, args.origin, fetch=curl_once if args.transport == "curl" else fetch_once)
            print(json.dumps(result, sort_keys=True, indent=2))
    except (PublicSiteError, OSError, ValueError, subprocess.SubprocessError) as error:
        print(f"Public site verification failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
