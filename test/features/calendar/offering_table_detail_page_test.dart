import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:mobile/features/calendar/follow_the_sky/presentation/widgets/follow_sky_v11_tokens.dart';
import 'package:mobile/features/calendar/presentation/maat_flow_detail_shell.dart';
import 'package:mobile/features/calendar/the_offering_table/presentation/offering_table_detail_page.dart';
import 'package:mobile/features/calendar/the_offering_table_flow.dart';
import 'package:mobile/features/calendar/track_sky_flow.dart';

void main() {
  tearDown(resetMaatFlowJoinedStateForTesting);

  testWidgets('catalog route opens the dedicated warm shared-shell detail', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: buildMaatFlowTemplateDetailPreviewForTesting(
          templateKey: kOfferingTableFlowKey,
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(OfferingTableDetailPage), findsOneWidget);
    expect(find.byType(MaatFlowDetailShell), findsOneWidget);
    expect(find.text('The Offering\nTable'), findsOneWidget);
    expect(find.text(kOfferingTableTagline), findsOneWidget);
    expect(find.text(kOfferingTableGlyph), findsOneWidget);
    expect(find.text('Personal Table'), findsOneWidget);
    expect(find.text('Household Table'), findsOneWidget);
    expect(find.text('Flowing Table'), findsOneWidget);
    expect(find.text('Day 1: The First Water'), findsOneWidget);
    expect(find.text('What was fed?'), findsOneWidget);
    expect(find.text('What did you provide today?'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('offering-table-day-6')),
      findsNothing,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('offering-table-show-all')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('offering-table-show-all')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('offering-table-day-6')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('offering-table-day-30')),
      findsOneWidget,
    );
  });

  testWidgets('join forwards selected date, lens, timezone, and no-cup mode', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final selectedDate = DateTime(2026, 9, 3);
    DateTime? joinedDate;
    TrackSkyTimeZone? joinedTimezone;
    OfferingTableLens? joinedLens;
    bool? joinedNoCupMode;

    await tester.pumpWidget(
      MaterialApp(
        home: OfferingTableDetailPage(
          timezone: TrackSkyTimeZone.eastern,
          initialStartDate: selectedDate,
          showBackButton: false,
          onJoin:
              ({
                required startDate,
                required timezone,
                required lens,
                required noCupMode,
              }) async {
                joinedDate = startDate;
                joinedTimezone = timezone;
                joinedLens = lens;
                joinedNoCupMode = noCupMode;
                return 41;
              },
        ),
      ),
    );
    await tester.pump();

    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('offering-table-lens-hapy')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('offering-table-lens-hapy')),
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('offering-table-no-cup')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('offering-table-join')));
    await tester.pumpAndSettle();

    expect(joinedDate, selectedDate);
    expect(joinedTimezone, TrackSkyTimeZone.eastern);
    expect(joinedLens, OfferingTableLens.hapy);
    expect(joinedNoCupMode, isTrue);
    expect(
      find.byKey(const ValueKey<String>('offering-table-joined')),
      findsOneWidget,
    );
  });

  testWidgets('narrow layout remains overflow-free', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: OfferingTableDetailPage(
          timezone: TrackSkyTimeZone.pacific,
          initialStartDate: DateTime(2026, 9, 3),
          showBackButton: false,
          onJoin:
              ({
                required startDate,
                required timezone,
                required lens,
                required noCupMode,
              }) async => 1,
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  test('Offering Table retains a distinct theme from Follow the Sky', () {
    expect(
      OfferingTableDetailTokens.theme.pageBackground,
      isNot(FollowSkyV11Tokens.detailTheme.pageBackground),
    );
    expect(
      OfferingTableDetailTokens.theme.glow,
      isNot(FollowSkyV11Tokens.detailTheme.glow),
    );
  });
}
