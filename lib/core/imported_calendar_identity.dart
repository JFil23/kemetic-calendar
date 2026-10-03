/// Imported projections, including pre-migration device copies, stay read-only.
bool isImportedDeviceCalendarEvent({String? clientEventId, String? category}) {
  final cid = clientEventId?.trim().toLowerCase() ?? '';
  if (cid.startsWith('native:') || cid.startsWith('external:')) {
    return true;
  }
  final normalizedCategory = category?.trim().toLowerCase() ?? '';
  return normalizedCategory == 'native_sync' ||
      normalizedCategory == 'external_calendar';
}
