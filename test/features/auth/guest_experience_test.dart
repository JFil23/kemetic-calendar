import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/main.dart' as app;
import 'package:mobile/services/app_navigation_restoration_controller.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/auth/account_invitation_dialog.dart';
import 'package:mobile/features/auth/account_access.dart';
import 'package:mobile/features/profile/profile_page.dart';
import 'package:mobile/widgets/day_sheet_components.dart';
import 'package:mobile/features/auth/guest_experience_host.dart';
import 'package:mobile/features/auth/visitor_preferences.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:mobile/features/calendar/presentation/maat_flow_detail_shell.dart';
import 'package:mobile/features/onboarding/onboarding_overlay.dart';
import 'package:mobile/features/pages/pages_page.dart';
import 'package:mobile/features/pages/pages_layout.dart';
import 'package:mobile/features/pages/pages_models.dart';
import 'package:mobile/features/pages/pages_board.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../pages/pages_resource_test.dart' show session, uid;
import 'dart:io';
import 'package:hive/hive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final requests = <http.Request>[];
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    final fonts =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final font in fonts) {
      final loader = FontLoader(font['family']);
      for (final a in font['fonts']) {
        loader.addFont(rootBundle.load(a['asset']));
      }
      await loader.load();
    }
    Hive.init(Directory.systemTemp.createTempSync('guest-commit-test-').path);
    for (final channel in [
      'receive_sharing_intent/events-media',
      'receive_sharing_intent/events-text',
      'receive_sharing_intent/messages',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(channel), (_) async => null);
    }
    for (final name in ['messages', 'events']) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            MethodChannel('com.llfbandit.app_links/$name'),
            (_) async => null,
          );
    }
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'fixture',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((r) async {
        requests.add(r);
        return http.Response(
          r.url.path.endsWith('get_together_inbox') ||
                  r.url.path.endsWith('get_commons_together_home_cards')
              ? '{}'
              : '[]',
          200,
          request: r,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  });
  tearDownAll(() async {
    await Supabase.instance.dispose();
    await Hive.close();
  });
  setUp(() async {
    await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
    SharedPreferences.setMockInitialValues({
      VisitorPreferences.introSeenKey: true,
      'onboarding_v1_completed:$uid': true,
    });
    requests.clear();
  });
  late GoRouter router;
  var time = Duration.zero;
  Future<void> mount(
    WidgetTester tester, {
    String? location = '/pages',
    bool wholeApp = false,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    time = Duration.zero;
    final initialLocation =
        location ??
        (await AppNavigationRestorationController.instance
                .restoreLaunchDestination(
                  isAuthenticated:
                      Supabase.instance.client.auth.currentSession != null,
                ))
            .route;
    router = app.createAppRouterForTesting(initialLocation: initialLocation);
    await tester.pumpWidget(
      wholeApp
          ? app.MyApp(router: router)
          : MaterialApp.router(
              theme: AppTheme.dark,
              routerConfig: router,
              builder: (_, child) => GuestExperienceHost(
                router: router,
                activityNow: () => time,
                onGoogleSignIn: (_) async {},
                child: child!,
              ),
            ),
    );
    await flush(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await Supabase.instance.client.removeAllChannels();
    router.dispose();
  }

  testWidgets(
    'first visitor sees authored intro then Pages; revisit skips it',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await mount(tester, location: null, wholeApp: true);
      expect(find.byType(HawIntroSlide), findsOneWidget);
      expect(router.state.uri.path, '/pages');
      expect(
        tester.getRect(find.byKey(const ValueKey('visitor-intro'))),
        const Rect.fromLTWH(0, 0, 390, 844),
      );
      await tester.pump(const Duration(milliseconds: 6400));
      await flush(tester);
      await tester.pump(const Duration(milliseconds: 650));
      expect(find.byType(HawIntroSlide), findsNothing);
      expect(find.byType(PagesPage), findsOneWidget);
      expect(find.byType(AccountInvitationDialog), findsNothing);
      expect(requests, isEmpty);
      await unmount(tester);
      await mount(tester, location: null, wholeApp: true);
      expect(router.state.uri.path, '/pages');
      expect(find.byType(PagesPage), findsOneWidget);
      expect(find.byType(HawIntroSlide), findsNothing);
      await unmount(tester);
    },
  );

  testWidgets(
    'idle and single click do not invite; five active seconds invite once',
    (tester) async {
      await mount(tester);
      time += const Duration(seconds: 20);
      await tester.pump(const Duration(seconds: 20));
      expect(find.byType(AccountInvitationDialog), findsNothing);
      await tester.tap(find.text('Notes'));
      time += const Duration(seconds: 20);
      await tester.pump(const Duration(seconds: 20));
      expect(find.byType(AccountInvitationDialog), findsNothing);
      for (var i = 0; i < 8; i++) {
        await tester.tap(find.text(i.isEven ? 'Reminders' : 'Notes'));
        time += const Duration(milliseconds: 500);
        await tester.pump(const Duration(milliseconds: 500));
      }
      await flush(tester);
      expect(find.byType(AccountInvitationDialog), findsOneWidget);
      await tester.tap(find.text('Keep exploring'));
      await flush(tester);
      expect(find.byType(AccountInvitationDialog), findsNothing);
      await unmount(tester);
      await mount(tester);
      time += const Duration(seconds: 10);
      await tester.pump(const Duration(seconds: 10));
      expect(find.byType(AccountInvitationDialog), findsNothing);
      await tester.tap(find.byTooltip('New note'));
      await flush(tester);
      expect(find.byType(AccountInvitationDialog), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('quick-add-input')),
        'Coffee tomorrow',
      );
      await tester.tap(find.byKey(const ValueKey('quick-add-submit-button')));
      await flush(tester);
      expect(find.byType(AccountInvitationDialog), findsOneWidget);
      expect(requests, isEmpty);
      await tester.tap(find.text('Keep exploring'));
      await unmount(tester);
    },
  );

  testWidgets(
    'account-only Journal route stays behind account gate and resumes after sign-in',
    (tester) async {
      await mount(tester, location: '/journal');
      expect(router.state.uri.path, '/pages');
      expect(find.byType(AccountInvitationDialog), findsOneWidget);
      expect(requests, isEmpty);
      await Supabase.instance.client.auth.recoverSession(session());
      await flush(tester);
      expect(find.byType(AccountInvitationDialog), findsNothing);
      expect(router.state.uri.path, '/journal');
      await unmount(tester);
    },
  );

  testWidgets(
    'existing member skips intro and invitation; restored OAuth intent returns to its route',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        VisitorPreferences.pendingLocationKey: '/nodes/haw',
        'onboarding_v1_completed:$uid': true,
      });
      await Supabase.instance.client.auth.recoverSession(session());
      await mount(tester);
      expect(find.byType(HawIntroSlide), findsNothing);
      expect(find.byType(AccountInvitationDialog), findsNothing);
      expect(router.state.uri.path, '/nodes/haw');
      expect(await VisitorPreferences().pendingLocation(), isNull);
      await unmount(tester);
    },
  );

  testWidgets(
    'guest catalog uses authored full details and prompts again at Add flow',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        VisitorPreferences.introSeenKey: true,
        VisitorPreferences.invitationSeenKey: true,
      });
      await mount(tester);
      final tile = find.byWidgetPredicate(
        (w) => w is PagesTile && w.card.destination == PagesDestination.studio,
      );
      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await flush(tester);
      expect(router.state.uri.path, '/flows');
      expect(find.text('The Offering Table'), findsOneWidget);
      await tester.ensureVisible(find.text('The Offering Table'));
      await tester.pump();
      await tester.tap(find.text('The Offering Table'));
      await flush(tester);
      expect(find.byKey(const ValueKey('offering-table-join')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('offering-table-join')));
      await flush(tester);
      expect(find.byType(AccountInvitationDialog), findsOneWidget);
      expect(requests.where((r) => r.method != 'GET'), isEmpty);
      await tester.tap(find.text('Keep exploring'));
      await unmount(tester);
    },
  );

  testWidgets('MyApp mounts guest Pages instead of a login-first application', (
    tester,
  ) async {
    await mount(tester, wholeApp: true);
    expect(requests, isEmpty);
    expect(find.byType(PagesLayout), findsOneWidget);
    expect(find.byType(AccountInvitationDialog), findsNothing);
    await unmount(tester);
  });

  testWidgets('background time is excluded and real scrolling earns activity', (
    tester,
  ) async {
    await mount(tester);
    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, -100),
    );
    time += const Duration(seconds: 1);
    await tester.pump(const Duration(seconds: 1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    time += const Duration(minutes: 1);
    await tester.pump(const Duration(minutes: 1));
    expect(find.byType(AccountInvitationDialog), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    for (var i = 0; i < 8; i++) {
      await tester.drag(
        find.byType(CustomScrollView).first,
        Offset(0, i.isEven ? 70 : -70),
      );
      time += const Duration(milliseconds: 500);
      await tester.pump(const Duration(milliseconds: 500));
    }
    await flush(tester);
    expect(find.byType(AccountInvitationDialog), findsOneWidget);
    await tester.tap(find.text('Keep exploring'));
    await unmount(tester);
  });

  for (final flow in CalendarPage.publicMaatFlowCatalog()) {
    testWidgets(
      '${flow.title} keeps its canonical action behind the account popup',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          VisitorPreferences.introSeenKey: true,
          VisitorPreferences.invitationSeenKey: true,
        });
        await mount(
          tester,
          location: '/flows?mode=maatTemplate&templateKey=${flow.key}',
        );
        final primary = find.descendant(
          of: find.byType(MaatFlowDetailDock),
          matching: find.byType(ElevatedButton),
        );
        expect(primary, findsOneWidget);
        await tester.tap(primary);
        await flush(tester);
        expect(find.byType(AccountInvitationDialog), findsOneWidget);
        expect(requests, isEmpty);
        await tester.tap(find.text('Keep exploring'));
        await unmount(tester);
      },
    );
  }

  testWidgets(
    'Calendar and New note can be explored; Save invites and cancellation retains draft',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        VisitorPreferences.introSeenKey: true,
        VisitorPreferences.invitationSeenKey: true,
      });
      await mount(tester, location: '/');
      expect(find.byType(CalendarPage), findsOneWidget);
      unawaited(
        CalendarPage.openQuickAddFromAnyContext(
          tester.element(find.byType(CalendarPage)),
        ),
      );
      await flush(tester);
      expect(find.byType(AccountInvitationDialog), findsNothing);
      final input = find.byKey(const ValueKey('quick-add-input'));
      await tester.enterText(input, 'Calendar guest draft');
      await tester.tap(find.byKey(const ValueKey('quick-add-submit-button')));
      await flush(tester);
      expect(find.byType(AccountInvitationDialog), findsOneWidget);
      expect(requests, isEmpty);
      await tester.tap(find.text('Keep exploring'));
      await flush(tester);
      expect(find.byType(AccountInvitationDialog), findsNothing);
      expect(
        tester.widget<TextField>(input).controller!.text,
        'Calendar guest draft',
      );
      expect(find.byType(CalendarPage), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('quick-add-full-editor-button')),
      );
      await flush(tester);
      expect(find.byType(AccountInvitationDialog), findsNothing);
      final fullTitle = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.hintText == 'Title',
      );
      expect(fullTitle, findsOneWidget);
      await tester.enterText(fullTitle, 'Full guest event draft');
      final save = find.byType(DaySheetSaveButton);
      await tester.ensureVisible(save);
      await tester.tap(save);
      await flush(tester);
      expect(find.byType(AccountInvitationDialog), findsOneWidget);
      expect(requests, isEmpty);
      await tester.tap(find.text('Keep exploring'));
      await flush(tester);
      expect(find.byType(AccountInvitationDialog), findsNothing);
      expect(
        tester.widget<TextField>(fullTitle).controller!.text,
        'Full guest event draft',
      );
      expect(requests, isEmpty);
      await unmount(tester);
    },
  );

  testWidgets(
    'sign-in on Pages keeps the page alive and logout removes account data',
    (tester) async {
      await mount(tester);
      final pages = tester.state(find.byType(PagesPage));
      await tester.tap(find.byTooltip('New note'));
      await flush(tester);
      await Supabase.instance.client.auth.recoverSession(session());
      await flush(tester);
      expect(find.byType(AccountInvitationDialog), findsNothing);
      expect(tester.state(find.byType(PagesPage)), same(pages));
      expect(
        tester
            .widget<PagesLayout>(find.byType(PagesLayout))
            .profileIdentity
            .isVisitor,
        isFalse,
      );
      await tester.runAsync(
        () => Supabase.instance.client.auth.signOut(scope: SignOutScope.local),
      );
      await flush(tester);
      final layout = tester.widget<PagesLayout>(find.byType(PagesLayout));
      expect(layout.profileIdentity.isVisitor, isTrue);
      expect(
        layout.cards.every(
          (card) =>
              card.value.flow == null &&
              card.value.event == null &&
              card.value.unread == 0,
        ),
        isTrue,
      );
      await unmount(tester);
    },
  );

  testWidgets(
    'OAuth note continuation opens the existing editor without saving',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        VisitorPreferences.pendingLocationKey: '/pages?create=note',
        'onboarding_v1_completed:$uid': true,
      });
      await Supabase.instance.client.auth.recoverSession(session());
      await mount(tester);
      expect(find.byKey(const ValueKey('quick-add-input')), findsOneWidget);
      expect(await VisitorPreferences().pendingLocation(), isNull);
      expect(
        requests.where(
          (r) =>
              r.url.path.contains('apply_planner_mutation') ||
              r.url.path.contains('create_user_event'),
        ),
        isEmpty,
      );
      await unmount(tester);
    },
  );

  testWidgets('account popup keeps dismissal reachable above the keyboard', (
    tester,
  ) async {
    await mount(tester);
    await tester.tap(find.byTooltip('New note'));
    await flush(tester);
    await tester.enterText(
      find.byKey(const ValueKey('quick-add-input')),
      'A guest note',
    );
    await tester.tap(find.byKey(const ValueKey('quick-add-submit-button')));
    await flush(tester);
    final email = find.descendant(
      of: find.byType(AccountInvitationDialog),
      matching: find.widgetWithText(TextField, 'Email'),
    );
    await tester.tap(email);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      tester.getRect(find.text('Keep exploring')).bottom,
      lessThanOrEqualTo(544),
    );
    await tester.tap(find.text('Keep exploring'));
    await flush(tester);
    expect(find.byType(AccountInvitationDialog), findsNothing);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets(
    'MyApp preserves the requested note editor through authentication',
    (tester) async {
      await mount(tester, wholeApp: true);
      await tester.tap(find.byTooltip('New note'));
      await flush(tester);
      expect(find.byType(AccountInvitationDialog), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('quick-add-input')),
        'A guest note',
      );
      unawaited(
        AccountAccess.require(
          tester.element(find.byKey(const ValueKey('quick-add-input'))),
        ),
      );
      await flush(tester);
      expect(find.byType(AccountInvitationDialog), findsOneWidget);
      await Supabase.instance.client.auth.recoverSession(session());
      await flush(tester);
      expect(find.byType(AccountInvitationDialog), findsNothing);
      expect(find.byKey(const ValueKey('quick-add-input')), findsOneWidget);
      expect(find.byType(OnboardingOverlay), findsNothing);
      await unmount(tester);
    },
  );

  testWidgets(
    'real app retains own-profile state from guest to its first account',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final router = app.createAppRouterForTesting(
        initialLocation: '/profile/me',
      );
      await tester.pumpWidget(app.MyApp(router: router));
      await flush(tester);
      final profile = find.byType(ProfilePage);
      expect(tester.widget<ProfilePage>(profile).userId, isEmpty);
      final retained = tester.state(profile);
      expect(find.byType(AccountInvitationDialog), findsNothing);
      await Supabase.instance.client.auth.recoverSession(session());
      await flush(tester);
      expect(tester.widget<ProfilePage>(profile).userId, uid);
      expect(identical(tester.state(profile), retained), isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      router.dispose();
    },
  );

  testWidgets(
    'OAuth flow creation continuation uses the existing Compose owner',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        VisitorPreferences.pendingLocationKey: '/flows?create=flow',
        'onboarding_v1_completed:$uid': true,
      });
      await Supabase.instance.client.auth.recoverSession(session());
      await mount(tester);
      expect(router.state.uri.path, '/flows');
      expect(find.text('Compose'), findsOneWidget);
      expect(await VisitorPreferences().pendingLocation(), isNull);
      await unmount(tester);
    },
  );
}

Future<void> flush(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}
