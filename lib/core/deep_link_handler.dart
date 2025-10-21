import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import '../data/share_repo.dart';
import '../features/inbox/inbox_page.dart';

class DeepLinkHandler {
  static final _repo = ShareRepo(Supabase.instance.client);
  static final _appLinks = AppLinks();

  /// Initialize deep link handling
  static void initialize(BuildContext context) {
    _appLinks.uriLinkStream.listen((Uri uri) {
      handleDeepLink(context, uri);
    });
  }

  /// Handle initial deep link (app opened from link)
  static Future<void> handleInitialLink(BuildContext context) async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        handleDeepLink(context, initialUri);
      }
    } catch (e) {
      print('[DeepLink] Error handling initial link: $e');
    }
  }

  static Future<void> handleDeepLink(BuildContext context, Uri uri) async {
    print('[DeepLink] Handling: $uri');

    // maat://flow/123?share=uuid&t=token
    if (uri.scheme == 'maat' && uri.host == 'flow') {
      final shareId = uri.queryParameters['share'];
      final token = uri.queryParameters['token'];

      if (shareId == null) {
        print('[DeepLink] Missing share ID');
        return;
      }

      try {
        final data = await _repo.resolveShare(
          shareId: shareId,
          token: token,
        );

        if (data['auth_required'] == true) {
          // Show sign-in prompt
          // TODO: Navigate to sign-in
          print('[DeepLink] Auth required');
          return;
        }

        // TODO: Open Flow Preview Card with data
        print('[DeepLink] Flow data: ${data['flow']}');
        
      } catch (e) {
        print('[DeepLink] Error: $e');
      }
    }

    // https://maat.app/f/shortid
    else if (uri.host == 'maat.app' && uri.pathSegments.isNotEmpty) {
      if (uri.pathSegments[0] == 'f' && uri.pathSegments.length > 1) {
        final shortLinkId = uri.pathSegments[1];

        try {
          final data = await _repo.resolveShare(
            shareId: '',
            shortLinkId: shortLinkId,
          );

          // TODO: Open Flow Preview Card
          print('[DeepLink] Flow from short link: ${data['flow']}');
          
        } catch (e) {
          print('[DeepLink] Error: $e');
        }
      }
    }
  }
}