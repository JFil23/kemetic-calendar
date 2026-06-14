import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_page.dart';

void main() {
  tearDown(resetMaatFlowJoinedStateForTesting);

  test(
    'Ma’at joined accounting recognizes active Follow the sky rows by name',
    () {
      expect(
        maatFlowTemplateMatchesActiveFlowForTesting(
          templateKey: 'track-the-sky',
          flowName: 'Follow the sky',
        ),
        isTrue,
      );
      expect(
        maatFlowTemplateMatchesActiveFlowForTesting(
          templateKey: 'track-the-sky',
          flowName: 'Follow the sky',
          active: false,
        ),
        isFalse,
      );
      expect(
        maatFlowTemplateMatchesActiveFlowForTesting(
          templateKey: 'track-the-sky',
          flowName: 'Follow the sky',
          isHidden: true,
        ),
        isFalse,
      );
    },
  );

  test('Ma’at joined accounting keeps explicit metadata authoritative', () {
    expect(
      maatFlowTemplateMatchesActiveFlowForTesting(
        templateKey: 'track-the-sky',
        flowName: 'Follow the sky',
        flowNotes: 'maat=the-weighing',
      ),
      isFalse,
    );
    expect(
      maatFlowTemplateMatchesActiveFlowForTesting(
        templateKey: 'the-weighing',
        flowName: 'Follow the sky',
        flowNotes: 'maat=the-weighing',
      ),
      isTrue,
    );
  });

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

    final exception = tester.takeException();
    if (exception is FlutterError) {
      for (final diagnostic in exception.diagnostics) {
        debugPrint(diagnostic.toStringDeep());
      }
    }
    expect(exception, isNull);
    expect(find.text("Ma'at Flows"), findsOneWidget);
    expect(find.text('NOT YET JOINED'), findsOneWidget);
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

  testWidgets('Ma’at flows back button delegates to route close handler', (
    tester,
  ) async {
    var closed = false;
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: buildMaatFlowsListPreviewForTesting(
          onClose: () {
            closed = true;
          },
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Back'));
    await tester.pump();

    expect(closed, isTrue);
  });

  testWidgets('Ma’at flows back button pops the nested Flow Studio route', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Navigator(
          key: navigatorKey,
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => const Center(child: Text('Flow Studio hub')),
          ),
        ),
      ),
    );
    await tester.pump();

    unawaited(
      navigatorKey.currentState!.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => buildMaatFlowsListPreviewForTesting(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text("Ma'at Flows"), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Flow Studio hub'), findsOneWidget);
    expect(find.text("Ma'at Flows"), findsNothing);
  });

  testWidgets(
    'Ma’at flows back button closes the sheet when it is the first nested route',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () {
                  showModalBottomSheet<void>(
                    context: context,
                    useRootNavigator: true,
                    isScrollControlled: true,
                    builder: (_) => SizedBox(
                      height: 700,
                      child: Navigator(
                        onGenerateRoute: (_) => MaterialPageRoute<void>(
                          builder: (_) => buildMaatFlowsListPreviewForTesting(),
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('Open Ma’at flows'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Open Ma’at flows'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text("Ma'at Flows"), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text("Ma'at Flows"), findsNothing);
      expect(find.text('Open Ma’at flows'), findsOneWidget);
    },
  );

  testWidgets('Ma’at flows plus button delegates to create flow handler', (
    tester,
  ) async {
    var createCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: buildMaatFlowsListPreviewForTesting(
          onCreateNew: () {
            createCount += 1;
          },
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('New flow'));
    await tester.pump();

    expect(createCount, 1);
  });

  testWidgets('The Weighing detail lays out its overview body', (tester) async {
    tester.view.physicalSize = const Size(768, 1536);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: buildMaatFlowTemplateDetailPreviewForTesting(),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Sit with what is true.'), findsOneWidget);
    expect(find.text('THREE-DECAN ARC'), findsOneWidget);
    expect(find.text('Join Flow'), findsOneWidget);
  });

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
    expect(find.text('NOT YET JOINED'), findsOneWidget);
  });
}
