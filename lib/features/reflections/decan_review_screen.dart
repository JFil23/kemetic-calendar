import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/navigation_fallback.dart';
import '../../data/account_operation_fence.dart';
import '../../data/decan_reflection_model.dart';
import '../../data/flows_repo.dart';
import '../calendar/calendar_page.dart';
import '../nodes/kemetic_node_library.dart';
import 'decan_review_controller.dart';
import 'decan_review_models.dart';
import 'decan_review_views.dart';
import 'decan_review_widgets.dart';

/// The review renderer owned by DecanReflectionDetailPage, regardless of entry.
class DecanReviewScreen extends StatefulWidget {
  const DecanReviewScreen({
    super.key,
    required this.window,
    this.reflection,
    this.compose = false,
    this.controllerForTesting,
  });
  final DecanReviewWindow window;
  final DecanReflection? reflection;
  final bool compose;
  final DecanReviewController? controllerForTesting;
  @override
  State<DecanReviewScreen> createState() => _DecanReviewScreenState();
}

class _DecanReviewScreenState extends State<DecanReviewScreen> {
  late final c =
      widget.controllerForTesting ??
      DecanReviewController(
        client: Supabase.instance.client,
        window: widget.window,
        initialReflection: widget.reflection,
      );
  final answer = TextEditingController(),
      own = TextEditingController(),
      post = TextEditingController();
  bool _redirected = false;
  @override
  void initState() {
    super.initState();
    c.addListener(_update);
    unawaited(
      c.initialize().then((_) {
        if (mounted && widget.compose && !c.loading && c.review != null)
          c.preparePost();
      }),
    );
  }

  void _update() {
    if (!mounted) return;
    if (answer.text != c.answer)
      answer.value = TextEditingValue(
        text: c.answer,
        selection: TextSelection.collapsed(offset: c.answer.length),
      );
    if (own.text != c.ownMoment) own.text = c.ownMoment;
    if (post.text != c.postText) post.text = c.postText;
    setState(() {});
    if (!_redirected &&
        widget.reflection == null &&
        c.reflection != null &&
        !c.loading) {
      _redirected = true;
      // Replace the creation URL with the persisted identity for reload/restore.
      final router = GoRouter.maybeOf(context);
      if (router != null) router.replace('/reflections/${c.reflection!.id}');
    }
  }

  @override
  void dispose() {
    c.removeListener(_update);
    c.dispose();
    answer.dispose();
    own.dispose();
    post.dispose();
    super.dispose();
  }

  void _done() => popOrGo(context, '/');
  Future<void> _openJournal() async {
    final entry = c.journalEntry;
    if (entry == null) {
      _message('Your words have not been saved to Journal yet.');
      return;
    }
    await openDetailRoute(context, '/journal/entry/${entry.id}');
    if (mounted) await c.refreshSavedVersion();
  }

  void _message(String text) => ScaffoldMessenger.maybeOf(
    context,
  )?.showSnackBar(SnackBar(content: Text(text)));
  Future<void> _openMoment(DecanMoment moment) async {
    final client = Supabase.instance.client;
    final fence = AccountOperationFence(client);
    try {
      if (moment.libraryId != null) {
        final reading = KemeticNodeLibrary.resolve(moment.libraryId!);
        if (reading == null)
          throw StateError('This reading is no longer available.');
        await openDetailRoute(
          context,
          '/nodes/${Uri.encodeComponent(reading.id)}',
        );
      } else if (moment.journalEntryId != null) {
        await openDetailRoute(
          context,
          '/journal/entry/${moment.journalEntryId}',
        );
      } else if (moment.flowId != null) {
        final row = await FlowsRepo(client).getFlowById(moment.flowId!);
        if (!mounted || !fence.isCurrent) return;
        if (row == null || row.userId != fence.userId)
          throw StateError('This flow is no longer available.');
        await CalendarPage.openFlowStudioFromAnyContext(
          context,
          restorationState: {'mode': 'myFlows', 'initialFlowId': row.id},
        );
      } else if (moment.flowKey != null) {
        await CalendarPage.openFlowStudioFromAnyContext(
          context,
          restorationState: {
            'mode': 'maatTemplate',
            'templateKey': moment.flowKey,
          },
        );
      }
    } catch (_) {
      if (mounted)
        _message(
          'This source could not be opened. Your selected moment is kept.',
        );
    } finally {
      fence.dispose();
    }
  }

  Future<void> _openSuggestion(DecanContinuation item) => _openMoment(
    DecanMoment(
      id: item.id,
      kind: 'suggestion',
      sourceId: item.id,
      occurredOn: null,
      sourceLabel: item.title,
      actionLabel: 'Explore',
      text: item.title,
      libraryId: item.libraryId,
      flowKey: item.flowKey,
    ),
  );
  @override
  Widget build(BuildContext context) {
    Widget body;
    if (c.accountChanged) {
      body = DecanReviewCanvas(
        children: [
          const DecanReviewIntro(eyebrow: 'Reflection', title: 'Sign in again'),
          const DecanReviewNotice(
            'Your draft is kept for the account that wrote it.',
          ),
          DecanReviewButton('Close', onPressed: _done),
        ],
      );
    } else if (c.review == null) {
      body = DecanReviewCanvas(
        children: [
          const DecanReviewIntro(
            eyebrow: 'As the decan closes',
            title: 'These ten days',
            subtitle: 'A few moments to return to.',
          ),
          if (c.loading)
            const Center(
              child: CircularProgressIndicator(
                color: DecanReviewStyle.gold,
                strokeWidth: 1.5,
              ),
            )
          else ...[
            DecanReviewNotice(c.error ?? 'Could not open this reflection.'),
            DecanReviewButton(
              'Try again',
              onPressed: () => unawaited(c.initialize()),
              primary: true,
            ),
          ],
          DecanReviewButton('Close', onPressed: _done, quiet: true),
        ],
      );
    } else {
      switch (c.stage) {
        case DecanReviewStage.review:
        case DecanReviewStage.writing:
          body = DecanReviewOpening(
            moments: c.selectedMoments,
            decanStart: c.window.start,
            question: c.review!.question,
            onChoose: () => c.show(DecanReviewStage.choosing),
            onWrite: () => c.show(DecanReviewStage.writing),
            onReadSaved: c.savedAnswer.isEmpty
                ? null
                : () => c.show(DecanReviewStage.saved),
            onRestore: c.sourceDeleted
                ? () => unawaited(c.saveAnswer(restore: true))
                : null,
            onLeave: () => unawaited(c.leaveOpen()),
            onOpenMoment: (m) => unawaited(_openMoment(m)),
            answerController: c.stage == DecanReviewStage.writing
                ? answer
                : null,
            onAnswerChanged: c.changeAnswer,
            onSave: () => unawaited(c.saveAnswer()),
            saving: c.busy || c.loading,
            pending: c.notice != null,
            notice: c.notice,
            onReviewSaved: c.notice == null
                ? null
                : () => unawaited(
                    c.error != null ? c.initialize() : c.refreshSavedVersion(),
                  ),
          );
        case DecanReviewStage.choosing:
          body = DecanReviewChooser(
            moments: c.items.values.where((m) => !m.isOwn).toList(),
            selectedIds: c.selected,
            onToggle: c.toggle,
            onOpen: (m) => unawaited(_openMoment(m)),
            ownController: own,
            onOwnChanged: c.changeOwn,
            onKeep: () => unawaited(c.keepMoments()),
            onBack: () => c.show(DecanReviewStage.review),
            onMore: c.hasMore ? () => unawaited(c.moreMoments()) : null,
            onJournal: () => unawaited(c.moreMoments(journal: true)),
            onPrivateReading: () => unawaited(c.choosePrivateReadingNotes()),
            onRecovery: () => unawaited(c.findPreservedDrafts()),
            loading: c.busy,
            notice: c.notice,
          );
        case DecanReviewStage.saved:
          body = DecanReviewSaved(
            response: c.savedAnswer,
            question: c.review!.question,
            onJournal: () => unawaited(_openJournal()),
            onPost: c.preparePost,
            onDone: _done,
            onExplore: () => unawaited(c.explore()),
            notice: c.notice,
          );
        case DecanReviewStage.publishing:
          final reading = c.readingId == null
              ? null
              : KemeticNodeLibrary.resolve(c.readingId!);
          body = DecanReviewPublish(
            controller: post,
            onChanged: c.changePost,
            question: c.review!.question,
            includeQuestion: c.includeQuestion,
            onQuestionChanged: (v) => c.changePostOptions(question: v),
            author: c.post?.authorLabel ?? 'You',
            handle: c.post?.authorHandle,
            onPublish: c.post?.isHidden == true
                ? null
                : () => unawaited(c.publish()),
            onReviewPublished: () => unawaited(c.refreshPublishedVersion()),
            onBack: () => c.show(DecanReviewStage.saved),
            readingTitle: reading?.title,
            includeReading: c.includeReading,
            onReadingChanged: (v) => c.changePostOptions(reading: v),
            saving: c.busy,
            editing: c.post != null,
            notice: c.notice,
          );
        case DecanReviewStage.posted:
          body = DecanReviewCanvas(
            privacy: 'Community',
            children: [
              const DecanReviewIntro(
                eyebrow: 'Your profile & feed',
                title: 'A shared reflection',
                subtitle: 'Published by you.',
                compact: true,
              ),
              if (c.post != null)
                DecanPublicReflectionCard(
                  author: c.post!.authorLabel,
                  handle: c.post!.authorHandle,
                  body: c.post!.bodyText,
                  question: c.post!.questionText,
                  readingTitle: c.post!.readingLink?['title'] as String?,
                  onReading: c.post!.readingLink == null
                      ? null
                      : () => unawaited(
                          openDetailRoute(
                            context,
                            '/nodes/${c.post!.readingLink!['slug']}',
                          ),
                        ),
                ),
              if (c.notice != null) DecanReviewNotice(c.notice!),
              DecanReviewButton('Edit post', onPressed: c.preparePost),
              DecanReviewButton(
                'Open private Journal',
                onPressed: () => unawaited(_openJournal()),
                quiet: true,
              ),
              DecanReviewButton(
                'Remove post',
                onPressed: () => unawaited(c.removePost()),
                quiet: true,
                busy: c.busy,
              ),
              DecanReviewButton('Done', onPressed: _done, quiet: true),
              const DecanReviewFooter('Your Journal keeps its own words.'),
            ],
          );
        case DecanReviewStage.recovery:
          body = DecanReviewCanvas(
            children: [
              const DecanReviewIntro(
                eyebrow: 'Your writing',
                title: 'Preserved drafts',
                subtitle: 'Choose a version to review.',
              ),
              if (c.notice != null) DecanReviewNotice(c.notice!),
              if (!c.busy && c.preservedDrafts.isEmpty)
                const DecanReviewNotice(
                  'No conflicting drafts were found for this reflection.',
                ),
              for (final record in c.preservedDrafts) ...[
                DecanReviewLabel(
                  (record['request'] as Map)['kind'] == 'post'
                      ? 'Words to post'
                      : (record['request'] as Map)['kind'] == 'review'
                      ? 'Selected moments'
                      : 'Journal words',
                ),
                if ((record['request'] as Map)['kind'] != 'review')
                  DecanReviewWords(
                    ((record['request'] as Map)['words'] ??
                            (record['request'] as Map)['body'] ??
                            '')
                        .toString(),
                  ),
                DecanReviewButton(
                  'Review this draft',
                  onPressed: c.busy
                      ? null
                      : () => unawaited(c.usePreservedDraft(record)),
                ),
              ],
              DecanReviewButton(
                'Try again',
                onPressed: c.busy
                    ? null
                    : () => unawaited(c.findPreservedDrafts()),
                quiet: true,
              ),
              DecanReviewButton(
                'Back to reflection',
                onPressed: () => c.show(DecanReviewStage.review),
                quiet: true,
              ),
            ],
          );
        case DecanReviewStage.continuation:
          body = DecanReviewContinuation(
            suggestions: c.suggestions,
            notice: c.notice,
            onRetry: c.busy ? null : () => unawaited(c.explore()),
            onOpen: (s) => unawaited(_openSuggestion(s)),
            onDismiss: (s) => unawaited(c.dismissSuggestion(s)),
            onDone: _done,
          );
      }
    }
    return Scaffold(
      backgroundColor: DecanReviewStyle.base,
      resizeToAvoidBottomInset: false,
      body: body,
    );
  }
}
