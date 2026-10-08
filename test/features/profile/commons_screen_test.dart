import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/data/account_view_cache.dart';
import 'package:mobile/data/commons_question_selection.dart';
import 'package:mobile/data/warm_state/warm_snapshot_store.dart';
import 'package:mobile/features/profile/profile_page.dart';
import 'package:mobile/features/profile/commons_question_block.dart';
import 'package:mobile/services/app_restoration_service.dart';
import 'package:mobile/services/app_window_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/profile_post_removal_test.dart' show session;
import '../../support/maat_flow_visual_test_fonts.dart';

void main() {
  const owner = 'commons-screen-owner';
  var olderReads = 0;
  var failNextPage = true;
  var saved = false;
  late String question;
  Map<String, dynamic> answer(int n, {String? body, bool mine = false}) => {
    'id': 'answer-$n',
    'question_id': question,
    'user_id': mine ? owner : 'person-$n',
    'body_text': body ?? 'Public reflection number $n',
    'is_mine': mine,
    'author_display_name': 'Practitioner $n',
    'created_at': '2026-10-06T12:00:${n.toString().padLeft(2, '0')}.123456Z',
  };
  setUpAll(() async {
    await loadMaatFlowVisualTestFonts();
    SharedPreferences.setMockInitialValues({});
    question = commonsQuestionSeed(DateTime.now()).id;
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'fixture-key',
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
      ),
      httpClient: MockClient((r) async {
        Object? data = [];
        var status = 200;
        switch (r.url.path.split('/').last) {
          case 'profile_stats':
            data = {
              'id': owner,
              'display_name': 'Commons fixture',
              'handle': 'commonsfixture',
            };
          case 'get_commons_together_home_cards':
            if (saved) {
              status = 400;
              data = {'message': 'refresh unavailable'};
            } else {
              data = {
                'rhythm': {
                  'scope': 'following',
                  'active_users_today': 2,
                  'flows_kept_today': 7,
                  'public_fragments_today': 3,
                  'public_rooms_open': 1,
                },
                'questions': [
                  {
                    'id': question,
                    'question': 'What do I know now?',
                    'answers': List.generate(12, (i) => answer(30 - i)),
                    'answers_has_more': true,
                  },
                ],
              };
            }
          case 'get_commons_question_answers':
            olderReads++;
            if (failNextPage) {
              failNextPage = false;
              status = 400;
              data = {'message': 'try again'};
            } else {
              data = {
                'answers': List.generate(14, (i) => answer(18 - i)),
                'has_more': false,
              };
            }
          case 'answer_commons_question':
            expect(
              jsonDecode(r.body)['p_question_text'],
              commonsQuestionSeed(DateTime.now()).text,
            );
            saved = true;
            data = answer(
              31,
              body: jsonDecode(r.body)['p_body'] as String,
              mine: true,
            );
        }
        return http.Response(
          jsonEncode(data),
          status,
          headers: {'content-type': 'application/json'},
          request: r,
        );
      }),
    );
  });
  tearDownAll(() => Supabase.instance.dispose());
  Future<void> drain(WidgetTester tester) async {
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 30));
    }
  }

  testWidgets(
    'Commons exposes every page, retries without losing answers, and displays acknowledged publication',
    (tester) async {
      AppRestorationService.debugUserIdResolver = () => owner;
      AppWindowService.debugWindowIdResolver = () async => 'commons-screen';
      AppRestorationService.debugRemoteSnapshotWriter = (_, _, _, _) async {};
      await tester.runAsync(() async {
        await Supabase.instance.client.auth.recoverSession(session(owner));
        AccountViewCache.instance.enterAccount(owner);
      });
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'Inter'),
          home: const ProfilePage(
            userId: owner,
            isMyProfile: true,
            initialFeedRevealed: true,
          ),
        ),
      );
      await drain(tester);
      expect(find.text(commonsQuestionSeed(DateTime.now()).text), findsWidgets);
      expect(find.text('What do I know now?'), findsNothing);
      expect(find.text('7'), findsWidgets);
      expect(find.text('Public reflection number 19'), findsOneWidget);
      await tester.ensureVisible(find.text('Show more answers'));
      await drain(tester);
      await tester.tap(find.text('Show more answers'));
      await drain(tester);
      expect(
        find.text('Could not load more answers. Please try again.'),
        findsOneWidget,
      );
      expect(find.text('Public reflection number 30'), findsOneWidget);
      await tester.ensureVisible(find.text('Show more answers'));
      await drain(tester);
      await tester.tap(find.text('Show more answers'));
      await drain(tester);
      expect(olderReads, 2);
      expect(find.text('Public reflection number 5'), findsOneWidget);
      expect(find.text('Public reflection number 30'), findsOneWidget);
      expect(find.text('Show more answers'), findsNothing);
      final editor = find.descendant(
        of: find.byType(CommonsAnswerComposer),
        matching: find.byType(TextField),
      );
      await tester.ensureVisible(editor);
      await drain(tester);
      await tester.enterText(editor, 'A public reflection from this screen.');
      await tester.ensureVisible(find.text('Save public answer'));
      await drain(tester);
      await tester.tap(find.text('Save public answer'));
      await drain(tester);
      expect(
        find.text('A public reflection from this screen.'),
        findsOneWidget,
      );
      expect(find.text('Edit answer'), findsOneWidget);
      expect(
        find.text('Commons could not refresh. Please try again.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await drain(tester);
      final flush = AppRestorationService.instance.flushPendingWrites();
      await drain(tester);
      await flush;
      final warmFlush = WarmSnapshotStore.instance.flushed;
      await drain(tester);
      await warmFlush;
      tester.view.reset();
    },
  );
}
