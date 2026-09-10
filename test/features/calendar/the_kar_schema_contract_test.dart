import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const path =
      '../supabase/migrations/20260910092351_kar_private_versioned_history.sql';

  test('Kꜣr persistence is private, permanent, and one-per-user/netjer', () {
    final source = File(path).readAsStringSync();

    expect(source, contains('create table public.kar_shrines'));
    expect(source, contains('unique (user_id, netjer_key)'));
    expect(
      source,
      contains('alter table public.kar_shrines enable row level security'),
    );
    expect(source, contains('using ((select auth.uid()) = user_id)'));
    expect(source, contains('with check ((select auth.uid()) = user_id)'));
    expect(
      source,
      contains('revoke all on table public.kar_shrines from anon'),
    );
    expect(
      source,
      contains(
        'grant select, insert on table public.kar_shrines to authenticated',
      ),
    );
    expect(
      source,
      contains(
        'grant update (state, revision, updated_at)\n'
        '  on table public.kar_shrines\n'
        '  to authenticated',
      ),
    );
    expect(
      source,
      isNot(
        contains(
          'grant select, insert, update on table public.kar_shrines to authenticated',
        ),
      ),
    );
    expect(source, isNot(contains('grant delete')));
    expect(source, isNot(contains('for delete')));
    expect(source, contains('revision bigint not null default 0'));
    expect(source, contains('application-preserved scene lineage'));
  });

  test('migration accepts exactly the six authored netjer identities', () {
    final source = File(path).readAsStringSync();
    for (final key in const <String>[
      'djehuty',
      'maat',
      'sekhmet',
      'hetheru',
      'khepri',
      'ptah',
    ]) {
      expect(source, contains("'$key'"), reason: key);
    }
  });

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
