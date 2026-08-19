import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/event_resource.dart';
import 'package:mobile/utils/external_link_utils.dart';

void main() {
  EventResource? resolve({
    Object? behaviorPayload,
    String? detail,
    String? location,
  }) {
    return resolveEventResource(
      EventResourceSource(
        behaviorPayload: behaviorPayload,
        detail: detail,
        location: location,
      ),
    );
  }

  test('behaviorPayload beats detail and location', () {
    final resource = resolve(
      behaviorPayload: const {'url': 'https://payload.example/watch'},
      detail: 'See https://detail.example/notes for context.',
      location: 'https://location.example/place',
    );
    expect(
      resource,
      const EventResource(
        target: 'https://payload.example/watch',
        kind: EventResourceKind.web,
      ),
    );
  });

  test('detail beats location when payload has no usable target', () {
    final resource = resolve(
      behaviorPayload: const {'url': '   '},
      detail: 'Read https://detail.example/path tonight.',
      location: 'City Hall',
    );
    expect(
      resource,
      const EventResource(
        target: 'https://detail.example/path',
        kind: EventResourceKind.web,
      ),
    );
  });

  test('nested structured payload targets still resolve', () {
    final resource = resolve(
      behaviorPayload: const {
        'meta': {
          'links': {'watch_url': 'https://nested.example/video'},
        },
      },
      detail: 'https://detail.example/ignored',
      location: 'https://location.example/ignored',
    );
    expect(
      resource,
      const EventResource(
        target: 'https://nested.example/video',
        kind: EventResourceKind.web,
      ),
    );
  });

  test('compact payload keys still resolve', () {
    final resource = resolve(
      behaviorPayload: const {'externalUrl': 'https://compact.example/doc'},
    );
    expect(resource?.target, 'https://compact.example/doc');
    expect(resource?.kind, EventResourceKind.web);
  });

  test('ordinary https resources remain web', () {
    final resource = resolve(
      detail: 'Open https://docs.example.com/guide.pdf later.',
    );
    expect(resource?.kind, EventResourceKind.web);
    expect(resource?.target, 'https://docs.example.com/guide.pdf');
  });

  test('mailto remains email', () {
    final resource = resolve(
      behaviorPayload: const {'href': 'mailto:keeper@example.com'},
    );
    expect(
      resource,
      const EventResource(
        target: 'mailto:keeper@example.com',
        kind: EventResourceKind.email,
      ),
    );
  });

  test('tel remains phone', () {
    final resource = resolve(
      behaviorPayload: const {'link': 'tel:+15551234567'},
    );
    expect(
      resource,
      const EventResource(
        target: 'tel:+15551234567',
        kind: EventResourceKind.phone,
      ),
    );
  });

  test('location map fallback remains map-compatible', () {
    const address = '1600 Pennsylvania Avenue NW, Washington, DC';
    final resource = resolve(location: address);
    expect(resource?.target, address);
    expect(resource?.kind, EventResourceKind.map);
    final uri = buildExternalLaunchUri(resource!.target, fallbackToMaps: true);
    expect(uri, isNotNull);
    expect(uri!.host, contains('maps.google'));
    expect(
      eventResourceCameFromLocation(
        const EventResourceSource(location: address),
      ),
      isTrue,
    );
  });

  test('YouTube resolves as an ordinary web resource', () {
    const url = 'https://www.youtube.com/watch?v=abc123';
    final resource = resolve(location: url);
    expect(
      resource,
      const EventResource(target: url, kind: EventResourceKind.web),
    );
    expect(eventResourceDashboardLabel(resource!), 'Watch on YouTube');
    expect(
      eventResourceActionLabel(Uri.parse(url), fallbackToMaps: true),
      'Watch on YouTube',
    );
  });

  test('malformed and unsupported input preserves null fallback', () {
    expect(resolve(), isNull);
    expect(resolve(detail: 'No links here.', location: '   '), isNull);
    expect(
      resolve(behaviorPayload: const {'url': 'not a launch target'}),
      isNull,
    );
    expect(resolveEventResourceFromRaw('hello world'), isNull);
  });

  test('invalid payload is skipped so later sources can still win', () {
    final resource = resolve(
      behaviorPayload: const {
        'url': 'not a launch target',
        'href': 'https://second.example/ok',
      },
    );
    expect(resource?.target, 'https://second.example/ok');
  });

  test(
    'dashboard helper preserves contains-youtu token labeling without a registry',
    () {
      expect(
        eventResourceDashboardLabel(
          const EventResource(
            target: 'https://youtu.be/example',
            kind: EventResourceKind.web,
          ),
        ),
        'Watch on YouTube',
      );
      expect(
        eventResourceDashboardTokenLooksLikeYouTube(
          'https://cdn.example.com/youtu-session',
        ),
        isTrue,
      );
      expect(
        eventResourceDashboardLabel(
          const EventResource(
            target: 'https://cdn.example.com/youtu-session',
            kind: EventResourceKind.web,
          ),
        ),
        'Watch on YouTube',
      );
      expect(
        eventResourceDashboardLabel(
          const EventResource(
            target: 'https://zoom.us/j/123',
            kind: EventResourceKind.web,
          ),
        ),
        'Open Link',
      );
    },
  );

  test(
    'dashboard location adapter ignores detail YouTube in favor of Vimeo',
    () {
      const vimeo = 'https://vimeo.com/123456789';
      const youtube = 'https://www.youtube.com/watch?v=abc123';
      expect(
        resolveEventResource(
          const EventResourceSource(detail: youtube, location: vimeo),
        )?.target,
        youtube,
      );
      final resource = resolveEventResourceForDashboard(vimeo);
      expect(resource?.target, vimeo);
      expect(eventResourceDashboardLabel(resource!), 'Open Link');
    },
  );

  test(
    'dashboard location adapter keeps YouTube location over payload URL',
    () {
      const youtube = 'https://www.youtube.com/watch?v=abc123';
      const other = 'https://docs.example.com/notes';
      expect(
        resolveEventResource(
          const EventResourceSource(
            behaviorPayload: {'url': other},
            location: youtube,
          ),
        )?.target,
        other,
      );
      final resource = resolveEventResourceForDashboard(youtube);
      expect(resource?.target, youtube);
      expect(eventResourceDashboardLabel(resource!), 'Watch on YouTube');
    },
  );

  test('dashboard has no external CTA when location is absent', () {
    const youtube = 'https://www.youtube.com/watch?v=abc123';
    expect(
      resolveEventResource(
        const EventResourceSource(
          behaviorPayload: {'url': youtube},
          detail: 'Watch https://www.youtube.com/watch?v=abc123',
        ),
      )?.target,
      youtube,
    );
    expect(resolveEventResourceForDashboard(null), isNull);
    expect(resolveEventResourceForDashboard(''), isNull);
    expect(resolveEventResourceForDashboard('   '), isNull);
  });

  test('normalized location token containing youtu keeps Watch on YouTube', () {
    const token = 'https://media.example.net/clip.youtu';
    final resource = resolveEventResourceForDashboard(token);
    expect(resource?.target, token);
    expect(eventResourceDashboardLabel(resource!), 'Watch on YouTube');
    expect(eventResourceDashboardTokenLooksLikeYouTube(token), isTrue);
  });

  test('flow dashboard uses a location-only compatibility adapter', () {
    final source = File(
      'lib/features/calendar/calendar_flow_pages.dart',
    ).readAsStringSync();
    final dashboard = source.substring(
      source.indexOf('_FlowDayContent _contentForDashboardDay('),
      source.indexOf('Widget _buildDashboardBody({'),
    );
    expect(
      dashboard,
      contains('resolveEventResourceForDashboard(event.location)'),
    );
    expect(dashboard, contains('eventResourceDashboardLabel(resource)'));
    expect(
      dashboard,
      isNot(contains('behaviorPayload: event.behaviorPayload')),
    );
    expect(dashboard, isNot(contains('detail: event.detail')));
    expect(dashboard, isNot(contains("contains('youtu')")));
    expect(source, isNot(contains("contains('youtu')")));
    expect(source, contains('_launchExternalPreviewTarget(content.location!)'));

    final adapter = File(
      'lib/features/calendar/event_resource.dart',
    ).readAsStringSync();
    final dashboardResolver = adapter.substring(
      adapter.indexOf(
        'EventResource? resolveEventResourceForDashboard(String? location) {',
      ),
      adapter.indexOf('bool eventResourceCameFromLocation('),
    );
    expect(dashboardResolver, contains('behaviorPayload: null'));
    expect(dashboardResolver, contains('detail: null'));
    expect(dashboardResolver, contains('location: location'));
  });

  test('Day View no longer owns resource-search precedence', () {
    final source = File(
      'lib/features/calendar/day_view.dart',
    ).readAsStringSync();
    final adapter = source.substring(
      source.indexOf(
        '_DayViewExternalAction? _dayViewExternalActionForEvent(EventItem event) {',
      ),
      source.indexOf('bool _dayViewShouldShowDetailLocation('),
    );
    expect(adapter, contains('resolveEventResource(source)'));
    expect(adapter, contains('eventResourceCameFromLocation(source)'));
    expect(source, isNot(contains('_dayViewCollectPayloadTargets')));
    expect(source, isNot(contains('_dayViewExternalActionForRaw')));
  });

  test(
    'parseYouTubeVideoId extracts watch, short, embed, and youtu.be ids',
    () {
      expect(
        parseYouTubeVideoId('https://www.youtube.com/watch?v=dQw4w9wgGcQ'),
        'dQw4w9wgGcQ',
      );
      expect(
        parseYouTubeVideoId('https://youtu.be/dQw4w9wgGcQ?t=30'),
        'dQw4w9wgGcQ',
      );
      expect(
        parseYouTubeVideoId('https://www.youtube.com/shorts/dQw4w9wgGcQ'),
        'dQw4w9wgGcQ',
      );
      expect(
        parseYouTubeVideoId('https://www.youtube.com/embed/dQw4w9wgGcQ'),
        'dQw4w9wgGcQ',
      );
      expect(
        parseYouTubeVideoId('https://www.youtube.com/playlist?list=PLtest'),
        isNull,
      );
      expect(
        parseYouTubeVideoId('https://example.com/watch?v=dQw4w9wgGcQ'),
        isNull,
      );
      expect(
        youtubeEmbedUrlForVideoId('dQw4w9wgGcQ'),
        contains('youtube.com/embed/dQw4w9wgGcQ'),
      );
    },
  );
}
