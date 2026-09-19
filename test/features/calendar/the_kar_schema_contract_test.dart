import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('save is one compare-and-swap and never overwrites a conflict', () {
    final source = File(
      'lib/features/calendar/the_kar/kar_repository.dart',
    ).readAsStringSync();
    final supabaseSave = source.substring(
      source.indexOf(
        'Future<KarShrine> save(KarShrine shrine) async {',
        source.indexOf('class SupabaseKarRepository'),
      ),
      source.indexOf('class MemoryKarRepository'),
    );

    expect(supabaseSave, contains("'state': shrine.toStateJson()"));
    expect(supabaseSave, contains("'revision': shrine.revision + 1"));
    expect(
      supabaseSave,
      contains("'updated_at': DateTime.now().toUtc().toIso8601String()"),
    );
    expect(supabaseSave, contains(".eq('id', shrine.id)"));
    expect(supabaseSave, contains(".eq('user_id', _userId)"));
    expect(supabaseSave, contains(".eq('revision', shrine.revision)"));
    expect(supabaseSave, contains('.select()'));
    expect(supabaseSave, contains('.maybeSingle()'));
    expect(
      supabaseSave,
      contains('if (updated == null) throw const KarRevisionConflict();'),
    );
    expect(supabaseSave, isNot(contains('catch')));
    expect(supabaseSave, isNot(contains("'id':")));
    expect(supabaseSave, isNot(contains("'user_id':")));
    expect(supabaseSave, isNot(contains("'netjer_key':")));
    expect(supabaseSave, isNot(contains("'created_at':")));
  });
}
