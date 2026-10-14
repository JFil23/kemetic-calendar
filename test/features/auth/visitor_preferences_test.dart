import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/features/auth/visitor_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(
    () => SharedPreferences.setMockInitialValues({
      'onboarding_v2_progress:account-a': '{"hawSlide":"orientation"}',
      'planner_account:v1:account-a': 'pending-account-write',
    }),
  );
  test(
    'visitor markers survive new owners without changing account content',
    () async {
      final first = VisitorPreferences();
      expect(await first.introSeen(), isFalse);
      await first.markIntroSeen();
      await first.markInvitationSeen();
      await first.rememberLocation(
        '/flows?mode=maatTemplate&templateKey=the-djed',
      );
      final returning = VisitorPreferences();
      expect(await returning.introSeen(), isTrue);
      expect(await returning.invitationSeen(), isTrue);
      expect(
        await returning.pendingLocation(),
        '/flows?mode=maatTemplate&templateKey=the-djed',
      );
      await returning.clearLocation();
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('planner_account:v1:account-a'),
        'pending-account-write',
      );
      expect(
        prefs.getString('onboarding_v2_progress:account-a'),
        '{"hawSlide":"orientation"}',
      );
      expect(await returning.pendingLocation(), isNull);
    },
  );
  test(
    'navigation intents cannot retain credentials or external destinations',
    () {
      for (final target in [
        'https://example.com',
        '//example.com/path',
        '/?code=secret',
        '/?access_token=secret',
        '/pages?account=/inbox',
        '/#access_token=secret',
      ]) {
        expect(safeVisitorLocation(target), isNull, reason: target);
      }
    },
  );
  test(
    'public owners remain browsable; account reads and edit routes are gated',
    () {
      for (final target in [
        '/',
        '/pages',
        '/nodes',
        '/nodes/haw',
        '/flows',
        '/flows?mode=maatFlows',
        '/inbox',
        '/inbox/conversation/person',
        '/inbox/dm/thread',
        '/nodes/haw?action=add_insight',
        '/nodes/haw?insight=new',
        '/profile/me',
        '/profile/me/edit',
        '/rhythm/today',
        '/flows?mode=myFlows',
        '/flows?mode=maatTemplate&templateKey=the-kar',
      ]) {
        expect(
          guestAccountRedirect(Uri.parse(target), signedIn: false),
          isNull,
          reason: target,
        );
      }
      for (final target in [
        '/journal',
        '/flows?flow=17',
        '/flows/17/edit',
        '/shared-flow/by-flow/17',
      ]) {
        final redirect = Uri.parse(
          guestAccountRedirect(Uri.parse(target), signedIn: false)!,
        );
        expect(redirect.path, '/pages');
        expect(redirect.queryParameters['account'], target);
        expect(guestAccountRedirect(Uri.parse(target), signedIn: true), isNull);
      }
    },
  );

  test(
    'existing share invitations retain their capability through authentication',
    () async {
      for (final location in [
        '/share/example?token=invitation',
        '/inbox?share=example&token=invitation',
      ]) {
        final redirect = Uri.parse(
          guestAccountRedirect(Uri.parse(location), signedIn: false)!,
        );
        expect(redirect.queryParameters['account'], location);
        await VisitorPreferences().rememberLocation(location);
        expect(await VisitorPreferences().pendingLocation(), location);
      }
      expect(safeVisitorLocation('/?token=login-secret'), isNull);
    },
  );
}
