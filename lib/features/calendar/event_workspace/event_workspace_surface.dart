import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../services/restoration_coordinator.dart';
import '../../../utils/external_link_utils.dart';
import 'event_workspace_models.dart';
import 'youtube_workspace_renderer.dart';

const Color _workspaceCanvas = Color(0xFF060504);
const Color _workspaceInk = Color(0xFFF3E6D0);

const Key eventWorkspaceSurfaceKey = ValueKey<String>(
  'event-workspace-surface',
);
const Key eventWorkspaceMinimizeKey = ValueKey<String>(
  'event-workspace-minimize',
);
const Key eventWorkspacePlayerFrameKey = ValueKey<String>(
  'event-workspace-player-frame',
);
const Key eventWorkspaceBodyKey = ValueKey<String>('event-workspace-body');
const Key eventWorkspaceRemainingKey = ValueKey<String>(
  'event-workspace-remaining',
);
const Key eventWorkspaceExpiredKey = ValueKey<String>(
  'event-workspace-expired',
);
const Key eventWorkspaceCloseKey = ValueKey<String>('event-workspace-close');
const Key eventWorkspaceExtend5Key = ValueKey<String>(
  'event-workspace-extend-5',
);
const Key eventWorkspaceExtend10Key = ValueKey<String>(
  'event-workspace-extend-10',
);
const Key eventWorkspaceExtend15Key = ValueKey<String>(
  'event-workspace-extend-15',
);

class EventWorkspaceSurface extends StatefulWidget {
  const EventWorkspaceSurface({
    super.key,
    required this.title,
    required this.sourceUrl,
    required this.onMinimize,
    required this.onClose,
    this.purpose,
    this.canonicalEnd,
    this.onRequestExtend,
  });

  final String title;
  final String sourceUrl;
  final String? purpose;
  final DateTime? canonicalEnd;
  final VoidCallback onMinimize;
  final VoidCallback onClose;
  final Future<bool> Function(Duration extension)? onRequestExtend;

  @override
  State<EventWorkspaceSurface> createState() => _EventWorkspaceSurfaceState();
}

class _EventWorkspaceSurfaceState extends State<EventWorkspaceSurface> {
  Timer? _ticker;
  final ValueNotifier<DateTime> _now = ValueNotifier<DateTime>(DateTime.now());
  bool _extending = false;
  String? _extendError;

  @override
  void initState() {
    super.initState();
    RestorationCoordinator.instance.resumeListenable.addListener(
      _recomputeFromWallClock,
    );
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant EventWorkspaceSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.canonicalEnd != widget.canonicalEnd) {
      _syncTicker();
      _recomputeFromWallClock();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    RestorationCoordinator.instance.resumeListenable.removeListener(
      _recomputeFromWallClock,
    );
    _now.dispose();
    super.dispose();
  }

  void _syncTicker() {
    _ticker?.cancel();
    _ticker = null;
    if (widget.canonicalEnd == null) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _recomputeFromWallClock();
    });
  }

  void _recomputeFromWallClock() {
    if (!mounted) return;
    _now.value = DateTime.now();
  }

  Future<void> _extend(Duration extension) async {
    final request = widget.onRequestExtend;
    if (request == null || _extending) return;
    setState(() {
      _extending = true;
      _extendError = null;
    });
    final ok = await request(extension);
    if (!mounted) return;
    setState(() {
      _extending = false;
      if (!ok) {
        _extendError = "This event can't be extended.";
      }
    });
  }

  Future<void> _openExternally(String target) async {
    final handled = await launchExternalTarget(target);
    if (!handled && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this link.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: eventWorkspaceSurfaceKey,
      color: _workspaceCanvas,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _WorkspaceHeader(
                title: widget.title,
                onMinimize: widget.onMinimize,
              ),
              AspectRatio(
                key: eventWorkspacePlayerFrameKey,
                aspectRatio: eventWorkspacePlayerAspectRatio,
                child: YouTubeWorkspaceRenderer(
                  sourceUrl: widget.sourceUrl,
                  onOpenExternally: _openExternally,
                ),
              ),
              Expanded(
                child: _EventWorkspaceSessionBody(
                  nowListenable: _now,
                  canonicalEnd: widget.canonicalEnd,
                  purpose: widget.purpose,
                ),
              ),
            ],
          ),
          ValueListenableBuilder<DateTime>(
            valueListenable: _now,
            builder: (context, now, _) {
              final end = widget.canonicalEnd;
              if (end == null ||
                  !eventWorkspaceHasEnded(canonicalEnd: end, now: now)) {
                return const SizedBox.shrink();
              }
              return _buildExpiredPrompt();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildExpiredPrompt() {
    return Material(
      key: eventWorkspaceExpiredKey,
      color: const Color(0xE60A0806),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'This event has ended.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _workspaceInk,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 28),
              if (widget.onRequestExtend != null) ...[
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final extension in eventWorkspaceExtensionChoices)
                      _ExtendChip(
                        key: switch (extension.inMinutes) {
                          5 => eventWorkspaceExtend5Key,
                          10 => eventWorkspaceExtend10Key,
                          15 => eventWorkspaceExtend15Key,
                          _ => ValueKey(
                            'event-workspace-extend-${extension.inMinutes}',
                          ),
                        },
                        label: '+${extension.inMinutes} min',
                        onPressed: _extending ? null : () => _extend(extension),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              SizedBox(
                width: 180,
                child: OutlinedButton(
                  key: eventWorkspaceCloseKey,
                  onPressed: widget.onClose,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _workspaceInk,
                    side: const BorderSide(color: Color(0x66F3E6D0)),
                  ),
                  child: const Text('Close'),
                ),
              ),
              if (_extendError != null) ...[
                const SizedBox(height: 16),
                Text(
                  _extendError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFE8C4A0)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EventWorkspaceSessionBody extends StatelessWidget {
  const _EventWorkspaceSessionBody({
    required this.nowListenable,
    required this.canonicalEnd,
    required this.purpose,
  });

  final ValueListenable<DateTime> nowListenable;
  final DateTime? canonicalEnd;
  final String? purpose;

  @override
  Widget build(BuildContext context) {
    final purposeText = purpose?.trim();
    return Material(
      key: eventWorkspaceBodyKey,
      color: _workspaceCanvas,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (canonicalEnd != null)
              ValueListenableBuilder<DateTime>(
                valueListenable: nowListenable,
                builder: (context, now, _) {
                  final remaining = eventWorkspaceRemaining(
                    canonicalEnd: canonicalEnd!,
                    now: now,
                  )!;
                  return Text(
                    formatEventWorkspaceRemaining(remaining),
                    key: eventWorkspaceRemainingKey,
                    style: const TextStyle(
                      color: _workspaceInk,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  );
                },
              ),
            if (canonicalEnd != null &&
                purposeText != null &&
                purposeText.isNotEmpty)
              const SizedBox(height: 10),
            if (purposeText != null && purposeText.isNotEmpty)
              Text(
                purposeText,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xCCF3E6D0),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceHeader extends StatelessWidget {
  const _WorkspaceHeader({required this.title, required this.onMinimize});

  final String title;
  final VoidCallback onMinimize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 8),
      child: Row(
        children: [
          IconButton(
            key: eventWorkspaceMinimizeKey,
            tooltip: 'Back to event',
            onPressed: onMinimize,
            icon: const Icon(Icons.expand_more, color: _workspaceInk),
          ),
          Expanded(
            child: Text(
              title.trim().isEmpty ? 'Event' : title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _workspaceInk,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExtendChip extends StatelessWidget {
  const _ExtendChip({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(onPressed: onPressed, child: Text(label));
  }
}
