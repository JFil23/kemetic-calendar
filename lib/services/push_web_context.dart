class WebPushContext {
  const WebPushContext({
    required this.secureContext,
    required this.notificationApiAvailable,
    required this.serviceWorkerApiAvailable,
    required this.pushManagerApiAvailable,
    required this.appleMobile,
    required this.standalone,
    required this.serviceWorkerScriptReachable,
  });

  final bool secureContext;
  final bool notificationApiAvailable;
  final bool serviceWorkerApiAvailable;
  final bool pushManagerApiAvailable;
  final bool appleMobile;
  final bool standalone;
  final bool serviceWorkerScriptReachable;

  String? get blockerMessage {
    if (!secureContext) {
      return 'Web push requires HTTPS (or localhost during development).';
    }
    if (appleMobile && !standalone) {
      return 'On iPhone and iPad, web push only works from the installed Home Screen app.';
    }
    if (!notificationApiAvailable ||
        !serviceWorkerApiAvailable ||
        !pushManagerApiAvailable) {
      return 'This browser does not expose the APIs required for web push.';
    }
    if (!serviceWorkerScriptReachable) {
      return 'The web push service worker is missing from this web build.';
    }
    return null;
  }
}

Future<bool> ensureWebPushServiceWorkerReady() async {
  return true;
}

Future<WebPushContext> inspectWebPushContext() async {
  return const WebPushContext(
    secureContext: true,
    notificationApiAvailable: true,
    serviceWorkerApiAvailable: true,
    pushManagerApiAvailable: true,
    appleMobile: false,
    standalone: true,
    serviceWorkerScriptReachable: true,
  );
}
