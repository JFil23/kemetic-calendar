import 'package:flutter/material.dart';

import '../shared/glossy_text.dart';

const Key calendarFloatingShortcutsKey = ValueKey<String>(
  'calendar-floating-shortcuts',
);
const Key calendarFloatingShortcutsSurfaceKey = ValueKey<String>(
  'calendar-floating-shortcuts-surface',
);
final GlobalKey calendarFloatingTodayButtonKey = GlobalKey(
  debugLabel: 'calendar-floating-today-button',
);
const Key calendarFloatingTodaySurfaceKey = ValueKey<String>(
  'calendar-floating-today-surface',
);
const Key calendarFloatingCalendarsButtonKey = ValueKey<String>(
  'calendar-floating-calendars-button',
);
const Key calendarFloatingInboxButtonKey = ValueKey<String>(
  'calendar-floating-inbox-button',
);

// Measured from the Apple Calendar phone reference: a compact 140 x 48 pt
// shared capsule, inset 28 pt from the trailing and bottom screen edges.
const double kCalendarFloatingShortcutsWidth = 140;
const double kCalendarFloatingShortcutsHeight = 48;
const double kCalendarFloatingTodayWidth = 80;
const double kCalendarFloatingShortcutsTrailing = 28;
const double kCalendarFloatingShortcutsLeading = 28;
const double kCalendarFloatingShortcutsBottom = 28;

class CalendarFloatingShortcutsLayer extends StatelessWidget {
  const CalendarFloatingShortcutsLayer({
    super.key,
    required this.child,
    required this.onTodayPressed,
    required this.onCalendarsPressed,
    required this.onInboxPressed,
    this.unreadInboxCount = 0,
  });

  final Widget child;
  final VoidCallback onTodayPressed;
  final VoidCallback onCalendarsPressed;
  final VoidCallback onInboxPressed;
  final int unreadInboxCount;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboardVisible = media.viewInsets.bottom > 0;

    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        if (!keyboardVisible)
          Positioned(
            left: media.padding.left + kCalendarFloatingShortcutsLeading,
            bottom: media.padding.bottom + kCalendarFloatingShortcutsBottom,
            child: CalendarFloatingTodayButton(
              key: calendarFloatingTodayButtonKey,
              onPressed: onTodayPressed,
            ),
          ),
        if (!keyboardVisible)
          Positioned(
            right: media.padding.right + kCalendarFloatingShortcutsTrailing,
            bottom: media.padding.bottom + kCalendarFloatingShortcutsBottom,
            child: CalendarFloatingShortcuts(
              onCalendarsPressed: onCalendarsPressed,
              onInboxPressed: onInboxPressed,
              unreadInboxCount: unreadInboxCount,
            ),
          ),
      ],
    );
  }
}

class CalendarFloatingTodayButton extends StatelessWidget {
  const CalendarFloatingTodayButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: kCalendarFloatingTodayWidth,
      height: kCalendarFloatingShortcutsHeight,
      child: _CalendarFloatingCapsule(
        surfaceKey: calendarFloatingTodaySurfaceKey,
        child: Semantics(
          button: true,
          label: 'Today',
          onTap: onPressed,
          child: ExcludeSemantics(
            child: InkWell(
              onTap: onPressed,
              child: const Center(
                child: Text(
                  'Today',
                  style: TextStyle(
                    color: Color(0xFFF7F7F7),
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    height: 1,
                    letterSpacing: -0.25,
                    fontFamily: 'Roboto',
                    fontFamilyFallback: <String>['Arial', 'sans-serif'],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CalendarFloatingShortcuts extends StatelessWidget {
  const CalendarFloatingShortcuts({
    super.key = calendarFloatingShortcutsKey,
    required this.onCalendarsPressed,
    required this.onInboxPressed,
    this.unreadInboxCount = 0,
  });

  final VoidCallback onCalendarsPressed;
  final VoidCallback onInboxPressed;
  final int unreadInboxCount;

  @override
  Widget build(BuildContext context) {
    final normalizedUnreadCount = unreadInboxCount.clamp(0, 999);

    return SizedBox(
      width: kCalendarFloatingShortcutsWidth,
      height: kCalendarFloatingShortcutsHeight,
      child: _CalendarFloatingCapsule(
        surfaceKey: calendarFloatingShortcutsSurfaceKey,
        child: Row(
          children: [
            Expanded(
              child: _CalendarFloatingShortcutButton(
                key: calendarFloatingCalendarsButtonKey,
                semanticLabel: 'Calendars',
                onPressed: onCalendarsPressed,
                child: KemeticGold.glyph(MeduNeterGlyphs.calendars, size: 24),
              ),
            ),
            Expanded(
              child: _CalendarFloatingShortcutButton(
                key: calendarFloatingInboxButtonKey,
                semanticLabel: normalizedUnreadCount > 0
                    ? 'Inbox, $normalizedUnreadCount unread'
                    : 'Inbox',
                onPressed: onInboxPressed,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    KemeticGold.glyph(MeduNeterGlyphs.inbox, size: 23),
                    if (normalizedUnreadCount > 0) ...[
                      const SizedBox(width: 6),
                      Text(
                        normalizedUnreadCount > 99
                            ? '99+'
                            : '$normalizedUnreadCount',
                        style: const TextStyle(
                          color: Color(0xFFF7F7F7),
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          height: 1,
                          letterSpacing: -0.35,
                          fontFamily: 'Roboto',
                          fontFamilyFallback: <String>['Arial', 'sans-serif'],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarFloatingCapsule extends StatelessWidget {
  const _CalendarFloatingCapsule({
    required this.surfaceKey,
    required this.child,
  });

  final Key surfaceKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(
      kCalendarFloatingShortcutsHeight / 2,
    );
    return DecoratedBox(
      key: surfaceKey,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xF52B2B2E), Color(0xF51B1B1D)],
        ),
        borderRadius: borderRadius,
        border: Border.all(color: const Color(0x3DFFFFFF), width: 0.75),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x80000000),
            blurRadius: 24,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Material(color: Colors.transparent, child: child),
      ),
    );
  }
}

class _CalendarFloatingShortcutButton extends StatelessWidget {
  const _CalendarFloatingShortcutButton({
    super.key,
    required this.semanticLabel,
    required this.onPressed,
    required this.child,
  });

  final String semanticLabel;
  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      onTap: onPressed,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onPressed,
          child: Center(child: child),
        ),
      ),
    );
  }
}
