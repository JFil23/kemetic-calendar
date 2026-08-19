import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/event_workspace/event_workspace_models.dart';
import 'package:mobile/features/calendar/event_workspace/event_workspace_surface.dart';
import 'package:mobile/services/app_restoration_service.dart';
import 'package:mobile/services/restoration_coordinator.dart';

void main() {
  test('remaining time is canonical end minus now and is never persisted', () {
    final end = DateTime(2026, 8, 19, 8, 10);
    final now = DateTime(2026, 8, 19, 8, 5);
    expect(
      eventWorkspaceRemaining(canonicalEnd: end, now: now),
      const Duration(minutes: 5),
    );
    expect(eventWorkspaceHasEnded(canonicalEnd: end, now: end), isTrue);
    expect(
      eventWorkspaceHasEnded(
        canonicalEnd: end,
        now: DateTime(2026, 8, 19, 8, 9, 59),
      ),
      isFalse,
    );

    final source = File(
      'lib/features/calendar/event_workspace/event_workspace_surface.dart',
    ).readAsStringSync();
    expect(source, isNot(contains('remainingSeconds')));
    expect(source, isNot(contains('expired = true')));
  });

  test('all-day and missing-end events are not session-governable', () {
    expect(
      eventWorkspaceIsSessionGovernable(
        presentable: true,
        allDay: true,
        hasCanonicalSchedule: false,
      ),
      isFalse,
    );
    expect(
      eventWorkspaceIsSessionGovernable(
        presentable: true,
        allDay: false,
        hasCanonicalSchedule: false,
      ),
      isFalse,
    );
    expect(
      eventWorkspaceIsSessionGovernable(
        presentable: true,
        allDay: false,
        hasCanonicalSchedule: true,
      ),
      isTrue,
    );
    expect(
      noteHasCanonicalSchedule(
        allDay: false,
        startHour: 8,
        startMinute: 0,
        endHour: 8,
        endMinute: 10,
      ),
      isTrue,
    );
    expect(
      noteHasCanonicalSchedule(
        allDay: true,
        startHour: 9,
        startMinute: 0,
        endHour: 17,
        endMinute: 0,
      ),
      isFalse,
    );
  });

  test('restoration presentation is detail or workspace, never mode', () {
    final state = EventDetailRestorationState(
      kYear: 6267,
      kMonth: 4,
      kDay: 12,
      identityType: eventDetailIdentityClientEventId,
      identityValue: 'cid-youtube',
      presentation: eventWorkspacePresentationWorkspace,
    );
    final json = state.toJson();
    expect(json['presentation'], 'workspace');
    expect(json.containsKey('mode'), isFalse);
    expect(json.containsKey('remainingSeconds'), isFalse);

    final restored = EventDetailRestorationState.fromJson(json);
    expect(restored?.presentation, 'workspace');

    final invalid = EventDetailRestorationState.fromJson({
      ...json,
      'presentation': 'mode',
    });
    expect(invalid?.presentation, 'detail');
  });

  testWidgets('workspace minimize returns without completing', (tester) async {
    var minimized = false;
    var closed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: EventWorkspaceSurface(
          title: 'Morning practice',
          sourceUrl: 'https://www.youtube.com/watch?v=dQw4w9wgGcQ',
          onMinimize: () => minimized = true,
          onClose: () => closed = true,
        ),
      ),
    );

    expect(find.byKey(eventWorkspaceSurfaceKey), findsOneWidget);
    await tester.tap(find.byKey(eventWorkspaceMinimizeKey));
    await tester.pump();
    expect(minimized, isTrue);
    expect(closed, isFalse);
    expect(find.byKey(eventWorkspaceExpiredKey), findsNothing);
  });

  testWidgets('expired workspace shows Close and Extend without completing', (
    tester,
  ) async {
    var closed = false;
    Duration? requested;
    await tester.pumpWidget(
      MaterialApp(
        home: EventWorkspaceSurface(
          title: 'Timed YouTube',
          sourceUrl: 'https://www.youtube.com/watch?v=dQw4w9wgGcQ',
          canonicalEnd: DateTime.now().subtract(const Duration(seconds: 1)),
          onMinimize: () {},
          onClose: () => closed = true,
          onRequestExtend: (extension) async {
            requested = extension;
            return true;
          },
        ),
      ),
    );

    expect(find.byKey(eventWorkspaceExpiredKey), findsOneWidget);
    expect(find.text('This event has ended.'), findsOneWidget);
    expect(find.byKey(eventWorkspaceCloseKey), findsOneWidget);
    expect(find.byKey(eventWorkspaceExtend5Key), findsOneWidget);

    await tester.tap(find.byKey(eventWorkspaceExtend10Key));
    await tester.pump();
    expect(requested, const Duration(minutes: 10));
    expect(closed, isFalse);

    await tester.tap(find.byKey(eventWorkspaceCloseKey));
    await tester.pump();
    expect(closed, isTrue);
  });

  testWidgets('resume listenable recomputes expiry from wall clock', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EventWorkspaceSurface(
          title: 'Background expiry',
          sourceUrl: 'https://www.youtube.com/watch?v=dQw4w9wgGcQ',
          canonicalEnd: DateTime.now().add(const Duration(hours: 1)),
          onMinimize: () {},
          onClose: () {},
        ),
      ),
    );
    expect(find.byKey(eventWorkspaceExpiredKey), findsNothing);

    RestorationCoordinator.instance.noteLifecycleState(
      AppLifecycleState.resumed,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: EventWorkspaceSurface(
          title: 'Background expiry',
          sourceUrl: 'https://www.youtube.com/watch?v=dQw4w9wgGcQ',
          canonicalEnd: DateTime.now().subtract(const Duration(minutes: 1)),
          onMinimize: () {},
          onClose: () {},
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(eventWorkspaceExpiredKey), findsOneWidget);
  });
}
