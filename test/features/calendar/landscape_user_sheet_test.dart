import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/flow_appearance.dart';
import 'package:mobile/data/flow_appearance_store.dart';
import 'package:mobile/features/calendar/day_view.dart';
import 'package:mobile/features/calendar/presentation/user_flow_appearance_visual.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'landscape_split_behavior_test.dart' show pumpLandscape;
import '../../support/maat_flow_visual_test_fonts.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'anon-key-0123456789012345678901234567890123456789',
    );
    await loadMaatFlowVisualTestFonts();
  });
  setUp(() {
    FlowAppearanceStore.debugResetImageCacheForTesting();
    CalendarEventDetailSheetCoordinator.debugResetForTests();
  });
  tearDown(() {
    FlowAppearanceStore.debugResetImageCacheForTesting();
    CalendarEventDetailSheetCoordinator.debugResetForTests();
  });

  testWidgets(
    'user image and native sign remain present through landscape resize and scroll',
    (tester) async {
      final bytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      );
      FlowAppearanceStore(
        Supabase.instance.client,
      ).rememberImageBytes('fixture/photo.png', bytes);
      final notes = [
        NoteData(
          clientEventId: 'photo-event',
          title: 'Study with photo',
          allDay: false,
          start: const TimeOfDay(hour: 8, minute: 0),
          end: const TimeOfDay(hour: 9, minute: 0),
          flowId: 77,
        ),
      ];
      await pumpLandscape(
        tester,
        flows: const {
          77: FlowData(
            id: 77,
            name: 'Study',
            color: Color(0xFF6F93A8),
            active: true,
            appearance: FlowAppearance(
              imageObjectPath: 'fixture/photo.png',
              signKind: FlowSignKind.shen,
              signLabel: 'Study',
              accentArgb: 0xFF6F93A8,
            ),
          ),
        },
        notes: (_, _, d) => d == 13 ? notes : const [],
      );
      await tester.tap(find.text('Study with photo').last);
      await tester.pumpAndSettle();
      final sheet = find.byType(CalendarEventDetailSheet);
      final image = find.descendant(of: sheet, matching: find.byType(Image));
      final hero = find.descendant(
        of: sheet,
        matching: find.byType(UserFlowAppearanceHero),
      );
      expect(image, findsOneWidget);
      expect(tester.widget<Image>(image).image, isA<MemoryImage>());
      expect(
        tester.widget<UserFlowAppearanceHero>(hero).appearance.imageObjectPath,
        'fixture/photo.png',
      );
      expect(tester.widget<UserFlowAppearanceHero>(hero).height, 190);
      expect(
        tester
            .widget<Opacity>(
              find.byKey(const ValueKey('user-flow-appearance-image-opacity')),
            )
            .opacity,
        .24,
      );
      final pane = tester.getRect(
        find.byKey(const ValueKey('landscape-calendar-pane')),
      );
      final sheetBounds = tester.getRect(find.byType(BottomSheet));
      expect(sheetBounds.left, pane.left);
      expect(sheetBounds.right, pane.right);
      final scrim = tester.getRect(find.byType(ModalBarrier).last);
      expect(scrim, pane);
      expect(
        find.byKey(const ValueKey('landscape-ledger')).hitTestable(),
        findsOneWidget,
      );
      final before = tester.getSize(sheet).height;
      await tester.drag(
        find.byKey(const ValueKey('landscape-detail-resize')),
        const Offset(0, -160),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(sheet).height, greaterThan(before));
      expect(tester.getSize(hero).height, 190);
      final scroller = find.byKey(
        const ValueKey('user-flow-day-sheet-foreground-scroll'),
      );
      await tester.drag(scroller, const Offset(0, -650));
      await tester.pumpAndSettle();
      expect(find.text('Observed').last.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
