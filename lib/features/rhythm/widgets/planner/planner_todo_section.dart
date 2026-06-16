import 'package:flutter/material.dart';

import 'package:mobile/widgets/keyboard_aware.dart';

import 'planner_hairline_rule.dart';
import 'planner_pager_dots.dart';
import 'planner_pill_button.dart';
import 'planner_plate.dart';
import 'planner_visual_tokens.dart';

class PlannerTodoSection extends StatelessWidget {
  const PlannerTodoSection({
    super.key,
    required this.activeDayLabel,
    required this.activeDayIsToday,
    required this.dateAccentColor,
    required this.commitmentInputController,
    required this.plannerLoading,
    required this.loadingSlot,
    required this.todoPageHeight,
    required this.todoPageController,
    required this.todoDayCount,
    required this.activeTodoDayIndex,
    required this.todoPageBuilder,
    required this.onAddTodo,
    required this.onTodoPageChanged,
  });

  final String activeDayLabel;
  final bool activeDayIsToday;
  final Color dateAccentColor;
  final TextEditingController commitmentInputController;
  final bool plannerLoading;
  final Widget loadingSlot;
  final double todoPageHeight;
  final PageController todoPageController;
  final int todoDayCount;
  final int activeTodoDayIndex;
  final IndexedWidgetBuilder todoPageBuilder;
  final VoidCallback onAddTodo;
  final ValueChanged<int> onTodoPageChanged;

  @override
  Widget build(BuildContext context) {
    return PlannerPlate(
      label: 'To Do',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_month_rounded,
                  size: 16,
                  color: dateAccentColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    activeDayLabel,
                    style: PlannerVisualTokens.ceremonialItalic.copyWith(
                      color: dateAccentColor.withValues(
                        alpha: PlannerVisualTokens.liftedAlpha(0.78),
                      ),
                      fontSize: 16,
                    ),
                  ),
                ),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: commitmentInputController,
                  builder: (context, value, child) {
                    final hasText = value.text.trim().isNotEmpty;
                    return PlannerPillButton(
                      label: 'Add',
                      icon: Icons.add,
                      onPressed: hasText ? onAddTodo : null,
                    );
                  },
                ),
                if (activeDayIsToday) ...[
                  const SizedBox(width: 10),
                  const PlannerPillButton(label: 'Today', active: true),
                ],
              ],
            ),
          ),
          const PlannerHairlineRule(margin: EdgeInsets.zero),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
            child: TextField(
              controller: commitmentInputController,
              scrollPadding: keyboardManagedTextFieldScrollPadding,
              style: PlannerVisualTokens.inputText,
              decoration: InputDecoration(
                hintText: 'Name a commitment to move today',
                hintStyle: PlannerVisualTokens.inputHint,
                filled: false,
                isDense: true,
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
              ),
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => onAddTodo(),
            ),
          ),
          const PlannerHairlineRule(margin: EdgeInsets.zero),
          if (plannerLoading)
            Padding(padding: const EdgeInsets.all(18), child: loadingSlot)
          else
            SizedBox(
              height: todoPageHeight,
              child: PageView.builder(
                controller: todoPageController,
                physics: const BouncingScrollPhysics(),
                onPageChanged: onTodoPageChanged,
                itemCount: todoDayCount,
                itemBuilder: todoPageBuilder,
              ),
            ),
          const PlannerHairlineRule(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
            child: Column(
              children: [
                PlannerPagerDots(
                  count: todoDayCount,
                  activeIndex: activeTodoDayIndex,
                  dotSize: 5,
                  activeWidth: 14,
                ),
                const SizedBox(height: 10),
                Text(
                  'Swipe to review the previous 2 days or plan 2 days ahead.',
                  textAlign: TextAlign.center,
                  style: PlannerVisualTokens.captionItalic,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
