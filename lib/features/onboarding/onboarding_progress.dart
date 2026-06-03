import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
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
  final Map<String, Set<String>> _memoryCompletionKeys =
      <String, Set<String>>{};
  final Map<String, Future<OnboardingProgress>> _hydrationFutures =
      <String, Future<OnboardingProgress>>{};
  final Map<String, Future<OnboardingProgress>> _completionQueues =
      <String, Future<OnboardingProgress>>{};

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
    if (state.progress == merged) return;
    _states[trimmedUserId] = state.copyWith(progress: merged);
    notifyListeners();
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
    notifyListeners();

    late final Future<OnboardingProgress> hydration;
    hydration =
        (() async {
              var progress = await _localStorage.loadLocal(trimmedUserId);
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
              _states[trimmedUserId] = _OnboardingHelperUserState(
                hydrationState: OnboardingHelperHydrationState.ready,
                progress: mergedProgress,
              );
              notifyListeners();
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
              _states[trimmedUserId] = _OnboardingHelperUserState(
                hydrationState: OnboardingHelperHydrationState.ready,
                progress: progress,
              );
              notifyListeners();
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
          await _remoteStore.markCompleted(trimmedUserId, completionKeys);
          final existingState = _states[trimmedUserId];
          _states[trimmedUserId] = _OnboardingHelperUserState(
            hydrationState:
                existingState?.hydrationState ??
                OnboardingHelperHydrationState.unknown,
            progress: updated,
          );
          notifyListeners();
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
      notifyListeners();
    }
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
