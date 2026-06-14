import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/reminders/reminder_model.dart';
import 'package:mobile/features/reminders/reminder_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('post-dispose updates do not emit into a closed stream', () async {
    final service = ReminderService();
    final now = DateTime.utc(2026, 6, 14, 12);
    final reminder = Reminder(
      id: 'reminder-1',
      title: 'Spanish conjugation practice',
      alertAtUtc: now.add(const Duration(hours: 1)),
      eventId: 'event-1',
      flowId: 'flow-714',
      createdAt: now,
      updatedAt: now,
    );

    service.dispose();

    await expectLater(service.addOrUpdate(reminder), completes);
    await expectLater(
      service.markStatus('reminder-1', ReminderStatus.completed),
      completes,
    );
    await expectLater(service.load(), completes);
  });
}
