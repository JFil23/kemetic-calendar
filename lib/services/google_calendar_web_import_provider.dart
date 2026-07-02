import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'calendar_sync_service.dart';

const googleCalendarImportProviderName = 'google_calendar';

const googleCalendarReadOnlyScopes = <String>[
  'https://www.googleapis.com/auth/calendar.calendarlist.readonly',
  'https://www.googleapis.com/auth/calendar.events.readonly',
];

const googleCalendarReadOnlyScopeString =
    'https://www.googleapis.com/auth/calendar.calendarlist.readonly '
    'https://www.googleapis.com/auth/calendar.events.readonly';

const _providerTokenWait = Duration(seconds: 12);
const _providerTokenPoll = Duration(milliseconds: 250);

@visibleForTesting
bool googleCalendarScopesAreReadOnly(Iterable<String> scopes) {
  final scopeSet = scopes.map((scope) => scope.trim()).toSet();
  return scopeSet.isNotEmpty &&
      scopeSet.containsAll(googleCalendarReadOnlyScopes) &&
      scopeSet.every((scope) => scope.endsWith('.readonly'));
}

class GoogleCalendarWebImportProvider implements CalendarWebImportProvider {
  GoogleCalendarWebImportProvider(
    this._client, {
    http.Client? httpClient,
    DateTime Function()? now,
  }) : _http = httpClient ?? http.Client(),
       _now = now ?? DateTime.now;

  final SupabaseClient _client;
  final http.Client _http;
  final DateTime Function() _now;

  static const _calendarListEndpoint =
      'https://www.googleapis.com/calendar/v3/users/me/calendarList';

  @override
  Future<bool> hasReadAccess() => _waitForProviderToken();

  @override
  Future<bool> requestReadAccess({required String redirectTo}) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;

    final usesGoogleIdentity = _currentUserHasGoogleIdentity(user);
    final queryParams = <String, String>{
      'include_granted_scopes': 'true',
      'prompt': 'consent',
    };

    if (usesGoogleIdentity) {
      return _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectTo,
        scopes: googleCalendarReadOnlyScopeString,
        queryParams: queryParams,
      );
    }

    return _client.auth.linkIdentity(
      OAuthProvider.google,
      redirectTo: redirectTo,
      scopes: googleCalendarReadOnlyScopeString,
      queryParams: queryParams,
    );
  }

  @override
  Future<List<NativeCalendarEvent>> fetchEvents(
    DateTime start,
    DateTime end,
  ) async {
    await _waitForProviderToken();
    final token = _providerToken();
    if (token == null || token.isEmpty) {
      throw const CalendarWebAuthorizationRequiredException(
        'missing provider token',
      );
    }

    final calendars = await _fetchCalendars(token);
    final events = <NativeCalendarEvent>[];

    for (final calendar in calendars) {
      try {
        events.addAll(await _fetchCalendarEvents(token, calendar, start, end));
      } on CalendarWebAuthorizationRequiredException {
        rethrow;
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
            '[calendar-sync] skipped a Google calendar import page: '
            '${_safeError(e)}',
          );
        }
      }
    }

    if (kDebugMode) {
      debugPrint(
        '[calendar-sync] Google Calendar import fetched ${events.length} events',
      );
    }
    return events;
  }

  String? _providerToken() {
    final token = _client.auth.currentSession?.providerToken?.trim();
    return token == null || token.isEmpty ? null : token;
  }

  Future<bool> _waitForProviderToken() async {
    if (_providerToken() != null) return true;

    final stopwatch = Stopwatch()..start();
    while (stopwatch.elapsed < _providerTokenWait) {
      await Future<void>.delayed(_providerTokenPoll);
      if (_providerToken() != null) {
        if (kDebugMode) {
          debugPrint('[calendar-sync] Google provider token available');
        }
        return true;
      }
    }

    if (kDebugMode) {
      debugPrint('[calendar-sync] Google provider token missing');
    }
    return false;
  }

  Future<List<_GoogleCalendarRef>> _fetchCalendars(String token) async {
    final calendars = <_GoogleCalendarRef>[];
    String? pageToken;

    do {
      final uri = Uri.parse(_calendarListEndpoint).replace(
        queryParameters: <String, String>{
          'showDeleted': 'false',
          'showHidden': 'false',
          'minAccessRole': 'reader',
          if (pageToken != null) 'pageToken': pageToken,
        },
      );
      final decoded = await _getJson(token, uri);
      final items = decoded['items'];
      if (items is List) {
        for (final item in items.whereType<Map>()) {
          final id = item['id']?.toString().trim();
          if (id == null || id.isEmpty) continue;
          calendars.add(
            _GoogleCalendarRef(id: id, timeZone: item['timeZone']?.toString()),
          );
        }
      }
      pageToken = decoded['nextPageToken']?.toString();
    } while (pageToken != null && pageToken.isNotEmpty);

    if (kDebugMode) {
      debugPrint(
        '[calendar-sync] Google Calendar import found ${calendars.length} calendars',
      );
    }
    return calendars;
  }

  Future<List<NativeCalendarEvent>> _fetchCalendarEvents(
    String token,
    _GoogleCalendarRef calendar,
    DateTime start,
    DateTime end,
  ) async {
    final events = <NativeCalendarEvent>[];
    String? pageToken;

    do {
      final uri = Uri.https(
        'www.googleapis.com',
        '/calendar/v3/calendars/${Uri.encodeComponent(calendar.id)}/events',
        <String, String>{
          'singleEvents': 'true',
          'orderBy': 'startTime',
          'showDeleted': 'false',
          'timeMin': start.toUtc().toIso8601String(),
          'timeMax': end.toUtc().toIso8601String(),
          'maxResults': '2500',
          if (pageToken != null) 'pageToken': pageToken,
        },
      );
      final decoded = await _getJson(token, uri);
      final items = decoded['items'];
      if (items is List) {
        for (final item in items.whereType<Map>()) {
          final event = _eventFromGoogle(
            calendar,
            item.cast<String, dynamic>(),
          );
          if (event != null) events.add(event);
        }
      }
      pageToken = decoded['nextPageToken']?.toString();
    } while (pageToken != null && pageToken.isNotEmpty);

    return events;
  }

  Future<Map<String, dynamic>> _getJson(String token, Uri uri) async {
    final response = await _http
        .get(uri, headers: {'authorization': 'Bearer $token'})
        .timeout(const Duration(seconds: 20));

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw CalendarWebAuthorizationRequiredException(
        'Google Calendar read access was not granted or expired',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Google Calendar API returned HTTP ${response.statusCode}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Unexpected Google Calendar response');
    }
    return decoded;
  }

  NativeCalendarEvent? _eventFromGoogle(
    _GoogleCalendarRef calendar,
    Map<String, dynamic> raw,
  ) {
    if (raw['status'] == 'cancelled') return null;

    final id = raw['id']?.toString().trim();
    final fallbackId = raw['iCalUID']?.toString().trim();
    final identity = id?.isNotEmpty == true ? id! : fallbackId;
    if (identity == null || identity.isEmpty) return null;

    final startRaw = raw['start'];
    final endRaw = raw['end'];
    if (startRaw is! Map || endRaw is! Map) return null;

    final start = _parseGoogleDateTime(startRaw.cast<String, dynamic>());
    if (start == null) return null;
    final end = _parseGoogleDateTime(endRaw.cast<String, dynamic>());
    final allDay = startRaw['date'] != null;

    return NativeCalendarEvent(
      nativeId: _privacyHash('${calendar.id}|$identity'),
      title: raw['summary']?.toString().trim().isNotEmpty == true
          ? raw['summary'].toString().trim()
          : 'Untitled external event',
      description: raw['description']?.toString(),
      location: raw['location']?.toString(),
      allDay: allDay,
      start: start,
      end: end,
      calendarId: 'google:${_privacyHash(calendar.id)}',
      timeZone:
          startRaw['timeZone']?.toString() ??
          endRaw['timeZone']?.toString() ??
          calendar.timeZone,
      lastModified:
          DateTime.tryParse(raw['updated']?.toString() ?? '') ?? _now(),
      clientEventId: null,
      source: 'google-web',
    );
  }

  DateTime? _parseGoogleDateTime(Map<String, dynamic> raw) {
    final dateTime = raw['dateTime']?.toString();
    if (dateTime != null && dateTime.isNotEmpty) {
      return DateTime.tryParse(dateTime);
    }

    final date = raw['date']?.toString();
    if (date == null || date.isEmpty) return null;
    final parts = date.split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    return DateTime(year, month, day);
  }

  bool _currentUserHasGoogleIdentity(User user) {
    final provider = user.appMetadata['provider']?.toString().toLowerCase();
    if (provider == 'google') return true;

    final providers = user.appMetadata['providers'];
    if (providers is Iterable &&
        providers.any((entry) => entry.toString().toLowerCase() == 'google')) {
      return true;
    }

    return user.identities?.any(
          (identity) => identity.provider.toLowerCase() == 'google',
        ) ??
        false;
  }
}

class _GoogleCalendarRef {
  const _GoogleCalendarRef({required this.id, this.timeZone});

  final String id;
  final String? timeZone;
}

String _safeError(Object error) {
  final text = error.toString();
  return text.replaceAll(
    RegExp(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'),
    '<redacted-email>',
  );
}

String _privacyHash(String value) {
  final bytes = utf8.encode(value);
  final left = _fnv32(bytes, seed: 0x811c9dc5);
  final right = _fnv32(bytes.reversed.toList(), seed: 0x01000193);
  return '${left.toRadixString(16).padLeft(8, '0')}'
      '${right.toRadixString(16).padLeft(8, '0')}';
}

int _fnv32(List<int> bytes, {required int seed}) {
  var hash = seed;
  for (final byte in bytes) {
    hash ^= byte;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash;
}
