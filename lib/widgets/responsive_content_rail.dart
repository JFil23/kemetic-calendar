import 'package:flutter/material.dart';

class ResponsiveContentRail extends StatelessWidget {
  const ResponsiveContentRail({
    super.key,
    required this.child,
    this.breakpoint = 600,
    this.maxWidth = 720,
    this.expandHeight = true,
  });

  final Widget child;
  final double breakpoint;
  final double maxWidth;
  final bool expandHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.maxWidth.isFinite ||
            constraints.maxWidth < breakpoint) {
          return child;
        }

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: SizedBox(
              width: double.infinity,
              height: expandHeight && constraints.maxHeight.isFinite
                  ? constraints.maxHeight
                  : null,
              child: child,
            ),
          ),
        );
      },
    );
  }
}
