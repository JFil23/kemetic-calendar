import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const int kTrueOnboardingVersion = 2;

enum TrueOnboardingStep {
  welcome,
  currentDecanIntro,
  profileBasics,
  firstMaatFlow,
  firstFlowCalendarDay,
  firstFlowDayEvent,
  eventDetailObservedJournal,
  menuExplore,
  complete,
}

extension TrueOnboardingStepWire on TrueOnboardingStep {
  String get wireName {
    switch (this) {
      case TrueOnboardingStep.welcome:
        return 'welcome';
      case TrueOnboardingStep.currentDecanIntro:
        return 'currentDecanIntro';
      case TrueOnboardingStep.profileBasics:
        return 'profileBasics';
      case TrueOnboardingStep.firstMaatFlow:
        return 'firstMaatFlow';
      case TrueOnboardingStep.firstFlowCalendarDay:
        return 'firstFlowCalendarDay';
      case TrueOnboardingStep.firstFlowDayEvent:
        return 'firstFlowDayEvent';
      case TrueOnboardingStep.eventDetailObservedJournal:
        return 'eventDetailObservedJournal';
      case TrueOnboardingStep.menuExplore:
        return 'menuExplore';
      case TrueOnboardingStep.complete:
        return 'complete';
    }
  }

  static TrueOnboardingStep fromWire(String? raw) {
    switch (raw) {
      case 'currentDecanIntro':
        return TrueOnboardingStep.currentDecanIntro;
      case 'profileBasics':
        return TrueOnboardingStep.profileBasics;
      case 'firstMaatFlow':
        return TrueOnboardingStep.firstMaatFlow;
      case 'firstFlowCalendarDay':
        return TrueOnboardingStep.firstFlowCalendarDay;
      case 'firstFlowDayEvent':
        return TrueOnboardingStep.firstFlowDayEvent;
      case 'eventDetailObservedJournal':
        return TrueOnboardingStep.eventDetailObservedJournal;
      case 'menuExplore':
        return TrueOnboardingStep.menuExplore;
      case 'complete':
        return TrueOnboardingStep.complete;
      case 'welcome':
      default:
        return TrueOnboardingStep.welcome;
    }
  }
}

class OnboardingHelperIds {
  OnboardingHelperIds._();

  static const String calendarToggle = 'calendar_toggle';
  static const String monthDetails = 'calendar_month_details';
  static const String dayCardLongPress = 'calendar_day_card_long_press';
  static const String journalBadges = 'journal_badges';
  static const String flowStudioAddFlow = 'flow_studio_add_flow';
  static const String flowStudioSavedFlows = 'flow_studio_saved_flows';
  static const String flowStudioMaatFlows = 'flow_studio_maat_flows';
  static const String profileCommunityFeed = 'profile_community_feed';
  static const String settingsControl = 'settings_control';

  @Deprecated('Use flowStudioAddFlow/flowStudioSavedFlows/flowStudioMaatFlows.')
  static const String flowBuilder = 'flowBuilder';

  static const int defaultVersion = 1;

  static const Set<String> all = {
    calendarToggle,
    monthDetails,
    dayCardLongPress,
    journalBadges,
    flowStudioAddFlow,
    flowStudioSavedFlows,
    flowStudioMaatFlows,
    profileCommunityFeed,
    settingsControl,
  };

  static const Map<String, int> versions = {
    calendarToggle: defaultVersion,
    monthDetails: defaultVersion,
    dayCardLongPress: defaultVersion,
    journalBadges: defaultVersion,
    flowStudioAddFlow: defaultVersion,
    flowStudioSavedFlows: defaultVersion,
    flowStudioMaatFlows: defaultVersion,
    profileCommunityFeed: defaultVersion,
    settingsControl: defaultVersion,
  };

  static const Map<String, Set<String>> legacyAliases = {
    'calendarToggle': {calendarToggle},
    'monthDetails': {monthDetails},
    'dayCardLongPress': {dayCardLongPress},
    'journalBadges': {journalBadges},
    'journal_badges_helper': {journalBadges},
    'journal_record_badges': {journalBadges},
    'journalRecordBadges': {journalBadges},
    'helper_seen_journal_badges': {journalBadges},
    'flowBuilder': {
      flowStudioAddFlow,
      flowStudioSavedFlows,
      flowStudioMaatFlows,
    },
    'profileCommunityFeed': {profileCommunityFeed},
    'settingsControl': {settingsControl},
  };

  static int versionFor(String helperId) =>
      versions[helperId] ?? defaultVersion;

  static String completionKeyFor(String helperId, {int? version}) {
    final resolvedVersion = version ?? versionFor(helperId);
    return resolvedVersion == defaultVersion
        ? helperId
        : '$helperId@v$resolvedVersion';
  }

  static ({String helperId, int version}) parseCompletionKey(String key) {
    final raw = key.trim();
    final versionMatch = RegExp(r'^(.*)@v([1-9][0-9]*)$').firstMatch(raw);
    if (versionMatch == null) {
      return (helperId: raw, version: defaultVersion);
    }
    final helperId = versionMatch.group(1)?.trim() ?? raw;
    final version = int.tryParse(versionMatch.group(2) ?? '') ?? defaultVersion;
    return (helperId: helperId, version: version);
  }

  static Set<String> completionKeysFor(String helperId) {
    final raw = helperId.trim();
    if (raw.isEmpty) return const <String>{};
    final aliases = legacyAliases[raw];
    if (aliases != null) {
      return aliases.map((id) => completionKeyFor(id)).toSet();
    }
    final parsed = parseCompletionKey(raw);
    if (!all.contains(parsed.helperId)) return const <String>{};
    return {completionKeyFor(parsed.helperId, version: parsed.version)};
  }

  static Set<String> normalizeCompletedHelperKeys(Iterable<String> rawIds) {
    final normalized = <String>{};
    for (final raw in rawIds) {
      normalized.addAll(completionKeysFor(raw));
    }
    return normalized;
  }
}

@immutable
class OnboardingHelperDefinition {
  const OnboardingHelperDefinition({
    required this.id,
    required this.title,
    required this.body,
    required this.analyticsEvent,
    required this.sourceWidget,
  });

  final String id;
  final String title;
  final String body;
  final String analyticsEvent;
  final String sourceWidget;
}

class OnboardingHelperRegistry {
  OnboardingHelperRegistry._();

  static const String flowHubPageAddFlowSourceWidget =
      'FlowHubPage.addFlowHelper';
  static const String maatFlowListAddFlowSourceWidget =
      'MaatFlowListPage.addFlowHelper';

  static const flowStudioAddFlow = OnboardingHelperDefinition(
    id: OnboardingHelperIds.flowStudioAddFlow,
    title: 'Build your own rhythm',
    body:
        'Create personal flows for study, health, family, writing, business, or spiritual practice.',
    analyticsEvent: 'helper_seen_flow_builder',
    sourceWidget: 'FlowStudioAddFlowHelper',
  );

  static const flowStudioSavedFlows = OnboardingHelperDefinition(
    id: OnboardingHelperIds.flowStudioSavedFlows,
    title: 'Saved flows',
    body: 'Your saved and active flows live here.',
    analyticsEvent: 'helper_seen_flow_studio_saved_flows',
    sourceWidget: 'FlowStudioSavedFlowsHelper',
  );

  static const flowStudioMaatFlows = OnboardingHelperDefinition(
    id: OnboardingHelperIds.flowStudioMaatFlows,
    title: 'Ma’at template flows',
    body: 'Ma’at templates give you ready-made rhythms to adapt.',
    analyticsEvent: 'helper_seen_flow_studio_maat_flows',
    sourceWidget: 'FlowStudioMaatFlowsHelper',
  );

  static const calendarToggle = OnboardingHelperDefinition(
    id: OnboardingHelperIds.calendarToggle,
    title: 'Switch calendar views',
    body:
        'Tap ḥꜣw to toggle between the Kemetic calendar and the Gregorian calendar at any time.',
    analyticsEvent: 'helper_seen_calendar_toggle',
    sourceWidget: 'CalendarPage.calendarToggleHelper',
  );

  static const monthDetails = OnboardingHelperDefinition(
    id: OnboardingHelperIds.monthDetails,
    title: 'Month details',
    body: 'Tap the month or decan name for lore, structure, and meaning.',
    analyticsEvent: 'helper_seen_month_details',
    sourceWidget: 'CalendarPage.monthDetailsHelper',
  );

  static const dayCardLongPress = OnboardingHelperDefinition(
    id: OnboardingHelperIds.dayCardLongPress,
    title: 'Reveal the day card',
    body: 'Long press a day to reveal its card.',
    analyticsEvent: 'helper_seen_day_card_long_press',
    sourceWidget: 'CalendarPage.dayCardLongPressHelper',
  );

  static const journalBadges = OnboardingHelperDefinition(
    id: OnboardingHelperIds.journalBadges,
    title: 'Your record gathers here',
    body:
        'Reflections, observed events, and journal badges will appear here over time.',
    analyticsEvent: 'helper_seen_journal_badges',
    sourceWidget: 'JournalPage.journalBadgesHelper',
  );

  static const settingsControl = OnboardingHelperDefinition(
    id: OnboardingHelperIds.settingsControl,
    title: 'Control the experience',
    body:
        'Manage notifications, calendar preferences, profile settings, and privacy here.',
    analyticsEvent: 'helper_seen_settings_control',
    sourceWidget: 'SettingsPage.settingsControlHelper',
  );

  static const profileCommunityFeed = OnboardingHelperDefinition(
    id: OnboardingHelperIds.profileCommunityFeed,
    title: 'Your community lives below',
    body:
        'Scroll down to reveal the community feed, where shared flows and confirmations begin to gather.',
    analyticsEvent: 'helper_seen_profile_community_feed',
    sourceWidget: 'ProfilePage.profileCommunityFeedHelper',
  );

  static const List<OnboardingHelperDefinition> all = [
    calendarToggle,
    monthDetails,
    dayCardLongPress,
    journalBadges,
    flowStudioAddFlow,
    flowStudioSavedFlows,
    flowStudioMaatFlows,
    profileCommunityFeed,
    settingsControl,
  ];

  static const Map<String, OnboardingHelperDefinition> byId = {
    OnboardingHelperIds.calendarToggle: calendarToggle,
    OnboardingHelperIds.monthDetails: monthDetails,
    OnboardingHelperIds.dayCardLongPress: dayCardLongPress,
    OnboardingHelperIds.journalBadges: journalBadges,
    OnboardingHelperIds.flowStudioAddFlow: flowStudioAddFlow,
    OnboardingHelperIds.flowStudioSavedFlows: flowStudioSavedFlows,
    OnboardingHelperIds.flowStudioMaatFlows: flowStudioMaatFlows,
    OnboardingHelperIds.profileCommunityFeed: profileCommunityFeed,
    OnboardingHelperIds.settingsControl: settingsControl,
  };

  static bool isRegistered(String helperId) {
    final keys = OnboardingHelperIds.completionKeysFor(helperId);
    if (keys.isEmpty) return false;
    return keys.every((key) {
      final parsed = OnboardingHelperIds.parseCompletionKey(key);
      return byId.containsKey(parsed.helperId);
    });
  }

  static OnboardingHelperDefinition? maybeById(String helperId) {
    final keys = OnboardingHelperIds.completionKeysFor(helperId);
    if (keys.length != 1) return null;
    final parsed = OnboardingHelperIds.parseCompletionKey(keys.single);
    return byId[parsed.helperId];
  }
}

@immutable
class OnboardingProgress {
  const OnboardingProgress({
    this.onboardingVersion = kTrueOnboardingVersion,
    this.currentStep = TrueOnboardingStep.welcome,
    this.hasSeenWelcome = false,
    this.hasSeenCurrentDecanIntro = false,
    this.hasCompletedProfileBasics = false,
    this.hasChosenFirstMaatFlow = false,
    this.firstMaatFlowId,
    this.firstMaatFlowTemplateId,
    this.firstMaatFlowEventDate,
    this.firstMaatFlowEventClientEventId,
    this.hasTappedFirstFlowDay = false,
    this.hasOpenedFirstFlowEvent = false,
    this.hasSeenObservedJournalPrompt = false,
    this.hasSeenMenuPrompt = false,
    this.completedOnboarding = false,
    this.skippedOnboarding = false,
    this.seenHelpers = const <String>{},
  });

  final int onboardingVersion;
  final TrueOnboardingStep currentStep;
  final bool hasSeenWelcome;
  final bool hasSeenCurrentDecanIntro;
  final bool hasCompletedProfileBasics;
  final bool hasChosenFirstMaatFlow;
  final String? firstMaatFlowId;
  final String? firstMaatFlowTemplateId;
  final DateTime? firstMaatFlowEventDate;
  final String? firstMaatFlowEventClientEventId;
  final bool hasTappedFirstFlowDay;
  final bool hasOpenedFirstFlowEvent;
  final bool hasSeenObservedJournalPrompt;
  final bool hasSeenMenuPrompt;
  final bool completedOnboarding;
  final bool skippedOnboarding;
  final Set<String> seenHelpers;

  OnboardingProgress copyWith({
    int? onboardingVersion,
    TrueOnboardingStep? currentStep,
    bool? hasSeenWelcome,
    bool? hasSeenCurrentDecanIntro,
    bool? hasCompletedProfileBasics,
    bool? hasChosenFirstMaatFlow,
    String? firstMaatFlowId,
    bool clearFirstMaatFlowId = false,
    String? firstMaatFlowTemplateId,
    bool clearFirstMaatFlowTemplateId = false,
    DateTime? firstMaatFlowEventDate,
    bool clearFirstMaatFlowEventDate = false,
    String? firstMaatFlowEventClientEventId,
    bool clearFirstMaatFlowEventClientEventId = false,
    bool? hasTappedFirstFlowDay,
    bool? hasOpenedFirstFlowEvent,
    bool? hasSeenObservedJournalPrompt,
    bool? hasSeenMenuPrompt,
    bool? completedOnboarding,
    bool? skippedOnboarding,
    Set<String>? seenHelpers,
  }) {
    return OnboardingProgress(
      onboardingVersion: onboardingVersion ?? this.onboardingVersion,
      currentStep: currentStep ?? this.currentStep,
      hasSeenWelcome: hasSeenWelcome ?? this.hasSeenWelcome,
      hasSeenCurrentDecanIntro:
          hasSeenCurrentDecanIntro ?? this.hasSeenCurrentDecanIntro,
      hasCompletedProfileBasics:
          hasCompletedProfileBasics ?? this.hasCompletedProfileBasics,
      hasChosenFirstMaatFlow:
          hasChosenFirstMaatFlow ?? this.hasChosenFirstMaatFlow,
      firstMaatFlowId: clearFirstMaatFlowId
          ? null
          : (firstMaatFlowId ?? this.firstMaatFlowId),
      firstMaatFlowTemplateId: clearFirstMaatFlowTemplateId
          ? null
          : (firstMaatFlowTemplateId ?? this.firstMaatFlowTemplateId),
      firstMaatFlowEventDate: clearFirstMaatFlowEventDate
          ? null
          : (firstMaatFlowEventDate ?? this.firstMaatFlowEventDate),
      firstMaatFlowEventClientEventId: clearFirstMaatFlowEventClientEventId
          ? null
          : (firstMaatFlowEventClientEventId ??
                this.firstMaatFlowEventClientEventId),
      hasTappedFirstFlowDay:
          hasTappedFirstFlowDay ?? this.hasTappedFirstFlowDay,
      hasOpenedFirstFlowEvent:
          hasOpenedFirstFlowEvent ?? this.hasOpenedFirstFlowEvent,
      hasSeenObservedJournalPrompt:
          hasSeenObservedJournalPrompt ?? this.hasSeenObservedJournalPrompt,
      hasSeenMenuPrompt: hasSeenMenuPrompt ?? this.hasSeenMenuPrompt,
      completedOnboarding:
          completedOnboarding ??
          (this.completedOnboarding ||
              (currentStep ?? this.currentStep) == TrueOnboardingStep.complete),
      skippedOnboarding: skippedOnboarding ?? this.skippedOnboarding,
      seenHelpers: seenHelpers ?? this.seenHelpers,
    );
  }

  OnboardingProgress markHelperSeen(String helperId) {
    return copyWith(
      seenHelpers: OnboardingHelperIds.normalizeCompletedHelperKeys({
        ...seenHelpers,
        helperId,
      }),
    );
  }

  Map<String, dynamic> toJson() => {
    'onboardingVersion': onboardingVersion,
    'currentStep': currentStep.wireName,
    'hasSeenWelcome': hasSeenWelcome,
    'hasSeenCurrentDecanIntro': hasSeenCurrentDecanIntro,
    'hasCompletedProfileBasics': hasCompletedProfileBasics,
    'hasChosenFirstMaatFlow': hasChosenFirstMaatFlow,
    'firstMaatFlowId': firstMaatFlowId,
    'firstMaatFlowTemplateId': firstMaatFlowTemplateId,
    'firstMaatFlowEventDate': firstMaatFlowEventDate?.toIso8601String(),
    'firstMaatFlowEventClientEventId': firstMaatFlowEventClientEventId,
    'hasTappedFirstFlowDay': hasTappedFirstFlowDay,
    'hasOpenedFirstFlowEvent': hasOpenedFirstFlowEvent,
    'hasSeenObservedJournalPrompt': hasSeenObservedJournalPrompt,
    'hasSeenMenuPrompt': hasSeenMenuPrompt,
    'completedOnboarding': completedOnboarding,
    'skippedOnboarding': skippedOnboarding,
    'seenHelpers': seenHelpers.toList()..sort(),
  };

  static OnboardingProgress fromJson(Map<String, dynamic> json) {
    final rawHelpers = json['seenHelpers'];
    final helperIds = rawHelpers is List
        ? OnboardingHelperIds.normalizeCompletedHelperKeys(
            rawHelpers.whereType<String>(),
          )
        : const <String>{};
    final eventDateRaw = json['firstMaatFlowEventDate'] as String?;
    return OnboardingProgress(
      onboardingVersion:
          (json['onboardingVersion'] as num?)?.toInt() ??
          kTrueOnboardingVersion,
      currentStep: TrueOnboardingStepWire.fromWire(
        json['currentStep'] as String?,
      ),
      hasSeenWelcome: json['hasSeenWelcome'] == true,
      hasSeenCurrentDecanIntro: json['hasSeenCurrentDecanIntro'] == true,
      hasCompletedProfileBasics: json['hasCompletedProfileBasics'] == true,
      hasChosenFirstMaatFlow: json['hasChosenFirstMaatFlow'] == true,
      firstMaatFlowId: json['firstMaatFlowId'] as String?,
      firstMaatFlowTemplateId: json['firstMaatFlowTemplateId'] as String?,
      firstMaatFlowEventDate: eventDateRaw == null
          ? null
          : DateTime.tryParse(eventDateRaw),
      firstMaatFlowEventClientEventId:
          json['firstMaatFlowEventClientEventId'] as String?,
      hasTappedFirstFlowDay: json['hasTappedFirstFlowDay'] == true,
      hasOpenedFirstFlowEvent: json['hasOpenedFirstFlowEvent'] == true,
      hasSeenObservedJournalPrompt:
          json['hasSeenObservedJournalPrompt'] == true,
      hasSeenMenuPrompt: json['hasSeenMenuPrompt'] == true,
      completedOnboarding: json['completedOnboarding'] == true,
      skippedOnboarding: json['skippedOnboarding'] == true,
      seenHelpers: helperIds,
    );
  }
}

class OnboardingProgressStorage {
  static const String _keyPrefix = 'onboarding_v2_progress';
  static final Map<String, Future<void>> _helperCompletionQueues =
      <String, Future<void>>{};

  String _keyForUser(String userId) => '$_keyPrefix:$userId';

  Future<OnboardingProgress> load(String userId) async {
    return loadLocal(userId);
  }

  Future<OnboardingProgress> loadLocal(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyForUser(userId));
      if (raw == null || raw.trim().isEmpty) {
        return const OnboardingProgress();
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return const OnboardingProgress();
      }
      return OnboardingProgress.fromJson(decoded);
    } catch (e) {
      debugPrint('[OnboardingProgressStorage] Failed to load progress: $e');
      return const OnboardingProgress();
    }
  }

  Future<void> save(String userId, OnboardingProgress progress) async {
    return saveLocal(userId, progress);
  }

  Future<void> saveLocal(String userId, OnboardingProgress progress) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final normalized = progress.copyWith(
        seenHelpers: OnboardingHelperIds.normalizeCompletedHelperKeys(
          progress.seenHelpers,
        ),
      );
      await prefs.setString(
        _keyForUser(userId),
        jsonEncode(normalized.toJson()),
      );
      OnboardingHelperCompletionService.instance.absorbLocalProgress(
        userId,
        normalized,
      );
    } catch (e) {
      debugPrint('[OnboardingProgressStorage] Failed to save progress: $e');
    }
  }

  Future<void> update(
    String userId,
    OnboardingProgress Function(OnboardingProgress progress) update,
  ) async {
    final current = await load(userId);
    await save(userId, update(current));
  }

  Future<bool> shouldShowHelper(String userId, String helperId) async {
    return OnboardingHelperCompletionService.instance.shouldShowHelper(
      userId,
      helperId,
    );
  }

  Future<OnboardingProgress> markHelperCompleted(
    String userId,
    String helperId,
  ) {
    return OnboardingHelperCompletionService.instance.markHelperCompleted(
      userId,
      helperId,
    );
  }

  Future<OnboardingProgress> markHelperCompletedLocally(
    String userId,
    String helperId,
  ) {
    final queueKey = _keyForUser(userId);
    final completer = Completer<OnboardingProgress>();
    final previous = _helperCompletionQueues[queueKey] ?? Future<void>.value();
    final completionKeys = OnboardingHelperIds.completionKeysFor(helperId);

    late final Future<void> current;
    current = previous
        .catchError((_) {})
        .then((_) async {
          final progress = await loadLocal(userId);
          if (completionKeys.isEmpty ||
              progress.seenHelpers.containsAll(completionKeys)) {
            completer.complete(progress);
            return;
          }
          final updated = progress.copyWith(
            seenHelpers: {...progress.seenHelpers, ...completionKeys},
          );
          await saveLocal(userId, updated);
          completer.complete(updated);
        })
        .catchError((Object error, StackTrace stackTrace) {
          if (!completer.isCompleted) {
            completer.completeError(error, stackTrace);
          }
        })
        .whenComplete(() {
          if (identical(_helperCompletionQueues[queueKey], current)) {
            _helperCompletionQueues.remove(queueKey);
          }
        });

    _helperCompletionQueues[queueKey] = current;
    return completer.future;
  }
}

abstract class OnboardingHelperCompletionRemoteStore {
  Future<Set<String>> loadCompletedHelperKeys(String userId);

  Future<void> markCompleted(String userId, Iterable<String> completionKeys);
}

class SupabaseOnboardingHelperCompletionRemoteStore
    implements OnboardingHelperCompletionRemoteStore {
  SupabaseOnboardingHelperCompletionRemoteStore([SupabaseClient? client])
    : _client = client;

  final SupabaseClient? _client;

  SupabaseClient? _safeClient() {
    if (_client != null) return _client;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Set<String>> loadCompletedHelperKeys(String userId) async {
    final client = _safeClient();
    if (client == null) return const <String>{};
    try {
      final rows = await client
          .from('user_onboarding_helper_completions')
          .select('helper_id, version')
          .eq('user_id', userId);
      return OnboardingHelperIds.normalizeCompletedHelperKeys(
        rows.map((row) {
          final helperId = (row['helper_id'] as String?)?.trim();
          if (helperId == null || helperId.isEmpty) return '';
          final version =
              (row['version'] as num?)?.toInt() ??
              OnboardingHelperIds.defaultVersion;
          return OnboardingHelperIds.completionKeyFor(
            helperId,
            version: version,
          );
        }),
      );
    } catch (e) {
      debugPrint(
        '[OnboardingHelperCompletionRemoteStore] Failed to load helper completions: $e',
      );
      return const <String>{};
    }
  }

  @override
  Future<void> markCompleted(
    String userId,
    Iterable<String> completionKeys,
  ) async {
    final client = _safeClient();
    if (client == null) return;
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final rows =
        OnboardingHelperIds.normalizeCompletedHelperKeys(completionKeys).map((
          key,
        ) {
          final parsed = OnboardingHelperIds.parseCompletionKey(key);
          return <String, dynamic>{
            'user_id': userId,
            'helper_id': parsed.helperId,
            'version': parsed.version,
            'completed_at': nowIso,
          };
        }).toList();
    if (rows.isEmpty) return;
    try {
      await client
          .from('user_onboarding_helper_completions')
          .upsert(rows, onConflict: 'user_id,helper_id,version');
    } catch (e) {
      debugPrint(
        '[OnboardingHelperCompletionRemoteStore] Failed to persist helper completion: $e',
      );
    }
  }
}

enum OnboardingHelperHydrationState { unknown, loading, ready }

@immutable
class OnboardingHelperRenderDebugSnapshot {
  const OnboardingHelperRenderDebugSnapshot({
    required this.helperId,
    required this.userId,
    required this.hydrationState,
    required this.completedLocal,
    required this.completedCloud,
    required this.completedMemory,
  });

  final String helperId;
  final String userId;
  final OnboardingHelperHydrationState hydrationState;
  final bool completedLocal;
  final bool completedCloud;
  final bool completedMemory;
}

class _OnboardingHelperUserState {
  const _OnboardingHelperUserState({
    required this.hydrationState,
    required this.progress,
  });

  final OnboardingHelperHydrationState hydrationState;
  final OnboardingProgress progress;

  _OnboardingHelperUserState copyWith({
    OnboardingHelperHydrationState? hydrationState,
    OnboardingProgress? progress,
  }) {
    return _OnboardingHelperUserState(
      hydrationState: hydrationState ?? this.hydrationState,
      progress: progress ?? this.progress,
    );
  }
}

class OnboardingHelperCompletionService extends ChangeNotifier {
  OnboardingHelperCompletionService({
    OnboardingProgressStorage? localStorage,
    OnboardingHelperCompletionRemoteStore? remoteStore,
  }) : _localStorage = localStorage ?? OnboardingProgressStorage(),
       _remoteStore =
           remoteStore ?? SupabaseOnboardingHelperCompletionRemoteStore();

  static OnboardingHelperCompletionService instance =
      OnboardingHelperCompletionService();

  final OnboardingProgressStorage _localStorage;
  final OnboardingHelperCompletionRemoteStore _remoteStore;
  final Map<String, _OnboardingHelperUserState> _states =
      <String, _OnboardingHelperUserState>{};
  final Map<String, Set<String>> _localCompletionKeys = <String, Set<String>>{};
  final Map<String, Set<String>> _cloudCompletionKeys = <String, Set<String>>{};
  final Map<String, Set<String>> _memoryCompletionKeys =
      <String, Set<String>>{};
  final Map<String, Future<OnboardingProgress>> _hydrationFutures =
      <String, Future<OnboardingProgress>>{};
  final Map<String, Future<OnboardingProgress>> _completionQueues =
      <String, Future<OnboardingProgress>>{};
  bool _notificationScheduled = false;
  bool _isDisposed = false;

  @visibleForTesting
  static void resetForTesting({
    OnboardingProgressStorage? localStorage,
    OnboardingHelperCompletionRemoteStore? remoteStore,
  }) {
    instance.dispose();
    instance = OnboardingHelperCompletionService(
      localStorage: localStorage,
      remoteStore: remoteStore,
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  OnboardingHelperHydrationState hydrationStateFor(String userId) {
    return _states[userId]?.hydrationState ??
        OnboardingHelperHydrationState.unknown;
  }

  bool isHydrated(String userId) =>
      hydrationStateFor(userId) == OnboardingHelperHydrationState.ready;

  bool isHelperCompletedSync(String userId, String helperId) {
    final completionKeys = OnboardingHelperIds.completionKeysFor(helperId);
    if (completionKeys.isEmpty) return false;
    final progressKeys =
        _states[userId]?.progress.seenHelpers ?? const <String>{};
    final memoryKeys = _memoryCompletionKeys[userId] ?? const <String>{};
    return completionKeys.any(
      (key) => progressKeys.contains(key) || memoryKeys.contains(key),
    );
  }

  bool isHelperCompletedLocallySync(String userId, String helperId) {
    final completionKeys = OnboardingHelperIds.completionKeysFor(helperId);
    if (completionKeys.isEmpty) return false;
    final localKeys = _localCompletionKeys[userId] ?? const <String>{};
    return completionKeys.any(localKeys.contains);
  }

  bool isHelperCompletedInCloudSync(String userId, String helperId) {
    final completionKeys = OnboardingHelperIds.completionKeysFor(helperId);
    if (completionKeys.isEmpty) return false;
    final cloudKeys = _cloudCompletionKeys[userId] ?? const <String>{};
    return completionKeys.any(cloudKeys.contains);
  }

  OnboardingHelperRenderDebugSnapshot debugSnapshot(
    String userId,
    String helperId,
  ) {
    final trimmedUserId = userId.trim();
    final completionKeys = OnboardingHelperIds.completionKeysFor(helperId);
    final memoryKeys = _memoryCompletionKeys[trimmedUserId] ?? const <String>{};
    return OnboardingHelperRenderDebugSnapshot(
      helperId: helperId,
      userId: trimmedUserId,
      hydrationState: hydrationStateFor(trimmedUserId),
      completedLocal: isHelperCompletedLocallySync(trimmedUserId, helperId),
      completedCloud: isHelperCompletedInCloudSync(trimmedUserId, helperId),
      completedMemory: completionKeys.any(memoryKeys.contains),
    );
  }

  void debugLogHelperRender({
    required String userId,
    required String helperId,
    required String sourceWidget,
  }) {
    assert(() {
      final snapshot = debugSnapshot(userId, helperId);
      debugPrint(
        '[OnboardingHelperRender] helperId=${snapshot.helperId} '
        'userId=${snapshot.userId} '
        'hydrationState=${snapshot.hydrationState.name} '
        'completedLocal=${snapshot.completedLocal} '
        'completedCloud=${snapshot.completedCloud} '
        'completedMemory=${snapshot.completedMemory} '
        'sourceWidget=$sourceWidget',
      );
      return true;
    }());
  }

  bool shouldShowHelperSync(String userId, String helperId) {
    final state = _states[userId];
    if (state == null ||
        state.hydrationState != OnboardingHelperHydrationState.ready ||
        !state.progress.completedOnboarding) {
      return false;
    }
    final completionKeys = OnboardingHelperIds.completionKeysFor(helperId);
    if (completionKeys.isEmpty) return false;
    return !completionKeys.any(state.progress.seenHelpers.contains);
  }

  void absorbLocalProgress(String userId, OnboardingProgress progress) {
    final trimmedUserId = userId.trim();
    if (trimmedUserId.isEmpty || !_states.containsKey(trimmedUserId)) {
      return;
    }
    final state = _states[trimmedUserId]!;
    final memoryKeys = _memoryCompletionKeys[trimmedUserId] ?? const <String>{};
    final merged = progress.copyWith(
      seenHelpers: OnboardingHelperIds.normalizeCompletedHelperKeys({
        ...progress.seenHelpers,
        ...memoryKeys,
      }),
    );
    _localCompletionKeys[trimmedUserId] = merged.seenHelpers;
    if (state.progress == merged) return;
    _states[trimmedUserId] = state.copyWith(progress: merged);
    _notifyListenersSafely();
  }

  Future<bool> shouldShowHelper(String userId, String helperId) async {
    await hydrateUser(userId);
    return shouldShowHelperSync(userId, helperId);
  }

  Future<OnboardingProgress> hydrateUser(String userId, {bool force = false}) {
    final trimmedUserId = userId.trim();
    if (trimmedUserId.isEmpty) {
      return Future<OnboardingProgress>.value(const OnboardingProgress());
    }
    final current = _states[trimmedUserId];
    if (!force &&
        current?.hydrationState == OnboardingHelperHydrationState.ready) {
      return Future<OnboardingProgress>.value(current!.progress);
    }
    final existing = _hydrationFutures[trimmedUserId];
    if (!force && existing != null) return existing;

    _states[trimmedUserId] = _OnboardingHelperUserState(
      hydrationState: OnboardingHelperHydrationState.loading,
      progress: current?.progress ?? const OnboardingProgress(),
    );
    _notifyListenersSafely();

    late final Future<OnboardingProgress> hydration;
    hydration =
        (() async {
              var progress = await _localStorage.loadLocal(trimmedUserId);
              final localKeys =
                  OnboardingHelperIds.normalizeCompletedHelperKeys(
                    progress.seenHelpers,
                  );
              final remoteKeys = await _remoteStore.loadCompletedHelperKeys(
                trimmedUserId,
              );
              final memoryKeys =
                  _memoryCompletionKeys[trimmedUserId] ?? const <String>{};
              final mergedKeys =
                  OnboardingHelperIds.normalizeCompletedHelperKeys({
                    ...progress.seenHelpers,
                    ...remoteKeys,
                    ...memoryKeys,
                  });
              final mergedProgress = progress.copyWith(seenHelpers: mergedKeys);
              if (!setEquals(progress.seenHelpers, mergedKeys) ||
                  remoteKeys.isNotEmpty) {
                await _localStorage.saveLocal(trimmedUserId, mergedProgress);
              }
              _localCompletionKeys[trimmedUserId] =
                  setEquals(localKeys, mergedKeys) ? localKeys : mergedKeys;
              _cloudCompletionKeys[trimmedUserId] = remoteKeys;
              _states[trimmedUserId] = _OnboardingHelperUserState(
                hydrationState: OnboardingHelperHydrationState.ready,
                progress: mergedProgress,
              );
              _notifyListenersSafely();
              return mergedProgress;
            })()
            .catchError((Object error) {
              debugPrint(
                '[OnboardingHelperCompletionService] Failed to hydrate helpers: $error',
              );
              final progress =
                  (_states[trimmedUserId]?.progress ??
                          const OnboardingProgress())
                      .copyWith(
                        seenHelpers:
                            _memoryCompletionKeys[trimmedUserId] ??
                            const <String>{},
                      );
              _localCompletionKeys[trimmedUserId] = progress.seenHelpers;
              _states[trimmedUserId] = _OnboardingHelperUserState(
                hydrationState: OnboardingHelperHydrationState.ready,
                progress: progress,
              );
              _notifyListenersSafely();
              return progress;
            })
            .whenComplete(() {
              if (identical(_hydrationFutures[trimmedUserId], hydration)) {
                _hydrationFutures.remove(trimmedUserId);
              }
            });
    _hydrationFutures[trimmedUserId] = hydration;
    return hydration;
  }

  Future<OnboardingProgress> markHelperCompleted(
    String userId,
    String helperId,
  ) {
    final trimmedUserId = userId.trim();
    final completionKeys = OnboardingHelperIds.completionKeysFor(helperId);
    if (trimmedUserId.isEmpty || completionKeys.isEmpty) {
      return Future<OnboardingProgress>.value(
        _states[trimmedUserId]?.progress ?? const OnboardingProgress(),
      );
    }

    _completeInMemory(trimmedUserId, completionKeys);

    final previous =
        _completionQueues[trimmedUserId] ??
        Future<OnboardingProgress>.value(
          _states[trimmedUserId]?.progress ?? const OnboardingProgress(),
        );

    late final Future<OnboardingProgress> current;
    current = previous
        .catchError(
          (_) => _states[trimmedUserId]?.progress ?? const OnboardingProgress(),
        )
        .then((_) async {
          final progress = await _localStorage.loadLocal(trimmedUserId);
          final memoryKeys =
              _memoryCompletionKeys[trimmedUserId] ?? const <String>{};
          final mergedKeys = OnboardingHelperIds.normalizeCompletedHelperKeys({
            ...progress.seenHelpers,
            ...memoryKeys,
          });
          final updated = progress.copyWith(seenHelpers: mergedKeys);
          await _localStorage.saveLocal(trimmedUserId, updated);
          _localCompletionKeys[trimmedUserId] = mergedKeys;
          await _remoteStore.markCompleted(trimmedUserId, completionKeys);
          _cloudCompletionKeys[trimmedUserId] =
              OnboardingHelperIds.normalizeCompletedHelperKeys({
                ...?_cloudCompletionKeys[trimmedUserId],
                ...completionKeys,
              });
          final existingState = _states[trimmedUserId];
          _states[trimmedUserId] = _OnboardingHelperUserState(
            hydrationState:
                existingState?.hydrationState ??
                OnboardingHelperHydrationState.unknown,
            progress: updated,
          );
          _notifyListenersSafely();
          return updated;
        })
        .whenComplete(() {
          if (identical(_completionQueues[trimmedUserId], current)) {
            _completionQueues.remove(trimmedUserId);
          }
        });

    _completionQueues[trimmedUserId] = current;
    return current;
  }

  void _completeInMemory(String userId, Set<String> completionKeys) {
    final normalized = OnboardingHelperIds.normalizeCompletedHelperKeys(
      completionKeys,
    );
    if (normalized.isEmpty) return;
    final memoryKeys = _memoryCompletionKeys.putIfAbsent(
      userId,
      () => <String>{},
    );
    final beforeMemoryCount = memoryKeys.length;
    memoryKeys.addAll(normalized);

    final existingState = _states[userId];
    final currentProgress =
        existingState?.progress ?? const OnboardingProgress();
    final mergedKeys = OnboardingHelperIds.normalizeCompletedHelperKeys({
      ...currentProgress.seenHelpers,
      ...normalized,
    });
    final updatedProgress = currentProgress.copyWith(seenHelpers: mergedKeys);
    _states[userId] = _OnboardingHelperUserState(
      hydrationState:
          existingState?.hydrationState ??
          OnboardingHelperHydrationState.unknown,
      progress: updatedProgress,
    );
    if (memoryKeys.length != beforeMemoryCount ||
        !setEquals(currentProgress.seenHelpers, mergedKeys)) {
      _notifyListenersSafely();
    }
  }

  void _notifyListenersSafely() {
    if (_isDisposed) return;
    final scheduler = SchedulerBinding.instance;
    if (scheduler.schedulerPhase == SchedulerPhase.idle) {
      notifyListeners();
      return;
    }
    if (_notificationScheduled) return;
    _notificationScheduled = true;
    scheduler.addPostFrameCallback((_) {
      _notificationScheduled = false;
      if (_isDisposed) return;
      notifyListeners();
    });
  }
}

bool hasCompletedProfileBasics({
  required Iterable<String> avatarGlyphIds,
  String? displayName,
  String? handle,
}) {
  final hasGlyphAvatar = avatarGlyphIds.any((id) => id.trim().isNotEmpty);
  final hasDisplayName = displayName?.trim().isNotEmpty ?? false;
  final hasHandle = handle?.trim().isNotEmpty ?? false;
  return hasGlyphAvatar && (hasDisplayName || hasHandle);
}
