import 'package:flutter/material.dart';

import '../../maat_flow_palette.dart';
import '../../maat_flow_visual_tokens.dart';
import '../domain/track_sky_course.dart';

typedef CourseSelectedCallback = void Function(TrackSkyCourseCandidate? candidate, String? freeText);

/// Course picker: ALREADY IN YOUR LIFE chips + free text. Never hard-coded intentions.
class FollowSkyCoursePicker extends StatefulWidget {
  const FollowSkyCoursePicker({
    super.key,
    required this.candidates,
    required this.onSubmit,
    this.onSetLater,
    this.title = "What don't you want daily life to quietly steal from you?",
    this.submitLabel = 'Carry this course',
    this.showSetLater = true,
  });

  final List<TrackSkyCourseCandidate> candidates;
  final CourseSelectedCallback onSubmit;
  final VoidCallback? onSetLater;
  final String title;
  final String submitLabel;
  final bool showSetLater;

  @override
  State<FollowSkyCoursePicker> createState() => _FollowSkyCoursePickerState();
}

class _FollowSkyCoursePickerState extends State<FollowSkyCoursePicker> {
  TrackSkyCourseCandidate? _selected;
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasChips = widget.candidates.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.title,
          style: const TextStyle(
            fontFamily: MaatFlowListTokens.fontFamily,
            fontSize: 22,
            height: 1.25,
            color: MaatFlowPalette.gold,
          ),
        ),
        const SizedBox(height: 16),
        if (hasChips) ...[
          Text(
            'ALREADY IN YOUR LIFE',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.2,
              color: MaatFlowListTokens.sectionLabel,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in widget.candidates)
                ChoiceChip(
                  label: Text(c.label),
                  selected: _selected?.sourceId == c.sourceId,
                  onSelected: (v) {
                    setState(() {
                      _selected = v ? c : null;
                      if (v) _controller.clear();
                    });
                  },
                  selectedColor: const Color(0xFF2A2440),
                  labelStyle: TextStyle(
                    color: _selected?.sourceId == c.sourceId
                        ? MaatFlowPalette.gold
                        : MaatFlowPalette.silverMid,
                  ),
                  side: BorderSide(
                    color: _selected?.sourceId == c.sourceId
                        ? MaatFlowPalette.gold
                        : MaatFlowListTokens.joinedCardBorder,
                  ),
                  backgroundColor: MaatFlowListTokens.joinedCardBg,
                ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Or name something else',
            style: TextStyle(fontSize: 13, color: MaatFlowPalette.silverMid),
          ),
        ] else ...[
          Text(
            'Name something else',
            style: TextStyle(fontSize: 13, color: MaatFlowPalette.silverMid),
          ),
        ],
        const SizedBox(height: 8),
        TextField(
          controller: _controller,
          style: const TextStyle(color: MaatFlowPalette.silverHi),
          cursorColor: MaatFlowPalette.gold,
          onChanged: (_) {
            if (_selected != null) setState(() => _selected = null);
          },
          decoration: InputDecoration(
            hintText: 'e.g. Finish my book',
            hintStyle: TextStyle(color: MaatFlowPalette.silverLo),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: MaatFlowListTokens.joinedCardBorder),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: MaatFlowPalette.gold),
            ),
          ),
        ),
        const SizedBox(height: 22),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: MaatFlowPalette.gold,
            foregroundColor: MaatFlowListTokens.pageBg,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: () {
            final text = _controller.text.trim();
            if (_selected != null) {
              widget.onSubmit(_selected, null);
            } else if (text.isNotEmpty) {
              widget.onSubmit(null, text);
            }
          },
          child: Text(widget.submitLabel),
        ),
        if (widget.showSetLater && widget.onSetLater != null) ...[
          const SizedBox(height: 10),
          TextButton(
            onPressed: widget.onSetLater,
            child: Text(
              'Set later',
              style: TextStyle(color: MaatFlowPalette.silverMid),
            ),
          ),
        ],
      ],
    );
  }
}
