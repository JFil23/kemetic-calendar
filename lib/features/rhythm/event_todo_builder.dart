import 'models/rhythm_models.dart';

class EventTodoSource {
  const EventTodoSource({
    required this.title,
    this.detail,
    this.location,
    this.flowName,
    this.isFlow = false,
    this.isReminder = false,
  });

  final String title;
  final String? detail;
  final String? location;
  final String? flowName;
  final bool isFlow;
  final bool isReminder;
}

const _taskVerbs = <String>[
  'add',
  'ask',
  'attend',
  'book',
  'bring',
  'buy',
  'call',
  'check',
  'clean',
  'complete',
  'confirm',
  'copy',
  'create',
  'do',
  'draft',
  'download',
  'email',
  'file',
  'fill',
  'finish',
  'go',
  'identify',
  'install',
  'journal',
  'make',
  'meet',
  'order',
  'pack',
  'pay',
  'pick',
  'practice',
  'prepare',
  'print',
  'read',
  'record',
  'renew',
  'reply',
  'research',
  'review',
  'say',
  'schedule',
  'send',
  'set',
  'sign',
  'submit',
  'take',
  'text',
  'update',
  'upload',
  'visit',
  'wash',
  'write',
];

final _taskVerbAlternation = _taskVerbs.map(RegExp.escape).join('|');
final _taskVerbAtStart = RegExp(
  '^(?:$_taskVerbAlternation)\\b',
  caseSensitive: false,
);
final _taskClauseSplitter = RegExp(
  '(?:\\s*,\\s*(?:and\\s+|then\\s+)?|\\s+and\\s+|\\s+then\\s+)'
  '(?=(?:$_taskVerbAlternation)\\b)',
  caseSensitive: false,
);
final _trailingClarification = RegExp(
  r'\s*(?:,?\s*(?:and\s+)?(?:note|notice|remember)\s+that\b|,?\s*(?:because|so\s+that|so\s+you|so\s+we|so\s+i|in\s+order\s+to)\b).*$',
  caseSensitive: false,
);

List<RhythmTodoDraft> buildEventTodoDrafts(EventTodoSource source) {
  final title = _cleanPlainText(source.title);
  final detailForNotes = _cleanDetailForNotes(source.detail);
  final location = _cleanPlainText(source.location ?? '');
  final explicitTaskList = _extractExplicitTaskList(detailForNotes);
  if (explicitTaskList.isNotEmpty) {
    return _draftsForExtractedTasks(
      explicitTaskList,
      detail: detailForNotes,
      location: location,
    );
  }

  final instructionDrafts = _buildInstructionalPracticeDrafts(
    title: title,
    detail: detailForNotes,
    location: location,
  );
  if (instructionDrafts != null) {
    return instructionDrafts;
  }

  final detailTasks = _extractDetailTasks(detailForNotes);
  final shouldUseDetailTasks =
      detailTasks.length >= 2 ||
      (detailTasks.length == 1 && _isVagueTitle(title));

  final notes = _buildNotes(
    detail: _summarizeDetailForNotes(detailForNotes),
    location: location,
  );

  if (shouldUseDetailTasks) {
    return _draftsForExtractedTasks(
      detailTasks,
      detail: detailForNotes,
      location: location,
    );
  }

  return [
    RhythmTodoDraft(
      title: _fallbackTaskTitle(source, title),
      notes: notes.isEmpty ? null : notes,
    ),
  ];
}

String _buildNotes({required String detail, required String location}) {
  final parts = <String>[
    if (detail.isNotEmpty) detail,
    if (location.isNotEmpty && !detail.contains(location))
      'Location: $location',
  ];
  return parts.isEmpty ? '' : parts.join('\n\n');
}

List<RhythmTodoDraft> _draftsForExtractedTasks(
  List<String> tasks, {
  required String detail,
  required String location,
}) {
  final notes = _buildExtractedTaskNotes(detail: detail, location: location);
  return _uniqueTitles(tasks)
      .map(
        (task) =>
            RhythmTodoDraft(title: task, notes: notes.isEmpty ? null : notes),
      )
      .toList(growable: false);
}

String _buildExtractedTaskNotes({
  required String detail,
  required String location,
}) {
  final links = _extractUrls(detail);
  final clarifications = _extractClarificationNotes(detail);
  final parts = <String>[
    if (links.isNotEmpty) 'Reference: ${links.join('\n')}',
    if (clarifications.isNotEmpty) 'Context: ${clarifications.join('\n')}',
    if (location.isNotEmpty && !detail.contains(location))
      'Location: $location',
  ];
  return parts.join('\n');
}

List<RhythmTodoDraft>? _buildInstructionalPracticeDrafts({
  required String title,
  required String detail,
  required String location,
}) {
  if (detail.isEmpty) return null;
  final lowerTitle = title.toLowerCase();
  final lowerDetail = detail.toLowerCase();
  final isLearningPractice =
      lowerTitle.contains('sign') ||
      lowerTitle.contains('reading') ||
      lowerDetail.contains('copy each') ||
      lowerDetail.contains('say the value aloud') ||
      lowerDetail.contains('identify at least');
  if (!isLearningPractice) return null;

  final object = _extractPracticeObject(title: title, detail: detail);
  if (object == null) return null;
  final stepDrafts = _buildPracticeStepDrafts(
    detail: detail,
    object: object,
    location: location,
  );
  if (stepDrafts.length >= 2) return stepDrafts;

  final goal = _extractPracticeGoal(detail);
  final taskTitle = goal == null
      ? 'Practice $object'
      : 'Practice $object until you can $goal';
  final notes = _buildPracticeNotes(detail: detail, location: location);
  return [
    RhythmTodoDraft(title: taskTitle, notes: notes.isEmpty ? null : notes),
  ];
}

List<RhythmTodoDraft> _buildPracticeStepDrafts({
  required String detail,
  required String object,
  required String location,
}) {
  final lower = detail.toLowerCase();
  final singularObject = _singularPracticeObject(object);
  final pluralObject = _pluralPracticeObject(object);
  final reference = _extractReferenceList(detail);
  final clarifications = _extractClarificationNotes(detail);
  final locationNote = location.isNotEmpty && !detail.contains(location)
      ? 'Location: $location'
      : null;
  final sharedNotes = <String>[
    if (reference != null) 'Reference: $reference',
    if (clarifications.isNotEmpty) 'Context: ${clarifications.join('\n')}',
    if (locationNote != null) locationNote,
  ].join('\n');

  final drafts = <RhythmTodoDraft>[];
  void addStep(String title, {String? notes}) {
    final cleaned = _cleanPlainText(title);
    if (cleaned.isEmpty) return;
    drafts.add(
      RhythmTodoDraft(
        title: _sentenceCase(cleaned),
        notes: notes?.trim().isNotEmpty == true ? notes!.trim() : null,
      ),
    );
  }

  if (lower.contains('copy each sign')) {
    addStep(
      'Copy each $singularObject ${_copyCountLabel(detail) ?? '3 times'}',
      notes: sharedNotes.isEmpty ? null : sharedNotes,
    );
  }
  if (lower.contains('say the value aloud')) {
    addStep('Say each $singularObject value aloud');
  }

  final goalTitle = _extractPracticeGoalTaskTitle(
    detail: detail,
    object: pluralObject,
  );
  if (goalTitle != null) addStep(goalTitle);

  return _uniqueDraftTitles(drafts);
}

String? _extractPracticeObject({
  required String title,
  required String detail,
}) {
  final theseSigns = RegExp(
    r'\bthese\s+([a-z]+|\d+)\s+([^:.]+?\bsigns?)\b',
    caseSensitive: false,
  ).firstMatch(detail);
  if (theseSigns != null) {
    final count = _numberWordToDigits(theseSigns.group(1)!);
    final object = _cleanPracticeObject(theseSigns.group(2)!);
    if (object.isNotEmpty) return count == null ? object : '$count $object';
  }

  final countedSigns = RegExp(
    r'\b(\d+)\s+([^.,;:]+?\bsigns?)\b',
    caseSensitive: false,
  ).firstMatch(detail);
  if (countedSigns != null) {
    final object = _cleanPracticeObject(countedSigns.group(2)!);
    if (object.isNotEmpty) return '${countedSigns.group(1)} $object';
  }

  if (title.toLowerCase().contains('sign')) {
    if (detail.toLowerCase().contains('medu neter')) {
      return 'Medu Neter signs';
    }
    return title;
  }
  return null;
}

String _cleanPracticeObject(String raw) {
  return _cleanPlainText(raw)
      .replaceAll(RegExp(r'\bunilateral\b', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String? _extractPracticeGoal(String detail) {
  final identifyCount = RegExp(
    r'\bidentify\s+(?:at\s+least\s+)?(\d+)\s+of\s+the\s+(\d+)\s+signs?\b',
    caseSensitive: false,
  ).firstMatch(detail);
  if (identifyCount != null) {
    return 'identify at least ${identifyCount.group(1)} of ${identifyCount.group(2)} signs';
  }

  final doneWhen = RegExp(
    r'\byou\s+are\s+done\s+when\s+you\s+can\s+(.+?)(?:[.!?]|$)',
    caseSensitive: false,
  ).firstMatch(detail);
  if (doneWhen != null) {
    final goal = _cleanTaskCandidate(doneWhen.group(1)!);
    if (goal.isNotEmpty) return goal[0].toLowerCase() + goal.substring(1);
  }
  return null;
}

String? _extractPracticeGoalTaskTitle({
  required String detail,
  required String object,
}) {
  final identifyCount = RegExp(
    r'\bidentify\s+(?:at\s+least\s+)?(\d+)\s+of\s+the\s+(\d+)\s+signs?\b',
    caseSensitive: false,
  ).firstMatch(detail);
  if (identifyCount != null) {
    final lowerAfterMatch = detail
        .substring(identifyCount.end)
        .trimLeft()
        .toLowerCase();
    final memorySuffix = lowerAfterMatch.startsWith('from memory')
        ? ' from memory'
        : '';
    return 'Identify at least ${identifyCount.group(1)} of ${identifyCount.group(2)} $object$memorySuffix';
  }

  final goal = _extractPracticeGoal(detail);
  return goal == null ? null : _sentenceCase(goal);
}

String _singularPracticeObject(String object) {
  final withoutCount = _stripLeadingCount(object);
  if (withoutCount.toLowerCase().endsWith('signs')) {
    return withoutCount.substring(0, withoutCount.length - 1);
  }
  return withoutCount;
}

String _pluralPracticeObject(String object) {
  final withoutCount = _stripLeadingCount(object);
  if (withoutCount.toLowerCase().endsWith('sign')) {
    return '${withoutCount}s';
  }
  return withoutCount;
}

String _stripLeadingCount(String object) {
  return _cleanPlainText(object).replaceFirst(RegExp(r'^\d+\s+'), '').trim();
}

String _buildPracticeNotes({required String detail, required String location}) {
  final steps = <String>[];
  final lower = detail.toLowerCase();
  if (lower.contains('copy each sign')) {
    steps.add('Copy each sign ${_copyCountLabel(detail) ?? '3 times'}');
  }
  if (lower.contains('say the value aloud')) {
    steps.add('Say each value aloud');
  }

  final goal = _extractPracticeGoal(detail);
  final reference = _extractReferenceList(detail);
  final clarifications = _extractClarificationNotes(detail);
  final parts = <String>[
    if (steps.isNotEmpty) 'Steps: ${steps.join('; ')}.',
    if (goal != null) 'Goal: ${_sentenceCase(goal)}.',
    if (reference != null) 'Reference: $reference',
    if (clarifications.isNotEmpty) 'Context: ${clarifications.join('\n')}',
    if (location.isNotEmpty && !detail.contains(location))
      'Location: $location',
  ];
  return parts.join('\n');
}

String? _copyCountLabel(String detail) {
  final copy = RegExp(
    r'\bcopy\s+each\s+sign\s+([a-z]+|\d+)\s+times?\b',
    caseSensitive: false,
  ).firstMatch(detail);
  if (copy == null) return null;
  final count = _numberWordToDigits(copy.group(1)!);
  return '${count ?? copy.group(1)!} times';
}

String? _extractReferenceList(String detail) {
  final colon = detail.indexOf(':');
  if (colon < 0 || colon >= detail.length - 1) return null;
  final afterColon = detail.substring(colon + 1);
  final actionStart = RegExp(
    r'\b(copy|practice|say|write|you are done)\b',
    caseSensitive: false,
  ).firstMatch(afterColon);
  final rawReference = actionStart == null
      ? afterColon
      : afterColon.substring(0, actionStart.start);
  final reference = _cleanPlainText(
    rawReference,
  ).replaceAll(RegExp(r'\s*,\s*and\s+', caseSensitive: false), '; ');
  if (reference.length < 8) return null;
  return reference.replaceAll(RegExp(r'\s*,\s*'), '; ').trim();
}

String _summarizeDetailForNotes(String detail) {
  final lower = detail.toLowerCase();
  if (lower.contains('ensure your space is comfortable') &&
      lower.contains('engage in movements')) {
    return 'Set up a comfortable, distraction-free space. Follow the linked movement practice. Focus on fluidity.';
  }
  return detail;
}

List<String> _extractDetailTasks(String detail) {
  if (detail.isEmpty) return const [];

  final explicitTasks = _extractExplicitTaskList(detail);
  if (explicitTasks.isNotEmpty) return explicitTasks;

  final rawLines = detail
      .split(RegExp(r'[\r\n]+'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList(growable: false);
  final bulletTasks = rawLines
      .where((line) => _hasListMarker(line))
      .map(_stripListMarker)
      .expand(_tasksFromListItem)
      .toList(growable: false);
  if (bulletTasks.isNotEmpty) return bulletTasks;

  final compoundTasks = _extractTasksFromText(detail);
  return compoundTasks.length >= 2 ? compoundTasks : const [];
}

List<String> _extractExplicitTaskList(String detail) {
  final match = RegExp(
    r'(?:tasks?|to[- ]dos?|todo)\s*:\s*(.+)$',
    caseSensitive: false,
    dotAll: true,
  ).firstMatch(detail);
  if (match == null) return const [];
  return _extractTasksFromListText(match.group(1)!);
}

String _fallbackTaskTitle(EventTodoSource source, String cleanedTitle) {
  final title = cleanedTitle.isEmpty
      ? _cleanPlainText(source.flowName ?? '')
      : cleanedTitle;
  if (title.isEmpty) {
    if (source.isReminder) return 'Review reminder';
    if (source.isFlow) return 'Do flow';
    return 'Review event';
  }
  if (_startsWithTaskVerb(title) || source.isReminder) {
    return _sentenceCase(title);
  }
  if (source.isFlow || _looksLikePracticeTitle(title)) {
    return 'Do $title';
  }
  if (_cleanPlainText(source.location ?? '').isNotEmpty) {
    return 'Go to $title';
  }
  return _sentenceCase(title);
}

bool _looksLikePracticeTitle(String title) {
  final lower = title.toLowerCase();
  return lower.contains('flow') ||
      lower.contains('practice') ||
      lower.contains('meditation') ||
      lower.contains('healing') ||
      lower.contains('breathwork') ||
      lower.contains('workout') ||
      lower.contains('stretch');
}

String? _numberWordToDigits(String raw) {
  final value = raw.trim().toLowerCase();
  final parsed = int.tryParse(value);
  if (parsed != null) return parsed.toString();
  const words = {
    'one': '1',
    'two': '2',
    'three': '3',
    'four': '4',
    'five': '5',
    'six': '6',
    'seven': '7',
    'eight': '8',
    'nine': '9',
    'ten': '10',
    'eleven': '11',
    'twelve': '12',
  };
  return words[value];
}

bool _isVagueTitle(String title) {
  final lower = title.toLowerCase();
  return title.isEmpty ||
      lower == 'event' ||
      lower == 'note' ||
      lower == 'reminder' ||
      lower == 'tasks' ||
      lower == 'to do' ||
      lower == 'todo' ||
      lower == 'errands' ||
      lower == 'follow up' ||
      lower == 'prep';
}

List<String> _uniqueTitles(List<String> tasks) {
  final seen = <String>{};
  final unique = <String>[];
  for (final task in tasks) {
    final normalized = task.toLowerCase();
    if (seen.add(normalized)) unique.add(task);
  }
  return unique;
}

List<RhythmTodoDraft> _uniqueDraftTitles(List<RhythmTodoDraft> drafts) {
  final seen = <String>{};
  final unique = <RhythmTodoDraft>[];
  for (final draft in drafts) {
    final normalized = draft.title.toLowerCase();
    if (seen.add(normalized)) unique.add(draft);
  }
  return unique;
}

bool _hasListMarker(String value) {
  return RegExp(r'^\s*(?:[-*\u2022]|\d+[.)]|\[[ xX]\])\s+').hasMatch(value);
}

String _stripListMarker(String value) {
  return value.replaceFirst(
    RegExp(r'^\s*(?:[-*\u2022]|\d+[.)]|\[[ xX]\])\s+'),
    '',
  );
}

String _cleanTaskCandidate(String raw) {
  var value = _stripListMarker(raw);
  value = value.replaceAll(RegExp(r'https?://\S+'), '').trim();
  value = value.replaceAll(RegExp(r'\s+'), ' ');
  if (_isClarificationCandidate(value)) return '';
  value = value
      .replaceFirst(
        RegExp(r'^(?:please|remember to)\s+', caseSensitive: false),
        '',
      )
      .replaceFirst(
        RegExp(r'^(?:need to|needs to)\s+', caseSensitive: false),
        '',
      )
      .replaceFirst(RegExp(r'^make sure to\s+', caseSensitive: false), '')
      .trim();
  value = _stripTrailingClarification(value);
  value = value.replaceAll(RegExp(r'[.!?,;:]+$'), '').trim();
  if (value.isEmpty || _isLinkInstruction(value)) return '';
  return _sentenceCase(value);
}

bool _startsWithTaskVerb(String value) {
  final trimmed = value.trim();
  return trimmed.isNotEmpty &&
      !_isLinkInstruction(trimmed) &&
      _taskVerbAtStart.hasMatch(trimmed);
}

List<String> _extractTasksFromText(String text) {
  final tasks = text
      .split(RegExp(r'[\r\n]+|(?<=[.!?])\s+|;\s+'))
      .expand(_splitTaskClauses)
      .where((clause) => !_isClarificationCandidate(clause))
      .map(_cleanTaskCandidate)
      .where(_startsWithTaskVerb)
      .toList(growable: false);
  return _uniqueTitles(tasks);
}

List<String> _extractTasksFromListText(String text) {
  final listItems = text
      .split(RegExp(r'[\r\n;]+'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
  if (listItems.length > 1) {
    return _uniqueTitles(
      listItems.expand(_tasksFromListItem).toList(growable: false),
    );
  }
  final compoundTasks = _extractTasksFromText(text);
  if (compoundTasks.length >= 2) return compoundTasks;
  return _tasksFromListItem(text);
}

List<String> _tasksFromListItem(String text) {
  final compoundTasks = _extractTasksFromText(text);
  if (compoundTasks.length >= 2) return compoundTasks;
  final cleaned = _cleanTaskCandidate(text);
  return cleaned.isEmpty ? const [] : [cleaned];
}

List<String> _splitTaskClauses(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return const [];
  return trimmed
      .split(_taskClauseSplitter)
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
}

List<String> _extractUrls(String text) {
  return RegExp(r'https?://\S+')
      .allMatches(text)
      .map((match) => match.group(0)!.replaceAll(RegExp(r'[.,;:]+$'), ''))
      .toSet()
      .toList(growable: false);
}

List<String> _extractClarificationNotes(String text) {
  final notes = <String>[];
  for (final sentence in _splitContextSentences(text)) {
    final explicit = _extractExplicitClarification(sentence);
    if (explicit != null && explicit.isNotEmpty) {
      notes.add(explicit);
      continue;
    }
    for (final clause in _splitTaskClauses(sentence)) {
      final trailing = _extractTrailingClarification(clause);
      if (trailing != null && trailing.isNotEmpty) notes.add(trailing);
    }
  }
  return _uniqueTitles(notes);
}

List<String> _splitContextSentences(String text) {
  return text
      .split(RegExp(r'[\r\n]+|(?<=[.!?])\s+'))
      .map((sentence) => sentence.trim())
      .where((sentence) => sentence.isNotEmpty)
      .toList(growable: false);
}

String? _extractExplicitClarification(String sentence) {
  final match = RegExp(
    r'\b(?:note|notice|remember)\s+that\s+(.+)$|\bkeep\s+in\s+mind\s+that\s+(.+)$|\bbe\s+aware\s+that\s+(.+)$',
    caseSensitive: false,
  ).firstMatch(sentence);
  if (match == null) return null;
  final raw = match
      .groups([1, 2, 3])
      .whereType<String>()
      .firstWhere((value) => value.trim().isNotEmpty, orElse: () => '');
  return _cleanClarification(raw);
}

String? _extractTrailingClarification(String sentence) {
  if (!_taskVerbAtStart.hasMatch(sentence.trim())) return null;
  final match = RegExp(
    r'\b(?:because|so\s+that|so\s+you|so\s+we|so\s+i|in\s+order\s+to)\b.+$',
    caseSensitive: false,
  ).firstMatch(sentence);
  if (match == null) return null;
  return _cleanClarification(match.group(0)!);
}

bool _isClarificationCandidate(String value) {
  final lower = value.trim().toLowerCase();
  return lower.isEmpty ||
      lower.startsWith('note that ') ||
      lower.startsWith('notice that ') ||
      lower.startsWith('remember that ') ||
      lower.startsWith('and note that ') ||
      lower.startsWith('and notice that ') ||
      lower.startsWith('and remember that ') ||
      lower.startsWith('keep in mind that ') ||
      lower.startsWith('be aware that ') ||
      lower.startsWith('because ') ||
      lower.startsWith('so that ') ||
      lower.startsWith('so you ') ||
      lower.startsWith('so we ') ||
      lower.startsWith('so i ') ||
      lower.startsWith('in order to ');
}

String _stripTrailingClarification(String value) {
  return value.replaceFirst(_trailingClarification, '').trim();
}

String _cleanClarification(String raw) {
  var value = raw.replaceAll(RegExp(r'https?://\S+'), '').trim();
  value = value
      .replaceFirst(RegExp(r'^(?:and\s+)?', caseSensitive: false), '')
      .replaceFirst(
        RegExp(r'^(?:note|notice|remember)\s+that\s+', caseSensitive: false),
        '',
      )
      .replaceFirst(
        RegExp(r'^keep\s+in\s+mind\s+that\s+', caseSensitive: false),
        '',
      )
      .replaceFirst(RegExp(r'^be\s+aware\s+that\s+', caseSensitive: false), '')
      .trim();
  value = value.replaceAll(RegExp(r'\s+'), ' ');
  value = value.replaceAll(RegExp(r'[.!?,;:]+$'), '').trim();
  if (value.isEmpty || _isLinkInstruction(value)) return '';
  return _sentenceCase(value);
}

bool _isLinkInstruction(String value) {
  final lower = value.trim().toLowerCase();
  return lower.isEmpty ||
      lower == 'link' ||
      lower.startsWith('link:') ||
      lower.startsWith('use this link') ||
      lower.startsWith('use link') ||
      lower.startsWith('http://') ||
      lower.startsWith('https://');
}

String _cleanDetailForNotes(String? raw) {
  if (raw == null || raw.trim().isEmpty) return '';
  var detail = raw.trim();
  if (detail.startsWith('flowLocalId=') || detail.startsWith('repeat=')) {
    final semi = detail.indexOf(';');
    detail = semi > 0 && semi < detail.length - 1
        ? detail.substring(semi + 1).trim()
        : '';
  }
  detail = detail
      .split(RegExp(r'[\r\n]+'))
      .where((line) => !_looksLikeCidLine(line))
      .join('\n')
      .trim();
  return detail.replaceAll(RegExp(r'[ \t]+'), ' ').trim();
}

bool _looksLikeCidLine(String raw) {
  final value = raw.trim().replaceAll(RegExp(r'\s+'), '');
  final withoutPrefix = value.startsWith('kemet_cid:')
      ? value.substring('kemet_cid:'.length)
      : value;
  return RegExp(
    r'^ky=\d+-km=\d+-kd=\d+\|s=\d+\|t=[^|]+\|f=[^|]+$',
  ).hasMatch(withoutPrefix);
}

String _cleanPlainText(String raw) {
  return raw.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String _sentenceCase(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return trimmed;
  return '${trimmed[0].toUpperCase()}${trimmed.substring(1)}';
}
