Future<String> browserNotificationPermissionStatus() async {
  return 'unsupported';
}

Future<String> requestBrowserNotificationPermission() async {
  return 'denied';
}

Future<String?> getExistingBrowserPushSubscriptionJson() async {
  return null;
}

Future<String?> subscribeBrowserPush(String publicKey) async {
  return null;
}

Future<void> unsubscribeBrowserPush() async {}
