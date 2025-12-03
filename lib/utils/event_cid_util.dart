// lib/utils/event_cid_util.dart
// Shared utility for building client event IDs
// Used by both inbox import flow and existing flow scheduling

class EventCidUtil {
  /// Build a canonical clientEventId from Kemetic date, title, time and flow id.
  /// 
  /// This helper ensures that every note uses the same format when being persisted
  /// and deleted. The start time is converted to minutes since midnight,
  /// defaulting to 9:00 (540) when allDay is true or no start time is provided.
  /// A flowId of -1 indicates a manual/unlinked note.
  static String buildClientEventId({
    required int ky,
    required int km,
    required int kd,
    required String title,
    required int startHour,
    required int startMinute,
    required bool allDay,
    required int flowId,
  }) {
    final startMin = allDay ? 540 : (startHour * 60 + startMinute);
    return 'ky=$ky-km=$km-kd=$kd|s=$startMin|t=${Uri.encodeComponent(title)}|f=$flowId';
  }
}


