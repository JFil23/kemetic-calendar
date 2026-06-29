const Set<String> localSupabaseHosts = {'localhost', '127.0.0.1', '10.0.2.2'};

const int localSupabasePort = 54321;

class SupabaseRuntimeConfig {
  const SupabaseRuntimeConfig({
    required this.url,
    required this.anonKey,
    required this.appEnvironment,
    required this.appSiteUrl,
    required this.nativeAuthRedirectUrl,
  });

  final String url;
  final String anonKey;
  final String appEnvironment;
  final String appSiteUrl;
  final String nativeAuthRedirectUrl;
}

bool hasValidSupabaseRuntimeConfig(String url, String anonKey) {
  return hasValidSupabaseUrl(url) && hasValidSupabaseAnonKey(anonKey);
}

bool hasValidSupabaseUrl(String url) {
  final normalized = url.trim();
  final parsed = Uri.tryParse(normalized);
  return normalized.isNotEmpty &&
      parsed != null &&
      parsed.scheme == 'https' &&
      parsed.host.endsWith('.supabase.co') &&
      !looksLikeRuntimePlaceholder(normalized.toLowerCase());
}

bool hasAllowedLocalSupabaseUrl(String url) {
  final normalized = url.trim();
  final parsed = Uri.tryParse(normalized);
  return normalized.isNotEmpty &&
      parsed != null &&
      parsed.scheme == 'http' &&
      localSupabaseHosts.contains(parsed.host.toLowerCase()) &&
      parsed.hasPort &&
      parsed.port == localSupabasePort &&
      (parsed.path.isEmpty || parsed.path == '/') &&
      !parsed.hasQuery &&
      !parsed.hasFragment;
}

bool hasValidSupabaseAnonKey(String anonKey) {
  final normalized = anonKey.trim();
  final lower = normalized.toLowerCase();
  return normalized.length > 20 &&
      !looksLikeRuntimePlaceholder(lower) &&
      !lower.contains('service_role') &&
      !lower.contains('service-role');
}

List<String> supabaseRuntimeConfigErrors(
  SupabaseRuntimeConfig config, {
  required bool allowLocalSupabase,
  required bool debugMode,
  required bool releaseMode,
  required bool profileMode,
}) {
  final errors = <String>[];
  final url = config.url.trim();
  final anonKey = config.anonKey.trim();
  final envName = config.appEnvironment.trim().toLowerCase();
  final siteUrl = config.appSiteUrl.trim();
  final nativeRedirect = Uri.tryParse(config.nativeAuthRedirectUrl);

  if (url.isEmpty) {
    errors.add('SUPABASE_URL is missing.');
  } else if (hasValidSupabaseUrl(url)) {
    // Valid production/staging Supabase project URL.
  } else if (hasAllowedLocalSupabaseUrl(url)) {
    if (!allowLocalSupabase) {
      errors.add('SUPABASE_URL must be a real https://*.supabase.co URL.');
    } else if (!debugMode || releaseMode || profileMode) {
      errors.add('ALLOW_LOCAL_SUPABASE is only available in debug builds.');
    }
  } else {
    errors.add('SUPABASE_URL must be a real https://*.supabase.co URL.');
  }

  final lowerAnon = anonKey.toLowerCase();
  if (anonKey.length <= 20) {
    errors.add('SUPABASE_ANON_KEY is missing or too short.');
  } else if (looksLikeRuntimePlaceholder(lowerAnon)) {
    errors.add('SUPABASE_ANON_KEY still looks like a placeholder.');
  } else if (lowerAnon.contains('service_role') ||
      lowerAnon.contains('service-role')) {
    errors.add('SUPABASE_ANON_KEY must not be a service role key.');
  }

  if (envName.isEmpty) {
    errors.add('APP_ENV is missing.');
  } else if (!const {'dev', 'staging', 'prod'}.contains(envName)) {
    errors.add('APP_ENV must be one of dev, staging, or prod.');
  }

  if ((releaseMode || profileMode) && envName == 'dev') {
    errors.add('Release/profile builds must set APP_ENV to staging or prod.');
  }

  final site = Uri.tryParse(siteUrl);
  if (siteUrl.isEmpty ||
      site == null ||
      site.scheme != 'https' ||
      site.host.isEmpty ||
      looksLikeRuntimePlaceholder(siteUrl.toLowerCase())) {
    errors.add('APP_SITE_URL must be a real https URL.');
  }

  if (nativeRedirect == null ||
      nativeRedirect.scheme != 'kemet.app' ||
      nativeRedirect.host != 'login-callback') {
    errors.add('Native auth redirect must remain kemet.app://login-callback.');
  }

  return errors;
}

bool looksLikeRuntimePlaceholder(String value) {
  return value.contains('your-') ||
      value.contains('your_') ||
      value.contains('your_project') ||
      value.contains('placeholder') ||
      value.contains('example') ||
      value.contains('change-me');
}
