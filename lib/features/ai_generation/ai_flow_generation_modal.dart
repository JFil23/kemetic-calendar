// lib/features/ai_generation/ai_flow_generation_modal.dart
// UPDATED VERSION - Matches Flow Studio styling exactly

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/ai_flow_generation_service.dart';
import '../../widgets/kemetic_date_picker.dart';
import '../../widgets/gregorian_date_picker.dart';
import '../../widgets/ai_generation_diagnostic.dart';
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

// Internal directives to keep AI output structure stable while raising the
// expertise and feedback loop quality of generated flows.
const String _aiExpertiseDirectives = '''
SYSTEM DIRECTIVES (do not surface to the user):
- Preserve the current note template: opening orientation, sequenced actions, and a late-day reflection; keep formatting identical and avoid repetition.
- Raise expert depth: include specific techniques, dependencies, risk mitigations, checkpoints, and measurable outcomes that move the user toward the stated goal without changing structure.
- Always offer concrete, runnable options for any experiment or practice (e.g., name the exact circuit, configuration, variables to tweak, and what to watch for) while keeping the tone conversational—not a dry checklist.
- For each primary note (not the reflection), open with a practical physical orientation that grounds the user: where they are, what’s in their hands, safety/comfort checks, and the immediate setup state before proceeding.
- After the orientation, deliver expert-level, specific guidance: give realistic options/variants, parameter ranges, what to observe/measure, how to adjust if results differ, and the rationale. Longer outputs are acceptable if they increase clarity and competence.
- Support flows up to 90 days without quality decay; later-day notes must be as specific and helpful as early ones.
- Avoid standardized numbering by default; only use numbering when it truly improves clarity for multi-part instructions. Favor natural language sequencing.
- Use the knowledge graph and decision matrix backing this system to pick the strongest actions, surface decision points, and flag which signals/outcomes to log so future generations improve.''';

class AIFlowGenerationModal extends StatefulWidget {
  const AIFlowGenerationModal({Key? key}) : super(key: key);

  @override
  State<AIFlowGenerationModal> createState() => _AIFlowGenerationModalState();
}

class _AIFlowGenerationModalState extends State<AIFlowGenerationModal> {
  final _service = AIFlowGenerationService(Supabase.instance.client);
  final _descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  DateTime? _startDate;
  DateTime? _endDate;
  int _selectedColorIndex = 0;
  CalendarMode _mode = CalendarMode.gregorian;
  bool _isGenerating = false;
  String? _error;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickRangeStart() async {
    final picked = _mode == CalendarMode.kemetic
        ? await showKemeticDatePicker(context: context, initialDate: _startDate)
        : await showGregorianDatePicker(
            context: context,
            initialDate: _startDate,
          );

    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (_endDate == null || _endDate!.isBefore(_startDate!)) {
          _endDate = _startDate!.add(const Duration(days: 6));
        }
      });
    }
  }

  Future<void> _pickRangeEnd() async {
    final picked = _mode == CalendarMode.kemetic
        ? await showKemeticDatePicker(
            context: context,
            initialDate: _endDate ?? _startDate,
          )
        : await showGregorianDatePicker(
            context: context,
            initialDate: _endDate ?? _startDate,
          );

    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
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

    setState(() {
      _isGenerating = true;
      _error = null;
    });

    try {
      final split = _splitForFlowApi(_descriptionController.text);
      final enrichedDescription = split.description;

      // ✅ CRITICAL: Convert color to hex string format
      // Ensure _selectedColorIndex is within bounds
      final safeColorIndex = _selectedColorIndex.clamp(
        0,
        _flowPalette.length - 1,
      );
      final selectedColor = _flowPalette[safeColorIndex];
      final colorValue = selectedColor.value;
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

      // ✅ Debug logging (keep until first successful test)
      if (kDebugMode) {
        print(
          '🎨 [AI Modal] Color index: $_selectedColorIndex (safe: $safeColorIndex)',
        );
        print('🎨 [AI Modal] Color value (ARGB int): $colorValue');
        print('🎨 [AI Modal] Color as hex string: $colorAsHex');
        print('🚀 [AI Modal] Request payload:');
        print('   Description: $enrichedDescription');
        print('   Start Date: ${_formatDate(_startDate!)}');
        print('   End Date: ${_formatDate(_endDate!)}');
        print('   Flow Color: $colorAsHex'); // Should always be "#rrggbb"
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
        setState(() {
          _error = msg;
          _isGenerating = false;
        });
        return;
      }

      // Success! Close modal and return the result
      Navigator.of(context).pop(response);

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

      setState(() {
        _error = 'Something went wrong. Please try again.';
        _isGenerating = false;
      });
    }
  }

  String _formatDateRange() {
    if (_startDate == null || _endDate == null) return '';
    final days = _endDate!.difference(_startDate!).inDays + 1;
    return '$days day${days == 1 ? '' : 's'}';
  }

  /// Keep user prompt intact while injecting system directives that boost
  /// expertise, knowledge-graph use, and decision quality without altering
  /// the established flow format.
  String _composeDirectivePrompt(String rawDescription) {
    final trimmed = rawDescription.trim();
    if (trimmed.isEmpty) return _aiExpertiseDirectives.trim();
    return '$trimmed\n\n$_aiExpertiseDirectives'.trim();
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

  /// Long pastes go to `source_text` on the edge function so the model treats
  /// them as authoritative material while keeping DICTATION heuristics off.
  ({String description, String? sourceText}) _splitForFlowApi(String raw) {
    final trimmed = raw.trim();
    final directives = _aiExpertiseDirectives.trim();
    if (trimmed.isEmpty) {
      return (description: _composeDirectivePrompt(''), sourceText: null);
    }
    if (trimmed.length <= 2800) {
      return (description: _composeDirectivePrompt(trimmed), sourceText: null);
    }
    final intent = _extractLongPasteIntent(trimmed);
    return (
      description:
          '$directives\n\nUSER_INTENT_SUMMARY:\n$intent\n\nTransform SOURCE_TEXT into a staged flow for the selected date range. Preserve concrete initiatives, constraints, milestones, numbers, and sequence from SOURCE_TEXT instead of collapsing it into generic advice.',
      sourceText: trimmed,
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
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
                if (kDebugMode)
                  IconButton(
                    icon: const Icon(Icons.bug_report, color: Colors.orange),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AIGenerationDiagnosticWidget(),
                        ),
                      );
                    },
                    tooltip: 'Run Diagnostics',
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
                      minLines: 5,
                      maxLines: 18,
                      keyboardType: TextInputType.multiline,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText:
                            'Paste a long plan or notes, pick your date range (e.g. 90 days), and ask to turn it into a flow…',
                        hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.4),
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
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
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
                            child: Text(
                              'Kemetic',
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                          CalendarMode.gregorian: Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'Gregorian',
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                        },
                      ),
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
                                  : _formatShortDate(_startDate!),
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
                                  : _formatShortDate(_endDate!),
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
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.red.withOpacity(0.3),
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
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.black,
                                ),
                              ),
                            )
                          : const Text(
                              'Generate Flow',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),

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
            ),
          ),
        ],
      ),
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
              color: Colors.white.withOpacity(0.6),
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
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
