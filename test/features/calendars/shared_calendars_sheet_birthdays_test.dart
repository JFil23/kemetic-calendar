import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/birthday_calendar.dart';
import 'package:mobile/data/event_filing_engine.dart';
import 'package:mobile/data/shared_calendar_models.dart';
import 'package:mobile/data/shared_calendars_repo.dart';
import 'package:mobile/features/calendars/shared_calendars_sheet.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('Birthdays row has its own add button and validating form', (
    tester,
  ) async {
    final repo = _FakeSharedCalendarsRepo();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SharedCalendarsSheet(
            repo: repo,
            routeMode: true,
            showCloseButton: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Birthdays'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('birthdays-calendar-add-button')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('birthdays-calendar-add-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Add Birthday'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('birthday-name-field')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('birthday-alert-picker')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('birthday-save-button')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Name is required.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey<String>('birthday-name-field')),
      'Amina',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('birthday-save-button')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Birthday date is required.'), findsOneWidget);
    expect(repo.createdBirthdays, isEmpty);
  });
}

class _FakeSharedCalendarsRepo extends SharedCalendarsRepo {
  _FakeSharedCalendarsRepo()
    : super(
        SupabaseClient(
          'http://localhost',
          'anon-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  final List<({String name, DateTime birthday, int alertOffsetMinutes})>
  createdBirthdays = [];

  @override
  Future<SharedCalendarsSnapshot> loadSnapshot() async {
    return SharedCalendarsSnapshot(
      calendars: [_birthdaysCalendar],
      pendingInvites: const <SharedCalendarInvite>[],
      hiddenCalendarIds: const <String>{},
    );
  }

  @override
  Future<SharedCalendarsSnapshot?> restoreCachedSnapshot() async => null;

  @override
  Future<List<FiledEvent>> getCalendarFiledEvents(
    String calendarId, {
    int pageSize = 1000,
    int? maxRows,
    DateTime? startsOnOrAfterUtc,
  }) async {
    return const <FiledEvent>[];
  }

  @override
  Future<void> setCalendarVisible(String calendarId, bool visible) async {}

  @override
  Future<String> createBirthday({
    required String name,
    required DateTime birthday,
    required int alertOffsetMinutes,
  }) async {
    createdBirthdays.add((
      name: name,
      birthday: birthday,
      alertOffsetMinutes: alertOffsetMinutes,
    ));
    return 'birthday-1';
  }
}

const _birthdaysCalendar = SharedCalendarSummary(
  id: 'calendar-birthdays',
  ownerId: 'user-1',
  name: 'Birthdays',
  colorValue: kBirthdaysCalendarColorValue,
  icon: 'birthdays',
  isPersonal: false,
  role: SharedCalendarRole.owner,
  status: SharedCalendarInviteStatus.accepted,
  memberCount: 1,
  pendingInviteCount: 0,
  systemType: kBirthdaysSystemType,
);
