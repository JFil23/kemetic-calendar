import 'package:shared_preferences/shared_preferences.dart';

/// Device presentation preferences, independent of account content and warm
/// eviction. The pending location is a navigation intent, never a queued write.
class VisitorPreferences {
  static const introSeenKey = 'visitor_experience_v1:intro_seen';
  static const invitationSeenKey = 'visitor_experience_v1:invitation_seen';
  static const pendingLocationKey = 'visitor_experience_v1:pending_location';

  static final Map<String, Object> _fallback = {};

  Future<bool> _seen(String key) async {
    try {
      return (await SharedPreferences.getInstance()).getBool(key) ?? false;
    } catch (_) {
      return _fallback[key] == true;
    }
  }

  Future<bool> introSeen() => _seen(introSeenKey);
  Future<bool> invitationSeen() => _seen(invitationSeenKey);
  Future<String?> pendingLocation() async {
    try {
      return safeVisitorLocation(
        (await SharedPreferences.getInstance()).getString(pendingLocationKey),
      );
    } catch (_) {
      return safeVisitorLocation(_fallback[pendingLocationKey] as String?);
    }
  }

  Future<void> _write(String key, Object value) async {
    _fallback[key] = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value is bool) {
        await prefs.setBool(key, value);
      } else {
        await prefs.setString(key, value as String);
      }
    } catch (_) {
      /* Browsing still works if this browser disallows storage. */
    }
  }

  Future<void> markIntroSeen() => _write(introSeenKey, true);
  Future<void> markInvitationSeen() => _write(invitationSeenKey, true);
  Future<void> rememberLocation(String location) async {
    final safe = safeVisitorLocation(location);
    if (safe != null) {
      await _write(pendingLocationKey, safe);
    }
  }

  Future<void> clearLocation() async {
    _fallback.remove(pendingLocationKey);
    try {
      await (await SharedPreferences.getInstance()).remove(pendingLocationKey);
    } catch (_) {
      /* No account content or pending writes are held here. */
    }
  }
}

String? safeVisitorLocation(String? location) {
  final uri = Uri.tryParse(location ?? '');
  if (uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      !uri.path.startsWith('/') ||
      uri.path.startsWith('//') ||
      uri.fragment.isNotEmpty)
    return null;
  // Never retain authentication tokens, recovery commands or another invitation.
  if (uri.queryParameters.keys.any(
    (key) => {
      'account',
      'code',
      'access_token',
      'refresh_token',
      'error',
      'type',
    }.contains(key),
  ))
    return null;
  // These existing share entry owners require their invitation capability.
  // It is distinct from a login token and still verified by ShareRepo.
  if (uri.queryParameters.containsKey('token') &&
      !(RegExp(r'^/share/[^/]+$').hasMatch(uri.path) ||
          (uri.path == '/inbox' &&
              uri.queryParameters['share']?.isNotEmpty == true)))
    return null;
  return uri.toString();
}

/// Audited presentation/editor routes use their canonical null-account owners.
/// Saved private record and invitation-capability routes keep their boundaries.
bool isGuestBrowseLocation(Uri uri) {
  if (uri.path == '/' || uri.path == '/pages') return true;
  if (uri.path == '/nodes') return true;
  if ({
    '/calendars',
    '/profile/me',
    '/profile/me/edit',
    '/profile/flow-post-picker',
    '/profile/insight-post-picker',
    '/profile-search',
    '/rhythm/today',
    '/rhythm/todo',
    '/rhythm/editor/timed',
    '/rhythm/editor/untimed',
  }.contains(uri.path))
    return true;
  if (uri.path == '/inbox' && !uri.queryParameters.containsKey('share'))
    return true;
  if (RegExp(r'^/inbox/(conversation|dm)/[^/]+$').hasMatch(uri.path))
    return true;
  if (RegExp(r'^/nodes/[^/]+$').hasMatch(uri.path)) {
    // New insight entry uses no account-owned source identity.
    return uri.queryParameters['action'] != 'add_insight' &&
            uri.queryParameters['insight'] != 'new' ||
        uri.queryParameters.keys.every({'action', 'insight'}.contains);
  }
  if (uri.path == '/flows') {
    return uri.queryParameters['flow'] == null &&
        {
          null,
          'maatFlows',
          'maatTemplate',
          'myFlows',
        }.contains(uri.queryParameters['mode']);
  }
  return false;
}

String? guestAccountRedirect(Uri uri, {required bool signedIn}) {
  if (signedIn || isGuestBrowseLocation(uri)) return null;
  final safe = safeVisitorLocation(uri.toString());
  return Uri(
    path: '/pages',
    queryParameters: safe == null ? null : {'account': safe},
  ).toString();
}
