import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui' as ui;

import '../../core/theme/app_fonts.dart';
import '../../widgets/keyboard_aware.dart';
import 'decan_reflection_skin.dart';
import 'decan_review_models.dart';

/// Presentation for the approved reflection experience and its post preview.
/// Journal and social surfaces retain their own established presentation owners.
abstract final class DecanReviewStyle {
  static const base = Color(0xFF0B0906);
  static const baseBottom = Color(0xFF0D0B07);
  static const ink = Color(0xFFF2ECE0);
  static const soft = Color(0xFFC8C4BC);
  static const muted = Color(0xFF9E9A94);
  static const quiet = Color(0xFF6A6660);
  static const gold = DecanReflectionTokens.gold;
  static const line = Color(0xFF2A2219);
  static const strongLine = Color(0xFF4A3D2A);
  static TextStyle serif(
    double size, {
    Color color = ink,
    double height = 1.4,
    bool italic = false,
  }) => TextStyle(
    fontFamily: DecanReflectionTokens.fontFamily,
    fontFamilyFallback: DecanReflectionTokens.fontFallback,
    fontSize: size,
    fontWeight: FontWeight.w400,
    height: height,
    fontStyle: italic ? FontStyle.italic : FontStyle.normal,
    color: color,
  );
  static TextStyle ui(
    double size, {
    Color color = muted,
    double spacing = 0,
    double height = 1.5,
  }) => TextStyle(
    fontFamily: AppFonts.ui,
    fontFamilyFallback: const ['GentiumPlus'],
    fontSize: size,
    height: height,
    color: color,
    letterSpacing: spacing,
  );
}

/// Editable children retain their element/focus while surrounding review copy
/// is tucked away for the keyboard, as in the canonical Day View composer.
abstract interface class DecanReviewEditable {}

class DecanReviewCanvas extends StatefulWidget {
  const DecanReviewCanvas({
    super.key,
    required this.children,
    this.privacy = 'Only you',
    this.scrollController,
  });
  final List<Widget> children;
  final String privacy;
  final ScrollController? scrollController;

  @override
  State<DecanReviewCanvas> createState() => _DecanReviewCanvasState();
}

class _DecanReviewCanvasState extends State<DecanReviewCanvas> {
  final _ownedScrollController = ScrollController();
  ScrollController get _scroll =>
      widget.scrollController ?? _ownedScrollController;
  bool _editing = false;
  double _reviewOffset = 0;

  void _retainReviewPosition(bool editing) {
    if (_editing == editing) return;
    if (editing && _scroll.hasClients) _reviewOffset = _scroll.offset;
    _editing = editing;
    if (!editing) {
      // Compact editing temporarily removes the surrounding copy's height.
      // Restore that review position when the keyboard closes; keyboard reveal
      // itself remains owned by the shared inset/editable surfaces.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _editing || !_scroll.hasClients) return;
        _scroll.jumpTo(
          _reviewOffset.clamp(0, _scroll.position.maxScrollExtent),
        );
      });
    }
  }

  @override
  void dispose() {
    _ownedScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => KeyboardInsetBoundary(
    child: KeyboardAwareEditableSurface(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final inset = constraints.maxWidth < 330 ? 22.0 : 30.0;
          final editing =
              keyboardIsVisible(context) &&
              widget.children.any((child) => child is DecanReviewEditable);
          _retainReviewPosition(editing);
          final tightEditing =
              editing && MediaQuery.sizeOf(context).height < 120;
          return DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [DecanReviewStyle.base, DecanReviewStyle.baseBottom],
              ),
            ),
            child: ClipRect(
              child: CustomPaint(
                painter: const _DecanCrownPainter(),
                child: SafeArea(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: SingleChildScrollView(
                        controller: _scroll,
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: EdgeInsets.fromLTRB(
                          inset,
                          tightEditing
                              ? 0
                              : editing
                              ? 4
                              : 24,
                          inset,
                          tightEditing
                              ? 0
                              : editing
                              ? 4
                              : 30,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Offstage(
                              offstage: editing,
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const SizedBox(height: 30),
                                  if (widget.privacy.isNotEmpty)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (widget.privacy == 'Only you') ...[
                                          const Icon(
                                            Icons.lock_outline,
                                            size: 11,
                                            color: DecanReviewStyle.muted,
                                          ),
                                          const SizedBox(width: 7),
                                        ],
                                        Text(
                                          widget.privacy,
                                          style: DecanReviewStyle.ui(
                                            11,
                                            spacing: .22,
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                            for (final child in widget.children)
                              Offstage(
                                offstage:
                                    editing && child is! DecanReviewEditable,
                                child: child,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}

class _DecanCrownPainter extends CustomPainter {
  const _DecanCrownPainter();
  @override
  void paint(Canvas canvas, Size size) {
    // The reference uses an ellipse 130% wide and 380px tall at y=-60.
    canvas.save();
    canvas.translate(size.width / 2, -60);
    canvas.scale(size.width * 1.3, 380);
    canvas.drawRect(
      Rect.fromLTRB(-1, 0, 1, (size.height + 60) / 380),
      Paint()
        ..shader = ui.Gradient.radial(
          Offset.zero,
          1,
          const [Color(0xFF3A2416), Color(0xFF1D130C), Color(0x001D130C)],
          const [0, .42, 1],
        ),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DecanCrownPainter oldDelegate) => false;
}

class DecanReviewIntro extends StatelessWidget {
  const DecanReviewIntro({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
    this.compact = false,
  });
  final String eyebrow;
  final String title;
  final String? subtitle;
  final bool compact;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: compact ? 22 : 46, bottom: compact ? 30 : 38),
    child: Column(
      children: [
        DecanReviewLabel(eyebrow),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: DecanReviewStyle.serif(
            MediaQuery.sizeOf(context).width < 370
                ? (compact ? 33 : 38)
                : (compact ? 38 : 46),
            height: 1.04,
          ).copyWith(letterSpacing: -.55),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 10),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: DecanReviewStyle.serif(
              19,
              italic: true,
              color: DecanReviewStyle.muted,
            ),
          ),
        ],
      ],
    ),
  );
}

class DecanReviewLabel extends StatelessWidget {
  const DecanReviewLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: DecanReviewStyle.ui(10.5, spacing: 2.1, height: 1.6),
  );
}

class DecanReviewSeal extends StatelessWidget {
  const DecanReviewSeal({super.key, this.days = const {}, this.size = 40});
  final Set<int> days;
  final double size;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _SealPainter(days)),
    ),
  );
}

class _SealPainter extends CustomPainter {
  const _SealPainter(this.days);
  final Set<int> days;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 40, size.height / 40);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..color = DecanReviewStyle.strongLine
      ..strokeWidth = 1;
    canvas.drawCircle(const Offset(20, 20), 19.5, line);
    for (var i = 0; i < 10; i++) {
      final on = days.contains(i + 1);
      canvas.save();
      canvas.translate(20, 20);
      canvas.rotate((i * 36 + 18) * math.pi / 180);
      line
        ..color = (on ? DecanReviewStyle.gold : DecanReviewStyle.quiet)
        ..strokeWidth = (on ? 1.25 : 1)
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(0, on ? -15 : -13.5),
        Offset(0, on ? -7 : -9.5),
        line,
      );
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SealPainter oldDelegate) =>
      !setEquals(days, oldDelegate.days);
}

class DecanReviewRule extends StatelessWidget {
  const DecanReviewRule({super.key, required this.days});
  final Set<int> days;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      height: 13,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: DecanReviewStyle.line)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(
            10,
            (i) => Container(
              width: 1,
              height: days.contains(i + 1) ? 13 : 6,
              color: days.contains(i + 1)
                  ? DecanReviewStyle.gold
                  : DecanReviewStyle.strongLine,
            ),
          ),
        ),
      ),
    ),
  );
}

class DecanMomentTile extends StatelessWidget {
  const DecanMomentTile({
    super.key,
    required this.moment,
    required this.decanStart,
    this.onOpen,
    this.showRule = false,
  });
  final DecanMoment moment;
  final DateTime decanStart;
  final VoidCallback? onOpen;
  final bool showRule;
  @override
  Widget build(BuildContext context) {
    final day = moment.dayIn(decanStart);
    final content = Container(
      decoration: BoxDecoration(
        border: showRule
            ? const Border(top: BorderSide(color: DecanReviewStyle.line))
            : null,
      ),
      padding: const EdgeInsets.only(top: 27, bottom: 28),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: MediaQuery.sizeOf(context).width < 370 ? 30 : 34,
            child: Column(
              children: [
                Text(
                  day?.toString().padLeft(2, '0') ?? '—',
                  style:
                      DecanReviewStyle.serif(
                        29,
                        color: DecanReviewStyle.soft,
                        height: 1,
                      ).copyWith(
                        fontFeatures: const [FontFeature.oldstyleFigures()],
                      ),
                ),
                if (day != null) ...[
                  const SizedBox(height: 7),
                  Text(
                    'DAY',
                    style: DecanReviewStyle.serif(
                      11,
                      color: DecanReviewStyle.muted,
                      height: 1,
                    ).copyWith(letterSpacing: 1.5),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: MediaQuery.sizeOf(context).width < 370 ? 13 : 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: 9),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: moment.sourceLabel,
                          style: DecanReviewStyle.ui(
                            11,
                            color: DecanReviewStyle.soft,
                            spacing: .22,
                          ),
                        ),
                        TextSpan(
                          text: ' · ${moment.actionLabel}',
                          style: DecanReviewStyle.ui(11, spacing: .22),
                        ),
                      ],
                    ),
                  ),
                ),
                _MomentWords(
                  moment.text,
                  hanging: moment.isQuote,
                  style: DecanReviewStyle.serif(
                    MediaQuery.sizeOf(context).width < 370
                        ? (moment.isQuote ? 24 : 23)
                        : (moment.isQuote ? 26 : 25),
                    italic: moment.isQuote,
                    height: 1.24,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (onOpen == null) return content;
    return Semantics(
      button: true,
      label: 'Open ${moment.sourceLabel}: ${moment.text}',
      child: InkWell(onTap: onOpen, child: content),
    );
  }
}

class DecanReviewButton extends StatelessWidget {
  const DecanReviewButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.primary = false,
    this.busy = false,
    this.quiet = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final bool busy;
  final bool quiet;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: primary ? 32 : 8),
    child: Semantics(
      button: true,
      enabled: onPressed != null && !busy,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(99),
        child: InkWell(
          onTap: busy ? null : onPressed,
          borderRadius: BorderRadius.circular(99),
          child: Container(
            constraints: BoxConstraints(minHeight: primary ? 54 : 46),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: primary
                ? BoxDecoration(
                    border: Border.all(color: const Color(0xA6D4AE43)),
                    borderRadius: BorderRadius.circular(99),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x14D4AE43), Color(0x08D4AE43)],
                    ),
                  )
                : null,
            child: busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: DecanReviewStyle.gold,
                    ),
                  )
                : Text(
                    label,
                    textAlign: TextAlign.center,
                    style:
                        DecanReviewStyle.ui(
                          primary ? 13.5 : 13,
                          color: onPressed == null
                              ? DecanReviewStyle.quiet
                              : quiet
                              ? DecanReviewStyle.muted
                              : primary
                              ? DecanReviewStyle.ink
                              : DecanReviewStyle.soft,
                          spacing: primary ? .4 : .26,
                          height: 1.4,
                        ).copyWith(
                          fontWeight: primary
                              ? FontWeight.w500
                              : FontWeight.w400,
                        ),
                  ),
          ),
        ),
      ),
    ),
  );
}

class DecanReviewQuestion extends StatelessWidget {
  const DecanReviewQuestion(this.question, {super.key});
  final String question;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      const SizedBox(height: 26),
      Container(width: 40, height: 1, color: const Color(0xBFD4AE43)),
      const SizedBox(height: 32),
      LayoutBuilder(
        builder: (context, constraints) {
          final style = DecanReviewStyle.serif(
            MediaQuery.sizeOf(context).width < 370 ? 29 : 34,
            height: 1.14,
          ).copyWith(letterSpacing: -.272);
          // Match CSS text-wrap:balance: use the narrowest centered measure that
          // retains the natural number of lines, including accessibility scaling.
          final painter = TextPainter(
            text: TextSpan(text: question, style: style),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          );
          painter.layout(maxWidth: constraints.maxWidth);
          final lines = painter.computeLineMetrics().length;
          var low = 0.0, high = constraints.maxWidth;
          for (var i = 0; i < 12; i++) {
            final mid = (low + high) / 2;
            painter.layout(maxWidth: mid);
            if (painter.computeLineMetrics().length > lines) {
              low = mid;
            } else {
              high = mid;
            }
          }
          painter.dispose();
          return Align(
            child: SizedBox(
              width: math.min(constraints.maxWidth, high + 1),
              child: Text(question, textAlign: TextAlign.center, style: style),
            ),
          );
        },
      ),
    ],
  );
}

class DecanReviewFooter extends StatelessWidget {
  const DecanReviewFooter(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 38),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: DecanReviewStyle.serif(
        15,
        italic: true,
        color: DecanReviewStyle.muted,
        height: 1.5,
      ),
    ),
  );
}

class DecanReviewWords extends StatelessWidget {
  const DecanReviewWords(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 18, bottom: 22),
    padding: const EdgeInsets.only(left: 20),
    decoration: const BoxDecoration(
      border: Border(left: BorderSide(color: Color(0x80D4AE43))),
    ),
    child: Text(
      text,
      style: DecanReviewStyle.serif(30, italic: true, height: 1.26),
    ),
  );
}

class DecanReviewNotice extends StatelessWidget {
  const DecanReviewNotice(this.message, {super.key});
  final String message;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      margin: const EdgeInsets.only(top: 22),
      padding: const EdgeInsets.fromLTRB(14, 3, 0, 3),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: Color(0x80D4AE43))),
      ),
      child: Text(
        message,
        style: DecanReviewStyle.ui(
          12.5,
          color: DecanReviewStyle.soft,
          height: 1.6,
        ),
      ),
    ),
  );
}

class DecanPublicReflectionCard extends StatelessWidget {
  const DecanPublicReflectionCard({
    super.key,
    required this.author,
    this.handle,
    required this.body,
    this.question,
    this.readingTitle,
    this.onReading,
    this.onAuthor,
  });
  final String author;
  final String? handle;
  final String body;
  final String? question;
  final String? readingTitle;
  final VoidCallback? onReading, onAuthor;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 28, bottom: 4),
    padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
    decoration: BoxDecoration(
      color: const Color(0xFF120E0A),
      border: Border.all(color: DecanReviewStyle.line),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onAuthor,
          child: Text(
            author,
            style: DecanReviewStyle.ui(
              13,
              color: DecanReviewStyle.ink,
            ).copyWith(fontWeight: FontWeight.w500),
          ),
        ),
        Text(
          '${handle == null || handle!.isEmpty ? '' : '@${handle!.replaceFirst('@', '')} · '}Decan reflection',
          style: DecanReviewStyle.ui(11, spacing: .22),
        ),
        const SizedBox(height: 22),
        const DecanReviewLabel('From these ten days'),
        if (question != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              question!,
              style: DecanReviewStyle.serif(
                19,
                italic: true,
                color: DecanReviewStyle.muted,
                height: 1.35,
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(body, style: DecanReviewStyle.serif(27, height: 1.28)),
        ),
        if (readingTitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: DecanReviewStyle.line)),
              ),
              child: TextButton(
                onPressed: onReading,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.only(top: 15),
                  alignment: Alignment.centerLeft,
                ),
                child: Text(
                  'Reading · $readingTitle ↗',
                  style: DecanReviewStyle.ui(
                    12.5,
                    color: DecanReviewStyle.soft,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class DecanContinuationTile extends StatelessWidget {
  const DecanContinuationTile({
    super.key,
    required this.suggestion,
    required this.onOpen,
    required this.onDismiss,
  });
  final DecanContinuation suggestion;
  final VoidCallback onOpen;
  final VoidCallback onDismiss;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 26),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecanReviewLabel(
          suggestion.isReading ? 'From the Library' : 'A flow to explore',
        ),
        const SizedBox(height: 10),
        Text(
          suggestion.reason,
          style: DecanReviewStyle.serif(19, color: DecanReviewStyle.soft),
        ),
        DecanReviewButton(
          '${suggestion.title} ↗',
          onPressed: onOpen,
          primary: true,
        ),
        DecanReviewButton('Not for now', onPressed: onDismiss, quiet: true),
      ],
    ),
  );
}

/// Hang only an authored opening quote; the following lines keep their measure.
class _MomentWords extends StatelessWidget {
  const _MomentWords(this.text, {required this.style, required this.hanging});
  final String text;
  final TextStyle style;
  final bool hanging;
  @override
  Widget build(BuildContext context) {
    if (!hanging || !text.startsWith('“')) return Text(text, style: style);
    return Semantics(
      label: text,
      excludeSemantics: true,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Text(text.substring(1), style: style),
          Positioned(
            left:
                -.42 * MediaQuery.textScalerOf(context).scale(style.fontSize!),
            top: 0,
            child: Text('“', style: style),
          ),
        ],
      ),
    );
  }
}
