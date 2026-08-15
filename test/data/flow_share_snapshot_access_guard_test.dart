import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('flow snapshots do not grant live access to sender event rows', () {
    final migration = File(
      '../supabase/migrations/20260815121000_drop_live_shared_flow_event_access.sql',
    ).readAsStringSync();

    expect(
      migration,
      contains('drop policy if exists "user_events_select_shared_flow_events"'),
    );
    expect(migration, contains('on public.user_events'));
  });
}
