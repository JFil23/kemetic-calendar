import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mobile/repositories/dm_conversation_repo.dart';

void main() {
  group('DmConversationRepo failure classification', () {
    test('maps missing summary view to backend unavailable', () {
      final failure = classifyDmConversationFailure(
        operation: DmConversationOperation.listConversations,
        localOverrideActive: false,
        error: const PostgrestException(
          message:
              "Could not find the table 'public.dm_conversation_summaries' in the schema cache",
          code: 'PGRST205',
        ),
      );

      expect(failure.category, DmConversationErrorCategory.backendUnavailable);
      expect(
        userFacingDmConversationError(failure),
        'Group chats are not available on this backend yet.',
      );
      expect(
        dmConversationFailureDiagnostic(failure),
        allOf(
          contains('operation=list_conversations'),
          contains('status=n/a'),
          contains('category=backend_unavailable'),
          contains('code=PGRST205'),
          contains('localOverride=false'),
        ),
      );
    });

    test('maps missing edge function to backend unavailable', () {
      final failure = classifyDmConversationFailure(
        operation: DmConversationOperation.createConversation,
        localOverrideActive: false,
        error: const FunctionException(
          status: 404,
          details: {'message': 'Function not found', 'code': 'NOT_FOUND'},
          reasonPhrase: 'Not Found',
        ),
      );

      expect(failure.category, DmConversationErrorCategory.backendUnavailable);
      expect(failure.status, 404);
      expect(
        userFacingDmConversationError(failure),
        'Group chats are not available on this backend yet.',
      );
    });

    test('maps block and allow-incoming denials to participant copy', () {
      final failure = classifyDmConversationFailure(
        operation: DmConversationOperation.createConversation,
        localOverrideActive: true,
        status: 403,
        data: {'error': 'A selected user blocked another participant'},
      );

      expect(failure.category, DmConversationErrorCategory.participantDenied);
      expect(
        userFacingDmConversationError(failure),
        "One or more people can't be added to this group.",
      );
      expect(
        dmConversationFailureDiagnostic(failure),
        contains('localOverride=true'),
      );
    });

    test('keeps unknown errors on the generic retry message', () {
      const failure = DmConversationFailure(
        operation: DmConversationOperation.sendMessage,
        category: DmConversationErrorCategory.unknown,
        localOverrideActive: false,
      );

      expect(
        userFacingDmConversationError(failure),
        'Could not update messages right now. Please try again.',
      );
    });

    test('diagnostics do not include raw response text', () {
      final failure = classifyDmConversationFailure(
        operation: DmConversationOperation.createConversation,
        localOverrideActive: false,
        status: 403,
        data: {
          'code': 'BLOCKED',
          'message':
              'blocked participant user@example.com message body participantIds=[abc]',
        },
      );

      final diagnostic = dmConversationFailureDiagnostic(failure);
      expect(diagnostic, contains('category=participant_denied'));
      expect(diagnostic, contains('code=BLOCKED'));
      expect(diagnostic, isNot(contains('user@example.com')));
      expect(diagnostic, isNot(contains('message body')));
      expect(diagnostic, isNot(contains('participantIds')));
    });
  });
}
