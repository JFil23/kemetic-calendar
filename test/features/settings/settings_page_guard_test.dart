import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('settings page guard', () {
    late String source;

    setUpAll(() async {
      source = await File(
        'lib/features/settings/settings_page.dart',
      ).readAsString();
    });

    test('app bar sign-out action signs out and routes through auth gate', () {
      expect(source, contains("import 'package:go_router/go_router.dart';"));

      final signOut = _sourceBetween(
        source,
        'Future<void> _signOut() async {',
        '\n  @override\n  void initState',
      );
      expect(
        signOut,
        contains('await Supabase.instance.client.auth.signOut();'),
      );
      expect(signOut, contains("context.go('/');"));
      expect(signOut, contains("'Could not sign out. Please try again.'"));

      final appBar = _sourceBetween(
        source,
        'appBar: AppBar(',
        '),\n      body: SingleChildScrollView(',
      );
      expect(appBar, contains('centerTitle: true'));
      expect(appBar, contains("tooltip: 'Sign out'"));
      expect(appBar, contains('Icons.logout'));
      expect(appBar, contains('onPressed: _signingOut ? null : _signOut'));
    });

    test('scroll padding clears the global bottom menu', () {
      expect(
        source,
        contains("import '../../core/global_bottom_menu_metrics.dart';"),
      );
      expect(
        source,
        contains(
          'final scrollBottomPadding = bottomPaddingAboveGlobalMenu(context, 32);',
        ),
      );

      final scrollView = _sourceBetween(
        source,
        'body: SingleChildScrollView(',
        'child: Column(',
      );
      expect(
        scrollView,
        contains('EdgeInsets.fromLTRB(16, 12, 16, scrollBottomPadding)'),
      );
      expect(
        scrollView,
        isNot(contains('EdgeInsets.fromLTRB(16, 12, 16, 24)')),
      );
    });
  });
}

String _sourceBetween(String source, String start, String end) {
  final startIndex = source.indexOf(start);
  expect(startIndex, isNonNegative, reason: 'Missing source start: $start');
  final endIndex = source.indexOf(end, startIndex + start.length);
  expect(endIndex, isNonNegative, reason: 'Missing source end: $end');
  return source.substring(startIndex, endIndex);
}
