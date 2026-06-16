import 'package:flutter/material.dart';

import 'package:mobile/features/rhythm/models/rhythm_models.dart';
import 'package:mobile/features/rhythm/theme/rhythm_theme.dart';
import 'package:mobile/widgets/keyboard_aware.dart';

import 'planner_circle_control.dart';
import 'planner_hairline_rule.dart';
import 'planner_pager_dots.dart';
import 'planner_plate.dart';
import 'planner_visual_tokens.dart';

class PlannerNotesSection extends StatelessWidget {
  const PlannerNotesSection({
    super.key,
    required this.notesLocalOnly,
    required this.noteInputController,
    required this.notes,
    required this.activeNoteIndex,
    required this.notePageController,
    required this.noteCardBuilder,
    required this.onAddNote,
    required this.onPageChanged,
    required this.onShowNotePicker,
    this.addHeroTag,
  });

  final bool notesLocalOnly;
  final TextEditingController noteInputController;
  final List<RhythmNote> notes;
  final int activeNoteIndex;
  final PageController notePageController;
  final IndexedWidgetBuilder noteCardBuilder;
  final VoidCallback onAddNote;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onShowNotePicker;
  final Object? addHeroTag;

  @override
  Widget build(BuildContext context) {
    return PlannerPlate(
      label: 'Notes',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (notesLocalOnly)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
              child: _LocalNotice(),
            ),
          LayoutBuilder(
            builder: (context, constraints) {
              final carouselWidth = constraints.maxWidth - 36;
              final squareSize =
                  (carouselWidth *
                              PlannerVisualTokens
                                  .notesCarouselViewportFraction -
                          10)
                      .clamp(220.0, 360.0)
                      .toDouble();
              return Padding(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 8),
                child: notes.isEmpty
                    ? SizedBox(height: squareSize, child: _EmptyNotesCard())
                    : SizedBox(
                        height: squareSize,
                        child: PageView.builder(
                          controller: notePageController,
                          physics: const BouncingScrollPhysics(),
                          padEnds: true,
                          itemCount: notes.length,
                          onPageChanged: onPageChanged,
                          itemBuilder: noteCardBuilder,
                        ),
                      ),
              );
            },
          ),
          if (notes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: PlannerPagerDots(
                        count: notes.length,
                        activeIndex: activeNoteIndex,
                      ),
                    ),
                  ),
                  PlannerCircleControl(
                    icon: Icons.list_alt,
                    tooltip: 'See all notes',
                    onPressed: onShowNotePicker,
                    size: 28,
                  ),
                ],
              ),
            ),
          const PlannerHairlineRule(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: TextField(
                    controller: noteInputController,
                    scrollPadding: keyboardManagedTextFieldScrollPadding,
                    minLines: 1,
                    maxLines: 3,
                    style: PlannerVisualTokens.inputText,
                    decoration: _underlineInputDecoration(
                      hintText: 'Write a note, affirmation, or reminder',
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.newline,
                    onSubmitted: (_) => onAddNote(),
                  ),
                ),
                const SizedBox(width: 12),
                PlannerCircleControl(
                  icon: Icons.add,
                  tooltip: 'Add note',
                  heroTag: addHeroTag,
                  onPressed: onAddNote,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _underlineInputDecoration({required String hintText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: PlannerVisualTokens.inputHint,
      isDense: true,
      filled: false,
      contentPadding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
      border: UnderlineInputBorder(
        borderSide: PlannerVisualTokens.quietGoldBorder,
      ),
      enabledBorder: UnderlineInputBorder(
        borderSide: PlannerVisualTokens.quietGoldBorder,
      ),
      focusedBorder: UnderlineInputBorder(
        borderSide: PlannerVisualTokens.focusedGoldBorder,
      ),
    );
  }
}

class _LocalNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orangeAccent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(PlannerVisualTokens.plateRadius),
        border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.cloud_off, color: Colors.orangeAccent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Planner notes are saved only on this device. Cloud sync is unavailable.',
              style: RhythmTheme.subheading.copyWith(
                color: Colors.orangeAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyNotesCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.black.withValues(
              alpha: PlannerVisualTokens.liftedAlpha(0.24),
            ),
            Colors.black.withValues(
              alpha: PlannerVisualTokens.liftedAlpha(0.42),
            ),
          ],
        ),
        border: Border.all(
          color: PlannerVisualTokens.gold.withValues(
            alpha: PlannerVisualTokens.liftedAlpha(0.10),
          ),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        'No notes yet. Add a quick reminder to keep it in your field today.',
        textAlign: TextAlign.center,
        style: PlannerVisualTokens.captionItalic.copyWith(fontSize: 15),
      ),
    );
  }
}
