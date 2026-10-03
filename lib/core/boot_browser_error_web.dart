// Match the pinned Hive backend's dart:html/indexed_db error objects.
// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

String? browserBootErrorName(Object error) {
  if (error is html.DomException) return error.name;
  if (error is html.Event) {
    // The pinned SDK passes the failing IDBRequest as this event's target.
    // Keep legacy IndexedDB interop contained here; the caller allowlists names.
    final dynamic target = error.target;
    final Object? name = target?.error?.name;
    return name is String ? name : null;
  }
  return null;
}
