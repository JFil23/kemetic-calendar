import '../calendar/kemetic_month_metadata.dart';
import 'ask_haw_memory.dart';
import 'ask_haw_models.dart';

/// Matching only: never use a normalized phrase as saved event text.
String normalizeAskHaw(String input) {
  var value = input
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r'[\u0300-\u036f\u200b-\u200d\ufeff]'), '')
      .replaceAll('’', "'")
      .replaceAll('‘', "'");
  const replacements = {
    'ḥ': 'h',
    'ḫ': 'kh',
    'ḏ': 'dj',
    'ꜣ': 'a',
    'ȝ': 'a',
    'ꜥ': 'a',
    'š': 's',
    'ṯ': 't',
    'ā': 'a',
    'á': 'a',
    'à': 'a',
    'â': 'a',
    'ä': 'a',
    'ē': 'e',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'ī': 'i',
    'í': 'i',
    'ì': 'i',
    'î': 'i',
    'ï': 'i',
    'ō': 'o',
    'ó': 'o',
    'ò': 'o',
    'ô': 'o',
    'ö': 'o',
    'ū': 'u',
    'ú': 'u',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
  };
  replacements.forEach((from, to) => value = value.replaceAll(from, to));
  return value
      .replaceAll(RegExp(r"[^a-z0-9':]+"), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

class AskHawRecognizer {
  const AskHawRecognizer();

  AskHawRequest recognize(String raw, {AskHawMemory? memory}) {
    final text = normalizeAskHaw(raw);
    final temporal = hasExplicitTemporal(raw);
    AskHawRequest request(
      AskHawIntent intent, {
      String query = '',
      String? target,
      String? temporalText,
      int? minutes,
      String? contentId,
      bool learned = false,
    }) => AskHawRequest(
      intent: intent,
      raw: raw,
      query: query,
      minutes: minutes,
      targetText: target,
      temporalText: temporalText,
      explicitTemporal: temporal,
      contentId: contentId,
      learned: learned,
    );
    if (text.isEmpty) return request(AskHawIntent.clarify);
    // Confirmed safe meanings override generic phrase patterns, including a
    // supported search/explanation. Fresh dates/times always retain precedence.
    if (!temporal) {
      final binding = memory?.bindingFor(text);
      final matches = AskHawIntent.values.where(
        (value) => value.name == binding?['intent'],
      );
      if (binding != null &&
          matches.isNotEmpty &&
          const {
            AskHawIntent.event,
            AskHawIntent.find,
            AskHawIntent.explain,
            AskHawIntent.next,
            AskHawIntent.fit,
            AskHawIntent.plan,
          }.contains(matches.first)) {
        final freshMinutes = parseAskHawMinutes(raw);
        final hasDuration = RegExp(
          r'\b\d+(?:\.\d+)?\s*(minutes?|mins?|hours?|hrs?)\b',
        ).hasMatch(raw.toLowerCase());
        return request(
          matches.first,
          query: binding['query'] is String ? binding['query'] as String : text,
          contentId: binding['contentId'] is String
              ? binding['contentId'] as String
              : null,
          minutes:
              freshMinutes ??
              (hasDuration
                  ? 0
                  : binding['minutes'] is num
                  ? (binding['minutes'] as num).toInt()
                  : null),
          learned: true,
        );
      }
    }
    if (!temporal && text == 'i want to read more') {
      return request(AskHawIntent.clarify, query: 'reading goal');
    }
    if (RegExp(
      r"^(what('?s| is) next|next|what should i do next|continue)( please)?$",
    ).hasMatch(text)) {
      return request(AskHawIntent.next);
    }
    if (RegExp(
          r'^(help( me)? )?(plan|organize|schedule)( my)? (day|today|tomorrow)$',
        ).hasMatch(text) ||
        RegExp(
          r'^(help me plan|plan my day|help me organize)( |$)',
        ).hasMatch(text)) {
      return request(AskHawIntent.plan, temporalText: raw);
    }
    final fit = RegExp(
      r'^(i have|i only have|what can i do (with|in)|fit something (into|in)|something for)\b',
    ).hasMatch(text);
    final minutes = parseAskHawMinutes(raw);
    if (fit) {
      return request(
        AskHawIntent.fit,
        minutes:
            minutes ??
            (RegExp(
                  r'\b\d+(?:\.\d+)?\s*(minutes?|mins?|hours?|hrs?)\b',
                ).hasMatch(raw.toLowerCase())
                ? 0
                : null),
        query: _stripDuration(text),
      );
    }
    if (text == 'help me use shorter sessions' ||
        text == 'use shorter sessions') {
      return request(AskHawIntent.preferences, query: 'shorter sessions');
    }
    if (RegExp(
      r'^(show|manage|edit|clear|forget)( my)? (memory|preferences|remembered phrases)|^what do you remember',
    ).hasMatch(text)) {
      return request(AskHawIntent.preferences, query: text);
    }
    final command = RegExp(
      r'^(move|reschedule|shorten|skip|pause|resume|continue)\s+(.+)$',
    ).firstMatch(text);
    if (command != null) {
      final verb = command.group(1)!;
      final tail = command.group(2)!;
      final split = RegExp(r'\s+(to|until|on|at)\s+').firstMatch(tail);
      final target = split == null ? tail : tail.substring(0, split.start);
      final temporalText = split == null ? null : tail.substring(split.end);
      final intent = switch (verb) {
        'move' || 'reschedule' => AskHawIntent.move,
        'shorten' => AskHawIntent.shorten,
        'skip' => AskHawIntent.skip,
        'pause' => AskHawIntent.pause,
        'resume' || 'continue' => AskHawIntent.resume,
        _ => AskHawIntent.unsupported,
      };
      return request(
        intent,
        target: target,
        temporalText: temporalText,
        minutes: intent == AskHawIntent.shorten ? minutes : null,
      );
    }
    final explanation = RegExp(
      r"^(what is|what are|what's|who is|who was|tell me about|explain|define)\s+(.+)$",
    ).firstMatch(text);
    if (explanation != null) {
      return request(
        AskHawIntent.explain,
        query: _stripArticle(explanation.group(2)!),
      );
    }
    final search = RegExp(
      r'^(find|find me|show me|search for|recommend|suggest|i am looking for|look for)\s+(.+)$',
    ).firstMatch(text);
    if (search != null) {
      var query = search.group(2)!;
      if (query.startsWith('me ')) query = query.substring(3);
      return request(AskHawIntent.find, query: _stripArticle(query));
    }
    if (RegExp(
      r"^(help|help me|what can you do|how (do|can) i use (you|haw))$",
    ).hasMatch(text)) {
      return request(AskHawIntent.clarify);
    }
    // A question or an unsupported imperative is never silently an all-day event.
    if (raw.trimRight().endsWith('?') ||
        RegExp(
          r'^(how|why|when|where|which|can you|could you|would you|help me|please help|remember|forget|change|delete|remove)\b',
        ).hasMatch(text)) {
      return request(AskHawIntent.unsupported, query: text);
    }
    return request(AskHawIntent.event);
  }
}

int? parseAskHawMinutes(String raw) {
  final text = raw.toLowerCase().trim();
  final match = RegExp(
    r'\b(\d+(?:\.\d+)?)\s*(minutes?|mins?|hours?|hrs?)\b',
  ).firstMatch(text);
  if (match != null) {
    final amount = double.tryParse(match.group(1)!);
    if (amount == null) return null;
    final minutes = (amount * (match.group(2)!.startsWith('h') ? 60 : 1))
        .round();
    return minutes > 0 && minutes <= 1440 ? minutes : null;
  }
  if (RegExp(r'\bhalf (an? )?hour\b').hasMatch(text)) return 30;
  if (RegExp(r'\b(an?|one) hour\b').hasMatch(text)) return 60;
  if (RegExp(r'\b(a|one) minute\b').hasMatch(text)) return 1;
  return null;
}

bool hasExplicitTemporal(String raw) {
  final text = normalizeAskHaw(raw);
  return RegExp(
        r'\b(today|tomorrow|tonight|yesterday|monday|tuesday|wednesday|thursday|friday|saturday|sunday|noon|midnight)\b',
      ).hasMatch(text) ||
      RegExp(
        r'\b\d{1,2}:\d{2}\b|\b\d{1,2}\s*(am|pm)\b|\b(at|on|in)\s+\d+\s*(days?|weeks?)?\b',
      ).hasMatch(text) ||
      RegExp(r'\b\d{1,2}/\d{1,2}').hasMatch(raw) ||
      RegExp(
        r'\b(january|jan|february|feb|march|mar|april|apr|may|june|jun|july|jul|august|aug|september|sept|sep|october|oct|november|nov|december|dec)\s+\d{1,2}\b',
      ).hasMatch(text) ||
      _kemeticDatePattern.hasMatch(text);
}

// Match the canonical Quick Add owner's month-name-plus-day grammar. A bare
// month name can also name Library content (for example, Thoth or Hathor), so it
// cannot by itself invalidate the user's confirmed meaning.
final _kemeticDatePattern = RegExp(
  r'\b(?:' +
      {
        for (final month in kKemeticMonths.skip(1))
          for (final name in {
            month.displayShort,
            month.displayTransliteration,
            month.transliterationFull,
            month.hellenized,
            month.key,
            ...month.searchAliases,
          })
            if (name.trim().length >= 3) RegExp.escape(normalizeAskHaw(name)),
      }.join('|') +
      r')\s+\d{1,2}\b',
);

String _stripArticle(String value) =>
    value.replaceFirst(RegExp(r'^(a|an|the)\s+'), '').trim();
String _stripDuration(String value) => value
    .replaceAll(RegExp(r'\b\d+\s*(minutes?|mins?|hours?|hrs?)\b'), '')
    .replaceAll(
      RegExp(
        r'^(i (only )?have|what can i do (with|in)|fit something (into|in)|something for)\s*',
      ),
      '',
    )
    .trim();
