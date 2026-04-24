# Kemetic Calendar

Flutter mobile app for Kemetic date-based planning, recurring flows, journaling, sharing, reminders, and calendar import.

## Core capabilities

- Kemetic and Gregorian calendar views
- Flow creation, scheduling, and imported/shared flow support
- Inbox and profile-driven sharing flows
- Journal and nutrition workflows
- Local notifications, push, and ICS import

## Local development

```bash
cd mobile
scripts/run_dev.sh
```

Target a specific device:

```bash
cd mobile
scripts/run_dev.sh <device>
```

Validate env files before running or building:

```bash
cd mobile
scripts/verify_env.sh
scripts/verify_env.sh env/prod.json
```

For web/Cloudflare builds, `scripts/build_web_release.sh` will accept either:

- `SUPABASE_URL` and `SUPABASE_ANON_KEY` from the shell/CI environment, or
- a JSON env file passed as the first argument, such as `env/prod.json`

It also writes the final runtime `env.json`, `_headers`, `_redirects`, and `.well-known` files into `build/web`.

Validate release identity and Firebase/deep-link alignment before submission:

```bash
cd mobile
scripts/verify_release_config.sh
scripts/verify_release_config.sh --strict-signing
```

Validate mobile deep-link entrypoints on a simulator/device:

```bash
cd mobile
scripts/validate_deep_links.sh android
scripts/validate_deep_links.sh ios
```

## Release builds

Use the guarded helper scripts so release builds receive the expected Supabase
config and reject placeholder identity/signing before producing store artifacts:

```bash
cd mobile
scripts/build_android_release.sh
scripts/build_ios_release.sh
scripts/build_web_release.sh env/prod.json
```

If you need raw Flutter commands for ad hoc testing, keep in mind:

- `flutter build appbundle --release --dart-define-from-file=env/prod.json` is the Android store artifact.
- `flutter build apk ...` is for side-loading, not Play Store submission.

The iOS helper script wraps the same production defines and synchronizes the
Firebase plist before building:

```bash
cd mobile
scripts/build_ios_release.sh
```

Android release signing uses `android/key.properties`. The guarded Android
release helper refuses to build when the keystore file is missing, still uses
example values, or points at a missing keystore. Start from:

```bash
cd mobile
cp android/key.properties.example android/key.properties
```

The `storeFile` value in `android/key.properties` should point to your local
upload keystore path.

## iOS Firebase

- Place the real Firebase config at `ios/config/GoogleService-Info.plist` locally.
- `scripts/ensure_ios_firebase.sh` copies it into `ios/Runner/` for Flutter builds.
- Keep Debug and Release entitlements aligned with your APNs environment.

## Android Firebase

- Keep `android/app/google-services.json` aligned with the final Android `applicationId`.
- Do not ship the placeholder `com.example.mobile` Firebase client.
- Keep `web/.well-known/assetlinks.json` aligned with the Android `applicationId` and release keystore SHA-256 fingerprint.

## Notes

- Keep `kemet.app://login-callback` allowlisted in Supabase auth redirects.
- Keep `maat.app/.well-known/assetlinks.json` and `maat.app/.well-known/apple-app-site-association` live for Android App Links and iOS Universal Links.
- `scripts/deploy_cloudflare_pages.sh` can direct-upload `build/web` to Cloudflare Pages with `CLOUDFLARE_PAGES_PROJECT=<project>`.
- Cloudflare Pages builds need `SUPABASE_URL` and `SUPABASE_ANON_KEY` configured in the build environment if you are not providing an env JSON file locally.
- Commit example env files only; keep real env JSON files and production secrets out of git.
