import '../calendar/reading_house_private_margin_store.dart';
import '../calendar/the_reading_house_flow.dart';
import '../../widgets/kemetic_date_picker.dart' show KemeticMath;
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../data/account_operation_fence.dart';
import '../../data/decan_reflection_model.dart';
import '../../data/decan_reflection_repo.dart';
import '../../data/decan_reflection_prompt_state.dart';
import '../../data/journal_repo.dart';
import '../../data/profile_repo.dart';
import '../../data/insight_post_model.dart';
import '../../data/flows_repo.dart';
import '../journal/journal_v2_document_model.dart';
import '../nodes/library_read_progress_store.dart';
import 'decan_review_context.dart';
import 'decan_review_models.dart';

@immutable
class DecanReviewWindow {
  const DecanReviewWindow({
    required this.start,
    required this.end,
    required this.name,
  });
  final DateTime start, end;
  final String name;
  static DecanReviewWindow? fromQuery(Map<String, String> q) {
    final start = DateTime.tryParse(q['start'] ?? '');
    final end = DateTime.tryParse(q['end'] ?? '');
    if (start == null || end == null) return null;
    final k = KemeticMath.fromGregorian(start);
    final expectedEnd = DateTime(start.year, start.month, start.day + 9);
    if (k.kMonth > 12 ||
        ![1, 11, 21].contains(k.kDay) ||
        end != expectedEnd ||
        DateTime.now().isBefore(DateTime(end.year, end.month, end.day, 20)))
      return null;
    return DecanReviewWindow(
      start: start,
      end: end,
      name: q['name'] ?? 'Decan reflection',
    );
  }

  static String invitationRoute(Map<String, dynamic> data) {
    final q = <String, String>{
      'start': data['decan_start']?.toString() ?? '',
      'end': data['decan_end']?.toString() ?? '',
      if (data['decan_name'] is String) 'name': data['decan_name'] as String,
    };
    return fromQuery(q) == null
        ? '/reflections'
        : Uri(path: '/reflections/new', queryParameters: q).toString();
  }

  String get key => date(start);
  static String date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

enum DecanReviewStage {
  review,
  writing,
  choosing,
  saved,
  publishing,
  posted,
  continuation,
  recovery,
}

/// Owns one account/period session, including durable authored drafts. The
/// account repositories own all server writes and disposable read snapshots.
class DecanReviewController extends ChangeNotifier {
  DecanReviewController({
    required SupabaseClient client,
    required this.window,
    this.initialReflection,
    DecanReflectionRepo? reflections,
    JournalRepo? journal,
    ProfileRepo? profiles,
  }) : _client = client,
       _repo = reflections ?? DecanReflectionRepo(client),
       _journal = journal ?? JournalRepo(client),
       _profiles = profiles ?? ProfileRepo(client),
       _fence = AccountOperationFence(client) {
    reflection = initialReflection;
    review = initialReflection?.reviewContext;
    _accountSub = client.auth.onAuthStateChange.listen((_) {
      if (!_fence.isCurrent) {
        accountChanged = true;
        items.clear();
        selected.clear();
        review = null;
        suggestions = [];
        preservedDrafts = [];
        journalEntry = null;
        ownMoment = '';
        _draft = {};
        reflection = null;
        answer = '';
        savedAnswer = '';
        postText = '';
        post = null;
        notifyListeners();
      }
    });
  }
  final SupabaseClient _client;
  final DecanReflectionRepo _repo;
  final JournalRepo _journal;
  final ProfileRepo _profiles;
  final AccountOperationFence _fence;
  late final StreamSubscription<AuthState> _accountSub;
  final DecanReviewWindow window;
  final DecanReflection? initialReflection;
  DecanReflection? reflection;
  DecanReviewContext? review;
  InsightPost? post;
  JournalEntry? journalEntry;
  DateTime? journalDate;
  bool sourceExists = false;
  bool sourceDeleted = false,
      loading = true,
      busy = false,
      accountChanged = false;
  String? error, notice;
  String answer = '', savedAnswer = '', postText = '', ownMoment = '';
  bool includeQuestion = true, includeReading = false;
  String? readingId;
  DecanReviewStage stage = DecanReviewStage.review;
  final Map<String, DecanMoment> items = {};
  final Map<String, String?> _cursors = {};
  final Set<String> failedSources = {};
  final Set<String> selected = {};
  final Set<String> _historyExclusions = {};
  final Set<String> _checkedPrivateSittings = {};
  List<DecanContinuation> suggestions = [];
  List<Map<String, dynamic>> preservedDrafts = [];
  Map<String, dynamic> _draft = {};
  Future<void> _draftWrites = Future.value();
  bool _disposed = false;
  String get account => _fence.userId ?? '';
  String get draftKey => 'decan_review:user:$account:${window.key}';
  bool get valid => !_disposed && _fence.isCurrent && account.isNotEmpty;
  bool get hasMore =>
      failedSources.isNotEmpty || _cursors.values.any((c) => c != null);
  List<DecanMoment> get selectedMoments => review?.moments ?? [];
  void _changed() {
    if (valid) notifyListeners();
  }

  Future<void> initialize() async {
    loading = true;
    error = null;
    notice = null;
    _changed();
    try {
      if (!valid) throw StateError('Sign in to review these days');
      final prefs = await SharedPreferences.getInstance();
      if (!valid) return;
      final raw = prefs.getString(draftKey);
      if (raw != null)
        _draft = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      answer = _draft['answer'] as String? ?? '';
      ownMoment = _draft['own_moment'] as String? ?? '';
      postText = _draft['post_text'] as String? ?? '';
      reflection = initialReflection == null
          ? await _repo.findByWindow(window.start, window.end, strict: true)
          : await _repo.getById(initialReflection!.id, strict: true);
      if (initialReflection != null && reflection == null) {
        review = null;
        throw StateError('This reflection is no longer available.');
      }
      if (!valid) return;
      review = reflection?.reviewContext;
      if (_draft['context_dirty'] != true)
        _draft['context_revision'] = reflection?.reviewRevision ?? 0;
      await Future.wait(
        [
          'flows',
          'library',
          'responses',
          'previous',
        ].map((s) => _loadSource(s)),
      );
      if (!valid) return;
      if (review == null) {
        final chosen = _initialMoments(items.values.toList());
        final q = DecanReviewQuestions.choose(
          hasMoments: chosen.isNotEmpty,
          previousQuestionId: _draft['previous_question'] as String?,
        );
        review = _draft['context'] is Map
            ? DecanReviewContext.fromJson(
                Map<String, dynamic>.from(_draft['context'] as Map),
              )
            : DecanReviewContext(
                questionId: q,
                question: DecanReviewQuestions.catalog[q]!,
                moments: chosen,
              );
        await _saveContext();
      }
      if (!valid) return;
      if (_draft['context_dirty'] == true && _draft['context'] is Map) {
        review = DecanReviewContext.fromJson(
          Map<String, dynamic>.from(_draft['context'] as Map),
        );
      }
      await _loadAnswer();
      if (!valid) return;
      try {
        post = await _profiles.getDecanPost(reflection!.id);
      } catch (_) {
        notice =
            'Your reflection is ready. The published version could not be checked yet.';
      }
      selected.addAll(selectedMoments.where((m) => !m.isOwn).map((m) => m.id));
      for (final m in selectedMoments) {
        items[m.id] = m;
        if (m.isOwn) ownMoment = m.text;
      }
      stage = answer.isNotEmpty && answer != savedAnswer
          ? DecanReviewStage.writing
          : DecanReviewStage.review;
      if (failedSources.isNotEmpty)
        notice =
            'Some recorded moments could not load. You can retry in Choose moments.';
    } catch (e) {
      error = e.toString();
      if (review != null)
        notice = reflection?.reviewContext == null
            ? 'Your reflection could not be prepared. Your draft is kept; retry to continue.'
            : 'The saved reflection is here. Could not refresh it; retry before keeping changes.';
    } finally {
      loading = false;
      _changed();
    }
  }

  Future<void> _loadSource(String source, {String? cursor}) async {
    try {
      final page = await _repo.reviewActivity(
        start: window.start,
        end: window.end,
        source: source,
        cursor: cursor,
      );
      if (!valid) return;
      for (final m in page.items) {
        items[m.id] = m;
      }
      _cursors[source] = page.nextCursor;
      failedSources.remove(source);
      _historyExclusions.addAll(page.excludedSuggestions);
      if (page.previousQuestionId != null)
        _draft['previous_question'] = page.previousQuestionId;
    } catch (_) {
      if (valid) failedSources.add(source);
    }
  }

  Future<void> moreMoments({bool journal = false}) async {
    if (busy || !valid) return;
    busy = true;
    _changed();
    if (journal) {
      await _loadSource('journal', cursor: _cursors['journal']);
    } else {
      final pending = {
        ...failedSources,
        ..._cursors.entries.where((e) => e.value != null).map((e) => e.key),
      };
      await Future.wait(
        pending.map((s) => _loadSource(s, cursor: _cursors[s])),
      );
    }
    notice = failedSources.isEmpty
        ? null
        : 'Some sources are unavailable. Your selection is kept. Try again.';
    busy = false;
    _changed();
  }

  /// Private margins are opened only after a deliberate chooser action.
  /// Exact keys come from verified activity and owned flows, never a prefs scan.
  Future<void> choosePrivateReadingNotes() => _run(() async {
    final candidates = items.values
        .where(
          (m) =>
              m.kind == 'flow' &&
              m.flowKey == 'the-reading-house' &&
              m.flowId != null &&
              m.eventNumber != null,
        )
        .toList();
    final seen = <String>{};
    var added = 0;
    for (final moment
        in candidates
            .where(
              (m) => !_checkedPrivateSittings.contains(
                '${m.flowId}:${m.eventNumber}',
              ),
            )
            .take(12)) {
      final key = '${moment.flowId}:${moment.eventNumber}';
      if (!seen.add(key)) continue;
      final flow = await FlowsRepo(_client).getFlowById(moment.flowId!);
      if (!valid) return;
      if (flow == null || flow.userId != account) continue;
      final values = await const ReadingHousePrivateMarginStore().loadValues(
        flowId: flow.id,
        eventNumber: moment.eventNumber,
      );
      if (!valid) return;
      _checkedPrivateSittings.add(key);
      for (final spec in [
        kReadingHousePrivateReflectionSpecId,
        kReadingHouseShortNoteSpecId,
      ]) {
        final text = values[spec]?.text?.trim();
        if (text == null || text.isEmpty) continue;
        final id = 'private-reading:$key:$spec';
        items[id] = DecanMoment(
          id: id,
          kind: 'private_reading',
          sourceId: key,
          occurredOn: moment.occurredOn,
          sourceLabel: 'Reading House',
          actionLabel: 'Private note on this device',
          text: text,
          flowId: flow.id,
          flowKey: 'the-reading-house',
          eventNumber: moment.eventNumber,
          isQuote: true,
        );
        added++;
      }
    }
    notice = added == 0
        ? 'No private notes were found for the Reading House sittings loaded here. You can load more recorded moments.'
        : 'These notes stay on this device unless you select one and keep it in your private reflection. Nothing is posted.';
  });

  static List<DecanMoment> _initialMoments(List<DecanMoment> all) {
    all.sort(
      (a, b) =>
          (b.occurredOn ?? DateTime(0)).compareTo(a.occurredOn ?? DateTime(0)),
    );
    final result = <DecanMoment>[];
    for (final kind in ['response', 'flow', 'library']) {
      final candidates = all.where(
        (m) => m.kind == kind && m.actionLabel != 'Skipped',
      );
      if (candidates.isNotEmpty) result.add(candidates.first);
    }
    result.sort(
      (a, b) =>
          (a.occurredOn ?? DateTime(0)).compareTo(b.occurredOn ?? DateTime(0)),
    );
    return result;
  }

  Future<void> _loadAnswer() async {
    final source = await _repo.reviewJournalSource(reflection!.id);
    if (!valid) return;
    sourceExists = source != null;
    sourceDeleted = source?['is_deleted'] == true;
    journalDate = source == null
        ? DateTime.now()
        : DateTime.parse(source['greg_date'] as String);
    journalEntry = await _journal.getByDateStrict(journalDate!);
    if (!valid) return;
    savedAnswer = '';
    if (source != null && !sourceDeleted && journalEntry != null) {
      final doc = JournalDocument.fromJson(
        Map<String, dynamic>.from(jsonDecode(journalEntry!.body) as Map),
      );
      for (final b in doc.blocks.whereType<ParagraphBlock>()) {
        if (b.id == source['block_id'])
          savedAnswer = b.ops.map((o) => o.insert).join();
      }
    }
    if (!(_draft['answer_dirty'] == true)) answer = savedAnswer;
    if (_draft['answer_dirty'] != true)
      _draft['journal_revision'] = _journal.revisionForDate(journalDate!);
  }

  void changeAnswer(String value) {
    answer = value;
    _draft['answer_dirty'] = true;
    _persistLater();
  }

  void changePost(String value) {
    postText = value;
    _draft['post_dirty'] = true;
    _persistLater();
    _changed();
  }

  void changeOwn(String value) {
    ownMoment = value;
    _persistLater();
  }

  void show(DecanReviewStage next) {
    if (loading || busy || !valid) return;
    stage = next;
    notice = null;
    _changed();
  }

  void toggle(DecanMoment moment) {
    if (busy || !valid) return;
    if (selected.contains(moment.id))
      selected.remove(moment.id);
    else if (selected.length + (ownMoment.trim().isEmpty ? 0 : 1) < 3)
      selected.add(moment.id);
    else
      notice = 'Keep up to three moments. Uncheck one to choose another.';
    _changed();
  }

  Future<void> keepMoments() async {
    if (selected.length + (ownMoment.trim().isEmpty ? 0 : 1) > 3) {
      notice = 'Keep up to three moments, including your own.';
      _changed();
      return;
    }
    final next = [
      for (final id in selected)
        if (items[id] != null) items[id]!,
      if (ownMoment.trim().isNotEmpty)
        DecanMoment(
          id: 'own:${window.key}',
          kind: 'own',
          sourceId: window.key,
          occurredOn: null,
          sourceLabel: 'Your moment',
          actionLabel: 'Remembered',
          text: ownMoment.trim(),
        ),
    ];
    review = review!.copyWith(moments: next);
    _draft['context_dirty'] = true;
    await _run(() async {
      await _saveContext();
      stage = DecanReviewStage.review;
    });
  }

  Future<void> leaveOpen() => _run(() async {
    review = review!.copyWith(questionOpen: true);
    _draft['context_dirty'] = true;
    await _saveContext();
    await _markSeen();
    stage = DecanReviewStage.continuation;
    await _prepareSuggestions();
  });
  Future<void> saveAnswer({bool restore = false}) => _run(() async {
    if (answer.trim().isEmpty)
      throw StateError('Leave a few words, or keep the question open.');
    if (sourceDeleted && !restore)
      throw StateError(
        'This contribution was removed in Journal. Review your Journal before adding it again.',
      );
    await _saveContext();
    final today = DateTime.now();
    if (!sourceExists &&
        _draft['answer_request'] == null &&
        DecanReviewWindow.date(journalDate ?? today) !=
            DecanReviewWindow.date(today)) {
      journalDate = today;
      await _journal.getByDateStrict(today);
      if (!valid) return;
      _draft['journal_revision'] = _journal.revisionForDate(today);
    }
    journalDate ??= today;
    final request = await _pendingRequest('answer_request', {
      'p_account': account,
      'p_reflection': reflection!.id,
      'p_date': DecanReviewWindow.date(journalDate!),
      'p_expected_revision':
          _draft['journal_revision'] ?? _journal.revisionForDate(journalDate!),
      'p_words': answer.trim(),
      'p_restore': restore,
    });
    final result = await _repo.saveReviewAnswerRequest(request);
    if (!valid) return;
    // Never clear a later keystroke when an earlier request is acknowledged.
    if (answer.trim() == request['p_words']) {
      _draft['answer_dirty'] = false;
      _draft.remove('answer_request');
    }
    _draft['journal_revision'] = result['revision'];
    journalEntry = JournalEntry.fromJson(
      Map<String, dynamic>.from(result['row'] as Map),
    );
    savedAnswer = request['p_words'] as String;
    sourceExists = true;
    sourceDeleted = false;
    await _persist();
    await _markSeen();
    stage = _draft['answer_dirty'] == true
        ? DecanReviewStage.writing
        : DecanReviewStage.saved;
  });
  Future<void> refreshSavedVersion() => _run(() async {
    final latest = await _repo.getById(reflection!.id, strict: true);
    if (latest != null) reflection = latest;
    await _loadAnswer();
    // The user explicitly reviewed the remote copy; the pending local words
    // remain visible and a subsequent Keep action uses this new base revision.
    _draft['journal_revision'] = _journal.revisionForDate(journalDate!);
    _draft.remove('answer_request');
    _draft.remove('context_request');
    _draft['reflection_id'] = reflection?.id;
    _draft['context_revision'] = reflection?.reviewRevision ?? 0;
    notice = savedAnswer.isEmpty
        ? 'There are no saved words for this reflection. Your draft is still here.'
        : 'Saved in Journal: $savedAnswer';
    await _persist();
  });
  Future<void> _saveContext() async {
    if (reflection?.reviewContext != null && _draft['context_dirty'] != true)
      return;
    _draft['reflection_id'] ??= reflection?.id ?? const Uuid().v4();
    final request = await _pendingRequest('context_request', {
      'p_account': account,
      'p_id': _draft['reflection_id'],
      'p_start': DecanReviewWindow.date(window.start),
      'p_end': DecanReviewWindow.date(window.end),
      'p_name': window.name,
      'p_context': review!.toJson(),
      'p_expected_revision':
          _draft['context_revision'] ?? reflection?.reviewRevision ?? 0,
    });
    reflection = await _repo.saveReviewRequest(request);
    _draft.remove('context_request');
    _draft['context_dirty'] = false;
    _draft['context_revision'] = reflection!.reviewRevision;
    await _persist();
  }

  Future<void> _markSeen() async {
    if (!valid) return;
    await DecanReflectionPromptState(_client).markInteracted(window.start);
    if (!valid) return;
    await _repo.markPromptInteracted(
      decanStart: window.start,
      decanEnd: window.end,
      interactionKind: 'interacted',
    );
  }

  void preparePost() {
    if (!valid || loading || busy) return;
    if (post?.isHidden == true) {
      notice =
          'This post was removed. Your private reflection is still kept in Journal.';
      _changed();
      return;
    }
    if (_draft['post_dirty'] != true) postText = post?.bodyText ?? savedAnswer;
    includeQuestion = _draft['post_dirty'] == true
        ? (_draft['include_question'] as bool? ?? true)
        : post == null || post!.questionText != null;
    readingId = post?.readingLink?['slug'] as String?;
    includeReading = _draft['post_dirty'] == true
        ? _draft['include_reading'] == true
        : readingId != null;
    readingId ??= selectedMoments
        .map((m) => m.libraryId)
        .whereType<String>()
        .firstOrNull;
    stage = DecanReviewStage.publishing;
    _changed();
  }

  Future<void> refreshPublishedVersion() => _run(() async {
    final latest = await _profiles.getDecanPost(reflection!.id);
    if (!valid) return;
    post = latest;
    _draft.remove('post_request');
    _draft['post_revision'] = latest?.revision ?? 0;
    if (latest != null) _draft['post_id'] = latest.id;
    notice = latest == null || latest.isHidden
        ? 'There is no visible published copy. Your draft is still here.'
        : 'Published copy: ${latest.bodyText}';
    await _persist();
  });

  Future<void> findPreservedDrafts() => _run(() async {
    stage = DecanReviewStage.recovery;
    preservedDrafts = await _repo.preservedReviewDrafts(reflection!.id);
  });

  Future<void> usePreservedDraft(Map<String, dynamic> record) => _run(() async {
    if (!preservedDrafts.contains(record)) return;
    final request = Map<String, dynamic>.from(record['request'] as Map);
    // Selecting a version stages it for review. Keep the current local draft too.
    _draft['before_recovery'] = {
      'answer': answer,
      'post_text': postText,
      'context': review?.toJson(),
    };
    switch (request['kind']) {
      case 'post':
        final latest = await _profiles.getDecanPost(reflection!.id);
        if (!valid) return;
        post = latest;
        postText = request['body'] as String? ?? '';
        includeQuestion = request['question'] == true;
        readingId = request['reading'] as String?;
        includeReading = readingId != null;
        _draft['post_dirty'] = true;
        _draft['post_revision'] = latest?.revision ?? 0;
        _draft.remove('post_request');
        if (latest != null) _draft['post_id'] = latest.id;
        stage = DecanReviewStage.publishing;
        notice = latest == null
            ? 'Review these words before posting.'
            : 'Published copy: ${latest.bodyText}';
      case 'journal':
        answer = request['words'] as String? ?? '';
        _draft['answer_dirty'] = true;
        await _loadAnswer();
        if (!valid) return;
        _draft['journal_revision'] = _journal.revisionForDate(journalDate!);
        _draft.remove('answer_request');
        stage = DecanReviewStage.writing;
        notice =
            'Saved in Journal: ${savedAnswer.isEmpty ? 'No saved contribution.' : savedAnswer}';
      case 'review':
        review = DecanReviewContext.fromJson(
          Map<String, dynamic>.from(request['context'] as Map),
        );
        selected.clear();
        ownMoment = '';
        for (final m in review!.moments) {
          items[m.id] = m;
          if (m.isOwn) {
            ownMoment = m.text;
          } else {
            selected.add(m.id);
          }
        }
        _draft['context_dirty'] = true;
        _draft.remove('context_request');
        stage = DecanReviewStage.choosing;
        notice = 'Review these preserved moments before keeping them.';
    }
    await _persist();
  });

  void changePostOptions({bool? question, bool? reading}) {
    if (question != null) includeQuestion = question;
    if (reading != null) includeReading = reading;
    _draft['post_dirty'] = true;
    _persistLater();
    _changed();
  }

  Future<void> publish() => _run(() async {
    if (post?.isHidden == true)
      throw StateError(
        'This post was removed. Your Journal keeps its own words.',
      );
    if (postText.trim().isEmpty)
      throw StateError('Write the words you want to share.');
    _draft['post_id'] ??= post?.id ?? const Uuid().v4();
    final request = await _pendingRequest('post_request', {
      'p_account': account,
      'p_post': _draft['post_id'],
      'p_reflection': reflection!.id,
      'p_expected_revision': _draft['post_revision'] ?? post?.revision ?? 0,
      'p_body': postText.trim(),
      'p_include_question': includeQuestion,
      'p_reading_slug': includeReading ? readingId : null,
      'p_date': DecanReviewWindow.date(journalDate ?? DateTime.now()),
      'p_remove': false,
    });
    post = await _profiles.saveDecanPostRequest(request);
    if (!valid) return;
    _draft.remove('post_request');
    _draft['post_dirty'] =
        postText.trim() != request['p_body'] ||
        includeQuestion != request['p_include_question'] ||
        (includeReading ? readingId : null) != request['p_reading_slug'];
    _draft['post_revision'] = post?.revision ?? 0;
    await _persist();
    if (post == null)
      throw StateError('The post is no longer visible. Your Journal is kept.');
    stage = _draft['post_dirty'] == true
        ? DecanReviewStage.publishing
        : DecanReviewStage.posted;
  });
  Future<void> removePost() => _run(() async {
    if (post == null) return;
    final request = await _pendingRequest('remove_request', {
      'p_account': account,
      'p_post': post!.id,
      'p_reflection': reflection!.id,
      'p_expected_revision': post!.revision,
      'p_body': '',
      'p_include_question': false,
      'p_reading_slug': null,
      'p_date': DecanReviewWindow.date(post!.entryDate),
      'p_remove': true,
    });
    await _profiles.saveDecanPostRequest(request);
    post = await _profiles.getDecanPost(reflection!.id);
    _draft.remove('remove_request');
    await _persist();
    stage = DecanReviewStage.saved;
  });
  Future<void> explore() => _run(() async {
    stage = DecanReviewStage.continuation;
    await _prepareSuggestions();
  });
  Future<void> _prepareSuggestions() async {
    final joined = await FlowsRepo(_client).decanContinuationJoinedKeys();
    if (!valid) return;
    final candidates = DecanReviewSuggestions.build(
      moments: selectedMoments,
      excluded: {..._historyExclusions, ...review!.dismissedSuggestions},
      joinedFlowKeys: joined,
    );
    final readingIds = candidates
        .map((c) => c.libraryId)
        .whereType<String>()
        .toList();
    final progress = await SupabaseLibraryReadProgressRemote(
      _client,
    ).fetchSelected(userId: account, ids: readingIds);
    if (!valid) return;
    final completed = progress
        .where((p) => p.completedAt != null)
        .map((p) => p.nodeId)
        .toSet();
    suggestions = candidates
        .where((c) => !completed.contains(c.libraryId))
        .toList();
    review = review!.copyWith(
      presentedSuggestions: {
        ...review!.presentedSuggestions,
        ...suggestions.map((s) => s.id),
      },
    );
    _draft['context_dirty'] = true;
    await _saveContext();
  }

  Future<void> dismissSuggestion(DecanContinuation item) => _run(() async {
    review = review!.copyWith(
      dismissedSuggestions: {...review!.dismissedSuggestions, item.id},
    );
    _draft['context_dirty'] = true;
    await _saveContext();
    suggestions.removeWhere((s) => s.id == item.id);
  });
  Future<Map<String, dynamic>> _pendingRequest(
    String key,
    Map<String, dynamic> values,
  ) async {
    final old = _draft[key];
    if (old is Map) {
      final candidate = Map<String, dynamic>.from(old)..remove('p_mutation');
      if (jsonEncode(candidate) == jsonEncode(values))
        return Map<String, dynamic>.from(old);
    }
    final request = {...values, 'p_mutation': const Uuid().v4()};
    _draft[key] = request;
    await _persist();
    return request;
  }

  Future<void> _run(Future<void> Function() action) async {
    if (loading || busy || !valid) return;
    busy = true;
    notice = null;
    _changed();
    try {
      await action();
    } catch (e) {
      notice = e is DecanReviewConflict
          ? e.toString()
          : e is StateError
          ? e.message.toString()
          : 'Could not finish saving. Your draft is kept; try again.';
    } finally {
      busy = false;
      _changed();
    }
  }

  void _persistLater() {
    unawaited(
      _persist().catchError((Object e) {
        notice =
            'Could not keep this draft on the device. Keep this screen open and retry.';
        _changed();
      }),
    );
  }

  Future<void> _persist() {
    final key = draftKey;
    final data = jsonEncode({
      ..._draft,
      'answer': answer,
      'post_text': postText,
      'own_moment': ownMoment,
      'include_question': includeQuestion,
      'include_reading': includeReading,
      if (review != null) 'context': review!.toJson(),
    });
    final write = _draftWrites.catchError((_) {}).then((_) async {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(key, data))
        throw StateError('Draft could not be kept on this device');
    });
    _draftWrites = write;
    return write;
  }

  @override
  void dispose() {
    _disposed = true;
    _accountSub.cancel();
    _fence.dispose();
    super.dispose();
  }
}
