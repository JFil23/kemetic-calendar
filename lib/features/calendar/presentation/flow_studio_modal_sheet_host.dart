import 'package:flutter/material.dart';

import '../../../widgets/day_sheet_components.dart';

/// Shared outer chrome for Flow Studio modal sheets.
///
/// Durable routes (`/flows`, `/flows/:flowId/edit`) and the Day Sheet embed
/// keep their own hosts. This widget only owns the tablet/phone modal frame
/// used by the detached and mounted Calendar sheet openers.
class FlowStudioModalSheetHost extends StatelessWidget {
  const FlowStudioModalSheetHost({
    super.key,
    required this.isTablet,
    required this.child,
    required this.onClose,
    this.phoneHeader,
  });

  static const BorderRadius borderRadius = BorderRadius.vertical(
    top: Radius.circular(16),
  );

  final bool isTablet;
  final Widget child;
  final VoidCallback onClose;
  final Widget? phoneHeader;

  static Widget handle() {
    return Container(
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  static Widget compactPhoneHeader() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const SizedBox(height: 10),
        handle(),
        const SizedBox(height: 8),
      ],
    );
  }

  static Widget overlayPhoneHeader({
    required bool showCloseButton,
    required VoidCallback onClose,
  }) {
    return SizedBox(
      height: showCloseButton ? 52 : 22,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          handle(),
          if (showCloseButton)
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close, color: DaySheetTokens.silverMid),
                onPressed: onClose,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isTablet) {
      return SafeArea(
        child: FractionallySizedBox(
          heightFactor: 0.9,
          child: ClipRRect(
            borderRadius: borderRadius,
            child: Material(
              color: Colors.black,
              child: Column(
                children: <Widget>[
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: onClose,
                    ),
                  ),
                  Expanded(child: child),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.4,
      maxChildSize: 1.0,
      snap: true,
      snapSizes: const <double>[0.8, 1.0],
      expand: false,
      builder: (context, scrollController) {
        return ClipRRect(
          borderRadius: borderRadius,
          child: Material(
            color: Colors.black,
            child: Column(
              children: <Widget>[
                phoneHeader ?? compactPhoneHeader(),
                Expanded(child: child),
              ],
            ),
          ),
        );
      },
    );
  }
}
