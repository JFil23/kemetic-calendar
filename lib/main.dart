import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/local_events_repo.dart';
import 'features/calendar/calendar_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KemeticApp());
}

class KemeticApp extends StatelessWidget {
  const KemeticApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LocalEventsRepo(),
      child: MaterialApp(
        title: 'Kemetic Calendar',
        theme: ThemeData(useMaterial3: true),
        home: const CalendarPage(), // 👈 this loads your grid calendar
      ),
    );
  }
}
