import '../core/daily_reflection_question.dart';
import 'commons_models.dart';

/// Canonical local-date identity shared by Commons and its passive preview.
({String id, String text}) commonsQuestionSeed(DateTime now) {
  final daily = dailyReflectionQuestionForDate(now);
  final date =
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  var text = daily?.question.trim() ?? '';
  while (text.length >= 2) {
    final first = text[0], last = text[text.length - 1];
    if (!((first == '"' && last == '"') ||
        (first == "'" && last == "'") ||
        (first == '“' && last == '”') ||
        (first == '‘' && last == '’'))) {
      break;
    }
    text = text.substring(1, text.length - 1).trim();
  }
  return (
    id: daily == null
        ? 'daily-reflection:$date'
        : 'daily-reflection:${daily.kYear}:${daily.dayKey}',
    text: text,
  );
}

CommonsQuestion activeCommonsQuestion(
  CommonsHomeSnapshot? snapshot,
  DateTime now,
) {
  final seed = commonsQuestionSeed(now);
  final matching = snapshot?.questions
      .where((q) => q.id == seed.id)
      .firstOrNull;
  return CommonsQuestion(
    id: seed.id,
    // Authored prompt copy belongs to the current calendar. The snapshot owns
    // the answers, not a competing version of the day's reflection question.
    question: seed.text.isNotEmpty ? seed.text : (matching?.question ?? ''),
    answers: matching?.answers ?? const [],
    myAnswer: matching?.myAnswer,
    hasMoreAnswers: matching?.hasMoreAnswers ?? false,
  );
}
