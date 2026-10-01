// Browser/device probe: production housing and populated static Reading House.
// No account access or writes. Run with flutter run -d web-server -t this file.
import 'package:flutter/material.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/calendar/landscape_month_view.dart';
import 'package:mobile/features/calendar/presentation/instrument_event_presentation_frame.dart';
import 'package:mobile/features/calendar/the_reading_house/presentation/reading_house_day_presentation.dart';
import 'package:mobile/widgets/kemetic_keyboard.dart';

void main() => runApp(
  MaterialApp(
    theme: AppTheme.dark,
    builder: (_, child) => KemeticKeyboardHost(child: child!),
    home: const LandscapeKeyboardProbe(),
  ),
);

class LandscapeKeyboardProbe extends StatelessWidget {
  const LandscapeKeyboardProbe({super.key});

  void _open(BuildContext context) {
    BuildContext? pane;
    void visit(Element element) {
      if (element.widget.key == const ValueKey('landscape-calendar-pane')) {
        pane = element;
      } else {
        element.visitChildElements(visit);
      }
    }

    context.visitChildElements(visit);
    showCalendarEventDetailSheetModal<void>(
      context: pane ?? context,
      builder: (_) => MaatDayViewSheetHost(
        flow: MaatDayViewFlow.readingHouse,
        leading: const Text('Add reflection'),
        trailing: const Icon(Icons.more_vert),
        body: ReadingHouseDayPresentation(onSendMessage: (_) {}),
        footer: MaatDayViewFooterActions(
          onMakeTodo: () {},
          calendarLabel: 'Calendar',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    resizeToAvoidBottomInset: false,
    body: Stack(
      children: [
        LandscapeMonthView(
          initialKy: 2,
          initialKm: 7,
          initialKd: 16,
          showGregorian: true,
          notesForDay: (_, _, _) => const [],
          flowIndex: const {},
          getMonthName: (_) => 'Rekh-Nedjes',
          clock: () => DateTime(2026, 10, 1, 10, 30),
        ),
        Positioned(
          left: 52,
          top: 50,
          child: TextButton(
            onPressed: () => _open(context),
            child: const Text('Open Reading House'),
          ),
        ),
      ],
    ),
  );
}
