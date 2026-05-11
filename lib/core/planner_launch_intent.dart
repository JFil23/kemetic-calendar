import 'package:flutter/foundation.dart';

@immutable
class PlannerLaunchIntent {
  const PlannerLaunchIntent({
    required this.route,
    this.openDayCard = false,
    this.localDate,
    this.timezone,
    this.source,
    this.launchToken,
  });

  static const String canonicalRoute = '/rhythm/today';

  final String route;
  final bool openDayCard;
  final DateTime? localDate;
  final String? timezone;
  final String? source;
  final String? launchToken;

  static PlannerLaunchIntent? parse(Uri uri) {
    final route = _plannerRouteFor(uri);
    if (route == null) return null;

    return PlannerLaunchIntent(
      route: route,
      openDayCard: _isTruthy(uri.queryParameters['openDayCard']),
      localDate: _parseLocalDate(uri.queryParameters['date']),
      timezone: _nonEmpty(uri.queryParameters['tz']),
      source: _nonEmpty(uri.queryParameters['source']),
      launchToken: _nonEmpty(uri.queryParameters['_launch']),
    );
  }

  static PlannerLaunchIntent fallbackForRoute(String route) {
    return PlannerLaunchIntent(route: route);
  }

  String get routeLocation {
    final params = <String, String>{
      if (openDayCard) 'openDayCard': '1',
      if (source != null) 'source': source!,
      if (localDate != null) 'date': _formatLocalDate(localDate!),
      if (timezone != null) 'tz': timezone!,
      if (launchToken != null) '_launch': launchToken!,
    };

    return Uri(
      path: canonicalRoute,
      queryParameters: params.isEmpty ? null : params,
    ).toString();
  }

  String get sessionLocation => route;

  Map<String, String> get telemetryParameters => <String, String>{
    'route': route,
    if (openDayCard) 'open_day_card': '1',
    if (source != null) 'source': source!,
    if (localDate != null) 'date': _formatLocalDate(localDate!),
    if (timezone != null) 'tz': timezone!,
  };

  PlannerLaunchIntent withLaunchToken(String token) {
    return PlannerLaunchIntent(
      route: route,
      openDayCard: openDayCard,
      localDate: localDate,
      timezone: timezone,
      source: source,
      launchToken: _nonEmpty(token),
    );
  }

  static String _formatLocalDate(DateTime value) {
    final local = DateTime(value.year, value.month, value.day);
    return [
      local.year.toString().padLeft(4, '0'),
      local.month.toString().padLeft(2, '0'),
      local.day.toString().padLeft(2, '0'),
    ].join('-');
  }

  static String? _plannerRouteFor(Uri uri) {
    final path = uri.path.isEmpty ? '/' : uri.path;
    if (path == '/rhythm/today' || path == '/rhythm/todo') {
      return path;
    }

    final host = uri.host.toLowerCase();
    final segments = uri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);

    if (host == 'rhythm' && segments.length == 1) {
      final first = segments.first.toLowerCase();
      if (first == 'today' || first == 'todo') {
        return '/rhythm/$first';
      }
    }

    return null;
  }

  static bool _isTruthy(String? raw) {
    final value = raw?.trim().toLowerCase();
    return value == '1' || value == 'true' || value == 'yes';
  }

  static DateTime? _parseLocalDate(String? raw) {
    final value = _nonEmpty(raw);
    if (value == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      return null;
    }

    final parsed = DateTime.tryParse(value);
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  static String? _nonEmpty(String? raw) {
    final value = raw?.trim();
    return value == null || value.isEmpty ? null : value;
  }
}
