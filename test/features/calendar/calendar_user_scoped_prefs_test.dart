import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/features/calendar/calendar_user_scoped_prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const userA = 'user-a';
  const userB = 'user-b';

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test(
    'migration copies global tombstones once and leaves legacy intact',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        CalendarUserScopedPrefs.legacyManualDeleteTombstonesKey: <String>[
          'cid-a',
          'cid-b',
        ],
      });
      final prefs = await SharedPreferences.getInstance();

      await CalendarUserScopedPrefs.ensureMigrated(prefs: prefs, userId: userA);

      expect(
        prefs.getStringList(
          CalendarUserScopedPrefs.manualDeleteTombstonesKey(userA),
        ),
        <String>['cid-a', 'cid-b'],
      );
      expect(
        prefs.getStringList(
          CalendarUserScopedPrefs.legacyManualDeleteTombstonesKey,
        ),
        <String>['cid-a', 'cid-b'],
        reason: 'copy-never-drop must leave the global key for rollback safety',
      );
      expect(
        prefs.getBool(
          CalendarUserScopedPrefs.userScopedMigrationDoneKey(userA),
        ),
        isTrue,
      );

      // Second run must not overwrite user-scoped edits.
      await prefs.setStringList(
        CalendarUserScopedPrefs.manualDeleteTombstonesKey(userA),
        <String>['cid-a-only'],
      );
      await CalendarUserScopedPrefs.ensureMigrated(prefs: prefs, userId: userA);
      expect(
        prefs.getStringList(
          CalendarUserScopedPrefs.manualDeleteTombstonesKey(userA),
        ),
        <String>['cid-a-only'],
      );
    },
  );

  test('read prefers user-scoped list and falls back to global', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      CalendarUserScopedPrefs.legacyManualDeleteTombstonesKey: <String>[
        'global-cid',
      ],
    });
    final prefs = await SharedPreferences.getInstance();

    final beforeScoped = await CalendarUserScopedPrefs.readStringList(
      prefs: prefs,
      userId: userA,
      userKey: CalendarUserScopedPrefs.manualDeleteTombstonesKey,
      legacyKey: CalendarUserScopedPrefs.legacyManualDeleteTombstonesKey,
    );
    expect(beforeScoped, <String>['global-cid']);

    await CalendarUserScopedPrefs.writeStringList(
      prefs: prefs,
      userId: userA,
      userKey: CalendarUserScopedPrefs.manualDeleteTombstonesKey,
      legacyKey: CalendarUserScopedPrefs.legacyManualDeleteTombstonesKey,
      values: <String>['user-a-cid'],
    );

    final userARead = await CalendarUserScopedPrefs.readStringList(
      prefs: prefs,
      userId: userA,
      userKey: CalendarUserScopedPrefs.manualDeleteTombstonesKey,
      legacyKey: CalendarUserScopedPrefs.legacyManualDeleteTombstonesKey,
    );
    expect(userARead, <String>['user-a-cid']);

    final userBRead = await CalendarUserScopedPrefs.readStringList(
      prefs: prefs,
      userId: userB,
      userKey: CalendarUserScopedPrefs.manualDeleteTombstonesKey,
      legacyKey: CalendarUserScopedPrefs.legacyManualDeleteTombstonesKey,
    );
    expect(
      userBRead,
      <String>['global-cid'],
      reason:
          'second user with no scoped key falls back to global until they write',
    );
  });

  test('second user write does not bleed into first user scoped key', () async {
    final prefs = await SharedPreferences.getInstance();
    await CalendarUserScopedPrefs.writeStringList(
      prefs: prefs,
      userId: userA,
      userKey: CalendarUserScopedPrefs.manualDeleteTombstonesKey,
      legacyKey: CalendarUserScopedPrefs.legacyManualDeleteTombstonesKey,
      values: <String>['only-a'],
    );
    await CalendarUserScopedPrefs.writeStringList(
      prefs: prefs,
      userId: userB,
      userKey: CalendarUserScopedPrefs.manualDeleteTombstonesKey,
      legacyKey: CalendarUserScopedPrefs.legacyManualDeleteTombstonesKey,
      values: <String>['only-b'],
    );

    expect(
      prefs.getStringList(
        CalendarUserScopedPrefs.manualDeleteTombstonesKey(userA),
      ),
      <String>['only-a'],
    );
    expect(
      prefs.getStringList(
        CalendarUserScopedPrefs.manualDeleteTombstonesKey(userB),
      ),
      <String>['only-b'],
    );
  });

  test('occurrence exclusions persist in the active user scope', () async {
    final prefs = await SharedPreferences.getInstance();
    const exclusion = 'reminder:rule-1:2026-08-15';

    await CalendarUserScopedPrefs.writeStringList(
      prefs: prefs,
      userId: userA,
      userKey: CalendarUserScopedPrefs.occurrenceExclusionsKey,
      legacyKey: CalendarUserScopedPrefs.legacyOccurrenceExclusionsKey,
      values: const <String>[exclusion],
    );

    expect(
      await CalendarUserScopedPrefs.readStringList(
        prefs: prefs,
        userId: userA,
        userKey: CalendarUserScopedPrefs.occurrenceExclusionsKey,
        legacyKey: CalendarUserScopedPrefs.legacyOccurrenceExclusionsKey,
      ),
      const <String>[exclusion],
    );
    expect(
      await CalendarUserScopedPrefs.readStringList(
        prefs: prefs,
        userId: userB,
        userKey: CalendarUserScopedPrefs.occurrenceExclusionsKey,
        legacyKey: CalendarUserScopedPrefs.legacyOccurrenceExclusionsKey,
      ),
      isEmpty,
    );
  });
}
