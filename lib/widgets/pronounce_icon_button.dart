import 'dart:async';
import '../features/calendar/pronunciation/pronunciation_service.dart';
import 'package:flutter/material.dart';
import '../core/touch_targets.dart';
import '../features/calendar/pronunciation/pronunciation_catalog.dart';

class PronounceIconButton extends StatefulWidget {
  const PronounceIconButton({
    super.key,
    required this.pronunciationKey,
    required this.color,
    this.size = 22,
    this.service,
  });
  final PronunciationService? service;
  final PronunciationKey pronunciationKey;
  final Color color;
  final double size;
  @override
  State<PronounceIconButton> createState() => _PronounceIconButtonState();
}

class _PronounceIconButtonState extends State<PronounceIconButton> {
  final Object _owner = Object();
  late final _speech = widget.service ?? PronunciationService.instance;
  void _stopOwned() {
    unawaited(_speech.stop(owner: _owner).catchError((Object _) {}));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ModalRoute.of(context)?.isCurrent == false) _stopOwned();
  }

  @override
  void dispose() {
    _stopOwned();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PronounceIconButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pronunciationKey != widget.pronunciationKey) _stopOwned();
  }

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<PronunciationKey?>(
        valueListenable: _speech.activeKey,
        builder: (context, active, _) => PronunciationControl(
          color: widget.color,
          size: widget.size,
          playing: active == widget.pronunciationKey,
          onPressed: () async {
            try {
              if (active == widget.pronunciationKey) {
                await _speech.stop(key: widget.pronunciationKey);
              } else {
                await _speech.play(widget.pronunciationKey, owner: _owner);
              }
            } catch (_) {
              if (context.mounted) {
                ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Pronunciation is unavailable on this device',
                    ),
                  ),
                );
              }
            }
          },
        ),
      );
}

/// Shared visual contract, also used to verify idle and playing states.
class PronunciationControl extends StatelessWidget {
  const PronunciationControl({
    super.key,
    required this.color,
    required this.size,
    required this.playing,
    required this.onPressed,
  });
  final Color color;
  final double size;
  final bool playing;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Semantics(
    label: Overlay.maybeOf(context) == null
        ? (playing ? 'Stop pronunciation' : 'Play pronunciation')
        : null,
    child: IconButton(
      tooltip: Overlay.maybeOf(context) == null
          ? null
          : (playing ? 'Stop pronunciation' : 'Play pronunciation'),
      padding: expandedIconButtonPadding(
        context,
        iconSize: size,
        fallback: EdgeInsets.zero,
      ),
      constraints: expandedIconButtonConstraints(
        context,
        fallback: const BoxConstraints(minWidth: 44, minHeight: 44),
      ),
      visualDensity: expandedVisualDensity(context),
      icon: Icon(
        playing ? Icons.stop_circle_outlined : Icons.volume_up_rounded,
        color: color,
        size: size,
      ),
      onPressed: onPressed,
    ),
  );
}

/// Keeps existing title typography and its separate navigation gesture intact.
class PronunciationLabel extends StatelessWidget {
  const PronunciationLabel({
    super.key,
    required this.child,
    required this.pronunciationKey,
    this.color = const Color(0xFFB99B59),
    this.size = 18,
  });
  final Widget child;
  final PronunciationKey? pronunciationKey;
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: child),
      if (pronunciationKey != null)
        PronounceIconButton(
          pronunciationKey: pronunciationKey!,
          color: color,
          size: size,
        ),
    ],
  );
}
