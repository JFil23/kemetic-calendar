import 'package:flutter/material.dart';
import '../../data/commons_models.dart';

const _profileGoldText = Color(0xFFF1CF7A);
const _profileGoldMid = Color(0xFFE8BE54);
const _profileSerifFont = 'CormorantGaramond';
const _profileSerifFallback = ['GentiumPlus', 'Georgia', 'serif'];
Widget buildCommonsSection({
  required String numeral,
  required String title,
  String? note,
  double topPadding = 28,
  bool compact = false,
  required List<Widget> children,
}) {
  return Padding(
    padding: EdgeInsets.only(top: topPadding),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: compact ? 12 : 24,
              child: Text(
                numeral,
                style: TextStyle(
                  color: _profileGoldText.withValues(alpha: 0.68),
                  fontFamily: _profileSerifFont,
                  fontFamilyFallback: _profileSerifFallback,
                  fontSize: compact ? 8 : 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            Text(
              title.toUpperCase(),
              style: TextStyle(
                color: _profileGoldText,
                fontSize: compact ? 7 : 11,
                fontWeight: FontWeight.w800,
                letterSpacing: compact ? .8 : 1.8,
              ),
            ),
            SizedBox(width: compact ? 5 : 10),
            Expanded(
              child: Container(
                height: 1,
                color: _profileGoldMid.withValues(alpha: 0.18),
              ),
            ),
          ],
        ),
        if (note != null && note.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Text(
              note,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.58),
                fontFamily: _profileSerifFont,
                fontFamilyFallback: _profileSerifFallback,
                fontStyle: FontStyle.italic,
                fontSize: 15,
                height: 1.32,
              ),
            ),
          ),
        ],
        SizedBox(height: compact ? 4 : 14),
        ...children,
      ],
    ),
  );
}

Widget buildCommonsCard({
  required Widget child,
  EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  Color? borderColor,
  double radius = 16,
}) {
  return Container(
    padding: padding,
    decoration: BoxDecoration(
      color: const Color(0xFF15110A).withValues(alpha: 0.66),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: borderColor ?? _profileGoldMid.withValues(alpha: 0.24),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.16),
          blurRadius: 16,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: child,
  );
}

Widget buildCommonsCompactButton(
  String label, {
  bool primary = false,
  required VoidCallback? onPressed,
}) {
  return OutlinedButton(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      foregroundColor: primary
          ? _profileGoldText
          : Colors.white.withValues(alpha: 0.78),
      backgroundColor: primary
          ? _profileGoldMid.withValues(alpha: 0.12)
          : Colors.transparent,
      side: BorderSide(
        color: primary
            ? _profileGoldText.withValues(alpha: 0.48)
            : _profileGoldMid.withValues(alpha: 0.2),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      minimumSize: const Size(0, 36),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    child: Text(
      label,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.2,
      ),
    ),
  );
}

Widget buildCommonsEmptyState(String title, String body) {
  return buildCommonsCard(
    padding: const EdgeInsets.all(17),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.86),
            fontFamily: _profileSerifFont,
            fontFamilyFallback: _profileSerifFallback,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          body,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.58),
            fontFamily: _profileSerifFont,
            fontFamilyFallback: _profileSerifFallback,
            fontStyle: FontStyle.italic,
            fontSize: 15,
            height: 1.32,
          ),
        ),
      ],
    ),
  );
}

/// Shared Commons section; the owning page supplies its existing actions.
class CommonsQuestionBlock extends StatelessWidget {
  const CommonsQuestionBlock({
    super.key,
    required this.question,
    required this.composer,
    required this.answerBuilder,
    this.topPadding = 28,
    this.pane = false,
    this.editing = false,
    this.loading = false,
  });
  final CommonsQuestion question;
  final Widget composer;
  final Widget Function(CommonsAnswer, bool) answerBuilder;
  final bool editing, loading;
  final bool pane;
  final double topPadding;
  @override
  Widget build(BuildContext context) {
    final questionText = question.question.trim().replaceAll(
      RegExp(r'^"|"$'),
      '',
    );
    final hasQuestion = questionText.isNotEmpty;
    if (pane) {
      return LayoutBuilder(
        builder: (context, bounds) {
          final small = bounds.maxWidth < 170;
          final answer = question.myAnswer;
          final otherAnswers = question.answers
              .where((a) => a.id != answer?.id)
              .length;
          return Padding(
            padding: const EdgeInsets.all(6),
            child: buildCommonsSection(
              topPadding: 0,
              compact: true,
              numeral: 'II',
              title: 'Question of the Day',
              children: [
                Expanded(
                  child: buildCommonsCard(
                    radius: 11,
                    padding: EdgeInsets.symmetric(
                      horizontal: small ? 6 : 8,
                      vertical: small ? 3 : 4,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          hasQuestion
                              ? "FROM TODAY'S DAILY REFLECTION"
                              : 'DAILY REFLECTION',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _profileGoldText.withValues(alpha: .72),
                            fontSize: 6,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .55,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              hasQuestion ? questionText : 'No question today.',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: .9),
                                fontFamily: _profileSerifFont,
                                fontFamilyFallback: _profileSerifFallback,
                                fontSize: small ? 13 : 16,
                                fontWeight: FontWeight.w600,
                                height: 1.18,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (hasQuestion)
                          Container(
                            height: small ? 18 : 20,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 7),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D0D0F),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: _profileGoldMid.withValues(alpha: .20),
                              ),
                            ),
                            child: Text(
                              answer?.bodyText ?? 'Answer in the Commons',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: _profileSerifFont,
                                fontFamilyFallback: _profileSerifFallback,
                                fontSize: small ? 9 : 10,
                                fontStyle: answer == null
                                    ? FontStyle.italic
                                    : FontStyle.normal,
                                color: Colors.white.withValues(
                                  alpha: answer == null ? .42 : .9,
                                ),
                              ),
                            ),
                          ),
                        if (!small) ...[
                          const SizedBox(height: 4),
                          Text(
                            answer != null
                                ? 'Your public answer'
                                : otherAnswers == 0
                                ? 'No public answers yet.'
                                : '$otherAnswers public answer${otherAnswers == 1 ? '' : 's'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .48),
                              fontFamily: _profileSerifFont,
                              fontFamilyFallback: _profileSerifFallback,
                              fontStyle: FontStyle.italic,
                              fontSize: 8,
                              height: 1.0,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    }
    final myAnswer = question.myAnswer;
    final answerCount = question.answers
        .where((answer) => answer.id != myAnswer?.id)
        .length;
    return buildCommonsSection(
      topPadding: topPadding,
      numeral: 'II',
      title: 'Question of the Day',
      children: [
        buildCommonsCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                hasQuestion
                    ? 'FROM TODAY\'S DAILY REFLECTION'
                    : 'DAILY REFLECTION',
                style: TextStyle(
                  color: _profileGoldText.withValues(alpha: 0.72),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.7,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                hasQuestion
                    ? questionText
                    : 'No daily reflection question is available today.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontFamily: _profileSerifFont,
                  fontFamilyFallback: _profileSerifFallback,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  height: 1.18,
                ),
              ),
              const SizedBox(height: 16),
              if (hasQuestion)
                composer
              else
                buildCommonsEmptyState(
                  'No public question is open.',
                  'You can still carry the daily reflection privately in your journal.',
                ),
              if (myAnswer != null && !editing) ...[
                const SizedBox(height: 12),
                answerBuilder(myAnswer, true),
              ],
              if (answerCount > 0) ...[
                const SizedBox(height: 14),
                Text(
                  'PUBLIC ANSWERS',
                  style: TextStyle(
                    color: _profileGoldText.withValues(alpha: 0.72),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.7,
                  ),
                ),
                const SizedBox(height: 8),
                for (final answer
                    in question.answers
                        .where((answer) => answer.id != myAnswer?.id)
                        .take(6)) ...[
                  answerBuilder(answer, false),
                  const SizedBox(height: 8),
                ],
              ] else if (!loading && myAnswer == null) ...[
                const SizedBox(height: 12),
                Text(
                  'No public answers yet.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.48),
                    fontFamily: _profileSerifFont,
                    fontFamilyFallback: _profileSerifFallback,
                    fontStyle: FontStyle.italic,
                    fontSize: 15,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class CommonsAnswerComposer extends StatelessWidget {
  const CommonsAnswerComposer({
    super.key,
    required this.controller,
    required this.onSave,
    required this.onCancel,
    this.saving = false,
  });
  final TextEditingController controller;
  final VoidCallback onSave, onCancel;
  final bool saving;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _profileGoldMid.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: controller,
            enabled: !saving,
            minLines: 3,
            maxLines: 5,
            maxLength: 1200,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontFamily: _profileSerifFont,
              fontFamilyFallback: _profileSerifFallback,
              fontSize: 17,
              height: 1.3,
            ),
            decoration: InputDecoration(
              hintText: 'Answer in the Commons',
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.42),
                fontStyle: FontStyle.italic,
              ),
              counterStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.36),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: _profileGoldMid.withValues(alpha: 0.18),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: _profileGoldText.withValues(alpha: 0.62),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              buildCommonsCompactButton(
                saving ? 'Saving...' : 'Save public answer',
                primary: true,
                onPressed: saving ? null : onSave,
              ),
              buildCommonsCompactButton(
                'Cancel',
                onPressed: saving ? null : onCancel,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CommonsAnswerCard extends StatelessWidget {
  const CommonsAnswerCard({
    super.key,
    required this.answer,
    this.isMine = false,
    required this.onAction,
  });
  final CommonsAnswer answer;
  final bool isMine;
  final ValueChanged<String> onAction;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMine
              ? _profileGoldText.withValues(alpha: 0.26)
              : Colors.white.withValues(alpha: 0.09),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isMine ? 'Your answer' : answer.authorLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isMine
                        ? _profileGoldText
                        : Colors.white.withValues(alpha: 0.72),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (isMine)
                PopupMenuButton<String>(
                  onSelected: onAction,
                  icon: Icon(
                    Icons.more_horiz_rounded,
                    color: Colors.white.withValues(alpha: 0.58),
                    size: 19,
                  ),
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                )
              else
                PopupMenuButton<String>(
                  onSelected: onAction,
                  icon: Icon(
                    Icons.more_horiz_rounded,
                    color: Colors.white.withValues(alpha: 0.44),
                    size: 19,
                  ),
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'report', child: Text('Report')),
                    PopupMenuItem(value: 'block', child: Text('Block user')),
                  ],
                ),
            ],
          ),
          Text(
            answer.bodyText,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontFamily: _profileSerifFont,
              fontFamilyFallback: _profileSerifFallback,
              fontSize: 17,
              height: 1.32,
            ),
          ),
        ],
      ),
    );
  }
}
