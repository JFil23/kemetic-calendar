// Google supplies these navigation notices in descriptions of Gmail-created
// events. They are provider UI instructions, not event notes. Match only the
// observed complete notices; callers must limit this transform to imports.
String _wrappedNotice(String sentence) =>
    sentence.split(' ').map(RegExp.escape).join(r'[ \t\r\n]+');

final _googleCalendarAppNotice = RegExp(
  '^[ \\t]*${_wrappedNotice('To see detailed information for automatically created events like '
  'this one, use the official Google Calendar app.')}'
  r'[ \t\r\n]+https://g\.co/calendar[ \t]*\r?$'
  // Remove the notice's following separator, retaining the indentation
  // and all line breaks inside any genuine notes that follow it.
  r'(?:\n(?:[ \t]*\r?\n)*)?',
  multiLine: true,
);

final _gmailSourceNotice = RegExp(
  '^[ \\t]*${_wrappedNotice('This event was created from an email you received in Gmail.')}'
  r'[ \t\r\n]+(https://mail\.google\.com/mail\?[^\s<>]+)[ \t]*\r?$',
  multiLine: true,
);

/// Event prose and its original email link for imported-event presentation.
///
/// Raw provider data remains untouched. The email URL stays available to the
/// existing event resource resolver and link area; unrelated prose is retained.
String importedCalendarDisplayDetail(String? detail) {
  if (detail == null || detail.isEmpty) return detail ?? '';
  return detail
      .replaceAll(_googleCalendarAppNotice, '')
      .replaceAllMapped(_gmailSourceNotice, (match) => match.group(1)!);
}
