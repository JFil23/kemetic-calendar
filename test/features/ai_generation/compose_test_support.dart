import '../../support/maat_flow_visual_test_fonts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_page.dart'
    show debugBuildFlowStudioPageForTest;
import 'package:mobile/models/ai_flow_generation_response.dart';
import 'package:mobile/services/ai_flow_generation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> initializeComposeTests() async {
  SharedPreferences.setMockInitialValues({});
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('com.llfbandit.app_links/events'),
        (_) async => null,
      );
  await Supabase.initialize(
    url: 'https://example.supabase.co',
    anonKey: 'anon-key-0123456789012345678901234567890123456789',
  );
}

Future<void> openCompose(
  WidgetTester tester, {
  String prompt = '',
  bool manual = true,
  bool build = false,
  Future<void> Function(dynamic)? onRouteResult,
}) async {
  await loadMaatFlowVisualTestFonts();
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(fontFamily: 'GentiumPlus'),
      home: debugBuildFlowStudioPageForTest(
        onRouteResult: onRouteResult,
        initialDraftJson: {
          'studioMode': build ? 'build' : 'compose',
          'name': '',
          'active': true,
          'selectedColorIndex': 0,
          'composePrompt': prompt,
          'composeUseKemetic': false,
          'composeStartDate': '2026-06-02T00:00:00.000',
          'composeEndDate': '2026-06-11T00:00:00.000',
          'composeManualDateRangeEdited': manual,
          'useKemetic': false,
          'splitByPeriod': true,
        },
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 900));
}

Future<void> revealCompose(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

class RecordingComposeService extends AIFlowGenerationService {
  RecordingComposeService() : super(Supabase.instance.client);
  int calls = 0;
  DateTime? start;
  DateTime? end;
  @override
  Future<AIFlowGenerationResponse> generate({
    required String description,
    required DateTime startDate,
    required DateTime endDate,
    String? flowColor,
    String? timezone,
    String? sourceText,
    bool forceRefresh = false,
    String? maatBriefId,
    String? maatDeliveryId,
  }) async {
    calls++;
    start = startDate;
    end = endDate;
    return const AIFlowGenerationResponse(
      success: false,
      errorMessage: 'test response',
    );
  }
}
