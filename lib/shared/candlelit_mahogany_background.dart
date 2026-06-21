import 'package:flutter/material.dart';

class CandlelitMahoganyBackground extends StatelessWidget {
  const CandlelitMahoganyBackground({
    super.key,
    required this.child,
    this.includeBottomScrim = true,
    this.paintBottomScrimAboveChild = true,
  });

  static const Color base = Color(0xFF0D0B07);
  static const double scrimHeight = 96;

  static const Gradient crownBloom = RadialGradient(
    center: Alignment(0, -1.2),
    radius: 1.2,
    colors: <Color>[Color.fromRGBO(93, 82, 65, 0.18), Colors.transparent],
    stops: <double>[0, 0.6],
  );

  static const Gradient bottomScrim = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[Colors.transparent, base],
    stops: <double>[0, 0.78],
  );

  final Widget child;
  final bool includeBottomScrim;
  final bool paintBottomScrimAboveChild;

  @override
  Widget build(BuildContext context) {
    const bottomScrimLayer = Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: scrimHeight,
      child: IgnorePointer(
        child: DecoratedBox(decoration: BoxDecoration(gradient: bottomScrim)),
      ),
    );

    return ColoredBox(
      color: base,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const DecoratedBox(
            decoration: BoxDecoration(color: base, gradient: crownBloom),
          ),
          if (includeBottomScrim && !paintBottomScrimAboveChild)
            bottomScrimLayer,
          Positioned.fill(child: child),
          if (includeBottomScrim && paintBottomScrimAboveChild)
            bottomScrimLayer,
        ],
      ),
    );
  }
}
