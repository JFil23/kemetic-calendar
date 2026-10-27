import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/features/ask_haw/ask_haw_onboarding_helper.dart';
import 'package:mobile/features/onboarding/guided_onboarding_overlay.dart';
import 'package:mobile/features/onboarding/onboarding_progress.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Remote remote;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    remote = _Remote();
    GuidedOnboardingController.instance.clear();
    OnboardingHelperCompletionService.resetForTesting(remoteStore: remote);
  });
  tearDown(() => GuidedOnboardingController.instance.clear());

  test(
    'only the approved helper becomes eligible after hydrated completion',
    () async {
      final service = OnboardingHelperCompletionService.instance;
      const id = OnboardingHelperIds.askHawQuickAdd;
      expect(service.shouldShowHelperSync('a', id), isFalse);
      await service.hydrateUser('a');
      expect(service.shouldShowHelperSync('a', id), isFalse);
      await OnboardingProgressStorage().save(
        'a',
        const OnboardingProgress().copyWith(completedOnboarding: true),
      );
      await service.hydrateUser('a', force: true);
      expect(service.shouldShowHelperSync('a', id), isTrue);
      for (final legacy in OnboardingHelperIds.all.where(
        (value) => value != id,
      )) {
        expect(
          service.shouldShowHelperSync('a', legacy),
          isFalse,
          reason: legacy,
        );
      }
      expect(service.shouldShowHelperSync('b', id), isFalse);
    },
  );

  test(
    'opening + consumes helper immediately and survives a new service',
    () async {
      await OnboardingProgressStorage().save(
        'a',
        const OnboardingProgress().copyWith(completedOnboarding: true),
      );
      final service = OnboardingHelperCompletionService.instance;
      await service.hydrateUser('a');
      const id = OnboardingHelperIds.askHawQuickAdd;
      expect(service.shouldShowHelperSync('a', id), isTrue);
      final acknowledgement = Completer<void>();
      remote.acknowledgement = acknowledgement;
      final consumed = AskHawOnboardingHelper.consume('a');
      expect(service.shouldShowHelperSync('a', id), isFalse);
      acknowledgement.complete();
      await consumed;
      await AskHawOnboardingHelper.consume('a');
      expect(
        remote.writes,
        1,
        reason: 'Repeated + entries must not repeat marker writes.',
      );
      OnboardingHelperCompletionService.resetForTesting(remoteStore: remote);
      expect(
        await OnboardingHelperCompletionService.instance.shouldShowHelper(
          'a',
          id,
        ),
        isFalse,
      );
    },
  );

  test('consumption clears only its account and helper overlay', () async {
    const helper = OnboardingHelperRegistry.askHawQuickAdd;
    GuidedOnboardingController.instance.show(
      CoachmarkTarget(
        title: helper.title,
        body: helper.body,
        helperId: helper.id,
        helperUserId: 'b',
        variant: CoachmarkVariant.helperBubble,
      ),
    );
    await AskHawOnboardingHelper.consume('a');
    expect(GuidedOnboardingController.instance.target?.helperUserId, 'b');
    await AskHawOnboardingHelper.consume('b');
    expect(GuidedOnboardingController.instance.target, isNull);
  });
}

class _Remote implements OnboardingHelperCompletionRemoteStore {
  final completed = <String, Set<String>>{};
  Completer<void>? acknowledgement;
  int writes = 0;
  @override
  Future<Set<String>> loadCompletedHelperKeys(String userId) async =>
      completed[userId] ?? {};
  @override
  Future<void> markCompleted(
    String userId,
    Iterable<String> completionKeys,
  ) async {
    writes++;
    await acknowledgement?.future;
    completed.putIfAbsent(userId, () => {}).addAll(completionKeys);
  }
}
