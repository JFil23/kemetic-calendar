import 'package:flutter/material.dart';

import 'package:mobile/features/rhythm/theme/rhythm_theme.dart';
import 'package:mobile/widgets/keyboard_aware.dart';

import 'planner_hairline_rule.dart';
import 'planner_pager_dots.dart';
import 'planner_pill_button.dart';
import 'planner_plate.dart';
import 'planner_visual_tokens.dart';

class PlannerNutritionSection extends StatelessWidget {
  const PlannerNutritionSection({
    super.key,
    required this.decanName,
    required this.activeNutritionDayIndex,
    required this.nutritionFormOpen,
    required this.nutritionLoading,
    required this.nutritionMissingTable,
    required this.nutritionLocalOnly,
    required this.nutritionError,
    required this.nutritionPageController,
    required this.nutritionSourceController,
    required this.nutritionNutrientController,
    required this.nutritionPurposeController,
    required this.nutritionPageBuilder,
    required this.onToggleFormOpen,
    required this.onAddNutritionItem,
    required this.onRetryNutrition,
    required this.onNutritionPageChanged,
    required this.onOpenDecanInfo,
  });

  final String decanName;
  final int activeNutritionDayIndex;
  final bool nutritionFormOpen;
  final bool nutritionLoading;
  final bool nutritionMissingTable;
  final bool nutritionLocalOnly;
  final String? nutritionError;
  final PageController nutritionPageController;
  final TextEditingController nutritionSourceController;
  final TextEditingController nutritionNutrientController;
  final TextEditingController nutritionPurposeController;
  final IndexedWidgetBuilder nutritionPageBuilder;
  final VoidCallback onToggleFormOpen;
  final VoidCallback onAddNutritionItem;
  final VoidCallback onRetryNutrition;
  final ValueChanged<int> onNutritionPageChanged;
  final VoidCallback onOpenDecanInfo;

  @override
  Widget build(BuildContext context) {
    return PlannerPlate(
      label: 'Nutrition',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
            child: Column(
              children: [
                InkWell(
                  onTap: onToggleFormOpen,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Add to Day ${activeNutritionDayIndex + 1}',
                            style: PlannerVisualTokens.plateBody.copyWith(
                              color: const Color(0xFFDCBE82),
                              fontSize: 17,
                            ),
                          ),
                        ),
                        AnimatedRotation(
                          turns: nutritionFormOpen ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            Icons.keyboard_arrow_down,
                            color: PlannerVisualTokens.gold.withValues(
                              alpha: PlannerVisualTokens.liftedAlpha(0.55),
                            ),
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  height: 0.5,
                  color: PlannerVisualTokens.gold.withValues(
                    alpha: PlannerVisualTokens.liftedAlpha(0.10),
                  ),
                ),
                AnimatedCrossFade(
                  crossFadeState: nutritionFormOpen
                      ? CrossFadeState.showFirst
                      : CrossFadeState.showSecond,
                  duration: const Duration(milliseconds: 220),
                  firstChild: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _NutritionTextField(
                          controller: nutritionSourceController,
                          labelText: 'Source',
                          hintText: 'Source',
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 12),
                        _NutritionTextField(
                          controller: nutritionNutrientController,
                          labelText: 'Nutrient (optional)',
                          hintText: 'Nutrient (optional)',
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 12),
                        _NutritionTextField(
                          controller: nutritionPurposeController,
                          labelText: 'Purpose (optional)',
                          hintText: 'Purpose (optional)',
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => onAddNutritionItem(),
                        ),
                        const SizedBox(height: 14),
                        Align(
                          alignment: Alignment.centerRight,
                          child: PlannerPillButton(
                            label: 'Add to grid',
                            icon: Icons.add,
                            active: true,
                            onPressed: nutritionLoading
                                ? null
                                : onAddNutritionItem,
                          ),
                        ),
                      ],
                    ),
                  ),
                  secondChild: const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          if (nutritionMissingTable || nutritionLocalOnly)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
              child: _Notice(
                icon: Icons.cloud_off,
                color: Colors.orangeAccent,
                text: nutritionLocalOnly
                    ? 'Nutrition sources are saved only on this device. Cloud sync is unavailable.'
                    : 'Nutrition tracking is not available in this environment yet.',
              ),
            ),
          if (nutritionError != null &&
              !nutritionMissingTable &&
              !nutritionLocalOnly)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
              child: _ErrorNotice(
                text: nutritionError!,
                onRetryNutrition: onRetryNutrition,
              ),
            ),
          if (nutritionLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 22),
              child: Center(
                child: SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.6,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      PlannerVisualTokens.gold,
                    ),
                  ),
                ),
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
              child: SizedBox(
                height: 230,
                child: PageView.builder(
                  controller: nutritionPageController,
                  physics: const BouncingScrollPhysics(),
                  padEnds: true,
                  itemCount: 10,
                  onPageChanged: onNutritionPageChanged,
                  itemBuilder: nutritionPageBuilder,
                ),
              ),
            ),
            const PlannerHairlineRule(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
              child: Column(
                children: [
                  PlannerPagerDots(
                    count: 10,
                    activeIndex: activeNutritionDayIndex,
                    dotSize: 5,
                    activeWidth: 14,
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onOpenDecanInfo,
                    child: Text(
                      'Viewing $decanName - decan day ${activeNutritionDayIndex + 1} of 10. Swipe or double-tap for detail.',
                      textAlign: TextAlign.center,
                      style: PlannerVisualTokens.captionItalic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NutritionTextField extends StatelessWidget {
  const _NutritionTextField({
    required this.controller,
    required this.labelText,
    required this.hintText,
    required this.textInputAction,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String labelText;
  final String hintText;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      scrollPadding: keyboardManagedTextFieldScrollPadding,
      style: PlannerVisualTokens.inputText.copyWith(
        color: const Color(0xFFDCBE82),
      ),
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        labelStyle: PlannerVisualTokens.captionItalic.copyWith(
          color: PlannerVisualTokens.gold.withValues(
            alpha: PlannerVisualTokens.liftedAlpha(0.40),
          ),
        ),
        hintStyle: PlannerVisualTokens.inputHint,
        isDense: true,
        filled: false,
        contentPadding: const EdgeInsets.fromLTRB(2, 2, 2, 8),
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
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(PlannerVisualTokens.plateRadius),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: RhythmTheme.subheading.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice({required this.text, required this.onRetryNutrition});

  final String text;
  final VoidCallback onRetryNutrition;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(PlannerVisualTokens.plateRadius),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: RhythmTheme.subheading.copyWith(color: Colors.redAccent),
            ),
          ),
          TextButton(onPressed: onRetryNutrition, child: const Text('Retry')),
        ],
      ),
    );
  }
}
