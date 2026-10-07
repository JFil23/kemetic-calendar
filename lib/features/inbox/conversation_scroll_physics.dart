import 'package:flutter/widgets.dart';

/// Preserve the visible end of a chat while either keyboard changes its height.
/// A person reading older messages keeps their position. Short chats retain the
/// existing top alignment, spacing and ordinary platform scrolling behavior.
class ConversationScrollPhysics extends RangeMaintainingScrollPhysics {
  const ConversationScrollPhysics({super.parent});

  @override
  ConversationScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      ConversationScrollPhysics(parent: buildParent(ancestor));

  @override
  double adjustPositionForNewDimensions({
    required ScrollMetrics oldPosition,
    required ScrollMetrics newPosition,
    required bool isScrolling,
    required double velocity,
  }) {
    if (velocity == 0 &&
        newPosition.pixels >= oldPosition.maxScrollExtent - 1 &&
        newPosition.pixels >= newPosition.minScrollExtent) {
      return newPosition.maxScrollExtent;
    }
    return super.adjustPositionForNewDimensions(
      oldPosition: oldPosition,
      newPosition: newPosition,
      isScrolling: isScrolling,
      velocity: velocity,
    );
  }
}
