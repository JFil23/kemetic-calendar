import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:mobile/features/calendar/maat_flow_catalog.dart';
import 'package:mobile/features/calendar/maat_flow_identity.dart';

void main() {
  setUp(EndFlowVisibilityStore.instance.debugReset);
  tearDown(() {
    EndFlowVisibilityStore.instance.debugReset();
    resetMaatFlowJoinedStateForTesting();
  });

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

  test('ended filing rows do not keep Ma’at templates joined', () {
    expect(
      maatFlowFilingSnapshotMarksInstanceActiveForTesting(
        visibleInActiveList: false,
      ),
      isFalse,
    );
    expect(
      maatFlowFilingSnapshotMarksInstanceActiveForTesting(
        visibleInActiveList: true,
      ),
      isTrue,
    );
  });

  test('Ma’at joined accounting always applies the visibility overlay', () {
    EndFlowVisibilityStore.instance.markPending(1);
    expect(
      maatFlowFilingSnapshotMarksInstanceActiveForTesting(
        visibleInActiveList: true,
      ),
      isFalse,
    );

    EndFlowVisibilityStore.instance.removePending(1);
    expect(
      maatFlowFilingSnapshotMarksInstanceActiveForTesting(
        visibleInActiveList: true,
      ),
      isTrue,
    );

    EndFlowVisibilityStore.instance.markCommitted(1);
    expect(
      maatFlowFilingSnapshotMarksInstanceActiveForTesting(
        visibleInActiveList: true,
      ),
      isFalse,
    );
  });

  testWidgets('Ma’at product catalog renders exactly the four active flows', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 16000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const expectedTitles = <String, String>{
      'track-the-sky': 'Follow the Sky',
      'the-offering-table': 'The Offering Table',
      'the-djed': 'The Djed',
      'the-reading-house': 'The Reading House',
    };

    expect(
      knownMaatFlowTemplateKeysForTesting(),
      hasLength(
        MaatFlowKind.values.length - kArchivedCompatibilityMaatFlowKinds.length,
      ),
    );
    expect(
      coreMaatFlowTemplateKeysForTesting().toSet(),
      expectedTitles.keys.toSet(),
    );
    expect(coreMaatFlowTemplateTitlesForTesting(), expectedTitles);
    expect(knownMaatFlowCategoryForTesting('the-moon-return'), isNotNull);
    expect(knownMaatFlowCategoryForTesting('the-course'), isNotNull);
    expect(knownMaatFlowCategoryForTesting('the-decan-watch'), isNotNull);

    await tester.pumpWidget(
      MaterialApp(home: buildMaatFlowsListPreviewForTesting()),
    );
    await tester.pump();

    for (final key in expectedTitles.keys) {
      expect(
        find.byKey(ValueKey<String>('maat-flow-discovery-card-$key')),
        findsOneWidget,
        reason: key,
      );
    }
    for (final key in <String>[
      'dawn-house-rite',
      'evening-threshold-rite',
      'the-weighing',
      'the-kept-word',
      'the-tending',
      'the-first-arrangement',
      'the-clearing',
      'the-wag',
      'the-days-outside-the-year',
    ]) {
      expect(
        find.byKey(ValueKey<String>('maat-flow-discovery-card-$key')),
        findsNothing,
        reason: key,
      );
    }
    expect(find.byKey(kMaatFlowCategoryDailyRhythmTabKey), findsNothing);
    expect(find.byKey(kMaatFlowCategoryInnerWorkTabKey), findsNothing);
    expect(find.byKey(kMaatFlowCategoryLivingInMaatTabKey), findsNothing);
  });

  testWidgets(
    'discovery remains a four-flow catalog regardless of joined rows',
    (tester) async {
      tester.view.physicalSize = const Size(786, 1566);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: buildMaatFlowsListPreviewForTesting(
            joinedKeys: const <String>{'track-the-sky'},
            completionCounts: const <String, (int total, int remaining)>{
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
      expect(find.text('Flows'), findsOneWidget);
      expect(find.text('NOT YET JOINED'), findsNothing);
      expect(find.text('6 of 10'), findsNothing);
      expect(find.text('Follow the Sky'), findsOneWidget);
      expect(find.text('The Weighing'), findsNothing);
      final djedCard = find.byKey(
        const ValueKey<String>('maat-flow-discovery-card-the-djed'),
      );
      await tester.scrollUntilVisible(
        djedCard,
        500,
        scrollable: find.byType(Scrollable).first,
      );
      expect(djedCard, findsOneWidget);
    },
  );

  testWidgets(
    'Ma’at flow cards show the complete description and grow when it wraps',
    (tester) async {
      const description =
          'The sky keeps moving. What you’re working toward moves with it.';
      tester.view.physicalSize = const Size(760, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: buildMaatFlowsListPreviewForTesting(
            joinedKeys: const <String>{'track-the-sky'},
          ),
        ),
      );
      await tester.pump();

      final descriptionFinder = find.text(description);
      expect(descriptionFinder, findsOneWidget);
      final cardFinder = find.byKey(
        const ValueKey<String>('maat-flow-discovery-card-track-the-sky'),
      );
      final wideCardHeight = tester.getSize(cardFinder).height;

      tester.view.physicalSize = const Size(393, 1000);
      await tester.pump();

      expect(find.text(description), findsOneWidget);
      final narrowCardHeight = tester.getSize(cardFinder).height;
      expect(narrowCardHeight, greaterThan(wideCardHeight));
    },
  );

  testWidgets(
    'Offering identity and full description remain clear at mobile widths',
    (tester) async {
      const description =
          'Declare your intention before the day asks anything of you.';
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Future<double> pumpAtWidth(double width) async {
        tester.view.physicalSize = Size(width, 16000);
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            home: buildMaatFlowsListPreviewForTesting(
              joinedKeys: const <String>{'the-offering-table'},
            ),
          ),
        );
        await tester.pump();

        final descriptionFinder = find.text(description);
        final cardFinder = find.byKey(
          const ValueKey<String>('maat-flow-discovery-card-the-offering-table'),
        );
        expect(descriptionFinder, findsOneWidget);
        expect(find.text('1 of 30'), findsNothing);
        expect(
          tester
              .getRect(cardFinder)
              .contains(tester.getRect(descriptionFinder).bottomRight),
          isTrue,
        );
        expect(tester.takeException(), isNull);
        return tester.getSize(cardFinder).height;
      }

      final normalHeight = await pumpAtWidth(390);
      final narrowHeight = await pumpAtWidth(320);
      expect(narrowHeight, greaterThan(normalHeight));
    },
  );

  testWidgets('archived flows and old category tabs stay out of discovery', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: buildMaatFlowsListPreviewForTesting(),
      ),
    );
    await tester.pump();

    expect(find.text('Dawn House Rite'), findsNothing);
    expect(find.text('Follow the Sky'), findsOneWidget);
    expect(find.text('The Weighing'), findsNothing);
    expect(find.byKey(kMaatFlowCategoryInnerWorkTabKey), findsNothing);
  });

  testWidgets('joined state does not alter the approved discovery cards', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: buildMaatFlowsListPreviewForTesting(
          joinedKeys: const <String>{'track-the-sky'},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('active'), findsNothing);
    expect(find.text('3 of 10'), findsNothing);
    expect(find.text('30%'), findsNothing);
    expect(find.text('Follow the Sky'), findsOneWidget);
  });

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

    expect(find.text('Flows'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Flow Studio hub'), findsOneWidget);
    expect(find.text('Flows'), findsNothing);
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

      expect(find.text('Flows'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Flows'), findsNothing);
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

    await tester.tap(find.byTooltip('Create a flow'));
    await tester.pump();

    expect(createCount, 1);
  });

  testWidgets('The Djed detail uses the approved v2 visual', (tester) async {
    tester.view.physicalSize = const Size(768, 1536);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: buildMaatFlowTemplateDetailPreviewForTesting(
          templateKey: 'the-djed',
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('The Djed'), findsOneWidget);
    expect(find.text('4 SUPPORTS'), findsOneWidget);
    expect(find.text('9 SITTINGS'), findsOneWidget);
    expect(find.text('Join Flow'), findsNothing);
  });

  testWidgets(
    'active template detail reflects joined state and disables join',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: buildMaatFlowTemplateDetailPreviewForTesting(
            templateKey: 'the-djed',
            joinedStartDate: DateTime(2026, 9, 1),
          ),
        ),
      );

      expect(find.text('Carried in My Flows'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('djed-carried')),
        findsOneWidget,
      );
    },
  );

  testWidgets('discovery opens only the selected active flow', (tester) async {
    final opened = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: buildMaatFlowsListPreviewForTesting(
          onPickTemplate: (key) async {
            opened.add(key);
            return null;
          },
        ),
      ),
    );

    final button = find.byKey(
      const ValueKey<String>('maat-flow-discovery-open-track-the-sky'),
    );
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(opened, <String>['track-the-sky']);
    expect(find.text('Carry this flow'), findsNothing);
  });

  testWidgets('archived joined keys cannot reappear through discovery state', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: buildMaatFlowsListPreviewForTesting(
          joinedKeys: const <String>{'dawn-house-rite'},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Dawn House Rite'), findsNothing);
    expect(find.text('The Weighing'), findsNothing);
    expect(find.text('Follow the Sky'), findsOneWidget);
    expect(coreMaatFlowTemplateKeysForTesting(), hasLength(4));
  });
}
