// lib/data/models.dart

class Event {
  final String id;
  final String ownerId;
  final String title;
  final String? notes;
  final bool allDay;

  // Canonical storage: UTC instants
  final DateTime startUtc;
  final DateTime endUtc;
  final String timeZone;

  // Denormalized Kemetic fields for fast queries
  final int kYear;
  final int kMonth; // 1..12, or 0 for epagomenal
  final int kDay;
  final bool isEpagomenal;
  final String? kSeason; // Akhet/Peret/Shemu

  const Event({
    required this.id,
    required this.ownerId,
    required this.title,
    this.notes,
    required this.allDay,
    required this.startUtc,
    required this.endUtc,
    required this.timeZone,
    required this.kYear,
    required this.kMonth,
    required this.kDay,
    required this.isEpagomenal,
    required this.kSeason,
  });

  Map<String, dynamic> toMap() => {
    'ownerId': ownerId,
    'title': title,
    'notes': notes,
    'allDay': allDay,
    'startUtc': startUtc.toUtc(),
    'endUtc': endUtc.toUtc(),
    'timeZone': timeZone,
    'kYear': kYear,
    'kMonth': kMonth,
    'kDay': kDay,
    'isEpagomenal': isEpagomenal,
    'kSeason': kSeason,
  };

  factory Event.fromMap(String id, Map<String, dynamic> m) => Event(
    id: id,
    ownerId: m['ownerId'] as String,
    title: m['title'] as String,
    notes: m['notes'] as String?,
    allDay: (m['allDay'] as bool?) ?? false,
    startUtc: DateTime.parse(m['startUtc'].toString()).toUtc(),
    endUtc: DateTime.parse(m['endUtc'].toString()).toUtc(),
    timeZone: (m['timeZone'] as String?) ?? 'UTC',
    kYear: m['kYear'] as int,
    kMonth: m['kMonth'] as int,
    kDay: m['kDay'] as int,
    isEpagomenal: (m['isEpagomenal'] as bool?) ?? false,
    kSeason: m['kSeason'] as String?,
  );
}
