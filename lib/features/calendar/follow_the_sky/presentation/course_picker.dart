import 'package:flutter/material.dart';

import '../../../../widgets/keyboard_aware.dart';
import '../../maat_flow_palette.dart';
import '../../maat_flow_visual_tokens.dart';
import '../domain/track_sky_course.dart';

typedef CourseSelectedCallback = void Function(
  TrackSkyCourseCandidate? candidate,
  String? freeText,
);

/// Compact course section for the Follow the Sky detail page.
/// Chips only when candidates exist; outlined CTA (no solid gold pill).
class FollowSkyCoursePicker extends StatefulWidget {
  const FollowSkyCoursePicker({
    super.key,
    required this.candidates,
    required this.onSubmit,
    this.onSetLater,
    this.onDraftChanged,
    this.prompt = "What don’t you want daily life to quietly steal from you?",
    this.submitLabel = 'Carry this course',
    this.showSetLater = true,
    this.showSubmitButton = true,
    this.sectionLabel = 'ONE THING TO CARRY',
    this.helperText = 'ḥꜣw will carry it between turnings.',
    this.nameElseLabel = 'Or name something else',
    this.placeholder = 'Finish my book',
  });

  final List<TrackSkyCourseCandidate> candidates;
  final CourseSelectedCallback onSubmit;
  final VoidCallback? onSetLater;
  final VoidCallback? onDraftChanged;
  final String prompt;
  final String submitLabel;
  final bool showSetLater;
  final bool showSubmitButton;
  final String sectionLabel;
  final String helperText;
  final String nameElseLabel;
  final String placeholder;

  @override
  State<FollowSkyCoursePicker> createState() => FollowSkyCoursePickerState();
}

class FollowSkyCoursePickerState extends State<FollowSkyCoursePicker> {
  TrackSkyCourseCandidate? _selected;
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool get canSubmit =>
      _selected != null || _controller.text.trim().isNotEmpty;

  void focusField() {
    _focusNode.requestFocus();
  }

  /// Returns true if a course draft was submitted.
  bool submitIfReady() {
    if (!canSubmit) {
      focusField();
      return false;
    }
    final text = _controller.text.trim();
    if (_selected != null) {
      widget.onSubmit(_selected, null);
      return true;
    }
    if (text.isNotEmpty) {
      widget.onSubmit(null, text);
      return true;
    }
    return false;
  }

  void _notifyDraft() {
    widget.onDraftChanged?.call();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final hasChips = widget.candidates.isNotEmpty;
    final sky = MaatFlowPalette.resolve(
      flowId: 'track-the-sky',
      accent: const Color(0xFF6876D8),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.sectionLabel,
          style: const TextStyle(
            fontSize: 10.5,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w600,
            color: MaatFlowListTokens.sectionLabel,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.prompt,
          style: const TextStyle(
            fontFamily: MaatFlowListTokens.fontFamily,
            fontFamilyFallback: MaatFlowListTokens.fontFallback,
            fontSize: 16,
            height: 1.35,
            color: MaatFlowPalette.silverHi,
          ),
        ),
        if (hasChips) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final c in widget.candidates)
                Semantics(
                  label: c.provenance,
                  child: ChoiceChip(
                    label: Text(c.label),
                    selected: _selected?.sourceId == c.sourceId,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onSelected: (v) {
                      setState(() {
                        _selected = v ? c : null;
                        if (v) _controller.clear();
                      });
                      widget.onDraftChanged?.call();
                    },
                    selectedColor: const Color(0xFF241F14),
                    labelStyle: TextStyle(
                      fontSize: 12.5,
                      color: _selected?.sourceId == c.sourceId
                          ? MaatFlowPalette.gold
                          : sky.glowColor.withValues(alpha: 0.78),
                    ),
                    side: BorderSide(
                      color: _selected?.sourceId == c.sourceId
                          ? MaatFlowPalette.gold
                          : sky.accent.withValues(alpha: 0.35),
                    ),
                    backgroundColor: sky.accent.withValues(alpha: 0.07),
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        Text(
          widget.nameElseLabel,
          style: TextStyle(
            fontSize: 12.5,
            fontStyle: FontStyle.italic,
            color: MaatFlowPalette.silverLo,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          scrollPadding: keyboardManagedTextFieldScrollPadding,
          style: const TextStyle(
            color: MaatFlowPalette.silverHi,
            fontSize: 15,
          ),
          cursorColor: MaatFlowPalette.gold,
          onChanged: (_) {
            if (_selected != null) setState(() => _selected = null);
            _notifyDraft();
          },
          decoration: InputDecoration(
            isDense: true,
            hintText: widget.placeholder,
            hintStyle: TextStyle(
              color: MaatFlowPalette.silverLo,
              fontSize: 14,
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: MaatFlowListTokens.joinedCardBorder),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: MaatFlowPalette.gold),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.helperText,
          style: const TextStyle(
            fontSize: 12.5,
            fontStyle: FontStyle.italic,
            color: MaatFlowPalette.silverLo,
            height: 1.35,
          ),
        ),
        if (widget.showSubmitButton) ...[
          const SizedBox(height: 14),
          SizedBox(
            height: 43,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: MaatFlowPalette.gold,
                side: const BorderSide(color: MaatFlowPalette.gold, width: 1.1),
                backgroundColor: MaatFlowPalette.gold.withValues(alpha: 0.055),
                shape: const StadiumBorder(),
              ),
              onPressed: !canSubmit
                  ? null
                  : () {
                      submitIfReady();
                    },
              child: Text(
                widget.submitLabel,
                style: const TextStyle(
                  fontFamily: MaatFlowListTokens.fontFamily,
                  fontFamilyFallback: MaatFlowListTokens.fontFallback,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
        if (widget.showSetLater && widget.onSetLater != null) ...[
          const SizedBox(height: 4),
          TextButton(
            onPressed: widget.onSetLater,
            child: Text(
              'Set later',
              style: TextStyle(
                fontSize: 14,
                color: MaatFlowPalette.silverMid,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
