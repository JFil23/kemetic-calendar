import 'dart:ui';

List<Color> calendarEventMarkerColors<T>(
  Iterable<T> events, {
  required Color Function(T event) colorOf,
  Object? Function(T event)? groupBy,
  int maxMarkers = 3,
}) {
  if (maxMarkers <= 0) return const <Color>[];

  final colors = <Color>[];
  final seenGroups = <Object>{};
  for (final event in events) {
    final group = groupBy?.call(event);
    if (group != null && !seenGroups.add(group)) continue;

    colors.add(colorOf(event));
    if (colors.length >= maxMarkers) break;
  }
  return colors;
}
