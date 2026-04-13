import 'package:flutter/material.dart';

import 'package:mobile/features/rhythm/pages/rhythm_editors.dart';
import 'package:mobile/features/rhythm/theme/rhythm_theme.dart';

/// Section picker → timed vs untimed (except Restoration) → editor. Calls [onSaved] after a successful save.
Future<void> openRhythmAddFlow(
  BuildContext context, {
  VoidCallback? onSaved,
}) async {
  const categories = <String>[
    'Rhythm of Day',
    'Body & Nourishment',
    'Restoration',
    'Anchors',
    'Nourishing Activities',
    'Custom',
  ];
  final selected = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text('Choose a section', style: RhythmTheme.heading.copyWith(fontSize: 18)),
          ),
          ...categories.map(
            (c) => ListTile(
              title: Text(c),
              onTap: () => Navigator.pop(ctx, c),
            ),
          ),
        ],
      ),
    ),
  );
  if (!context.mounted || selected == null) return;

  if (selected == 'Restoration') {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => UntimedRhythmEditorPage(category: selected),
      ),
    );
    if (ok == true) onSaved?.call();
    return;
  }

  final mode = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text('Rhythm with times'),
            subtitle: const Text('Wake windows, deep work, anchors with a time window'),
            onTap: () => Navigator.pop(ctx, 'timed'),
          ),
          ListTile(
            title: const Text('Notes & practices'),
            subtitle: const Text('Gentle commitments without a fixed clock time'),
            onTap: () => Navigator.pop(ctx, 'untimed'),
          ),
        ],
      ),
    ),
  );
  if (!context.mounted || mode == null) return;

  if (mode == 'timed') {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => TimedRhythmEditorPage(categoryDisplay: selected),
      ),
    );
    if (ok == true) onSaved?.call();
  } else {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => UntimedRhythmEditorPage(category: selected),
      ),
    );
    if (ok == true) onSaved?.call();
  }
}
