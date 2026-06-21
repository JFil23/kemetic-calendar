import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/birthday_calendar.dart';
import 'package:mobile/data/event_filing_engine.dart';
import 'package:mobile/data/shared_calendar_models.dart';
import 'package:mobile/data/shared_calendars_repo.dart';
import 'package:mobile/features/calendars/shared_calendars_sheet.dart';
import 'package:mobile/shared/date_picker/stone_register_date_picker.dart';
import 'package:mobile/widgets/gregorian_date_picker.dart';
import 'package:intl/intl.dart';
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

  testWidgets('Birthday picker Cancel preserves empty value on small phone', (
    tester,
  ) async {
    _useSmallPhoneSurface(tester);
    final repo = _FakeSharedCalendarsRepo();

    await _pumpBirthdaysSheet(tester, repo);
    await _openBirthdayDialog(tester);

    await tester.enterText(
      find.byKey(const ValueKey<String>('birthday-name-field')),
      'Amina',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('birthday-date-picker')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pick birthday'), findsOneWidget);
    expect(find.text('Gregorian Calendar'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Choose date'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey<String>('birthday-save-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Birthday date is required.'), findsOneWidget);
    expect(repo.createdBirthdays, isEmpty);
  });

  testWidgets(
    'Birthday picker Done saves date-only value and reopens cleanly',
    (tester) async {
      _useSmallPhoneSurface(tester);
      final repo = _FakeSharedCalendarsRepo();
      final now = DateTime.now();
      final expectedBirthday = DateUtils.dateOnly(
        DateTime(now.year - 18, now.month, now.day),
      );
      final expectedLabel = DateFormat.yMMMMd().format(expectedBirthday);

      await _pumpBirthdaysSheet(tester, repo);
      await _openBirthdayDialog(tester);

      await tester.enterText(
        find.byKey(const ValueKey<String>('birthday-name-field')),
        'Amina',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('birthday-date-picker')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Done'));
      await tester.pumpAndSettle();

      expect(find.text(expectedLabel), findsOneWidget);

      await tester.tap(find.text(expectedLabel));
      await tester.pumpAndSettle();
      expect(find.text('Pick birthday'), findsOneWidget);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Done'));
      await tester.pumpAndSettle();

      expect(find.text(expectedLabel), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('birthday-save-button')),
      );
      await tester.pumpAndSettle();

      expect(repo.createdBirthdays, hasLength(1));
      expect(repo.createdBirthdays.single.name, 'Amina');
      expect(repo.createdBirthdays.single.birthday, expectedBirthday);
      expect(
        repo.createdBirthdays.single.alertOffsetMinutes,
        kBirthdayNoAlertMinutes,
      );
    },
  );

  test('bounded birthday Gregorian adapter preserves Feb. 29', () {
    const adapter = GregorianDatePickerAdapter(yearStart: 2024, yearCount: 2);

    final feb29 = adapter.valueFromSelection(
      const StoneWheelSelection({'month': 1, 'day': 28, 'year': 0}),
      StoneDatePickerCalendarMode.gregorian,
    );

    expect(feb29, DateTime(2024, 2, 29));
    expect(
      adapter
          .buildColumns(feb29, StoneDatePickerCalendarMode.gregorian)
          .singleWhere((column) => column.id == 'day')
          .values,
      hasLength(29),
    );
  });
}

Future<void> _pumpBirthdaysSheet(
  WidgetTester tester,
  _FakeSharedCalendarsRepo repo,
) async {
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
}

Future<void> _openBirthdayDialog(WidgetTester tester) async {
  await tester.tap(
    find.byKey(const ValueKey<String>('birthdays-calendar-add-button')),
  );
  await tester.pumpAndSettle();
  expect(find.text('Add Birthday'), findsOneWidget);
}

void _useSmallPhoneSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
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
