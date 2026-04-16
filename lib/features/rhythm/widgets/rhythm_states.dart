import 'package:flutter/material.dart';

import '../theme/rhythm_theme.dart';

class RhythmEmptyStateCard extends StatelessWidget {
  const RhythmEmptyStateCard({
    super.key,
    required this.title,
    required this.message,
    this.primaryAction,
    this.secondaryAction,
  });

  final String title;
  final String message;
  final Widget? primaryAction;
  final Widget? secondaryAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: RhythmTheme.cardSurface(),
      padding: RhythmTheme.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: RhythmTheme.heading),
          const SizedBox(height: 8),
          Text(message, style: RhythmTheme.subheading),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.start,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (primaryAction != null) primaryAction!,
              if (secondaryAction != null) secondaryAction!,
            ],
          ),
        ],
      ),
    );
  }
}

class RhythmErrorStateCard extends StatelessWidget {
  const RhythmErrorStateCard({
    super.key,
    required this.title,
    required this.message,
    this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: RhythmTheme.cardSurface(),
      padding: RhythmTheme.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.amberAccent),
              const SizedBox(width: 8),
              Text(title, style: RhythmTheme.heading),
            ],
          ),
          const SizedBox(height: 8),
          Text(message, style: RhythmTheme.subheading),
          if (onRetry != null)
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ),
        ],
      ),
    );
  }
}

class RhythmLoadingShell extends StatelessWidget {
  const RhythmLoadingShell({super.key, this.height = 120});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: RhythmTheme.cardSurface(),
      padding: RhythmTheme.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ShimmerBar(width: 120),
          const SizedBox(height: 16),
          _ShimmerBar(width: double.infinity),
          const SizedBox(height: 10),
          _ShimmerBar(width: MediaQuery.of(context).size.width * 0.6),
          const SizedBox(height: 10),
          _ShimmerBar(width: MediaQuery.of(context).size.width * 0.4),
        ],
      ),
    );
  }
}

class _ShimmerBar extends StatefulWidget {
  const _ShimmerBar({required this.width});

  final double width;

  @override
  State<_ShimmerBar> createState() => _ShimmerBarState();
}

class _ShimmerBarState extends State<_ShimmerBar> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: 12,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: LinearGradient(
              begin: Alignment(-1 + 2 * _controller.value, 0),
              end: Alignment(1 + 2 * _controller.value, 0),
              colors: [
                Colors.white.withValues(alpha: 0.04),
                Colors.white.withValues(alpha: 0.12),
                Colors.white.withValues(alpha: 0.04),
              ],
            ),
          ),
        );
      },
    );
  }
}
