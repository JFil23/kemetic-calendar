import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/calendar/day_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/maat_flow_visual_test_fonts.dart';

const _googleGeneratedDetail =
    'To see detailed information for automatically created events like this one, '
    'use the official Google Calendar app. https://g.co/calendar\n\n'
    'This event was created from an email you received in Gmail. '
    'https://mail.google.com/mail?extsrc=cal&plid=example';

const _captureImportedDetail = bool.fromEnvironment('CAPTURE_IMPORTED_DETAIL');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await loadMaatFlowVisualTestFonts();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final name in [
      'com.llfbandit.app_links/messages',
      'com.llfbandit.app_links/events',
    ]) {
      messenger.setMockMethodCallHandler(
        MethodChannel(name),
        (_) async => null,
      );
    }
    try {
      Supabase.instance.client;
    } catch (_) {
      await Supabase.initialize(
        url: 'https://example.supabase.co',
        anonKey: 'anon-key-0123456789012345678901234567890123456789',
        authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      );
    }
  });

  setUp(() => CalendarEventDetailSheetCoordinator.debugResetForTests());
  tearDown(() => CalendarEventDetailSheetCoordinator.debugResetForTests());

  for (final landscape in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'imported detail static ${landscape ? 'landscape' : 'portrait'} ${scale}x',
        (tester) async {
          _viewport(tester, landscape: landscape);
          await tester.pumpWidget(
            _CalendarHarness(
              scale: scale,
              detailOnly: scale > 1,
              note: _note(
                clientEventId: 'external:provider-copy',
                category: 'external_calendar',
                calendarName: 'Home and family',
              ),
            ),
          );
          await tester.pumpAndSettle();
          if (scale == 1) {
            expect(find.text('HOME AND FAMILY'), findsOneWidget);
          }
          expect(find.textContaining('EXTERNAL_CALENDAR'), findsNothing);
          await tester.tap(find.text('Regular Pest Control'));
          await tester.pumpAndSettle();
          expect(find.byType(BottomSheet), findsOneWidget);
          expect(find.text('10:00 AM – 11:00 AM'), findsOneWidget);
          expect(find.text('All-day'), findsNothing);
          expect(find.byTooltip('Event options'), findsNothing);
          expect(find.text('Edit Note'), findsNothing);
          expect(find.text('End Note'), findsNothing);
          expect(find.text('Share Note'), findsNothing);
          expect(find.textContaining('EXTERNAL_CALENDAR'), findsNothing);
          expect(tester.takeException(), isNull);
          if (_captureImportedDetail) {
            await expectLater(
              find.byType(Overlay).first,
              matchesGoldenFile(
                '/tmp/haw-imported-detail-${landscape ? 'landscape' : 'portrait'}-${scale}x.png',
              ),
            );
          }
        },
      );
    }
  }

  for (final landscape in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'all-day holiday detail static ${landscape ? 'landscape' : 'portrait'} ${scale}x',
        (tester) async {
          _viewport(tester, landscape: landscape);
          await tester.pumpWidget(
            _CalendarHarness(
              scale: scale,
              detailOnly: true,
              note: _note(
                clientEventId: 'external:public-holiday',
                category: 'external_calendar',
                calendarName: 'Holidays in United States',
                title: 'Halloween',
                detail: 'Observance',
                allDay: true,
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Halloween'));
          await tester.pumpAndSettle();
          if (landscape && scale > 1) {
            await tester.drag(
              find.byKey(const ValueKey('landscape-detail-resize')),
              const Offset(0, -120),
            );
            await tester.pumpAndSettle();
          }
          final sheet = find.byType(BottomSheet);
          expect(sheet, findsOneWidget);
          expect(find.text('All-day').hitTestable(), findsOneWidget);
          expect(
            find.descendant(of: sheet, matching: find.text('All-day')),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: sheet,
              matching: find.text('9:00 AM – 5:00 PM'),
            ),
            findsNothing,
          );
          expect(find.text('HOLIDAYS IN UNITED STATES'), findsOneWidget);
          expect(find.byTooltip('Event options'), findsNothing);
          expect(tester.takeException(), isNull);
          if (_captureImportedDetail) {
            await expectLater(
              find.byType(Overlay).first,
              matchesGoldenFile(
                '/tmp/haw-all-day-detail-${landscape ? 'landscape' : 'portrait'}-${scale}x.png',
              ),
            );
          }
        },
      );
    }
  }

  for (final landscape in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'all-day lane ${landscape ? 'landscape' : 'portrait'} ${scale}x',
        (tester) async {
          _viewport(tester, landscape: landscape);
          await tester.pumpWidget(
            _CalendarHarness(
              scale: scale,
              note: _note(
                clientEventId: 'external:holiday',
                title: 'Lottery Winner',
                category: 'external_calendar',
                calendarName: 'Personal',
                allDay: true,
              ),
            ),
          );
          await tester.pumpAndSettle();
          final lane = find.byKey(const ValueKey('day-view-all-day-events'));
          expect(lane, findsOneWidget);
          expect(
            find.descendant(
              of: lane,
              matching: find.byType(CalendarDayEventBlock),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: find.byKey(dayViewTimelineEventLayerKey),
              matching: find.byType(CalendarDayEventBlock),
            ),
            findsNothing,
          );
          expect(find.text('Lottery Winner').hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
          if (_captureImportedDetail) {
            await expectLater(
              find.byType(Overlay).first,
              matchesGoldenFile(
                '/tmp/haw-all-day-lane-${landscape ? 'landscape' : 'portrait'}-${scale}x.png',
              ),
            );
          }
          await tester.tap(find.text('Lottery Winner'));
          await tester.pumpAndSettle();
          expect(find.byType(BottomSheet), findsOneWidget);
          expect(find.byTooltip('Event options'), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final event in [
    (cid: 'native:all-day', category: 'native_sync', allDay: true),
    (cid: 'manual:all-day', category: 'Personal', allDay: true),
    (
      cid: 'external:timed-workday',
      category: 'external_calendar',
      allDay: false,
    ),
  ]) {
    testWidgets('detail time follows all-day flag for ${event.cid}', (
      tester,
    ) async {
      _viewport(tester);
      await tester.pumpWidget(
        _CalendarHarness(
          detailOnly: true,
          note: NoteData(
            id: 'detail-time',
            clientEventId: event.cid,
            category: event.category,
            title: 'Calendar event',
            allDay: event.allDay,
            start: const TimeOfDay(hour: 9, minute: 0),
            end: const TimeOfDay(hour: 17, minute: 0),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Calendar event'));
      await tester.pumpAndSettle();
      expect(
        find.text(event.allDay ? 'All-day' : '9:00 AM – 5:00 PM'),
        findsOneWidget,
      );
      expect(
        find.text(event.allDay ? '9:00 AM – 5:00 PM' : 'All-day'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }

  // Static preview first established this existing link-only layout. The same
  // surface must result when the raw imported Google description is supplied.
  for (final landscape in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'Google imported detail uses existing link area ${landscape ? 'landscape' : 'portrait'} ${scale}x',
        (tester) async {
          _viewport(tester, landscape: landscape);
          await tester.pumpWidget(
            _CalendarHarness(
              scale: scale,
              detailOnly: scale > 1,
              note: _note(
                clientEventId: 'external:provider-copy',
                category: 'external_calendar',
                calendarName: 'Home and family',
                detail: _googleGeneratedDetail,
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Regular Pest Control'));
          await tester.pumpAndSettle();
          expect(find.text('Open link'), findsOneWidget);
          expect(
            find.textContaining('official Google Calendar', findRichText: true),
            findsNothing,
          );
          expect(
            find.textContaining('created from an email', findRichText: true),
            findsNothing,
          );
          expect(
            find.textContaining('g.co/calendar', findRichText: true),
            findsNothing,
          );
          expect(
            find.textContaining('mail.google.com', findRichText: true),
            findsNothing,
          );
          expect(find.byTooltip('Event options'), findsNothing);
          expect(tester.takeException(), isNull);
          if (_captureImportedDetail) {
            await expectLater(
              find.byType(Overlay).first,
              matchesGoldenFile(
                '/tmp/haw-imported-clean-detail-${landscape ? 'landscape' : 'portrait'}-${scale}x.png',
              ),
            );
          }
        },
      );
    }
  }

  testWidgets('imported detail keeps original notes beside the source link', (
    tester,
  ) async {
    _viewport(tester);
    await tester.pumpWidget(
      _CalendarHarness(
        note: _note(
          clientEventId: 'external:provider-copy',
          detail: 'Keep the side gate accessible.\n\n$_googleGeneratedDetail',
        ),
        detailOnly: true,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Regular Pest Control'));
    await tester.pumpAndSettle();
    expect(
      find.text('Keep the side gate accessible.', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Open link'), findsOneWidget);
    expect(
      find.textContaining('official Google Calendar', findRichText: true),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  for (final identity in [
    (cid: 'external:google-copy', category: 'external_calendar', name: 'Work'),
    (cid: 'external:device-copy', category: null, name: 'Home'),
    (cid: 'native:legacy-copy', category: 'native_sync', name: 'Family'),
    (cid: 'legacy-copy', category: 'external_calendar', name: ''),
    (cid: 'legacy-copy', category: 'native_sync', name: ''),
  ]) {
    testWidgets(
      'imported detail excludes authored actions ${identity.cid}/${identity.category}',
      (tester) async {
        _viewport(tester);
        final actions = <String>[];
        await tester.pumpWidget(
          _CalendarHarness(
            note: _note(
              clientEventId: identity.cid,
              category: identity.category,
              calendarName: identity.name,
            ),
            onAction: actions.add,
          ),
        );
        await tester.pumpAndSettle();
        final label = identity.name.isEmpty
            ? 'IMPORTED CALENDAR'
            : identity.name.toUpperCase();
        expect(find.text(label), findsOneWidget);
        await tester.tap(find.text('Regular Pest Control'));
        await tester.pumpAndSettle();
        expect(find.text(label), findsWidgets);
        expect(find.byTooltip('Event options'), findsNothing);
        for (final text in ['Edit Note', 'End Note', 'Share Note']) {
          expect(find.text(text), findsNothing);
        }
        expect(find.textContaining('EXTERNAL_CALENDAR'), findsNothing);
        expect(find.textContaining('NATIVE_SYNC'), findsNothing);
        expect(actions, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final action in [
    (label: 'Edit Note', value: 'edit'),
    (label: 'End Note', value: 'end'),
    (label: 'Share Note', value: 'share'),
  ]) {
    testWidgets('authored detail retains ${action.label}', (tester) async {
      _viewport(tester);
      final actions = <String>[];
      await tester.pumpWidget(
        _CalendarHarness(
          note: _note(clientEventId: 'manual:authored', category: 'Personal'),
          detailOnly: true,
          onAction: actions.add,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Regular Pest Control'));
      await tester.pumpAndSettle();
      expect(find.text('PERSONAL'), findsOneWidget);
      await tester.tap(find.byTooltip('Event options'));
      await tester.pumpAndSettle();
      expect(find.text('Edit Note'), findsOneWidget);
      expect(find.text('End Note'), findsOneWidget);
      expect(find.text('Share Note'), findsOneWidget);
      await tester.tap(find.text(action.label));
      await tester.pumpAndSettle();
      expect(actions, [action.value]);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'stale ${action.label} menu rejects freshly classified import',
      (tester) async {
        _viewport(tester);
        final actions = <String>[];
        final initial = _note(
          clientEventId: 'legacy-copy',
          category: 'Personal',
        );
        var current = _target(initial);
        await tester.pumpWidget(
          _CalendarHarness(
            note: initial,
            detailOnly: true,
            onAction: actions.add,
            resolveTarget: (_) => current,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Regular Pest Control'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Event options'));
        await tester.pumpAndSettle();
        current = _target(
          _note(clientEventId: 'legacy-copy', category: 'external_calendar'),
        );
        await tester.tap(find.text(action.label));
        await tester.pumpAndSettle();
        expect(actions, isEmpty);
        expect(find.byType(BottomSheet), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final detail in [
    'Reminder: bring insurance card',
    'flowLocalId=literal; Reminder: bring insurance card',
    'ky=1-km=1-kd=1|s=900|t=literal|f=example',
  ]) {
    testWidgets('imported detail preserves literal provider text: $detail', (
      tester,
    ) async {
      _viewport(tester);
      await tester.pumpWidget(
        _CalendarHarness(
          note: _note(
            clientEventId: 'external:literal-provider',
            detail: detail,
          ),
          detailOnly: true,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Regular Pest Control'));
      await tester.pumpAndSettle();
      expect(find.text(detail, findRichText: true), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (_captureImportedDetail) {
        final name = detail.startsWith('Reminder:')
            ? 'reminder'
            : detail.startsWith('flowLocalId=')
            ? 'prefix'
            : 'identity';
        await expectLater(
          find.byType(Overlay).first,
          matchesGoldenFile('/tmp/haw-imported-literal-$name.png'),
        );
      }
    });
  }

  testWidgets('authored detail retains its existing metadata prefix cleanup', (
    tester,
  ) async {
    _viewport(tester);
    await tester.pumpWidget(
      _CalendarHarness(
        note: _note(
          clientEventId: 'manual:authored',
          detail:
              'flowLocalId=77; Reminder: bring insurance card\nKeep the existing authored instructions.',
        ),
        detailOnly: true,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Regular Pest Control'));
    await tester.pumpAndSettle();
    expect(
      find.text('Keep the existing authored instructions.', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('Reminder:', findRichText: true), findsNothing);
    expect(
      find.textContaining('flowLocalId=', findRichText: true),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}

NoteData _note({
  required String clientEventId,
  String? category,
  String? calendarName,
  String title = 'Regular Pest Control',
  String detail = 'Regular visit. Keep the side gate accessible.',
  bool allDay = false,
}) => NoteData(
  id: 'provider-projection-id',
  clientEventId: clientEventId,
  calendarId: 'external:calendar-source',
  calendarName: calendarName,
  title: title,
  detail: detail,
  category: category,
  allDay: allDay,
  start: allDay ? null : const TimeOfDay(hour: 10, minute: 0),
  end: allDay ? null : const TimeOfDay(hour: 11, minute: 0),
);

void _viewport(WidgetTester tester, {bool landscape = false}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = landscape
      ? const Size(844, 390)
      : const Size(390, 844);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

class _CalendarHarness extends StatelessWidget {
  const _CalendarHarness({
    required this.note,
    this.scale = 1,
    this.onAction,
    this.detailOnly = false,
    this.resolveTarget,
  });

  final NoteData note;
  final double scale;
  final bool detailOnly;
  final DayViewSheetEventTarget Function(DayViewSheetEventTarget)?
  resolveTarget;
  final ValueChanged<String>? onAction;

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: AppTheme.dark,
    debugShowCheckedModeBanner: false,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: Scaffold(
      body: detailOnly
          ? Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () => showCalendarEventDetailSheetModal<void>(
                    context: context,
                    builder: (_) => CalendarEventDetailSheet(
                      hostContext: context,
                      initialTarget: _target(note),
                      resolveCurrentEventTarget: resolveTarget,
                      onEditNote: (_, _, _, _) async => onAction?.call('edit'),
                      onDeleteNote: (_, _, _, _) async => onAction?.call('end'),
                      onShareNote: (_) async => onAction?.call('share'),
                    ),
                  ),
                  child: Text(note.title),
                ),
              ),
            )
          : DayViewGrid(
              ky: 1,
              km: 1,
              kd: 1,
              notes: [note],
              showGregorian: false,
              flowIndex: const {},
              initialScrollOffset: 9 * 60,
              onEditNote: (_, _, _, _) async => onAction?.call('edit'),
              onDeleteNote: (_, _, _, _) async => onAction?.call('end'),
              onShareNote: (_) async => onAction?.call('share'),
            ),
    ),
  );
}

DayViewSheetEventTarget _target(NoteData note) => DayViewSheetEventTarget(
  ky: 1,
  km: 1,
  kd: 1,
  event: EventItem.fromTimedNote(
    id: note.id,
    clientEventId: note.clientEventId,
    calendarId: note.calendarId,
    calendarName: note.calendarName,
    category: note.category,
    title: note.title,
    detail: note.detail,
    allDay: note.allDay,
    startHour: note.start?.hour,
    startMinute: note.start?.minute,
    endHour: note.end?.hour,
    endMinute: note.end?.minute,
    color: Colors.blue,
  ),
);
