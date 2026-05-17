import 'package:flutter/widgets.dart';

const double kGlobalBottomMenuBaseHeight = 50;
const double kGlobalBottomMenuLandscapeBaseHeight = 25;

double globalBottomMenuBaseHeight(BuildContext context) {
  return MediaQuery.orientationOf(context) == Orientation.landscape
      ? kGlobalBottomMenuLandscapeBaseHeight
      : kGlobalBottomMenuBaseHeight;
}

double globalBottomMenuHeight(BuildContext context) {
  return globalBottomMenuBaseHeight(context) +
      MediaQuery.paddingOf(context).bottom;
}

double bottomPaddingAboveGlobalMenu(BuildContext context, double basePadding) {
  return basePadding + globalBottomMenuHeight(context);
}
