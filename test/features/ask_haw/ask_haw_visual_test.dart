import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/ask_haw/ask_haw_response.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../support/maat_flow_visual_test_fonts.dart';

const _states = <String, AskHawResponse?>{
  'event': null,
  'explanation': AskHawResponse(
    title: 'A decan is ten days.',
    body: 'Three decans make one month in the Kemetic calendar.',
    options: [
      AskHawOption(id: 'library:decans', label: 'Read the Library entry'),
    ],
  ),
  'discovery': AskHawResponse(
    title: 'Make room for reading',
    kind: AskHawResponseKind.results,
    options: [
      AskHawOption(
        id: 'flow:the-reading-house',
        label: 'Reading House',
        detail: 'A practice for spending time with a text.',
        reason: 'Matches your interest in reading · Preview before joining',
      ),
      AskHawOption(
        id: 'library:decans',
        label: 'Decans',
        detail: 'A short Library reading',
        reason: 'Understand the rhythm of ten days',
      ),
    ],
  ),
  'clarification': AskHawResponse(
    title: 'What would you like to do?',
    kind: AskHawResponseKind.choices,
    options: [
      AskHawOption(id: 'find', label: 'Find a reading Flow'),
      AskHawOption(
        id: 'event',
        label: 'Add reading to my calendar',
        secondary: true,
      ),
    ],
  ),
  'proposal': AskHawResponse(
    title: 'Move your writing session?',
    body: 'Friday · 8:10–8:40 p.m.\nYour other commitments stay in place.',
    kind: AskHawResponseKind.proposal,
    options: [
      AskHawOption(id: 'accept', label: 'Use this time'),
      AskHawOption(id: 'choose', label: 'Choose another time', secondary: true),
    ],
  ),
  'success': AskHawResponse(
    title: 'Your session has moved.',
    body: 'Friday · 8:10–8:40 p.m.',
    kind: AskHawResponseKind.success,
    options: [
      AskHawOption(
        id: 'default',
        label: 'Use this time by default',
        secondary: true,
      ),
    ],
  ),
  'unavailable': AskHawResponse(
    title: 'I couldn’t confirm your available time.',
    body: 'Your calendar did not finish loading. Your text is still here.',
    kind: AskHawResponseKind.unavailable,
    options: [
      AskHawOption(id: 'retry', label: 'Try again'),
      AskHawOption(id: 'event', label: 'Add an event instead', secondary: true),
    ],
  ),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'anon-key-0123456789012345678901234567890123456789',
      authOptions: const FlutterAuthClientOptions(
        detectSessionInUri: false,
        autoRefreshToken: false,
      ),
    );
    await loadMaatFlowVisualTestFonts();
  });

  testWidgets(
    'shared Quick Add response states fit phones, landscape, tablet and enlarged text',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey();
      for (final size in [
        const Size(390, 844),
        const Size(844, 390),
        const Size(820, 1180),
      ]) {
        for (final scale in [1.0, 1.6]) {
          tester.view.physicalSize = size;
          for (final entry in _states.entries) {
            await tester.pumpWidget(
              MaterialApp(
                theme: ThemeData.dark(useMaterial3: true),
                home: MediaQuery(
                  data: MediaQueryData(
                    size: size,
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: Scaffold(
                    backgroundColor: const Color(0xFF080807),
                    body: RepaintBoundary(
                      key: key,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 640),
                          child: Builder(
                            builder: (context) =>
                                CalendarPage.buildQuickAddVisualReference(
                                  context,
                                  response: entry.value,
                                ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: '${entry.key} $size $scale',
            );
            expect(
              find.byKey(const ValueKey('quick-add-input')),
              findsOneWidget,
            );
            expect(find.text('JOURNAL'), findsOneWidget);
            expect(find.text('PLANNER'), findsOneWidget);
            if (entry.value != null)
              expect(find.text(entry.value!.title), findsOneWidget);
            if (Platform.environment['HAW_ASK_CAPTURE_DIR']
                case final String path
                when path.isNotEmpty && scale == 1 && size.width == 390) {
              await tester.runAsync(() async {
                final boundary =
                    key.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary;
                final image = await boundary.toImage(pixelRatio: 1);
                final bytes = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                await Directory(path).create(recursive: true);
                await File(
                  '$path/${entry.key}.png',
                ).writeAsBytes(bytes!.buffer.asUint8List());
                image.dispose();
              });
            }
          }
        }
      }
    },
  );
}
