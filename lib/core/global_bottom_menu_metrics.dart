import 'package:flutter/widgets.dart';

const double kGlobalBottomMenuBaseHeight = 50;

double globalBottomMenuHeight(BuildContext context) {
  return kGlobalBottomMenuBaseHeight + MediaQuery.paddingOf(context).bottom;
}

double bottomPaddingAboveGlobalMenu(BuildContext context, double basePadding) {
  return basePadding + globalBottomMenuHeight(context);
}
