import 'package:flutter/foundation.dart';

import 'planner_launch_intent.dart';

@immutable
abstract class AppLinkIntent {
  const AppLinkIntent();

  static AppLinkIntent? parse(Uri uri) {
    return AppLinkIntentParser.parse(uri);
  }
}

@immutable
class AuthAppLinkIntent extends AppLinkIntent {
  final Uri uri;

  const AuthAppLinkIntent(this.uri);
}

@immutable
class ShareAppLinkIntent extends AppLinkIntent {
  final String shareId;
  final String? token;

  const ShareAppLinkIntent({required this.shareId, this.token});

  String get routeLocation {
    final queryParameters = <String, String>{
      if (token != null && token!.isNotEmpty) 'token': token!,
    };
    return Uri(
      path: '/share/$shareId',
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    ).toString();
  }
}

@immutable
class FlowPostAppLinkIntent extends AppLinkIntent {
  final String postId;

  const FlowPostAppLinkIntent({required this.postId});

  String get routeLocation => '/flow-post/${Uri.encodeComponent(postId)}';
}

@immutable
class PlannerAppLinkIntent extends AppLinkIntent {
  final PlannerLaunchIntent plannerIntent;

  const PlannerAppLinkIntent(this.plannerIntent);

  String get routeLocation => plannerIntent.routeLocation;
}

class AppLinkIntentParser {
  static AppLinkIntent? parse(Uri uri) {
    if (_looksLikeAuthCallback(uri)) {
      return AuthAppLinkIntent(uri);
    }

    final plannerIntent = PlannerLaunchIntent.parse(uri);
    if (plannerIntent != null) {
      return PlannerAppLinkIntent(plannerIntent);
    }

    final flowPostIntent = _parseFlowPostLink(uri);
    if (flowPostIntent != null) return flowPostIntent;

    return _parseShareLink(uri);
  }

  static FlowPostAppLinkIntent? _parseFlowPostLink(Uri uri) {
    final segments = uri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);
    final supportedWebHost =
        uri.host == 'maat.app' || uri.host == 'www.maat.app';
    final supportedScheme = uri.scheme == 'maat';
    if (!supportedWebHost && !supportedScheme) return null;
    if (supportedScheme && uri.host.toLowerCase() == 'flow-post') {
      final postId = segments.isEmpty ? null : _nonEmpty(segments.first);
      return postId == null ? null : FlowPostAppLinkIntent(postId: postId);
    }
    if (segments.length < 2) return null;
    if (segments.first.toLowerCase() != 'flow-post') return null;
    final postId = _nonEmpty(segments[1]);
    return postId == null ? null : FlowPostAppLinkIntent(postId: postId);
  }

  static bool _looksLikeAuthCallback(Uri uri) {
    final qp = uri.queryParameters;
    final fragment = uri.fragment;
    return qp.containsKey('code') ||
        qp.containsKey('access_token') ||
        qp.containsKey('refresh_token') ||
        fragment.contains('access_token=') ||
        fragment.contains('refresh_token=');
  }

  static ShareAppLinkIntent? _parseShareLink(Uri uri) {
    final token =
        _nonEmpty(uri.queryParameters['token']) ??
        _nonEmpty(uri.queryParameters['t']);

    final shareIdFromQuery = _nonEmpty(uri.queryParameters['share']);
    if (shareIdFromQuery != null) {
      return ShareAppLinkIntent(shareId: shareIdFromQuery, token: token);
    }

    final segments = uri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);

    if (segments.length >= 2) {
      final shareId = _parsePathShareId(segments[0], segments[1]);
      if (shareId != null) {
        return ShareAppLinkIntent(shareId: shareId, token: token);
      }
    }

    final shareIdFromHost = _parseHostShareId(uri.host, segments);
    if (shareIdFromHost != null) {
      return ShareAppLinkIntent(shareId: shareIdFromHost, token: token);
    }

    return null;
  }

  static String? _parsePathShareId(String leadingSegment, String rawShareId) {
    switch (leadingSegment.toLowerCase()) {
      case 'share':
      case 'f':
        return _nonEmpty(rawShareId);
      default:
        return null;
    }
  }

  static String? _parseHostShareId(String rawHost, List<String> segments) {
    final host = rawHost.toLowerCase();

    if ((host == 'share' || host == 'f' || host == 'flow') &&
        segments.isNotEmpty) {
      return _nonEmpty(segments.first);
    }

    if ((host == 'maat.app' || host == 'www.maat.app') &&
        segments.length >= 2) {
      return _parsePathShareId(segments[0], segments[1]);
    }

    return null;
  }

  static String? _nonEmpty(String? raw) {
    final trimmed = raw?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}
