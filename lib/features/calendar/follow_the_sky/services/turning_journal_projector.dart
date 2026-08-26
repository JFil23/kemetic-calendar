import '../../maat_flow_response_journal_blocks.dart';
import '../domain/turning_record.dart';

class TurningJournalProjector {
  const TurningJournalProjector();

  String sourceIdFor(String clientEventId) =>
      'follow-sky-turning:${clientEventId.trim()}';

  MaatJournalResponseBlock project({
    required TurningRecord record,
    required DateTime localDate,
  }) {
    return MaatJournalResponseBlock(
      sourceId: sourceIdFor(record.clientEventId),
      text: record.reflectionText,
      localDate: localDate,
      sourceMetadata: <String, dynamic>{
        'kind': 'follow_sky_turning',
        'turning_record_id': record.id,
        'client_event_id': record.clientEventId,
        'sky_event_id': record.skyEventId,
        'intention_snapshot': record.intentionSnapshot,
        'scheduled_time_snapshot': record.scheduledTimeSnapshot
            .toUtc()
            .toIso8601String(),
        if (record.photoObjectPath != null)
          'photo_object_path': record.photoObjectPath,
        if (record.completion != null)
          'completion': record.completion!.wireName,
        'last_edited_at': record.lastEditedAt.toUtc().toIso8601String(),
      },
    );
  }
}
