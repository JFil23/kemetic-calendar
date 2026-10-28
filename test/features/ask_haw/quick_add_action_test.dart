import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/auth/account_access.dart';
import 'package:mobile/features/auth/visitor_preferences.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/maat_flow_visual_test_fonts.dart';

const _inputKey = ValueKey('quick-add-input');
const _submitKey = ValueKey('quick-add-submit-button');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final requests = <http.Request>[];
  var accountRequests = 0;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final name in [
      'com.llfbandit.app_links/messages',
      'com.llfbandit.app_links/events',
    ]) {
      messenger.setMockMethodCallHandler(MethodChannel(name), (call) async {
        if (name.endsWith('/events') && call.method == 'listen') {
          scheduleMicrotask(
            () => messenger.handlePlatformMessage(name, null, (_) {}),
          );
        }
        return null;
      });
    }
    await Supabase.initialize(
      url: 'https://example.supabase.test',
      anonKey: 'fixture',
      authOptions: const FlutterAuthClientOptions(
        detectSessionInUri: false,
        autoRefreshToken: false,
      ),
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response(
          '[]',
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    await loadMaatFlowVisualTestFonts();
  });

  setUp(() async {
    await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
    SharedPreferences.setMockInitialValues({
      VisitorPreferences.introSeenKey: true,
      VisitorPreferences.invitationSeenKey: true,
    });
    requests.clear();
    accountRequests = 0;
  });

  tearDownAll(() async => Supabase.instance.dispose());

  Future<void> mount(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: AccountAccess(
          signedIn: false,
          requestAccount: ({String? resumeLocation}) async {
            accountRequests++;
            return false;
          },
          child: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: Builder(
                builder: CalendarPage.buildQuickAddVisualReference,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }

  Future<void> enter(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(_inputKey), text);
    await tester.pump();
  }

  Future<void> tapSubmit(WidgetTester tester) async {
    final action = find.byKey(_submitKey);
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pumpAndSettle();
  }

  void expectAction(WidgetTester tester, String label) {
    expect(
      find.descendant(of: find.byKey(_submitKey), matching: find.text(label)),
      findsOneWidget,
    );
    final semanticAction = find.bySemanticsLabel(label);
    expect(semanticAction, findsOneWidget);
    final semantics = tester.getSemantics(semanticAction);
    expect(semantics.label, label);
    expect(semantics.getSemanticsData().flagsCollection.isButton, isTrue);
    expect(semantics.getSemanticsData().flagsCollection.isEnabled, isTrue);
    expect(
      semantics.getSemanticsData().hasAction(ui.SemanticsAction.tap),
      isTrue,
    );
  }

  testWidgets(
    'empty action has exact Ask label and no separate question help button',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await mount(tester);
        expectAction(tester, 'ask hAw');
        expect(find.text('Quick add'), findsNothing);
        expect(find.byTooltip('How to ask ḥꜣw'), findsNothing);
        expect(find.byIcon(Icons.help_outline), findsNothing);
        expect(find.text('?'), findsNothing);
        expect(find.text('JOURNAL'), findsOneWidget);
        expect(find.text('PLANNER'), findsOneWidget);
        expect(find.text('Open full editor'), findsOneWidget);
        expect(accountRequests, 0);
        expect(requests, isEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'typing event, question and empty updates visible and semantic action together',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await mount(tester);
        for (final (text, label) in [
          ('Dentist Friday at 3', 'Quick add'),
          ('What is a decan?', 'ask hAw'),
          ('', 'ask hAw'),
          ('  ', 'ask hAw'),
          ('call mom', 'Quick add'),
          ('Find reading flows', 'ask hAw'),
          ('Why is the sky green?', 'ask hAw'),
          ('dinner with Mike at 6pm in Beverly Hills', 'Quick add'),
          ('', 'ask hAw'),
        ]) {
          await enter(tester, text);
          expectAction(tester, label);
          expect(find.byKey(const ValueKey('ask-haw-response')), findsNothing);
        }
        expect(accountRequests, 0);
        expect(requests, isEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'question action explains without entering event or account path',
    (tester) async {
      await mount(tester);
      await enter(tester, 'What is a decan?');
      await tapSubmit(tester);
      expect(find.byKey(const ValueKey('ask-haw-response')), findsOneWidget);
      expect(find.text('Decans'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('ask-haw-option-open:library:decans')),
        findsOneWidget,
      );
      expect(find.byKey(_submitKey), findsNothing);
      expect(
        tester.widget<TextField>(find.byKey(_inputKey)).controller!.text,
        'What is a decan?',
      );
      expect(accountRequests, 0);
      expect(requests, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'editing an answer restores the matching event action and retains denied guest draft',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await mount(tester);
        await enter(tester, 'What is a decan?');
        await tapSubmit(tester);
        expect(find.text('Decans'), findsOneWidget);
        await enter(tester, 'Dentist Friday at 3');
        expect(find.byKey(const ValueKey('ask-haw-response')), findsNothing);
        expectAction(tester, 'Quick add');
        await tapSubmit(tester);
        expect(
          accountRequests,
          1,
          reason: 'The existing event account guard owns submission.',
        );
        expect(requests, isEmpty);
        expect(find.byKey(const ValueKey('ask-haw-response')), findsNothing);
        expect(
          tester.widget<TextField>(find.byKey(_inputKey)).controller!.text,
          'Dentist Friday at 3',
        );
        expectAction(tester, 'Quick add');
        await enter(tester, '');
        expectAction(tester, 'ask hAw');
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'editing unsupported answer and keyboard submit use the same Ask classification',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await mount(tester);
        await enter(tester, 'Why is the sky green?');
        await tapSubmit(tester);
        expect(find.text('Try a more specific request'), findsOneWidget);
        expect(accountRequests, 0);
        await enter(tester, 'What is a decan?');
        expect(find.text('Try a more specific request'), findsNothing);
        expectAction(tester, 'ask hAw');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(find.text('Decans'), findsOneWidget);
        expect(accountRequests, 0);
        expect(requests, isEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );
}
