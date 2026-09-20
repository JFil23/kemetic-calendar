import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/birthday_calendar.dart';
import 'package:mobile/data/shared_calendar_models.dart';

void main() {
  test('pending invite keeps canonical source-flow identity in cache', () {
    final invite = SharedCalendarInvite.fromRow(<String, dynamic>{
      'calendar_id': 'house-calendar',
      'calendar_name': 'The Odyssey',
      'calendar_color': 0x3FA98A,
      'role': 'viewer',
      'invited_at': '2026-09-19T12:00:00Z',
      'source_flow_id': 104,
      'source_flow_key': 'the-reading-house',
      'source_book_title': 'The Odyssey',
    });

    expect(invite.sourceFlowId, 104);
    expect(invite.sourceFlowKey, 'the-reading-house');
    expect(invite.sourceBookLabel, 'The Odyssey');
    expect(invite.toCacheJson(), containsPair('source_flow_id', 104));
    expect(
      invite.toCacheJson(),
      containsPair('source_flow_key', 'the-reading-house'),
    );
  });

  test('pending invite strips the legacy Reading House display prefix', () {
    final invite = SharedCalendarInvite(
      calendarId: 'legacy-house-calendar',
      calendarName: 'Reading House · catcher in the rye',
      calendarColorValue: 0x3FA98A,
      role: SharedCalendarRole.viewer,
      invitedAt: DateTime.utc(2026, 9, 19),
    );

    expect(invite.sourceBookLabel, 'catcher in the rye');
  });

  group('SharedCalendarSummary permissions', () {
    test('owner can manage membership and see pending invites', () {
      final calendar = _summary(
        role: SharedCalendarRole.owner,
        pendingInviteCount: 4,
      );

      expect(calendar.canEditEvents, isTrue);
      expect(calendar.canManageMembership, isTrue);
      expect(calendar.canSeeMemberRoster, isTrue);
      expect(calendar.canSeePendingInvites, isTrue);
    });

    test('editor can edit events but cannot manage membership', () {
      final calendar = _summary(
        role: SharedCalendarRole.editor,
        pendingInviteCount: 4,
      );

      expect(calendar.canEditEvents, isTrue);
      expect(calendar.canManageMembership, isFalse);
      expect(calendar.canSeeMemberRoster, isTrue);
      expect(calendar.canSeePendingInvites, isFalse);
    });

    test('viewer can see roster but cannot edit events or pending invites', () {
      final calendar = _summary(
        role: SharedCalendarRole.viewer,
        pendingInviteCount: 4,
      );

      expect(calendar.canEditEvents, isFalse);
      expect(calendar.canManageMembership, isFalse);
      expect(calendar.canSeeMemberRoster, isTrue);
      expect(calendar.canSeePendingInvites, isFalse);
    });

    test('birthdays calendar is protected from membership management', () {
      final calendar = _summary(
        role: SharedCalendarRole.owner,
        pendingInviteCount: 4,
        systemType: kBirthdaysSystemType,
      );

      expect(calendar.isBirthdays, isTrue);
      expect(calendar.canEditEvents, isTrue);
      expect(calendar.canManageMembership, isFalse);
      expect(calendar.canSeeMemberRoster, isFalse);
      expect(calendar.canSeePendingInvites, isFalse);
    });
  });

  group('SharedCalendarMember', () {
    test('parses role labels and display fallbacks', () {
      final member = SharedCalendarMember.fromRow({
        'user_id': 123,
        'role': 'viewer',
        'status': 'pending',
        'handle': 'kid',
      });

      expect(member.userId, '123');
      expect(member.roleLabel, 'View only');
      expect(member.isPending, isTrue);
      expect(member.displayLabel, '@kid');
      expect(member.handleLabel, '@kid');
    });
  });
}

SharedCalendarSummary _summary({
  required SharedCalendarRole role,
  int pendingInviteCount = 0,
  String? systemType,
}) {
  return SharedCalendarSummary(
    id: 'calendar-1',
    ownerId: 'owner-1',
    name: 'Family',
    colorValue: 0xFFD4AF37,
    icon: 'calendar',
    isPersonal: false,
    role: role,
    status: SharedCalendarInviteStatus.accepted,
    memberCount: 2,
    pendingInviteCount: pendingInviteCount,
    systemType: systemType,
  );
}
