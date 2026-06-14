import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Flow Studio uses Build Compose spectrum state instead of palette save',
    () {
      final studio = File(
        'lib/features/calendar/calendar_flow_studio_page.dart',
      ).readAsStringSync();
      final draft = File(
        'lib/features/calendar/calendar_flow_studio_models.dart',
      ).readAsStringSync();

      expect(studio, contains('enum _FlowStudioMode { build, compose }'));
      expect(
        studio,
        contains('_FlowStudioMode _studioMode = _FlowStudioMode.build;'),
      );
      expect(studio, contains('class _FlowStudioSpectrumPicker'));
      expect(studio, contains("ValueKey('flow-studio-spectrum')"));
      expect(studio, contains("ValueKey('flow-studio-color-hex')"));
      expect(studio, contains("ValueKey('flow-studio-save-cta')"));
      expect(studio, contains("ValueKey('flow-studio-shape-cta')"));
      expect(studio, contains('color: _buildColor,'));
      expect(
        studio,
        isNot(contains('color: _flowPalette[_selectedColorIndex],')),
      );

      expect(draft, contains('final int selectedColorIndex;'));
      expect(draft, contains('final String studioMode;'));
      expect(draft, contains('final double? buildHue;'));
      expect(draft, contains('final int? buildColorArgb;'));
      expect(draft, contains('final double? composeHue;'));
      expect(draft, contains('final int? composeColorArgb;'));
    },
  );

  test('Flow Studio Compose reuses existing AI generation plumbing', () {
    final studio = File(
      'lib/features/calendar/calendar_flow_studio_page.dart',
    ).readAsStringSync();
    final modal = File(
      'lib/features/ai_generation/ai_flow_generation_modal.dart',
    ).readAsStringSync();

    expect(modal, contains('splitAiFlowPromptForApi'));
    expect(modal, contains('aiFlowColorHexFromColor'));
    expect(modal, contains('aiFlowIanaTimezoneForLocal'));

    expect(studio, contains('splitAiFlowPromptForApi(rawPrompt)'));
    expect(studio, contains('AIFlowGenerationService'));
    expect(studio, contains('service.generate('));
    expect(studio, contains('_aiImportDataFromResponse(result, startDate)'));
    expect(studio, contains('await _initializeFromImport(importData);'));
  });
}
