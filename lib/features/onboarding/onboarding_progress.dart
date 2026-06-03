import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  static const String calendarToggle = 'calendarToggle';
  static const String monthDetails = 'monthDetails';
  static const String dayCardLongPress = 'dayCardLongPress';
  static const String journalBadges = 'journalBadges';
  static const String flowBuilder = 'flowBuilder';
  static const String profileCommunityFeed = 'profileCommunityFeed';
  static const String settingsControl = 'settingsControl';

  static const Set<String> all = {
    calendarToggle,
    monthDetails,
    dayCardLongPress,
    journalBadges,
    flowBuilder,
    profileCommunityFeed,
    settingsControl,
  };
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
    return copyWith(seenHelpers: {...seenHelpers, helperId});
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
        ? rawHelpers.whereType<String>().toSet()
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
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyForUser(userId), jsonEncode(progress.toJson()));
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
    final progress = await load(userId);
    return progress.completedOnboarding &&
        !progress.seenHelpers.contains(helperId);
  }

  Future<OnboardingProgress> markHelperCompleted(
    String userId,
    String helperId,
  ) {
    final queueKey = _keyForUser(userId);
    final completer = Completer<OnboardingProgress>();
    final previous = _helperCompletionQueues[queueKey] ?? Future<void>.value();

    late final Future<void> current;
    current = previous
        .catchError((_) {})
        .then((_) async {
          final progress = await load(userId);
          if (progress.seenHelpers.contains(helperId)) {
            completer.complete(progress);
            return;
          }
          final updated = progress.markHelperSeen(helperId);
          await save(userId, updated);
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
