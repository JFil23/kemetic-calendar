import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/event_resource.dart';
import 'package:mobile/features/calendar/imported_calendar_detail.dart';

const _appNotice =
    'To see detailed information for automatically created events like this '
    'one, use the official Google Calendar app. https://g.co/calendar';
const _mailUrl = 'https://mail.google.com/mail?extsrc=cal&plid=original-event';
const _gmailNotice =
    'This event was created from an email you received in Gmail. $_mailUrl';

void main() {
  test('null and empty details remain empty', () {
    expect(importedCalendarDisplayDetail(null), '');
    expect(importedCalendarDisplayDetail(''), '');
  });

  test('observed provider paragraphs reduce to the original email URL', () {
    expect(
      importedCalendarDisplayDetail('$_appNotice\n\n$_gmailNotice'),
      _mailUrl,
    );
  });

  test('a complete app notice with its generic URL is removed', () {
    expect(importedCalendarDisplayDetail(_appNotice), '');
  });

  test('a complete Gmail source notice retains its original URL', () {
    expect(importedCalendarDisplayDetail(_gmailNotice), _mailUrl);
  });

  test('wrapped provider paragraphs retain the original email URL', () {
    final wrapped =
        'To see detailed information for automatically created\n'
        'events like this one, use the official Google Calendar app.\n'
        'https://g.co/calendar\n\n'
        'This event was created from an email you received\n'
        'in Gmail.\n$_mailUrl';
    expect(importedCalendarDisplayDetail(wrapped), _mailUrl);
  });

  test('CRLF and horizontal whitespace wrapping are accepted', () {
    final wrapped =
        '  To see detailed information for automatically created\r\n'
        '\tevents like this one, use the official Google Calendar app.\r\n'
        'https://g.co/calendar  \r\n\r\n'
        '\tThis event was created from an email you received\r\n'
        'in Gmail.\t$_mailUrl  ';
    expect(importedCalendarDisplayDetail(wrapped), _mailUrl);
  });

  test('real notes and their line breaks survive surrounding notices', () {
    const before = 'Arrival instructions.\n  Keep the side gate accessible.';
    const after = 'Aftercare:\n\n  Call if the issue returns.';
    expect(
      importedCalendarDisplayDetail(
        '$before\n\n$_appNotice\n\n$_gmailNotice\n\n$after',
      ),
      '$before\n\n$_mailUrl\n\n$after',
    );
  });

  test('indentation of a genuine line following an app notice survives', () {
    expect(
      importedCalendarDisplayDetail('$_appNotice\n  Keep the side gate open.'),
      '  Keep the side gate open.',
    );
  });

  test('original email URL wins over the removed generic app URL', () {
    final resource = resolveEventResource(
      EventResourceSource(
        detail: importedCalendarDisplayDetail('$_appNotice\n\n$_gmailNotice'),
        location: 'City Hall',
      ),
    );
    expect(resource?.target, _mailUrl);
    expect(resource?.kind, EventResourceKind.web);
  });

  test('real event URL wins over the removed generic app URL', () {
    const eventUrl = 'https://example.com/appointments/original-event';
    final detail = importedCalendarDisplayDetail(
      '$_appNotice\n\nBring identification.\n$eventUrl',
    );
    expect(detail, 'Bring identification.\n$eventUrl');
    expect(
      resolveEventResource(EventResourceSource(detail: detail))?.target,
      eventUrl,
    );
  });

  test('a removed app notice creates no artificial resource', () {
    expect(
      resolveEventResource(
        EventResourceSource(detail: importedCalendarDisplayDetail(_appNotice)),
      ),
      isNull,
    );
  });

  for (final original in [
    '  Ordinary notes.\n\n  Keep this spacing.\n',
    'Reminder: bring insurance card',
    'flowLocalId=literal; Reminder: bring insurance card',
    'ky=1-km=1-kd=1|s=900|t=literal|f=example',
    'Use another calendar if you need the shared office schedule.',
    'https://g.co/calendar',
    _appNotice.replaceFirst('official', 'preferred'),
    _appNotice.replaceFirst('To see', 'To view'),
    _appNotice.replaceFirst('https://g.co/calendar', 'https://g.co/calendar/'),
    _appNotice.replaceFirst(
      'https://g.co/calendar',
      'https://example.com/event',
    ),
    'The instructions say: $_appNotice',
    '$_appNotice Ask the host first.',
    'The instructions say: $_gmailNotice',
    '$_gmailNotice Ask the host first.',
    _gmailNotice.replaceFirst('received', 'sent'),
    _gmailNotice.replaceFirst('mail.google.com/', 'mail.google.com.example/'),
    _gmailNotice.replaceFirst('/mail?', '/other?'),
  ]) {
    test('preserves genuine prose or near match: $original', () {
      expect(importedCalendarDisplayDetail(original), original);
    });
  }
}
