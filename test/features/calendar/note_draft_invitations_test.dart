import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/profile_repo.dart';
import 'package:mobile/data/share_models.dart';
import 'package:mobile/features/calendar/note_draft_invitations.dart';

UserSearchResult person(String id) =>
    UserSearchResult(userId: id, displayName: id);
ShareResult sent(ShareRecipient recipient) =>
    ShareResult(recipient: recipient, status: 'sent');
void main() {
  test(
    'selection restores only within its account, including old empty draft',
    () {
      final draft = NoteDraftInvitations(accountId: 'owner')
        ..people = [person('friend')];
      expect(
        NoteDraftInvitations.restore(
          draft.toJson(),
          'owner',
        ).people.single.userId,
        'friend',
      );
      expect(
        NoteDraftInvitations.restore(draft.toJson(), 'other').people,
        isEmpty,
      );
      expect(NoteDraftInvitations.restore(null, 'owner').people, isEmpty);
    },
  );
  test(
    'no invitation before save acknowledgement; concurrent Save cannot duplicate',
    () async {
      final draft = NoteDraftInvitations(accountId: 'owner')
        ..people = [person('friend')];
      final ack = Completer<String>();
      var saves = 0;
      var sends = 0;
      Future<bool> save() => draft.saveAndInvite(
        currentAccountId: () => 'owner',
        saveEvent: () {
          saves++;
          return ack.future;
        },
        send: (id, recipients) async {
          expect(id, 'saved-note');
          sends++;
          return recipients.map(sent).toList();
        },
        checkpoint: () async {},
      );
      final saving = save();
      expect(sends, 0);
      expect(await save(), isFalse);
      expect(saves, 1);
      ack.complete('saved-note');
      expect(await saving, isTrue);
      expect(sends, 1);
    },
  );
  test('save failure retains selection and never calls sharing', () async {
    final draft = NoteDraftInvitations(accountId: 'owner')
      ..people = [person('friend')];
    await expectLater(
      draft.saveAndInvite(
        currentAccountId: () => 'owner',
        saveEvent: () async => throw StateError('offline'),
        send: (_, _) async => fail('must not share'),
        checkpoint: () async {},
      ),
      throwsStateError,
    );
    expect(draft.savedTargetId, isNull);
    expect(draft.people.single.userId, 'friend');
    expect(draft.busy, isFalse);
  });
  test(
    'partial send retries only failures against the same note after restoration',
    () async {
      var draft = NoteDraftInvitations(accountId: 'owner')
        ..people = [person('a'), person('b')];
      expect(
        await draft.saveAndInvite(
          currentAccountId: () => 'owner',
          saveEvent: () async => 'saved',
          send: (_, recipients) async => [
            sent(recipients.first),
            ShareResult(error: 'offline'),
          ],
          checkpoint: () async {},
        ),
        isFalse,
      );
      expect(draft.people.single.userId, 'b');
      draft = NoteDraftInvitations.restore(draft.toJson(), 'owner');
      expect(
        await draft.saveAndInvite(
          currentAccountId: () => 'owner',
          saveEvent: () async => fail('must not duplicate note'),
          send: (id, recipients) async {
            expect(id, 'saved');
            expect(recipients.single.value, 'b');
            return recipients.map(sent).toList();
          },
          checkpoint: () async {},
        ),
        isTrue,
      );
    },
  );
  test(
    'lost invitation acknowledgement retains saved identity and selection',
    () async {
      final draft = NoteDraftInvitations(accountId: 'owner')
        ..people = [person('friend')];
      await expectLater(
        draft.saveAndInvite(
          currentAccountId: () => 'owner',
          saveEvent: () async => 'saved',
          send: (_, _) async => throw TimeoutException('lost ack'),
          checkpoint: () async {},
        ),
        throwsA(isA<TimeoutException>()),
      );
      expect(draft.savedTargetId, 'saved');
      expect(draft.people, hasLength(1));
    },
  );
  test('account switch during save fences invitation dispatch', () async {
    var account = 'owner';
    final draft = NoteDraftInvitations(accountId: account)
      ..people = [person('friend')];
    await expectLater(
      draft.saveAndInvite(
        currentAccountId: () => account,
        saveEvent: () async {
          account = 'other';
          return 'saved';
        },
        send: (_, _) async => fail('must not share across accounts'),
        checkpoint: () async {},
      ),
      throwsStateError,
    );
  });
}
