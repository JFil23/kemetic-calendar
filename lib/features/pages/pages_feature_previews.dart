import 'package:flutter/material.dart';
import '../../data/commons_models.dart';
import '../profile/commons_question_block.dart';

/// The shared question's pane layout. Commons remains the action owner.
class PagesQuestionPreview extends StatelessWidget {
  const PagesQuestionPreview({super.key, this.question});
  final CommonsQuestion? question;
  @override
  Widget build(BuildContext context) => CommonsQuestionBlock(
    pane: true,
    question: question ?? const CommonsQuestion(id: '', question: ''),
    composer: const SizedBox.shrink(),
    answerBuilder: (_, _) => const SizedBox.shrink(),
  );
}
