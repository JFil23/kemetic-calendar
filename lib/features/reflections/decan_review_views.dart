import 'package:flutter/material.dart';
import 'decan_review_models.dart';
import 'decan_review_widgets.dart';

class DecanReviewOpening extends StatelessWidget {
  const DecanReviewOpening({
    super.key,
    required this.moments,
    required this.decanStart,
    required this.question,
    required this.onChoose,
    required this.onWrite,
    required this.onLeave,
    required this.onOpenMoment,
    this.answerController,
    this.onAnswerChanged,
    this.onSave,
    this.saving = false,
    this.pending = false,
    this.notice,
    this.onReviewSaved,
    this.onReadSaved,
    this.onRestore,
  });
  final List<DecanMoment> moments;
  final DateTime decanStart;
  final String question;
  final VoidCallback onChoose;
  final VoidCallback onWrite;
  final VoidCallback onLeave;
  final ValueChanged<DecanMoment> onOpenMoment;
  final TextEditingController? answerController;
  final ValueChanged<String>? onAnswerChanged;
  final VoidCallback? onSave;
  final bool saving;
  final bool pending;
  final String? notice;
  final VoidCallback? onReviewSaved, onReadSaved, onRestore;

  @override
  Widget build(BuildContext context) => DecanReviewCanvas(
    children: [
      DecanReviewIntro(
        eyebrow: 'As the decan closes',
        title: 'These ten days',
        subtitle: moments.isEmpty
            ? 'There is room for what went unrecorded.'
            : 'A few moments to return to.',
      ),
      DecanReviewRule(
        days: moments.map((m) => m.dayIn(decanStart)).whereType<int>().toSet(),
      ),
      if (moments.isEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 40, 8, 26),
          child: Text(
            'You can begin with whatever stayed with you.',
            textAlign: TextAlign.center,
            style: DecanReviewStyle.serif(24, color: DecanReviewStyle.soft),
          ),
        ),
      for (var i = 0; i < moments.length; i++)
        DecanMomentTile(
          moment: moments[i],
          decanStart: decanStart,
          showRule: i > 0,
          onOpen: moments[i].hasDestination
              ? () => onOpenMoment(moments[i])
              : null,
        ),
      TextButton(
        onPressed: onChoose,
        style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
        child: Text(
          moments.isEmpty ? 'Add a moment of your own' : 'Choose moments',
          style: DecanReviewStyle.ui(12.5).copyWith(
            decoration: TextDecoration.underline,
            decorationColor: DecanReviewStyle.strongLine,
          ),
        ),
      ),
      DecanReviewQuestion(question),
      if (notice != null && answerController == null)
        DecanReviewNotice(notice!),
      if (answerController != null) ...[
        const SizedBox(height: 34),
        DecanReviewTextField(
          controller: answerController!,
          label: 'Your words',
          onChanged: onAnswerChanged,
        ),
        if (notice != null) DecanReviewNotice(notice!),
        if (onReviewSaved != null)
          DecanReviewButton(
            'Review saved version',
            onPressed: onReviewSaved,
            quiet: true,
          ),
        if (onRestore != null)
          DecanReviewButton(
            'Add these words to Journal again',
            onPressed: onRestore,
            primary: true,
            busy: saving,
          )
        else
          DecanReviewButton(
            pending ? 'Retry Journal save' : 'Keep in Journal',
            onPressed: onSave,
            primary: true,
            busy: saving,
          ),
      ] else
        DecanReviewButton(
          onReadSaved == null
              ? 'Leave a few words  →'
              : 'Read your saved reflection  →',
          onPressed: onReadSaved ?? onWrite,
          primary: true,
        ),
      if (onReadSaved != null && answerController == null)
        DecanReviewButton('Edit your words', onPressed: onWrite, quiet: true),
      DecanReviewButton(
        'Leave the question open',
        onPressed: onLeave,
        quiet: true,
      ),
      const DecanReviewFooter('One decan ends. Another begins.'),
    ],
  );
}

class DecanReviewTextField extends StatelessWidget {
  const DecanReviewTextField({
    super.key,
    required this.controller,
    required this.label,
    this.onChanged,
    this.minLines = 3,
    this.autofocus = false,
  });
  final TextEditingController controller;
  final String label;
  final ValueChanged<String>? onChanged;
  final int minLines;
  final bool autofocus;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(label, style: DecanReviewStyle.ui(11)),
      const SizedBox(height: 10),
      TextField(
        controller: controller,
        onChanged: onChanged,
        autofocus: autofocus,
        minLines: minLines,
        maxLines: null,
        maxLength: 12000,
        keyboardType: TextInputType.multiline,
        textCapitalization: TextCapitalization.sentences,
        style: DecanReviewStyle.serif(24, height: 1.38),
        cursorColor: DecanReviewStyle.gold,
        decoration: InputDecoration(
          labelText: null,
          counterText: '',
          isDense: true,
          contentPadding: const EdgeInsets.only(top: 4, bottom: 16),
          hintText: 'A thought, a sentence, or just a word…',
          hintStyle: DecanReviewStyle.serif(
            24,
            italic: true,
            color: DecanReviewStyle.quiet,
            height: 1.38,
          ),
          enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: DecanReviewStyle.strongLine),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: DecanReviewStyle.gold),
          ),
        ),
      ),
    ],
  );
}

class DecanReviewSaved extends StatelessWidget {
  const DecanReviewSaved({
    super.key,
    required this.response,
    required this.question,
    required this.onJournal,
    required this.onPost,
    required this.onDone,
    this.onExplore,
    this.notice,
  });
  final String response;
  final String? notice;
  final String question;
  final VoidCallback onJournal;
  final VoidCallback onPost;
  final VoidCallback onDone;
  final VoidCallback? onExplore;
  @override
  Widget build(BuildContext context) => DecanReviewCanvas(
    children: [
      const DecanReviewIntro(
        eyebrow: 'Decan reflection',
        title: 'Kept in Journal',
        subtitle: 'Your words have a place to return to.',
      ),
      const DecanReviewLabel('From these ten days'),
      DecanReviewWords(response),
      Text(
        question,
        style: DecanReviewStyle.serif(
          18,
          italic: true,
          color: DecanReviewStyle.muted,
          height: 1.45,
        ),
      ),
      if (notice != null) DecanReviewNotice(notice!),
      DecanReviewButton('Open Journal  →', onPressed: onJournal, primary: true),
      DecanReviewButton('Post reflection', onPressed: onPost),
      DecanReviewButton('Done', onPressed: onDone, quiet: true),
      if (onExplore != null)
        DecanReviewButton(
          'Something to explore',
          onPressed: onExplore,
          quiet: true,
        ),
      const DecanReviewFooter('Sharing is always your choice.'),
    ],
  );
}

/// The same source contribution is rendered by Journal's canonical owner.
/// It receives preceding blocks from the existing document renderer, so drawings
/// and unrelated formatting are not flattened to reflection text.
class DecanJournalContribution extends StatelessWidget {
  const DecanJournalContribution({
    super.key,
    required this.response,
    required this.question,
    required this.rangeLabel,
    required this.days,
    required this.onReflection,
    required this.onEdit,
    this.onPost,
    this.answerController,
    this.onAnswerChanged,
    this.onSave,
    this.saving = false,
    this.pending = false,
    this.notice,
  });
  final String response;
  final String question;
  final String rangeLabel;
  final Set<int> days;
  final VoidCallback onReflection;
  final VoidCallback onEdit;
  final VoidCallback? onPost;
  final TextEditingController? answerController;
  final ValueChanged<String>? onAnswerChanged;
  final VoidCallback? onSave;
  final bool saving;
  final bool pending;
  final String? notice;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          DecanReviewSeal(days: days, size: 22),
          const SizedBox(width: 10),
          Expanded(child: DecanReviewLabel('Decan reflection · $rangeLabel')),
        ],
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          question,
          style: DecanReviewStyle.serif(
            18,
            italic: true,
            color: DecanReviewStyle.muted,
            height: 1.45,
          ),
        ),
      ),
      if (answerController != null) ...[
        DecanReviewTextField(
          controller: answerController!,
          label: 'Your reflection',
          minLines: 4,
          onChanged: onAnswerChanged,
        ),
        DecanReviewButton(
          pending ? 'Retry Journal save' : 'Save Journal changes',
          onPressed: onSave,
          primary: true,
          busy: saving,
        ),
      ] else ...[
        Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 6),
          child: Text(
            response,
            style: DecanReviewStyle.serif(26, height: 1.38),
          ),
        ),
        DecanReviewButton('Edit these words', onPressed: onEdit, quiet: true),
      ],
      Padding(
        padding: const EdgeInsets.only(top: 14),
        child: OutlinedButton(
          onPressed: onReflection,
          style: OutlinedButton.styleFrom(
            alignment: Alignment.centerLeft,
            minimumSize: const Size.fromHeight(50),
            side: const BorderSide(color: DecanReviewStyle.line),
            backgroundColor: const Color(0x05FFFFFF),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Return to the selected moments',
                  style: DecanReviewStyle.ui(13, color: DecanReviewStyle.soft),
                ),
              ),
              const Icon(
                Icons.north_east,
                size: 15,
                color: DecanReviewStyle.muted,
              ),
            ],
          ),
        ),
      ),
      if (notice != null) DecanReviewNotice(notice!),
      if (onPost != null)
        DecanReviewButton('Post reflection', onPressed: onPost),
    ],
  );
}

class DecanReviewContinuation extends StatelessWidget {
  const DecanReviewContinuation({
    super.key,
    required this.suggestions,
    required this.onOpen,
    required this.onDismiss,
    required this.onDone,
    this.notice,
    this.onRetry,
  });
  final List<DecanContinuation> suggestions;
  final ValueChanged<DecanContinuation> onOpen;
  final ValueChanged<DecanContinuation> onDismiss;
  final VoidCallback onDone;
  final String? notice;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => DecanReviewCanvas(
    children: [
      const DecanReviewIntro(
        eyebrow: 'An optional next step',
        title: 'Something to explore',
        subtitle: 'Follow what holds your attention.',
      ),
      if (notice != null) ...[
        DecanReviewNotice(notice!),
        DecanReviewButton(
          'Try suggestions again',
          onPressed: onRetry,
          quiet: true,
        ),
      ],
      for (final item in suggestions)
        DecanContinuationTile(
          suggestion: item,
          onOpen: () => onOpen(item),
          onDismiss: () => onDismiss(item),
        ),
      if (suggestions.isEmpty)
        Text(
          'There is no need to choose anything more.',
          textAlign: TextAlign.center,
          style: DecanReviewStyle.serif(24, color: DecanReviewStyle.soft),
        ),
      DecanReviewButton('Leave it here', onPressed: onDone, quiet: true),
    ],
  );
}

/// The chooser doubles as the paged activity browser. Loaded pages are supplied
/// by the account repository; a failed page is explicitly retryable.
class DecanReviewChooser extends StatelessWidget {
  const DecanReviewChooser({
    super.key,
    required this.moments,
    required this.selectedIds,
    required this.onToggle,
    required this.onOpen,
    required this.ownController,
    required this.onOwnChanged,
    required this.onKeep,
    required this.onBack,
    this.onMore,
    this.onJournal,
    this.onPrivateReading,
    this.onRecovery,
    this.loading = false,
    this.notice,
  });
  final List<DecanMoment> moments;
  final Set<String> selectedIds;
  final ValueChanged<DecanMoment> onToggle, onOpen;
  final TextEditingController ownController;
  final ValueChanged<String> onOwnChanged;
  final VoidCallback onKeep, onBack;
  final VoidCallback? onMore, onJournal, onPrivateReading, onRecovery;
  final bool loading;
  final String? notice;
  @override
  Widget build(BuildContext context) => DecanReviewCanvas(
    children: [
      DecanReviewButton('‹ Reflection', onPressed: onBack, quiet: true),
      if (onRecovery != null)
        DecanReviewButton(
          'Find preserved drafts',
          onPressed: loading ? null : onRecovery,
          quiet: true,
        ),
      const DecanReviewIntro(
        eyebrow: 'Your selection',
        title: 'What stayed with you?',
        subtitle: 'Choose up to three moments.',
        compact: true,
      ),
      for (final moment in moments)
        DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: DecanReviewStyle.line)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Checkbox(
                  value: selectedIds.contains(moment.id),
                  activeColor: DecanReviewStyle.gold,
                  checkColor: DecanReviewStyle.base,
                  side: const BorderSide(color: DecanReviewStyle.strongLine),
                  onChanged: loading ? null : (_) => onToggle(moment),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DecanReviewLabel(moment.sourceLabel),
                      const SizedBox(height: 6),
                      Text(
                        moment.text,
                        style: DecanReviewStyle.serif(
                          23,
                          italic: moment.isQuote,
                        ),
                      ),
                      Text(moment.actionLabel, style: DecanReviewStyle.ui(11)),
                      if (moment.hasDestination)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: () => onOpen(moment),
                            child: Text(
                              'Open source ↗',
                              style: DecanReviewStyle.ui(12),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      if (notice != null) DecanReviewNotice(notice!),
      if (onMore != null)
        DecanReviewButton(
          'More from these ten days',
          onPressed: onMore,
          busy: loading,
          quiet: true,
        ),
      if (onJournal != null)
        DecanReviewButton(
          'Choose from Journal',
          onPressed: onJournal,
          quiet: true,
        ),
      if (onPrivateReading != null)
        DecanReviewButton(
          'Choose a Reading House note',
          onPressed: loading ? null : onPrivateReading,
          quiet: true,
        ),
      const SizedBox(height: 26),
      DecanReviewTextField(
        controller: ownController,
        label: 'A moment of your own',
        minLines: 2,
        onChanged: onOwnChanged,
      ),
      Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Text(
          'It can be something that happened outside the app.',
          style: DecanReviewStyle.ui(12, height: 1.6),
        ),
      ),
      DecanReviewButton(
        'Keep these moments',
        onPressed: loading ? null : onKeep,
        primary: true,
      ),
    ],
  );
}

class DecanReviewPublish extends StatelessWidget {
  const DecanReviewPublish({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.question,
    required this.includeQuestion,
    required this.onQuestionChanged,
    required this.author,
    this.handle,
    required this.onPublish,
    required this.onBack,
    this.readingTitle,
    this.includeReading = false,
    this.onReadingChanged,
    this.saving = false,
    this.editing = false,
    this.notice,
    this.onReviewPublished,
  });
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String question, author;
  final String? handle, readingTitle, notice;
  final bool includeQuestion, includeReading, saving, editing;
  final ValueChanged<bool> onQuestionChanged;
  final ValueChanged<bool>? onReadingChanged;
  final VoidCallback? onPublish, onReviewPublished;
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) => DecanReviewCanvas(
    children: [
      DecanReviewButton('‹ Reflection', onPressed: onBack, quiet: true),
      DecanReviewIntro(
        eyebrow: 'Your choice',
        title: editing ? 'Edit your post' : 'Share a reflection',
        subtitle: 'Choose the words you want to share.',
        compact: true,
      ),
      Container(
        padding: const EdgeInsets.symmetric(vertical: 17),
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: DecanReviewStyle.line),
            bottom: BorderSide(color: DecanReviewStyle.line),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Your profile & community feed',
              style: DecanReviewStyle.ui(13.5, color: DecanReviewStyle.ink),
            ),
            const SizedBox(height: 2),
            Text(
              'Visible to signed-in members. Your Journal stays private.',
              style: DecanReviewStyle.ui(12.5, height: 1.6),
            ),
          ],
        ),
      ),
      const SizedBox(height: 26),
      DecanReviewTextField(
        controller: controller,
        label: 'Words to post',
        onChanged: onChanged,
      ),
      _DecanReviewCheck(
        label: 'Include the question',
        value: includeQuestion,
        onChanged: onQuestionChanged,
      ),
      if (readingTitle != null && onReadingChanged != null)
        _DecanReviewCheck(
          label: 'Link $readingTitle',
          value: includeReading,
          onChanged: onReadingChanged!,
        ),
      DecanPublicReflectionCard(
        author: author,
        handle: handle,
        body: controller.text,
        question: includeQuestion ? question : null,
        readingTitle: includeReading ? readingTitle : null,
      ),
      if (notice != null) DecanReviewNotice(notice!),
      if (notice != null && onReviewPublished != null)
        DecanReviewButton(
          'Review published version',
          onPressed: saving ? null : onReviewPublished,
          quiet: true,
        ),
      DecanReviewButton(
        editing ? 'Save post' : 'Post reflection',
        onPressed: onPublish,
        primary: true,
        busy: saving,
      ),
      DecanReviewButton('Keep it private', onPressed: onBack, quiet: true),
      const DecanReviewFooter('Your Journal keeps its own words.'),
    ],
  );
}

class _DecanReviewCheck extends StatelessWidget {
  const _DecanReviewCheck({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => onChanged(!value),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Checkbox(
            value: value,
            onChanged: (v) => onChanged(v!),
            activeColor: DecanReviewStyle.gold,
            checkColor: DecanReviewStyle.base,
            side: const BorderSide(color: DecanReviewStyle.strongLine),
          ),
          Expanded(
            child: Text(
              label,
              style: DecanReviewStyle.serif(
                19,
                color: DecanReviewStyle.soft,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
