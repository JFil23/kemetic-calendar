import 'package:flutter/foundation.dart';

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

class AppLinkIntentParser {
  static AppLinkIntent? parse(Uri uri) {
    if (_looksLikeAuthCallback(uri)) {
      return AuthAppLinkIntent(uri);
    }

    return _parseShareLink(uri);
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
