import 'package:flutter/material.dart';
import 'package:mobile/core/touch_targets.dart';
import 'package:mobile/shared/glossy_text.dart';
import 'package:mobile/widgets/inbox_icon_with_badge.dart';
import 'package:mobile/widgets/kemetic_date_picker.dart' show KemeticMath;
import 'package:mobile/widgets/month_name_text.dart';

const Color _dayViewGold = KemeticGold.base;
const Gradient _dayViewGoldGloss = KemeticGold.gloss;
const TextStyle _dayViewMonthStyle = TextStyle(
  fontSize: 18,
  fontWeight: FontWeight.w500,
  fontFamily: 'GentiumPlus',
  fontFamilyFallback: ['NotoSans', 'Roboto', 'Arial', 'sans-serif'],
);
const TextStyle _dayViewMiniCalendarNumberStyle = TextStyle(
  fontSize: 14,
  fontFamily: 'GentiumPlus',
  fontFamilyFallback: ['NotoSans', 'Roboto', 'Arial', 'sans-serif'],
);

class KemeticDayViewHeader extends StatelessWidget {
  const KemeticDayViewHeader({
    super.key,
    required this.currentKy,
    required this.currentKm,
    required this.currentKd,
    required this.showGregorian,
    required this.getMonthName,
    required this.dateButtonBuilder,
    this.miniCalendarScrollController,
    this.onSelectDay,
    this.onToggleDateDisplay,
    this.onClose,
    this.onJumpToToday,
    this.onOpenQuickAdd,
    this.onShowActionsMenu,
    this.onOpenProfile,
  });

  final int currentKy;
  final int currentKm;
  final int currentKd;
  final bool showGregorian;
  final String Function(int km) getMonthName;
  final Widget Function(BuildContext context, DateTime currentGregorian)
  dateButtonBuilder;
  final ScrollController? miniCalendarScrollController;
  final ValueChanged<int>? onSelectDay;
  final VoidCallback? onToggleDateDisplay;
  final VoidCallback? onClose;
  final VoidCallback? onJumpToToday;
  final Future<void> Function(BuildContext context)? onOpenQuickAdd;
  final Future<void> Function(BuildContext context)? onShowActionsMenu;
  final Future<void> Function(BuildContext context)? onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final headerHeight = expandedTouchTargetMinDimension(context, fallback: 44);
    final miniCalendarHeight = expandedTouchTargetMinDimension(
      context,
      fallback: 32,
    );
    final miniCalendarDaySize = expandedTouchTargetMinDimension(
      context,
      fallback: 30,
      minSize: 44,
    );
    final kemeticMonthName = getMonthName(currentKm);
    final dayCount = currentKm == 13
        ? (KemeticMath.isLeapKemeticYear(currentKy) ? 6 : 5)
        : 30;

    final now = DateTime.now();
    final today = KemeticMath.fromGregorian(now);
    final currentGregorian = KemeticMath.toGregorian(
      currentKy,
      currentKm,
      currentKd,
    );
    final monthName = showGregorian
        ? _gregorianMonthNames[currentGregorian.month - 1]
        : kemeticMonthName;

    return Container(
      color: const Color(0xFF0D0D0F),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              height: headerHeight,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: KemeticGold.icon(Icons.close),
                    onPressed: onClose ?? () {},
                  ),
                  Expanded(
                    child: _DayViewMonthLabel(
                      monthName: monthName,
                      showGregorian: showGregorian,
                      onTap: onToggleDateDisplay,
                    ),
                  ),
                  if (onOpenQuickAdd != null)
                    Builder(
                      builder: (btnCtx) => IconButton(
                        tooltip: 'New note',
                        icon: const GlossyIcon(
                          icon: Icons.add,
                          gradient: goldGloss,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        onPressed: () async {
                          await onOpenQuickAdd!(btnCtx);
                        },
                      ),
                    ),
                  IconButton(
                    tooltip: 'Today',
                    icon: const GlossyIcon(
                      icon: Icons.today,
                      gradient: goldGloss,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    onPressed: onJumpToToday ?? () {},
                  ),
                  Builder(
                    builder: (btnCtx) => IconButton(
                      tooltip: 'Menu',
                      icon: const InboxUnreadDotOverlay(
                        child: GlossyIcon(
                          icon: Icons.apps,
                          gradient: goldGloss,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      onPressed: () async {
                        if (onShowActionsMenu != null) {
                          await onShowActionsMenu!(btnCtx);
                        }
                      },
                    ),
                  ),
                  IconButton(
                    tooltip: 'My Profile',
                    icon: const GlossyIcon(
                      icon: Icons.person,
                      gradient: goldGloss,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    onPressed: () async {
                      if (onOpenProfile != null) {
                        await onOpenProfile!(context);
                      }
                    },
                  ),
                ],
              ),
            ),
            SizedBox(
              height: miniCalendarHeight,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: dayCount,
                controller: miniCalendarScrollController,
                itemBuilder: (context, index) {
                  final day = index + 1;
                  final isCurrentDay = day == currentKd;
                  final isToday =
                      today.kYear == currentKy &&
                      today.kMonth == currentKm &&
                      today.kDay == day;

                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onSelectDay == null ? null : () => onSelectDay!(day),
                    child: Container(
                      width: miniCalendarDaySize,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      alignment: Alignment.center,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: isCurrentDay
                              ? Border.all(color: _dayViewGold, width: 1.5)
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            '$day',
                            style: _dayViewMiniCalendarNumberStyle.copyWith(
                              color: isToday
                                  ? _dayViewGold
                                  : (isCurrentDay
                                        ? const Color(0xFFAAAAAA)
                                        : Colors.white54),
                              fontWeight: isCurrentDay || isToday
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.only(bottom: 12),
              alignment: Alignment.center,
              child: dateButtonBuilder(context, currentGregorian),
            ),
            const Divider(height: 1, color: Color(0xFF1A1A1A)),
          ],
        ),
      ),
    );
  }
}

const List<String> _gregorianMonthNames = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

class _DayViewMonthLabel extends StatelessWidget {
  const _DayViewMonthLabel({
    required this.monthName,
    required this.showGregorian,
    this.onTap,
  });

  final String monthName;
  final bool showGregorian;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final label = ShaderMask(
      shaderCallback: (Rect bounds) =>
          (showGregorian ? whiteGloss : _dayViewGoldGloss).createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: MonthNameText(
        monthName,
        style: _dayViewMonthStyle,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.fade,
      ),
    );

    if (onTap == null) return label;

    return Semantics(
      button: true,
      label: showGregorian ? 'Show Kemetic dates' : 'Show Gregorian dates',
      child: GestureDetector(
        key: const ValueKey('day_view_month_toggle'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: label,
        ),
      ),
    );
  }
}
