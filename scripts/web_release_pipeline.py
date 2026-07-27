#!/usr/bin/env python3
"""Deterministic, named-input web release support.

This module deliberately separates Flutter's reusable build output from the
immutable deployment payload. Flutter's `.last_build_id` remains in build/web
for its build-system cleanup role, but it is never copied into the deployment
payload.
"""

from __future__ import annotations

import argparse
import datetime as dt
import gzip
import hashlib
import io
import json
import os
import platform
import re
import shutil
import subprocess
import sys
import sysconfig
import tarfile
import tempfile
import zlib
from pathlib import Path, PurePosixPath
from typing import Any, Iterable, Mapping, Sequence
from urllib.parse import urlparse


SCHEMA_VERSION = 1
ENVIRONMENT_CONFIGS = {
    "staging": "config/web/staging.public.json",
    "production": "config/web/production.public.json",
}
RUNTIME_KEYS = (
    "APP_ENV",
    "APP_SITE_URL",
    "SUPABASE_URL",
    "SUPABASE_ANON_KEY",
    "FIREBASE_WEB_API_KEY",
    "FIREBASE_WEB_APP_ID",
    "FIREBASE_WEB_PROJECT_ID",
    "FIREBASE_WEB_SENDER_ID",
    "FIREBASE_WEB_AUTH_DOMAIN",
    "FIREBASE_WEB_STORAGE_BUCKET",
    "FIREBASE_WEB_VAPID_KEY",
    "WEB_PUSH_PUBLIC_KEY",
)
MANIFEST_KEYS = (
    "name",
    "short_name",
    "description",
    "id",
    "start_url",
    "scope",
    "display",
    "display_override",
    "theme_color",
    "background_color",
)
HTML_IDENTITY_KEYS = ("title", "apple_mobile_web_app_title")
ICON_PATHS = (
    "Icon-192.png",
    "Icon-512.png",
    "Icon-maskable-192.png",
    "Icon-maskable-512.png",
)
ICON_SETS = {
    "production": "web/icons",
    "staging": "config/web/icons/staging",
}
MATERIALIZED_WEB_PATHS = (
    "env.json",
    "flutter_bootstrap.js",
    "index.html",
    "manifest.json",
    "version.json",
    *(f"icons/{name}" for name in ICON_PATHS),
)
BUILDER_FILES = (
    "scripts/build_web_release.sh",
    "scripts/web_release_pipeline.py",
)
PINNED_FLUTTER_TOOLCHAIN = {
    "frameworkVersion": "3.35.3",
    "channel": "stable",
    "repositoryUrl": "https://github.com/flutter/flutter.git",
    "frameworkRevision": "a402d9a4376add5bc2d6b1e33e53edaae58c07f8",
    "engineRevision": "ddf47dd3ff96dbde6d9c614db0d7f019d7c7a2b7",
    "dartSdkVersion": "3.9.2",
    "devToolsVersion": "2.48.0",
    "flutter_sdk_commit": "a402d9a4376add5bc2d6b1e33e53edaae58c07f8",
    "flutter_sdk_tree": "49b4e0953230ddaa005225202d2ff70240dabc9f",
}
FORBIDDEN_ENVIRONMENT_NAMES = {
    "ENV_FILE",
    "SOURCE_DATE_EPOCH",
    "SUPABASE_URL",
    "SUPABASE_ANON_KEY",
    "WEB_BUILD_VERSION",
    "WEB_SOURCE_MAPS",
    "WEB_PUSH_PUBLIC_KEY",
}
FORBIDDEN_ENVIRONMENT_PREFIXES = (
    "APP_",
    "DART_",
    "FIREBASE_WEB_",
    "FLUTTER_",
    "PWA_",
    "PUB_",
    "WEB_",
)
DEPLOYMENT_OMISSIONS = (".last_build_id",)
BUILD_VERSION_PATTERN = re.compile(
    r"const buildVersion = (?:null|\"[^\"]*\"|\d+|\{\{flutter_service_worker_version\}\});"
)
SECRET_KEY_PATTERN = re.compile(
    r"(service.?role|private|password|oauth.?secret|client.?secret|database.?url)",
    re.IGNORECASE,
)


class ReleaseInputError(RuntimeError):
    """Raised when release inputs are incomplete or ambiguous."""


def canonical_json_bytes(value: Any) -> bytes:
    return (
        json.dumps(
            value,
            ensure_ascii=False,
            sort_keys=True,
            separators=(",", ":"),
        )
        + "\n"
    ).encode("utf-8")


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def sha256_tree(root: Path) -> str:
    if not root.is_dir():
        raise ReleaseInputError(f"Missing toolchain directory: {root}")
    digest = hashlib.sha256()
    for path in sorted(root.rglob("*"), key=lambda item: item.as_posix()):
        relative = path.relative_to(root).as_posix()
        if path.is_symlink():
            digest.update(relative.encode("utf-8"))
            digest.update(b"\0symlink\0")
            digest.update(os.readlink(path).encode("utf-8"))
        elif path.is_file():
            digest.update(relative.encode("utf-8"))
            digest.update(b"\0file\0")
            digest.update(bytes.fromhex(sha256_file(path)))
    return digest.hexdigest()


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(canonical_json_bytes(value))


def load_json(path: Path) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as error:
        raise ReleaseInputError(f"Missing required file: {path}") from error
    except json.JSONDecodeError as error:
        raise ReleaseInputError(f"Invalid JSON in {path}: {error}") from error


def require_exact_keys(
    value: Mapping[str, Any],
    expected: Iterable[str],
    *,
    label: str,
) -> None:
    expected_set = set(expected)
    actual_set = set(value)
    if actual_set != expected_set:
        missing = sorted(expected_set - actual_set)
        unknown = sorted(actual_set - expected_set)
        details = []
        if missing:
            details.append(f"missing={missing}")
        if unknown:
            details.append(f"unknown={unknown}")
        raise ReleaseInputError(f"{label} has an invalid schema: {', '.join(details)}")


def require_https_origin(value: str, *, label: str) -> None:
    parsed = urlparse(value)
    if (
        parsed.scheme != "https"
        or not parsed.netloc
        or parsed.path not in ("", "/")
        or parsed.params
        or parsed.query
        or parsed.fragment
    ):
        raise ReleaseInputError(f"{label} must be an exact https origin.")


def walk_mapping(value: Any, prefix: str = "") -> Iterable[tuple[str, Any]]:
    if isinstance(value, Mapping):
        for key, child in value.items():
            path = f"{prefix}.{key}" if prefix else str(key)
            yield path, child
            yield from walk_mapping(child, path)
    elif isinstance(value, list):
        for index, child in enumerate(value):
            yield from walk_mapping(child, f"{prefix}[{index}]")


def validate_public_only(config: Mapping[str, Any]) -> None:
    for path, value in walk_mapping(config):
        key = path.rsplit(".", 1)[-1]
        if SECRET_KEY_PATTERN.search(key):
            raise ReleaseInputError(
                f"Public web configuration contains a forbidden field: {path}"
            )
        if isinstance(value, str):
            lower = value.lower()
            if (
                "-----begin private key-----" in lower
                or "service_role" in lower
                or "service-role" in lower
                or value.startswith("sb_secret_")
            ):
                raise ReleaseInputError(
                    f"Public web configuration contains a private credential at {path}."
                )


def validate_named_config(
    config: Mapping[str, Any],
    *,
    environment: str,
) -> None:
    require_exact_keys(
        config,
        ("schema_version", "environment", "runtime", "web"),
        label="web public config",
    )
    if config["schema_version"] != SCHEMA_VERSION:
        raise ReleaseInputError(
            f"web public config schema_version must be {SCHEMA_VERSION}."
        )
    if config["environment"] != environment:
        raise ReleaseInputError(
            "web public config environment does not match the requested environment."
        )

    runtime = config["runtime"]
    web = config["web"]
    if not isinstance(runtime, Mapping) or not isinstance(web, Mapping):
        raise ReleaseInputError("runtime and web must be JSON objects.")
    require_exact_keys(runtime, RUNTIME_KEYS, label="runtime config")
    require_exact_keys(
        web,
        ("source_maps", "icon_set", "manifest", "html"),
        label="web config",
    )

    expected_app_env = "staging" if environment == "staging" else "prod"
    if runtime["APP_ENV"] != expected_app_env:
        raise ReleaseInputError(
            f"{environment} APP_ENV must be {expected_app_env!r}."
        )
    require_https_origin(str(runtime["APP_SITE_URL"]), label="APP_SITE_URL")

    supabase_url = str(runtime["SUPABASE_URL"])
    parsed_supabase = urlparse(supabase_url)
    if (
        parsed_supabase.scheme != "https"
        or not parsed_supabase.netloc.endswith(".supabase.co")
        or parsed_supabase.path not in ("", "/")
    ):
        raise ReleaseInputError("SUPABASE_URL must be a hosted Supabase project URL.")

    anon_key = str(runtime["SUPABASE_ANON_KEY"])
    if not anon_key.startswith("sb_publishable_") or len(anon_key) <= len(
        "sb_publishable_"
    ):
        raise ReleaseInputError(
            "SUPABASE_ANON_KEY must use Supabase's sb_publishable_ public-key format."
        )

    for key in RUNTIME_KEYS:
        value = runtime[key]
        if not isinstance(value, str) or not value.strip():
            raise ReleaseInputError(f"{key} must be a non-empty string.")

    if not isinstance(web["source_maps"], bool):
        raise ReleaseInputError("web.source_maps must be true or false.")
    expected_icon_set = "staging" if environment == "staging" else "production"
    if web["icon_set"] != expected_icon_set:
        raise ReleaseInputError(
            f"{environment} web.icon_set must be {expected_icon_set!r}."
        )
    if web["icon_set"] not in ICON_SETS:
        raise ReleaseInputError("web.icon_set is not a tracked icon set.")

    manifest = web["manifest"]
    html = web["html"]
    if not isinstance(manifest, Mapping) or not isinstance(html, Mapping):
        raise ReleaseInputError("web.manifest and web.html must be JSON objects.")
    require_exact_keys(manifest, MANIFEST_KEYS, label="web.manifest")
    require_exact_keys(html, HTML_IDENTITY_KEYS, label="web.html")

    for key in ("name", "short_name", "description", "id", "start_url", "scope"):
        if not isinstance(manifest[key], str) or not manifest[key]:
            raise ReleaseInputError(f"web.manifest.{key} must be a non-empty string.")
    for key in ("id", "start_url", "scope"):
        if not str(manifest[key]).startswith("/"):
            raise ReleaseInputError(f"web.manifest.{key} must be origin-relative.")
    if manifest["display"] != "standalone":
        raise ReleaseInputError("web.manifest.display must be standalone.")
    for key in ("id", "start_url", "scope"):
        if manifest[key] != "/":
            raise ReleaseInputError(f"web.manifest.{key} must remain exactly '/'.")
    display_override = manifest["display_override"]
    if (
        not isinstance(display_override, list)
        or "standalone" not in display_override
        or not all(isinstance(item, str) for item in display_override)
    ):
        raise ReleaseInputError(
            "web.manifest.display_override must include standalone."
        )
    for key in HTML_IDENTITY_KEYS:
        if not isinstance(html[key], str) or not html[key]:
            raise ReleaseInputError(f"web.html.{key} must be a non-empty string.")

    validate_public_only(config)


def forbidden_environment_names(environ: Mapping[str, str]) -> list[str]:
    forbidden = set()
    for name in environ:
        if name in FORBIDDEN_ENVIRONMENT_NAMES or any(
            name.startswith(prefix) for prefix in FORBIDDEN_ENVIRONMENT_PREFIXES
        ):
            forbidden.add(name)
    return sorted(forbidden)


def reject_forbidden_environment(environ: Mapping[str, str]) -> None:
    forbidden = forbidden_environment_names(environ)
    if forbidden:
        raise ReleaseInputError(
            "Forbidden ambient web-build variables are set: "
            + ", ".join(forbidden)
        )


def run(
    command: Sequence[str],
    *,
    cwd: Path | None = None,
) -> str:
    completed = subprocess.run(
        list(command),
        cwd=str(cwd) if cwd else None,
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    return completed.stdout.strip()


def git(repo: Path, *args: str) -> str:
    return run(("git", "-C", str(repo), *args))


def require_clean_paired_repositories(repo_root: Path) -> dict[str, Any]:
    repo_root = repo_root.resolve()
    parent_root = repo_root.parent
    mobile_toplevel = Path(git(repo_root, "rev-parse", "--show-toplevel")).resolve()
    parent_toplevel = Path(git(parent_root, "rev-parse", "--show-toplevel")).resolve()
    if mobile_toplevel != repo_root:
        raise ReleaseInputError("The mobile repository root is not the build root.")
    if parent_toplevel != parent_root or repo_root.name != "mobile":
        raise ReleaseInputError(
            "Web release builds require a paired parent/mobile worktree layout."
        )

    mobile_status = git(repo_root, "status", "--porcelain=v1", "--untracked-files=all")
    parent_status = git(parent_root, "status", "--porcelain=v1", "--untracked-files=all")
    if mobile_status:
        raise ReleaseInputError("Mobile source tree must be clean before release build.")
    if parent_status:
        raise ReleaseInputError("Parent source tree must be clean before release build.")

    mobile_commit = git(repo_root, "rev-parse", "HEAD^{commit}")
    mobile_tree = git(repo_root, "rev-parse", "HEAD^{tree}")
    parent_commit = git(parent_root, "rev-parse", "HEAD^{commit}")
    parent_tree = git(parent_root, "rev-parse", "HEAD^{tree}")
    parent_epoch = int(git(parent_root, "show", "-s", "--format=%ct", "HEAD"))

    gitlink_line = git(parent_root, "ls-tree", "HEAD", "mobile")
    match = re.fullmatch(r"160000 commit ([0-9a-f]{40})\tmobile", gitlink_line)
    if not match:
        raise ReleaseInputError("Parent HEAD does not contain the expected mobile gitlink.")
    gitlink = match.group(1)
    if gitlink != mobile_commit:
        raise ReleaseInputError(
            "Parent mobile gitlink does not match the checked-out mobile HEAD."
        )

    return {
        "parent_commit": parent_commit,
        "parent_tree": parent_tree,
        "parent_mobile_gitlink": gitlink,
        "mobile_commit": mobile_commit,
        "mobile_tree": mobile_tree,
        "source_epoch": parent_epoch,
    }


def combined_file_digest(repo_root: Path, paths: Sequence[str]) -> str:
    digest = hashlib.sha256()
    for relative in sorted(paths):
        path = repo_root / relative
        digest.update(relative.encode("utf-8"))
        digest.update(b"\0")
        digest.update(bytes.fromhex(sha256_file(path)))
    return digest.hexdigest()


def resolved_executable_sha256(name: str) -> str:
    path_value = shutil.which(name)
    if not path_value:
        raise ReleaseInputError(f"Required tool is not on PATH: {name}")
    path = Path(path_value)
    if not path.is_file():
        raise ReleaseInputError(f"Required tool is not a file: {path}")
    return sha256_file(path)


def require_unique_cache_file(root: Path, name: str) -> Path:
    matches = sorted(
        (path for path in root.rglob(name) if path.is_file()),
        key=lambda path: path.as_posix(),
    )
    if len(matches) != 1:
        raise ReleaseInputError(
            f"Expected exactly one cached {name!r} tool; found {len(matches)}."
        )
    return matches[0]


def normalized_toolchain() -> dict[str, Any]:
    flutter = json.loads(run(("flutter", "--version", "--machine")))
    flutter_root_value = flutter.get("flutterRoot")
    if not isinstance(flutter_root_value, str) or not flutter_root_value:
        raise ReleaseInputError("Flutter did not report flutterRoot.")
    flutter_root = Path(flutter_root_value).resolve()
    flutter_head = git(flutter_root, "rev-parse", "HEAD^{commit}")
    flutter_tree = git(flutter_root, "rev-parse", "HEAD^{tree}")
    flutter_status = git(
        flutter_root,
        "status",
        "--porcelain=v1",
        "--untracked-files=no",
    )
    if flutter_status:
        raise ReleaseInputError("Flutter SDK tracked files must be clean.")
    if flutter_head != flutter.get("frameworkRevision"):
        raise ReleaseInputError(
            "Flutter SDK HEAD does not match the reported framework revision."
        )

    flutter_fields = {
        key: flutter.get(key)
        for key in (
            "frameworkVersion",
            "channel",
            "repositoryUrl",
            "frameworkRevision",
            "engineRevision",
            "dartSdkVersion",
            "devToolsVersion",
        )
    }
    cache = flutter_root / "bin/cache"
    engine_artifacts = cache / "artifacts/engine"
    const_finder = require_unique_cache_file(
        engine_artifacts,
        "const_finder.dart.snapshot",
    )
    font_subset = require_unique_cache_file(engine_artifacts, "font-subset")
    if const_finder.parent != font_subset.parent:
        raise ReleaseInputError(
            "Flutter const-finder and font-subset tools have different host roots."
        )
    host_engine_root = const_finder.parent
    artifact_files = {
        "dart": cache / "dart-sdk/bin/dart",
        "dart2js_snapshot": cache / "dart-sdk/bin/snapshots/dart2js_aot.dart.snapshot",
        "dartdev_snapshot": cache / "dart-sdk/bin/snapshots/dartdev.dart.snapshot",
        "frontend_server_snapshot": (
            cache / "dart-sdk/bin/snapshots/frontend_server_aot.dart.snapshot"
        ),
        "const_finder_snapshot": const_finder,
        "font_subset": font_subset,
        "flutter_tools_snapshot": cache / "flutter_tools.snapshot",
        "engine_stamp": cache / "engine.stamp",
        "python_runtime": (
            Path(sys.base_prefix) / "Python"
            if (Path(sys.base_prefix) / "Python").is_file()
            else Path(sys.executable)
        ),
    }
    artifact_hashes = {
        name: sha256_file(path)
        for name, path in artifact_files.items()
    }
    artifact_trees = {
        "dart_sdk": sha256_tree(cache / "dart-sdk"),
        "flutter_web_sdk": sha256_tree(cache / "flutter_web_sdk"),
        "host_engine": sha256_tree(host_engine_root),
        "material_fonts": sha256_tree(cache / "artifacts/material_fonts"),
        "patched_sdk_product": sha256_tree(
            cache / "artifacts/engine/common/flutter_patched_sdk_product"
        ),
        "python_stdlib": sha256_tree(Path(sysconfig.get_paths()["stdlib"])),
    }
    bash_line = run(("bash", "--version")).splitlines()[0]
    host_executables = {
        name: resolved_executable_sha256(name)
        for name in ("bash", "git", "python3", "tar")
    }
    return {
        "flutter": flutter_fields,
        "flutter_sdk_commit": flutter_head,
        "flutter_sdk_tree": flutter_tree,
        "artifact_files": artifact_hashes,
        "artifact_trees": artifact_trees,
        "host_executables": host_executables,
        "python": platform.python_version(),
        "bash": bash_line,
        "git": run(("git", "--version")),
        "tar": run(("tar", "--version")).splitlines()[0],
        "zlib_compile": zlib.ZLIB_VERSION,
        "zlib_runtime": zlib.ZLIB_RUNTIME_VERSION,
        "platform": platform.platform(),
    }


def verify_flutter_web_version_override_contract() -> None:
    flutter_path = shutil.which("flutter")
    if not flutter_path:
        raise ReleaseInputError("Flutter is not on PATH.")
    flutter_root = Path(flutter_path).resolve().parents[1]
    source_path = (
        flutter_root
        / "packages/flutter_tools/lib/src/build_system/targets/web.dart"
    )
    source = source_path.read_text(encoding="utf-8")
    create_marker = "createVersionFile(environment, environment.defines);"
    resources_marker = (
        "final Directory webResources = "
        "environment.projectDir.childDirectory('web');"
    )
    copy_marker = "inputFile.copySync(outputFile.path);"
    exclusion_marker = (
        "if (relativePath == 'index.html' || "
        "relativePath == 'flutter_bootstrap.js')"
    )
    create_position = source.find(create_marker)
    resources_position = source.find(resources_marker, create_position + 1)
    copy_position = source.find(copy_marker, resources_position + 1)
    if (
        source.count(create_marker) != 1
        or resources_position < 0
        or source.count(copy_marker) != 1
        or source.count(exclusion_marker) != 1
        or create_position >= resources_position
        or resources_position >= copy_position
    ):
        raise ReleaseInputError(
            "Pinned Flutter no longer copies pre-materialized web/version.json "
            "after generating its default version receipt."
        )


def iso_utc_from_epoch(epoch: int) -> str:
    return (
        dt.datetime.fromtimestamp(epoch, tz=dt.timezone.utc)
        .replace(microsecond=0)
        .isoformat()
        .replace("+00:00", "Z")
    )


def extract_tag_value(html: str, pattern: re.Pattern[str], *, label: str) -> str:
    match = pattern.search(html)
    if not match:
        raise ReleaseInputError(f"Could not find {label} in web/index.html.")
    return match.group(1)


def validate_web_identity_files(
    *,
    manifest_path: Path,
    index_path: Path,
    expected_web: Mapping[str, Any],
    label: str,
) -> None:
    source_manifest = load_json(manifest_path)
    expected_manifest = expected_web["manifest"]
    for key in MANIFEST_KEYS:
        if source_manifest.get(key) != expected_manifest[key]:
            raise ReleaseInputError(
                f"{label} manifest {key!r} does not match named config."
            )

    html = index_path.read_text(encoding="utf-8")
    title = extract_tag_value(
        html,
        re.compile(r"<title>([^<]*)</title>"),
        label="HTML title",
    )
    apple_title = extract_tag_value(
        html,
        re.compile(
            r'<meta\s+name="apple-mobile-web-app-title"\s+content="([^"]*)">',
            re.MULTILINE,
        ),
        label="Apple web-app title",
    )
    expected_html = expected_web["html"]
    if title != expected_html["title"]:
        raise ReleaseInputError(f"{label} HTML title does not match named config.")
    if apple_title != expected_html["apple_mobile_web_app_title"]:
        raise ReleaseInputError(
            f"{label} Apple web-app title does not match named config."
        )


def validate_source_web_identity(repo_root: Path) -> None:
    production = load_json(repo_root / ENVIRONMENT_CONFIGS["production"])
    if not isinstance(production, Mapping):
        raise ReleaseInputError("Production web config must be a JSON object.")
    validate_web_identity_files(
        manifest_path=repo_root / "web/manifest.json",
        index_path=repo_root / "web/index.html",
        expected_web=production["web"],
        label="Tracked production web template",
    )


def selected_icon_paths(
    repo_root: Path,
    web_config: Mapping[str, Any],
) -> list[Path]:
    icon_set = str(web_config["icon_set"])
    source_dir = repo_root / ICON_SETS[icon_set]
    paths = [source_dir / name for name in ICON_PATHS]
    missing = [path.as_posix() for path in paths if not path.is_file()]
    if missing:
        raise ReleaseInputError(f"Tracked icon set is incomplete: {missing}")
    for name, path in zip(ICON_PATHS, paths, strict=True):
        expected_dimension = 192 if "192" in name else 512
        body = path.read_bytes()
        if (
            len(body) < 33
            or body[:8] != b"\x89PNG\r\n\x1a\n"
            or int.from_bytes(body[8:12], "big") != 13
            or body[12:16] != b"IHDR"
            or int.from_bytes(body[16:20], "big") != expected_dimension
            or int.from_bytes(body[20:24], "big") != expected_dimension
            or body[24] != 8
            or body[25] != 6
        ):
            raise ReleaseInputError(
                f"Tracked icon has invalid PNG dimensions or alpha format: {path}"
            )
    return paths


def icon_body_digest(paths: Sequence[Path]) -> str:
    digest = hashlib.sha256()
    for name, path in zip(
        ICON_PATHS,
        paths,
        strict=True,
    ):
        digest.update(name.encode("utf-8"))
        digest.update(b"\0")
        digest.update(bytes.fromhex(sha256_file(path)))
    return digest.hexdigest()


def icon_set_digest(repo_root: Path, web_config: Mapping[str, Any]) -> str:
    return icon_body_digest(selected_icon_paths(repo_root, web_config))


def require_pinned_flutter_toolchain(toolchain: Mapping[str, Any]) -> None:
    flutter = toolchain.get("flutter")
    if not isinstance(flutter, Mapping):
        raise ReleaseInputError("Flutter toolchain identity is missing.")
    actual = dict(flutter)
    actual["flutter_sdk_commit"] = toolchain.get("flutter_sdk_commit")
    actual["flutter_sdk_tree"] = toolchain.get("flutter_sdk_tree")
    if actual != PINNED_FLUTTER_TOOLCHAIN:
        raise ReleaseInputError(
            "Flutter/Dart toolchain left the pinned release authority: "
            f"expected={PINNED_FLUTTER_TOOLCHAIN} actual={actual}"
        )


def compute_prepared_release(
    *,
    environment: str,
    repo_root: Path,
    environ: Mapping[str, str],
) -> dict[str, Any]:
    if environment not in ENVIRONMENT_CONFIGS:
        raise ReleaseInputError("Environment must be exactly staging or production.")
    reject_forbidden_environment(environ)
    repo_root = repo_root.resolve()
    config_path = repo_root / ENVIRONMENT_CONFIGS[environment]
    config = load_json(config_path)
    if not isinstance(config, Mapping):
        raise ReleaseInputError("Named public web config must be a JSON object.")
    validate_named_config(config, environment=environment)
    validate_source_web_identity(repo_root)

    source = require_clean_paired_repositories(repo_root)
    builder_digest = combined_file_digest(repo_root, BUILDER_FILES)
    lock_digest = sha256_file(repo_root / "pubspec.lock")
    config_digest = sha256_file(config_path)
    runtime_env_digest = sha256_bytes(canonical_json_bytes(config["runtime"]))
    selected_icon_digest = icon_set_digest(repo_root, config["web"])
    toolchain = normalized_toolchain()
    require_pinned_flutter_toolchain(toolchain)
    toolchain_digest = sha256_bytes(canonical_json_bytes(toolchain))

    identity_inputs = {
        "schema_version": SCHEMA_VERSION,
        "environment": environment,
        "source": source,
        "config_sha256": config_digest,
        "runtime_env_sha256": runtime_env_digest,
        "icon_set_sha256": selected_icon_digest,
        "builder_sha256": builder_digest,
        "lockfile_sha256": lock_digest,
        "toolchain_sha256": toolchain_digest,
    }
    build_id = sha256_bytes(canonical_json_bytes(identity_inputs))
    build_version = f"{environment}-{source['mobile_commit'][:7]}-{build_id[:12]}"
    source_epoch = int(source["source_epoch"])

    prepared = {
        "schema_version": SCHEMA_VERSION,
        "environment": environment,
        "build_id": build_id,
        "build_version": build_version,
        "build_timestamp": iso_utc_from_epoch(source_epoch),
        "source_epoch": source_epoch,
        "source": source,
        "inputs": {
            "config_path": ENVIRONMENT_CONFIGS[environment],
            "config_sha256": config_digest,
            "runtime_env_sha256": runtime_env_digest,
            "icon_set": config["web"]["icon_set"],
            "icon_set_sha256": selected_icon_digest,
            "builder_files": list(BUILDER_FILES),
            "builder_sha256": builder_digest,
            "lockfile_path": "pubspec.lock",
            "lockfile_sha256": lock_digest,
            "toolchain": toolchain,
            "toolchain_sha256": toolchain_digest,
        },
        "runtime": config["runtime"],
        "web": config["web"],
    }
    return prepared


def prepare_release(
    *,
    environment: str,
    repo_root: Path,
    state_dir: Path,
    environ: Mapping[str, str],
) -> dict[str, Any]:
    prepared = compute_prepared_release(
        environment=environment,
        repo_root=repo_root,
        environ=environ,
    )

    state_dir.mkdir(parents=True, exist_ok=True)
    write_json(state_dir / "prepared.json", prepared)
    write_json(state_dir / "runtime-env.json", prepared["runtime"])
    return prepared


def safe_field(prepared: Mapping[str, Any], field: str) -> str:
    allowed = {
        "build_id": prepared["build_id"],
        "build_version": prepared["build_version"],
        "source_epoch": str(prepared["source_epoch"]),
        "source_maps": "1" if prepared["web"]["source_maps"] else "0",
    }
    if field not in allowed:
        raise ReleaseInputError(f"Unsupported prepared field: {field}")
    return str(allowed[field])


def inject_build_version(path: Path, build_version: str) -> None:
    text = path.read_text(encoding="utf-8")
    replacement = f"const buildVersion = {json.dumps(build_version)};"
    updated, count = BUILD_VERSION_PATTERN.subn(replacement, text)
    if count == 0:
        raise ReleaseInputError(f"Could not inject build version into {path}.")
    path.write_text(updated, encoding="utf-8")


def replace_exact_html_identity(
    path: Path,
    *,
    title: str,
    apple_title: str,
) -> None:
    text = path.read_text(encoding="utf-8")
    title_replacement = f"<title>{title}</title>"
    updated, title_count = re.subn(
        r"<title>[^<]*</title>",
        title_replacement,
        text,
    )
    apple_replacement = (
        '<meta name="apple-mobile-web-app-title" '
        f'content="{apple_title}">'
    )
    updated, apple_count = re.subn(
        r'<meta\s+name="apple-mobile-web-app-title"\s+content="[^"]*">',
        apple_replacement,
        updated,
        flags=re.MULTILINE,
    )
    if title_count != 1 or apple_count != 1:
        raise ReleaseInputError(
            "Could not uniquely materialize HTML/Apple installation identity."
        )
    path.write_text(updated, encoding="utf-8")


def flutter_version_fields(pubspec_path: Path) -> dict[str, str]:
    text = pubspec_path.read_text(encoding="utf-8")

    def scalar(name: str) -> str:
        matches = re.findall(
            rf"^{re.escape(name)}:\s*([^#\r\n]+?)\s*$",
            text,
            flags=re.MULTILINE,
        )
        if len(matches) != 1 or not matches[0]:
            raise ReleaseInputError(
                f"pubspec.yaml must declare exactly one {name!r} scalar."
            )
        return matches[0].strip().strip("'\"")

    app_name = scalar("name")
    complete_version = scalar("version")
    build_name, separator, build_number = complete_version.partition("+")
    fields = {
        "app_name": app_name,
        "version": build_name,
        "package_name": app_name,
    }
    if separator:
        fields["build_number"] = build_number
    return fields


def deterministic_version_receipt(prepared: Mapping[str, Any]) -> dict[str, Any]:
    return {
        "receipt_schema_version": SCHEMA_VERSION,
        "environment": prepared["environment"],
        "build_id": prepared["build_id"],
        "build_version": prepared["build_version"],
        "build_timestamp": prepared["build_timestamp"],
        "app_env": prepared["runtime"]["APP_ENV"],
        "site_origin": prepared["runtime"]["APP_SITE_URL"],
        "source": prepared["source"],
        "inputs": {
            "config_sha256": prepared["inputs"]["config_sha256"],
            "runtime_env_sha256": prepared["inputs"]["runtime_env_sha256"],
            "icon_set": prepared["inputs"]["icon_set"],
            "icon_set_sha256": prepared["inputs"]["icon_set_sha256"],
            "builder_sha256": prepared["inputs"]["builder_sha256"],
            "lockfile_sha256": prepared["inputs"]["lockfile_sha256"],
            "toolchain_sha256": prepared["inputs"]["toolchain_sha256"],
        },
        "deployment_omissions": list(DEPLOYMENT_OMISSIONS),
    }


def file_manifest(root: Path, *, prefix: str = "") -> list[tuple[str, str]]:
    entries = []
    for path in sorted(root.rglob("*"), key=lambda item: item.as_posix()):
        if path.is_symlink():
            raise ReleaseInputError(f"Release payload contains a symlink: {path}")
        if path.is_file():
            relative = path.relative_to(root).as_posix()
            display = f"{prefix}/{relative}" if prefix else relative
            entries.append((display, sha256_file(path)))
    return entries


def manifest_bytes(entries: Sequence[tuple[str, str]]) -> bytes:
    return "".join(f"{digest}  {path}\n" for path, digest in entries).encode(
        "utf-8"
    )


def materialize_release_inputs(
    *,
    build_root: Path,
    state_dir: Path,
) -> dict[str, Any]:
    build_root = build_root.resolve()
    prepared = load_json(state_dir / "prepared.json")
    if not isinstance(prepared, Mapping):
        raise ReleaseInputError("prepared.json must be a JSON object.")
    web_root = build_root / "web"
    if not web_root.is_dir():
        raise ReleaseInputError("Fresh source extraction is missing web/.")

    write_json(web_root / "env.json", prepared["runtime"])

    manifest = load_json(web_root / "manifest.json")
    if not isinstance(manifest, Mapping):
        raise ReleaseInputError("Tracked web manifest must be a JSON object.")
    materialized_manifest = dict(manifest)
    for key in MANIFEST_KEYS:
        materialized_manifest[key] = prepared["web"]["manifest"][key]
    write_json(web_root / "manifest.json", materialized_manifest)

    replace_exact_html_identity(
        web_root / "index.html",
        title=prepared["web"]["html"]["title"],
        apple_title=prepared["web"]["html"]["apple_mobile_web_app_title"],
    )
    inject_build_version(web_root / "index.html", prepared["build_version"])
    inject_build_version(
        web_root / "flutter_bootstrap.js",
        prepared["build_version"],
    )

    selected_paths = selected_icon_paths(build_root, prepared["web"])
    icon_destination = web_root / "icons"
    icon_destination.mkdir(parents=True, exist_ok=True)
    for name, source in zip(ICON_PATHS, selected_paths, strict=True):
        destination = icon_destination / name
        if source.resolve() != destination.resolve():
            shutil.copyfile(source, destination)
    if icon_set_digest(build_root, prepared["web"]) != prepared["inputs"][
        "icon_set_sha256"
    ]:
        raise ReleaseInputError("Selected icon bytes changed after preparation.")

    version = flutter_version_fields(build_root / "pubspec.yaml")
    version.update(deterministic_version_receipt(prepared))
    write_json(web_root / "version.json", version)

    validate_web_identity_files(
        manifest_path=web_root / "manifest.json",
        index_path=web_root / "index.html",
        expected_web=prepared["web"],
        label="Materialized web input",
    )

    entries = file_manifest(web_root)
    record = {
        "schema_version": SCHEMA_VERSION,
        "environment": prepared["environment"],
        "build_id": prepared["build_id"],
        "runtime_affecting_paths": list(MATERIALIZED_WEB_PATHS),
        "web_input_file_count": len(entries),
        "web_input_manifest": [
            {"path": path, "sha256": digest}
            for path, digest in entries
        ],
        "web_input_manifest_sha256": sha256_bytes(manifest_bytes(entries)),
    }
    write_json(state_dir / "materialization.json", record)
    return record


def require_compiled_web_matches_materialization(
    *,
    raw_root: Path,
    state_dir: Path,
) -> dict[str, Any]:
    record = load_json(state_dir / "materialization.json")
    if not isinstance(record, Mapping):
        raise ReleaseInputError("materialization.json must be a JSON object.")
    require_exact_keys(
        record,
        (
            "schema_version",
            "environment",
            "build_id",
            "runtime_affecting_paths",
            "web_input_file_count",
            "web_input_manifest",
            "web_input_manifest_sha256",
        ),
        label="materialization receipt",
    )
    entries_value = record["web_input_manifest"]
    if not isinstance(entries_value, list):
        raise ReleaseInputError("Materialized web input manifest must be a list.")
    expected: list[tuple[str, str]] = []
    for item in entries_value:
        if not isinstance(item, Mapping):
            raise ReleaseInputError("Materialized web input entry must be an object.")
        require_exact_keys(item, ("path", "sha256"), label="web input entry")
        require_sha256(item["sha256"], label="web input entry sha256")
        expected.append((str(item["path"]), str(item["sha256"])))
    if expected != sorted(expected):
        raise ReleaseInputError("Materialized web input manifest is not canonical.")
    if len(expected) != record["web_input_file_count"]:
        raise ReleaseInputError("Materialized web input file count changed.")
    if (
        sha256_bytes(manifest_bytes(expected))
        != record["web_input_manifest_sha256"]
    ):
        raise ReleaseInputError("Materialized web input manifest digest is invalid.")
    missing = []
    changed = []
    for relative, digest in expected:
        output = raw_root / relative
        if not output.is_file():
            missing.append(relative)
        elif (
            relative not in {"index.html", "flutter_bootstrap.js"}
            and sha256_file(output) != digest
        ):
            changed.append(relative)
    if missing or changed:
        raise ReleaseInputError(
            "Flutter output diverged from pre-compilation web inputs: "
            f"missing={missing} changed={changed}"
        )
    expected_build_version = load_json(state_dir / "prepared.json")["build_version"]
    for relative in ("index.html", "flutter_bootstrap.js"):
        compiled_text = (raw_root / relative).read_text(encoding="utf-8")
        expected_literal = (
            f"const buildVersion = {json.dumps(expected_build_version)};"
        )
        if compiled_text.count(expected_literal) != 1:
            raise ReleaseInputError(
                f"Compiled {relative} lost the pre-materialized build identity."
            )
        if "{{flutter_service_worker_version}}" in compiled_text:
            raise ReleaseInputError(
                f"Compiled {relative} retained an unresolved build identity token."
            )
    return dict(record)


def copy_deployment_payload(raw_root: Path, payload_root: Path) -> list[str]:
    if payload_root.exists():
        raise ReleaseInputError(f"Refusing to overwrite deployment payload: {payload_root}")
    payload_root.mkdir(parents=True)
    omissions = []
    for source in sorted(raw_root.rglob("*"), key=lambda item: item.as_posix()):
        relative = source.relative_to(raw_root)
        if relative.as_posix() in DEPLOYMENT_OMISSIONS:
            omissions.append(relative.as_posix())
            continue
        destination = payload_root / relative
        if source.is_symlink():
            raise ReleaseInputError(f"Raw web output contains a symlink: {source}")
        if source.is_dir():
            destination.mkdir(parents=True, exist_ok=True)
        elif source.is_file():
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, destination)
    return omissions


def normalized_tar_info(name: str, *, epoch: int, is_dir: bool) -> tarfile.TarInfo:
    info = tarfile.TarInfo(name)
    info.uid = 0
    info.gid = 0
    info.uname = "root"
    info.gname = "root"
    info.mtime = epoch
    info.mode = 0o755 if is_dir else 0o644
    info.type = tarfile.DIRTYPE if is_dir else tarfile.REGTYPE
    return info


def create_deterministic_archive(
    payload_root: Path,
    archive_path: Path,
    *,
    epoch: int,
) -> None:
    archive_path.parent.mkdir(parents=True, exist_ok=True)
    tar_buffer = io.BytesIO()
    with tarfile.open(
        fileobj=tar_buffer,
        mode="w",
        format=tarfile.PAX_FORMAT,
    ) as archive:
        root_info = normalized_tar_info("web", epoch=epoch, is_dir=True)
        archive.addfile(root_info)
        for path in sorted(payload_root.rglob("*"), key=lambda item: item.as_posix()):
            if path.is_symlink():
                raise ReleaseInputError(f"Release payload contains a symlink: {path}")
            relative = path.relative_to(payload_root).as_posix()
            archive_name = f"web/{relative}"
            if path.is_dir():
                info = normalized_tar_info(
                    archive_name,
                    epoch=epoch,
                    is_dir=True,
                )
                archive.addfile(info)
            elif path.is_file():
                content = path.read_bytes()
                info = normalized_tar_info(
                    archive_name,
                    epoch=epoch,
                    is_dir=False,
                )
                info.size = len(content)
                archive.addfile(info, io.BytesIO(content))

    with archive_path.open("wb") as output:
        with gzip.GzipFile(
            filename="",
            mode="wb",
            fileobj=output,
            compresslevel=9,
            mtime=0,
        ) as compressed:
            compressed.write(tar_buffer.getvalue())


def safe_receipt(
    prepared: Mapping[str, Any],
    materialization: Mapping[str, Any],
) -> dict[str, Any]:
    source = prepared["source"]
    inputs = prepared["inputs"]
    manifest = prepared["web"]["manifest"]
    return {
        "schema_version": SCHEMA_VERSION,
        "environment": prepared["environment"],
        "build_id": prepared["build_id"],
        "build_version": prepared["build_version"],
        "build_timestamp": prepared["build_timestamp"],
        "site_origin": prepared["runtime"]["APP_SITE_URL"],
        "source": source,
        "inputs": {
            "config_path": inputs["config_path"],
            "config_sha256": inputs["config_sha256"],
            "runtime_env_sha256": inputs["runtime_env_sha256"],
            "icon_set": inputs["icon_set"],
            "icon_set_sha256": inputs["icon_set_sha256"],
            "materialized_web_inputs_sha256": materialization[
                "web_input_manifest_sha256"
            ],
            "builder_files": inputs["builder_files"],
            "builder_sha256": inputs["builder_sha256"],
            "lockfile_path": inputs["lockfile_path"],
            "lockfile_sha256": inputs["lockfile_sha256"],
            "toolchain": inputs["toolchain"],
            "toolchain_sha256": inputs["toolchain_sha256"],
        },
        "pwa_identity": {
            key: manifest[key]
            for key in (
                "name",
                "short_name",
                "id",
                "start_url",
                "scope",
                "display",
            )
        }
        | {
            "icon_set": inputs["icon_set"],
            "icon_set_sha256": inputs["icon_set_sha256"],
            "html_title": prepared["web"]["html"]["title"],
            "apple_mobile_web_app_title": prepared["web"]["html"][
                "apple_mobile_web_app_title"
            ],
        },
    }


def write_once_or_identical(path: Path, content: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        if path.read_bytes() != content:
            raise ReleaseInputError(f"Refusing to overwrite different evidence: {path}")
        return
    temporary = path.with_name(f".{path.name}.tmp-{os.getpid()}")
    temporary.write_bytes(content)
    os.replace(temporary, path)


def install_release_directory(candidate: Path, destination: Path) -> Path:
    if destination.exists():
        if file_manifest(candidate) != file_manifest(destination):
            raise ReleaseInputError(
                f"Release identity already exists with different bytes: {destination}"
            )
        shutil.rmtree(candidate)
        return destination
    os.replace(candidate, destination)
    return destination


def require_prepared_current(
    *,
    authority_root: Path,
    state_dir: Path,
    prepared: Mapping[str, Any],
) -> None:
    runtime_env = load_json(state_dir / "runtime-env.json")
    if runtime_env != prepared.get("runtime"):
        raise ReleaseInputError("Prepared runtime environment changed during the build.")
    current = compute_prepared_release(
        environment=str(prepared.get("environment", "")),
        repo_root=authority_root,
        environ=os.environ,
    )
    if canonical_json_bytes(current) != canonical_json_bytes(prepared):
        raise ReleaseInputError(
            "Source, configuration, builder, lockfile, or toolchain changed "
            "between preparation and finalization."
        )


def finalize_release(
    *,
    build_root: Path,
    authority_root: Path,
    state_dir: Path,
) -> Path:
    build_root = build_root.resolve()
    authority_root = authority_root.resolve()
    prepared = load_json(state_dir / "prepared.json")
    if not isinstance(prepared, Mapping):
        raise ReleaseInputError("prepared.json must be a JSON object.")
    require_prepared_current(
        authority_root=authority_root,
        state_dir=state_dir,
        prepared=prepared,
    )

    raw_root = build_root / "build/web"
    if not raw_root.is_dir():
        raise ReleaseInputError("Flutter did not produce build/web.")
    last_build_id = raw_root / ".last_build_id"
    if not last_build_id.is_file():
        raise ReleaseInputError(
            "Flutter build output is missing .last_build_id; omission policy cannot be audited."
        )

    materialization = require_compiled_web_matches_materialization(
        raw_root=raw_root,
        state_dir=state_dir,
    )
    if (
        materialization["environment"] != prepared["environment"]
        or materialization["build_id"] != prepared["build_id"]
    ):
        raise ReleaseInputError("Materialized web authority does not match the build.")
    validate_web_identity_files(
        manifest_path=raw_root / "manifest.json",
        index_path=raw_root / "index.html",
        expected_web=prepared["web"],
        label="Compiled web output",
    )

    raw_entries = file_manifest(raw_root)
    marker_value = last_build_id.read_text(encoding="utf-8").strip()
    if not re.fullmatch(r"[0-9a-f]{32}", marker_value):
        raise ReleaseInputError("Flutter .last_build_id has an unexpected format.")
    audit_dir = authority_root / "dist/web-release-audit"
    audit_dir.mkdir(parents=True, exist_ok=True)
    raw_manifest_path = (
        audit_dir
        / f"{prepared['environment']}-{prepared['build_id'][:16]}"
        / f"{marker_value}.raw.sha256"
    )
    write_once_or_identical(raw_manifest_path, manifest_bytes(raw_entries))

    release_parent = authority_root / "dist/web-releases"
    release_parent.mkdir(parents=True, exist_ok=True)
    release_name = f"{prepared['environment']}-{prepared['build_id'][:16]}"
    release_dir = release_parent / release_name
    candidate_dir = Path(
        tempfile.mkdtemp(prefix=f".{release_name}.", dir=release_parent)
    )
    try:
        payload_root = candidate_dir / "web"
        omissions = copy_deployment_payload(raw_root, payload_root)
        if omissions != list(DEPLOYMENT_OMISSIONS):
            raise ReleaseInputError(
                "Deployment omission set changed: "
                f"expected={list(DEPLOYMENT_OMISSIONS)} actual={omissions}"
            )
        if (payload_root / ".last_build_id").exists():
            raise ReleaseInputError(".last_build_id entered the deployment payload.")

        payload_entries = file_manifest(payload_root, prefix="web")
        manifest_path = candidate_dir / "payload-manifest.sha256"
        manifest_path.write_bytes(manifest_bytes(payload_entries))

        archive_name = f"{prepared['build_version']}-web.tar.gz"
        archive_path = candidate_dir / archive_name
        create_deterministic_archive(
            payload_root,
            archive_path,
            epoch=int(prepared["source_epoch"]),
        )

        receipt = safe_receipt(prepared, materialization)
        receipt.update(
            {
                "payload": {
                    "file_count": len(payload_entries),
                    "manifest_file": manifest_path.name,
                    "manifest_sha256": sha256_file(manifest_path),
                    "archive_file": archive_path.name,
                    "archive_sha256": sha256_file(archive_path),
                    "archive_root": "web",
                    "omitted_raw_build_files": omissions,
                }
            }
        )
        write_json(candidate_dir / "release-receipt.json", receipt)
        return install_release_directory(candidate_dir, release_dir)
    except Exception:
        if candidate_dir.exists():
            shutil.rmtree(candidate_dir)
        raise


def parse_manifest(path: Path) -> dict[str, str]:
    entries: dict[str, str] = {}
    for line_number, line in enumerate(
        path.read_text(encoding="utf-8").splitlines(),
        start=1,
    ):
        match = re.fullmatch(r"([0-9a-f]{64})  (.+)", line)
        if not match:
            raise ReleaseInputError(
                f"Invalid manifest line {line_number} in {path}."
            )
        digest, name = match.groups()
        if name in entries:
            raise ReleaseInputError(f"Duplicate manifest path: {name}")
        entries[name] = digest
    return entries


def validate_archive_member(member: tarfile.TarInfo) -> None:
    name = PurePosixPath(member.name)
    if name.is_absolute() or ".." in name.parts:
        raise ReleaseInputError(f"Unsafe archive path: {member.name}")
    if member.issym() or member.islnk() or member.isdev():
        raise ReleaseInputError(f"Unsupported archive entry: {member.name}")
    if "__MACOSX" in name.parts or any(part.startswith("._") for part in name.parts):
        raise ReleaseInputError(f"macOS metadata entered archive: {member.name}")


def require_sha256(value: Any, *, label: str) -> None:
    if not isinstance(value, str) or not re.fullmatch(r"[0-9a-f]{64}", value):
        raise ReleaseInputError(f"{label} must be a lowercase SHA-256 digest.")


def validate_release_receipt(receipt: Mapping[str, Any]) -> None:
    require_exact_keys(
        receipt,
        (
            "schema_version",
            "environment",
            "build_id",
            "build_version",
            "build_timestamp",
            "site_origin",
            "source",
            "inputs",
            "pwa_identity",
            "payload",
        ),
        label="release receipt",
    )
    if receipt["schema_version"] != SCHEMA_VERSION:
        raise ReleaseInputError("Release receipt schema version is unsupported.")
    if receipt["environment"] not in ENVIRONMENT_CONFIGS:
        raise ReleaseInputError("Release receipt environment is invalid.")
    require_sha256(receipt["build_id"], label="build_id")
    require_https_origin(str(receipt["site_origin"]), label="site_origin")

    source = receipt["source"]
    inputs = receipt["inputs"]
    pwa_identity = receipt["pwa_identity"]
    payload = receipt["payload"]
    if not all(
        isinstance(value, Mapping)
        for value in (source, inputs, pwa_identity, payload)
    ):
        raise ReleaseInputError("Release receipt objects have invalid types.")
    require_exact_keys(
        source,
        (
            "parent_commit",
            "parent_tree",
            "parent_mobile_gitlink",
            "mobile_commit",
            "mobile_tree",
            "source_epoch",
        ),
        label="release source",
    )
    for key in (
        "parent_commit",
        "parent_tree",
        "parent_mobile_gitlink",
        "mobile_commit",
        "mobile_tree",
    ):
        if not isinstance(source[key], str) or not re.fullmatch(
            r"[0-9a-f]{40}", source[key]
        ):
            raise ReleaseInputError(f"release source {key} is invalid.")
    if source["parent_mobile_gitlink"] != source["mobile_commit"]:
        raise ReleaseInputError("Release receipt parent/mobile pairing is inconsistent.")
    if not isinstance(source["source_epoch"], int):
        raise ReleaseInputError("Release source_epoch must be an integer.")

    require_exact_keys(
        inputs,
        (
            "config_path",
            "config_sha256",
            "runtime_env_sha256",
            "icon_set",
            "icon_set_sha256",
            "materialized_web_inputs_sha256",
            "builder_files",
            "builder_sha256",
            "lockfile_path",
            "lockfile_sha256",
            "toolchain",
            "toolchain_sha256",
        ),
        label="release inputs",
    )
    for key in (
        "config_sha256",
        "runtime_env_sha256",
        "icon_set_sha256",
        "materialized_web_inputs_sha256",
        "builder_sha256",
        "lockfile_sha256",
        "toolchain_sha256",
    ):
        require_sha256(inputs[key], label=f"inputs.{key}")
    if inputs["config_path"] != ENVIRONMENT_CONFIGS[receipt["environment"]]:
        raise ReleaseInputError("Release config path does not match its environment.")
    expected_icon_set = (
        "staging" if receipt["environment"] == "staging" else "production"
    )
    if inputs["icon_set"] != expected_icon_set:
        raise ReleaseInputError("Release icon set does not match its environment.")
    if inputs["builder_files"] != list(BUILDER_FILES):
        raise ReleaseInputError("Release builder file inventory is invalid.")
    if inputs["lockfile_path"] != "pubspec.lock":
        raise ReleaseInputError("Release lockfile path is invalid.")
    if not isinstance(inputs["toolchain"], Mapping):
        raise ReleaseInputError("Release toolchain identity must be an object.")
    require_pinned_flutter_toolchain(inputs["toolchain"])
    if (
        sha256_bytes(canonical_json_bytes(inputs["toolchain"]))
        != inputs["toolchain_sha256"]
    ):
        raise ReleaseInputError("Release toolchain digest is internally inconsistent.")

    identity_inputs = {
        "schema_version": SCHEMA_VERSION,
        "environment": receipt["environment"],
        "source": source,
        "config_sha256": inputs["config_sha256"],
        "runtime_env_sha256": inputs["runtime_env_sha256"],
        "icon_set_sha256": inputs["icon_set_sha256"],
        "builder_sha256": inputs["builder_sha256"],
        "lockfile_sha256": inputs["lockfile_sha256"],
        "toolchain_sha256": inputs["toolchain_sha256"],
    }
    expected_build_id = sha256_bytes(canonical_json_bytes(identity_inputs))
    if receipt["build_id"] != expected_build_id:
        raise ReleaseInputError("Release build_id is inconsistent with its inputs.")
    expected_build_version = (
        f"{receipt['environment']}-{source['mobile_commit'][:7]}-"
        f"{expected_build_id[:12]}"
    )
    if receipt["build_version"] != expected_build_version:
        raise ReleaseInputError("Release build_version is inconsistent with its inputs.")
    if receipt["build_timestamp"] != iso_utc_from_epoch(source["source_epoch"]):
        raise ReleaseInputError(
            "Release build_timestamp is inconsistent with the source epoch."
        )

    require_exact_keys(
        pwa_identity,
        (
            "name",
            "short_name",
            "id",
            "start_url",
            "scope",
            "display",
            "icon_set",
            "icon_set_sha256",
            "html_title",
            "apple_mobile_web_app_title",
        ),
        label="PWA identity",
    )
    require_exact_keys(
        payload,
        (
            "file_count",
            "manifest_file",
            "manifest_sha256",
            "archive_file",
            "archive_sha256",
            "archive_root",
            "omitted_raw_build_files",
        ),
        label="release payload",
    )
    if (
        not isinstance(payload["file_count"], int)
        or payload["file_count"] <= 0
        or payload["archive_root"] != "web"
        or payload["omitted_raw_build_files"] != list(DEPLOYMENT_OMISSIONS)
    ):
        raise ReleaseInputError("Release payload policy is invalid.")
    for key in ("manifest_file", "archive_file"):
        name = payload[key]
        if (
            not isinstance(name, str)
            or not name
            or Path(name).name != name
            or "/" in name
            or "\\" in name
        ):
            raise ReleaseInputError(f"Release payload {key} must be a basename.")
    require_sha256(payload["manifest_sha256"], label="payload.manifest_sha256")
    require_sha256(payload["archive_sha256"], label="payload.archive_sha256")


def validate_embedded_identity(
    destination: Path,
    receipt: Mapping[str, Any],
) -> None:
    web_root = destination / "web"
    version = load_json(web_root / "version.json")
    runtime = load_json(web_root / "env.json")
    manifest = load_json(web_root / "manifest.json")
    if not all(isinstance(value, Mapping) for value in (version, runtime, manifest)):
        raise ReleaseInputError("Embedded release identities must be JSON objects.")

    require_exact_keys(runtime, RUNTIME_KEYS, label="embedded env.json")
    validate_public_only({"runtime": runtime})
    if not str(runtime["SUPABASE_ANON_KEY"]).startswith("sb_publishable_"):
        raise ReleaseInputError("Embedded Supabase key is not publishable.")
    expected_app_env = (
        "staging" if receipt["environment"] == "staging" else "prod"
    )
    if runtime["APP_ENV"] != expected_app_env:
        raise ReleaseInputError("Embedded APP_ENV does not match release receipt.")
    if runtime["APP_SITE_URL"] != receipt["site_origin"]:
        raise ReleaseInputError("Embedded APP_SITE_URL does not match release receipt.")
    runtime_digest = sha256_bytes(canonical_json_bytes(runtime))
    if runtime_digest != receipt["inputs"]["runtime_env_sha256"]:
        raise ReleaseInputError("Embedded env.json does not match its input digest.")

    version_expectations = {
        "receipt_schema_version": SCHEMA_VERSION,
        "environment": receipt["environment"],
        "build_id": receipt["build_id"],
        "build_version": receipt["build_version"],
        "build_timestamp": receipt["build_timestamp"],
        "app_env": expected_app_env,
        "site_origin": receipt["site_origin"],
        "source": receipt["source"],
        "deployment_omissions": list(DEPLOYMENT_OMISSIONS),
    }
    for key, expected in version_expectations.items():
        if version.get(key) != expected:
            raise ReleaseInputError(
                f"Embedded version.json {key} does not match release receipt."
            )
    expected_version_inputs = {
        key: receipt["inputs"][key]
        for key in (
            "config_sha256",
            "runtime_env_sha256",
            "icon_set",
            "icon_set_sha256",
            "builder_sha256",
            "lockfile_sha256",
            "toolchain_sha256",
        )
    }
    if version.get("inputs") != expected_version_inputs:
        raise ReleaseInputError(
            "Embedded version.json input digests do not match release receipt."
        )
    embedded_icon_paths = [web_root / "icons" / name for name in ICON_PATHS]
    if any(not path.is_file() for path in embedded_icon_paths):
        raise ReleaseInputError("Embedded icon set is incomplete.")
    if (
        icon_body_digest(embedded_icon_paths)
        != receipt["pwa_identity"]["icon_set_sha256"]
        or receipt["pwa_identity"]["icon_set_sha256"]
        != receipt["inputs"]["icon_set_sha256"]
        or receipt["pwa_identity"]["icon_set"] != receipt["inputs"]["icon_set"]
    ):
        raise ReleaseInputError("Embedded icon set does not match release receipt.")

    for key in ("name", "short_name", "id", "start_url", "scope", "display"):
        if manifest.get(key) != receipt["pwa_identity"][key]:
            raise ReleaseInputError(
                f"Embedded manifest {key} does not match release receipt."
            )
    index = (web_root / "index.html").read_text(encoding="utf-8")
    title = extract_tag_value(
        index,
        re.compile(r"<title>([^<]*)</title>"),
        label="embedded HTML title",
    )
    apple_title = extract_tag_value(
        index,
        re.compile(
            r'<meta\s+name="apple-mobile-web-app-title"\s+content="([^"]*)">',
            re.MULTILINE,
        ),
        label="embedded Apple web-app title",
    )
    if title != receipt["pwa_identity"]["html_title"]:
        raise ReleaseInputError("Embedded HTML title does not match release receipt.")
    if apple_title != receipt["pwa_identity"]["apple_mobile_web_app_title"]:
        raise ReleaseInputError(
            "Embedded Apple web-app title does not match release receipt."
        )


def verify_release(
    release_dir: Path,
    *,
    expected_archive_sha256: str | None = None,
    extract_to: Path | None = None,
) -> dict[str, Any]:
    receipt = load_json(release_dir / "release-receipt.json")
    if not isinstance(receipt, Mapping):
        raise ReleaseInputError("Release receipt must be a JSON object.")
    validate_release_receipt(receipt)
    payload = receipt["payload"]
    archive_path = release_dir / payload["archive_file"]
    manifest_path = release_dir / payload["manifest_file"]

    archive_digest = sha256_file(archive_path)
    if archive_digest != payload["archive_sha256"]:
        raise ReleaseInputError("Archive hash does not match release receipt.")
    if expected_archive_sha256 and archive_digest != expected_archive_sha256:
        raise ReleaseInputError("Archive hash does not match the authorized hash.")
    if sha256_file(manifest_path) != payload["manifest_sha256"]:
        raise ReleaseInputError("Manifest hash does not match release receipt.")

    expected = parse_manifest(manifest_path)
    if any(not name.startswith("web/") for name in expected):
        raise ReleaseInputError("Payload manifest must contain one web/ root.")
    if ".last_build_id" in expected or "web/.last_build_id" in expected:
        raise ReleaseInputError(".last_build_id entered the declared payload.")
    if len(expected) != payload["file_count"]:
        raise ReleaseInputError("Manifest file count does not match release receipt.")

    staged_root = release_dir / "web"
    if not staged_root.is_dir():
        raise ReleaseInputError("Release directory is missing its staged web root.")
    staged = dict(file_manifest(staged_root, prefix="web"))
    if staged != expected:
        missing = sorted(set(expected) - set(staged))
        extra = sorted(set(staged) - set(expected))
        changed = sorted(
            name
            for name in set(expected) & set(staged)
            if expected[name] != staged[name]
        )
        raise ReleaseInputError(
            "Staged payload does not match manifest: "
            f"missing={missing} extra={extra} changed={changed}"
        )
    validate_embedded_identity(release_dir, receipt)

    temporary: tempfile.TemporaryDirectory[str] | None = None
    if extract_to is None:
        temporary = tempfile.TemporaryDirectory(prefix="kemetic-release-verify-")
        destination = Path(temporary.name)
    else:
        destination = extract_to
        if destination.exists() and any(destination.iterdir()):
            raise ReleaseInputError("Extraction destination must be empty.")
        destination.mkdir(parents=True, exist_ok=True)

    try:
        with tarfile.open(archive_path, mode="r:gz") as archive:
            members = archive.getmembers()
            member_names = [member.name.rstrip("/") for member in members]
            if len(member_names) != len(set(member_names)):
                raise ReleaseInputError("Archive contains duplicate member names.")
            for member in members:
                validate_archive_member(member)
                normalized_name = member.name.rstrip("/")
                if normalized_name != "web" and not normalized_name.startswith(
                    "web/"
                ):
                    raise ReleaseInputError(
                        f"Archive entry is outside the web root: {member.name}"
                    )
            archive.extractall(destination, members=members, filter="data")
        actual = dict(file_manifest(destination))
        if actual != expected:
            missing = sorted(set(expected) - set(actual))
            extra = sorted(set(actual) - set(expected))
            changed = sorted(
                name
                for name in set(expected) & set(actual)
                if expected[name] != actual[name]
            )
            raise ReleaseInputError(
                "Extracted payload does not match manifest: "
                f"missing={missing} extra={extra} changed={changed}"
            )
        validate_embedded_identity(destination, receipt)
    finally:
        if temporary is not None:
            temporary.cleanup()
    return receipt


def compare_releases(first: Path, second: Path) -> list[dict[str, str | None]]:
    first_receipt = load_json(first / "release-receipt.json")
    second_receipt = load_json(second / "release-receipt.json")
    first_manifest = parse_manifest(first / first_receipt["payload"]["manifest_file"])
    second_manifest = parse_manifest(second / second_receipt["payload"]["manifest_file"])
    differences = []
    for name in sorted(set(first_manifest) | set(second_manifest)):
        first_hash = first_manifest.get(name)
        second_hash = second_manifest.get(name)
        if first_hash != second_hash:
            differences.append(
                {
                    "path": name,
                    "first_sha256": first_hash,
                    "second_sha256": second_hash,
                }
            )
    return differences


def json_difference_paths(
    first: Any,
    second: Any,
    *,
    prefix: str = "",
) -> list[str]:
    """Return the exact dotted paths whose JSON values differ."""
    if isinstance(first, Mapping) and isinstance(second, Mapping):
        paths: list[str] = []
        for key in sorted(set(first) | set(second)):
            path = f"{prefix}.{key}" if prefix else str(key)
            if key not in first or key not in second:
                paths.append(path)
                continue
            paths.extend(
                json_difference_paths(first[key], second[key], prefix=path)
            )
        return paths
    if first != second:
        return [prefix or "$"]
    return []


def require_unique_string_list(value: Any, *, label: str) -> list[str]:
    if (
        not isinstance(value, list)
        or not value
        or not all(isinstance(item, str) and item for item in value)
        or len(value) != len(set(value))
    ):
        raise ReleaseInputError(f"{label} must be a nonempty unique string list.")
    return list(value)


def validate_environment_delta(
    staging_release: Path,
    production_release: Path,
    *,
    contract_path: Path,
) -> dict[str, Any]:
    contract = load_json(contract_path)
    if not isinstance(contract, Mapping):
        raise ReleaseInputError("Environment delta contract must be an object.")
    require_exact_keys(
        contract,
        (
            "schema_version",
            "runtime_keys",
            "manifest_fields",
            "html_identity_fields",
            "release_receipt_fields",
            "version_receipt_fields",
            "reason_vocabulary",
            "reason_bindings",
            "icon_body_paths",
            "deployable_body_paths",
            "required_equal_manifest_fields",
            "required_fixed_values",
        ),
        label="environment delta contract",
    )
    if contract["schema_version"] != 1:
        raise ReleaseInputError("Environment delta contract schema is unsupported.")

    runtime_keys = require_unique_string_list(
        contract["runtime_keys"],
        label="environment delta runtime_keys",
    )
    manifest_fields = require_unique_string_list(
        contract["manifest_fields"],
        label="environment delta manifest_fields",
    )
    html_identity_fields = require_unique_string_list(
        contract["html_identity_fields"],
        label="environment delta html_identity_fields",
    )
    release_receipt_fields = require_unique_string_list(
        contract["release_receipt_fields"],
        label="environment delta release_receipt_fields",
    )
    version_receipt_fields = require_unique_string_list(
        contract["version_receipt_fields"],
        label="environment delta version_receipt_fields",
    )
    icon_body_paths = require_unique_string_list(
        contract["icon_body_paths"],
        label="environment delta icon_body_paths",
    )
    reason_vocabulary = require_unique_string_list(
        contract["reason_vocabulary"],
        label="environment delta reason_vocabulary",
    )
    deployable_body_paths = contract["deployable_body_paths"]
    reason_bindings = contract["reason_bindings"]
    if not isinstance(deployable_body_paths, Mapping) or not deployable_body_paths:
        raise ReleaseInputError(
            "environment delta deployable_body_paths must be an object."
        )
    if not isinstance(reason_bindings, Mapping):
        raise ReleaseInputError("environment delta reason_bindings must be an object.")
    if set(reason_bindings) != set(reason_vocabulary):
        raise ReleaseInputError(
            "Environment delta reason vocabulary and bindings disagree."
        )
    expected_reason_paths: dict[str, set[str]] = {}
    for reason in reason_vocabulary:
        expected_reason_paths[reason] = set(
            require_unique_string_list(
                reason_bindings[reason],
                label=f"environment delta reason binding {reason}",
            )
        )
    actual_reason_paths = {reason: set() for reason in reason_vocabulary}
    for path, reasons_value in deployable_body_paths.items():
        if not isinstance(path, str) or not path.startswith("web/"):
            raise ReleaseInputError(
                f"Environment delta deployable path is invalid: {path!r}"
            )
        reasons = require_unique_string_list(
            reasons_value,
            label=f"environment delta reasons for {path}",
        )
        unknown_reasons = sorted(set(reasons) - set(reason_vocabulary))
        if unknown_reasons:
            raise ReleaseInputError(
                f"Environment delta path {path} uses unknown reasons: "
                f"{unknown_reasons}"
            )
        for reason in reasons:
            actual_reason_paths[reason].add(path)
    if actual_reason_paths != expected_reason_paths:
        raise ReleaseInputError(
            "Environment delta reason-to-body bindings drifted: "
            f"expected={expected_reason_paths} actual={actual_reason_paths}"
        )

    staging_receipt = verify_release(staging_release)
    production_receipt = verify_release(production_release)
    if (
        staging_receipt["environment"] != "staging"
        or production_receipt["environment"] != "production"
    ):
        raise ReleaseInputError("Environment release ordering is invalid.")
    receipt_differences = json_difference_paths(
        staging_receipt,
        production_receipt,
    )
    if receipt_differences != sorted(release_receipt_fields):
        raise ReleaseInputError(
            "Release-receipt environment delta drifted: "
            f"actual={receipt_differences}"
        )

    differences = compare_releases(staging_release, production_release)
    actual_paths = {item["path"] for item in differences}
    expected_paths = set(deployable_body_paths)
    if actual_paths != expected_paths:
        raise ReleaseInputError(
            "Cross-environment deployable delta is unexplained: "
            f"missing={sorted(expected_paths - actual_paths)} "
            f"extra={sorted(actual_paths - expected_paths)}"
        )

    staging_runtime = load_json(staging_release / "web/env.json")
    production_runtime = load_json(production_release / "web/env.json")
    runtime_differences = sorted(
        key
        for key in RUNTIME_KEYS
        if staging_runtime[key] != production_runtime[key]
    )
    if runtime_differences != sorted(runtime_keys):
        raise ReleaseInputError(
            f"Runtime environment delta drifted: {runtime_differences}"
        )

    staging_manifest = load_json(staging_release / "web/manifest.json")
    production_manifest = load_json(production_release / "web/manifest.json")
    manifest_differences = sorted(
        key
        for key in set(staging_manifest) | set(production_manifest)
        if staging_manifest.get(key) != production_manifest.get(key)
    )
    if manifest_differences != sorted(manifest_fields):
        raise ReleaseInputError(
            f"Manifest structural delta drifted: {manifest_differences}"
        )
    for key in contract["required_equal_manifest_fields"]:
        if staging_manifest.get(key) != production_manifest.get(key):
            raise ReleaseInputError(f"Manifest field must remain equal: {key}")
    for key, expected in contract["required_fixed_values"].items():
        if (
            staging_manifest.get(key) != expected
            or production_manifest.get(key) != expected
        ):
            raise ReleaseInputError(
                f"Manifest field {key!r} left its fixed release value."
            )

    staging_index = (staging_release / "web/index.html").read_text(
        encoding="utf-8"
    )
    production_index = (production_release / "web/index.html").read_text(
        encoding="utf-8"
    )
    html_values = {
        "staging": {
            "title": extract_tag_value(
                staging_index,
                re.compile(r"<title>([^<]*)</title>"),
                label="staging HTML title",
            ),
            "apple_mobile_web_app_title": extract_tag_value(
                staging_index,
                re.compile(
                    r'<meta\s+name="apple-mobile-web-app-title"\s+content="([^"]*)">'
                ),
                label="staging Apple title",
            ),
        },
        "production": {
            "title": extract_tag_value(
                production_index,
                re.compile(r"<title>([^<]*)</title>"),
                label="production HTML title",
            ),
            "apple_mobile_web_app_title": extract_tag_value(
                production_index,
                re.compile(
                    r'<meta\s+name="apple-mobile-web-app-title"\s+content="([^"]*)">'
                ),
                label="production Apple title",
            ),
        },
    }
    actual_html_differences = sorted(
        key
        for key in html_values["staging"]
        if html_values["staging"][key] != html_values["production"][key]
    )
    if actual_html_differences != sorted(html_identity_fields):
        raise ReleaseInputError(
            f"HTML identity delta drifted: {actual_html_differences}"
        )
    for path in icon_body_paths:
        if sha256_file(staging_release / path) == sha256_file(
            production_release / path
        ):
            raise ReleaseInputError(f"RC icon body is not distinct: {path}")

    staging_version = load_json(staging_release / "web/version.json")
    production_version = load_json(production_release / "web/version.json")
    version_differences = json_difference_paths(
        staging_version,
        production_version,
    )
    if version_differences != sorted(version_receipt_fields):
        raise ReleaseInputError(
            "Version-receipt environment delta drifted: "
            f"actual={version_differences}"
        )

    return {
        "schema_version": 1,
        "staging_build_id": staging_receipt["build_id"],
        "production_build_id": production_receipt["build_id"],
        "runtime_differences": runtime_differences,
        "manifest_differences": manifest_differences,
        "html_identity_differences": actual_html_differences,
        "release_receipt_differences": receipt_differences,
        "version_receipt_differences": version_differences,
        "deployable_body_differences": differences,
        "reason_bindings": {
            reason: sorted(paths)
            for reason, paths in sorted(actual_reason_paths.items())
        },
        "unexplained_differences": [],
    }


def command_prepare(arguments: argparse.Namespace) -> None:
    prepared = prepare_release(
        environment=arguments.environment,
        repo_root=arguments.repo_root,
        state_dir=arguments.state_dir,
        environ=os.environ,
    )
    print(f"environment={prepared['environment']}")
    print(f"build_id={prepared['build_id']}")
    print(f"build_version={prepared['build_version']}")
    print(f"site_origin={prepared['runtime']['APP_SITE_URL']}")
    print(f"config_sha256={prepared['inputs']['config_sha256']}")


def command_field(arguments: argparse.Namespace) -> None:
    prepared = load_json(arguments.prepared)
    print(safe_field(prepared, arguments.field))


def command_verify_lockfile(arguments: argparse.Namespace) -> None:
    prepared = load_json(arguments.prepared)
    if not isinstance(prepared, Mapping):
        raise ReleaseInputError("prepared.json must be a JSON object.")
    expected = prepared.get("inputs", {}).get("lockfile_sha256")
    require_sha256(expected, label="prepared lockfile_sha256")
    actual = sha256_file(arguments.lockfile)
    if actual != expected:
        raise ReleaseInputError(
            "Resolved pubspec.lock differs from the recorded source lockfile."
        )
    print(f"verified_lockfile_sha256={actual}")


def command_materialize(arguments: argparse.Namespace) -> None:
    record = materialize_release_inputs(
        build_root=arguments.build_root,
        state_dir=arguments.state_dir,
    )
    print(
        "materialized_web_inputs_sha256="
        f"{record['web_input_manifest_sha256']}"
    )
    print(f"materialized_web_files={record['web_input_file_count']}")


def command_finalize(arguments: argparse.Namespace) -> None:
    release_dir = finalize_release(
        build_root=arguments.build_root,
        authority_root=arguments.authority_root,
        state_dir=arguments.state_dir,
    )
    receipt = load_json(release_dir / "release-receipt.json")
    print(f"release_dir={release_dir}")
    print(f"archive={release_dir / receipt['payload']['archive_file']}")
    print(f"archive_sha256={receipt['payload']['archive_sha256']}")
    print(f"payload_files={receipt['payload']['file_count']}")


def command_verify(arguments: argparse.Namespace) -> None:
    receipt = verify_release(
        arguments.release_dir,
        expected_archive_sha256=arguments.expected_archive_sha256,
        extract_to=arguments.extract_to,
    )
    print(f"verified_build_id={receipt['build_id']}")
    print(f"verified_archive_sha256={receipt['payload']['archive_sha256']}")
    print(f"verified_payload_files={receipt['payload']['file_count']}")


def command_compare(arguments: argparse.Namespace) -> None:
    print(
        json.dumps(
            compare_releases(arguments.first, arguments.second),
            ensure_ascii=False,
            indent=2,
        )
    )


def command_compare_environments(arguments: argparse.Namespace) -> None:
    result = validate_environment_delta(
        arguments.staging,
        arguments.production,
        contract_path=arguments.contract,
    )
    content = canonical_json_bytes(result)
    if arguments.output:
        write_once_or_identical(arguments.output, content)
    print(content.decode("utf-8"), end="")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)

    prepare = subparsers.add_parser("prepare")
    prepare.add_argument("environment", choices=tuple(ENVIRONMENT_CONFIGS))
    prepare.add_argument("--repo-root", type=Path, required=True)
    prepare.add_argument("--state-dir", type=Path, required=True)
    prepare.set_defaults(handler=command_prepare)

    field = subparsers.add_parser("field")
    field.add_argument("--prepared", type=Path, required=True)
    field.add_argument(
        "field",
        choices=("build_id", "build_version", "source_epoch", "source_maps"),
    )
    field.set_defaults(handler=command_field)

    verify_lockfile = subparsers.add_parser("verify-lockfile")
    verify_lockfile.add_argument("--prepared", type=Path, required=True)
    verify_lockfile.add_argument("--lockfile", type=Path, required=True)
    verify_lockfile.set_defaults(handler=command_verify_lockfile)

    materialize = subparsers.add_parser("materialize")
    materialize.add_argument("--build-root", type=Path, required=True)
    materialize.add_argument("--state-dir", type=Path, required=True)
    materialize.set_defaults(handler=command_materialize)

    finalize = subparsers.add_parser("finalize")
    finalize.add_argument("--build-root", type=Path, required=True)
    finalize.add_argument("--authority-root", type=Path, required=True)
    finalize.add_argument("--state-dir", type=Path, required=True)
    finalize.set_defaults(handler=command_finalize)

    verify = subparsers.add_parser("verify")
    verify.add_argument("--release-dir", type=Path, required=True)
    verify.add_argument("--expected-archive-sha256")
    verify.add_argument("--extract-to", type=Path)
    verify.set_defaults(handler=command_verify)

    compare = subparsers.add_parser("compare")
    compare.add_argument("first", type=Path)
    compare.add_argument("second", type=Path)
    compare.set_defaults(handler=command_compare)

    compare_environments = subparsers.add_parser("compare-environments")
    compare_environments.add_argument("staging", type=Path)
    compare_environments.add_argument("production", type=Path)
    compare_environments.add_argument(
        "--contract",
        type=Path,
        default=Path("config/web/environment-delta-contract.v1.json"),
    )
    compare_environments.add_argument("--output", type=Path)
    compare_environments.set_defaults(handler=command_compare_environments)
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    parser = build_parser()
    arguments = parser.parse_args(argv)
    try:
        arguments.handler(arguments)
    except (ReleaseInputError, subprocess.CalledProcessError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
