import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

final RegExp externalLinkPattern = RegExp(
  r'([^\s@]+@[^\s@]+\.[^\s@]+|(?:https?:\/\/|www\.)[^\s<>()]+|(?:[a-z0-9-]+\.)+[a-z]{2,}(?:\/[^\s<>()]*)?)',
  caseSensitive: false,
  multiLine: true,
);

const Set<String> _nativePreferredHosts = {
  'zoom.us',
  'meet.google.com',
  'youtube.com',
  'youtu.be',
  'maps.google.com',
  'maps.app.goo.gl',
  'calendar.google.com',
  'teams.microsoft.com',
  'discord.gg',
  'slack.com',
};

String normalizeExternalLinkToken(String raw) {
  var normalized = raw.trim();
  while (normalized.isNotEmpty && RegExp(r'[),.;!?]$').hasMatch(normalized)) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  return normalized;
}

bool looksLikeLaunchTarget(String text) {
  final lower = text.toLowerCase().trim();
  if (lower.isEmpty) return false;

  if (RegExp(r'^[a-z][a-z0-9+\-.]*:').hasMatch(lower)) {
    return true;
  }

  if (lower.startsWith('http://') || lower.startsWith('https://')) {
    return true;
  }

  if (RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(lower)) {
    return true;
  }

  final phonePattern = RegExp(
    r'^[\+]?[(]?[0-9]{3}[)]?[-\s\.]?[0-9]{3}[-\s\.]?[0-9]{4,6}$',
  );
  final digitsOnly = lower.replaceAll(RegExp(r'[\s\-\(\)\.]'), '');
  if (phonePattern.hasMatch(lower) ||
      (digitsOnly.length >= 10 &&
          digitsOnly.length <= 15 &&
          RegExp(r'^\+?[0-9]+$').hasMatch(digitsOnly))) {
    return true;
  }

  final knownServices = [
    r'zoom\.us',
    r'meet\.google\.com',
    r'youtube\.com',
    r'youtu\.be',
    r'facebook\.com',
    r'instagram\.com',
    r'twitter\.com',
    r'linkedin\.com',
    r'tiktok\.com',
    r'discord\.gg',
    r'slack\.com',
    r'teams\.microsoft\.com',
    r'maps\.google\.com',
    r'maps\.app\.goo\.gl',
    r'calendar\.google\.com',
    r'zoommtg://',
  ];

  for (final service in knownServices) {
    if (RegExp(service).hasMatch(lower)) {
      return true;
    }
  }

  if (RegExp(
        r'^[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,}(/.*)?$',
      ).hasMatch(lower) &&
      lower.contains('.') &&
      !lower.contains(' ')) {
    return true;
  }

  if (lower.startsWith('www.')) {
    return true;
  }

  return false;
}

Uri? buildExternalLaunchUri(String raw, {bool fallbackToMaps = true}) {
  final loc = normalizeExternalLinkToken(raw);
  if (loc.isEmpty) return null;

  if (looksLikeLaunchTarget(loc)) {
    final lower = loc.toLowerCase();

    if (RegExp(r'^[a-z][a-z0-9+\-.]*:').hasMatch(lower)) {
      return Uri.parse(loc);
    }

    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return Uri.parse(loc);
    }

    if (RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(lower)) {
      return Uri.parse('mailto:$loc');
    }

    final digitsOnly = lower.replaceAll(RegExp(r'[\s\-\(\)\.]'), '');
    final phonePattern = RegExp(r'^\+?[0-9]{7,15}$');
    if (phonePattern.hasMatch(digitsOnly)) {
      return Uri.parse('tel:$loc');
    }

    return Uri.parse('https://$loc');
  }

  if (!fallbackToMaps) return null;
  final q = Uri.encodeComponent(loc);
  return Uri.parse('https://maps.google.com/?q=$q');
}

bool _hostMatches(String host, String expectedHost) {
  return host == expectedHost || host.endsWith('.$expectedHost');
}

@visibleForTesting
List<LaunchMode> preferredLaunchModesForUri(Uri uri) {
  final scheme = uri.scheme.toLowerCase();
  final host = uri.host.toLowerCase();
  final isWebUrl = scheme == 'http' || scheme == 'https';

  if (!isWebUrl) {
    return const [LaunchMode.externalApplication, LaunchMode.platformDefault];
  }

  final prefersNativeApp = _nativePreferredHosts.any(
    (expectedHost) => _hostMatches(host, expectedHost),
  );
  if (prefersNativeApp) {
    return const [
      LaunchMode.externalNonBrowserApplication,
      LaunchMode.externalApplication,
      LaunchMode.inAppBrowserView,
      LaunchMode.inAppWebView,
      LaunchMode.platformDefault,
    ];
  }

  return const [
    LaunchMode.externalApplication,
    LaunchMode.inAppBrowserView,
    LaunchMode.inAppWebView,
    LaunchMode.platformDefault,
  ];
}

Future<bool> launchExternalTarget(
  String raw, {
  bool fallbackToMaps = true,
}) async {
  final uri = buildExternalLaunchUri(raw, fallbackToMaps: fallbackToMaps);
  if (uri == null) return false;

  for (final mode in preferredLaunchModesForUri(uri)) {
    try {
      if (await launchUrl(uri, mode: mode)) {
        return true;
      }
    } catch (_) {
      // Try the next launch mode.
    }
  }

  return false;
}
