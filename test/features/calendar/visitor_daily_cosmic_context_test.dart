import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/visitor_preferences.dart';
import 'package:mobile/features/calendar/daily_cosmic_context_badge.dart';
import 'package:mobile/features/settings/settings_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final firstDay = DateTime(2026, 10, 14);
  var now = firstDay;

  Future<void> visit(DailyCosmicContextController controller) =>
      controller.evaluate(
        userId: null,
        isAuthenticated: false,
        onboardingComplete: false,
        suppressed: false,
        allowVisitor: true,
      );
  Future<void> signIn(
    DailyCosmicContextController controller, {
    bool onboardingComplete = true,
  }) => controller.evaluate(
    userId: 'member',
    isAuthenticated: true,
    onboardingComplete: onboardingComplete,
    suppressed: false,
  );
  DailyCosmicContextController create({DailyCosmicContextPrefs? prefs}) {
    final controller = DailyCosmicContextController(
      now: () => now,
      prefs: prefs ?? const DailyCosmicContextPrefs(),
    );
    addTearDown(controller.dispose);
    return controller;
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    now = firstDay;
  });

  test(
    'visitor sees current authored rhythm once per local day across restarts',
    () async {
      final controller = create();
      await visit(controller);
      final badge = controller.current!;
      expect(
        badge.cosmicContext,
        dailyCosmicContextBadgeForDate(firstDay)!.cosmicContext,
      );
      expect(badge.gregorianDateKey, '2026-10-14');
      expect(controller.canPersistPreference, isFalse);
      await visit(controller);
      expect(controller.current, same(badge));
      await controller.dismiss();
      await visit(controller);
      expect(controller.current, isNull);
      final restarted = create();
      await visit(restarted);
      expect(restarted.current, isNull);
      now = DateTime(2026, 10, 15);
      await visit(restarted);
      expect(restarted.current!.gregorianDateKey, '2026-10-15');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), {VisitorPreferences.dailyRhythmLastShownKey});
      expect(
        prefs.getString(VisitorPreferences.dailyRhythmLastShownKey),
        '2026-10-15',
      );
    },
  );

  test(
    'guest switch is temporary and cannot overwrite member opt-out',
    () async {
      await SettingsPrefs.setDailyCosmicContextBadgeEnabled(false);
      final controller = create();
      await visit(controller);
      final badge = controller.current;
      expect(badge, isNotNull);
      expect(controller.automaticDisplay, isTrue);
      for (final enabled in [false, true, false]) {
        await controller.setEnabled(enabled);
        await visit(controller);
        expect(controller.current, same(badge));
        expect(controller.automaticDisplay, enabled);
        expect(await SettingsPrefs.dailyCosmicContextBadgeEnabled(), isFalse);
      }
      await controller.dismiss();
      now = DateTime(2026, 10, 15);
      await visit(controller);
      expect(controller.current, isNotNull);
      expect(controller.automaticDisplay, isTrue);
      expect(await SettingsPrefs.dailyCosmicContextBadgeEnabled(), isFalse);
      await signIn(controller);
      expect(controller.current, isNull);
      expect(controller.canPersistPreference, isTrue);
    },
  );

  test(
    'guest opt-out does not prevent next day or alter a member preference',
    () async {
      final controller = create();
      await visit(controller);
      await controller.setEnabled(false);
      expect(await SettingsPrefs.dailyCosmicContextBadgeEnabled(), isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.containsKey(SettingsPrefs.dailyCosmicContextBadgeEnabledKey),
        isFalse,
      );
      await controller.dismiss();
      now = DateTime(2026, 10, 15);
      await visit(controller);
      expect(controller.current, isNotNull);
      expect(controller.automaticDisplay, isTrue);
      await signIn(controller);
      expect(controller.current, isNotNull);
      expect(controller.canPersistPreference, isTrue);
      await controller.setEnabled(false);
      expect(await SettingsPrefs.dailyCosmicContextBadgeEnabled(), isFalse);
      expect(controller.current, isNotNull);
      await controller.dismiss();
      now = DateTime(2026, 10, 16);
      final restartedMember = create();
      await signIn(restartedMember);
      expect(restartedMember.current, isNull);
      final memberSeen =
          DailyCosmicContextPrefs.lastShownGregorianDateKeyForUser('member');
      expect(prefs.getString(memberSeen), '2026-10-15');
      expect(
        prefs.getString(VisitorPreferences.dailyRhythmLastShownKey),
        '2026-10-15',
      );
    },
  );

  test(
    'intro/modal suppression leaves visitor day unseen until presentation',
    () async {
      final controller = create();
      await controller.evaluate(
        userId: null,
        isAuthenticated: false,
        onboardingComplete: false,
        suppressed: true,
        allowVisitor: true,
      );
      expect(controller.current, isNull);
      expect(await VisitorPreferences().dailyRhythmLastShown(), isNull);
      await visit(controller);
      expect(controller.current, isNotNull);
    },
  );

  test(
    'sign-in cannot bypass first-account onboarding with guest eligibility',
    () async {
      final controller = create();
      await visit(controller);
      await controller.evaluate(
        userId: 'member',
        isAuthenticated: true,
        onboardingComplete: false,
        suppressed: false,
        allowVisitor: true,
      );
      expect(controller.current, isNull);
      expect(
        (await SharedPreferences.getInstance()).containsKey(
          DailyCosmicContextPrefs.lastShownGregorianDateKeyForUser('member'),
        ),
        isFalse,
      );
      await signIn(controller);
      expect(controller.current, isNotNull);
    },
  );

  test(
    'sign-in fences a pending guest read and preserves member preference',
    () async {
      final prefs = _PendingVisitorPrefs();
      final controller = create(prefs: prefs);
      final opening = visit(controller);
      await signIn(controller);
      final member = controller.current;
      prefs.seen.complete(null);
      await opening;
      expect(controller.current, same(member));
      expect(controller.canPersistPreference, isTrue);
      expect(await VisitorPreferences().dailyRhythmLastShown(), isNull);
    },
  );

  test(
    'departure immediately fences a stale member toggle and pending reads',
    () async {
      final prefs = _PendingMemberPrefs();
      final controller = create(prefs: prefs);
      final opening = signIn(controller);
      controller.clearForAccountChange();
      await controller.setEnabled(false);
      await visit(controller);
      final visitor = controller.current;
      prefs.enabled.complete(true);
      await opening;
      expect(controller.current, same(visitor));
      expect(controller.canPersistPreference, isFalse);
      expect(await SettingsPrefs.dailyCosmicContextBadgeEnabled(), isTrue);
    },
  );

  test('no bundled rhythm does not consume the visitor daily marker', () async {
    final controller = DailyCosmicContextController(
      now: () => firstDay,
      badgeForDate: (_) => null,
    );
    addTearDown(controller.dispose);
    await visit(controller);
    expect(controller.current, isNull);
    expect(await VisitorPreferences().dailyRhythmLastShown(), isNull);
  });
}

class _PendingVisitorPrefs extends DailyCosmicContextPrefs {
  final seen = Completer<String?>();
  @override
  Future<String?> lastShownVisitorGregorianDate() => seen.future;
}

class _PendingMemberPrefs extends DailyCosmicContextPrefs {
  final enabled = Completer<bool>();
  @override
  Future<bool> isEnabled() => enabled.future;
}
