import 'package:flutter/material.dart';

import '../../theme/rhythm_theme.dart';

const nutritionTimeEditorRowKey = ValueKey<String>('nutrition-editor-time-row');
const nutritionTimeEditorLabelKey = ValueKey<String>(
  'nutrition-editor-time-label',
);
const nutritionTimeEditorValueKey = ValueKey<String>(
  'nutrition-editor-time-value',
);

class NutritionTimeEditorRow extends StatelessWidget {
  const NutritionTimeEditorRow({
    super.key,
    required this.value,
    required this.onTap,
    this.enabled = true,
  });

  final String value;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Time',
      value: value,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: nutritionTimeEditorRowKey,
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: SizedBox(
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Text(
                      'Time',
                      key: nutritionTimeEditorLabelKey,
                      style: RhythmTheme.label.copyWith(color: Colors.white54),
                    ),
                    const Spacer(),
                    Text(
                      value,
                      key: nutritionTimeEditorValueKey,
                      style: RhythmTheme.subheading.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
