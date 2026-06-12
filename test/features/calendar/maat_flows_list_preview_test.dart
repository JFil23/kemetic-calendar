import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_page.dart';

void main() {
  tearDown(resetMaatFlowJoinedStateForTesting);

  testWidgets('Ma’at flows list groups joined flows above waiting flows', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(786, 1566);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: buildMaatFlowsListPreviewForTesting(
          joinedKeys: const <String>{'the-weighing', 'track-the-sky'},
          completionCounts: const <String, (int total, int remaining)>{
            'the-weighing': (12, 7),
            'track-the-sky': (10, 4),
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.takeException(), isNull);
    expect(find.text("Ma'at Flows"), findsOneWidget);
    expect(find.text('N O T  Y E T  J O I N E D'), findsOneWidget);
    expect(find.text('5 of 12'), findsOneWidget);
    expect(find.text('6 of 10'), findsOneWidget);
    expect(find.text('3 of 10'), findsNothing);
    expect(find.text('30%'), findsNothing);
    expect(find.text('The Weighing'), findsOneWidget);
    expect(find.text('Follow the sky'), findsOneWidget);
    expect(find.text('Dawn House Rite'), findsOneWidget);
  });

  testWidgets(
    'Ma’at joined card without counts shows active, not fake progress',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: buildMaatFlowsListPreviewForTesting(
            joinedKeys: const <String>{'the-weighing', 'track-the-sky'},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('active'), findsWidgets);
      expect(find.text('3 of 10'), findsNothing);
      expect(find.text('30%'), findsNothing);
    },
  );

  testWidgets('successful join cannot be overridden by stale joined keys', (
    tester,
  ) async {
    Future<int?> joinTemplate(String key) async {
      return key == 'dawn-house-rite' ? 441 : null;
    }

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: buildMaatFlowsListPreviewForTesting(onPickTemplate: joinTemplate),
      ),
    );
    await tester.pump();

    expect(find.text('active'), findsNothing);
    await tester.tap(find.text('Dawn House Rite'));
    await tester.pumpAndSettle();
    expect(find.text('active'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: buildMaatFlowsListPreviewForTesting(
          joinedKeys: const <String>{},
          onPickTemplate: joinTemplate,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('active'), findsOneWidget);
    expect(find.text('N O T  Y E T  J O I N E D'), findsOneWidget);
  });
}
