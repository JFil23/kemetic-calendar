import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/utils/flow_visibility.dart';

void main() {
  test(
    'ledger marks a placed flow inactive when no remaining events exist',
    () {
      final ledger = buildFlowLedger<_FakeFlow>(
        flows: [
          const _FakeFlow(
            id: 1,
            active: true,
            isSaved: false,
            isHidden: false,
            isReminder: false,
          ),
        ],
        idOf: (flow) => flow.id,
        activeOf: (flow) => flow.active,
        isSavedOf: (flow) => flow.isSaved,
        isHiddenOf: (flow) => flow.isHidden,
        isReminderOf: (flow) => flow.isReminder,
        endDateOf: (flow) => flow.endDate,
        notesOf: (flow) => flow.notes,
        useRemainingEventCount: true,
        remainingEventCounts: const {1: 0},
      );

      expect(ledger.activeCount, 0);
      expect(ledger.activeItems, isEmpty);
    },
  );

  test('ledger counts remaining events only for active flows', () {
    final ledger = buildFlowLedger<_FakeFlow>(
      flows: [
        const _FakeFlow(
          id: 1,
          active: true,
          isSaved: false,
          isHidden: false,
          isReminder: false,
        ),
        const _FakeFlow(
          id: 2,
          active: false,
          isSaved: true,
          isHidden: false,
          isReminder: false,
        ),
      ],
      idOf: (flow) => flow.id,
      activeOf: (flow) => flow.active,
      isSavedOf: (flow) => flow.isSaved,
      isHiddenOf: (flow) => flow.isHidden,
      isReminderOf: (flow) => flow.isReminder,
      endDateOf: (flow) => flow.endDate,
      notesOf: (flow) => flow.notes,
      useRemainingEventCount: true,
      remainingEventCounts: const {1: 3, 2: 8},
    );

    expect(ledger.activeCount, 1);
    expect(ledger.totalRemainingEventCount, 3);
    expect(ledger.savedTemplateItems.length, 1);
  });

  test('ledger marks an ended flow inactive even with remaining events', () {
    final ledger = buildFlowLedger<_FakeFlow>(
      flows: [
        _FakeFlow(
          id: 1,
          active: true,
          isSaved: false,
          isHidden: false,
          isReminder: false,
          endDate: DateTime(2025, 12, 1),
        ),
      ],
      idOf: (flow) => flow.id,
      activeOf: (flow) => flow.active,
      isSavedOf: (flow) => flow.isSaved,
      isHiddenOf: (flow) => flow.isHidden,
      isReminderOf: (flow) => flow.isReminder,
      endDateOf: (flow) => flow.endDate,
      notesOf: (flow) => flow.notes,
      useRemainingEventCount: true,
      remainingEventCounts: const {1: 2},
      now: DateTime(2026, 4, 30, 12),
    );

    expect(ledger.activeCount, 0);
    expect(ledger.activeItems, isEmpty);
  });

  test('ledger keeps ended saved flows in saved templates', () {
    final ledger = buildFlowLedger<_FakeFlow>(
      flows: [
        _FakeFlow(
          id: 1,
          active: true,
          isSaved: true,
          isHidden: false,
          isReminder: false,
          endDate: DateTime(2025, 12, 1),
        ),
      ],
      idOf: (flow) => flow.id,
      activeOf: (flow) => flow.active,
      isSavedOf: (flow) => flow.isSaved,
      isHiddenOf: (flow) => flow.isHidden,
      isReminderOf: (flow) => flow.isReminder,
      endDateOf: (flow) => flow.endDate,
      notesOf: (flow) => flow.notes,
      useRemainingEventCount: true,
      remainingEventCounts: const {1: 2},
      now: DateTime(2026, 4, 30, 12),
    );

    expect(ledger.activeCount, 0);
    expect(ledger.savedTemplateItems.length, 1);
  });

  test('ledger keeps active saved flows in both active and saved lists', () {
    final ledger = buildFlowLedger<_FakeFlow>(
      flows: [
        const _FakeFlow(
          id: 1,
          active: true,
          isSaved: true,
          isHidden: false,
          isReminder: false,
        ),
      ],
      idOf: (flow) => flow.id,
      activeOf: (flow) => flow.active,
      isSavedOf: (flow) => flow.isSaved,
      isHiddenOf: (flow) => flow.isHidden,
      isReminderOf: (flow) => flow.isReminder,
      endDateOf: (flow) => flow.endDate,
      notesOf: (flow) => flow.notes,
      useRemainingEventCount: true,
      remainingEventCounts: const {1: 2},
      now: DateTime(2026, 4, 30, 12),
    );

    expect(ledger.activeCount, 1);
    expect(ledger.activeItems.length, 1);
    expect(ledger.savedTemplateItems.length, 1);
  });

  test('ledger files active saved flows with no events as saved templates', () {
    final ledger = buildFlowLedger<_FakeFlow>(
      flows: [
        const _FakeFlow(
          id: 1,
          active: true,
          isSaved: true,
          isHidden: false,
          isReminder: false,
        ),
      ],
      idOf: (flow) => flow.id,
      activeOf: (flow) => flow.active,
      isSavedOf: (flow) => flow.isSaved,
      isHiddenOf: (flow) => flow.isHidden,
      isReminderOf: (flow) => flow.isReminder,
      endDateOf: (flow) => flow.endDate,
      notesOf: (flow) => flow.notes,
      useRemainingEventCount: true,
      remainingEventCounts: const {1: 0},
      now: DateTime(2026, 4, 30, 12),
    );

    expect(ledger.activeItems, isEmpty);
    expect(ledger.savedTemplateItems, hasLength(1));
  });

  test('calendar-active flow excludes reminders and hidden rows', () {
    expect(
      isCalendarActiveFlow(active: true, isHidden: false, isReminder: false),
      isTrue,
    );
    expect(
      isCalendarActiveFlow(active: true, isHidden: false, isReminder: true),
      isFalse,
    );
    expect(
      isCalendarActiveFlow(active: true, isHidden: true, isReminder: false),
      isFalse,
    );
    expect(
      isCalendarActiveFlow(active: false, isHidden: false, isReminder: false),
      isFalse,
    );
  });

  test('calendar-active flow excludes repeating-note helper rows', () {
    expect(
      isCalendarActiveFlow(
        active: true,
        isHidden: false,
        isReminder: false,
        notes: '{"kind":"repeating_note","detail":"Water plants"}',
      ),
      isFalse,
    );
  });

  test('soft-deleted flow is hidden and inactive', () {
    expect(isSoftDeletedFlow(active: false, isHidden: true), isTrue);
    expect(isSoftDeletedFlow(active: true, isHidden: true), isTrue);
    expect(isSoftDeletedFlow(active: false, isHidden: false), isFalse);
  });

  test('saved flow template excludes reminders and hidden rows', () {
    expect(
      isSavedFlowTemplate(isSaved: true, isHidden: false, isReminder: false),
      isTrue,
    );
    expect(
      isSavedFlowTemplate(isSaved: true, isHidden: false, isReminder: true),
      isFalse,
    );
    expect(
      isSavedFlowTemplate(isSaved: true, isHidden: true, isReminder: false),
      isFalse,
    );
    expect(
      isSavedFlowTemplate(isSaved: false, isHidden: false, isReminder: false),
      isFalse,
    );
  });
}

class _FakeFlow {
  const _FakeFlow({
    required this.id,
    required this.active,
    required this.isSaved,
    required this.isHidden,
    required this.isReminder,
    this.endDate,
  });

  final int id;
  final bool active;
  final bool isSaved;
  final bool isHidden;
  final bool isReminder;
  final DateTime? endDate;
  String? get notes => null;
}
