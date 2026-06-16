import 'package:flutter/material.dart';
import 'package:mobile/core/touch_targets.dart';
import 'package:mobile/shared/glossy_text.dart';
import 'package:mobile/widgets/kemetic_app_bar_action.dart';
import 'package:mobile/widgets/kemetic_date_picker.dart' show KemeticMath;
import 'package:mobile/widgets/month_name_text.dart';

const Color _dayViewGold = KemeticGold.base;
const Gradient _dayViewGoldGloss = KemeticGold.gloss;
const Color _dayViewDateBronze = Color(0xFF89743A);
const Color _dayViewGregorianBlue = Color(0xFF67B0EF);
const TextStyle _dayViewMonthStyle = TextStyle(
  fontSize: 19,
  fontWeight: FontWeight.w500,
  fontFamily: 'CormorantGaramond',
  fontFamilyFallback: ['GentiumPlus', 'NotoSerif', 'Georgia', 'serif'],
);
const TextStyle _dayViewMiniCalendarNumberStyle = TextStyle(
  fontSize: 15,
  fontWeight: FontWeight.w500,
  fontFamily: 'CormorantGaramond',
  fontFamilyFallback: ['GentiumPlus', 'NotoSerif', 'Georgia', 'serif'],
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
    this.onMiniCalendarManualScrollStart,
    this.onToggleDateDisplay,
    this.onClose,
    this.onJumpToToday,
    this.onOpenQuickAdd,
    this.onOpenSearch,
    this.onOpenProfile,
    this.onOpenMenu,
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
  final VoidCallback? onMiniCalendarManualScrollStart;
  final VoidCallback? onToggleDateDisplay;
  final VoidCallback? onClose;
  final VoidCallback? onJumpToToday;
  final Future<void> Function(BuildContext context)? onOpenQuickAdd;
  final Future<void> Function(BuildContext context)? onOpenSearch;
  final Future<void> Function(BuildContext context)? onOpenProfile;
  final Future<void> Function(BuildContext context)? onOpenMenu;

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
    final closeButtonConstraints = BoxConstraints.tightFor(
      width: 42,
      height: headerHeight,
    );
    final actionButtonConstraints = BoxConstraints.tightFor(
      width: 36,
      height: headerHeight,
    );

    return Container(
      color: const Color(0xFF060504),
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
                    tooltip: 'Close',
                    icon: KemeticGold.icon(Icons.close),
                    constraints: closeButtonConstraints,
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
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
                        constraints: actionButtonConstraints,
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        onPressed: () async {
                          await onOpenQuickAdd!(btnCtx);
                        },
                      ),
                    ),
                  if (onOpenSearch != null)
                    IconButton(
                      tooltip: 'Search notes',
                      icon: const KemeticAppBarSearchIcon(),
                      constraints: actionButtonConstraints,
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      onPressed: () async {
                        await onOpenSearch!(context);
                      },
                    ),
                  IconButton(
                    tooltip: 'Today',
                    icon: const KemeticAppBarTodayIcon(),
                    constraints: actionButtonConstraints,
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    onPressed: onJumpToToday ?? () {},
                  ),
                  IconButton(
                    tooltip: 'My Profile',
                    icon: const KemeticAppBarProfileIcon(),
                    constraints: actionButtonConstraints,
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    onPressed: () async {
                      if (onOpenProfile != null) {
                        await onOpenProfile!(context);
                      }
                    },
                  ),
                  if (onOpenMenu != null)
                    IconButton(
                      tooltip: 'Menu',
                      icon: KemeticGold.icon(Icons.more_vert, size: 25),
                      constraints: actionButtonConstraints,
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      onPressed: () async {
                        await onOpenMenu!(context);
                      },
                    ),
                ],
              ),
            ),
            SizedBox(
              height: miniCalendarHeight,
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is ScrollStartNotification &&
                      notification.dragDetails != null) {
                    onMiniCalendarManualScrollStart?.call();
                  }
                  return false;
                },
                child: ListView.builder(
                  key: const ValueKey('day_view_mini_calendar'),
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
                    final displayLabel = showGregorian
                        ? '${KemeticMath.toGregorian(currentKy, currentKm, day).day}'
                        : '$day';

                    return GestureDetector(
                      key: ValueKey('day_view_mini_chip_$day'),
                      behavior: HitTestBehavior.opaque,
                      onTap: onSelectDay == null
                          ? null
                          : () => onSelectDay!(day),
                      child: Container(
                        width: miniCalendarDaySize,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        alignment: Alignment.center,
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: isCurrentDay
                                ? Border.all(color: _dayViewGold, width: 1.9)
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              displayLabel,
                              style: _dayViewMiniCalendarNumberStyle.copyWith(
                                color: isToday
                                    ? _dayViewGold
                                    : (isCurrentDay
                                          ? (showGregorian
                                                ? _dayViewGregorianBlue
                                                : _dayViewGold)
                                          : (showGregorian
                                                ? _dayViewGregorianBlue
                                                      .withValues(alpha: 0.76)
                                                : _dayViewDateBronze.withValues(
                                                    alpha: 0.88,
                                                  ))),
                                fontWeight: isCurrentDay || isToday
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.only(bottom: 12),
              alignment: Alignment.center,
              child: dateButtonBuilder(context, currentGregorian),
            ),
            const Divider(height: 1, color: Color(0x3321190D)),
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
          (showGregorian ? blueGloss : _dayViewGoldGloss).createShader(bounds),
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
