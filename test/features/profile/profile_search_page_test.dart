import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/profile/profile_search_page.dart';
import 'package:mobile/widgets/keyboard_aware.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> _ensureSupabaseInitialized() async {
  try {
    Supabase.instance.client;
    return;
  } catch (_) {}

  await Supabase.initialize(
    url: 'https://example.supabase.co',
    anonKey: 'anon-key-0123456789012345678901234567890123456789',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await _ensureSupabaseInitialized();
  });

  testWidgets('uses scaffold resize instead of extra keyboard padding', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: ProfileSearchPage(
          titleText: 'New Message',
          hintText: 'Search people to message',
          fallbackLocation: '/inbox',
          selectionMode: 'conversation',
        ),
      ),
    );
    await tester.pump();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.resizeToAvoidBottomInset, isTrue);
    expect(scaffold.body, isA<Padding>());

    final bodyPadding = scaffold.body! as Padding;
    expect(bodyPadding.padding, const EdgeInsets.all(20));

    final searchField = tester.widget<TextField>(find.byType(TextField));
    expect(searchField.scrollPadding, keyboardManagedTextFieldScrollPadding);
    expect(tester.takeException(), isNull);
  });
}
