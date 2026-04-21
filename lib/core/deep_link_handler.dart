import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:go_router/go_router.dart';
import 'app_link_intent.dart';

class DeepLinkHandler {
  static final _appLinks = AppLinks();

  static void _log(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  /// Initialize deep link handling
  static void initialize(BuildContext context) {
    _appLinks.uriLinkStream.listen((Uri uri) {
      if (!context.mounted) return;
      unawaited(handleDeepLink(context, uri));
    });
  }

  /// Handle initial deep link (app opened from link)
  static Future<void> handleInitialLink(BuildContext context) async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (!context.mounted) return;
      if (initialUri != null) {
        unawaited(handleDeepLink(context, initialUri));
      }
    } catch (e) {
      _log('[DeepLink] Error handling initial link: $e');
    }
  }

  static Future<void> handleDeepLink(BuildContext context, Uri uri) async {
    final intent = AppLinkIntent.parse(uri);
    if (intent == null) {
      _log('[DeepLink] Ignored unsupported link: $uri');
      return;
    }

    switch (intent) {
      case AuthAppLinkIntent():
        _log('[DeepLink] Auth callback should be handled by AuthGate: $uri');
      case ShareAppLinkIntent():
        if (!context.mounted) return;
        context.go(intent.routeLocation);
    }
  }
}
