import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/shared/glossy_text.dart';

import '../../core/navigation_fallback.dart';
import '../../core/navigation_persistence_policy.dart';
import '../../main.dart' show Events, appEnvironmentEnv;
import '../../services/navigation_trace.dart';
import '../../services/device_calendar_controller.dart';
import '../../services/push_notifications.dart';
import '../../services/speech/speech_service.dart';
import '../../utils/external_link_utils.dart';
import '../calendar/calendar_page.dart';
import '../calendar/calendar_hydration_diagnostics.dart';
import '../calendar/notify.dart';
import 'speech_settings_card.dart';
import 'package:mobile/features/onboarding/guided_onboarding_overlay.dart';
import '../onboarding/onboarding_progress.dart';
import 'settings_prefs.dart';
import 'external_calendar_settings.dart';
import 'device_calendar_settings.dart';
import 'us_holiday_seeder.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, this.externalCalendarCallbackResult});

  final String? externalCalendarCallbackResult;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsBuildInfo {
  const _SettingsBuildInfo({
    required this.appVersion,
    required this.appEnvironment,
    required this.webBuildVersion,
    required this.buildTimestamp,
  });

  static const unavailable = _SettingsBuildInfo(
    appVersion: '1.0.0+1',
    appEnvironment: appEnvironmentEnv,
    webBuildVersion: 'unavailable',
    buildTimestamp: 'unavailable',
  );

  final String appVersion;
  final String appEnvironment;
  final String webBuildVersion;
  final String buildTimestamp;
}

class _SettingsPageState extends State<SettingsPage> {
  void _consumeExternalCalendarCallback(String result) {
    // The child acknowledges in its post-frame callback, after loading allows
    // it to mount. Do not schedule another frame just to remove this query.
    if (!mounted) return;
    final router = GoRouter.of(context);
    final uri = router.routeInformationProvider.value.uri;
    if (uri.path != '/settings' ||
        uri.queryParameters['external_calendar'] != result) {
      return;
    }
    final remaining = Map<String, List<String>>.from(uri.queryParametersAll)
      ..remove('external_calendar');
    router.replace(uri.replace(queryParameters: remaining).toString());
  }

  static const String _speechPreviewUtteranceId = 'settings:speech-preview';
  static const String _privacyPolicyUrl = 'https://haw-info.pages.dev/privacy';
  static const String _termsUrl = 'https://haw-info.pages.dev/terms';
  static const String _supportUrl = 'https://haw-info.pages.dev/support';
  static const String _lastPushTestDeliveryKeyPref =
      'push.lastSelfTestDeliveryKey';

  bool _realTimeAlerts = false;
  bool _usHolidaysEnabled = false;
  bool _dailyCosmicContextBadgeEnabled = true;
  bool _savingDailyCosmicContextBadge = false;
  bool _seedingHolidays = false;
  bool _loading = true;
  bool _requestingPush = false;
  bool _loadingPushDiagnostics = false;
  bool _sendingPushTest = false;
  bool _checkingPushTestReceipt = false;
  bool _signingOut = false;
  bool _replayingOnboarding = false;
  int _buildMarkerTapCount = 0;
  Timer? _buildMarkerTapResetTimer;
  bool _loadingSpeechVoices = false;
  bool _savingSpeechVoice = false;
  bool _deletingAccount = false;
  bool _settingsHelperPrompted = false;
  String? _pushStatus;
  String? _pushTestDeliveryKey;
  String? _speechVoiceStatus;
  String? _accountStatus;
  Future<void>? _hydrationDiagnosticsReady;
  _SettingsBuildInfo _buildInfo = _SettingsBuildInfo.unavailable;
  PushRegistrationDiagnostics? _pushDiagnostics;
  PushDeliveryReceiptStatus? _pushTestReceiptStatus;
  SpeechVoiceOption _selectedSpeechVoice = SpeechVoiceOption.g;
  final GlobalKey _settingsControlsHelperKey = GlobalKey(
    debugLabel: 'settings_controls_helper',
  );

  bool get _hasSession => Supabase.instance.client.auth.currentSession != null;

  Future<void> _replayOnboarding() async {
    final owner = Supabase.instance.client.auth.currentUser?.id;
    if (_replayingOnboarding || owner == null) return;
    setState(() => _replayingOnboarding = true);
    try {
      final storage = OnboardingProgressStorage();
      final progress = await storage.load(owner);
      if (!mounted || owner != Supabase.instance.client.auth.currentUser?.id) {
        return;
      }
      await storage.saveRequired(owner, progress.restartForReplay());
      if (!mounted || owner != Supabase.instance.client.auth.currentUser?.id) {
        return;
      }
      openPrimarySection(context, AppSection.calendar);
      await CalendarPage.presentRequestedOnboarding();
    } catch (_) {
      if (mounted && owner == Supabase.instance.client.auth.currentUser?.id) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not restart onboarding. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _replayingOnboarding = false);
    }
  }

  void _showReflectionBadge() {
    openPrimarySection(context, AppSection.calendar);
    unawaited(CalendarPage.presentRequestedReflectionBadge());
  }

  Future<void> _signOut() async {
    if (_signingOut) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _signingOut = true;
    });

    try {
      final previousUserId = Supabase.instance.client.auth.currentUser?.id;
      await Supabase.instance.client.auth.signOut();
      await CalendarHydrationDiagnostics.instance.clearForAccountChange(
        previousUserId: previousUserId,
      );
      if (!mounted) return;

      context.go('/');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _signingOut = false;
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not sign out. Please try again.')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    SettingsPrefs.dailyCosmicContextBadgeChanges.addListener(
      _reloadDailyCosmicContextPreference,
    );
    _hydrationDiagnosticsReady = _prepareHydrationDiagnostics();
    _load();
    unawaited(_loadSpeechSettings());
    unawaited(_loadBuildInfo());
  }

  Future<void> _prepareHydrationDiagnostics() async {
    await CalendarHydrationDiagnostics.instance.closeForNavigation();
    await CalendarHydrationDiagnostics.instance.restoreLastCompletedForUser(
      Supabase.instance.client.auth.currentUser?.id,
    );
  }

  Future<void> _copyHydrationDiagnostics() async {
    await _hydrationDiagnosticsReady;
    final copied = await CalendarHydrationDiagnostics.instance
        .copyLastCompleted(exportedByBuild: _buildInfo.webBuildVersion);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          copied
              ? 'Hydration diagnostics copied.'
              : 'No completed hydration diagnostics yet.',
        ),
      ),
    );
  }

  @override
  void dispose() {
    SettingsPrefs.dailyCosmicContextBadgeChanges.removeListener(
      _reloadDailyCosmicContextPreference,
    );
    _buildMarkerTapResetTimer?.cancel();
    unawaited(
      SpeechService.instance.stop(utteranceId: _speechPreviewUtteranceId),
    );
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    await SettingsPrefs.clearLegacyReminderPrefs(prefs);

    if (!mounted) return;
    setState(() {
      _realTimeAlerts = SettingsPrefs.realTimeAlertsEnabledFrom(prefs);
      _usHolidaysEnabled = SettingsPrefs.usHolidaysEnabledFrom(prefs);
      _dailyCosmicContextBadgeEnabled =
          SettingsPrefs.dailyCosmicContextBadgeEnabledFrom(prefs);
      _pushTestDeliveryKey = prefs
          .getString(_lastPushTestDeliveryKeyPref)
          ?.trim();
      if (_pushTestDeliveryKey?.isEmpty == true) {
        _pushTestDeliveryKey = null;
      }
      _loading = false;
    });
    unawaited(_refreshPushDiagnostics());
    if (_pushTestDeliveryKey != null) {
      unawaited(_refreshPushTestReceiptStatus());
    }
    unawaited(_maybeShowSettingsHelper());
  }

  Future<void> _maybeShowSettingsHelper() async {
    if (_settingsHelperPrompted) return;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) return;
    const helper = OnboardingHelperRegistry.settingsControl;
    final helperService = OnboardingHelperCompletionService.instance;
    if (!await helperService.shouldShowHelper(userId, helper.id)) {
      return;
    }
    _settingsHelperPrompted = true;
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    await helperService.hydrateUser(userId);
    if (!mounted || !helperService.shouldShowHelperSync(userId, helper.id)) {
      return;
    }
    GuidedOnboardingController.instance.show(
      CoachmarkTarget(
        key: _settingsControlsHelperKey,
        title: helper.title,
        body: helper.body,
        placement: CoachmarkPlacement.auto,
        variant: CoachmarkVariant.helperBubble,
        showDismissButton: true,
        dismissLabel: 'Got it',
        helperId: helper.id,
        helperUserId: userId,
        sourceWidget: helper.sourceWidget,
        onDismiss: () async {
          final completion = helperService.markHelperCompleted(
            userId,
            helper.id,
          );
          GuidedOnboardingController.instance.clear();
          await completion;
          await Events.trackIfAuthed(
            helper.analyticsEvent,
            const <String, dynamic>{},
          );
        },
      ),
    );
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(SettingsPrefs.realTimeAlertsKey, _realTimeAlerts);
    await prefs.setBool(SettingsPrefs.usHolidaysEnabledKey, _usHolidaysEnabled);
  }

  Future<void> _loadSpeechSettings() async {
    setState(() => _loadingSpeechVoices = true);
    try {
      final voice = await SpeechService.instance.getPreferredVoice();
      if (!mounted) return;
      setState(() {
        _selectedSpeechVoice = voice;
        _speechVoiceStatus = null;
      });
      unawaited(SpeechService.instance.prepareLibrary());
    } catch (e) {
      if (mounted) {
        setState(
          () => _speechVoiceStatus =
              'Voice settings could not load. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _loadingSpeechVoices = false);
    }
  }

  Future<void> _loadBuildInfo() async {
    final buildInfo = await _readBuildInfo();
    if (!mounted) return;
    setState(() {
      _buildInfo = buildInfo;
    });
    CalendarHydrationDiagnostics.instance.setBuildLabel(
      buildInfo.webBuildVersion,
    );
  }

  Future<_SettingsBuildInfo> _readBuildInfo() async {
    var webBuildVersion = 'native';
    String? webAppEnvironment;
    if (kIsWeb) {
      webBuildVersion = 'unavailable';
      try {
        final response = await http.get(Uri.base.resolve('version.json'));
        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            webBuildVersion = _safeBuildInfoValue(decoded['build_version']);
          }
        }
      } catch (_) {
        webBuildVersion = 'unavailable';
      }
      webAppEnvironment = await _readWebRuntimeAppEnvironment();
    }

    return _SettingsBuildInfo(
      appVersion: _SettingsBuildInfo.unavailable.appVersion,
      appEnvironment:
          webAppEnvironment ?? _safeBuildInfoValue(appEnvironmentEnv),
      webBuildVersion: webBuildVersion,
      buildTimestamp: _buildTimestampLabel(webBuildVersion),
    );
  }

  Future<String?> _readWebRuntimeAppEnvironment() async {
    try {
      final response = await http.get(Uri.base.resolve('env.json'));
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      final safeValue = _safeBuildInfoValue(decoded['APP_ENV']);
      return safeValue == 'unavailable' ? null : safeValue;
    } catch (_) {
      return null;
    }
  }

  String _safeBuildInfoValue(Object? raw) {
    final value = raw?.toString().trim() ?? '';
    if (value.isEmpty) return 'unavailable';
    final safe = RegExp(r'^[A-Za-z0-9._:+-]{1,96}$');
    return safe.hasMatch(value) ? value : 'unavailable';
  }

  String _buildTimestampLabel(String buildVersion) {
    final match = RegExp(r'(\d{14})$').firstMatch(buildVersion.trim());
    if (match == null) return 'unavailable';
    final raw = match.group(1)!;
    return '${raw.substring(0, 4)}-${raw.substring(4, 6)}-${raw.substring(6, 8)} '
        '${raw.substring(8, 10)}:${raw.substring(10, 12)}:${raw.substring(12, 14)} UTC';
  }

  void _handleBuildMarkerTap() {
    _buildMarkerTapResetTimer?.cancel();
    _buildMarkerTapCount += 1;
    if (_buildMarkerTapCount < 7) {
      _buildMarkerTapResetTimer = Timer(const Duration(seconds: 3), () {
        _buildMarkerTapCount = 0;
      });
      return;
    }

    _buildMarkerTapCount = 0;
    final enableTrace = !NavigationTrace.instance.enabled;
    unawaited(() async {
      await NavigationTrace.instance.setEnabled(enableTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enableTrace
                ? 'Navigation Trace enabled'
                : 'Navigation Trace disabled',
          ),
        ),
      );
    }());
  }

  Future<void> _setSpeechVoice(SpeechVoiceOption voice) async {
    if (_savingSpeechVoice) return;
    setState(() => _savingSpeechVoice = true);
    try {
      await SpeechService.instance.setPreferredVoice(voice);
      if (!mounted) return;
      setState(() {
        _selectedSpeechVoice = voice;
        _speechVoiceStatus = null;
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => _speechVoiceStatus =
              'Your voice choice could not be saved. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _savingSpeechVoice = false);
    }
  }

  Future<void> _previewSpeechVoice() async {
    final speech = SpeechService.instance;
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (speech.activeUtteranceId.value == _speechPreviewUtteranceId) {
        await speech.stop(utteranceId: _speechPreviewUtteranceId);
        return;
      }

      await speech.preview(utteranceId: _speechPreviewUtteranceId);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Speech preview is unavailable: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _setRealTimeAlerts(bool enabled) async {
    final client = Supabase.instance.client;
    final push = PushNotifications.instance(client);
    final messenger = ScaffoldMessenger.of(context);

    if (enabled && !_hasSession) {
      messenger.showSnackBar(
        SnackBar(
          content: const Text(
            'Sign in before enabling push alerts on this device.',
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    setState(() {
      _realTimeAlerts = enabled;
      _requestingPush = enabled;
      _pushStatus = enabled
          ? 'Requesting permission and linking this device for push alerts...'
          : 'Push alerts are off on this device.';
    });

    if (!enabled) {
      await _save();
      await push.unregister();
      await Notify.syncLocalDeliveryMode();
      if (!mounted) return;
      setState(() {
        _requestingPush = false;
      });
      await _refreshPushDiagnostics();
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Push alerts disabled on this device.'),
          backgroundColor: Colors.green.shade700,
        ),
      );
      return;
    }

    final token = await push.requestAndRegisterToken();
    if (!mounted) return;

    final success = token != null;
    final failureMessage =
        push.lastRegistrationError ??
        'Push permission was denied, Firebase is not configured, or the device token could not be created.';
    setState(() {
      _requestingPush = false;
      _realTimeAlerts = success;
      _pushStatus = success
          ? 'Push alerts are enabled for this device.'
          : failureMessage;
    });
    await _save();
    await Notify.syncLocalDeliveryMode();
    await _refreshPushDiagnostics();

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          success ? 'Push alerts enabled on this device.' : failureMessage,
        ),
        backgroundColor: success ? Colors.green.shade700 : Colors.red.shade700,
      ),
    );
  }

  Future<void> _refreshPushDiagnostics() async {
    if (!mounted) return;
    setState(() {
      _loadingPushDiagnostics = true;
    });

    final diagnostics = await PushNotifications.instance(
      Supabase.instance.client,
    ).getDiagnostics();

    if (!mounted) return;
    setState(() {
      _pushDiagnostics = diagnostics;
      _loadingPushDiagnostics = false;
    });
  }

  Future<void> _sendPushTest() async {
    if (!_hasSession) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _sendingPushTest = true;
      _pushStatus = 'Dispatching a test push through send_push...';
    });

    final result = await PushNotifications.instance(
      Supabase.instance.client,
    ).sendSelfTestPush();

    if (!mounted) return;
    if (result.ok && result.deliveryKey != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastPushTestDeliveryKeyPref, result.deliveryKey!);
    }
    if (!mounted) return;
    setState(() {
      _sendingPushTest = false;
      _pushStatus = result.message;
      if (result.deliveryKey != null) {
        _pushTestDeliveryKey = result.deliveryKey;
        _pushTestReceiptStatus = null;
      }
    });
    await _refreshPushDiagnostics();
    if (result.ok && result.deliveryKey != null) {
      unawaited(_pollPushTestReceiptStatus(result.deliveryKey!));
    }

    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.ok
            ? Colors.green.shade700
            : Colors.red.shade700,
      ),
    );
  }

  Future<void> _refreshPushTestReceiptStatus({String? deliveryKey}) async {
    final key = (deliveryKey ?? _pushTestDeliveryKey)?.trim();
    if (!_hasSession || key == null || key.isEmpty) return;
    if (mounted) {
      setState(() {
        _checkingPushTestReceipt = true;
      });
    }

    final status = await PushNotifications.instance(
      Supabase.instance.client,
    ).getDeliveryReceiptStatus(key);

    if (!mounted) return;
    setState(() {
      _checkingPushTestReceipt = false;
      _pushTestReceiptStatus = status;
    });
  }

  Future<void> _pollPushTestReceiptStatus(String deliveryKey) async {
    for (var attempt = 0; attempt < 8; attempt += 1) {
      if (!mounted || _pushTestDeliveryKey != deliveryKey) return;
      await _refreshPushTestReceiptStatus(deliveryKey: deliveryKey);
      if (!mounted || _pushTestReceiptStatus?.opened == true) return;
      await Future<void>.delayed(const Duration(seconds: 3));
    }
  }

  Future<void> _openExternalSupportTarget(String target) async {
    final opened = await launchExternalTarget(target, fallbackToMaps: false);
    if (!mounted || opened) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Could not open this link on this device.'),
        backgroundColor: Colors.red.shade700,
      ),
    );
  }

  Future<void> _deleteAccount() async {
    final client = Supabase.instance.client;
    final messenger = ScaffoldMessenger.of(context);

    if (!_hasSession) {
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Sign in before deleting your account.'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0C0C0C),
          title: const Text(
            'Delete Account?',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'This permanently deletes your account sign-in and account data. This cannot be undone.',
            style: TextStyle(color: Colors.white70, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete account'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _deletingAccount = true;
      _accountStatus = 'Deleting account...';
    });

    try {
      final response = await client.functions.invoke('delete_account');
      final data = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : (response.data is Map
                ? Map<String, dynamic>.from(response.data as Map)
                : <String, dynamic>{});

      if (response.status >= 400) {
        final message =
            data['error']?.toString() ??
            'Account deletion returned HTTP ${response.status}.';
        throw StateError(message);
      }

      await client.auth.signOut();
      if (!mounted) return;
      setState(() {
        _deletingAccount = false;
        _accountStatus = 'Account deleted.';
      });
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Account deleted.'),
          backgroundColor: Colors.green.shade700,
        ),
      );
      popOrGo(context, '/');
    } catch (e) {
      if (!mounted) return;
      final message = e is StateError
          ? e.message
          : 'Could not delete account: $e';
      setState(() {
        _deletingAccount = false;
        _accountStatus = message;
      });
      messenger.showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
      );
    }
  }

  Future<void> _toggleUsHolidays(bool enabled) async {
    final previous = _usHolidaysEnabled;
    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      _usHolidaysEnabled = enabled;
      _seedingHolidays = true;
    });
    await _save();

    try {
      final calendarState = CalendarPage.globalKey.currentState;
      if (enabled) {
        final added = await UsHolidaySeeder.seed(years: 2);
        if (calendarState != null) {
          await calendarState.reloadFromOutside();
        }
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('Loaded $added U.S. holiday notes.'),
              backgroundColor: Colors.green.shade700,
            ),
          );
        }
      } else {
        await UsHolidaySeeder.clear();
        if (calendarState != null) {
          await calendarState.reloadFromOutside();
        }
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(
              content: const Text('Removed U.S. holiday notes.'),
              backgroundColor: Colors.green.shade700,
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _usHolidaysEnabled = previous;
      });
      await _save();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e is StateError ? e.message : 'Could not update holiday notes: $e',
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _seedingHolidays = false;
        });
      }
    }
  }

  Future<void> _reloadDailyCosmicContextPreference() async {
    final enabled = await SettingsPrefs.dailyCosmicContextBadgeEnabled();
    if (mounted) setState(() => _dailyCosmicContextBadgeEnabled = enabled);
  }

  Future<void> _setDailyCosmicContextBadgeEnabled(bool enabled) async {
    if (_savingDailyCosmicContextBadge) return;
    setState(() => _savingDailyCosmicContextBadge = true);
    try {
      await SettingsPrefs.setDailyCosmicContextBadgeEnabled(enabled);
      if (mounted) setState(() => _dailyCosmicContextBadgeEnabled = enabled);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save your choice. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingDailyCosmicContextBadge = false);
    }
  }

  String _formatTimestamp(DateTime dt) {
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$mm/$dd $hh:$min';
  }

  String _formatDurationSeconds(int? seconds) {
    if (seconds == null) return 'n/a';
    if (seconds < 60) return '${seconds}s';
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    if (minutes < 60) return '${minutes}m ${remainder}s';
    final hours = minutes ~/ 60;
    return '${hours}h ${minutes % 60}m';
  }

  String _shortDeliveryKey(String key) {
    if (key.length <= 42) return key;
    return '${key.substring(0, 24)}...${key.substring(key.length - 14)}';
  }

  String _pushToggleSubtitle() {
    if (!_hasSession) {
      return 'Sign in first, then allow notifications for this device.';
    }
    if (_realTimeAlerts) {
      final diagnostics = _pushDiagnostics;
      if (diagnostics == null) {
        return 'Push alerts are on locally. Checking whether this device is ready for delivery.';
      }
      if (diagnostics.currentDeviceReadyForPush) {
        return 'This device is linked for account-level push alerts.';
      }
      return diagnostics.currentDeviceReadinessIssue ??
          'Push alerts are on locally, but this device is not currently ready for delivery.';
    }
    return 'Off by default. Turn this on only for devices that should receive push alerts.';
  }

  bool get _canSendPushSelfTest {
    return !_sendingPushTest &&
        !_requestingPush &&
        _hasSession &&
        _realTimeAlerts &&
        _pushDiagnostics?.currentDeviceReadyForPush == true;
  }

  String _pushStatusText() {
    final readinessIssue = _pushDiagnostics?.currentDeviceReadinessIssue;
    if (_realTimeAlerts &&
        readinessIssue != null &&
        _pushStatus == 'Push alerts are enabled for this device.') {
      return readinessIssue;
    }
    if (_pushStatus != null) return _pushStatus!;
    if (_requestingPush) {
      return 'Requesting notification permission...';
    }
    if (_loadingPushDiagnostics) {
      return 'Checking Firebase, permission, and device registration...';
    }
    if (_realTimeAlerts) {
      return readinessIssue ?? 'Push alerts are enabled for this device.';
    }
    return _hasSession
        ? 'Push alerts are currently off on this device.'
        : 'Push alerts stay unavailable until you sign in.';
  }

  String _pushButtonLabel() {
    if (_requestingPush) return 'Requesting...';
    if (!_hasSession) return 'Sign in to enable push';
    return _realTimeAlerts
        ? 'Refresh push on this device'
        : 'Enable push on this device';
  }

  List<String> _pushDiagnosticLines() {
    final diagnostics = _pushDiagnostics;
    if (diagnostics == null) {
      return const <String>[];
    }

    final lines = <String>[
      diagnostics.firebaseReady
          ? 'Firebase is ready on ${diagnostics.platform}.'
          : 'Firebase is not ready for this build. Check the bundled Firebase config.',
      'Permission: ${diagnostics.permissionStatus}.',
    ];

    if (kIsWeb) {
      lines.add(
        'For the most reliable web delivery, install the PWA and allow notifications for this site.',
      );
      lines.add(
        diagnostics.browserSubscriptionPresent
            ? 'Browser subscription: present (${diagnostics.browserSubscriptionSummary}).'
            : 'Browser subscription: missing on this device.',
      );
    }

    if (!diagnostics.hasSession) {
      lines.add('Sign in to link this device to your account for remote push.');
      return lines;
    }

    if (diagnostics.databaseRegistered) {
      final lastSeen = diagnostics.lastSeenAt?.toLocal();
      lines.add(
        lastSeen == null
            ? 'Server registration: active for this device.'
            : 'Server registration: active, last seen ${_formatTimestamp(lastSeen)}.',
      );
      if (diagnostics.tokenSummary != 'not available') {
        lines.add('Registered token: ${diagnostics.tokenSummary}.');
      }
    } else {
      lines.add(
        'Server registration: this device is not currently linked in push_tokens.',
      );
    }

    if (_realTimeAlerts) {
      final readinessIssue = diagnostics.currentDeviceReadinessIssue;
      lines.add(
        readinessIssue == null
            ? 'Current device readiness: ready for push delivery.'
            : 'Current device readiness: $readinessIssue',
      );
    }

    if (diagnostics.error != null && diagnostics.error!.isNotEmpty) {
      lines.add('Diagnostics warning: ${diagnostics.error!}');
    }

    return lines;
  }

  List<String> _pushTestReceiptLines() {
    final key = _pushTestDeliveryKey;
    if (key == null || key.isEmpty) {
      return const <String>['No push test has been sent from this device yet.'];
    }

    final status = _pushTestReceiptStatus;
    final lines = <String>['Delivery key: ${_shortDeliveryKey(key)}'];

    if (_checkingPushTestReceipt) {
      lines.add('Receipt status: checking...');
    }

    if (status == null) {
      lines.add(
        'Receipt status: sent test pending. Background the app, tap the notification, then refresh.',
      );
      return lines;
    }

    if (status.lookupStatus == 'missing') {
      lines.add(
        'Receipt status: no server timing row yet. The send may still be settling or the push was not accepted.',
      );
      return lines;
    }

    if (status.lookupStatus == 'error') {
      lines.add('Receipt status lookup failed: ${status.receiptStatus}');
      return lines;
    }

    lines.add('Receipt status: ${status.receiptStatus ?? 'awaiting receipt'}.');
    if (status.sentAt != null) {
      lines.add('Server sent: ${_formatTimestamp(status.sentAt!.toLocal())}.');
    }
    if (status.firstReceivedAt != null) {
      lines.add(
        'Device received: ${_formatTimestamp(status.firstReceivedAt!.toLocal())}.',
      );
    }
    if (status.firstOpenedAt != null) {
      lines.add(
        'Opened from notification: ${_formatTimestamp(status.firstOpenedAt!.toLocal())}.',
      );
    }
    if (status.receiptLatencySeconds != null) {
      lines.add(
        'Receipt latency: ${_formatDurationSeconds(status.receiptLatencySeconds)}.',
      );
    }
    if (status.openLatencySeconds != null) {
      lines.add(
        'Open latency: ${_formatDurationSeconds(status.openLatencySeconds)}.',
      );
    }
    lines.add('Receipt events: ${status.receiptEventCount ?? 0}.');
    return lines;
  }

  Widget _sectionCard({
    required String title,
    required String description,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0C0C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF242424)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _settingSwitch({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
    Widget? trailing,
  }) {
    return Column(
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          activeThumbColor: KemeticGold.base,
          title: Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(color: Colors.white60, height: 1.35),
          ),
          value: value,
          onChanged: onChanged,
          secondary: trailing,
        ),
        const Divider(color: Color(0xFF1D1D1D), height: 1),
      ],
    );
  }

  Widget _footerHeading(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
    );
  }

  Widget _compactFooterRow({
    required IconData icon,
    required String title,
    required VoidCallback? onPressed,
    String? subtitle,
    bool destructive = false,
  }) {
    final foreground = destructive ? Colors.red.shade200 : Colors.white;
    final iconColor = destructive
        ? Colors.red.shade300
        : KemeticGold.base.withValues(alpha: 0.9);
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: onPressed == null
                          ? foreground.withValues(alpha: 0.42)
                          : foreground,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null && subtitle.trim().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.58),
                        fontSize: 12,
                        height: 1.25,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (onPressed != null)
              Icon(
                Icons.chevron_right,
                color: Colors.white.withValues(alpha: 0.32),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _thinDivider() {
    return const Divider(color: Color(0xFF1D1D1D), height: 1);
  }

  Widget _visibilityNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0C0C),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF242424)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Privacy & visibility',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Your private journal, calendar, and personal flow activity are private by default. Profile details, posts, comments, and shared activity may be visible to others when you choose to share or post.',
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildMarker() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleBuildMarkerTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.035),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF202020)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Build',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 6),
            _buildMarkerLine('App version', _buildInfo.appVersion),
            _buildMarkerLine('Web build', _buildInfo.webBuildVersion),
            _buildMarkerLine('Build time', _buildInfo.buildTimestamp),
            _buildMarkerLine('APP_ENV', _buildInfo.appEnvironment),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _copyHydrationDiagnostics,
                icon: const Icon(Icons.copy, size: 15),
                label: const Text('Copy hydration diagnostics'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white54,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  textStyle: const TextStyle(fontSize: 11),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarkerLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Text(
        '$label: $value',
        style: const TextStyle(color: Colors.white38, fontSize: 11),
      ),
    );
  }

  Widget _statusLine(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Icon(Icons.circle, size: 6, color: Colors.white38),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white70, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _primaryButton({
    required VoidCallback? onPressed,
    required Widget child,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: KemeticGold.base,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: onPressed,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: KemeticGold.base)),
      );
    }

    final pushDiagnosticLines = _pushDiagnosticLines();
    final pushReceiptLines = _pushTestReceiptLines();
    const scrollBottomPadding = 32.0;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: KemeticGold.icon(Icons.arrow_back),
          onPressed: () => popOrGo(context, '/'),
        ),
        centerTitle: true,
        title: const Text('Settings', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: KemeticGold.base),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: KemeticGold.icon(Icons.logout),
            onPressed: _signingOut ? null : _signOut,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 12, 16, scrollBottomPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Only live device, privacy, and account controls are surfaced here.',
              style: TextStyle(color: Colors.white60, height: 1.4),
            ),
            const SizedBox(height: 16),
            _sectionCard(
              title: 'Notifications',
              description:
                  'Push alerts are opt-in per device. Scheduled reminder notifications continue to be driven by the events and reminders you create.',
              children: [
                KeyedSubtree(
                  key: _settingsControlsHelperKey,
                  child: _settingSwitch(
                    title: 'Push alerts on this device',
                    subtitle: _pushToggleSubtitle(),
                    value: _realTimeAlerts,
                    onChanged: _requestingPush ? null : _setRealTimeAlerts,
                  ),
                ),
                const SizedBox(height: 16),
                _primaryButton(
                  onPressed: _requestingPush || !_hasSession
                      ? null
                      : () => _setRealTimeAlerts(true),
                  child: Text(_pushButtonLabel()),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF3A3A3A)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: _canSendPushSelfTest ? _sendPushTest : null,
                    child: Text(
                      _sendingPushTest
                          ? 'Sending test push...'
                          : 'Send test push to this device',
                    ),
                  ),
                ),
                _statusLine(_pushStatusText()),
                for (final line in pushDiagnosticLines) _statusLine(line),
                const SizedBox(height: 16),
                const Divider(color: Color(0xFF1D1D1D), height: 1),
                const SizedBox(height: 16),
                const Text(
                  'Push test receipt',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                for (final line in pushReceiptLines) _statusLine(line),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF3A3A3A)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed:
                        _checkingPushTestReceipt ||
                            !_hasSession ||
                            _pushTestDeliveryKey == null
                        ? null
                        : () => _refreshPushTestReceiptStatus(),
                    child: Text(
                      _checkingPushTestReceipt
                          ? 'Checking receipt...'
                          : 'Refresh push test receipt',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ExternalCalendarSettings(
              callbackResult: widget.externalCalendarCallbackResult,
              onCallbackConsumed: _consumeExternalCalendarCallback,
              showAppleAvailability:
                  !DeviceCalendarController.supportedPlatform,
            ),
            if (DeviceCalendarController.supportedPlatform) ...[
              const SizedBox(height: 16),
              const DeviceCalendarSettings(),
            ],
            const SizedBox(height: 16),
            _sectionCard(
              title: 'Calendar Content',
              description:
                  'Optional data sources that add entries inside the app without changing your core sync behavior.',
              children: [
                _settingSwitch(
                  title: 'Add U.S. holidays as notes',
                  subtitle: _seedingHolidays
                      ? 'Applying holiday notes...'
                      : 'Adds standard U.S. holidays as editable app notes.',
                  value: _usHolidaysEnabled,
                  onChanged: _seedingHolidays ? null : _toggleUsHolidays,
                  trailing: _seedingHolidays
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: KemeticGold.base,
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 16),
                _settingSwitch(
                  title: 'The Day’s Rhythm badge',
                  subtitle:
                      'Automatically shows a Day’s Rhythm card once each day. Turn off to hide future cards.',
                  value: _dailyCosmicContextBadgeEnabled,
                  onChanged: _savingDailyCosmicContextBadge
                      ? null
                      : _setDailyCosmicContextBadgeEnabled,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _sectionCard(
              title: 'Decan reflection',
              description:
                  'Return to your latest completed decan, even if you’ve already reflected.',
              children: [
                _primaryButton(
                  onPressed: _hasSession ? _showReflectionBadge : null,
                  child: const Text('Show reflection badge'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            AnimatedBuilder(
              animation: Listenable.merge([
                SpeechService.instance.activeUtteranceId,
                SpeechService.instance.libraryStatus,
                SpeechService.instance.libraryFailed,
              ]),
              builder: (context, _) => SpeechSettingsCard(
                selectedVoice: _selectedSpeechVoice,
                onChanged: _setSpeechVoice,
                onPreview: _previewSpeechVoice,
                busy: _loadingSpeechVoices || _savingSpeechVoice,
                previewActive:
                    SpeechService.instance.activeUtteranceId.value ==
                    _speechPreviewUtteranceId,
                status:
                    _speechVoiceStatus ??
                    SpeechService.instance.libraryStatus.value,
                onRetry: _speechVoiceStatus != null
                    ? _loadSpeechSettings
                    : SpeechService.instance.libraryFailed.value
                    ? SpeechService.instance.prepareLibrary
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            _footerHeading('Onboarding'),
            _compactFooterRow(
              icon: Icons.replay,
              title: _replayingOnboarding
                  ? 'Opening onboarding…'
                  : 'Replay onboarding',
              subtitle:
                  'Start again from the opening and choose a flow. Your saved flows stay in place.',
              onPressed: _replayingOnboarding || !_hasSession
                  ? null
                  : _replayOnboarding,
            ),
            const SizedBox(height: 18),
            _visibilityNotice(),
            const SizedBox(height: 18),
            _footerHeading('Legal & Support'),
            _compactFooterRow(
              icon: Icons.description_outlined,
              title: 'Terms',
              onPressed: () => _openExternalSupportTarget(_termsUrl),
            ),
            _thinDivider(),
            _compactFooterRow(
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy',
              onPressed: () => _openExternalSupportTarget(_privacyPolicyUrl),
            ),
            _thinDivider(),
            _compactFooterRow(
              icon: Icons.help_outline,
              title: 'Support',
              onPressed: () => _openExternalSupportTarget(_supportUrl),
            ),
            const SizedBox(height: 18),
            _footerHeading('Danger Zone'),
            _compactFooterRow(
              icon: Icons.delete_outline,
              title: _deletingAccount
                  ? 'Deleting account...'
                  : 'Delete account',
              subtitle: _hasSession
                  ? (_accountStatus ??
                        'Permanently removes your sign-in and account data.')
                  : 'Sign in to manage or delete your account.',
              destructive: true,
              onPressed: _deletingAccount || !_hasSession
                  ? null
                  : _deleteAccount,
            ),
            _thinDivider(),
            _compactFooterRow(
              icon: Icons.logout,
              title: _signingOut ? 'Signing out...' : 'Sign out',
              onPressed: _signingOut ? null : _signOut,
            ),
            const SizedBox(height: 16),
            const Text(
              'Preferences stay local to this device. Push registration and calendar permission are also device-specific.',
              style: TextStyle(color: Colors.white60, height: 1.4),
            ),
            const SizedBox(height: 12),
            _buildMarker(),
          ],
        ),
      ),
    );
  }
}
