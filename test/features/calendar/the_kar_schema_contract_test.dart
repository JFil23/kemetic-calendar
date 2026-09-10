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
        'grant select, insert, update on table public.kar_shrines to authenticated',
      ),
    );
    expect(source, isNot(contains('grant delete')));
    expect(source, isNot(contains('for delete')));
    expect(source, contains('revision bigint not null default 0'));
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
}
