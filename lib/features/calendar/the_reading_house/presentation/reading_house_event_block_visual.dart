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
      constraints: const BoxConstraints(minHeight: 164),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x6B7FD9BC)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x8C000000),
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
          BoxShadow(color: Color(0x127FD9BC), blurRadius: 16),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: <Widget>[
          const Positioned.fill(child: _ReadingHouseCardSurface()),
          Padding(
            padding: const EdgeInsets.fromLTRB(17, 17, 104, 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${data.sittingNumber.toString().padLeft(2, '0')} · Opening section',
                  style: _uiStyle(
                    color: const Color(0xFF8A7030),
                    fontSize: 11,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  data.title,
                  style: _displayStyle(
                    color: const Color(0xFFFBF7EF),
                    fontSize: 30,
                    fontWeight: FontWeight.w600,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  data.prompt,
                  style: _displayStyle(
                    color: const Color(0xFFD8D2C8),
                    fontSize: 17,
                    fontStyle: FontStyle.italic,
                    height: 1.32,
                  ),
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0x267FD9BC)),
                const SizedBox(height: 10),
                Text.rich(
                  TextSpan(
                    children: <InlineSpan>[
                      TextSpan(
                        text: 'Opening section',
                        style: _uiStyle(
                          color: const Color(0xFFA5BBB1),
                          fontSize: 11.5,
                        ),
                      ),
                      TextSpan(
                        text: ' · share only if you choose',
                        style: _uiStyle(
                          color: const Color(0xFF96B3A6),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Positioned(
            right: 17,
            top: 19,
            child: _ReadingScrollArtwork(width: 73, height: 94),
          ),
        ],
      ),
    );

    if (data.onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
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
      height: 61,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x6B7FD9BC)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x8C000000),
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
          BoxShadow(color: Color(0x127FD9BC), blurRadius: 16),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: <Widget>[
          const Positioned.fill(child: _ReadingHouseCardSurface()),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 7, 70, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'THE READING HOUSE · SITTING ${data.sittingNumber.toString().padLeft(2, '0')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _uiStyle(
                    color: const Color(0xFF9FE0C6),
                    fontSize: 7.5,
                    letterSpacing: 1.25,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  data.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _displayStyle(
                    color: const Color(0xFFFBF7EF),
                    fontSize: 17.5,
                    fontWeight: FontWeight.w600,
                    height: 0.96,
                  ),
                ),
                const Spacer(),
                Row(
                  children: <Widget>[
                    _ReaderStack(initials: data.memberInitials, compact: true),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        data.timingLabel ?? data.memberLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _uiStyle(
                          color: const Color(0xFF96B3A6),
                          fontSize: 8.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Positioned(
            right: 8,
            top: 0,
            bottom: 0,
            width: 55,
            child: Center(child: _ReadingScrollArtwork(width: 55, height: 49)),
          ),
        ],
      ),
    );
    if (data.onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: data.onTap,
        child: content,
      ),
    );
  }
}

class _ReaderStack extends StatelessWidget {
  const _ReaderStack({required this.initials, this.compact = false});

  final List<String> initials;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final visible = initials.take(3).toList(growable: false);
    final size = compact ? 13.0 : 18.0;
    final overlap = compact ? 8.0 : 11.0;
    return SizedBox(
      width: visible.isEmpty ? 0 : size + (visible.length - 1) * overlap,
      height: size,
      child: Stack(
        children: <Widget>[
          for (var index = 0; index < visible.length; index++)
            Positioned(
              left: index * overlap,
              child: Container(
                width: size,
                height: size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: index == 0
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: <Color>[Color(0xFFA8E6D1), Color(0xFF3FA98A)],
                        )
                      : null,
                  color: index == 0 ? null : const Color(0xFF3D8E75),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF0E241B),
                    width: compact ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  visible[index],
                  style: _uiStyle(
                    color: const Color(0xFF0A1B14),
                    fontSize: compact ? 7 : 6.5,
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

class _ReadingHouseCardSurface extends StatelessWidget {
  const _ReadingHouseCardSurface();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment(-0.72, -1),
          end: Alignment(0.72, 1),
          colors: <Color>[
            Color(0xFF0C2119),
            Color(0xFF1E4436),
            Color(0xFF0A1911),
          ],
          stops: <double>[0, 0.54, 1],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.68, -0.04),
                radius: 0.78,
                colors: <Color>[Color(0x33F0D296), Color(0x00F0D296)],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  Color(0xCC030806),
                  Color(0x75030806),
                  Color(0x05030806),
                ],
                stops: <double>[0, 0.46, 1],
              ),
            ),
          ),
        ],
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
    canvas.save();
    canvas.scale(size.width / 76, size.height / 68);

    canvas.drawOval(
      const Rect.fromLTWH(8, 54, 60, 12),
      Paint()..color = const Color(0x8C000000),
    );

    final sheet = Path()
      ..moveTo(19, 24)
      ..lineTo(57, 24)
      ..lineTo(69, 60)
      ..lineTo(7, 60)
      ..close();
    canvas.drawPath(
      sheet,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFFF1E3B5), Color(0xFFC5A766)],
        ).createShader(const Rect.fromLTWH(7, 24, 62, 36)),
    );

    canvas.save();
    canvas.clipPath(sheet);
    final grain = Paint()
      ..color = const Color(0x16FFF6E0)
      ..strokeWidth = 1.1;
    for (final y in <double>[30, 37, 44, 51]) {
      canvas.drawLine(Offset(10, y), Offset(68, y), grain);
    }
    canvas.drawLine(
      const Offset(25, 32.5),
      const Offset(52, 32.5),
      Paint()
        ..color = const Color(0xEBA8442A)
        ..strokeWidth = 1.9
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      const Offset(23.6, 40),
      const Offset(55, 40),
      Paint()
        ..color = const Color(0xD12E2418)
        ..strokeWidth = 1.7
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      const Offset(22.6, 46.5),
      const Offset(48, 46.5),
      Paint()
        ..color = const Color(0xB32E2418)
        ..strokeWidth = 1.7
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      const Offset(21.4, 53),
      const Offset(53, 53),
      Paint()
        ..color = const Color(0x852E2418)
        ..strokeWidth = 1.7
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();

    canvas.drawPath(
      sheet,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0x57FFF1D4)
        ..strokeWidth = 0.9,
    );

    final roller = RRect.fromLTRBR(15, 14, 61, 25, const Radius.circular(5.5));
    canvas.drawRRect(
      roller,
      Paint()
        ..shader = const LinearGradient(
          colors: <Color>[
            Color(0xFF8B632D),
            Color(0xFFF1D58B),
            Color(0xFF754B21),
          ],
        ).createShader(const Rect.fromLTWH(15, 14, 46, 11)),
    );
    canvas.drawLine(
      const Offset(15, 15.4),
      const Offset(61, 15.4),
      Paint()
        ..color = const Color(0x80FFF3D8)
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(15, 19.5), width: 6.4, height: 11),
      Paint()..color = const Color(0xFFC6AF87),
    );

    canvas.drawOval(
      Rect.fromCenter(center: const Offset(38, 34), width: 76, height: 68),
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.28, -0.52),
          radius: 0.64,
          colors: <Color>[
            Color(0x99FFE9BC),
            Color(0x2BF0D296),
            Color(0x00F0D296),
          ],
          stops: <double>[0, 0.54, 1],
        ).createShader(const Rect.fromLTWH(0, 0, 76, 68)),
    );
    canvas.restore();
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
