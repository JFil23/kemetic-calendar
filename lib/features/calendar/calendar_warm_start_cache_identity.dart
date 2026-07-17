import 'package:supabase_flutter/supabase_flutter.dart';

const int calendarWarmStartCacheSchemaVersion = 4;
const String calendarWarmStartCacheKeyPrefix = 'calendar:warm_start:v4';

String? calendarWarmStartProjectRefFromClient(SupabaseClient client) {
  const restSuffix = '/rest/v1';
  final restUrl = client.rest.url.trim();
  final baseUrl = restUrl.endsWith(restSuffix)
      ? restUrl.substring(0, restUrl.length - restSuffix.length)
      : restUrl;
  return calendarWarmStartProjectRefFromUrl(baseUrl);
}

String? calendarWarmStartProjectRefFromUrl(String? rawUrl) {
  final value = rawUrl?.trim();
  if (value == null || value.isEmpty) return null;

  final uri = Uri.tryParse(value);
  if (uri == null || !uri.hasScheme || uri.host.trim().isEmpty) {
    return null;
  }

  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'https' && scheme != 'http') return null;

  final host = uri.host.toLowerCase();
  if (host.endsWith('.supabase.co')) {
    final firstLabel = host.split('.').first.trim();
    return _safeCacheIdentity(firstLabel);
  }

  if (_isLocalSupabaseHost(host)) {
    final port = uri.hasPort ? uri.port : (scheme == 'https' ? 443 : 80);
    return _safeCacheIdentity('local_${host}_$port');
  }

  // Supabase supports custom domains, and isolated release validation uses a
  // short-lived HTTPS proxy in front of the same API. The browser origin is a
  // stable, non-secret namespace for that backend; refusing it disables the
  // same-process and durable Calendar snapshot authorities entirely.
  final port = uri.hasPort ? uri.port : (scheme == 'https' ? 443 : 80);
  return _safeCacheIdentity('custom_${scheme}_${host}_$port');
}

String? calendarWarmStartCacheKey({
  required String? projectRef,
  required String? userId,
}) {
  final safeProjectRef = _safeCacheIdentity(projectRef);
  final safeUserId = userId?.trim();
  if (safeProjectRef == null || safeUserId == null || safeUserId.isEmpty) {
    return null;
  }
  return '$calendarWarmStartCacheKeyPrefix:$safeProjectRef:$safeUserId';
}

String? calendarWarmStartCacheKeyForClient({
  required SupabaseClient client,
  required String? userId,
}) {
  return calendarWarmStartCacheKey(
    projectRef: calendarWarmStartProjectRefFromClient(client),
    userId: userId,
  );
}

String? calendarWarmStartCacheKeyForUrl({
  required String? supabaseUrl,
  required String? userId,
}) {
  return calendarWarmStartCacheKey(
    projectRef: calendarWarmStartProjectRefFromUrl(supabaseUrl),
    userId: userId,
  );
}

bool _isLocalSupabaseHost(String host) {
  return host == 'localhost' || host == '127.0.0.1' || host == '::1';
}

String? _safeCacheIdentity(String? value) {
  final raw = value?.trim().toLowerCase();
  if (raw == null || raw.isEmpty) return null;
  final safe = raw
      .replaceAll(RegExp(r'[^a-z0-9_-]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  return safe.isEmpty ? null : safe;
}
