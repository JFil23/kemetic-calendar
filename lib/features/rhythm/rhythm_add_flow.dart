import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
            child: Text(
              'Choose a section',
              style: RhythmTheme.heading.copyWith(fontSize: 18),
            ),
          ),
          ...categories.map(
            (c) => ListTile(title: Text(c), onTap: () => Navigator.pop(ctx, c)),
          ),
        ],
      ),
    ),
  );
  if (!context.mounted || selected == null) return;

  if (selected == 'Restoration') {
    context.go(
      '/rhythm/editor/untimed?category=${Uri.encodeComponent(selected)}',
    );
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
            subtitle: const Text(
              'Wake windows, deep work, anchors with a time window',
            ),
            onTap: () => Navigator.pop(ctx, 'timed'),
          ),
          ListTile(
            title: const Text('Notes & practices'),
            subtitle: const Text(
              'Gentle commitments without a fixed clock time',
            ),
            onTap: () => Navigator.pop(ctx, 'untimed'),
          ),
        ],
      ),
    ),
  );
  if (!context.mounted || mode == null) return;

  if (mode == 'timed') {
    context.go(
      '/rhythm/editor/timed?category=${Uri.encodeComponent(selected)}',
    );
  } else {
    context.go(
      '/rhythm/editor/untimed?category=${Uri.encodeComponent(selected)}',
    );
  }
}
