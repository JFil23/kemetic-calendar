import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    '../supabase/migrations/'
    '20260905152737_reading_house_rooms_realtime_and_read_state.sql',
  ).readAsStringSync();

  test('read cursor is per user and exact House, with monotonic updates', () {
    expect(migration, contains('primary key (calendar_id, flow_id, user_id)'));
    expect(migration, contains('greatest('));
    expect(migration, contains('user_id = (select auth.uid())'));
    expect(migration, contains('HOUSE_READ_STATE_CANNOT_REGRESS'));
    expect(migration, contains('HOUSE_READ_STATE_IDENTITY_IMMUTABLE'));
    expect(migration, contains('new.last_read_at := least('));
  });

  test('read-state writes are RPC-only for authenticated clients', () {
    expect(
      migration,
      contains(
        'revoke insert, update, delete, truncate, references, trigger\n'
        'on public.reading_house_room_read_state from authenticated;',
      ),
    );
    expect(
      migration,
      contains(
        'grant select on public.reading_house_room_read_state to authenticated;',
      ),
    );
    expect(migration, isNot(contains('grant select, insert, update')));
    expect(
      migration,
      isNot(contains('create policy reading_house_room_read_state_insert_own')),
    );
    expect(
      migration,
      isNot(contains('create policy reading_house_room_read_state_update_own')),
    );
    expect(
      migration,
      contains(
        'before insert or update on public.reading_house_room_read_state',
      ),
    );
    expect(migration, contains('mark_reading_house_room_read'));
  });

  test('public House identity helper validates caller membership', () {
    final helperEnd = migration.indexOf(
      'revoke all on function public.reading_house_flow_on_calendar',
    );
    final helper = migration.substring(0, helperEnd);
    expect(helper, contains('security definer'));
    expect(helper, contains("set search_path = ''"));
    expect(helper, contains('auth.uid() is not null'));
    expect(helper, contains('public.reading_house_is_calendar_member('));
  });

  test('room summary is security-invoker and unread excludes own messages', () {
    expect(migration, contains('with (security_invoker = true)'));
    expect(migration, contains('unread.author_id <> (select auth.uid())'));
    expect(migration, contains('unread.deleted_at is null'));
  });

  test('all live room-lane mutations are server-rejected after ending', () {
    expect(
      'HOUSE_ENDED_READ_ONLY'.allMatches(migration),
      hasLength(greaterThanOrEqualTo(2)),
    );
    expect(migration, contains('private.reading_house_is_active_house'));
    expect(
      migration,
      contains('before insert or update or delete on public.%I'),
    );
    expect(
      migration,
      contains('private.guard_reading_house_live_lane_mutation()'),
    );
  });

  test('House identity is immutable and announcements remain host-only', () {
    expect(migration, contains('HOUSE_ROOM_IDENTITY_IMMUTABLE'));
    expect(
      migration,
      contains("tg_table_name = 'reading_house_announcements'"),
    );
    expect(migration, contains('public.reading_house_can_moderate_calendar('));
    expect(migration, contains('ANNOUNCEMENT_NOT_ALLOWED'));
  });

  test('chat edit and soft-delete mutations use authenticated RPCs', () {
    expect(migration, contains('update_reading_house_chat_message'));
    expect(migration, contains('delete_reading_house_chat_message'));
    expect(migration, contains('set deleted_at = timezone'));
    expect(migration, contains('v_message.author_id <> v_uid'));
  });

  test('approved Reading House lanes are idempotently published', () {
    for (final table in const <String>[
      'reading_house_chat_messages',
      'reading_house_shared_fragments',
      'reading_house_fragment_replies',
      'reading_house_announcements',
    ]) {
      expect(migration, contains("'$table'"));
    }
    expect(migration, contains("pubname = 'supabase_realtime'"));
    expect(
      migration,
      contains('alter publication supabase_realtime add table'),
    );
  });
}
