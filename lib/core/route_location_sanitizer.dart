String? stableRouteLocationForContinuity(String? location) {
  final normalized = location?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }

  final uri = Uri.tryParse(normalized);
  if (uri == null ||
      uri.hasScheme ||
      uri.host.isNotEmpty ||
      uri.path.isEmpty ||
      !uri.path.startsWith('/')) {
    return null;
  }

  final nextQuery = Map<String, String>.from(uri.queryParameters);
  final path = uri.path;

  if (path.startsWith('/nodes/')) {
    nextQuery.remove('action');
    nextQuery.remove('insight');
  }

  if (path.startsWith('/rhythm/')) {
    nextQuery.remove('openDayCard');
    nextQuery.remove('open_day_card');
    nextQuery.remove('source');
    nextQuery.remove('date');
    nextQuery.remove('tz');
  }

  nextQuery.remove('_launch');

  return Uri(
    path: path,
    queryParameters: nextQuery.isEmpty ? null : nextQuery,
  ).toString();
}

bool routeLocationContainsOneShotIntent(String? location) {
  final normalized = location?.trim();
  if (normalized == null || normalized.isEmpty) {
    return false;
  }
  final uri = Uri.tryParse(normalized);
  if (uri == null) return false;

  final params = uri.queryParameters;
  if (uri.path.startsWith('/nodes/')) {
    final action = params['action']?.trim();
    final insight = params['insight']?.trim();
    if (action == 'add_insight' || insight == 'new') {
      return true;
    }
  }
  if (uri.path.startsWith('/rhythm/')) {
    if (_isTruthy(params['openDayCard']) ||
        _isTruthy(params['open_day_card']) ||
        params.containsKey('_launch')) {
      return true;
    }
  }
  return false;
}

bool _isTruthy(String? raw) {
  final value = raw?.trim().toLowerCase();
  return value == '1' || value == 'true' || value == 'yes';
}
