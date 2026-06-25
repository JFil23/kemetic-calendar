// lib/features/ai_generation/ai_flow_generation_modal.dart
// UPDATED VERSION - Matches Flow Studio styling exactly

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../calendar/kemetic_month_metadata.dart';
import '../../models/ai_flow_generation_response.dart';
import '../../services/ai_flow_generation_service.dart';
import '../../widgets/kemetic_date_picker.dart';
import '../../widgets/gregorian_date_picker.dart';
import '../../widgets/keyboard_aware.dart';
import 'package:mobile/shared/glossy_text.dart';
import 'flow_prompt_classifier.dart';
import 'flow_duration_parser.dart';
import 'itinerary_prompt_parser.dart';

// Your flow palette from Flow Studio
const _flowPalette = [
  Color(0xFF4DD0E1),
  Color(0xFF7C4DFF),
  Color(0xFFEF5350),
  Color(0xFF66BB6A),
  Color(0xFFFFCA28),
  Color(0xFF42A5F5),
  Color(0xFFAB47BC),
  Color(0xFF26A69A),
  Color(0xFFFF7043),
  Color(0xFF9CCC65),
];

String buildCanonicalAiFlowPromptText({
  String? description,
  String? sourceText,
  String? pastedPromptBody,
}) {
  final seen = <String>{};
  final parts = <String>[];
  for (final raw in [description, sourceText, pastedPromptBody]) {
    final trimmed = raw?.trim();
    if (trimmed == null || trimmed.isEmpty) continue;
    final key = trimmed.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    if (seen.add(key)) parts.add(trimmed);
  }
  return parts.join('\n\n');
}

String aiFlowColorHexFromColor(Color color) {
  final rgb = color.toARGB32() & 0x00FFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0')}';
}

String aiFlowIanaTimezoneForLocal(DateTime nowLocal) {
  final offsetHours = nowLocal.timeZoneOffset.inHours;
  final timezoneMap = {
    -10: 'Pacific/Honolulu',
    -9: 'America/Anchorage',
    -8: 'America/Los_Angeles',
    -7: 'America/Los_Angeles',
    -6: 'America/Denver',
    -5: 'America/Chicago',
    -4: 'America/New_York',
    0: 'Europe/London',
    1: 'Europe/Paris',
    8: 'Asia/Singapore',
    9: 'Asia/Tokyo',
    10: 'Australia/Sydney',
  };
  return timezoneMap[offsetHours] ?? 'America/Los_Angeles';
}

bool _aiFlowLooksLikeTelemetryBlock(String block) {
  final compact = block.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (compact.isEmpty) return false;
  final jsonKeys = RegExp(r'"[\w.-]+":').allMatches(compact).length;
  final telemetryHits = RegExp(
    r'(event_message|deployment_id|execution_id|function_id|project_ref|served_by|booted|shutdown|WallClockTime|cpu_time_used|memory_used|timestamp|version|region)',
    caseSensitive: false,
  ).allMatches(compact).length;
  return telemetryHits >= 2 ||
      (compact.startsWith('{') && compact.endsWith('}') && jsonKeys >= 4);
}

String _aiFlowExtractLongPasteIntent(String raw) {
  final blocks = raw
      .split(RegExp(r'\n\s*\n'))
      .map((b) => b.trim())
      .where((b) => b.isNotEmpty)
      .toList();
  final proseBlocks = blocks
      .where((b) => !_aiFlowLooksLikeTelemetryBlock(b))
      .toList();
  if (proseBlocks.isEmpty) {
    return raw.length > 1800 ? '${raw.substring(0, 1800)}...' : raw;
  }

  final requestCue = RegExp(
    r'(turn|make|convert|transform|create|build|organize|map).{0,40}(flow|\d{1,3}\s*day)',
    caseSensitive: false,
    dotAll: true,
  );
  final requestBlocks = proseBlocks
      .where((b) => requestCue.hasMatch(b))
      .toList();

  final candidates = <String>[
    if (requestBlocks.isNotEmpty) requestBlocks.first,
    proseBlocks.first,
    if (proseBlocks.length > 1) proseBlocks.last,
  ];

  final seen = <String>{};
  final chosen = <String>[];
  for (final block in candidates) {
    final key = block.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (key.isEmpty || seen.contains(key)) continue;
    seen.add(key);
    chosen.add(block);
  }

  final summary = chosen.join('\n\n');
  return summary.length > 1800 ? '${summary.substring(0, 1800)}...' : summary;
}

bool _aiFlowShouldSendAsSourceMaterial(String raw) {
  final trimmed = raw.trim();
  if (trimmed.length > 2200) return true;
  final blocks = trimmed
      .split(RegExp(r'\n\s*\n'))
      .map((b) => b.trim())
      .where((b) => b.isNotEmpty)
      .toList();
  return blocks.length >= 4;
}

/// Long pastes go to `source_text` on the edge function so the model treats
/// them as authoritative material while keeping dictation heuristics off.
({String description, String? sourceText}) splitAiFlowPromptForApi(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return (description: '', sourceText: null);
  }
  if (!_aiFlowShouldSendAsSourceMaterial(trimmed)) {
    return (description: trimmed, sourceText: null);
  }
  final intent = _aiFlowExtractLongPasteIntent(trimmed);
  return (
    description:
        'USER_INTENT_SUMMARY:\n$intent\n\nTransform SOURCE_TEXT into a flow for the selected date range. Preserve concrete initiatives, constraints, milestones, numbers, sequence, and voice from SOURCE_TEXT. Organize it into a clear progression instead of generic summaries.',
    sourceText: trimmed,
  );
}

String _formatAiFlowDateOnly(DateTime d) {
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

enum CalendarMode { kemetic, gregorian }

typedef AIFlowGenerateCallback =
    Future<AIFlowGenerationResponse> Function({
      required String description,
      required DateTime startDate,
      required DateTime endDate,
      String? flowColor,
      String? timezone,
      String? sourceText,
    });

class _VisibleThinkingStep {
  const _VisibleThinkingStep({required this.title, required this.detail});

  final String title;
  final String detail;
}

class AIFlowGenerationModal extends StatefulWidget {
  const AIFlowGenerationModal({
    super.key,
    this.initialStartDate,
    this.initialEndDate,
    this.initialDateRangeIsManual = false,
    this.generateFlowForTesting,
  });

  final DateTime? initialStartDate;
  final DateTime? initialEndDate;
  final bool initialDateRangeIsManual;
  final AIFlowGenerateCallback? generateFlowForTesting;

  @override
  State<AIFlowGenerationModal> createState() => _AIFlowGenerationModalState();
}

class _AIFlowGenerationModalState extends State<AIFlowGenerationModal> {
  AIFlowGenerationService? _service;
  final _descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  late final DateTime _defaultStartDate;
  DateTime? _startDate;
  DateTime? _endDate;
  final int _selectedColorIndex = 0;
  CalendarMode _mode = CalendarMode.gregorian;
  bool _isGenerating = false;
  bool _manualDateRangeEdited = false;
  String? _error;
  Timer? _visibleThinkingTimer;
  List<_VisibleThinkingStep> _visibleThinkingSteps = const [];
  int _visibleThinkingIndex = 0;

  _VisibleThinkingStep? get _activeVisibleThinkingStep {
    if (_visibleThinkingSteps.isEmpty) return null;
    final safeIndex = _visibleThinkingIndex.clamp(
      0,
      _visibleThinkingSteps.length - 1,
    );
    return _visibleThinkingSteps[safeIndex];
  }

  @override
  void initState() {
    super.initState();
    _defaultStartDate = dateOnlyForAiFlow(
      widget.initialStartDate ?? DateTime.now(),
    );
    _startDate = widget.initialStartDate == null
        ? null
        : dateOnlyForAiFlow(widget.initialStartDate!);
    _endDate = widget.initialEndDate == null
        ? null
        : dateOnlyForAiFlow(widget.initialEndDate!);
    _manualDateRangeEdited =
        widget.initialDateRangeIsManual &&
        _startDate != null &&
        _endDate != null;
    if (!_manualDateRangeEdited) {
      _applyPromptOrDefaultRange(notify: false);
    }
    _descriptionController.addListener(_handleDescriptionChanged);
  }

  @override
  void dispose() {
    _stopVisibleThinking();
    _descriptionController.removeListener(_handleDescriptionChanged);
    _descriptionController.dispose();
    super.dispose();
  }

  void _handleDescriptionChanged() {
    if (_manualDateRangeEdited || _isGenerating) return;
    _applyPromptOrDefaultRange();
  }

  String _currentCanonicalPromptText({String? sourceText}) {
    return buildCanonicalAiFlowPromptText(
      description: _descriptionController.text,
      sourceText: sourceText,
    );
  }

  void _applyPromptOrDefaultRange({bool notify = true}) {
    final range = resolveAiFlowDateRange(
      prompt: _currentCanonicalPromptText(),
      defaultStartDate: _defaultStartDate,
    );
    if (_startDate == range.startDate && _endDate == range.endDate) return;

    void assign() {
      _startDate = range.startDate;
      _endDate = range.endDate;
    }

    if (notify && mounted) {
      setState(assign);
    } else {
      assign();
    }
  }

  FlowDateRange _effectiveDateRange() {
    return resolveAiFlowDateRange(
      prompt: _currentCanonicalPromptText(),
      defaultStartDate: _defaultStartDate,
      manualStartDate: _startDate,
      manualEndDate: _endDate,
      useManualRange: _manualDateRangeEdited,
    );
  }

  int _currentDisplayedDurationDays() {
    final start = _startDate;
    final end = _endDate;
    if (start != null && end != null) {
      final days = end.difference(start).inDays + 1;
      if (days > 0) return days;
    }
    return extractFlowDurationDays(_currentCanonicalPromptText()) ??
        defaultAiFlowDurationDays;
  }

  String _dateRangeHelperText() {
    if (_manualDateRangeEdited) {
      return 'Manual range overrides prompt duration.';
    }
    final range = resolveAiFlowDateRange(
      prompt: _currentCanonicalPromptText(),
      defaultStartDate: _defaultStartDate,
    );
    if (range.source == FlowDateRangeSource.itinerarySchedule) {
      return 'Detected itinerary dates from your schedule. Tap dates to override.';
    }
    final promptDays = extractFlowDurationDays(_currentCanonicalPromptText());
    if (promptDays != null) {
      return 'Using $promptDays day${promptDays == 1 ? '' : 's'} from your prompt. Tap dates to override.';
    }
    return 'Using a 10-day default. Optional - you can also say "30 days" in your prompt.';
  }

  void _resetManualDateRange() {
    setState(() {
      _manualDateRangeEdited = false;
      _applyPromptOrDefaultRange(notify: false);
    });
  }

  Future<DateTime?> _showDatePickerForMode(DateTime? initialDate) {
    if (_mode == CalendarMode.kemetic) {
      return showKemeticDatePicker(context: context, initialDate: initialDate);
    }
    return showGregorianDatePicker(context: context, initialDate: initialDate);
  }

  Future<void> _pickRangeStart() async {
    final picked = await _showDatePickerForMode(_startDate);
    if (!mounted || picked == null) return;

    final pickedDate = dateOnlyForAiFlow(picked);
    final wasManual = _manualDateRangeEdited;
    final fallbackDays = wasManual ? 7 : _currentDisplayedDurationDays();
    setState(() {
      _manualDateRangeEdited = true;
      _startDate = pickedDate;
      if (!wasManual || _endDate == null || _endDate!.isBefore(_startDate!)) {
        _endDate = DateTime(
          _startDate!.year,
          _startDate!.month,
          _startDate!.day + fallbackDays - 1,
        );
      }
    });
  }

  Future<void> _pickRangeEnd() async {
    final picked = await _showDatePickerForMode(_endDate ?? _startDate);
    if (!mounted || picked == null) return;

    setState(() {
      _manualDateRangeEdited = true;
      _endDate = dateOnlyForAiFlow(picked);
    });
  }

  Future<void> _generate() async {
    if (!_formKey.currentState!.validate()) return;

    final split = splitAiFlowPromptForApi(_descriptionController.text);
    final canonicalPrompt = _currentCanonicalPromptText(
      sourceText: split.sourceText,
    );
    final promptType = classifyFlowPrompt(canonicalPrompt);
    debugPrint('[AI Modal] promptType=${promptType.name}');

    final selectedDateForParsing = _startDate ?? _defaultStartDate;
    final parsedItinerary = promptType == FlowPromptType.itinerarySchedule
        ? parseItineraryPrompt(
            canonicalPrompt,
            selectedStartDate: selectedDateForParsing,
            now: _defaultStartDate,
          )
        : null;

    if (promptType == FlowPromptType.itinerarySchedule &&
        (parsedItinerary == null || parsedItinerary.events.isEmpty)) {
      debugPrint(
        '[AI Modal] deterministic itinerary parser found no usable events; skipping AI service',
      );
      setState(() {
        _error =
            'Some dates or times could not be resolved. Review the pasted itinerary and try again.';
        _isGenerating = false;
      });
      return;
    }

    final dateRange = parsedItinerary == null
        ? _effectiveDateRange()
        : FlowDateRange(
            startDate: parsedItinerary.startDate,
            endDate: parsedItinerary.endDate,
            durationDays:
                parsedItinerary.endDate
                    .difference(parsedItinerary.startDate)
                    .inDays +
                1,
            source: FlowDateRangeSource.itinerarySchedule,
          );
    final startDate = dateRange.startDate;
    final endDate = dateRange.endDate;
    if (_startDate != startDate || _endDate != endDate) {
      setState(() {
        _startDate = startDate;
        _endDate = endDate;
      });
    }

    final enrichedDescription = split.description;
    final rangeDays = endDate.difference(startDate).inDays + 1;
    final visibleThinkingSteps = _buildVisibleThinkingSteps(
      hasSourceText:
          split.sourceText != null && split.sourceText!.trim().isNotEmpty,
      rangeDays: rangeDays,
    );

    setState(() {
      _isGenerating = true;
      _error = null;
      _visibleThinkingSteps = visibleThinkingSteps;
      _visibleThinkingIndex = 0;
    });
    _startVisibleThinking();

    try {
      // ✅ CRITICAL: Convert color to hex string format
      // Ensure _selectedColorIndex is within bounds
      final safeColorIndex = _selectedColorIndex.clamp(
        0,
        _flowPalette.length - 1,
      );
      final selectedColor = _flowPalette[safeColorIndex];
      final colorAsHex = aiFlowColorHexFromColor(selectedColor);

      // ✅ Safety check: ensure color is never null or empty
      if (colorAsHex.isEmpty || colorAsHex == '#') {
        throw StateError(
          'Invalid color conversion for selected AI flow color.',
        );
      }

      if (parsedItinerary != null) {
        debugPrint(
          '[AI Modal] using deterministic itinerary import '
          'events=${parsedItinerary.events.length} '
          'range=${_formatAiFlowDateOnly(parsedItinerary.startDate)}..'
          '${_formatAiFlowDateOnly(parsedItinerary.endDate)}',
        );
        final response = parsedItinerary.toAIFlowGenerationResponse(
          flowColor: colorAsHex,
        );
        _stopVisibleThinking();
        Navigator.of(context).pop(response);

        final flowName = response.flowName ?? 'Itinerary';
        final notesCount = response.notesCount ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: gold),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Created "$flowName" with $notesCount events',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1E1E1E),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }

      // ✅ Get IANA timezone name (e.g., "America/Los_Angeles") instead of "PST"/"PDT"
      final ianaTimezone = aiFlowIanaTimezoneForLocal(DateTime.now());

      // ✅ Debug: Confirm we're about to call the service
      debugPrint('[AI Modal] About to call _service.generate()...');

      // Generate flow using new simplified service API
      final response = await _invokeGenerateFlow(
        description: enrichedDescription,
        startDate: startDate,
        endDate: endDate,
        flowColor: colorAsHex,
        timezone:
            ianaTimezone, // ✅ IANA format (e.g., "America/Los_Angeles") for Edge Function
        sourceText: split.sourceText,
      );

      if (!mounted) return;

      if (response.success != true) {
        final msg =
            response.errorMessage ??
            'Generation failed. Please check your connection or try again.';
        _stopVisibleThinking();
        setState(() {
          _error = msg;
          _isGenerating = false;
        });
        return;
      }

      // Success! Close modal and return the result
      _stopVisibleThinking();
      Navigator.of(context).pop(
        response.copyWith(
          requestedStartDate: startDate,
          requestedEndDate: endDate,
        ),
      );

      // Show success message
      final flowName = response.flowName ?? 'Flow';
      final notesCount = response.notesCount ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: gold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Created "$flowName" with $notesCount events',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF1E1E1E),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e, stackTrace) {
      if (!mounted) return;

      // ✅ Log the actual error for debugging
      debugPrint('[AI Modal] Error during generation: $e');
      debugPrint('[AI Modal] Stack trace: $stackTrace');

      final rawMessage = e.toString().trim();
      final cleanMessage = rawMessage.startsWith('Exception: ')
          ? rawMessage.substring('Exception: '.length).trim()
          : rawMessage;

      _stopVisibleThinking();
      setState(() {
        _error = cleanMessage.isNotEmpty
            ? cleanMessage
            : 'Something went wrong. Please try again.';
        _isGenerating = false;
      });
    }
  }

  Future<AIFlowGenerationResponse> _invokeGenerateFlow({
    required String description,
    required DateTime startDate,
    required DateTime endDate,
    String? flowColor,
    String? timezone,
    String? sourceText,
  }) {
    final generateForTesting = widget.generateFlowForTesting;
    if (generateForTesting != null) {
      return generateForTesting(
        description: description,
        startDate: startDate,
        endDate: endDate,
        flowColor: flowColor,
        timezone: timezone,
        sourceText: sourceText,
      );
    }

    final service = _service ??= AIFlowGenerationService(
      Supabase.instance.client,
    );
    return service.generate(
      description: description,
      startDate: startDate,
      endDate: endDate,
      flowColor: flowColor,
      timezone: timezone,
      sourceText: sourceText,
    );
  }

  List<_VisibleThinkingStep> _buildVisibleThinkingSteps({
    required bool hasSourceText,
    required int rangeDays,
  }) {
    return [
      _VisibleThinkingStep(
        title: 'Reading your request',
        detail: hasSourceText
            ? 'Pulling milestones, constraints, and concrete details from your pasted notes.'
            : 'Clarifying the goal, date window, and the cadence this flow needs.',
      ),
      _VisibleThinkingStep(
        title: 'Shaping the progression',
        detail: 'Laying out a clean arc across your $rangeDays-day range.',
      ),
      const _VisibleThinkingStep(
        title: 'Placing the beats',
        detail:
            'Spacing events so the flow feels usable instead of front-loaded.',
      ),
      const _VisibleThinkingStep(
        title: 'Tightening the language',
        detail: 'Cleaning up event phrasing and stripping out generic filler.',
      ),
      const _VisibleThinkingStep(
        title: 'Finalizing the result',
        detail:
            'Packaging the flow and preparing it to drop back into your calendar.',
      ),
    ];
  }

  void _startVisibleThinking() {
    _visibleThinkingTimer?.cancel();
    if (_visibleThinkingSteps.length <= 1) return;
    _visibleThinkingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final nextIndex = _visibleThinkingIndex + 1;
      if (nextIndex >= _visibleThinkingSteps.length) {
        timer.cancel();
        return;
      }
      setState(() {
        _visibleThinkingIndex = nextIndex;
      });
    });
  }

  void _stopVisibleThinking() {
    _visibleThinkingTimer?.cancel();
    _visibleThinkingTimer = null;
    _visibleThinkingSteps = const [];
    _visibleThinkingIndex = 0;
  }

  String _formatDateRange() {
    if (_startDate == null || _endDate == null) return '';
    final days = _endDate!.difference(_startDate!).inDays + 1;
    return '$days day${days == 1 ? '' : 's'}';
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboardInset = keyboardInsetOf(context);
    final closedHeight = media.size.height * 0.85;
    final openMaxHeight = math.max(
      280.0,
      media.size.height - keyboardInset - media.padding.top - 12,
    );
    final sheetHeight = keyboardInset > 0
        ? math.min(closedHeight, openMaxHeight)
        : closedHeight;
    const fieldScrollPadding = keyboardManagedTextFieldScrollPadding;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: Container(
        height: sheetHeight,
        decoration: const BoxDecoration(
          color: Color(0xFF000000),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: gold),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GlossyText(
                          text: 'Generate with AI',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                          gradient: silverGloss,
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Describe what you want and AI will create it',
                          style: TextStyle(
                            color: Color(0xFF999999),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Description input
                      const GlossyText(
                        text: 'What do you want to create?',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        gradient: silverGloss,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _descriptionController,
                        scrollPadding: fieldScrollPadding,
                        minLines: 5,
                        maxLines: 18,
                        keyboardType: TextInputType.multiline,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText:
                              'Paste a long plan or notes and ask for a flow. Add duration naturally, e.g. "make this a 30-day flow"...',
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 14,
                          ),
                          filled: true,
                          fillColor: const Color(0xFF1E1E1E),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please describe what you want to create';
                          }
                          if (value.trim().length < 5) {
                            return 'Please be more specific';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 24),

                      // Kemetic/Gregorian toggle (matching Flow Studio)
                      CupertinoSegmentedControl<CalendarMode>(
                        groupValue: _mode,
                        padding: const EdgeInsets.all(2),
                        children: const {
                          CalendarMode.kemetic: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            child: Text('Kemetic'),
                          ),
                          CalendarMode.gregorian: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            child: Text('Gregorian'),
                          ),
                        },
                        onValueChanged: (v) => setState(() => _mode = v),
                      ),

                      const SizedBox(height: 24),

                      // Date range (matching Flow Studio exactly)
                      const GlossyText(
                        text: 'Date range (optional)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        gradient: silverGloss,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _dateRangeHelperText(),
                        style: const TextStyle(
                          color: Color(0xFF999999),
                          fontSize: 13,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(
                                  color: silver,
                                  width: 1.25,
                                ),
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.1,
                                ),
                              ),
                              onPressed: _isGenerating ? null : _pickRangeStart,
                              child: Text(
                                _startDate == null
                                    ? '--'
                                    : _formatDateForMode(_startDate!),
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(
                                  color: silver,
                                  width: 1.25,
                                ),
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.1,
                                ),
                              ),
                              onPressed: _isGenerating ? null : _pickRangeEnd,
                              child: Text(
                                _endDate == null
                                    ? '--'
                                    : _formatDateForMode(_endDate!),
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Helper text
                      if (_manualDateRangeEdited)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: _isGenerating
                                ? null
                                : _resetManualDateRange,
                            icon: const Icon(Icons.auto_awesome, size: 16),
                            label: const Text('Use prompt duration'),
                            style: TextButton.styleFrom(
                              foregroundColor: gold,
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 32),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ),

                      if (_startDate != null && _endDate != null) ...[
                        const SizedBox(height: 8),
                        Builder(
                          builder: (context) {
                            return Text(
                              'Duration: ${_formatDateRange()}',
                              style: const TextStyle(
                                color: Color(0xFF999999),
                                fontSize: 14,
                              ),
                            );
                          },
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Error message
                      if (_error != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.red.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.red,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Generate button
                      ElevatedButton(
                        onPressed: _isGenerating ? null : _generate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: gold,
                          foregroundColor: Colors.black,
                          disabledBackgroundColor: Colors.grey.shade800,
                          disabledForegroundColor: Colors.grey.shade600,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isGenerating
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.black,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'Generating flow…',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              )
                            : const Text(
                                'Generate Flow',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),

                      if (_isGenerating &&
                          _activeVisibleThinkingStep != null) ...[
                        const SizedBox(height: 12),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: Container(
                            key: ValueKey<String>(
                              _activeVisibleThinkingStep!.title,
                            ),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF111111),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: gold.withValues(alpha: 0.22),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: gold.withValues(alpha: 0.14),
                                  ),
                                  child: const Icon(
                                    Icons.auto_awesome,
                                    color: gold,
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _activeVisibleThinkingStep!.title,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _activeVisibleThinkingStep!.detail,
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.72,
                                          ),
                                          fontSize: 13,
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),

                      // Tips section
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.lightbulb_outline,
                                  color: gold,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Tips for better results',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildTip('Be specific about times if needed'),
                            _buildTip('Mention if events repeat'),
                            _buildTip('Include location if relevant'),
                            _buildTip('Limit: 10 generations per day'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTip(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '•',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatShortDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  String _formatKemeticDate(DateTime date) {
    final k = KemeticMath.fromGregorian(date);
    final month = getMonthById(k.kMonth).displayShort;
    return '$month ${k.kDay}';
  }

  String _formatDateForMode(DateTime date) {
    return _mode == CalendarMode.kemetic
        ? _formatKemeticDate(date)
        : _formatShortDate(date);
  }
}

// Glossy text widget is now imported from shared/glossy_text.dart
