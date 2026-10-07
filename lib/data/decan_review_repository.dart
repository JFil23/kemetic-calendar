part of 'decan_reflection_repo.dart';

class DecanActivityPage {
  const DecanActivityPage(
    this.items,
    this.nextCursor, {
    this.previousQuestionId,
    this.excludedSuggestions = const {},
  });
  final List<DecanMoment> items;
  final String? nextCursor, previousQuestionId;
  final Set<String> excludedSuggestions;
}

class DecanReviewConflict implements Exception {
  const DecanReviewConflict(this.result);
  final Map<String, dynamic> result;
  @override
  String toString() =>
      'This reflection changed elsewhere. Your draft is kept; review the saved version before trying again.';
}

extension DecanReviewRepository on DecanReflectionRepo {
  Future<List<Map<String, dynamic>>> preservedReviewDrafts(String id) async {
    final fence = AccountOperationFence(_client);
    try {
      if (fence.userId == null) throw StateError('Sign in to open your drafts');
      final raw = await _client.rpc(
        'read_decan_recovery_v1',
        params: {'p_account': fence.userId, 'p_reflection': id},
      );
      if (!fence.isCurrent) throw StateError('Account changed');
      return (raw as List)
          .whereType<Map>()
          .map((r) => Map<String, dynamic>.from(r))
          .toList();
    } finally {
      fence.dispose();
    }
  }

  Future<DecanActivityPage> reviewActivity({
    required DateTime start,
    required DateTime end,
    required String source,
    String? cursor,
    bool cachedOnly = false,
  }) async {
    final fence = AccountOperationFence(_client);
    final account = fence.userId;
    if (account == null) {
      fence.dispose();
      throw StateError('Sign in to review these days');
    }
    final startDate = _fmtStoredDate(start);
    final endDate = _fmtStoredDate(end);
    final utcStart = DateTime(start.year, start.month, start.day).toUtc();
    final utcEnd = DateTime(end.year, end.month, end.day + 1).toUtc();
    try {
      final raw =
          await WarmJsonReads(
            _client,
            cachedOnly: cachedOnly,
            mayFetch: () => fence.isCurrent,
          ).value(
            'reflection.activity.$startDate.$endDate.$source.${Uri.encodeComponent(cursor ?? 'first')}',
            () => _client.rpc(
              'read_decan_activity_v1',
              params: {
                'p_account': account,
                'p_start': startDate,
                'p_end': endDate,
                'p_start_utc': utcStart.toIso8601String(),
                'p_end_utc': utcEnd.toIso8601String(),
                'p_source': source,
                'p_cursor': cursor,
              },
            ),
          );
      if (!fence.isCurrent)
        throw StateError('Account changed while reading reflection activity');
      final page = Map<String, dynamic>.from(raw as Map);
      final items = <DecanMoment>[];
      final excluded = <String>{};
      String? previousQuestion;
      for (final value in page['items'] as List) {
        final row = Map<String, dynamic>.from(value as Map);
        excluded.addAll(
          (row['excluded_suggestions'] as List? ?? []).cast<String>(),
        );
        previousQuestion = row['question_id'] as String? ?? previousQuestion;
        final item = decanMomentFromActivity(row);
        if (item != null) items.add(item);
      }
      return DecanActivityPage(
        items,
        page['next_cursor'] as String?,
        previousQuestionId: previousQuestion,
        excludedSuggestions: excluded,
      );
    } finally {
      fence.dispose();
    }
  }

  Future<DecanReflection> saveReviewRequest(
    Map<String, dynamic> request,
  ) async {
    final result = await _reviewMutation('apply_decan_review_v1', request);
    return DecanReflection.fromJson(
      Map<String, dynamic>.from(result['row'] as Map),
    );
  }

  Future<Map<String, dynamic>> saveReviewAnswerRequest(
    Map<String, dynamic> request,
  ) => _reviewMutation('apply_decan_journal_v1', request);

  Future<Map<String, dynamic>> _reviewMutation(
    String rpc,
    Map<String, dynamic> request,
  ) async {
    final fence = AccountOperationFence(_client);
    final account = fence.userId;
    if (account == null || request['p_account'] != account) {
      fence.dispose();
      throw StateError('Account changed before reflection save');
    }
    final domains = rpc == 'apply_decan_journal_v1'
        ? [
            'reflection.source.${request['p_reflection']}',
            'reflection.activity.',
            'journal.',
            'pages.journal.',
          ]
        : ['reflection.'];
    try {
      final raw = await _client.rpc(rpc, params: request);
      if (!fence.isCurrent)
        throw StateError('Account changed during reflection save');
      final result = Map<String, dynamic>.from(raw as Map);
      invalidateWarmDomains(account, domains);
      if (result['status'] != 'applied') throw DecanReviewConflict(result);
      // Warm presentation is published from the acknowledged server row. The
      // durable intent stays in the account draft store until acknowledgement.
      final row = Map<String, dynamic>.from(result['row'] as Map);
      if (rpc == 'apply_decan_journal_v1') {
        final current = Map<String, dynamic>.from(
          await _client.rpc(
                'read_journal_state_v1',
                params: {'p_account': account, 'p_date': request['p_date']},
              )
              as Map,
        );
        if (!fence.isCurrent)
          throw StateError('Account changed after reflection save');
        if (current['revision'] != result['revision'])
          throw DecanReviewConflict({'status': 'conflict', ...current});
      } else {
        final current = await _client
            .from('decan_reflections')
            .select()
            .eq('user_id', account)
            .eq('id', row['id'])
            .maybeSingle();
        if (!fence.isCurrent)
          throw StateError('Account changed after reflection save');
        if (current == null ||
            current['review_revision'] != row['review_revision'])
          throw DecanReviewConflict({'status': 'conflict', 'row': current});
      }
      final key = rpc == 'apply_decan_journal_v1'
          ? 'journal.entry.${row['id']}'
          : 'reflection.${row['id']}';
      await WarmSnapshotStore.instance.refresh(
        account,
        key,
        () async => row,
        isCurrent: () => fence.isCurrent,
      );
      return result;
    } catch (_) {
      invalidateWarmDomains(account, domains);
      rethrow;
    } finally {
      fence.dispose();
    }
  }

  Future<Map<String, dynamic>?> reviewJournalSource(
    String reflectionId, {
    bool cachedOnly = false,
  }) async {
    final fence = AccountOperationFence(_client);
    final account = fence.userId;
    if (account == null) {
      fence.dispose();
      throw StateError('Sign in to open your Journal');
    }
    try {
      final raw =
          await WarmJsonReads(
            _client,
            cachedOnly: cachedOnly,
            mayFetch: () => fence.isCurrent,
          ).value(
            'reflection.source.$reflectionId',
            () => _client
                .from('decan_journal_sources')
                .select()
                .eq('user_id', account)
                .eq('reflection_id', reflectionId)
                .maybeSingle(),
          );
      if (!fence.isCurrent)
        throw StateError('Account changed while opening Journal');
      return raw == null ? null : Map<String, dynamic>.from(raw as Map);
    } finally {
      fence.dispose();
    }
  }
}

/// Parse factual records from the existing owners. A missing catalog title is
/// not replaced with invented text; the remaining source stays navigable.
DecanMoment? decanMomentFromActivity(Map<String, dynamic> row) {
  final kind = row['kind'] as String;
  final flowKey = row['flow_key'] as String?;
  var text = (row['text'] as String? ?? '').trim();
  var source = 'Your flow';
  var action = 'Recorded';
  final libraryId = row['library_id'] as String?;
  final reading = libraryId == null
      ? null
      : KemeticNodeLibrary.resolve(libraryId);
  var quote = false;
  switch (kind) {
    case 'flow':
      source =
          DecanReviewSuggestions.flowTitles[flowKey] ??
          (row['flow_title'] as String? ?? 'Your flow');
      final status = row['status'] as String?;
      action = switch (status) {
        'observed' || 'observed_from_inside' => 'Observed',
        'partial' ||
        'observed_partly' ||
        'partly_observed' => 'Partly observed',
        'skipped' => 'Skipped',
        'raised' => 'Raised',
        'held' => 'Held',
        'slipped' => 'Slipped',
        'carrying' => 'Carrying',
        'not_yet' => 'Not yet',
        'names_spoken' => 'Names spoken',
        'completed' || 'complete' || 'done' => 'Completed',
        _ => 'Recorded',
      };
    case 'library':
      if (reading == null) return null;
      source = 'Library';
      text = reading.title;
      action = row['action'] == 'bookmarked' ? 'Bookmarked' : 'Opened';
    case 'response':
      source = DecanReviewSuggestions.flowTitles[flowKey] ?? 'Your flow';
      action = row['is_excerpt'] == true
          ? 'Your words · excerpt'
          : 'Your words';
      quote = true;
    case 'journal':
      source = 'Journal';
      action = 'Choose an excerpt';
      text = JournalBadgeUtils.stripBadgesFromPlainText(text).trim();
      quote = true;
    case 'previous':
      source = 'Previous reflection';
      action = 'Your words';
      quote = true;
    default:
      return null;
  }
  if (text.isEmpty) return null;
  final date = DateTime.tryParse(row['occurred_on'] as String? ?? '');
  return DecanMoment(
    id: row['id'] as String,
    kind: kind,
    sourceId: row['source_id'].toString(),
    occurredOn: date?.toLocal(),
    sourceLabel: source,
    actionLabel: action,
    text: text,
    flowId: (row['flow_id'] as num?)?.toInt(),
    eventNumber: (row['event_number'] as num?)?.toInt(),
    flowKey: flowKey,
    libraryId: libraryId,
    journalEntryId: row['journal_entry_id'] as String?,
    isQuote: quote,
  );
}
