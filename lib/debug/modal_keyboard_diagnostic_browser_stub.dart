class BrowserViewportSnapshot {
  const BrowserViewportSnapshot({
    required this.innerHeight,
    required this.visualViewportHeight,
    required this.visualViewportOffsetTop,
    required this.visualViewportPageTop,
  });

  final double? innerHeight;
  final double? visualViewportHeight;
  final double? visualViewportOffsetTop;
  final double? visualViewportPageTop;
}

typedef BrowserViewportListener =
    void Function(String event, BrowserViewportSnapshot snapshot);

class BrowserViewportSubscription {
  const BrowserViewportSubscription();

  void dispose() {}
}

BrowserViewportSubscription observeBrowserViewport(
  BrowserViewportListener listener,
) {
  return const BrowserViewportSubscription();
}
