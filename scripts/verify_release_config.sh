#!/usr/bin/env bash
set -euo pipefail

# Verifies release-facing Android/iOS identity and deep-link config alignment.
# Usage:
#   scripts/verify_release_config.sh
#   scripts/verify_release_config.sh --strict-signing

cd "$(dirname "$0")/.."

STRICT_SIGNING=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --strict-signing)
      STRICT_SIGNING=1
      ;;
    -h|--help)
      cat <<'EOF'
Usage: scripts/verify_release_config.sh [--strict-signing]

Checks Android/iOS release identity, Firebase alignment, and deep-link config.
Use --strict-signing for store-readiness checks that must reject missing or
placeholder Android signing material.
EOF
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 2
      ;;
  esac
  shift
done

python3 - "$STRICT_SIGNING" <<'PY'
import json
import plistlib
import re
import sys
from pathlib import Path

ROOT = Path(".")
STRICT_SIGNING = sys.argv[1] == "1"
errors: list[str] = []
warnings: list[str] = []
notes: list[str] = []


def read_text(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def find_required(pattern: str, text: str, label: str) -> str:
    match = re.search(pattern, text, re.MULTILINE)
    if not match:
        errors.append(f"Could not find {label}")
        return ""
    return match.group(1)


def load_plist(path: str) -> dict:
    with (ROOT / path).open("rb") as handle:
        return plistlib.load(handle)


def load_properties(path: str) -> dict[str, str]:
    props: dict[str, str] = {}
    for raw_line in read_text(path).splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if "=" not in line:
            continue
        key, value = line.split("=", 1)
        props[key.strip()] = value.strip()
    return props


def extract_url_schemes(info_plist: dict) -> set[str]:
    schemes: set[str] = set()
    for item in info_plist.get("CFBundleURLTypes", []):
        for scheme in item.get("CFBundleURLSchemes", []):
            if isinstance(scheme, str) and scheme:
                schemes.add(scheme)
    return schemes


def normalize_set(values: set[str]) -> str:
    return ", ".join(sorted(values))


def add_problem(message: str, *, strict: bool = False) -> None:
    if strict:
        errors.append(message)
    else:
        warnings.append(message)


build_gradle = read_text("android/app/build.gradle.kts")
android_namespace = find_required(
    r'namespace\s*=\s*"([^"]+)"', build_gradle, "Android namespace"
)
android_app_id = find_required(
    r'applicationId\s*=\s*"([^"]+)"', build_gradle, "Android applicationId"
)

manifest = read_text("android/app/src/main/AndroidManifest.xml")
android_manifest_package = find_required(
    r'package="([^"]+)"', manifest, "Android manifest package"
)

main_activity_paths = sorted(
    (ROOT / "android/app/src/main/kotlin").rglob("MainActivity.kt")
)
if not main_activity_paths:
    errors.append("Could not find Android MainActivity.kt")
    android_main_package = ""
else:
    android_main_package = find_required(
        r"^package\s+([^\s]+)",
        main_activity_paths[0].read_text(encoding="utf-8"),
        "Android MainActivity package",
    )

google_services = json.loads(read_text("android/app/google-services.json"))
android_firebase_packages = {
    client["client_info"]["android_client_info"]["package_name"]
    for client in google_services.get("client", [])
    if client.get("client_info", {}).get("android_client_info", {}).get("package_name")
}

if android_app_id == "com.example.mobile":
    errors.append("Android applicationId is still the placeholder com.example.mobile")

if android_manifest_package == "com.example.mobile":
    errors.append("Android manifest package is still the placeholder com.example.mobile")

if android_main_package == "com.example.mobile":
    errors.append("Android MainActivity package is still the placeholder com.example.mobile")

if android_app_id != android_manifest_package:
    errors.append(
        f"Android applicationId ({android_app_id}) does not match manifest package ({android_manifest_package})"
    )

if android_manifest_package and android_main_package and android_manifest_package != android_main_package:
    errors.append(
        f"Android manifest package ({android_manifest_package}) does not match MainActivity package ({android_main_package})"
    )

if android_namespace and android_namespace != android_manifest_package:
    warnings.append(
        f"Android namespace ({android_namespace}) differs from manifest package ({android_manifest_package})"
    )

if android_app_id not in android_firebase_packages:
    errors.append(
        "android/app/google-services.json does not contain a Firebase client for "
        f"{android_app_id} (found: {normalize_set(android_firebase_packages) or 'none'})"
    )

key_properties_path = ROOT / "android/key.properties"
if not key_properties_path.exists():
    add_problem(
        "android/key.properties is missing; release builds will fall back to debug signing locally",
        strict=STRICT_SIGNING,
    )
else:
    notes.append("android/key.properties present")
    key_properties = load_properties("android/key.properties")
    missing_keys = {
        key
        for key in ("storePassword", "keyPassword", "keyAlias", "storeFile")
        if not key_properties.get(key)
    }
    if missing_keys:
        add_problem(
            "android/key.properties is missing required keys: "
            f"{normalize_set(missing_keys)}",
            strict=STRICT_SIGNING,
        )
    store_password = key_properties.get("storePassword", "")
    key_password = key_properties.get("keyPassword", "")
    store_file = key_properties.get("storeFile", "")
    if store_password == "change-me" or key_password == "change-me":
        add_problem(
            "android/key.properties still contains example password values",
            strict=STRICT_SIGNING,
        )
    if store_file == "/absolute/path/to/upload-keystore.jks":
        add_problem(
            "android/key.properties still contains the example storeFile path",
            strict=STRICT_SIGNING,
        )
    elif store_file:
        store_file_path = Path(store_file).expanduser()
        if not store_file_path.is_absolute():
            add_problem(
                "android/key.properties storeFile must be an absolute path",
                strict=STRICT_SIGNING,
            )
        elif not store_file_path.exists():
            add_problem(
                f"android/key.properties storeFile does not exist: {store_file_path}",
                strict=STRICT_SIGNING,
            )

project = read_text("ios/Runner.xcodeproj/project.pbxproj")
ios_bundle_ids = {
    match
    for match in re.findall(r"PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);", project)
    if ".RunnerTests" not in match
}
if not ios_bundle_ids:
    errors.append("Could not find iOS app bundle identifier in Xcode project")
    ios_bundle_id = ""
elif len(ios_bundle_ids) > 1:
    errors.append(
        "Multiple iOS app bundle identifiers found in Xcode project: "
        f"{normalize_set(ios_bundle_ids)}"
    )
    ios_bundle_id = sorted(ios_bundle_ids)[0]
else:
    ios_bundle_id = next(iter(ios_bundle_ids))

ios_teams = {
    match
    for match in re.findall(r"DEVELOPMENT_TEAM = ([^;]+);", project)
    if match and ".RunnerTests" not in match
}
if not ios_teams:
    warnings.append("Could not find iOS DEVELOPMENT_TEAM in Xcode project")
    ios_team = ""
elif len(ios_teams) > 1:
    warnings.append(
        "Multiple iOS DEVELOPMENT_TEAM values found in Xcode project: "
        f"{normalize_set(ios_teams)}"
    )
    ios_team = sorted(ios_teams)[0]
else:
    ios_team = next(iter(ios_teams))

for plist_path in (
    "ios/config/GoogleService-Info.plist",
    "ios/Runner/GoogleService-Info.plist",
):
    plist_file = ROOT / plist_path
    if not plist_file.exists():
        warnings.append(f"{plist_path} is missing")
        continue
    bundle_id = load_plist(plist_path).get("BUNDLE_ID", "")
    if ios_bundle_id and bundle_id != ios_bundle_id:
        errors.append(
            f"{plist_path} BUNDLE_ID ({bundle_id}) does not match iOS app bundle identifier ({ios_bundle_id})"
        )

info_plist = load_plist("ios/Runner/Info.plist")
url_schemes = extract_url_schemes(info_plist)
for required_scheme in ("kemet.app", "maat"):
    if required_scheme not in url_schemes:
        errors.append(f"iOS URL scheme {required_scheme} is missing from Info.plist")

for usage_key in ("NSCalendarsUsageDescription", "NSPhotoLibraryUsageDescription"):
    value = info_plist.get(usage_key, "")
    if not isinstance(value, str) or not value.strip():
        errors.append(f"iOS Info.plist is missing {usage_key}")

app_icon_1024 = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png"
if not app_icon_1024.exists():
    errors.append("iOS App Store icon is missing: ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png")

aasa_path = ROOT / "web/.well-known/apple-app-site-association"
if not aasa_path.exists():
    warnings.append("web/.well-known/apple-app-site-association is missing")
else:
    aasa = json.loads(read_text("web/.well-known/apple-app-site-association"))
    expected_app_id = f"{ios_team}.{ios_bundle_id}" if ios_team and ios_bundle_id else ""
    aasa_app_ids = {
        detail.get("appID", "")
        for detail in aasa.get("applinks", {}).get("details", [])
        if isinstance(detail, dict)
    }
    if expected_app_id and expected_app_id not in aasa_app_ids:
        errors.append(
            "web/.well-known/apple-app-site-association does not include appID "
            f"{expected_app_id} (found: {normalize_set({app_id for app_id in aasa_app_ids if app_id}) or 'none'})"
        )

assetlinks_path = ROOT / "web/.well-known/assetlinks.json"
if not assetlinks_path.exists():
    add_problem(
        "web/.well-known/assetlinks.json is missing; Android App Links cannot verify",
        strict=STRICT_SIGNING,
    )
else:
    assetlinks = json.loads(read_text("web/.well-known/assetlinks.json"))
    assetlinks_packages = {
        entry.get("target", {}).get("package_name", "")
        for entry in assetlinks
        if isinstance(entry, dict)
    }
    if android_app_id and android_app_id not in assetlinks_packages:
        errors.append(
            "web/.well-known/assetlinks.json does not include Android package "
            f"{android_app_id} (found: {normalize_set({pkg for pkg in assetlinks_packages if pkg}) or 'none'})"
        )

required_domains = {"applinks:maat.app", "applinks:www.maat.app"}
for entitlements_path in (
    "ios/Runner/RunnerDebug.entitlements",
    "ios/Runner/RunnerRelease.entitlements",
):
    entitlements = load_plist(entitlements_path)
    domains = set(entitlements.get("com.apple.developer.associated-domains", []))
    missing = required_domains - domains
    if missing:
        errors.append(
            f"{entitlements_path} is missing associated domains: {normalize_set(missing)}"
        )

print("Release Config Summary")
print(f"- Android namespace: {android_namespace}")
print(f"- Android applicationId: {android_app_id}")
print(f"- Android manifest package: {android_manifest_package}")
print(f"- Android MainActivity package: {android_main_package}")
print(
    f"- Android Firebase packages: {normalize_set(android_firebase_packages) or 'none'}"
)
print(f"- iOS app bundle identifier: {ios_bundle_id}")
print(f"- iOS URL schemes: {normalize_set(url_schemes)}")
print(f"- Strict signing: {'on' if STRICT_SIGNING else 'off'}")

if notes:
    print("\nNotes:")
    for note in notes:
        print(f"- {note}")

if warnings:
    print("\nWarnings:")
    for warning in warnings:
        print(f"- {warning}")

if errors:
    print("\nErrors:", file=sys.stderr)
    for error in errors:
        print(f"- {error}", file=sys.stderr)
    sys.exit(1)

print("\n✅ Release config looks aligned.")
PY
