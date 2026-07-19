import 'package:flutter/foundation.dart';

const String nativeAuthRedirectUrl = 'kemet.app://login-callback';

String authRedirectTo() {
  if (kIsWeb) {
    return Uri.base
        .removeFragment()
        .replace(queryParameters: const {})
        .toString();
  }
  return nativeAuthRedirectUrl;
}
