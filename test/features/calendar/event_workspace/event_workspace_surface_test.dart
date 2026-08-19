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

    expect(
      formatEventWorkspaceRemaining(const Duration(minutes: 5, seconds: 4)),
      '5:04 remaining',
    );
    expect(
      formatEventWorkspaceRemaining(const Duration(hours: 1, minutes: 2)),
      '1:02:00 remaining',
    );
    expect(
      eventWorkspacePurposeFromDetail('  Draw from life.  '),
      'Draw from life.',
    );
    expect(
      eventWorkspacePurposeFromDetail('flowLocalId=12; Keep the line honest.'),
      'Keep the line honest.',
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

  testWidgets('player keeps a 16:9 frame and workspace body below it', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EventWorkspaceSurface(
          title: 'Draw the Idea',
          sourceUrl: 'https://www.youtube.com/watch?v=dQw4w9wgGcQ',
          purpose: 'Keep the line honest.',
          canonicalEnd: DateTime.now().add(
            const Duration(minutes: 5, seconds: 4),
          ),
          onMinimize: () {},
          onClose: () {},
        ),
      ),
    );

    final player = tester.widget<AspectRatio>(
      find.byKey(eventWorkspacePlayerFrameKey),
    );
    expect(player.aspectRatio, closeTo(16 / 9, 0.0001));
    expect(find.byKey(eventWorkspaceBodyKey), findsOneWidget);
    expect(find.byKey(eventWorkspaceRemainingKey), findsOneWidget);
    expect(find.text('Keep the line honest.'), findsOneWidget);
    expect(
      tester.getRect(find.byKey(eventWorkspacePlayerFrameKey)).height,
      lessThan(tester.getRect(find.byKey(eventWorkspaceSurfaceKey)).height),
    );
  });

  test(
    'YouTube renderer covers the platform-view flash with the workspace canvas',
    () {
      final renderer = File(
        'lib/features/calendar/event_workspace/youtube_workspace_renderer.dart',
      ).readAsStringSync();
      expect(renderer, contains('youtubeWorkspaceLoaderKey'));
      expect(renderer, contains("iframe.style.backgroundColor = '#060504'"));
      expect(renderer, contains('Color(0xFF060504)'));
      expect(renderer, isNot(contains('Color(0xFF111111)')));
    },
  );

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
