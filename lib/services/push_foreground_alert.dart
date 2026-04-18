import '../features/calendar/notify.dart';

Future<void> showForegroundPushAlert({
  required String title,
  String? body,
}) async {
  await Notify.showInstant(title: title, body: body);
}
