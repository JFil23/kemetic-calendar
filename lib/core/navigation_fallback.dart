import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

void popOrGo(BuildContext context, String fallbackLocation, {Object? result}) {
  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.pop(result);
    return;
  }
  context.go(fallbackLocation);
}
