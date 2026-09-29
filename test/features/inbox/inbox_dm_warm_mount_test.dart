import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/features/inbox/inbox_dm_conversation_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'key',
      httpClient: MockClient(
        (request) async => http.Response(
          '[]',
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
  });
  testWidgets(
    'conversation mounts and changes identity with a stable message stream',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: InboxDmConversationPage(conversationId: 'first'),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('No messages yet'), findsOneWidget);
      await tester.pumpWidget(
        const MaterialApp(
          home: InboxDmConversationPage(conversationId: 'second'),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('No messages yet'), findsOneWidget);
    },
  );
  tearDownAll(() async => Supabase.instance.dispose());
}
