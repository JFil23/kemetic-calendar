import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_pending_note_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  PendingCalendarNoteRecord record(String title) => PendingCalendarNoteRecord(
    clientEventId: 'same-cid',
    dayKey: '2-1-1',
    createdAt: DateTime.utc(2026, 8, 10, 20),
    notePayload: <String, dynamic>{
      'clientEventId': 'same-cid',
      'title': title,
      'allDay': true,
    },
  );

  test('records are isolated by user even when CID is the same', () async {
    final store = PendingCalendarNoteStore();
    await store.write(userId: 'user-a', record: record('A'));
    await store.write(userId: 'user-b', record: record('B'));

    final userA = await store.readForUser('user-a');
    final userB = await store.readForUser('user-b');
    expect(userA.single.notePayload['title'], 'A');
    expect(userB.single.notePayload['title'], 'B');
    expect(userA.single.createdAt, DateTime.utc(2026, 8, 10, 20));

    await store.remove(userId: 'user-a', clientEventId: 'same-cid');
    expect(await store.readForUser('user-a'), isEmpty);
    expect(await store.readForUser('user-b'), hasLength(1));
  });

  test('clearForUser leaves another account intact', () async {
    final store = PendingCalendarNoteStore();
    await store.write(userId: 'user-a', record: record('A'));
    await store.write(userId: 'user-b', record: record('B'));

    await store.clearForUser('user-a');

    expect(await store.readForUser('user-a'), isEmpty);
    expect(await store.readForUser('user-b'), hasLength(1));
  });
}
