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
