import '../services/restoration_trace.dart';

String? stableRouteLocationForContinuity(String? location) {
  final normalized = location?.trim();
  if (normalized == null || normalized.isEmpty) {
    traceRestoration(
      'sanitize input=${_traceValue(location)} output=<null> '
      'reason=empty durable=false transient=false',
    );
    return null;
  }

  final uri = Uri.tryParse(normalized);
  if (uri == null ||
      uri.hasScheme ||
      uri.host.isNotEmpty ||
      uri.path.isEmpty ||
      !uri.path.startsWith('/')) {
    traceRestoration(
      'sanitize input=${_traceValue(location)} output=<null> '
      'reason=invalid_internal_route durable=false transient=true',
    );
    return null;
  }

  final nextQuery = Map<String, String>.from(uri.queryParameters);
  final path = uri.path;

  if (_isFlowEditorRoute(uri)) {
    final fallback = _flowEditorContinuityFallback(uri);
    traceRestoration(
      'sanitize input=$normalized output=$fallback '
      'reason=flow_editor_fallback durable=true transient=true',
    );
    return fallback;
  }

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

  final output = Uri(
    path: path,
    queryParameters: nextQuery.isEmpty ? null : nextQuery,
  ).toString();
  traceRestoration(
    'sanitize input=$normalized output=$output '
    'reason=${output == normalized ? 'unchanged' : 'stripped_one_shot'} '
    'durable=true transient=${output == normalized ? 'false' : 'true'}',
  );
  return output;
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
  if (_isFlowEditorRoute(uri)) {
    return true;
  }
  return false;
}

bool _isFlowEditorRoute(Uri uri) {
  final segments = uri.pathSegments;
  return segments.length == 3 &&
      segments[0] == 'flows' &&
      int.tryParse(segments[1]) != null &&
      segments[2] == 'edit';
}

String _flowEditorContinuityFallback(Uri uri) {
  final flowId = int.tryParse(uri.pathSegments[1]);
  final rawFallback = uri.queryParameters['fallback']?.trim();
  if (rawFallback != null && rawFallback.isNotEmpty) {
    final fallbackUri = Uri.tryParse(rawFallback);
    if (fallbackUri != null &&
        _isInternalAppUri(fallbackUri) &&
        !_isFlowEditorRoute(fallbackUri)) {
      return stableRouteLocationForContinuity(rawFallback) ?? '/';
    }
  }
  if (flowId != null && flowId > 0) {
    return '/shared-flow/by-flow/$flowId';
  }
  return '/';
}

bool _isInternalAppUri(Uri uri) {
  return !uri.hasScheme &&
      uri.host.isEmpty &&
      uri.path.isNotEmpty &&
      uri.path.startsWith('/');
}

bool _isTruthy(String? raw) {
  final value = raw?.trim().toLowerCase();
  return value == '1' || value == 'true' || value == 'yes';
}

String _traceValue(String? raw) {
  final value = raw?.trim();
  return value == null || value.isEmpty ? '<empty>' : value;
}
