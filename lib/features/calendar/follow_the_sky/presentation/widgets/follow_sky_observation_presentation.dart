import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/sky_instrument_data.dart';
import '../fixtures/follow_sky_observation_presentation_fixture.dart';

class FollowSkyObservationPresentation extends StatefulWidget {
  const FollowSkyObservationPresentation({super.key, required this.fixture});

  final FollowSkyObservationPresentationFixture fixture;

  @override
  State<FollowSkyObservationPresentation> createState() =>
      _FollowSkyObservationPresentationState();
}

enum _PreviewCompletion { observed, partly, skipped }

class _FollowSkyObservationPresentationState
    extends State<FollowSkyObservationPresentation> {
  static const _velvet = Color(0xFF080706);
  static const _bone = Color(0xFFE8E2D6);
  static const _gold = Color(0xFFD4AE43);
  static const _goldDim = Color(0xFF8A7030);
  static const _silverMid = Color(0xFF9E9A94);
  static const _silverLow = Color(0xFF6A6660);
  static const _separator = Color(0xFF2A2415);
  static const _periwinkle = Color(0xFF6876D8);
  static const _glow = Color(0xFFA4B1FF);
  static const _rose = Color(0xFFE5C3C6);
  static const _display = 'CormorantGaramond';
  static const _ui = 'GentiumPlus';

  final TextEditingController _reflectionController = TextEditingController();
  late _LunarInstrumentController _instrumentController;
  bool _reflectionOpen = false;
  _PreviewCompletion? _completion;

  @override
  void initState() {
    super.initState();
    _instrumentController = _LunarInstrumentController(
      data: widget.fixture.instrument,
      initialSelection: widget.fixture.initialSelection,
    );
  }

  @override
  void didUpdateWidget(covariant FollowSkyObservationPresentation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fixture.instrument != widget.fixture.instrument) {
      _instrumentController.dispose();
      _instrumentController = _LunarInstrumentController(
        data: widget.fixture.instrument,
        initialSelection: widget.fixture.initialSelection,
      );
      _reflectionController.clear();
      _reflectionOpen = false;
      _completion = null;
    }
  }

  @override
  void dispose() {
    _instrumentController.dispose();
    _reflectionController.dispose();
    super.dispose();
  }

  void _selectFraction(double fraction) =>
      _instrumentController.selectFraction(fraction);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boundedHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : 620.0;
        final heroHeight = math.min(
          282.0,
          math.max(238.0, boundedHeight * 0.46),
        );
        final instrumentHeight = heroHeight + 76;
        return DecoratedBox(
          key: const ValueKey<String>('follow-sky-presentation-fixture'),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: <double>[0, 0.34, 0.74],
              colors: <Color>[Color(0xFF1B1220), Color(0xFF140F1A), _velvet],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: instrumentHeight,
                child: Column(
                  children: <Widget>[
                    SizedBox(
                      height: heroHeight,
                      child: ExcludeSemantics(
                        child: IgnorePointer(
                          child: RepaintBoundary(child: _buildSky()),
                        ),
                      ),
                    ),
                    _buildFinder(),
                    _buildDragInstruction(),
                  ],
                ),
              ),
              CustomScrollView(
                key: const ValueKey<String>('follow-sky-presentation-body'),
                physics: const BouncingScrollPhysics(),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: <Widget>[
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: instrumentHeight,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: SizedBox(
                          height: heroHeight,
                          child: _buildSkyInput(),
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: RepaintBoundary(
                      key: const ValueKey<String>(
                        'follow-sky-static-lower-sheet',
                      ),
                      child: _buildBody(),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(height: instrumentHeight * 0.64),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSky() {
    const compass = <String>['ESE', 'SE', 'SSE', 'S', 'SSW', 'SW', 'WSW'];
    final instrument = _instrumentController;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        RepaintBoundary(
          child: CustomPaint(
            isComplex: true,
            willChange: false,
            painter: _StaticSkyDomePainter(geometry: instrument.geometry),
          ),
        ),
        RepaintBoundary(
          child: CustomPaint(
            willChange: true,
            painter: _DynamicMoonPainter(instrument),
          ),
        ),
        const RepaintBoundary(child: CustomPaint(painter: _SkylinePainter())),
        Positioned(
          top: 20,
          left: 20,
          child: const Row(
            children: <Widget>[
              _SkySparkle(),
              SizedBox(width: 7),
              Text(
                'FOLLOW THE SKY',
                style: TextStyle(
                  color: _gold,
                  fontFamily: _ui,
                  fontSize: 10.5,
                  letterSpacing: 2.5,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 39,
          left: 20,
          right: 126,
          child: Text(
            widget.fixture.title.replaceFirst(' + ', ' +\n'),
            style: const TextStyle(
              color: Colors.white,
              fontFamily: _display,
              fontSize: 25,
              fontWeight: FontWeight.w500,
              height: 1.04,
              shadows: <Shadow>[Shadow(color: Colors.black87, blurRadius: 22)],
            ),
          ),
        ),
        Positioned(
          top: 22,
          right: 18,
          child: Text.rich(
            TextSpan(
              children: <InlineSpan>[
                TextSpan(
                  text: '${widget.fixture.dateLabel}\n',
                  style: const TextStyle(color: _rose, letterSpacing: 1.05),
                ),
                TextSpan(text: '${widget.fixture.locationLabel}\n'),
                TextSpan(text: widget.fixture.fullPhaseLabel),
              ],
            ),
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: _silverLow,
              fontFamily: _ui,
              fontSize: 9.5,
              height: 1.45,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Positioned(
          top: 113,
          right: 18,
          child: ValueListenableBuilder<_InstrumentFrame>(
            valueListenable: instrument,
            builder: (context, frame, _) => Text(
              _formatTime(frame.selectedAt),
              key: const ValueKey<String>('follow-sky-view-time'),
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: _glow,
                fontFamily: _display,
                fontSize: 18,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
                shadows: <Shadow>[
                  Shadow(color: _glow, blurRadius: 10),
                  Shadow(color: Colors.black87, blurRadius: 14),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 22,
          right: 22,
          bottom: 13,
          child: ValueListenableBuilder<_InstrumentFrame>(
            valueListenable: instrument,
            builder: (context, frame, _) {
              final compassIndex =
                  ((frame.position.azimuthDegrees - 112.5) / 22.5)
                      .round()
                      .clamp(0, 6);
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  for (var index = 0; index < compass.length; index++)
                    Text(
                      compass[index],
                      style: TextStyle(
                        color: index == compassIndex
                            ? _glow
                            : _bone.withValues(alpha: 0.28),
                        fontFamily: _ui,
                        fontSize: 9.5,
                        letterSpacing: 1.2,
                        shadows: index == compassIndex
                            ? const <Shadow>[
                                Shadow(color: _glow, blurRadius: 8),
                              ]
                            : null,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSkyInput() {
    return LayoutBuilder(
      builder: (context, constraints) {
        void update(Offset position) {
          _selectFraction(
            ((position.dx - 42) / (constraints.maxWidth - 84)).clamp(0.0, 1.0),
          );
        }

        final instrument = _instrumentController;
        final gesture = GestureDetector(
          key: const ValueKey<String>('follow-sky-hero-drag'),
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) => update(details.localPosition),
          onHorizontalDragDown: (details) => update(details.localPosition),
          onHorizontalDragUpdate: (details) => update(details.localPosition),
          child: const SizedBox.expand(),
        );
        return ValueListenableBuilder<_InstrumentFrame>(
          valueListenable: instrument,
          child: gesture,
          builder: (context, frame, child) => Semantics(
            label: 'Los Angeles lunar path presentation instrument',
            value:
                '${_formatTime(frame.selectedAt)}, ${frame.position.altitudeDegrees.toStringAsFixed(1)} degrees up, ${frame.position.azimuthDegrees.toStringAsFixed(0)} degrees azimuth',
            increasedValue: _formatTime(
              instrument.timeAtFraction(
                (frame.selectedFraction + 0.02).clamp(0.0, 1.0),
              ),
            ),
            decreasedValue: _formatTime(
              instrument.timeAtFraction(
                (frame.selectedFraction - 0.02).clamp(0.0, 1.0),
              ),
            ),
            slider: true,
            onIncrease: () => _selectFraction(
              (frame.selectedFraction + 0.02).clamp(0.0, 1.0),
            ),
            onDecrease: () => _selectFraction(
              (frame.selectedFraction - 0.02).clamp(0.0, 1.0),
            ),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildFinder() {
    return ValueListenableBuilder<_InstrumentFrame>(
      valueListenable: _instrumentController,
      builder: (context, frame, _) {
        final altitude = frame.position.altitudeDegrees.round();
        final note = altitude > 34
            ? 'high over the roofline'
            : altitude > 20
            ? 'clear of the roofline'
            : 'low · clear horizon';
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Flexible(
                child: Text(
                  _longCompassDirection(frame.position.azimuthDegrees),
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: const TextStyle(
                    color: _glow,
                    fontFamily: _display,
                    fontSize: 23,
                    fontStyle: FontStyle.italic,
                    shadows: <Shadow>[Shadow(color: _glow, blurRadius: 10)],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  '$altitude° up · $note',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _silverMid,
                    fontFamily: _ui,
                    fontSize: 12.5,
                    letterSpacing: 0.35,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDragInstruction() {
    return ValueListenableBuilder<_InstrumentFrame>(
      valueListenable: _instrumentController,
      builder: (context, frame, _) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 2, 20, 10),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text.rich(
            TextSpan(
              children: <InlineSpan>[
                const TextSpan(text: 'Drag the night. '),
                TextSpan(
                  text:
                      'Your view time moves to ${_formatTime(frame.selectedAt)}.',
                  style: const TextStyle(
                    color: _glow,
                    fontStyle: FontStyle.normal,
                  ),
                ),
              ],
            ),
            key: const ValueKey<String>('follow-sky-drag-instruction'),
            style: const TextStyle(
              color: _silverLow,
              fontFamily: _ui,
              fontSize: 11.5,
              fontStyle: FontStyle.italic,
              height: 1.2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Container(
      key: const ValueKey<String>('follow-sky-foreground-layer'),
      padding: const EdgeInsets.only(bottom: 22),
      decoration: const BoxDecoration(
        color: _velvet,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: Color(0x3A6876D8))),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0xB3000000),
            blurRadius: 24,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  widget.fixture.lens,
                  style: const TextStyle(
                    color: _periwinkle,
                    fontFamily: _ui,
                    fontSize: 10.5,
                    letterSpacing: 2.7,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.fixture.lensStatement,
                  style: const TextStyle(
                    color: _bone,
                    fontFamily: _display,
                    fontSize: 21,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(20, 17, 20, 0),
            padding: const EdgeInsets.fromLTRB(15, 14, 15, 15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _glow.withValues(alpha: 0.28)),
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: <Color>[
                  _periwinkle.withValues(alpha: 0.12),
                  Colors.white.withValues(alpha: 0.018),
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'YOU CHOSE',
                  style: TextStyle(
                    color: _glow,
                    fontFamily: _ui,
                    fontSize: 10,
                    letterSpacing: 2.4,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  '“${widget.fixture.intention}”',
                  style: const TextStyle(
                    color: _bone,
                    fontFamily: _display,
                    fontSize: 21,
                    fontWeight: FontWeight.w300,
                    fontStyle: FontStyle.italic,
                    height: 1.28,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.fixture.intentionContext,
                  style: const TextStyle(
                    color: _silverLow,
                    fontFamily: _ui,
                    fontSize: 11.5,
                    fontStyle: FontStyle.italic,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: _InstrumentTool(
              icon: Icons.description_outlined,
              label: 'Reflect',
              armed: _reflectionOpen,
              onTap: () => setState(() => _reflectionOpen = !_reflectionOpen),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 13, 20, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _glow,
                      shape: BoxShape.circle,
                      boxShadow: <BoxShadow>[
                        BoxShadow(color: _glow, blurRadius: 10),
                      ],
                    ),
                    child: SizedBox(width: 6, height: 6),
                  ),
                ),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Everything you add here is automatically kept in today’s Journal.',
                    style: TextStyle(
                      color: _silverLow,
                      fontFamily: _ui,
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_reflectionOpen) _buildReflection(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
            child: Row(
              children: <Widget>[
                const Text(
                  'COMPLETION',
                  style: TextStyle(
                    color: _goldDim,
                    fontFamily: _ui,
                    fontSize: 10.5,
                    letterSpacing: 2.7,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(child: Container(height: 1, color: _separator)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Row(
              children: <Widget>[
                _completionChip('Observed', _PreviewCompletion.observed),
                const SizedBox(width: 9),
                _completionChip('Partly', _PreviewCompletion.partly),
                const SizedBox(width: 9),
                _completionChip('Skipped', _PreviewCompletion.skipped),
              ],
            ),
          ),
          if (_completion != null) _buildConsequence(_completion!),
        ],
      ),
    );
  }

  Widget _buildReflection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'What did staying true to your choice look like tonight?',
            style: TextStyle(
              color: _bone,
              fontFamily: _display,
              fontSize: 20,
              height: 1.34,
            ),
          ),
          const SizedBox(height: 12),
          Stack(
            alignment: Alignment.bottomRight,
            children: <Widget>[
              TextField(
                key: const ValueKey<String>('follow-sky-fixture-reflection'),
                controller: _reflectionController,
                minLines: 3,
                maxLines: 5,
                style: const TextStyle(
                  color: _glow,
                  fontFamily: _display,
                  fontSize: 19,
                  fontStyle: FontStyle.italic,
                  height: 1.42,
                ),
                decoration: InputDecoration(
                  hintText: 'Type it, or say it out loud.',
                  hintStyle: const TextStyle(color: _silverLow),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.03),
                  contentPadding: const EdgeInsets.fromLTRB(13, 13, 52, 13),
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0x4DA4B1FF)),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(11),
                    ),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: _glow),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(11),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 9, bottom: 11),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _periwinkle.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                    border: Border.all(color: _glow.withValues(alpha: 0.34)),
                  ),
                  child: const Icon(Icons.mic_none, color: _glow, size: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _completionChip(String label, _PreviewCompletion value) {
    final selected = _completion == value;
    return Expanded(
      child: OutlinedButton(
        onPressed: () => setState(() => _completion = selected ? null : value),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 45),
          padding: EdgeInsets.zero,
          foregroundColor: selected ? _glow : _silverMid,
          backgroundColor: selected
              ? _periwinkle.withValues(alpha: 0.13)
              : Colors.transparent,
          side: BorderSide(
            color: selected ? _glow : _bone.withValues(alpha: 0.18),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontFamily: _display,
            fontSize: 16.5,
            fontWeight: FontWeight.w400,
          ),
        ),
        child: Text(label),
      ),
    );
  }

  Widget _buildConsequence(_PreviewCompletion completion) {
    final (heading, body) = switch (completion) {
      _PreviewCompletion.observed => (
        'KEPT',
        'Your choice, reflection, and anything you captured stay with this night. Hꜣw can return them when this pattern comes around again.',
      ),
      _PreviewCompletion.partly => (
        'KEPT',
        'A glance counts. Hꜣw keeps the reflection of what happened without turning the rest into debt.',
      ),
      _PreviewCompletion.skipped => (
        'NOTHING OWED',
        'The next Full Moon in this Flow is Sep 26. Your choice can end here or travel forward with you.',
      ),
    };
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 15, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.022),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _separator),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            heading,
            style: const TextStyle(
              color: _goldDim,
              fontFamily: _ui,
              fontSize: 10,
              letterSpacing: 2.4,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            body,
            style: const TextStyle(
              color: _silverMid,
              fontFamily: _display,
              fontSize: 17,
              height: 1.42,
            ),
          ),
        ],
      ),
    );
  }
}

class _InstrumentTool extends StatelessWidget {
  const _InstrumentTool({
    required this.icon,
    required this.label,
    required this.armed,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool armed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = armed
        ? _FollowSkyObservationPresentationState._glow
        : _FollowSkyObservationPresentationState._bone;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 69,
        decoration: BoxDecoration(
          color: armed
              ? _FollowSkyObservationPresentationState._periwinkle.withValues(
                  alpha: 0.1,
                )
              : Colors.white.withValues(alpha: 0.022),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: armed
                ? _FollowSkyObservationPresentationState._glow
                : _FollowSkyObservationPresentationState._separator,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, color: color, size: 23),
            const SizedBox(height: 7),
            Text(
              label,
              style: TextStyle(
                color: armed
                    ? _FollowSkyObservationPresentationState._glow
                    : _FollowSkyObservationPresentationState._silverMid,
                fontFamily: _FollowSkyObservationPresentationState._ui,
                fontSize: 11,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkySparkle extends StatelessWidget {
  const _SkySparkle();

  @override
  Widget build(BuildContext context) => const SizedBox(
    key: ValueKey<String>('follow-sky-sparkle'),
    width: 12,
    height: 12,
    child: CustomPaint(painter: _SkySparklePainter()),
  );
}

class _SkySparklePainter extends CustomPainter {
  const _SkySparklePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final path = Path()
      ..moveTo(center.dx, 0)
      ..quadraticBezierTo(
        center.dx + 1.2,
        center.dy - 1.2,
        size.width,
        center.dy,
      )
      ..quadraticBezierTo(
        center.dx + 1.2,
        center.dy + 1.2,
        center.dx,
        size.height,
      )
      ..quadraticBezierTo(center.dx - 1.2, center.dy + 1.2, 0, center.dy)
      ..quadraticBezierTo(center.dx - 1.2, center.dy - 1.2, center.dx, 0)
      ..close();
    canvas.drawPath(
      path,
      Paint()..color = _FollowSkyObservationPresentationState._gold,
    );
  }

  @override
  bool shouldRepaint(covariant _SkySparklePainter oldDelegate) => false;
}

class _InstrumentFrame {
  const _InstrumentFrame({
    required this.selectedAt,
    required this.selectedFraction,
    required this.position,
  });

  final DateTime selectedAt;
  final double selectedFraction;
  final SkyPositionSample position;
}

class _LunarDisplayGeometry {
  _LunarDisplayGeometry(LunarPathData data)
    : rise = data.rise!,
      transit = data.transit!,
      set = data.set!,
      maximum = data.eclipseContacts.firstWhere(
        (contact) => contact.kind == LunarEclipseContactKind.maximum,
      ),
      sortedSamples = (data.moonSamples.toList(growable: false)
        ..sort((a, b) => a.at.compareTo(b.at))) {
    maxAltitude = sortedSamples
        .map((sample) => sample.altitudeDegrees)
        .reduce(math.max);
    skyPath = List<Offset>.unmodifiable(
      List<Offset>.generate(59, (index) {
        final fraction = index / 58;
        final at = timeAtFraction(fraction);
        final altitude = positionAt(at).altitudeDegrees;
        return Offset(fraction, (altitude / maxAltitude).clamp(0.0, 1.0));
      }),
    );
  }

  final DateTime rise;
  final DateTime transit;
  final DateTime set;
  final LunarEclipseContact maximum;
  final List<SkyPositionSample> sortedSamples;
  late final double maxAltitude;
  late final List<Offset> skyPath;

  double fractionAt(DateTime at) => _fractionAt(at, rise, transit, set);

  DateTime timeAtFraction(double fraction) =>
      _timeAtFraction(fraction, rise, transit, set);

  SkyPositionSample positionAt(DateTime at) =>
      _interpolatePosition(sortedSamples, at);

  Offset pointAt(Size size, DateTime at) {
    final position = positionAt(at);
    return pointFor(
      size,
      fractionAt(at),
      position.altitudeDegrees / maxAltitude,
    );
  }

  Offset pointFor(Size size, double fraction, double normalizedAltitude) {
    final baseY = size.height - 39;
    final apexY = math.max(92.0, size.height * 0.34);
    return Offset(
      42 + fraction * (size.width - 84),
      baseY - normalizedAltitude.clamp(0.0, 1.0) * (baseY - apexY),
    );
  }
}

class _LunarInstrumentController extends ValueNotifier<_InstrumentFrame> {
  factory _LunarInstrumentController({
    required LunarPathData data,
    required DateTime initialSelection,
  }) {
    final geometry = _LunarDisplayGeometry(data);
    return _LunarInstrumentController._(geometry, initialSelection);
  }

  _LunarInstrumentController._(this.geometry, DateTime initialSelection)
    : super(_frameFor(geometry, initialSelection));

  final _LunarDisplayGeometry geometry;

  static _InstrumentFrame _frameFor(
    _LunarDisplayGeometry geometry,
    DateTime selectedAt,
  ) {
    final fraction = geometry.fractionAt(selectedAt);
    return _InstrumentFrame(
      selectedAt: selectedAt,
      selectedFraction: fraction,
      position: geometry.positionAt(selectedAt),
    );
  }

  DateTime timeAtFraction(double fraction) =>
      geometry.timeAtFraction(fraction.clamp(0.0, 1.0));

  void selectFraction(double fraction) {
    final next = timeAtFraction(fraction);
    final selectedAt = DateTime(
      next.year,
      next.month,
      next.day,
      next.hour,
      next.minute,
    );
    if (selectedAt == value.selectedAt) return;
    value = _frameFor(geometry, selectedAt);
  }
}

class _StaticSkyDomePainter extends CustomPainter {
  const _StaticSkyDomePainter({required this.geometry});

  final _LunarDisplayGeometry geometry;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -1),
          radius: 1.35,
          colors: <Color>[
            Color(0xFF2C2338),
            Color(0xFF1A1526),
            Color(0xFF0C0912),
          ],
          stops: <double>[0, 0.46, 1],
        ).createShader(bounds),
    );

    for (var index = 0; index < 118; index++) {
      final x = ((index * 83 + 29) % 521) / 521 * size.width;
      final rawY = ((index * index * 37 + index * 17 + 11) % 389) / 389;
      final y = math.pow(rawY, 1.3) * size.height * 0.9;
      final alpha = (0.1 + (index % 9) * 0.055) * (1 - y / size.height);
      canvas.drawCircle(
        Offset(x, y),
        index % 13 == 0 ? 1.25 : 0.55 + (index % 3) * 0.18,
        Paint()..color = const Color(0xFFEFE7DE).withValues(alpha: alpha),
      );
    }

    final pathDotPaint = Paint()
      ..color = _FollowSkyObservationPresentationState._rose.withValues(
        alpha: 0.28,
      );
    for (final point in geometry.skyPath) {
      canvas.drawCircle(
        geometry.pointFor(size, point.dx, point.dy),
        1,
        pathDotPaint,
      );
    }

    final apex = geometry.pointAt(size, geometry.transit);
    canvas.drawLine(
      apex.translate(0, -40),
      apex.translate(0, -30),
      Paint()
        ..color = _FollowSkyObservationPresentationState._rose.withValues(
          alpha: 0.4,
        ),
    );
    _paintLabel(
      canvas,
      'HIGHEST · ${_formatTime(geometry.transit)}',
      apex.translate(0, -48),
      color: _FollowSkyObservationPresentationState._rose.withValues(
        alpha: 0.58,
      ),
      centered: true,
    );

    final maximumPoint = geometry.pointAt(size, geometry.maximum.at);
    canvas.drawCircle(
      maximumPoint,
      3.2,
      Paint()..color = const Color(0xFFD88C82),
    );
    _paintLabel(
      canvas,
      'ECLIPSE MAX',
      maximumPoint.translate(2, -13),
      color: _FollowSkyObservationPresentationState._rose.withValues(
        alpha: 0.72,
      ),
      centered: true,
      fontSize: 8.7,
    );
  }

  void _paintLabel(
    Canvas canvas,
    String text,
    Offset position, {
    required Color color,
    bool centered = false,
    double fontSize = 9.3,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontFamily: _FollowSkyObservationPresentationState._ui,
          fontSize: fontSize,
          letterSpacing: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      centered ? position.translate(-painter.width / 2, 0) : position,
    );
  }

  @override
  bool shouldRepaint(covariant _StaticSkyDomePainter oldDelegate) =>
      oldDelegate.geometry != geometry;
}

class _DynamicMoonPainter extends CustomPainter {
  _DynamicMoonPainter(this.controller) : super(repaint: controller);

  final _LunarInstrumentController controller;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = controller.value;
    final geometry = controller.geometry;
    final moon = geometry.pointFor(
      size,
      frame.selectedFraction,
      frame.position.altitudeDegrees / geometry.maxAltitude,
    );
    final brightness = math
        .sin(math.pi * frame.selectedFraction)
        .clamp(0.0, 1.0);

    final litPathPaint = Paint()
      ..color = _FollowSkyObservationPresentationState._glow.withValues(
        alpha: 0.58,
      );
    final litPathGlow = Paint()
      ..color = _FollowSkyObservationPresentationState._glow.withValues(
        alpha: 0.18,
      )
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    for (final point in geometry.skyPath) {
      if (point.dx > frame.selectedFraction) break;
      final pathPoint = geometry.pointFor(size, point.dx, point.dy);
      canvas.drawCircle(pathPoint, 2.6, litPathGlow);
      canvas.drawCircle(pathPoint, 1.1, litPathPaint);
    }

    canvas.drawCircle(
      moon,
      52 + 34 * brightness,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            const Color(0xFFF0E1DC).withValues(alpha: 0.34),
            const Color(0xFFBEA5C8).withValues(alpha: 0.1),
            Colors.transparent,
          ],
          stops: const <double>[0, 0.52, 1],
        ).createShader(Rect.fromCircle(center: moon, radius: 86)),
    );
    canvas.drawCircle(moon, 24, Paint()..color = const Color(0xFFF6EEE3));
    final minutesFromMaximum =
        frame.selectedAt.difference(geometry.maximum.at).inSeconds.abs() / 60;
    final eclipseStrength = math.max(0.0, 1 - minutesFromMaximum / 105);
    if (eclipseStrength > 0) {
      canvas.save();
      canvas.clipPath(
        Path()..addOval(Rect.fromCircle(center: moon, radius: 24)),
      );
      canvas.drawCircle(
        moon.translate(8 - 14 * eclipseStrength, 0),
        24,
        Paint()
          ..color = const Color(
            0xFF7B3F4C,
          ).withValues(alpha: 0.78 * eclipseStrength),
      );
      canvas.restore();
    }
    canvas.drawCircle(
      moon,
      24,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7,
    );
  }

  @override
  bool shouldRepaint(covariant _DynamicMoonPainter oldDelegate) =>
      oldDelegate.controller != controller;
}

class _SkylinePainter extends CustomPainter {
  const _SkylinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final roof = Path()
      ..moveTo(0, size.height - 32)
      ..lineTo(size.width * 0.13, size.height - 32)
      ..lineTo(size.width * 0.13, size.height - 58)
      ..lineTo(size.width * 0.27, size.height - 58)
      ..lineTo(size.width * 0.27, size.height - 40)
      ..lineTo(size.width * 0.43, size.height - 40)
      ..lineTo(size.width * 0.47, size.height - 66)
      ..lineTo(size.width * 0.51, size.height - 40)
      ..lineTo(size.width * 0.69, size.height - 40)
      ..lineTo(size.width * 0.69, size.height - 52)
      ..lineTo(size.width * 0.82, size.height - 52)
      ..lineTo(size.width * 0.82, size.height - 36)
      ..lineTo(size.width, size.height - 36)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(roof, Paint()..color = const Color(0xFF08060B));
    canvas.drawPath(
      roof,
      Paint()
        ..color = _FollowSkyObservationPresentationState._glow.withValues(
          alpha: 0.16,
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - 92, size.width, 92),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Colors.transparent,
            const Color(0xFF0A0808).withValues(alpha: 0.5),
            _FollowSkyObservationPresentationState._velvet,
          ],
        ).createShader(Rect.fromLTWH(0, size.height - 92, size.width, 92)),
    );
  }

  @override
  bool shouldRepaint(covariant _SkylinePainter oldDelegate) => false;
}

SkyPositionSample _interpolatePosition(
  List<SkyPositionSample> samples,
  DateTime at,
) {
  final sorted = samples.toList(growable: false)
    ..sort((a, b) => a.at.compareTo(b.at));
  if (!at.isAfter(sorted.first.at)) return sorted.first;
  if (!at.isBefore(sorted.last.at)) return sorted.last;
  for (var index = 0; index < sorted.length - 1; index++) {
    final left = sorted[index];
    final right = sorted[index + 1];
    if (at.isAfter(right.at)) continue;
    final span = right.at.difference(left.at).inMilliseconds;
    final elapsed = at.difference(left.at).inMilliseconds;
    final fraction = span == 0 ? 0.0 : elapsed / span;
    return SkyPositionSample(
      at: at,
      azimuthDegrees:
          left.azimuthDegrees +
          (right.azimuthDegrees - left.azimuthDegrees) * fraction,
      altitudeDegrees:
          left.altitudeDegrees +
          (right.altitudeDegrees - left.altitudeDegrees) * fraction,
    );
  }
  return sorted.last;
}

double _fractionAt(DateTime at, DateTime rise, DateTime transit, DateTime set) {
  if (!at.isAfter(rise)) return 0;
  if (!at.isBefore(set)) return 1;
  if (!at.isAfter(transit)) {
    return 0.5 *
        at.difference(rise).inMilliseconds /
        transit.difference(rise).inMilliseconds;
  }
  return 0.5 +
      0.5 *
          at.difference(transit).inMilliseconds /
          set.difference(transit).inMilliseconds;
}

DateTime _timeAtFraction(
  double fraction,
  DateTime rise,
  DateTime transit,
  DateTime set,
) {
  final milliseconds = fraction <= 0.5
      ? transit.difference(rise).inMilliseconds * (fraction / 0.5)
      : set.difference(transit).inMilliseconds * ((fraction - 0.5) / 0.5);
  return (fraction <= 0.5 ? rise : transit).add(
    Duration(milliseconds: milliseconds.round()),
  );
}

String _formatTime(DateTime value) {
  final period = value.hour >= 12 ? 'PM' : 'AM';
  final hour = value.hour == 0
      ? 12
      : value.hour > 12
      ? value.hour - 12
      : value.hour;
  return '$hour:${value.minute.toString().padLeft(2, '0')} $period';
}

String _longCompassDirection(double azimuth) {
  const directions = <String>[
    'Due north',
    'North-northeast',
    'Northeast',
    'East-northeast',
    'Due east',
    'East-southeast',
    'Southeast',
    'South-southeast',
    'Due south',
    'South-southwest',
    'Southwest',
    'West-southwest',
    'Due west',
    'West-northwest',
    'Northwest',
    'North-northwest',
  ];
  return directions[((azimuth / 22.5).round()) % directions.length];
}
