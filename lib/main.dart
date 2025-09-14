import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/local_events_repo.dart';
import 'features/calendar/calendar_page.dart';

void main() {
  runApp(const _App());
}

class _App extends StatelessWidget {
  const _App({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LocalEventsRepo()..init(),
      child: MaterialApp(
        title: 'Kemetic Calendar',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5B47E0)),
          useMaterial3: true,
        ),
        home: const CalendarPage(),
      ),
    );
  }
}
