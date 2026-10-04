import 'dart:io';
import 'package:mobile/features/onboarding/decan_compass_copy_repo.dart';
import 'package:mobile/features/calendar/the_reading_house/presentation/reading_house_detail_page.dart';
import 'package:mobile/features/calendar/track_sky_timezone.dart';
import 'package:mobile/features/calendar/follow_the_sky/services/sky_catalog_repository.dart';
import 'package:mobile/features/calendar/follow_the_sky/presentation/follow_sky_detail_page.dart';
import 'package:mobile/widgets/keyboard_aware.dart';
import 'package:mobile/features/calendar/presentation/maat_flow_detail_shell.dart';
import 'package:flutter/services.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:mobile/features/calendar/maat_flow_identity.dart';
import 'package:mobile/features/calendar/presentation/instrument_event_presentation_frame.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/onboarding/onboarding_overlay.dart';
import 'package:mobile/features/onboarding/starter_maat_flow_recommendation.dart';
import '../../support/maat_flow_visual_test_fonts.dart';

const compass = HawCompassCopy(
  decanKey: 'm04_d2',
  dateLabel: 'Ka-her-Ka 16',
  decanName: 'hry-ib msḫtjw',
  decanOrdinalLabel: 'second',
  monthName: 'Ka-her-Ka',
  rhythmPhrase:
      'The second decan of Ka-her-Ka centers on strengthening what can carry weight.',
  orientationQuestion:
      'What should be reinforced before it is asked to hold more?',
  dayAlignedReturnKey: 'reinforce_weight',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await loadMaatFlowVisualTestFonts();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channel in [
      'com.llfbandit.app_links/messages',
      'com.llfbandit.app_links/events',
    ]) {
      messenger.setMockMethodCallHandler(
        MethodChannel(channel),
        (_) async => null,
      );
    }
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'fixture',
    );
  });
  tearDownAll(() => Supabase.instance.dispose());
  for (final size in [
    const Size(390, 844),
    const Size(844, 390),
    const Size(320, 568),
  ]) {
    for (final scale in [1.0, 2.0]) {
      for (final slide in [
        HawOnboardingSlide.exhale,
        HawOnboardingSlide.calendarConnection,
        HawOnboardingSlide.segmentation,
        HawOnboardingSlide.orientation,
      ]) {
        testWidgets('${slide.name} ${size.width}x${size.height} ${scale}x', (
          tester,
        ) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size;
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          final boundary = GlobalKey();
          await tester.pumpWidget(
            MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  disableAnimations: true,
                  textScaler: TextScaler.linear(scale),
                ),
                child: child!,
              ),
              home: RepaintBoundary(
                key: boundary,
                child: OnboardingOverlay(
                  initialSlide: slide,
                  compassCopy: DecanCompassCopyRepo.fallbackForDay(
                    kMonth: 7,
                    kDay: 19,
                  ),
                  recommendedFlowBuilder: (_, _) => const SizedBox(),
                  dayViewBuilder: (_, _, _) => const SizedBox(),
                  dayViewEventTargetKey: GlobalKey(),
                  onEntryStateSelected: (_) async {},
                  onSkip: () {},
                  onComplete: () {},
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (slide == HawOnboardingSlide.calendarConnection) {
            final connect = find.text('Connect calendar');
            final later = find.text('not now');
            final left = tester.getRect(connect);
            final right = tester.getRect(later);
            expect(left.center.dx, lessThan(right.center.dx));
            expect((left.center.dy - right.center.dy).abs(), lessThan(1));
            final connectStyle = tester.widget<Text>(connect).style!;
            expect(connectStyle, tester.widget<Text>(later).style);
            expect(connectStyle.fontStyle, FontStyle.italic);
            expect(connectStyle.fontSize, greaterThan(13));
            expect(find.byType(OutlinedButton), findsNothing);
          }
          if (slide == HawOnboardingSlide.segmentation) {
            await tester.scrollUntilVisible(
              find.text(HawEntryIntent.imagination.label),
              200,
              scrollable: find.byType(Scrollable).last,
            );
            expect(
              find.text(HawEntryIntent.imagination.label).hitTestable(),
              findsOneWidget,
            );
            await tester.drag(find.byType(ListView), const Offset(0, 1800));
            await tester.pumpAndSettle();
          }
          await capture(
            tester,
            boundary,
            '${slide.name}-${size.width.toInt()}x${size.height.toInt()}-${scale.toInt()}x',
          );
          if (slide == HawOnboardingSlide.orientation) {
            final viewport = find.byType(SingleChildScrollView).first;
            expect(
              tester.getRect(viewport).bottom,
              lessThan(tester.getRect(find.text('next')).top),
            );
            final scrollable = find.byType(Scrollable).first;
            final position = tester.state<ScrollableState>(scrollable).position;
            if (position.maxScrollExtent > 0) {
              await tester.drag(scrollable, const Offset(0, -10000));
              await tester.pumpAndSettle();
              expect(position.pixels, closeTo(position.maxScrollExtent, 1));
              await capture(
                tester,
                boundary,
                'orientation-end-${size.width.toInt()}x${size.height.toInt()}-${scale.toInt()}x',
              );
              expect(find.text('next').hitTestable(), findsOneWidget);
            }
          }
          await tester.pumpWidget(const SizedBox());
        });
      }
    }
  }
  for (final size in [const Size(390, 844), const Size(844, 390)]) {
    for (final scale in [1.0, 2.0]) {
      for (final intent in HawEntryIntent.values) {
        for (final owned in [false, true]) {
          testWidgets(
            '${intent.name} ${owned ? 'owned' : 'new'} recommendation ${size.width} ${scale}x',
            (tester) async {
              tester.view.devicePixelRatio = 1;
              tester.view.physicalSize = size;
              addTearDown(tester.view.reset);
              final boundary = GlobalKey();
              var opens = 0;
              var joins = 0;
              final action = owned
                  ? MaatFlowDetailPrimaryAction(
                      label: 'Go to flow',
                      onPressed: () => opens++,
                      note: 'Open the flow already in your calendar.',
                    )
                  : null;
              await tester.pumpWidget(
                MaterialApp(
                  theme: AppTheme.dark,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      disableAnimations: true,
                      textScaler: TextScaler.linear(scale),
                    ),
                    child: child!,
                  ),
                  home: RepaintBoundary(
                    key: boundary,
                    child: OnboardingOverlay(
                      initialSlide: HawOnboardingSlide.recommendedFlow,
                      recommendationReason: 'You said: ${intent.label}',
                      compassCopy: compass,
                      recommendedFlowBuilder: (_, _) =>
                          intent == HawEntryIntent.sky
                          ? KeyboardAwareEditableSurface(
                              child: FollowSkyDetailSurface(
                                initialCatalog:
                                    SkyCatalogRepository.parseJsonString(
                                      File(
                                        'assets/follow_the_sky/sky_catalog_v2_graphics_v1.json',
                                      ).readAsStringSync(),
                                    ),
                                now: DateTime.utc(2026, 10, 4, 12),
                                presentDayIanaTimeZone: 'America/Los_Angeles',
                                isJoined: owned,
                                existingFlowId: owned ? 957 : null,
                                primaryAction: action,
                                onJoin: (_) async {
                                  joins++;
                                },
                              ),
                            )
                          : owned && intent == HawEntryIntent.reading
                          ? ReadingHouseDetailSurface(
                              timezone: TrackSkyTimeZone.pacific,
                              initiallyHeld: true,
                              initialFlowId: 957,
                              initialStartDate: DateTime(2026, 10, 4),
                              primaryAction: action,
                            )
                          : buildMaatFlowTemplateDetailPreviewForTesting(
                              templateKey: intent.kind.flowKey,
                              joinedStartDate: owned
                                  ? DateTime(2026, 10, 4)
                                  : null,
                              primaryAction: action,
                              onJoin: () async {
                                joins++;
                                return 957;
                              },
                            ),
                      dayViewBuilder: (_, _, _) => const SizedBox(),
                      dayViewEventTargetKey: GlobalKey(),
                      onEntryStateSelected: (_) async {},
                      onSkip: () {},
                      onComplete: () {},
                    ),
                  ),
                ),
              );
              await tester.pump();
              await tester.runAsync(() async {
                // Asset decoding and the sky catalog use real asynchronous work.
                await Future<void>.delayed(const Duration(milliseconds: 100));
                final context = tester.element(find.byType(OnboardingOverlay));
                for (final asset in tester.widgetList<Image>(
                  find.byType(Image),
                )) {
                  await precacheImage(asset.image, context);
                }
              });
              // Follow the Sky keeps its instrument animation alive. Settle the
              // entrance on a bounded clock instead of waiting for all animation.
              await tester.pump(const Duration(seconds: 2));
              await tester.pump(const Duration(milliseconds: 600));
              expect(find.byType(CircularProgressIndicator), findsNothing);
              expect(tester.takeException(), isNull);
              for (final element
                  in find.byType(MaatFlowDetailHero).evaluate()) {
                final hero = element.widget as MaatFlowDetailHero;
                final host = find.byWidget(hero);
                final title = find.descendant(
                  of: host,
                  matching: find.text(hero.title),
                );
                final heroRect = tester.getRect(host);
                final titleRect = tester.getRect(title);
                expect(titleRect.top, greaterThanOrEqualTo(heroRect.top));
                expect(titleRect.bottom, lessThanOrEqualTo(heroRect.bottom));
              }
              for (final element
                  in find
                      .descendant(
                        of: find.byType(MaatFlowDetailDock),
                        matching: find.byType(ElevatedButton),
                      )
                      .evaluate()) {
                final button = find.byWidget(element.widget);
                final label = find.descendant(
                  of: button,
                  matching: find.byType(Text),
                );
                final buttonRect = tester.getRect(button);
                final labelRect = tester.getRect(label);
                expect(labelRect.top, greaterThanOrEqualTo(buttonRect.top));
                expect(labelRect.bottom, lessThanOrEqualTo(buttonRect.bottom));
              }
              await capture(
                tester,
                boundary,
                'recommendation-${owned ? 'owned' : 'new'}-${intent.name}-${size.width.toInt()}-${scale.toInt()}x',
              );
              if (scale > 1 || size.width > size.height) {
                final shell = find.byType(MaatFlowDetailShell);
                final innerScroll = find.descendant(
                  of: shell,
                  matching: find.byType(CustomScrollView),
                );
                if (innerScroll.evaluate().isNotEmpty) {
                  // In short viewports the outer page exposes the full detail
                  // window, then the existing detail scroll reveals its content.
                  await tester.ensureVisible(shell.first);
                  await tester.pump();
                  final controller = tester
                      .widget<CustomScrollView>(innerScroll.first)
                      .controller!;
                  controller.jumpTo(220);
                  await tester.pump(const Duration(milliseconds: 300));
                  expect(tester.takeException(), isNull);
                  await capture(
                    tester,
                    boundary,
                    'recommendation-scrolled-${owned ? 'owned' : 'new'}-${intent.name}-${size.width.toInt()}-${scale.toInt()}x',
                  );
                }
              }
              if (owned) {
                final button = find.text('Go to flow');
                await tester.ensureVisible(button);
                await tester.pump();
                expect(button.hitTestable(), findsOneWidget);
                await tester.tap(button);
                expect(opens, 1);
                expect(joins, 0);
                expect(find.byType(MaatFlowDetailShell), findsOneWidget);
              }
              await tester.pumpWidget(const SizedBox());
            },
          );
        }
        testWidgets(
          '${intent.name} closing with unchanged housing ${size.width} ${scale}x',
          (tester) async {
            tester.view.devicePixelRatio = 1;
            tester.view.physicalSize = size;
            addTearDown(tester.view.reset);
            final boundary = GlobalKey();
            final flow = MaatDayViewFlow.values[intent.index];
            final spec = MaatDayViewHousingSpec.forFlow(flow);
            await tester.pumpWidget(
              MaterialApp(
                theme: AppTheme.dark,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: RepaintBoundary(
                  key: boundary,
                  child: Scaffold(
                    backgroundColor: const Color(0xFF060604),
                    body: Align(
                      alignment: Alignment.bottomCenter,
                      child: HawOnboardingDetailFrame(
                        closing: HawOnboardingClosingBanner(
                          copy: intent.closingCopy,
                          onComplete: () {},
                        ),
                        detail: MaatDayViewSheetHost(
                          flow: flow,
                          trailing: const SizedBox(),
                          footer: const SizedBox(),
                          body: const ColoredBox(color: Color(0xFF17140D)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            final host = tester.widget<InstrumentEventSheetHost>(
              find.byType(InstrumentEventSheetHost),
            );
            expect(host.initialExtent, spec.initialExtent);
            expect(find.text('×').hitTestable(), findsOneWidget);
            await capture(
              tester,
              boundary,
              'housing-${intent.name}-${size.width.toInt()}-${scale.toInt()}x',
            );
            await tester.tap(find.text('×'));
            await tester.pump(const Duration(milliseconds: 1200));
            expect(find.text('this is ḥꜣw'), findsOneWidget);
            await tester.pump(const Duration(seconds: 2));
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox());
          },
        );
      }
    }
  }
  for (final intent in HawEntryIntent.values) {
    testWidgets('${intent.name} closing fits recording card', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: RepaintBoundary(
            key: boundary,
            child: Scaffold(
              backgroundColor: const Color(0xFF060604),
              body: Center(
                child: HawOnboardingClosingBanner(
                  copy: intent.closingCopy,
                  onComplete: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text(intent.closingCopy), findsOneWidget);
      await capture(tester, boundary, 'closing-${intent.name}');
      await tester.tap(find.text('×'));
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('this is ḥꜣw'), findsOneWidget);
      await capture(tester, boundary, 'seal-${intent.name}');
      await tester.pumpWidget(const SizedBox());
    });
  }
}

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  final output = Platform.environment['HAW_ONBOARDING_CAPTURE_DIR'];
  if (output == null) return;
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(output).create(recursive: true);
    await File('$output/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
