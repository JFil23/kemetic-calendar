import 'package:flutter/material.dart';
import 'package:mobile/features/calendar/maat_flow_visual_tokens.dart';

enum ReadingHouseEventBlockSize { featured, compact }

class ReadingHouseDetailFeaturedSection extends StatelessWidget {
  const ReadingHouseDetailFeaturedSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('reading-house-featured-section'),
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 24),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF1E2A24))),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _ReadingHouseContractLine(),
          SizedBox(height: 18),
          Divider(height: 1, color: Color(0xFF1E2A24)),
          SizedBox(height: 22),
          ReadingHouseEventBlockVisual(),
        ],
      ),
    );
  }
}

class _ReadingHouseContractLine extends StatelessWidget {
  const _ReadingHouseContractLine();

  @override
  Widget build(BuildContext context) {
    const labels = <String>['1 BOOK', '3 STARTER SITTINGS', 'DATES YOU SET'];
    return Wrap(
      spacing: 9,
      runSpacing: 5,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        for (var index = 0; index < labels.length; index++) ...<Widget>[
          Text(
            labels[index],
            style: _uiStyle(
              color: const Color(0xFFB9A15E),
              fontSize: 9,
              letterSpacing: 1.65,
            ),
          ),
          if (index != labels.length - 1)
            const SizedBox(
              width: 3,
              height: 3,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xFF7E6C3D),
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class ReadingHouseEventBlockVisual extends StatelessWidget {
  const ReadingHouseEventBlockVisual({
    super.key,
    this.size = ReadingHouseEventBlockSize.featured,
    this.sittingNumber = 1,
    this.title = 'Open the Text',
    this.prompt =
        'Before company shapes the reading, what is this opening asking you to hold privately?',
    this.memberInitials = const <String>['Y', 'M', 'A'],
    this.memberLabel = 'You and 2 other readers',
    this.timingLabel,
    this.onTap,
  });

  final ReadingHouseEventBlockSize size;
  final int sittingNumber;
  final String title;
  final String prompt;
  final List<String> memberInitials;
  final String memberLabel;
  final String? timingLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return switch (size) {
      ReadingHouseEventBlockSize.featured => _FeaturedBlock(data: this),
      ReadingHouseEventBlockSize.compact => _CompactBlock(data: this),
    };
  }
}

class _FeaturedBlock extends StatelessWidget {
  const _FeaturedBlock({required this.data});

  final ReadingHouseEventBlockVisual data;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      key: const ValueKey<String>('reading-house-event-block-featured'),
      constraints: const BoxConstraints(minHeight: 212),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFF315E50)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF07130F),
            Color(0xFF0B251D),
            Color(0xFF0A1713),
          ],
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x291A8B6C), blurRadius: 28),
        ],
      ),
      child: Stack(
        children: <Widget>[
          const Positioned(right: -24, top: -28, child: _MintGlow(size: 150)),
          Padding(
            padding: const EdgeInsets.fromLTRB(17, 20, 112, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${data.sittingNumber.toString().padLeft(2, '0')} · Opening section',
                  style: _uiStyle(
                    color: const Color(0xFF9C844A),
                    fontSize: 11,
                    letterSpacing: 1.25,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  data.title,
                  style: _displayStyle(
                    color: const Color(0xFFF2EEE7),
                    fontSize: 29,
                    fontWeight: FontWeight.w500,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  data.prompt,
                  style: _displayStyle(
                    color: const Color(0xFFD9D3C8),
                    fontSize: 17,
                    fontStyle: FontStyle.italic,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0xFF24473D)),
                const SizedBox(height: 10),
                Text(
                  'Opening section · share only if you choose',
                  style: _uiStyle(color: const Color(0xFF99A9A2), fontSize: 11),
                ),
              ],
            ),
          ),
          const Positioned(
            right: 18,
            top: 44,
            child: _ReadingScrollArtwork(width: 78, height: 88),
          ),
        ],
      ),
    );

    if (data.onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: data.onTap,
        child: content,
      ),
    );
  }
}

class _CompactBlock extends StatelessWidget {
  const _CompactBlock({required this.data});

  final ReadingHouseEventBlockVisual data;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      key: const ValueKey<String>('reading-house-event-block-compact'),
      constraints: const BoxConstraints(minHeight: 68),
      padding: const EdgeInsets.fromLTRB(13, 9, 76, 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0xFF315E50)),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: <Color>[Color(0xFF07110E), Color(0xFF17372D)],
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'THE READING HOUSE · SITTING ${data.sittingNumber.toString().padLeft(2, '0')}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _uiStyle(
                  color: const Color(0xFFC4B88E),
                  fontSize: 8,
                  letterSpacing: 1.15,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                data.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _displayStyle(
                  color: const Color(0xFFF2EEE7),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
              ),
              const SizedBox(height: 5),
              Row(
                children: <Widget>[
                  _ReaderStack(initials: data.memberInitials),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      data.timingLabel ?? data.memberLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _uiStyle(
                        color: const Color(0xFFB3C8C0),
                        fontSize: 9.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Positioned(
            right: -66,
            top: -5,
            child: _ReadingScrollArtwork(width: 56, height: 58),
          ),
        ],
      ),
    );
    if (data.onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: data.onTap,
        child: content,
      ),
    );
  }
}

class _ReaderStack extends StatelessWidget {
  const _ReaderStack({required this.initials});

  final List<String> initials;

  @override
  Widget build(BuildContext context) {
    final visible = initials.take(3).toList(growable: false);
    return SizedBox(
      width: visible.isEmpty ? 0 : 18 + (visible.length - 1) * 11,
      height: 18,
      child: Stack(
        children: <Widget>[
          for (var index = 0; index < visible.length; index++)
            Positioned(
              left: index * 11,
              child: Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: index == 0
                      ? const Color(0xFF78D8B9)
                      : const Color(0xFF3D8E75),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF092019)),
                ),
                child: Text(
                  visible[index],
                  style: _uiStyle(
                    color: const Color(0xFF07130F),
                    fontSize: 6.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MintGlow extends StatelessWidget {
  const _MintGlow({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: <Color>[Color(0x337FD9BC), Color(0x0017362E)],
        ),
      ),
    );
  }
}

class _ReadingScrollArtwork extends StatelessWidget {
  const _ReadingScrollArtwork({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(painter: _ReadingScrollPainter()),
    );
  }
}

class _ReadingScrollPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()
      ..shader = const RadialGradient(
        colors: <Color>[Color(0x88DCCB91), Color(0x00DCCB91)],
      ).createShader(Offset.zero & size);
    canvas.drawOval(Offset.zero & size, glow);

    final pageRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.22,
        size.height * 0.2,
        size.width * 0.58,
        size.height * 0.62,
      ),
      Radius.circular(size.width * 0.04),
    );
    final page = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[Color(0xFFF1E3B5), Color(0xFFC5A766)],
      ).createShader(pageRect.outerRect);
    canvas.drawRRect(pageRect, page);

    final roller = Paint()
      ..shader = const LinearGradient(
        colors: <Color>[
          Color(0xFF8B632D),
          Color(0xFFF1D58B),
          Color(0xFF754B21),
        ],
      ).createShader(Offset.zero & size);
    final top = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.15,
        size.height * 0.14,
        size.width * 0.7,
        size.height * 0.13,
      ),
      Radius.circular(size.height * 0.08),
    );
    canvas.drawRRect(top, roller);
    final bottom = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.19,
        size.height * 0.75,
        size.width * 0.62,
        size.height * 0.12,
      ),
      Radius.circular(size.height * 0.07),
    );
    canvas.drawRRect(bottom, roller);

    final ink = Paint()
      ..color = const Color(0xFF9D503C)
      ..strokeWidth = size.width * 0.018
      ..strokeCap = StrokeCap.round;
    for (var index = 0; index < 3; index++) {
      final y = size.height * (0.39 + index * 0.11);
      canvas.drawLine(
        Offset(size.width * 0.34, y),
        Offset(size.width * (index == 2 ? 0.61 : 0.7), y),
        ink,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ReadingScrollPainter oldDelegate) => false;
}

TextStyle _displayStyle({
  required Color color,
  required double fontSize,
  FontWeight fontWeight = FontWeight.w400,
  FontStyle? fontStyle,
  double? height,
}) {
  return TextStyle(
    color: color,
    fontFamily: MaatFlowListTokens.fontFamily,
    fontFamilyFallback: MaatFlowListTokens.fontFallback,
    fontSize: fontSize,
    fontWeight: fontWeight,
    fontStyle: fontStyle,
    height: height,
  );
}

TextStyle _uiStyle({
  required Color color,
  required double fontSize,
  FontWeight fontWeight = FontWeight.w400,
  double? letterSpacing,
}) {
  return TextStyle(
    color: color,
    fontFamily: 'GentiumPlus',
    fontSize: fontSize,
    fontWeight: fontWeight,
    letterSpacing: letterSpacing,
  );
}
