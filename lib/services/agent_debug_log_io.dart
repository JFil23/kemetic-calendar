import 'dart:io';

// #region agent log
void agentPlatformIngest(String jsonBody) {
  try {
    File(
      '/Users/jaralephillips/dev/kemetic-calendar/.cursor/debug-bdbad5.log',
    ).writeAsStringSync('$jsonBody\n', mode: FileMode.append);
  } catch (_) {}
}
// #endregion
