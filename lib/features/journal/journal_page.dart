import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/navigation_fallback.dart';
import '../../main.dart' show Events;
import 'package:mobile/features/onboarding/guided_onboarding_overlay.dart';
import '../onboarding/onboarding_progress.dart';
import 'journal_controller.dart';
import 'journal_overlay.dart';

class JournalPage extends StatefulWidget {
  const JournalPage({
    super.key,
    required this.controller,
    this.entryPoint = 'page_button',
  });

  final JournalController controller;
  final String entryPoint;

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
    final storage = OnboardingProgressStorage();
    if (!await storage.shouldShowHelper(
      userId,
      OnboardingHelperIds.journalBadges,
    )) {
      return;
    }
    _helperPrompted = true;
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    if (!await storage.shouldShowHelper(
      userId,
      OnboardingHelperIds.journalBadges,
    )) {
      return;
    }
    GuidedOnboardingController.instance.show(
      CoachmarkTarget(
        key: _journalHelperKey,
        title: 'Your record gathers here',
        body:
            'Reflections, observed events, and journal badges will appear here over time.',
        placement: CoachmarkPlacement.auto,
        variant: CoachmarkVariant.helperBubble,
        showDismissButton: true,
        dismissLabel: 'Got it',
        onDismiss: () async {
          GuidedOnboardingController.instance.clear();
          await storage.markHelperCompleted(
            userId,
            OnboardingHelperIds.journalBadges,
          );
          await Events.trackIfAuthed(
            'helper_seen_journal_badges',
            const <String, dynamic>{},
          );
        },
      ),
    );
    await storage.markHelperCompleted(
      userId,
      OnboardingHelperIds.journalBadges,
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
      onClose: () => popOrGo(context, '/'),
    );
  }
}
