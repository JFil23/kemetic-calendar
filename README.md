# Kemetic Calendar (Flutter)

A lightweight Flutter app that shows today in the **Ancient Kemetic (Egyptian) calendar** and a simple month view. It converts between Gregorian and Kemetic dates, highlights the current day, and lets you add sample events (local, in-memory) for any Kemetic day.

## ✨ Features

- Kemetic ↔︎ Gregorian conversion (with seasons & epagomenal days)
- Clean month grid (30-day months, 7 columns)
- Tap a day to add a **sample local event** (stored in memory)
- State management with **provider**
- Unit tests for the converter

## 📱 Screenshots
_(add later)_

## 🧱 Tech

- Flutter & Dart
- `provider` for app state
- `intl` for formatting

## 📦 Project structure

lib/
├─ core/
│ └─ kemetic_converter.dart # Date math & models
├─ data/
│ ├─ models.dart # Event model
│ └─ local_events_repo.dart # In-memory events + provider
├─ features/
│ └─ calendar/
│ └─ calendar_page.dart # Month grid UI
└─ main.dart # App entry; wires Provider + CalendarPage

## 🚀 Running with env defines

Use the shared env file (`env/dev.json`) so Android/iOS/web all receive the same dart-defines:

```bash
cd mobile
scripts/run_dev.sh            # auto-picks a device
scripts/run_ios.sh            # force iOS (first connected)
scripts/run_android.sh        # force Android (first connected)
```

Quick sanity check your env:

```bash
cd mobile
scripts/verify_env.sh                 # checks env/dev.json
scripts/verify_env.sh env/prod.json   # checks another env file
```

For release builds (App Store/TestFlight), use the single canonical command so Supabase defines are always present:

```bash
cd mobile
flutter build ipa --dart-define-from-file=env/prod.json
# or use the guard script (wraps the same defines):
scripts/build_ios_release.sh
```

If you archive in Xcode, add a Run Script to export the same dart-defines from `env/prod.json` so behavior matches the Flutter CLI build.

Keep real secrets out of git: commit `env/dev.example.json` / `env/prod.example.json`, and maintain the real files locally.

**If you press ▶ in Xcode directly, dart-defines may be bypassed. Prefer these scripts or Flutter CLI to keep env consistent.**

Auth redirect scheme: keep `kemet.app://login-callback` allowlisted in Supabase; do not change schemes without updating the allowlist.

Note on environments: if dev/prod currently point to the same Supabase project, that’s fine—document it in your local env files. When you add a dedicated prod project later, these scripts already support separate env JSONs.
## 🚀 Running with env defines

Use the shared env file (`env/dev.json`) so Android/iOS/web all receive the same dart-defines:

```bash
cd mobile
scripts/run_dev.sh            # auto-picks a device
scripts/run_dev.sh <device>   # target a specific device from `flutter devices`
```

`run_dev.sh` wraps `--dart-define-from-file=env/dev.json`, so IDE/Xcode runs stay consistent with CLI.
