import 'package:mobile/core/calendar_occurrence_identity.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CalendarOccurrenceExclusionsRepo {
  const CalendarOccurrenceExclusionsRepo(this._client);

  final SupabaseClient _client;

  Future<Set<CalendarOccurrenceIdentity>> listMine() async {
    final userId = _client.auth.currentUser?.id.trim();
    if (userId == null || userId.isEmpty) {
      return const <CalendarOccurrenceIdentity>{};
    }
    final rows = await _client
        .from('calendar_occurrence_exclusions')
        .select('occurrence_kind, source_id, occurrence_local_date')
        .eq('user_id', userId);

    final identities = <CalendarOccurrenceIdentity>{};
    for (final raw in rows as List<dynamic>) {
      final row = Map<String, dynamic>.from(raw as Map);
      if (row['occurrence_kind']?.toString() != 'reminder') continue;
      final sourceId = row['source_id']?.toString().trim() ?? '';
      final localDate = tryParseCalendarOccurrenceLocalDate(
        row['occurrence_local_date']?.toString() ?? '',
      );
      if (sourceId.isEmpty || localDate == null) continue;
      identities.add(
        CalendarOccurrenceIdentity.reminder(
          reminderId: sourceId,
          localDate: localDate,
        ),
      );
    }
    return identities;
  }

  Future<void> exclude(CalendarOccurrenceIdentity identity) async {
    final userId = _client.auth.currentUser?.id.trim();
    if (userId == null || userId.isEmpty) {
      throw StateError('Authentication is required to exclude an occurrence.');
    }
    await _client.from('calendar_occurrence_exclusions').upsert({
      'user_id': userId,
      'occurrence_kind': identity.kind.name,
      'source_id': identity.sourceId,
      'occurrence_local_date': identity.localDateKey,
      'reason': 'user_deleted',
    }, onConflict: 'user_id,occurrence_kind,source_id,occurrence_local_date');
  }
}
