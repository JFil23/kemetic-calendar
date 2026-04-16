#!/usr/bin/env bash
set -euo pipefail

# Verifies release-facing Android/iOS identity and deep-link config alignment.
# Usage:
#   scripts/verify_release_config.sh

cd "$(dirname "$0")/.."

python3 - <<'PY'
import json
import plistlib
import re
import sys
from pathlib import Path

ROOT = Path(".")
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


def extract_url_schemes(info_plist: dict) -> set[str]:
    schemes: set[str] = set()
    for item in info_plist.get("CFBundleURLTypes", []):
        for scheme in item.get("CFBundleURLSchemes", []):
            if isinstance(scheme, str) and scheme:
                schemes.add(scheme)
    return schemes


def normalize_set(values: set[str]) -> str:
    return ", ".join(sorted(values))


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

if not (ROOT / "android/key.properties").exists():
    warnings.append(
        "android/key.properties is missing; release builds will fall back to debug signing locally"
    )
else:
    notes.append("android/key.properties present")

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
