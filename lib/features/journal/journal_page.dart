import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/navigation_fallback.dart';
import '../../main.dart' show Events;
import 'package:mobile/features/calendar/calendar_reflection_context.dart';
import 'package:mobile/features/onboarding/guided_onboarding_overlay.dart';
import '../onboarding/onboarding_progress.dart';
import 'journal_controller.dart';
import 'journal_overlay.dart';

class JournalPage extends StatefulWidget {
  const JournalPage({
    super.key,
    required this.controller,
    this.entryPoint = 'page_button',
    this.reflectionContext,
  });

  final JournalController controller;
  final String entryPoint;
  final CalendarReflectionContext? reflectionContext;

  @override
  State<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage> {
  final GlobalKey _journalHelperKey = GlobalKey(
    debugLabel: 'journal_badges_helper',
  );
  bool _trackedOpen = false;
  bool _helperPrompted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_trackedOpen) return;

    final orientation = MediaQuery.of(context).orientation;
    Events.trackIfAuthed('journal_opened', {
      'entry_point': widget.entryPoint,
      'orientation': orientation == Orientation.portrait
          ? 'portrait'
          : 'landscape',
      'presentation': 'page',
    });
    _trackedOpen = true;
    _maybeShowJournalHelper();
  }

  Future<void> _maybeShowJournalHelper() async {
    if (_helperPrompted) return;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) return;
    const helper = OnboardingHelperRegistry.journalBadges;
    final helperService = OnboardingHelperCompletionService.instance;
    if (!await helperService.shouldShowHelper(userId, helper.id)) {
      return;
    }
    _helperPrompted = true;
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    await helperService.hydrateUser(userId);
    if (!mounted || !helperService.shouldShowHelperSync(userId, helper.id)) {
      return;
    }
    GuidedOnboardingController.instance.show(
      CoachmarkTarget(
        key: _journalHelperKey,
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

  @override
  Widget build(BuildContext context) {
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;

    return JournalOverlay(
      controller: widget.controller,
      isPortrait: isPortrait,
      presentationMode: JournalPresentationMode.page,
      badgeAreaKey: _journalHelperKey,
      reflectionContext: widget.reflectionContext,
      onClose: () => popOrGo(context, '/'),
    );
  }
}
