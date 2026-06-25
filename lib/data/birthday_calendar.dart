import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const String kBirthdaysSystemType = 'birthdays';
const String kBirthdaysCalendarName = 'Birthdays';
const int kBirthdaysCalendarColorValue = 0xFF21D6B5;
const int kBirthdayNoAlertMinutes = -1;
const int kBirthdayOnDayAlertMinutes = 0;
const int kBirthdayOneDayBeforeAlertMinutes = 1440;
const int kBirthdayOneWeekBeforeAlertMinutes = 10080;

const List<int> kBirthdayAlertOptions = <int>[
  kBirthdayNoAlertMinutes,
  kBirthdayOnDayAlertMinutes,
  kBirthdayOneDayBeforeAlertMinutes,
  kBirthdayOneWeekBeforeAlertMinutes,
];

String birthdayAlertLabel(int offsetMinutes) {
  switch (offsetMinutes) {
    case kBirthdayNoAlertMinutes:
      return 'No alert';
    case kBirthdayOnDayAlertMinutes:
      return 'On the day';
    case kBirthdayOneDayBeforeAlertMinutes:
      return '1 day before';
    case kBirthdayOneWeekBeforeAlertMinutes:
      return '1 week before';
    default:
      if (offsetMinutes <= 0) return 'On the day';
      final days = offsetMinutes ~/ 1440;
      if (days > 0 && offsetMinutes % 1440 == 0) {
        return days == 1 ? '1 day before' : '$days days before';
      }
      return '$offsetMinutes minutes before';
  }
}

@immutable
class BirthdayItem {
  const BirthdayItem({
    required this.id,
    required this.userId,
    required this.calendarId,
    required this.name,
    required this.month,
    required this.day,
    required this.alertOffsetMinutes,
    this.birthYear,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String calendarId;
  final String name;
  final int month;
  final int day;
  final int? birthYear;
  final int alertOffsetMinutes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory BirthdayItem.fromRow(Map<String, dynamic> row) {
    return BirthdayItem(
      id: (row['id'] as String?) ?? '',
      userId: (row['user_id'] as String?) ?? '',
      calendarId: (row['calendar_id'] as String?) ?? '',
      name: ((row['name'] as String?) ?? '').trim(),
      month: (row['month'] as num?)?.toInt() ?? 1,
      day: (row['day'] as num?)?.toInt() ?? 1,
      birthYear: (row['birth_year'] as num?)?.toInt(),
      alertOffsetMinutes:
          (row['alert_offset_minutes'] as num?)?.toInt() ??
          kBirthdayNoAlertMinutes,
      createdAt: _dateTimeOrNull(row['created_at']),
      updatedAt: _dateTimeOrNull(row['updated_at']),
    );
  }
}

@immutable
class BirthdayOccurrence {
  const BirthdayOccurrence({required this.item, required this.year});

  final BirthdayItem item;
  final int year;

  DateTime get localDate =>
      birthdayOccurrenceDate(year: year, month: item.month, day: item.day);

  DateTime get localStart =>
      DateTime(localDate.year, localDate.month, localDate.day, 9);

  DateTime get startsAtUtc => localStart.toUtc();

  String get clientEventId => birthdayClientEventId(item.id, year);

  String get title {
    final cleanName = item.name.trim();
    if (cleanName.isEmpty) return 'Birthday';
    return "$cleanName's birthday";
  }

  String? get detail {
    return 'alert=${item.alertOffsetMinutes};';
  }

  Map<String, dynamic> get behaviorPayload {
    return <String, dynamic>{
      'kind': 'birthday',
      'birthday_id': item.id,
      'name': item.name,
      'month': item.month,
      'day': item.day,
      if (item.birthYear != null) 'birth_year': item.birthYear,
      'occurrence_year': year,
      'alert_offset_minutes': item.alertOffsetMinutes,
    };
  }

  Map<String, dynamic> toStandaloneEventRow() {
    return <String, dynamic>{
      'id': clientEventId,
      'user_id': item.userId,
      'client_event_id': clientEventId,
      'calendar_id': item.calendarId,
      'calendar_name': kBirthdaysCalendarName,
      'calendar_color': kBirthdaysCalendarColorValue,
      'calendar_is_personal': false,
      'title': title,
      'detail': detail,
      'location': null,
      'all_day': true,
      'starts_at': startsAtUtc.toIso8601String(),
      'ends_at': null,
      'flow_local_id': null,
      'category': 'birthday',
      'action_id': null,
      'behavior_payload': behaviorPayload,
      'updated_at': (item.updatedAt ?? item.createdAt ?? DateTime.now().toUtc())
          .toIso8601String(),
      'created_at': (item.createdAt ?? DateTime.now().toUtc())
          .toIso8601String(),
    };
  }

  Map<String, dynamic> toFilingBackendRow() {
    final base = toStandaloneEventRow();
    return <String, dynamic>{
      ...base,
      'filed_flow_id': null,
      'flow_active': null,
      'flow_is_hidden': null,
      'flow_is_reminder': null,
      'flow_is_saved': null,
      'flow_notes': null,
      'user_timezone': 'UTC',
      'active_until': localStart.add(const Duration(days: 1)).toUtc(),
      'date_lifecycle': 'active',
      'has_event_share': false,
      'has_flow_share': false,
      'has_flow_post': false,
      'has_active_reminder': false,
      'has_scheduled_notification':
          item.alertOffsetMinutes != kBirthdayNoAlertMinutes,
      'reason_item_kind': 'birthday_record',
      'reason_deleted': null,
      'reason_active_until': 'birthday_all_day',
      'item_kind': 'note',
      'is_deleted': false,
      'is_saved': false,
      'is_shared_calendar_source': true,
      'is_event_share_source': false,
      'is_flow_share_source': false,
      'is_flow_post_source': false,
      'is_flow_saved_source': false,
      'is_active_reminder_source': false,
      'is_scheduled_notification_source':
          item.alertOffsetMinutes != kBirthdayNoAlertMinutes,
      'lifecycle': 'active',
      'live_on_calendar': true,
      'is_shared': true,
      'is_posted': false,
      'filing_reasons': <String, dynamic>{
        'item_kind': <String, dynamic>{
          'value': 'note',
          'reason': 'birthday_record',
        },
        'lifecycle': <String, dynamic>{
          'value': 'active',
          'date_lifecycle': 'active',
          'active_until': localStart
              .add(const Duration(days: 1))
              .toUtc()
              .toIso8601String(),
          'active_until_reason': 'birthday_all_day',
          'timezone': 'UTC',
        },
        'calendar': <String, dynamic>{
          'calendar_id': item.calendarId,
          'calendar_name': kBirthdaysCalendarName,
          'calendar_is_personal': false,
          'live_on_calendar': true,
        },
        'birthday': behaviorPayload,
      },
    };
  }
}

class BirthdayCalendarRepo {
  BirthdayCalendarRepo(this._client);

  final SupabaseClient _client;

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[BirthdayCalendarRepo] $message');
    }
  }

  Future<String?> ensureBirthdaysCalendar() async {
    try {
      final response = await _client.rpc('ensure_birthdays_calendar_for_user');
      if (response is String && response.trim().isNotEmpty) {
        return response.trim();
      }
      return null;
    } catch (e) {
      _log('ensureBirthdaysCalendar failed: $e');
      return null;
    }
  }

  Future<String> createBirthday({
    required String name,
    required DateTime birthday,
    required int alertOffsetMinutes,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Must not be empty.');
    }
    final response = await _client.rpc(
      'create_birthday_item',
      params: <String, dynamic>{
        'p_name': trimmed,
        'p_month': birthday.month,
        'p_day': birthday.day,
        'p_birth_year': birthday.year,
        'p_alert_offset_minutes': alertOffsetMinutes,
      },
    );
    if (response is String && response.trim().isNotEmpty) {
      return response.trim();
    }
    throw StateError('Birthday was created but no id was returned.');
  }

  Future<List<BirthdayItem>> getBirthdays({String? calendarId}) async {
    final user = _client.auth.currentUser;
    if (user == null) return const <BirthdayItem>[];

    try {
      var query = _client
          .from('birthday_items')
          .select(
            'id,user_id,calendar_id,name,month,day,birth_year,'
            'alert_offset_minutes,created_at,updated_at',
          )
          .eq('user_id', user.id)
          .isFilter('deleted_at', null);
      final trimmedCalendarId = calendarId?.trim();
      if (trimmedCalendarId != null && trimmedCalendarId.isNotEmpty) {
        query = query.eq('calendar_id', trimmedCalendarId);
      }
      final rows = await query
          .order('month', ascending: true)
          .order('day', ascending: true)
          .order('name', ascending: true);
      return (rows as List)
          .whereType<Map>()
          .map((row) => BirthdayItem.fromRow(row.cast<String, dynamic>()))
          .where(
            (item) =>
                item.id.isNotEmpty &&
                item.userId.isNotEmpty &&
                item.calendarId.isNotEmpty &&
                item.name.isNotEmpty,
          )
          .toList(growable: false);
    } catch (e) {
      _log('getBirthdays failed: $e');
      return const <BirthdayItem>[];
    }
  }

  Future<List<BirthdayOccurrence>> getOccurrencesForRange({
    required DateTime startUtc,
    required DateTime endUtc,
    String? calendarId,
  }) async {
    final items = await getBirthdays(calendarId: calendarId);
    return expandBirthdayOccurrences(
      items: items,
      startUtc: startUtc,
      endUtc: endUtc,
    );
  }

  Future<List<BirthdayOccurrence>> getUpcomingOccurrences({
    String? calendarId,
    DateTime? startsOnOrAfterUtc,
    int yearsAhead = 10,
  }) async {
    final startLocal = (startsOnOrAfterUtc ?? DateTime.now().toUtc()).toLocal();
    final start = DateTime(
      startLocal.year,
      startLocal.month,
      startLocal.day,
    ).toUtc();
    final end = DateTime(startLocal.year + yearsAhead + 1, 1, 1).toUtc();
    return getOccurrencesForRange(
      startUtc: start,
      endUtc: end,
      calendarId: calendarId,
    );
  }
}

DateTime? _dateTimeOrNull(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value.toUtc();
  final raw = value.toString().trim();
  if (raw.isEmpty) return null;
  return DateTime.tryParse(raw)?.toUtc();
}

bool isLeapGregorianYear(int year) {
  return (year % 4 == 0) && (year % 100 != 0 || year % 400 == 0);
}

DateTime birthdayOccurrenceDate({
  required int year,
  required int month,
  required int day,
}) {
  if (month == 2 && day == 29 && !isLeapGregorianYear(year)) {
    return DateTime(year, 2, 28);
  }
  final maxDay = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, day.clamp(1, maxDay).toInt());
}

String birthdayClientEventId(String birthdayId, int occurrenceYear) {
  return 'birthday:$birthdayId:$occurrenceYear';
}

List<BirthdayOccurrence> expandBirthdayOccurrences({
  required Iterable<BirthdayItem> items,
  required DateTime startUtc,
  required DateTime endUtc,
}) {
  if (!endUtc.isAfter(startUtc)) return const <BirthdayOccurrence>[];

  final startLocal = startUtc.toLocal();
  final endLocal = endUtc.toLocal();
  final startYear = startLocal.year - 1;
  final endYear = endLocal.year + 1;
  final occurrences = <BirthdayOccurrence>[];

  for (final item in items) {
    if (item.month < 1 || item.month > 12 || item.day < 1 || item.day > 31) {
      continue;
    }
    for (var year = startYear; year <= endYear; year++) {
      final occurrence = BirthdayOccurrence(item: item, year: year);
      final startsAt = occurrence.startsAtUtc;
      if (!startsAt.isBefore(startUtc) && startsAt.isBefore(endUtc)) {
        occurrences.add(occurrence);
      }
    }
  }

  occurrences.sort((a, b) {
    final byStart = a.startsAtUtc.compareTo(b.startsAtUtc);
    if (byStart != 0) return byStart;
    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  });
  return List<BirthdayOccurrence>.unmodifiable(occurrences);
}

BirthdayOccurrence? nextBirthdayOccurrence({
  required BirthdayItem item,
  DateTime? now,
}) {
  final localNow = (now ?? DateTime.now()).toLocal();
  for (var year = localNow.year; year <= localNow.year + 2; year++) {
    final occurrence = BirthdayOccurrence(item: item, year: year);
    if (occurrence.localStart.isAfter(localNow)) {
      return occurrence;
    }
  }
  return null;
}

String birthdayNotificationPayloadJson(BirthdayOccurrence occurrence) {
  final date = occurrence.localDate;
  return jsonEncode(<String, dynamic>{
    'kind': 'calendar_event',
    'item_type': 'note',
    'calendar_id': occurrence.item.calendarId,
    'event_id': occurrence.clientEventId,
    'client_event_id': occurrence.clientEventId,
    'birthday_id': occurrence.item.id,
    'local_date': [
      date.year.toString().padLeft(4, '0'),
      date.month.toString().padLeft(2, '0'),
      date.day.toString().padLeft(2, '0'),
    ].join('-'),
  });
}
