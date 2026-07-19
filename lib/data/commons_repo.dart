import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show DateUtils;
import 'package:mobile/core/supabase_auth_retry.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'commons_models.dart';
import 'profile_repo.dart';
import 'profile_feed_item_model.dart';
import 'shared_practice_models.dart';

class CommonsRepo {
  CommonsRepo(this._client);

  final SupabaseClient _client;

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[CommonsRepo] $message');
    }
  }

  Future<CommonsHomeSnapshot> getCommonsHome({
    required DateTime localDate,
    required String questionId,
    required String questionText,
    int limit = 12,
  }) async {
    final date = DateUtils.dateOnly(localDate.toLocal());
    try {
      final response = await withSupabaseAuthRetry(
        _client,
        () => _client.rpc(
          'get_commons_home',
          params: <String, dynamic>{
            'p_local_date': _dateOnly(date),
            'p_question_id': questionId.trim(),
            'p_question_text': questionText.trim(),
            'p_limit': limit,
          },
        ),
      );
      if (response is Map<String, dynamic>) {
        return CommonsHomeSnapshot.fromJson(response);
      }
      if (response is Map) {
        return CommonsHomeSnapshot.fromJson(
          Map<String, dynamic>.from(response),
        );
      }
      throw StateError(
        'Unexpected Commons home response: ${response.runtimeType}',
      );
    } catch (e) {
      _log('get_commons_home unavailable: $e');
      return _fallbackHome(
        localDate: date,
        questionId: questionId,
        questionText: questionText,
        limit: limit,
      );
    }
  }

  Future<CommonsAnswer> answerQuestion({
    required String questionId,
    required String questionText,
    required String body,
  }) async {
    final response = await withSupabaseAuthRetry(
      _client,
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
  }

  Future<void> deleteAnswer(String answerId) async {
    await withSupabaseAuthRetry(
      _client,
      () => _client.rpc(
        'delete_commons_answer',
        params: <String, dynamic>{'p_answer_id': answerId.trim()},
      ),
    );
  }

  Future<CommonsPracticeRoom> setPracticeVisibility({
    required String roomId,
    required SharedPracticeRoomVisibility visibility,
    SharedPracticeJoinPolicy? joinPolicy,
  }) async {
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
      return CommonsPracticeRoom.fromJson(Map<String, dynamic>.from(response));
    }
    throw StateError(
      'Unexpected shared practice visibility response: ${response.runtimeType}',
    );
  }

  Future<SharedPracticeJoinRequest> requestJoinSharedPractice({
    required String roomId,
    String? message,
  }) async {
    final response = await withSupabaseAuthRetry(
      _client,
      () => _client.rpc(
        'request_join_shared_practice',
        params: <String, dynamic>{
          'p_room_id': roomId.trim(),
          if (message != null && message.trim().isNotEmpty)
            'p_message': message.trim(),
        },
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
  }

  Future<CommonsHomeSnapshot> _fallbackHome({
    required DateTime localDate,
    required String questionId,
    required String questionText,
    required int limit,
  }) async {
    final profileRepo = ProfileRepo(_client);
    CommonsRhythmSummary rhythm = CommonsRhythmSummary.empty();
    try {
      final rollups = await profileRepo.getCommunityRhythmRollups(
        localDate: localDate,
      );
      if (rollups != null) {
        final labels = <String, String>{};
        for (final rollup in rollups) {
          if (rollup.isVisible) labels[rollup.metric] = rollup.countLabel!;
        }
        rhythm = rhythm.copyWith(
          activeUsersTodayLabel: labels['flow_steps_completed'] ?? '0',
          flowsKeptTodayLabel: labels['flow_steps_completed'] ?? '0',
          publicFragmentsTodayLabel: labels['insight_fragments_shared'] ?? '0',
        );
      }
    } catch (e) {
      _log('fallback rhythm failed: $e');
    }

    final discover = await profileRepo
        .getProfileFeedResult(limit: limit, offset: 0)
        .then<List<ProfileFeedItem>>((result) => result.data)
        .catchError((Object e) {
          _log('fallback discover failed: $e');
          return <ProfileFeedItem>[];
        });

    return CommonsHomeSnapshot(
      rhythm: rhythm,
      questions: <CommonsQuestion>[
        CommonsQuestion(id: questionId, question: questionText),
      ],
      discover: discover,
    );
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
