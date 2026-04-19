import 'package:flutter/material.dart';
import 'package:mobile/core/touch_targets.dart';
import 'package:mobile/shared/glossy_text.dart';
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
    required this.getMonthName,
    required this.dateButtonBuilder,
    this.miniCalendarScrollController,
    this.onSelectDay,
    this.onClose,
    this.onJumpToToday,
    this.onShowActionsMenu,
    this.onOpenProfile,
  });

  final int currentKy;
  final int currentKm;
  final int currentKd;
  final String Function(int km) getMonthName;
  final Widget Function(String monthName, int currentKd, int gregorianYear)
  dateButtonBuilder;
  final ScrollController? miniCalendarScrollController;
  final ValueChanged<int>? onSelectDay;
  final VoidCallback? onClose;
  final VoidCallback? onJumpToToday;
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
    final monthName = getMonthName(currentKm);
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
    final gregorianYear = currentGregorian.year;

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
                  Expanded(child: _DayViewMonthLabel(monthName: monthName)),
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
                      icon: const GlossyIcon(
                        icon: Icons.apps,
                        gradient: goldGloss,
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
              child: dateButtonBuilder(monthName, currentKd, gregorianYear),
            ),
            const Divider(height: 1, color: Color(0xFF1A1A1A)),
          ],
        ),
      ),
    );
  }
}

class _DayViewMonthLabel extends StatelessWidget {
  const _DayViewMonthLabel({required this.monthName});

  final String monthName;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (Rect bounds) => _dayViewGoldGloss.createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: MonthNameText(
        monthName,
        style: _dayViewMonthStyle,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.fade,
      ),
    );
  }
}
