import 'package:flutter/material.dart';

import '../../main.dart' show Events;
import 'journal_controller.dart';
import 'journal_overlay.dart';

class JournalPage extends StatefulWidget {
  const JournalPage({
    super.key,
    required this.controller,
    this.entryPoint = 'page_button',
  });

  final JournalController controller;
  final String entryPoint;

  @override
  State<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage> {
  bool _trackedOpen = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_trackedOpen) return;

    final orientation = MediaQuery.of(context).orientation;
    Events.trackIfAuthed('journal_opened', {
      'entry_point': widget.entryPoint,
      'orientation': orientation == Orientation.portrait
          ? 'portrait'
          : 'landscape',
      'presentation': 'page',
    });
    _trackedOpen = true;
  }

  @override
  Widget build(BuildContext context) {
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;

    return JournalOverlay(
      controller: widget.controller,
      isPortrait: isPortrait,
      presentationMode: JournalPresentationMode.page,
      onClose: () => Navigator.of(context).maybePop(),
    );
  }
}
