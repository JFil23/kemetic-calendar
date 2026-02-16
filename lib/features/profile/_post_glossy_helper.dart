import 'package:flutter/material.dart';

LinearGradient glossFromColor(int color) {
  final base = Color(0xFF000000 | (color & 0x00FFFFFF));
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      base.withOpacity(0.9),
      base,
      base.withOpacity(0.8),
    ],
  );
}
