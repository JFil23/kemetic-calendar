import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/auth/account_invitation_dialog.dart';
import 'package:mobile/features/auth/guest_experience_host.dart';
import 'package:mobile/features/auth/visitor_preferences.dart';
import 'package:mobile/features/profile/flow_post_caption_sheet.dart';
import 'guest_experience_test.dart' show flush;
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:mobile/features/inbox/inbox_conversation_page.dart';
import 'package:mobile/features/inbox/inbox_dm_conversation_page.dart';
import 'package:mobile/features/inbox/conversation_user.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final requests = <http.Request>[];
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'fixture',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((r) async {
        requests.add(r);
        return http.Response(
          '[]',
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  });
  tearDownAll(() => Supabase.instance.dispose());
  for (final location in [
    '/flows',
    '/flows?mode=myFlows',
    '/flows?mode=maatFlows',
    '/flows?create=flow',
    '/inbox/conversation/person',
    '/inbox/dm/thread',
    '/post-draft',
  ]) {
    testWidgets(
      'canonical guest owner $location does not read private data or invite on open',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          VisitorPreferences.introSeenKey: true,
          VisitorPreferences.invitationSeenKey: true,
        });
        requests.clear();
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final uri = Uri.parse(location);
        final router = GoRouter(
          initialLocation: location,
          routes: [
            GoRoute(
              path: uri.path,
              builder: (_, state) => uri.path == '/post-draft'
                  ? Builder(
                      builder: (context) => Scaffold(
                        body: TextButton(
                          onPressed: () => showFlowPostCaptionSheet(
                            context: context,
                            actionLabel: 'Post',
                          ),
                          child: const Text('Write post'),
                        ),
                      ),
                    )
                  : uri.path == '/flows'
                  ? CalendarPage.buildFlowStudioRoutePage(routeUri: state.uri)
                  : uri.path.contains('/conversation/')
                  ? InboxConversationPage(
                      otherUserId: 'person',
                      otherProfile: ConversationUser(id: 'person'),
                    )
                  : const InboxDmConversationPage(conversationId: 'thread'),
            ),
          ],
        );
        await tester.pumpWidget(
          MaterialApp.router(
            theme: AppTheme.dark,
            routerConfig: router,
            builder: (_, child) => GuestExperienceHost(
              router: router,
              onGoogleSignIn: (_) async {},
              child: child!,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AccountInvitationDialog), findsNothing);
        expect(
          requests,
          isEmpty,
          reason: 'No private reads or guest writes may start on mount',
        );
        expect(tester.takeException(), isNull);
        if (uri.path == '/post-draft') {
          await tester.tap(find.text('Write post'));
          await tester.pumpAndSettle();
          expect(find.byType(AccountInvitationDialog), findsNothing);
        }
        if (uri.queryParameters['create'] == 'flow') {
          await tester.tap(find.text('Build').hitTestable());
          await tester.pumpAndSettle();
          expect(find.byType(AccountInvitationDialog), findsNothing);
        }
        if (uri.path != '/flows' || uri.queryParameters['create'] == 'flow') {
          final field = find.byType(TextField).first;
          await tester.enterText(field, 'Guest draft kept here');
          await tester.pump();
          expect(
            tester.widget<TextField>(field).controller!.text,
            'Guest draft kept here',
          );
          expect(find.byType(AccountInvitationDialog), findsNothing);
          expect(requests, isEmpty);
          final action = uri.path == '/post-draft'
              ? find.byKey(const ValueKey('flow-post-caption-submit'))
              : uri.path == '/flows'
              ? find.text('Save').hitTestable()
              : find.byIcon(Icons.send);
          await tester.ensureVisible(action);
          await tester.tap(action);
          await flush(tester);
          expect(find.byType(AccountInvitationDialog), findsOneWidget);
          expect(
            requests,
            isEmpty,
            reason: 'Commit must wait for authentication',
          );
          await tester.tap(find.byTooltip('Keep exploring'));
          await tester.pumpAndSettle();
          expect(find.byType(AccountInvitationDialog), findsNothing);
          expect(
            tester.widget<TextField>(field).controller!.text,
            'Guest draft kept here',
          );
          expect(requests, isEmpty);
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
        await Supabase.instance.client.removeAllChannels();
        router.dispose();
      },
    );
  }
}
