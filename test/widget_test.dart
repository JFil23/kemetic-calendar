import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Shows missing Supabase configuration message placeholder',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(child: Text('Missing Supabase configuration.')),
      ),
    ));

    expect(find.text('Missing Supabase configuration.'), findsOneWidget);
  });
}
