import 'package:flutter/material.dart';
import '../../data/commons_models.dart';
import '../profile/commons_question_block.dart';

/// Pure thumbnail of the same Commons block. Taps belong to the parent tile;
/// composing and saving remain in Commons, with its existing mutation owner.
class PagesQuestionPreview extends StatefulWidget {
  const PagesQuestionPreview({super.key, this.question});
  final CommonsQuestion? question;
  @override
  State<PagesQuestionPreview> createState() => _PagesQuestionPreviewState();
}

class _PagesQuestionPreviewState extends State<PagesQuestionPreview> {
  final _answer = TextEditingController();
  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.question ?? const CommonsQuestion(id: '', question: '');
    return IgnorePointer(
      child: ExcludeFocus(
        child: FittedBox(
          fit: BoxFit.fill,
          child: SizedBox(
            width: 390,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
              child: CommonsQuestionBlock(
                topPadding: 0,
                question: q,
                composer: q.myAnswer != null
                    ? Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          buildCommonsCompactButton(
                            'Edit answer',
                            primary: true,
                            onPressed: () {},
                          ),
                          buildCommonsCompactButton(
                            'Answer privately',
                            onPressed: () {},
                          ),
                        ],
                      )
                    : CommonsAnswerComposer(
                        controller: _answer,
                        onSave: () {},
                        onCancel: () {},
                      ),
                answerBuilder: (answer, isMine) => CommonsAnswerCard(
                  answer: answer,
                  isMine: isMine,
                  onAction: (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
