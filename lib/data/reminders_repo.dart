import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/reminders/reminder_model.dart';

class RemindersRepo {
  final SupabaseClient _client;
  RemindersRepo(this._client);

  Future<List<Reminder>> getDueReminders(DateTime nowUtc) async {
    final resp = await _client.rpc(
      'get_due_reminders',
      params: {'now_utc': nowUtc.toIso8601String()},
    );
    if (resp is List) {
      return resp
          .map((e) => Reminder.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return const [];
  }

  Future<void> markStatus(String reminderId, ReminderStatus status) async {
    await _client.rpc(
      'mark_reminder_status',
      params: {'reminder_id': reminderId, 'new_status': status.name},
    );
  }
}
