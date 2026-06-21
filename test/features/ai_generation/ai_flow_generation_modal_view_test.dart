import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/ai_generation/ai_flow_generation_modal.dart';
import 'package:mobile/features/calendar/calendar_page.dart' show CalendarPage;
import 'package:mobile/features/calendar/kemetic_month_metadata.dart';
import 'package:mobile/widgets/kemetic_date_picker.dart';
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

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('AI generator hides color picker', (tester) async {
    _useLargeSurface(tester);

    await _openAiFlowModal(tester);

    expect(find.text('Generate with AI'), findsOneWidget);
    expect(find.text('Color'), findsNothing);
  });

  testWidgets('AI generator toggle uses Flow Studio segmented styling', (
    tester,
  ) async {
    _useLargeSurface(tester);

    await _openAiFlowModal(tester);

    final toggle = tester.widget<CupertinoSegmentedControl<CalendarMode>>(
      find.byWidgetPredicate(
        (widget) => widget is CupertinoSegmentedControl<CalendarMode>,
      ),
    );

    expect(toggle.padding, const EdgeInsets.all(2));
    expect(toggle.selectedColor, isNull);
    expect(toggle.borderColor, isNull);
    expect(toggle.unselectedColor, isNull);
  });

  testWidgets('manual Flow Studio still shows color picker', (tester) async {
    _useLargeSurface(tester);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return Center(
                child: ElevatedButton(
                  onPressed: () {
                    unawaited(
                      CalendarPage.openFlowStudioFromAnyContext(
                        context,
                        restorationState: const <String, dynamic>{
                          'mode': 'editor',
                        },
                      ),
                    );
                  },
                  child: const Text('Open Flow Studio'),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Flow Studio'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Flow Studio'), findsOneWidget);
    expect(find.text('COLOR'), findsOneWidget);
  });

  testWidgets(
    'AI generator date toggle changes visible date display without changing duration',
    (tester) async {
      _useLargeSurface(tester);

      final start = DateTime(2026, 6, 3);
      final end = DateTime(2026, 6, 12);
      await _openAiFlowModal(
        tester,
        initialStartDate: start,
        initialEndDate: end,
        initialDateRangeIsManual: true,
      );

      expect(find.text('Jun 3'), findsOneWidget);
      expect(find.text('Jun 12'), findsOneWidget);
      expect(find.text('Duration: 10 days'), findsOneWidget);

      await tester.tap(find.text('Kemetic'));
      await tester.pumpAndSettle();

      expect(find.text('Jun 3'), findsNothing);
      expect(find.text('Jun 12'), findsNothing);
      expect(find.text(_kemeticDateLabel(start)), findsOneWidget);
      expect(find.text(_kemeticDateLabel(end)), findsOneWidget);
      expect(find.text('Duration: 10 days'), findsOneWidget);

      await tester.tap(find.text('Gregorian'));
      await tester.pumpAndSettle();

      expect(find.text('Jun 3'), findsOneWidget);
      expect(find.text('Jun 12'), findsOneWidget);
      expect(find.text('Duration: 10 days'), findsOneWidget);
    },
  );

  testWidgets(
    'AI generator Gregorian start picker preserves cancel and done contract',
    (tester) async {
      _useSmallPhoneSurface(tester);

      await _openAiFlowModal(
        tester,
        initialStartDate: DateTime(2026, 6, 3),
        initialEndDate: DateTime(2026, 6, 12),
        initialDateRangeIsManual: true,
      );

      expect(find.text('Jun 3'), findsOneWidget);
      expect(find.text('Duration: 10 days'), findsOneWidget);

      await tester.tap(find.text('Jun 3'));
      await tester.pumpAndSettle();

      expect(find.text('Pick Gregorian date'), findsOneWidget);
      expect(find.text('Gregorian Calendar'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Jun 3'), findsOneWidget);
      expect(find.text('Duration: 10 days'), findsOneWidget);

      await tester.tap(find.text('Jun 3'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(find.text('Jun 3'), findsOneWidget);
      expect(find.text('Duration: 10 days'), findsOneWidget);
    },
  );

  testWidgets(
    'AI generator Kemetic start picker opens through app Kemetic wrapper',
    (tester) async {
      _useSmallPhoneSurface(tester);

      final start = DateTime(2025, 3, 20);
      final end = DateTime(2025, 3, 29);
      await _openAiFlowModal(
        tester,
        initialStartDate: start,
        initialEndDate: end,
        initialDateRangeIsManual: true,
      );

      await tester.tap(find.text('Kemetic'));
      await tester.pumpAndSettle();

      final startLabel = _kemeticDateLabel(start);
      expect(find.text(startLabel), findsOneWidget);

      await tester.tap(find.text(startLabel));
      await tester.pumpAndSettle();

      expect(find.text('Pick Kemetic date'), findsOneWidget);
      expect(find.text('Kemetic Calendar'), findsOneWidget);
      expect(find.text(getMonthById(1).displayFull), findsWidgets);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(find.text(startLabel), findsOneWidget);
      expect(find.text('Duration: 10 days'), findsOneWidget);
    },
  );
}

Future<void> _openAiFlowModal(
  WidgetTester tester, {
  DateTime? initialStartDate,
  DateTime? initialEndDate,
  bool initialDateRangeIsManual = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return Center(
              child: ElevatedButton(
                onPressed: () {
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => AIFlowGenerationModal(
                      initialStartDate: initialStartDate,
                      initialEndDate: initialEndDate,
                      initialDateRangeIsManual: initialDateRangeIsManual,
                    ),
                  );
                },
                child: const Text('Open AI modal'),
              ),
            );
          },
        ),
      ),
    ),
  );

  await tester.tap(find.text('Open AI modal'));
  await tester.pumpAndSettle();
}

String _kemeticDateLabel(DateTime date) {
  final k = KemeticMath.fromGregorian(date);
  return '${getMonthById(k.kMonth).displayShort} ${k.kDay}';
}

void _useLargeSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void _useSmallPhoneSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
