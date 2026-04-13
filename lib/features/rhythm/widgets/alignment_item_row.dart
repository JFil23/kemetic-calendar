import 'package:flutter/material.dart';

import '../models/rhythm_models.dart';
import 'rhythm_row.dart';
import 'rhythm_state_button.dart';

class AlignmentItemRow extends StatelessWidget {
  const AlignmentItemRow({
    super.key,
    required this.item,
    this.onStateChanged,
  });

  final RhythmItem item;
  final ValueChanged<RhythmItemState>? onStateChanged;

  @override
  Widget build(BuildContext context) {
    return RhythmRow(
      item: item,
      trailing: RhythmStateButtonGroup(
        current: item.state ?? RhythmItemState.pending,
        onChanged: onStateChanged,
      ),
    );
  }
}
