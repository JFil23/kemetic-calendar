// lib/utils/web_history.dart
/// No-op on non-web platforms.
void replaceUrlWithoutQuery() {}
void onVisibilityChange(void Function() cb) {}
void nudgeStandaloneWebView() {}
void onPushNotificationTap(void Function(Map<String, dynamic>) cb) {}

/// Recovery requires a new process on native platforms.
void reloadPageForBootRecovery() {}
