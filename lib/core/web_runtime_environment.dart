import 'dart:convert';

import 'package:http/http.dart' as http;

import 'supabase_runtime_config_guard.dart';

/// Named release builds already contain their validated public configuration.
/// Only incomplete/legacy inputs need the runtime fallback request.
bool needsWebRuntimeEnvironment({
  required String url,
  required String anonKey,
  required String appEnvironment,
  required String appSiteUrl,
}) {
  final site = Uri.tryParse(appSiteUrl.trim());
  return !hasValidSupabaseRuntimeConfig(url, anonKey) ||
      !const {
        'prod',
        'staging',
      }.contains(appEnvironment.trim().toLowerCase()) ||
      site == null ||
      site.scheme != 'https' ||
      site.host.isEmpty ||
      looksLikeRuntimePlaceholder(appSiteUrl.toLowerCase()) ||
      appSiteUrl.trim() == 'https://maat.app';
}

Future<Map<String, String>> loadWebRuntimeEnvironment(
  Uri uri, {
  http.Client? client,
  Duration timeout = const Duration(seconds: 4),
}) async {
  final requestClient = client ?? http.Client();
  try {
    final response = await requestClient.get(uri).timeout(timeout);
    if (response.statusCode != 200) return const {};
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return const {};
    return decoded.map((key, value) {
      return MapEntry(key, value is String ? value.trim() : '');
    })..removeWhere((_, value) => value.isEmpty);
  } catch (_) {
    // The caller still validates the resolved configuration before auth starts.
    return const {};
  } finally {
    requestClient.close();
  }
}
