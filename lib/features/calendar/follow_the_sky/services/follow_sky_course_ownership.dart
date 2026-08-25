/// Ownership stamp for calendar blocks created by Follow the Sky Protect Time.
///
/// Protect Time creates ordinary calendar blocks (not permanent Flows) and
/// stamps them with the Course id so measurement can attribute them without
/// requiring Connect Activity.
class FollowSkyCourseOwnership {
  static const String actionId = 'follow_the_sky.protect_time';
  static const String courseIdKey = 'trackSkyCourseId';
  static const String createdByKey = 'createdBy';
  static const String createdByValue = 'follow_the_sky';

  static Map<String, dynamic> behaviorPayload({required String courseId}) => {
        courseIdKey: courseId,
        createdByKey: createdByValue,
      };

  static String? courseIdOf(Map<String, dynamic>? payload) {
    final raw = payload?[courseIdKey]?.toString().trim();
    if (raw == null || raw.isEmpty) return null;
    return raw;
  }

  static bool isProtectTime(Map<String, dynamic>? payload) =>
      payload?[createdByKey]?.toString() == createdByValue;
}
