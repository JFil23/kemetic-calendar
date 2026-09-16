import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'offering_table_day_contract.dart';
import 'offering_table_day_state.dart';

class OfferingTableDayInstrument extends StatelessWidget {
  const OfferingTableDayInstrument({
    super.key,
    required this.contract,
    required this.state,
    required this.now,
    this.courseStates = const <int, OfferingTableDayViewState>{},
  });

  final OfferingTableDayContract contract;
  final OfferingTableDayViewState state;
  final DateTime now;
  final Map<int, OfferingTableDayViewState> courseStates;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      key: ValueKey<String>(
        'offering-table-day-${contract.day.toString().padLeft(2, '0')}-instrument',
      ),
      painter: OfferingTableDayInstrumentPainter(
        contract: contract,
        state: state,
        now: now,
        courseStates: courseStates,
      ),
      size: Size.infinite,
    );
  }
}

class OfferingTableDayInstrumentPainter extends CustomPainter {
  const OfferingTableDayInstrumentPainter({
    required this.contract,
    required this.state,
    required this.now,
    required this.courseStates,
  });

  static const _gold = Color(0xFFC99A3D);
  static const _goldGlow = Color(0xFFF0C96A);
  static const _water = Color(0xFF83BEB9);
  static const _intent = Color(0xFFE8B27C);
  static const _teal = Color(0xFFBFE4DF);
  static const _muted = Color(0xFF8E8375);

  final OfferingTableDayContract contract;
  final OfferingTableDayViewState state;
  final DateTime now;
  final Map<int, OfferingTableDayViewState> courseStates;

  bool done(String id) {
    final move = contract.moves.firstWhere((move) => move.id == id);
    return state.moveDone(move, now: now);
  }

  String word(String id) => state.words[id]?.trim() ?? '';
  String pick(String id) => state.picks[id]?.trim() ?? '';

  @override
  void paint(Canvas canvas, Size size) {
    final design = contract.isWideInstrument
        ? const Size(346, 196)
        : const Size(142, 204);
    final scale = math.min(
      size.width / design.width,
      size.height / design.height,
    );
    final offset = Offset(
      (size.width - design.width * scale) / 2,
      (size.height - design.height * scale) / 2,
    );
    canvas
      ..save()
      ..translate(offset.dx, offset.dy)
      ..scale(scale);
    _paintAuthoredHalo(canvas);
    switch (contract.day) {
      case 1:
        _day1(canvas);
      case 2:
        _day2(canvas);
      case 3:
        _day3(canvas);
      case 4:
        _day4(canvas);
      case 5:
        _day5(canvas);
      case 6:
        _day6(canvas);
      case 7:
        _day7(canvas);
      case 8:
        _day8(canvas);
      case 9:
        _day9(canvas);
      case 10:
        _day10(canvas);
      case 11:
        _day11(canvas);
      case 12:
        _day12(canvas);
      case 13:
        _day13(canvas);
      case 14:
        _day14(canvas);
      case 15:
        _day15(canvas);
      case 16:
        _day16(canvas);
      case 17:
        _day17(canvas);
      case 18:
        _day18(canvas);
      case 19:
        _day19(canvas);
      case 20:
        _day20(canvas);
      case 21:
        _day21(canvas);
      case 22:
        _day22(canvas);
      case 23:
        _day23(canvas);
      case 24:
        _day24(canvas);
      case 25:
        _day25(canvas);
      case 26:
        _day26(canvas);
      case 27:
        _day27(canvas);
      case 28:
        _day28(canvas);
      case 29:
        _day29(canvas);
      case 30:
        _day30(canvas);
    }
    canvas.restore();
  }

  Paint _stroke({
    Color color = _gold,
    double width = 1.55,
    double opacity = 1,
  }) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = color.withValues(alpha: opacity);

  Paint _fill(Color color, {double opacity = 1}) => Paint()
    ..style = PaintingStyle.fill
    ..color = color.withValues(alpha: opacity);

  void _paintAuthoredHalo(Canvas canvas) {
    final complete = state.dayComplete(contract, now: now);
    final spec = switch (contract.day) {
      1 => (const Offset(71, 110), 65.0, 62.0, complete),
      2 => (const Offset(71, 91), 65.0, 68.0, complete),
      3 => (const Offset(71, 120), 66.0, 46.0, complete),
      4 => (const Offset(71, 112), 65.0, 52.0, complete),
      5 => (const Offset(71, 115), 66.0, 46.0, complete),
      6 => (const Offset(71, 112), 66.0, 54.0, complete),
      7 => (const Offset(71, 116), 66.0, 52.0, complete),
      8 => (const Offset(71, 122), 66.0, 44.0, complete),
      9 => (const Offset(71, 107), 66.0, 56.0, complete),
      10 => (const Offset(286, 98), 48.0, 45.0, complete),
      11 => (const Offset(71, 119), 67.0, 48.0, complete),
      12 => (const Offset(71, 117), 66.0, 52.0, complete),
      13 => (const Offset(71, 112), 66.0, 58.0, complete),
      14 => (const Offset(71, 120), 65.0, 50.0, complete),
      15 => (const Offset(173, 105), 120.0, 62.0, complete),
      16 => (const Offset(71, 116), 66.0, 50.0, complete),
      17 => (const Offset(71, 116), 66.0, 52.0, complete),
      18 => (const Offset(71, 116), 66.0, 48.0, complete),
      19 => (const Offset(71, 119), 66.0, 48.0, complete),
      20 => (const Offset(294, 98), 45.0, 43.0, complete),
      21 => (const Offset(71, 116), 65.0, 50.0, complete),
      22 => (const Offset(71, 114), 66.0, 50.0, complete),
      23 => (const Offset(71, 114), 66.0, 54.0, complete),
      24 => (const Offset(71, 112), 66.0, 55.0, complete),
      25 => (const Offset(173, 107), 123.0, 60.0, complete),
      26 => (const Offset(173, 78), 120.0, 70.0, done('use')),
      27 => (const Offset(71, 115), 66.0, 54.0, complete),
      28 => (const Offset(71, 119), 66.0, 48.0, complete),
      29 => (const Offset(71, 119), 64.0, 46.0, complete),
      30 => (const Offset(300, 104), 44.0, 44.0, done('breath')),
      _ => (Offset.zero, 0.0, 0.0, false),
    };
    if (!spec.$4) return;
    final rect = Rect.fromCenter(
      center: spec.$1,
      width: spec.$2 * 2,
      height: spec.$3 * 2,
    );
    canvas.drawOval(
      rect,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            _goldGlow.withValues(alpha: .34),
            _goldGlow.withValues(alpha: .12),
            Colors.transparent,
          ],
          stops: const <double>[0, .55, 1],
        ).createShader(rect),
    );
  }

  Paint _waterGradient(Rect rect, {double opacity = .78}) => Paint()
    ..style = PaintingStyle.fill
    ..shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[
        const Color(0xFFCBEAE6).withValues(alpha: opacity),
        const Color(0xFF8BC5BF).withValues(alpha: opacity),
        const Color(0xFF5A928D).withValues(alpha: opacity),
      ],
      stops: const <double>[0, .45, 1],
    ).createShader(rect);

  void _dashedPath(
    Canvas canvas,
    Path path,
    Paint paint, {
    double dash = 5,
    double gap = 5,
  }) {
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = math.min(distance + dash, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + gap;
      }
    }
  }

  void _line(
    Canvas canvas,
    List<Offset> points, {
    bool bright = false,
    double opacity = 1,
    bool dashed = false,
  }) {
    if (points.length < 2) return;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    final paint = _stroke(
      color: bright ? _goldGlow : _gold,
      width: bright ? 1.8 : (dashed ? 1.35 : 1.55),
      opacity: opacity,
    );
    if (dashed) {
      _dashedPath(canvas, path, paint);
    } else {
      canvas.drawPath(path, paint);
    }
  }

  void _oval(
    Canvas canvas,
    Rect rect, {
    bool bright = false,
    double opacity = 1,
    bool dashed = false,
  }) {
    final path = Path()..addOval(rect);
    final paint = _stroke(
      color: bright ? _goldGlow : _gold,
      width: bright ? 1.8 : (dashed ? 1.35 : 1.55),
      opacity: opacity,
    );
    if (dashed) {
      _dashedPath(canvas, path, paint);
    } else {
      canvas.drawPath(path, paint);
    }
  }

  void _rect(
    Canvas canvas,
    Rect rect, {
    double radius = 0,
    bool bright = false,
    double opacity = 1,
    bool dashed = false,
  }) {
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    final paint = _stroke(
      color: bright ? _goldGlow : _gold,
      width: bright ? 1.8 : (dashed ? 1.35 : 1.55),
      opacity: opacity,
    );
    if (dashed) {
      _dashedPath(canvas, path, paint);
    } else {
      canvas.drawPath(path, paint);
    }
  }

  void _text(
    Canvas canvas,
    String text,
    Offset center, {
    double width = 90,
    double fontSize = 8,
    Color color = _muted,
    TextAlign align = TextAlign.center,
    FontStyle style = FontStyle.italic,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontFamily: 'CormorantGaramond',
          fontSize: fontSize,
          fontStyle: style,
          height: 1,
        ),
      ),
      textAlign: align,
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: width);
    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
    );
  }

  void _wordSlot(
    Canvas canvas,
    String id,
    Rect rect,
    String placeholder, {
    bool carried = false,
    double fontSize = 9,
  }) {
    _line(canvas, <Offset>[
      Offset(rect.left, rect.top + 15),
      Offset(rect.right, rect.top + 15),
    ], opacity: .34);
    final value = word(id);
    _text(
      canvas,
      value.isEmpty ? placeholder : value,
      rect.center,
      width: rect.width,
      fontSize: fontSize,
      color: value.isEmpty
          ? _intent.withValues(alpha: .38)
          : carried
          ? _teal
          : _intent,
    );
  }

  void _timer(
    Canvas canvas,
    Offset center,
    double radius,
    String id,
    int target,
  ) {
    final timer = state.timers[id] ?? const OfferingTableTimerState();
    final elapsed = timer.elapsedAt(now).clamp(0, target * 1000);
    final progress = target == 0 ? 0.0 : elapsed / (target * 1000);
    canvas.drawCircle(
      center,
      radius,
      _stroke(color: const Color(0xFF342815), width: 4),
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      _stroke(color: _goldGlow, width: 4),
    );
  }

  String _timerText(String id, int target) {
    final ms = (state.timers[id] ?? const OfferingTableTimerState())
        .elapsedAt(now)
        .clamp(0, target * 1000);
    final seconds = (ms / 1000).floor();
    final shown = target - seconds;
    return '${shown ~/ 60}:${(shown % 60).toString().padLeft(2, '0')}';
  }

  void _day1(Canvas c) {
    final jar = Path()
      ..moveTo(42, 43)
      ..lineTo(100, 43)
      ..lineTo(108, 60)
      ..lineTo(108, 157)
      ..quadraticBezierTo(71, 172, 34, 157)
      ..lineTo(34, 60)
      ..close();
    c.drawPath(jar, _stroke());
    _line(c, const <Offset>[
      Offset(42, 43),
      Offset(48, 31),
      Offset(94, 31),
      Offset(100, 43),
    ]);
    if (done('refill')) {
      c.save();
      c.clipPath(jar);
      c.drawRect(
        const Rect.fromLTWH(34, 110, 74, 55),
        _waterGradient(const Rect.fromLTWH(34, 110, 74, 55)),
      );
      c.restore();
      _line(c, const <Offset>[Offset(35, 111), Offset(107, 111)], opacity: .9);
    }
    _wordSlot(
      c,
      'supply',
      const Rect.fromLTWH(45, 79, 52, 18),
      'supply…',
      carried: done('refill'),
    );
    if (done('visible')) {
      _line(c, const <Offset>[
        Offset(112, 72),
        Offset(131, 72),
        Offset(131, 136),
        Offset(112, 136),
        Offset(112, 72),
        Offset(117, 80),
        Offset(126, 80),
      ], bright: true);
    }
  }

  void _day2(Canvas c) {
    final bowl = Path()
      ..moveTo(31, 61)
      ..cubicTo(33, 111, 48, 132, 71, 132)
      ..cubicTo(94, 132, 109, 111, 111, 61);
    c.drawPath(bowl, _stroke());
    _oval(c, const Rect.fromLTWH(31, 53, 80, 16));
    if (!done('drink')) {
      c.drawOval(
        const Rect.fromLTWH(34, 59, 74, 12),
        _waterGradient(const Rect.fromLTWH(34, 59, 74, 12)),
      );
    }
    _timer(c, const Offset(71, 61), 49, 'quiet', 60);
    _wordSlot(
      c,
      'input',
      const Rect.fromLTWH(29, 94, 84, 18),
      'first input…',
      carried: done('quiet'),
    );
  }

  void _day3(Canvas c) {
    final placed = done('place');
    final y = placed ? 126.0 : 88.0;
    _line(c, const <Offset>[
      Offset(18, 145),
      Offset(124, 145),
      Offset(114, 166),
      Offset(28, 166),
      Offset(18, 145),
    ]);
    _oval(
      c,
      Rect.fromCenter(center: Offset(71, y), width: 68, height: 24),
      bright: placed,
      opacity: placed ? 1 : .29,
    );
    final loaf = Path()
      ..moveTo(49, y)
      ..quadraticBezierTo(71, y - 13, 93, y);
    c.drawPath(
      loaf,
      _stroke(
        color: placed ? _goldGlow : _gold,
        width: placed ? 1.8 : 1.45,
        opacity: placed ? 1 : .29,
      ),
    );
    if (word('food').isNotEmpty) {
      _text(c, word('food'), Offset(71, y + 3), width: 55, fontSize: 7);
    }
    if (placed) {
      _line(c, const <Offset>[
        Offset(43, 137),
        Offset(99, 137),
        Offset(91, 133),
        Offset(99, 137),
        Offset(91, 141),
      ], bright: true);
    }
  }

  void _day4(Canvas c) {
    _oval(c, const Rect.fromLTWH(20, 104, 102, 44));
    final water = Path()
      ..moveTo(25, 123)
      ..quadraticBezierTo(71, 137, 117, 123);
    c.drawPath(
      water,
      _stroke(color: _water, width: 1.7, opacity: done('wash') ? .8 : .24),
    );
    _wordSlot(
      c,
      'care',
      const Rect.fromLTWH(31, 91, 80, 18),
      'body-care…',
      carried: done('do'),
    );
    if (done('do')) {
      final smile = Path()
        ..moveTo(49, 151)
        ..quadraticBezierTo(71, 163, 93, 151);
      c.drawPath(smile, _stroke(color: _goldGlow, width: 1.8));
    }
  }

  void _day5(Canvas c) {
    final hours = int.tryParse(word('hours'))?.clamp(0, 10) ?? 0;
    final hasShortener = word('shortener').isNotEmpty;
    final reduced = done('reduce');
    for (var i = 0; i < 10; i++) {
      final shortDot = i == math.max(0, hours - 1) && hasShortener && !reduced;
      c.drawCircle(
        Offset(18 + i * 12, 72),
        i < hours ? 3 : 2,
        _fill(
          i < hours && !shortDot ? _goldGlow : const Color(0xFF3A2C16),
          opacity: i < hours && !shortDot ? .98 : .5,
        ),
      );
    }
    _line(c, const <Offset>[
      Offset(47, 145),
      Offset(47, 106),
      Offset(71, 89),
      Offset(95, 106),
      Offset(95, 145),
      Offset(58, 145),
      Offset(58, 121),
      Offset(84, 121),
      Offset(84, 145),
    ]);
    _wordSlot(
      c,
      'hours',
      const Rect.fromLTWH(28, 91, 39, 18),
      'hours…',
      carried: done('reduce'),
      fontSize: 8.3,
    );
    _wordSlot(
      c,
      'shortener',
      const Rect.fromLTWH(77, 91, 47, 18),
      'shortener…',
      carried: done('reduce'),
      fontSize: 7.8,
    );
    if (hasShortener) {
      final warning = Path()
        ..moveTo(29, 90)
        ..quadraticBezierTo(42, 81, 50, 86);
      c.drawPath(
        warning,
        _stroke(
          color: reduced ? _goldGlow : _gold,
          width: reduced ? 1.8 : 1.45,
          opacity: reduced ? 1 : .29,
        ),
      );
    }
  }

  void _day6(Canvas c) {
    _rect(c, const Rect.fromLTWH(24, 50, 94, 108), radius: 5);
    _line(c, const <Offset>[Offset(24, 76), Offset(118, 76)]);
    _line(c, const <Offset>[
      Offset(45, 42),
      Offset(45, 60),
      Offset(97, 60),
      Offset(97, 42),
    ]);
    for (final x in <double>[44, 71, 98]) {
      _oval(
        c,
        Rect.fromCircle(center: Offset(x, 96), radius: 8),
        bright: x == 44 && done('book'),
        opacity: x == 44 && done('book') ? 1 : .29,
      );
    }
    _wordSlot(
      c,
      'appointment',
      const Rect.fromLTWH(36, 117, 70, 18),
      'appointment…',
      carried: done('book'),
      fontSize: 8.5,
    );
    if (done('find')) {
      _line(c, const <Offset>[Offset(38, 171), Offset(104, 171)], bright: true);
      final left = Path()
        ..moveTo(43, 166)
        ..quadraticBezierTo(50, 158, 57, 166);
      final right = Path()
        ..moveTo(85, 166)
        ..quadraticBezierTo(92, 158, 99, 166);
      c
        ..drawPath(left, _stroke(color: _goldGlow, width: 1.8))
        ..drawPath(right, _stroke(color: _goldGlow, width: 1.8));
      _text(
        c,
        'number / booking page found',
        const Offset(71, 188),
        width: 112,
        fontSize: 7,
      );
    }
    if (done('book')) {
      _line(c, const <Offset>[
        Offset(38, 96),
        Offset(43, 101),
        Offset(53, 88),
      ], bright: true);
      _text(
        c,
        'ON THE CALENDAR',
        const Offset(71, 36),
        width: 100,
        fontSize: 7.6,
      );
    }
  }

  void _day7(Canvas c) {
    final chosen = pick('dignity');
    _line(c, const <Offset>[Offset(24, 145), Offset(118, 145)]);
    _rect(c, const Rect.fromLTWH(34, 72, 42, 58));
    final cloth = Path()
      ..moveTo(84, 77)
      ..quadraticBezierTo(118, 88, 108, 123)
      ..quadraticBezierTo(92, 129, 82, 117)
      ..close();
    if (chosen.isNotEmpty) {
      c.drawPath(cloth, _stroke(color: _goldGlow, width: 1.8));
    } else {
      _dashedPath(c, cloth, _stroke(width: 1.35, opacity: .38));
    }
    if (chosen.isNotEmpty) {
      _text(c, chosen, const Offset(71, 166), width: 120, fontSize: 7.6);
    }
  }

  void _day8(Canvas c) {
    final portion = done('portion');
    final scheduled = done('schedule');
    final bowl = Path()
      ..moveTo(19, 116)
      ..quadraticBezierTo(27, 153, 71, 153)
      ..quadraticBezierTo(115, 153, 123, 116);
    c.drawPath(bowl, _stroke());
    _oval(c, const Rect.fromLTWH(19, 104, 104, 24));
    if (portion) {
      final fill = Path()
        ..moveTo(71, 116)
        ..lineTo(111, 123)
        ..quadraticBezierTo(100, 144, 72, 149)
        ..close();
      c.drawPath(fill, _fill(_goldGlow, opacity: .18));
      c.drawPath(fill, _stroke(color: _goldGlow, width: 1.2));
    }
    if (scheduled) {
      _line(c, const <Offset>[
        Offset(27, 164),
        Offset(115, 164),
        Offset(35, 158),
        Offset(35, 170),
        Offset(107, 170),
        Offset(107, 158),
      ], bright: true);
    }
    _wordSlot(
      c,
      'hunger',
      const Rect.fromLTWH(32, 103, 78, 18),
      'quiet hunger…',
      carried: portion || scheduled,
      fontSize: 9.3,
    );
    if (portion || scheduled) {
      _text(
        c,
        portion ? 'Portion now' : 'Opening scheduled',
        const Offset(71, 184),
        width: 110,
        fontSize: 7.6,
      );
    }
  }

  void _day9(Canvas c) {
    _oval(c, const Rect.fromLTWH(24, 51, 94, 94));
    _oval(
      c,
      const Rect.fromLTWH(43, 70, 56, 56),
      bright: done('drink'),
      opacity: done('drink') ? 1 : .29,
    );
    c.drawCircle(
      const Offset(71, 98),
      7,
      _fill(
        done('drink') ? _goldGlow : _gold,
        opacity: done('drink') ? 1 : .075,
      ),
    );
    if (done('drink')) {
      _line(c, const <Offset>[
        Offset(63, 98),
        Offset(69, 104),
        Offset(81, 89),
      ], bright: true);
    }
    _text(
      c,
      pick('repair').isEmpty ? 'choose repair' : pick('repair'),
      const Offset(71, 160),
      width: 120,
      fontSize: 7.6,
    );
    _text(
      c,
      done('drink')
          ? 'water · ${state.timestamps['drink'] ?? ''}'
          : _timeLabel(now),
      const Offset(71, 176),
      width: 120,
      fontSize: 7,
    );
  }

  void _day10(Canvas c) {
    _rect(c, const Rect.fromLTWH(30, 35, 238, 111), radius: 3);
    _text(
      c,
      'FED',
      const Offset(62, 54),
      width: 50,
      fontSize: 7.6,
      align: TextAlign.left,
    );
    _text(c, 'STILL ASKING', const Offset(198, 54), width: 80, fontSize: 7.6);
    _line(c, const <Offset>[Offset(145, 45), Offset(145, 130)], opacity: .29);
    _wordSlot(
      c,
      'fed',
      const Rect.fromLTWH(45, 78, 82, 18),
      'fed…',
      carried: done('prepare'),
      fontSize: 9.5,
    );
    _wordSlot(
      c,
      'asking',
      const Rect.fromLTWH(160, 78, 84, 18),
      'still asking…',
      fontSize: 9.5,
    );
    if (done('prepare')) {
      _line(c, const <Offset>[Offset(44, 124), Offset(126, 124)], bright: true);
    }
    _oval(
      c,
      const Rect.fromLTWH(277, 69, 42, 42),
      bright: done('prepare'),
      opacity: done('prepare') ? 1 : .29,
    );
  }

  void _day11(Canvas c) {
    _oval(c, const Rect.fromLTWH(20, 95, 102, 56));
    if (done('provide')) {
      c.drawOval(
        const Rect.fromLTWH(27, 113, 88, 34),
        _fill(_goldGlow, opacity: .16),
      );
    }
    _wordSlot(
      c,
      'dependent',
      const Rect.fromLTWH(39, 102, 64, 18),
      'who…',
      carried: done('provide'),
      fontSize: 8.8,
    );
    _wordSlot(
      c,
      'need',
      const Rect.fromLTWH(39, 128, 64, 18),
      'need…',
      carried: done('provide'),
      fontSize: 8.5,
    );
  }

  void _day12(Canvas c) {
    for (final x in <double>[43, 99]) {
      final bowl = Path()
        ..moveTo(x - 23, 105)
        ..quadraticBezierTo(x - 19, 144, x, 144)
        ..quadraticBezierTo(x + 19, 144, x + 23, 105);
      c.drawPath(bowl, _stroke());
      _oval(c, Rect.fromLTWH(x - 23, 99, 46, 12));
    }
    if (done('care')) {
      final bridge = Path()
        ..moveTo(59, 98)
        ..cubicTo(68, 84, 78, 84, 87, 98);
      c.drawPath(bridge, _stroke(color: _water, width: 1.7));
      _line(c, const <Offset>[
        Offset(67, 91),
        Offset(74, 86),
        Offset(73, 95),
      ], bright: true);
    }
    _wordSlot(
      c,
      'dependent',
      const Rect.fromLTWH(25, 91, 36, 18),
      'who…',
      carried: done('care'),
      fontSize: 7.6,
    );
    _wordSlot(
      c,
      'need',
      const Rect.fromLTWH(81, 91, 36, 18),
      'need…',
      carried: done('care'),
      fontSize: 7.6,
    );
  }

  void _day13(Canvas c) {
    final adjusted = done('adjust');
    _oval(c, const Rect.fromLTWH(21, 55, 100, 100));
    final position = pick('position');
    var endpoints = const <Offset>[
      Offset(71, 55),
      Offset(114, 130),
      Offset(28, 130),
    ];
    if (!adjusted && position == 'I carry more') {
      endpoints = const <Offset>[
        Offset(71, 55),
        Offset(119, 118),
        Offset(31, 142),
      ];
    }
    if (!adjusted && position == 'Someone else carries more') {
      endpoints = const <Offset>[
        Offset(71, 55),
        Offset(107, 145),
        Offset(23, 116),
      ];
    }
    for (final end in endpoints) {
      _line(c, <Offset>[const Offset(71, 105), end], bright: adjusted);
    }
    if (position.isNotEmpty) {
      _text(
        c,
        '${adjusted ? 'share made even · ' : ''}$position',
        const Offset(71, 165),
        width: 130,
        fontSize: 7.2,
      );
    }
    _wordSlot(
      c,
      'resource',
      const Rect.fromLTWH(39, 91, 64, 18),
      'resource…',
      carried: adjusted,
      fontSize: 8.8,
    );
  }

  void _day14(Canvas c) {
    final bowl = Path()
      ..moveTo(22, 111)
      ..quadraticBezierTo(29, 154, 71, 154)
      ..quadraticBezierTo(113, 154, 120, 111);
    c.drawPath(bowl, _stroke());
    _oval(c, const Rect.fromLTWH(22, 101, 98, 20));
    final timer =
        state.timers['refillTimer'] ?? const OfferingTableTimerState();
    final progress = (timer.elapsedAt(now) / 180000).clamp(0.0, 1.0);
    if (progress > 0) {
      final y = 149 - 34 * progress;
      final water = Path()
        ..moveTo(27, y)
        ..quadraticBezierTo(71, y + 9, 115, y)
        ..lineTo(112, 150)
        ..quadraticBezierTo(71, 163, 30, 150)
        ..close();
      c.drawPath(
        water,
        _waterGradient(Rect.fromLTWH(27, y, 88, 150 - y), opacity: .7),
      );
    }
    _wordSlot(
      c,
      'refill',
      const Rect.fromLTWH(37, 98, 68, 18),
      'what is low…',
      carried: done('refillTimer'),
      fontSize: 8.8,
    );
    _timer(c, const Offset(71, 69), 25, 'refillTimer', 180);
    _text(
      c,
      _timerText('refillTimer', 180),
      const Offset(71, 69),
      width: 45,
      fontSize: 7.6,
    );
  }

  void _day15(Canvas c) {
    _line(c, const <Offset>[Offset(35, 132), Offset(311, 132)]);
    _timer(c, const Offset(173, 94), 50, 'attentionTimer', 60);
    _wordSlot(
      c,
      'attention',
      const Rect.fromLTWH(114, 89, 118, 18),
      'full attention…',
      carried: done('attentionTimer'),
      fontSize: 10.2,
    );
    _rect(
      c,
      const Rect.fromLTWH(264, 72, 34, 54),
      radius: 5,
      bright: done('phone'),
      opacity: done('phone') ? 1 : .29,
    );
    _line(
      c,
      const <Offset>[Offset(269, 119), Offset(293, 119)],
      bright: done('phone'),
      opacity: done('phone') ? 1 : .29,
    );
  }

  void _day16(Canvas c) {
    final covered = done('cover');
    c.save();
    if (!covered) {
      c
        ..translate(71, 76)
        ..rotate(-6 * math.pi / 180)
        ..translate(-71, -76);
    }
    _line(c, const <Offset>[Offset(22, 76), Offset(120, 76)], bright: covered);
    _line(c, const <Offset>[Offset(71, 58), Offset(71, 82)]);
    c.restore();
    final leftY = covered
        ? 124.0
        : word('cost').isNotEmpty
        ? 139.0
        : 124.0;
    _line(c, <Offset>[Offset(34, leftY - 23), Offset(34, leftY)]);
    _line(c, const <Offset>[Offset(108, 101), Offset(108, 124)]);
    _line(c, <Offset>[
      Offset(20, leftY),
      Offset(48, leftY),
      Offset(43, leftY + 24),
      Offset(25, leftY + 24),
      Offset(20, leftY),
    ]);
    _line(c, const <Offset>[
      Offset(94, 124),
      Offset(122, 124),
      Offset(117, 148),
      Offset(99, 148),
      Offset(94, 124),
    ]);
    _wordSlot(
      c,
      'cost',
      Rect.fromLTWH(21, leftY + 2, 26, 18),
      'cost…',
      carried: covered,
      fontSize: 7.2,
    );
    if (covered) {
      final left = Path()
        ..moveTo(13, 91)
        ..quadraticBezierTo(23, 80, 33, 91)
        ..moveTo(13, 91)
        ..lineTo(13, 101);
      final right = Path()
        ..moveTo(109, 91)
        ..quadraticBezierTo(119, 80, 129, 91)
        ..moveTo(129, 91)
        ..lineTo(129, 101);
      c
        ..drawPath(left, _stroke(color: _goldGlow, width: 1.8))
        ..drawPath(right, _stroke(color: _goldGlow, width: 1.8));
    }
  }

  void _day17(Canvas c) {
    final stem = pick('stem');
    final sent = done('send');
    _rect(c, const Rect.fromLTWH(19, 69, 104, 82));
    if (stem.isEmpty) {
      _line(c, const <Offset>[
        Offset(19, 69),
        Offset(71, 111),
        Offset(123, 69),
      ]);
    } else {
      _line(c, const <Offset>[
        Offset(19, 69),
        Offset(71, 38),
        Offset(123, 69),
      ], bright: true);
      c.drawRect(
        const Rect.fromLTWH(30, 73, 82, 62),
        _fill(_gold, opacity: .075),
      );
      _text(c, stem, const Offset(71, 91), width: 80, fontSize: 7);
    }
    _line(
      c,
      const <Offset>[Offset(19, 151), Offset(58, 113)],
      bright: sent,
      opacity: sent ? 1 : .29,
    );
    _line(
      c,
      const <Offset>[Offset(123, 151), Offset(84, 113)],
      bright: sent,
      opacity: sent ? 1 : .29,
    );
    _wordSlot(
      c,
      'message',
      const Rect.fromLTWH(36, 122, 70, 18),
      'finish it…',
      carried: sent,
      fontSize: 8.5,
    );
    if (sent) {
      c.drawCircle(const Offset(71, 111), 8, _fill(_goldGlow, opacity: .12));
      _line(c, const <Offset>[
        Offset(67, 111),
        Offset(70, 114),
        Offset(76, 106),
      ], bright: true);
    }
  }

  void _day18(Canvas c) {
    _line(c, const <Offset>[Offset(20, 84), Offset(71, 52), Offset(122, 84)]);
    final leftDoor = Path()
      ..moveTo(27, 151)
      ..lineTo(27, 112)
      ..quadraticBezierTo(38, 99, 49, 112)
      ..lineTo(49, 151);
    final rightDoor = Path()
      ..moveTo(93, 151)
      ..lineTo(93, 112)
      ..quadraticBezierTo(104, 99, 115, 112)
      ..lineTo(115, 151);
    c
      ..drawPath(leftDoor, _stroke())
      ..drawPath(rightDoor, _stroke());
    if (done('adjust')) {
      _line(c, const <Offset>[Offset(31, 122), Offset(45, 122)], opacity: .29);
      _line(c, const <Offset>[Offset(97, 122), Offset(111, 122)], opacity: .29);
    }
    if (done('adjust')) {
      _line(c, const <Offset>[Offset(18, 165), Offset(124, 165)], bright: true);
    } else {
      final wave = Path()
        ..moveTo(18, 165)
        ..quadraticBezierTo(31, 151, 44, 165)
        ..quadraticBezierTo(57, 179, 70, 165)
        ..quadraticBezierTo(83, 151, 96, 165)
        ..quadraticBezierTo(109, 179, 124, 165);
      c.drawPath(wave, _stroke(color: _water, width: 1.7, opacity: .7));
    }
    _wordSlot(
      c,
      'impact',
      const Rect.fromLTWH(38, 133, 66, 18),
      'impact…',
      carried: done('adjust'),
      fontSize: 8.2,
    );
  }

  void _day19(Canvas c) {
    final left = Path()
      ..moveTo(18, 133)
      ..quadraticBezierTo(42, 101, 67, 126);
    final right = Path()
      ..moveTo(124, 133)
      ..quadraticBezierTo(100, 101, 75, 126);
    c.drawPath(left, _stroke());
    c.drawPath(right, _stroke());
    _oval(
      c,
      const Rect.fromLTWH(29, 92, 26, 26),
      bright: done('credit'),
      opacity: done('credit') ? 1 : .29,
    );
    _oval(
      c,
      const Rect.fromLTWH(87, 92, 26, 26),
      bright: done('lighten'),
      opacity: done('lighten') ? 1 : .29,
    );
    _wordSlot(
      c,
      'labor',
      const Rect.fromLTWH(38, 143, 66, 18),
      'unseen labor…',
      carried: done('lighten'),
      fontSize: 8.7,
    );
  }

  void _day20(Canvas c) {
    _rect(c, const Rect.fromLTWH(24, 36, 264, 116), radius: 3);
    _text(c, 'IMPROVED', const Offset(66, 55), width: 70, fontSize: 7.6);
    _text(c, 'STILL LEAKS', const Offset(166, 55), width: 75, fontSize: 7.6);
    _text(c, 'PATCH', const Offset(244, 55), width: 55, fontSize: 7.6);
    _wordSlot(
      c,
      'improved',
      const Rect.fromLTWH(38, 74, 70, 18),
      'improved…',
      carried: done('calendar'),
      fontSize: 8.3,
    );
    _wordSlot(
      c,
      'leak',
      const Rect.fromLTWH(129, 74, 70, 18),
      'leak…',
      fontSize: 8.3,
    );
    _wordSlot(
      c,
      'patch',
      const Rect.fromLTWH(218, 74, 55, 18),
      'patch…',
      carried: done('calendar'),
      fontSize: 8.3,
    );
    _rect(
      c,
      const Rect.fromLTWH(216, 102, 59, 33),
      radius: 3,
      bright: done('calendar'),
      opacity: done('calendar') ? 1 : .38,
      dashed: !done('calendar'),
    );
    if (done('calendar')) {
      _line(c, const <Offset>[
        Offset(224, 111),
        Offset(266, 111),
        Offset(224, 119),
        Offset(260, 119),
        Offset(224, 127),
        Offset(250, 127),
      ], bright: true);
    }
  }

  void _day21(Canvas c) {
    final open = done('clear');
    _line(c, const <Offset>[
      Offset(22, 157),
      Offset(22, 70),
      Offset(120, 70),
      Offset(120, 157),
    ]);
    if (open) {
      c.save();
      c.translate(24, -18);
      c.rotate(15 * math.pi / 180);
      _rect(c, const Rect.fromLTWH(54, 95, 34, 62), bright: true);
      c.restore();
    } else {
      _rect(c, const Rect.fromLTWH(54, 95, 34, 62));
    }
    _wordSlot(
      c,
      'source',
      const Rect.fromLTWH(38, 76, 66, 18),
      'source…',
      carried: open,
      fontSize: 8.8,
    );
    final wave = Path()
      ..moveTo(16, 176)
      ..quadraticBezierTo(48, open ? 154 : 170, 71, 176)
      ..quadraticBezierTo(97, open ? 154 : 170, 128, 176);
    c.drawPath(
      wave,
      _stroke(color: _water, width: 1.7, opacity: open ? .8 : .25),
    );
  }

  void _day22(Canvas c) {
    _rect(c, const Rect.fromLTWH(10, 98, 31, 31), radius: 3);
    final eye = Path()
      ..moveTo(53, 118)
      ..quadraticBezierTo(70, 96, 87, 118)
      ..quadraticBezierTo(70, 136, 53, 118);
    c.drawPath(eye, _stroke());
    final bowl = Path()
      ..moveTo(101, 102)
      ..quadraticBezierTo(105, 129, 119, 129)
      ..quadraticBezierTo(133, 129, 137, 102);
    c.drawPath(bowl, _stroke());
    _oval(c, const Rect.fromLTWH(101, 97, 36, 10));
    _line(c, const <Offset>[
      Offset(41, 113),
      Offset(53, 113),
      Offset(87, 113),
      Offset(101, 113),
    ], opacity: .29);
    _line(c, const <Offset>[
      Offset(47, 109),
      Offset(53, 113),
      Offset(47, 117),
    ], opacity: .29);
    _line(c, const <Offset>[
      Offset(95, 109),
      Offset(101, 113),
      Offset(95, 117),
    ], opacity: .29);
    if (word('thing').isNotEmpty) {
      _text(c, word('thing'), const Offset(25.5, 118), width: 29, fontSize: 7);
    }
    if (word('source').isNotEmpty) {
      _text(c, word('source'), const Offset(70, 121), width: 32, fontSize: 7);
    }
    if (done('offer')) {
      final flow = Path()
        ..moveTo(121, 78)
        ..cubicTo(103, 63, 83, 65, 69, 80)
        ..cubicTo(55, 94, 39, 92, 22, 81);
      c.drawPath(flow, _stroke(color: _goldGlow, width: 1.8));
      _line(c, const <Offset>[
        Offset(30, 74),
        Offset(20, 81),
        Offset(31, 85),
      ], bright: true);
    }
  }

  void _day23(Canvas c) {
    final top = Path()
      ..moveTo(17, 79)
      ..quadraticBezierTo(46, 94, 71, 79)
      ..quadraticBezierTo(96, 64, 125, 79);
    final bottom = Path()
      ..moveTo(17, 161)
      ..quadraticBezierTo(46, 176, 71, 161)
      ..quadraticBezierTo(96, 146, 125, 161);
    c.drawPath(top, _stroke(color: _water, width: 1.7, opacity: .55));
    c.drawPath(bottom, _stroke(color: _water, width: 1.7, opacity: .55));
    _rect(c, const Rect.fromLTWH(43, 72, 56, 85));
    _line(
      c,
      <Offset>[
        const Offset(64, 72),
        Offset(64, done('moved') ? 112 : 132),
        Offset(78, done('moved') ? 112 : 132),
        const Offset(78, 72),
      ],
      bright: done('moved'),
      opacity: done('moved') ? 1 : .29,
    );
    if (done('moved')) {
      final water = Path()
        ..moveTo(64, 119)
        ..quadraticBezierTo(71, 113, 78, 119);
      c.drawPath(water, _stroke(color: _water, width: 1.7));
    }
    _wordSlot(
      c,
      'delayed',
      const Rect.fromLTWH(49, 97, 44, 18),
      'delayed…',
      carried: done('moved'),
      fontSize: 7.8,
    );
    if (done('truth')) {
      _rect(c, const Rect.fromLTWH(90, 120, 34, 27), radius: 2, bright: true);
      _line(c, const <Offset>[
        Offset(90, 120),
        Offset(102, 130),
        Offset(124, 130),
      ], bright: true);
      _text(c, 'not today', const Offset(107, 156), width: 48, fontSize: 7);
    }
  }

  void _day24(Canvas c) {
    _line(c, const <Offset>[
      Offset(29, 73),
      Offset(113, 73),
      Offset(120, 94),
      Offset(120, 159),
      Offset(22, 159),
      Offset(22, 94),
      Offset(29, 73),
      Offset(43, 52),
      Offset(99, 52),
      Offset(113, 73),
    ]);
    for (var i = 0; i < 12; i++) {
      c.drawCircle(
        Offset(39 + (i % 4) * 21, 103 + (i ~/ 4) * 17),
        3,
        _fill(_gold, opacity: .28),
      );
    }
    _rect(
      c,
      const Rect.fromLTWH(54, 139, 34, 20),
      bright: done('release'),
      opacity: done('release') ? 1 : .29,
    );
    if (done('release')) {
      for (var i = 0; i < 5; i++) {
        c.drawCircle(
          Offset(58 + i * 7, 157 + i * 5),
          2.4,
          _fill(_goldGlow, opacity: .9 - i * .12),
        );
      }
    }
    _wordSlot(
      c,
      'surplus',
      const Rect.fromLTWH(39, 74, 64, 18),
      'surplus…',
      carried: done('release'),
      fontSize: 8.5,
    );
  }

  void _day25(Canvas c) {
    final flow = Path()
      ..moveTo(24, 112)
      ..cubicTo(72, 55, 111, 159, 161, 105)
      ..cubicTo(210, 52, 248, 157, 322, 96);
    c.drawPath(
      flow,
      _stroke(
        color: done('flow') ? _water : _gold,
        width: done('flow') ? 3 : 1.5,
        opacity: done('flow') ? 1 : .29,
      ),
    );
    _wordSlot(
      c,
      'received',
      const Rect.fromLTWH(46, 60, 112, 18),
      'where it reached you…',
      carried: done('flow'),
      fontSize: 9.5,
    );
    _wordSlot(
      c,
      'onward',
      const Rect.fromLTWH(195, 130, 112, 18),
      'where it can flow…',
      carried: done('flow'),
      fontSize: 9.5,
    );
    if (done('flow')) {
      c.drawCircle(const Offset(172, 105), 4, _fill(_goldGlow));
      _line(c, const <Offset>[
        Offset(294, 81),
        Offset(321, 96),
        Offset(296, 107),
      ], bright: true);
    }
  }

  void _day26(Canvas c) {
    _line(c, const <Offset>[
      Offset(22, 143),
      Offset(324, 143),
      Offset(311, 169),
      Offset(35, 169),
      Offset(22, 143),
    ]);
    _line(c, const <Offset>[
      Offset(42, 169),
      Offset(42, 184),
      Offset(304, 184),
      Offset(304, 169),
    ], opacity: .29);
    const sourceDays = <int>[1, 6, 8, 13, 16, 21, 24];
    const xs = <double>[46, 88, 130, 173, 216, 258, 300];
    var selected = 0;
    for (var i = 0; i < sourceDays.length; i++) {
      final source = courseStates[sourceDays[i]];
      final active = source != null && !source.isEmpty;
      if (active) selected = i;
      _artifact(
        c,
        i,
        Offset(xs[i], 116),
        bright: false,
        opacity: active ? 1 : .36,
        dashed: !active || (done('use') && i == selected),
      );
    }
    _wordSlot(
      c,
      'support',
      const Rect.fromLTWH(118, 28, 110, 18),
      'support already available…',
      carried: done('use'),
      fontSize: 8.5,
    );
    if (done('use')) {
      _artifact(c, selected, const Offset(173, 60), bright: true);
      final lift = Path()
        ..moveTo(xs[selected], 96)
        ..cubicTo(xs[selected], 78, 136, 84, 161, 70);
      c.drawPath(lift, _stroke(color: _goldGlow, width: 1.8));
      _line(c, const <Offset>[
        Offset(156, 64),
        Offset(164, 69),
        Offset(159, 77),
      ], bright: true);
      final tray = Path()
        ..moveTo(150, 84)
        ..quadraticBezierTo(173, 96, 196, 84);
      c.drawPath(tray, _stroke(color: _goldGlow, width: 1.8));
    }
  }

  void _artifact(
    Canvas c,
    int type,
    Offset p, {
    required bool bright,
    double opacity = 1,
    bool dashed = false,
  }) {
    final paint = _stroke(
      color: bright ? _goldGlow : _gold,
      width: bright ? 1.8 : (dashed ? 1.35 : 1.55),
      opacity: opacity,
    );
    void draw(Path path) {
      if (dashed) {
        _dashedPath(c, path, paint);
      } else {
        c.drawPath(path, paint);
      }
    }

    switch (type) {
      case 0:
        final jar = Path()
          ..moveTo(p.dx - 9, p.dy - 12)
          ..lineTo(p.dx + 9, p.dy - 12)
          ..lineTo(p.dx + 13, p.dy - 5)
          ..lineTo(p.dx + 13, p.dy + 15)
          ..quadraticBezierTo(p.dx, p.dy + 21, p.dx - 13, p.dy + 15)
          ..lineTo(p.dx - 13, p.dy - 5)
          ..close();
        draw(jar);
      case 1:
        draw(
          Path()..addRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: p, width: 26, height: 25),
              const Radius.circular(2),
            ),
          ),
        );
        draw(
          Path()
            ..moveTo(p.dx - 13, p.dy - 3)
            ..lineTo(p.dx + 13, p.dy - 3)
            ..moveTo(p.dx - 7, p.dy - 15)
            ..lineTo(p.dx - 7, p.dy - 7)
            ..moveTo(p.dx + 7, p.dy - 15)
            ..lineTo(p.dx + 7, p.dy - 7),
        );
      case 2:
        final bowl = Path()
          ..moveTo(p.dx - 12, p.dy - 2)
          ..quadraticBezierTo(p.dx - 9, p.dy + 16, p.dx, p.dy + 16)
          ..quadraticBezierTo(p.dx + 9, p.dy + 16, p.dx + 12, p.dy - 2);
        draw(bowl);
        draw(
          Path()..addOval(
            Rect.fromCenter(
              center: Offset(p.dx, p.dy - 2),
              width: 24,
              height: 8,
            ),
          ),
        );
      case 3:
        draw(Path()..addOval(Rect.fromCircle(center: p, radius: 13)));
        draw(
          Path()
            ..moveTo(p.dx, p.dy)
            ..lineTo(p.dx, p.dy - 13)
            ..moveTo(p.dx, p.dy)
            ..lineTo(p.dx - 11, p.dy + 7)
            ..moveTo(p.dx, p.dy)
            ..lineTo(p.dx + 11, p.dy + 7),
        );
      case 4:
        draw(
          Path()
            ..moveTo(p.dx - 14, p.dy - 8)
            ..lineTo(p.dx + 14, p.dy - 8)
            ..moveTo(p.dx, p.dy - 16)
            ..lineTo(p.dx, p.dy + 8)
            ..moveTo(p.dx - 11, p.dy - 7)
            ..lineTo(p.dx - 14, p.dy + 9)
            ..lineTo(p.dx - 6, p.dy + 9)
            ..close()
            ..moveTo(p.dx + 11, p.dy - 7)
            ..lineTo(p.dx + 8, p.dy + 9)
            ..lineTo(p.dx + 16, p.dy + 9)
            ..close(),
        );
      case 5:
        draw(
          Path()
            ..moveTo(p.dx - 12, p.dy + 13)
            ..lineTo(p.dx - 12, p.dy - 10)
            ..lineTo(p.dx + 12, p.dy - 10)
            ..lineTo(p.dx + 12, p.dy + 13)
            ..moveTo(p.dx - 5, p.dy + 13)
            ..lineTo(p.dx - 5, p.dy - 2)
            ..lineTo(p.dx + 5, p.dy - 2)
            ..lineTo(p.dx + 5, p.dy + 13),
        );
      case 6:
        draw(
          Path()
            ..moveTo(p.dx - 12, p.dy - 8)
            ..lineTo(p.dx + 12, p.dy - 8)
            ..lineTo(p.dx + 15, p.dy - 2)
            ..lineTo(p.dx + 15, p.dy + 14)
            ..lineTo(p.dx - 15, p.dy + 14)
            ..lineTo(p.dx - 15, p.dy - 2)
            ..close()
            ..addRect(Rect.fromLTWH(p.dx - 5, p.dy + 4, 10, 10)),
        );
    }
  }

  void _day27(Canvas c) {
    _rect(c, const Rect.fromLTWH(20, 66, 102, 88));
    for (var i = 0; i < 4; i++) {
      _line(c, <Offset>[
        Offset(45 + i * 25, 66),
        Offset(45 + i * 25, 154),
      ], opacity: .29);
    }
    for (var i = 0; i < 3; i++) {
      _line(c, <Offset>[
        Offset(20, 88 + i * 22),
        Offset(122, 88 + i * 22),
      ], opacity: .29);
    }
    if (done('return')) {
      final river = Path()
        ..moveTo(20, 104)
        ..cubicTo(43, 88, 61, 119, 80, 104)
        ..cubicTo(97, 90, 109, 96, 122, 91);
      c.drawPath(river, _stroke(color: _water, width: 1.7));
      _line(c, const <Offset>[
        Offset(96, 82),
        Offset(116, 91),
        Offset(96, 100),
      ], bright: true);
    }
    _wordSlot(
      c,
      'provision',
      const Rect.fromLTWH(39, 102, 64, 18),
      'what provisions…',
      carried: done('return'),
      fontSize: 8.1,
    );
    if (pick('returnKind').isNotEmpty) {
      _text(
        c,
        'return · ${pick('returnKind')}',
        const Offset(71, 178),
        width: 125,
        fontSize: 7.6,
      );
    }
  }

  void _day28(Canvas c) {
    _oval(c, const Rect.fromLTWH(13, 94, 44, 44));
    _oval(c, const Rect.fromLTWH(85, 94, 44, 44));
    final link = Path()
      ..moveTo(57, 116)
      ..cubicTo(72, 88, 88, 144, 85, 116);
    c.drawPath(
      link,
      done('give')
          ? _stroke(color: _goldGlow, width: 1.8)
          : _stroke(opacity: 0),
    );
    if (!done('give')) {
      _dashedPath(c, link, _stroke(width: 1.35, opacity: .38));
    }
    _wordSlot(
      c,
      'relationship',
      const Rect.fromLTWH(38, 70, 66, 18),
      'relationship…',
      carried: done('give'),
      fontSize: 8.5,
    );
    if (pick('provision').isNotEmpty) {
      _text(
        c,
        pick('provision'),
        const Offset(71, 163),
        width: 120,
        fontSize: 7.6,
      );
    }
  }

  void _day29(Canvas c) {
    _rect(c, const Rect.fromLTWH(14, 112, 114, 44), radius: 4);
    _rect(
      c,
      const Rect.fromLTWH(25, 73, 34, 30),
      radius: 3,
      opacity: .38,
      dashed: true,
    );
    _oval(c, const Rect.fromLTWH(75, 69, 38, 38), opacity: .38, dashed: true);
    _line(
      c,
      const <Offset>[Offset(72, 69), Offset(111, 69), Offset(111, 105)],
      opacity: .38,
      dashed: true,
    );
    if (done('prepare')) {
      _line(c, const <Offset>[Offset(22, 163), Offset(120, 163)], bright: true);
      _text(
        c,
        'set for tomorrow · still dashed',
        const Offset(71, 181),
        width: 130,
        fontSize: 6.8,
      );
    }
    if (pick('support').isNotEmpty) {
      _text(
        c,
        pick('support'),
        const Offset(71, 104),
        width: 100,
        fontSize: 7.6,
      );
    }
    _wordSlot(
      c,
      'easier',
      const Rect.fromLTWH(38, 129, 66, 18),
      'easier because…',
      carried: done('prepare'),
      fontSize: 8.3,
    );
  }

  void _day30(Canvas c) {
    _line(c, const <Offset>[
      Offset(18, 188),
      Offset(328, 188),
      Offset(316, 214),
      Offset(30, 214),
      Offset(18, 188),
    ]);
    _rect(c, const Rect.fromLTWH(46, 24, 239, 147), radius: 3);
    _text(c, 'THE ACCOUNT', const Offset(96, 42), width: 90, fontSize: 7.6);
    for (var i = 0; i < 5; i++) {
      final value = done('truth${i + 1}');
      c.drawCircle(
        Offset(61, 58 + i * 19),
        4,
        _fill(value ? _goldGlow : _gold, opacity: value ? 1 : .075),
      );
      _line(
        c,
        <Offset>[
          Offset(72, 58 + i * 19),
          Offset(value ? 258 : 182, 58 + i * 19),
        ],
        bright: value,
        opacity: value ? 1 : .29,
      );
      _text(c, '${i + 1}', Offset(78, 55 + i * 19), width: 10, fontSize: 7);
    }
    _wordSlot(
      c,
      'shortfall',
      const Rect.fromLTWH(62, 156, 92, 18),
      'shortfall…',
      fontSize: 8.5,
    );
    _wordSlot(
      c,
      'surprise',
      const Rect.fromLTWH(169, 156, 96, 18),
      'surprise…',
      carried: done('breath'),
      fontSize: 8.5,
    );
    _timer(c, const Offset(306, 92), 24, 'breath', 8);
    if (done('breath')) {
      c.drawCircle(const Offset(306, 92), 18, _fill(_goldGlow, opacity: .12));
      _line(c, const <Offset>[
        Offset(297, 92),
        Offset(304, 99),
        Offset(317, 81),
        Offset(306, 74),
        Offset(306, 110),
        Offset(288, 92),
        Offset(324, 92),
      ], bright: true);
    }
    final day29Support = courseStates[29]?.picks['support'] ?? '';
    if (day29Support.isNotEmpty) {
      _rect(c, const Rect.fromLTWH(292, 139, 28, 22), radius: 2, opacity: .55);
      _text(
        c,
        'day 29 · $day29Support',
        const Offset(306, 174),
        width: 74,
        fontSize: 6.4,
      );
    }
  }

  static String _timeLabel(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${value.hour < 12 ? 'AM' : 'PM'}';
  }

  @override
  bool shouldRepaint(covariant OfferingTableDayInstrumentPainter oldDelegate) {
    return oldDelegate.contract.day != contract.day ||
        oldDelegate.state.toJson().toString() != state.toJson().toString() ||
        oldDelegate.now.second != now.second ||
        oldDelegate.courseStates != courseStates;
  }
}
