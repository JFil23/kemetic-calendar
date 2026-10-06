import 'warm_state/warm_mutation.dart';
import 'dart:async';
import 'warm_state/warm_json_reads.dart';

import 'package:flutter/material.dart' show DateUtils;
import 'package:mobile/core/supabase_auth_retry.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'commons_models.dart';
import 'account_view_cache.dart';
import 'account_operation_fence.dart';
import 'warm_state/warm_snapshot_store.dart';
import 'shared_practice_models.dart';

class CommonsRepo {
  CommonsRepo(this._client);

  final SupabaseClient _client;

  Future<T> _answerWrite<T>(Future<T> Function() request) async {
    final account = AccountOperationFence(_client);
    try {
      final result = await withSupabaseAuthRetry(_client, () {
        if (!account.isCurrent || account.userId == null) {
          throw const WarmReadCancelled();
        }
        return request();
      });
      if (!account.isCurrent) throw const WarmReadCancelled();
      return result;
    } finally {
      account.dispose();
    }
  }

  Future<CommonsHomeSnapshot> getCommonsHome({
    required DateTime localDate,
    required String questionId,
    required String questionText,
    int limit = 12,
    bool cachedOnly = false,
    bool strict = false,
  }) async {
    final account = AccountOperationFence(_client);
    final uid = account.userId;
    final date = DateUtils.dateOnly(localDate.toLocal());
    try {
      final response =
          await WarmJsonReads(
            _client,
            cachedOnly: cachedOnly,
            mayFetch: () => account.isCurrent,
          ).value(
            'commons.home.${_dateOnly(date)}.$questionId.$limit',
            () => withSupabaseAuthRetry(
              _client,
              () => _client.rpc(
                'get_commons_together_home_cards',
                params: <String, dynamic>{
                  'p_local_date': _dateOnly(date),
                  'p_question_id': questionId.trim(),
                  'p_question_text': questionText.trim(),
                  'p_limit': limit,
                },
              ),
            ),
          );
      if (response is! Map) {
        throw StateError(
          'Unexpected Commons home response: ${response.runtimeType}',
        );
      }
      final quoteResponse =
          await WarmJsonReads(
            _client,
            cachedOnly: cachedOnly,
            mayFetch: () => account.isCurrent,
          ).value(
            'commons.quotes.$limit',
            () => withSupabaseAuthRetry(
              _client,
              () => _client.rpc(
                'get_shared_practice_quote_posts',
                params: <String, dynamic>{'p_room_id': null, 'p_limit': limit},
              ),
            ),
          );
      if (!account.isCurrent) throw const WarmReadCancelled();
      final snapshot = CommonsHomeSnapshot.fromJson(<String, dynamic>{
        ...Map<String, dynamic>.from(response),
        'group_quote_posts': quoteResponse is List
            ? quoteResponse
            : const <dynamic>[],
      });
      if (uid != null && uid == _client.auth.currentUser?.id) {
        AccountViewCache.instance.publish(uid, 'social.commons', snapshot);
      }
      return snapshot;
    } finally {
      account.dispose();
    }
  }

  Future<CommonsAnswerPage> getQuestionAnswers({
    required String questionId,
    required CommonsAnswer before,
    int limit = 12,
    bool cachedOnly = false,
  }) async {
    if (before.createdAt == null || before.questionId != questionId) {
      throw const FormatException('Invalid Commons answer cursor');
    }
    final account = AccountOperationFence(_client);
    try {
      final stamp =
          before.createdAtCursor ?? before.createdAt!.toUtc().toIso8601String();
      final response =
          await WarmJsonReads(
            _client,
            cachedOnly: cachedOnly,
            mayFetch: () => account.isCurrent,
          ).value(
            'commons.answers.$questionId.$stamp.${before.id}.$limit',
            () => withSupabaseAuthRetry(
              _client,
              () => _client.rpc(
                'get_commons_question_answers',
                params: {
                  'p_question_id': questionId,
                  'p_before_created_at': stamp,
                  'p_before_id': before.id,
                  'p_limit': limit,
                },
              ),
            ),
            validate: (raw) {
              final page = CommonsAnswerPage.fromJson(raw);
              if (page.answers.any((a) => a.questionId != questionId)) {
                throw const FormatException('Wrong Commons question');
              }
            },
          );
      if (!account.isCurrent) throw const WarmReadCancelled();
      return CommonsAnswerPage.fromJson(response);
    } finally {
      account.dispose();
    }
  }

  Future<CommonsAnswer> answerQuestion({
    required String questionId,
    required String questionText,
    required String body,
  }) async {
    final warmAccount = _client.auth.currentUser?.id;
    invalidateWarmDomains(warmAccount, [
      'commons.',
      'social.commons',
      'pages.commons',
    ]);
    try {
      final response = await _answerWrite(
        () => _client.rpc(
          'answer_commons_question',
          params: <String, dynamic>{
            'p_question_id': questionId.trim(),
            'p_question_text': questionText.trim(),
            'p_body': body.trim(),
          },
        ),
      );
      if (response is Map<String, dynamic>) {
        return CommonsAnswer.fromJson(response);
      }
      if (response is Map) {
        return CommonsAnswer.fromJson(Map<String, dynamic>.from(response));
      }
      throw StateError(
        'Unexpected Commons answer response: ${response.runtimeType}',
      );
    } finally {
      invalidateWarmDomains(warmAccount, [
        'commons.',
        'social.commons',
        'pages.commons',
      ]);
    }
  }

  Future<void> deleteAnswer(String answerId) async {
    final warmAccount = _client.auth.currentUser?.id;
    invalidateWarmDomains(warmAccount, [
      'commons.',
      'social.commons',
      'pages.commons',
    ]);
    try {
      await _answerWrite(
        () => _client.rpc(
          'delete_commons_answer',
          params: <String, dynamic>{'p_answer_id': answerId.trim()},
        ),
      );
    } finally {
      invalidateWarmDomains(warmAccount, [
        'commons.',
        'social.commons',
        'pages.commons',
      ]);
    }
  }

  Future<CommonsPracticeRoom> setPracticeVisibility({
    required String roomId,
    required SharedPracticeRoomVisibility visibility,
    SharedPracticeJoinPolicy? joinPolicy,
  }) async {
    final warmAccount = _client.auth.currentUser?.id;
    invalidateWarmDomains(warmAccount, [
      'commons.',
      'social.commons',
      'pages.commons',
    ]);
    try {
      final response = await withSupabaseAuthRetry(
        _client,
        () => _client.rpc(
          'set_shared_practice_visibility',
          params: <String, dynamic>{
            'p_room_id': roomId.trim(),
            'p_visibility': visibility.wireName,
            'p_join_policy':
                joinPolicy?.wireName ??
                (visibility == SharedPracticeRoomVisibility.public
                    ? SharedPracticeJoinPolicy.ownerApproval.wireName
                    : SharedPracticeJoinPolicy.closed.wireName),
          },
        ),
      );
      if (response is Map<String, dynamic>) {
        return CommonsPracticeRoom.fromJson(response);
      }
      if (response is Map) {
        return CommonsPracticeRoom.fromJson(
          Map<String, dynamic>.from(response),
        );
      }
      throw StateError(
        'Unexpected shared practice visibility response: ${response.runtimeType}',
      );
    } finally {
      invalidateWarmDomains(warmAccount, [
        'commons.',
        'social.commons',
        'pages.commons',
      ]);
    }
  }

  Future<SharedPracticeJoinRequest> requestJoinSharedPractice({
    required String roomId,
  }) async {
    final warmAccount = _client.auth.currentUser?.id;
    invalidateWarmDomains(warmAccount, [
      'commons.',
      'social.commons',
      'pages.commons',
    ]);
    try {
      final response = await withSupabaseAuthRetry(
        _client,
        () => _client.rpc(
          'request_join_shared_practice',
          params: <String, dynamic>{'p_room_id': roomId.trim()},
        ),
      );
      if (response is Map<String, dynamic>) {
        return SharedPracticeJoinRequest.fromJson(response);
      }
      if (response is Map) {
        return SharedPracticeJoinRequest.fromJson(
          Map<String, dynamic>.from(response),
        );
      }
      throw StateError(
        'Unexpected shared practice join response: ${response.runtimeType}',
      );
    } finally {
      invalidateWarmDomains(warmAccount, [
        'commons.',
        'social.commons',
        'pages.commons',
      ]);
    }
  }

  Future<SharedPracticeJoinRequest> cancelJoinSharedPractice({
    required String roomId,
  }) async {
    final warmAccount = _client.auth.currentUser?.id;
    invalidateWarmDomains(warmAccount, [
      'commons.',
      'social.commons',
      'pages.commons',
    ]);
    try {
      final response = await withSupabaseAuthRetry(
        _client,
        () => _client.rpc(
          'cancel_join_shared_practice',
          params: <String, dynamic>{'p_room_id': roomId.trim()},
        ),
      );
      if (response is Map<String, dynamic>) {
        return SharedPracticeJoinRequest.fromJson(response);
      }
      if (response is Map) {
        return SharedPracticeJoinRequest.fromJson(
          Map<String, dynamic>.from(response),
        );
      }
      throw StateError(
        'Unexpected shared practice cancellation response: '
        '${response.runtimeType}',
      );
    } finally {
      invalidateWarmDomains(warmAccount, [
        'commons.',
        'social.commons',
        'pages.commons',
      ]);
    }
  }

  Future<({bool likedByMe, int likesCount})> togglePracticeLike({
    required String roomId,
  }) async {
    final warmAccount = _client.auth.currentUser?.id;
    invalidateWarmDomains(warmAccount, [
      'commons.',
      'social.commons',
      'pages.commons',
    ]);
    try {
      final response = await withSupabaseAuthRetry(
        _client,
        () => _client.rpc(
          'toggle_shared_practice_room_like',
          params: <String, dynamic>{'p_room_id': roomId.trim()},
        ),
      );
      if (response is! Map) {
        throw StateError(
          'Unexpected shared practice like response: ${response.runtimeType}',
        );
      }
      return (
        likedByMe: response['liked_by_me'] == true,
        likesCount: (response['likes_count'] as num?)?.toInt() ?? 0,
      );
    } finally {
      invalidateWarmDomains(warmAccount, [
        'commons.',
        'social.commons',
        'pages.commons',
      ]);
    }
  }

  Future<void> setPracticeAccess({
    required String roomId,
    required SharedPracticeRoomVisibility visibility,
    required SharedPracticeRequestAudience requestAudience,
  }) async {
    final warmAccount = _client.auth.currentUser?.id;
    invalidateWarmDomains(warmAccount, [
      'commons.',
      'social.commons',
      'pages.commons',
    ]);
    try {
      await withSupabaseAuthRetry(
        _client,
        () => _client.rpc(
          'set_shared_practice_access',
          params: <String, dynamic>{
            'p_room_id': roomId.trim(),
            'p_visibility': visibility.wireName,
            'p_request_audience': requestAudience.wireName,
          },
        ),
      );
    } finally {
      invalidateWarmDomains(warmAccount, [
        'commons.',
        'social.commons',
        'pages.commons',
      ]);
    }
  }

  Future<({bool likedByMe, int likesCount})> toggleQuoteLike({
    required String quotePostId,
  }) async {
    final warmAccount = _client.auth.currentUser?.id;
    invalidateWarmDomains(warmAccount, [
      'commons.',
      'social.commons',
      'pages.commons',
    ]);
    try {
      final response = await withSupabaseAuthRetry(
        _client,
        () => _client.rpc(
          'toggle_shared_practice_quote_like',
          params: <String, dynamic>{'p_quote_post_id': quotePostId.trim()},
        ),
      );
      if (response is! Map) {
        throw StateError(
          'Unexpected quote like response: ${response.runtimeType}',
        );
      }
      return (
        likedByMe: response['liked_by_me'] == true,
        likesCount: (response['likes_count'] as num?)?.toInt() ?? 0,
      );
    } finally {
      invalidateWarmDomains(warmAccount, [
        'commons.',
        'social.commons',
        'pages.commons',
      ]);
    }
  }

  Future<SharedPracticeQuoteComment> addQuoteComment({
    required String quotePostId,
    required String bodyText,
  }) async {
    final warmAccount = _client.auth.currentUser?.id;
    invalidateWarmDomains(warmAccount, [
      'commons.',
      'social.commons',
      'pages.commons',
    ]);
    try {
      final response = await withSupabaseAuthRetry(
        _client,
        () => _client.rpc(
          'add_shared_practice_quote_comment',
          params: <String, dynamic>{
            'p_quote_post_id': quotePostId.trim(),
            'p_body_text': bodyText.trim(),
          },
        ),
      );
      if (response is Map) {
        return SharedPracticeQuoteComment.fromJson(
          Map<String, dynamic>.from(response),
        );
      }
      throw StateError(
        'Unexpected quote comment response: ${response.runtimeType}',
      );
    } finally {
      invalidateWarmDomains(warmAccount, [
        'commons.',
        'social.commons',
        'pages.commons',
      ]);
    }
  }
}

String _dateOnly(DateTime value) {
  final local = DateTime(value.year, value.month, value.day);
  return [
    local.year.toString().padLeft(4, '0'),
    local.month.toString().padLeft(2, '0'),
    local.day.toString().padLeft(2, '0'),
  ].join('-');
}
