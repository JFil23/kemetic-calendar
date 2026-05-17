import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/shared_calendar_models.dart';

void main() {
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
  );
}
