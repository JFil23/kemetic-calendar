// lib/features/ai_generation/ai_flow_generation_modal.dart
// UPDATED VERSION - Matches Flow Studio styling exactly

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/ai_flow_generation_service.dart';
import '../../models/ai_flow_generation_response.dart';
import '../../widgets/kemetic_date_picker.dart';
import '../../widgets/gregorian_date_picker.dart';
import 'package:mobile/shared/glossy_text.dart';

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

LinearGradient _glossFromColor(Color c) {
  final hsl = HSLColor.fromColor(c);
  final lighter = hsl
      .withLightness((hsl.lightness + 0.15).clamp(0.0, 1.0))
      .toColor();
  final darker = hsl
      .withLightness((hsl.lightness - 0.15).clamp(0.0, 1.0))
      .toColor();
  return LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [lighter, c, darker],
    stops: const [0.0, 0.5, 1.0],
  );
}

enum CalendarMode { kemetic, gregorian }

class _VisibleThinkingStep {
  const _VisibleThinkingStep({required this.title, required this.detail});

  final String title;
  final String detail;
}

class AIFlowGenerationModal extends StatelessWidget {
  const AIFlowGenerationModal({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF000000),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: AIFlowGenerationPanel(
        showHeader: true,
        onClose: () => Navigator.pop(context),
        onGenerated: (response) {
          Navigator.of(context).pop(response);
        },
      ),
    );
  }
}

class AIFlowGenerationPanel extends StatefulWidget {
  const AIFlowGenerationPanel({
    required this.onGenerated,
    this.showHeader = false,
    this.onClose,
    this.initialStartDate,
    this.initialEndDate,
    super.key,
  });

  final FutureOr<void> Function(AIFlowGenerationResponse response) onGenerated;
  final bool showHeader;
  final VoidCallback? onClose;
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;

  @override
  State<AIFlowGenerationPanel> createState() => _AIFlowGenerationPanelState();
}

class _AIFlowGenerationPanelState extends State<AIFlowGenerationPanel> {
  final _service = AIFlowGenerationService(Supabase.instance.client);
  final _descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  DateTime? _startDate;
  DateTime? _endDate;
  int _selectedColorIndex = 0;
  CalendarMode _mode = CalendarMode.gregorian;
  bool _isGenerating = false;
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
    _startDate = widget.initialStartDate;
    _endDate = widget.initialEndDate;
  }

  @override
  void dispose() {
    _stopVisibleThinking();
    _descriptionController.dispose();
    super.dispose();
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

    setState(() {
      _startDate = picked;
      if (_endDate == null || _endDate!.isBefore(_startDate!)) {
        _endDate = _startDate!.add(const Duration(days: 6));
      }
    });
  }

  Future<void> _pickRangeEnd() async {
    final picked = await _showDatePickerForMode(_endDate ?? _startDate);
    if (!mounted || picked == null) return;

    setState(() {
      _endDate = picked;
    });
  }

  Future<void> _generate() async {
    if (!_formKey.currentState!.validate()) return;

    // Require dates to be selected
    if (_startDate == null || _endDate == null) {
      setState(() {
        _error = 'Please select start and end dates';
      });
      return;
    }

    final split = _splitForFlowApi(_descriptionController.text);
    final enrichedDescription = split.description;
    final rangeDays = _endDate!.difference(_startDate!).inDays + 1;
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
      final colorValue = selectedColor.toARGB32();
      final hexString = colorValue
          .toRadixString(16)
          .substring(2)
          .padLeft(6, '0');
      final colorAsHex = '#$hexString';

      // ✅ Safety check: ensure color is never null or empty
      if (colorAsHex.isEmpty || colorAsHex == '#') {
        throw StateError(
          'Invalid color conversion: $colorValue -> $colorAsHex',
        );
      }

      // ✅ Get IANA timezone name (e.g., "America/Los_Angeles") instead of "PST"/"PDT"
      final nowLocal = DateTime.now();
      final offsetHours = nowLocal.timeZoneOffset.inHours;
      final timezoneMap = {
        -8: 'America/Los_Angeles', // PST (winter)
        -7: 'America/Los_Angeles', // PDT (summer)
        -6: 'America/Denver', // MDT (summer) or CST (winter)
        -5: 'America/Chicago', // CDT (summer) or EST (winter)
        -4: 'America/New_York', // EDT (summer)
        -10: 'Pacific/Honolulu', // HST (no DST)
        -9: 'America/Anchorage', // AKST/AKDT
        0: 'Europe/London', // GMT/BST
        1: 'Europe/Paris', // CET/CEST
        8: 'Asia/Singapore', // SGT
        9: 'Asia/Tokyo', // JST
        10: 'Australia/Sydney', // AEST/AEDT
      };
      final ianaTimezone = timezoneMap[offsetHours] ?? 'America/Los_Angeles';

      // ✅ Debug: Confirm we're about to call the service
      debugPrint('[AI Modal] About to call _service.generate()...');

      // Generate flow using new simplified service API
      final response = await _service.generate(
        description: enrichedDescription,
        startDate: _startDate!,
        endDate: _endDate!,
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

      // Success! Return the generated response to the caller.
      _stopVisibleThinking();
      await widget.onGenerated(
        response.copyWith(
          requestedStartDate: _startDate,
          requestedEndDate: _endDate,
        ),
      );
      if (!mounted) return;
      setState(() {
        _isGenerating = false;
      });
    } catch (e, stackTrace) {
      if (!mounted) return;

      // ✅ Log the actual error for debugging
      debugPrint('[AI Modal] Error during generation: $e');
      debugPrint('[AI Modal] Stack trace: $stackTrace');

      _stopVisibleThinking();
      setState(() {
        _error = 'Something went wrong. Please try again.';
        _isGenerating = false;
      });
    }
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

  bool _looksLikeTelemetryBlock(String block) {
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

  String _extractLongPasteIntent(String raw) {
    final blocks = raw
        .split(RegExp(r'\n\s*\n'))
        .map((b) => b.trim())
        .where((b) => b.isNotEmpty)
        .toList();
    final proseBlocks = blocks
        .where((b) => !_looksLikeTelemetryBlock(b))
        .toList();
    if (proseBlocks.isEmpty) {
      return raw.length > 1800 ? '${raw.substring(0, 1800)}…' : raw;
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
    return summary.length > 1800 ? '${summary.substring(0, 1800)}…' : summary;
  }

  bool _shouldSendAsSourceMaterial(String raw) {
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
  /// them as authoritative material while keeping DICTATION heuristics off.
  ({String description, String? sourceText}) _splitForFlowApi(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return (description: '', sourceText: null);
    }
    if (!_shouldSendAsSourceMaterial(trimmed)) {
      return (description: trimmed, sourceText: null);
    }
    final intent = _extractLongPasteIntent(trimmed);
    return (
      description:
          'USER_INTENT_SUMMARY:\n$intent\n\nTransform SOURCE_TEXT into a flow for the selected date range. Preserve concrete initiatives, constraints, milestones, numbers, sequence, and voice from SOURCE_TEXT. Organize it into a clear progression instead of generic summaries.',
      sourceText: trimmed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Description input
            const GlossyText(
              text: 'What do you want to create?',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              gradient: silverGloss,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descriptionController,
              minLines: 5,
              maxLines: 18,
              keyboardType: TextInputType.multiline,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText:
                    'Paste a long plan or notes, pick your date range (e.g. 90 days), and ask to turn it into a flow…',
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

            // Color picker (matching Flow Studio exactly)
            const GlossyText(
              text: 'Color',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              gradient: silverGloss,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 36,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _flowPalette.length,
                itemBuilder: (_, i) => _colorDot(i),
              ),
            ),

            const SizedBox(height: 24),

            // Kemetic/Gregorian toggle (matching Flow Studio)
            SizedBox(
              width: double.infinity,
              child: CupertinoSegmentedControl<CalendarMode>(
                groupValue: _mode,
                onValueChanged: (v) => setState(() => _mode = v),
                borderColor: silver,
                selectedColor: const Color(0xFF7C4DFF),
                unselectedColor: Colors.white,
                children: const {
                  CalendarMode.kemetic: Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Kemetic', style: TextStyle(fontSize: 14)),
                  ),
                  CalendarMode.gregorian: Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Gregorian', style: TextStyle(fontSize: 14)),
                  ),
                },
              ),
            ),

            const SizedBox(height: 24),

            // Date range (matching Flow Studio exactly)
            const GlossyText(
              text: 'Date range (optional)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              gradient: silverGloss,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: silver, width: 1.25),
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
                      _startDate == null ? '--' : _formatShortDate(_startDate!),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: silver, width: 1.25),
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
                      _endDate == null ? '--' : _formatShortDate(_endDate!),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Helper text
            const Text(
              'Set a start and end date to define rules',
              style: TextStyle(color: Color(0xFF999999), fontSize: 14),
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
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
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
                        style: const TextStyle(color: Colors.red, fontSize: 14),
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

            if (_isGenerating && _activeVisibleThinkingStep != null) ...[
              const SizedBox(height: 12),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: Container(
                  key: ValueKey<String>(_activeVisibleThinkingStep!.title),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111111),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: gold.withValues(alpha: 0.22)),
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
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                                color: Colors.white.withValues(alpha: 0.72),
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
                      Icon(Icons.lightbulb_outline, color: gold, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Tips for better results',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
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
    );

    if (!widget.showHeader) {
      return content;
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (widget.onClose != null)
                IconButton(
                  icon: const Icon(Icons.close, color: gold),
                  onPressed: widget.onClose,
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
                      style: TextStyle(color: Color(0xFF999999), fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(child: content),
      ],
    );
  }

  // Color dot widget (matching Flow Studio exactly)
  Widget _colorDot(int i) {
    final selected = i == _selectedColorIndex;
    return InkWell(
      onTap: () => setState(() => _selectedColorIndex = i),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 28,
        height: 28,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: _glossFromColor(_flowPalette[i]),
          border: Border.all(
            color: selected ? gold : Colors.white24,
            width: selected ? 2.0 : 1.0,
          ),
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
}

// Glossy text widget is now imported from shared/glossy_text.dart
