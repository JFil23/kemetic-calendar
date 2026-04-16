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

Validate release identity and Firebase/deep-link alignment before submission:

```bash
cd mobile
scripts/verify_release_config.sh
```

Validate mobile deep-link entrypoints on a simulator/device:

```bash
cd mobile
scripts/validate_deep_links.sh android
scripts/validate_deep_links.sh ios
```

## Release builds

Use the shared dart-define files so mobile builds receive the expected Supabase and app configuration:

```bash
cd mobile
flutter build apk --release --dart-define-from-file=env/prod.json
flutter build ipa --dart-define-from-file=env/prod.json
```

The iOS helper script wraps the same production defines:

```bash
cd mobile
scripts/build_ios_release.sh
```

Android release signing uses `android/key.properties` when present and falls back to debug signing for local release builds. Start from:

```bash
cd mobile
cp android/key.properties.example android/key.properties
```

The `storeFile` value in `android/key.properties` should point to your local upload keystore path.

## iOS Firebase

- Place the real Firebase config at `ios/config/GoogleService-Info.plist` locally.
- `scripts/ensure_ios_firebase.sh` copies it into `ios/Runner/` for Flutter builds.
- Keep Debug and Release entitlements aligned with your APNs environment.

## Android Firebase

- Keep `android/app/google-services.json` aligned with the final Android `applicationId`.
- Do not ship the placeholder `com.example.mobile` Firebase client.

## Notes

- Keep `kemet.app://login-callback` allowlisted in Supabase auth redirects.
- Keep `maat.app/.well-known/assetlinks.json` and `maat.app/.well-known/apple-app-site-association` live for Android App Links and iOS Universal Links.
- Commit example env files only; keep real env JSON files and production secrets out of git.
