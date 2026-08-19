import 'package:flutter/material.dart';

import '../../utils/external_link_utils.dart';

enum EventResourceKind { web, email, phone, map }

class EventResourceSource {
  const EventResourceSource({this.behaviorPayload, this.detail, this.location});

  final Object? behaviorPayload;
  final String? detail;
  final String? location;
}

class EventResource {
  const EventResource({required this.target, required this.kind});

  final String target;
  final EventResourceKind kind;

  @override
  bool operator ==(Object other) {
    return other is EventResource &&
        other.target == target &&
        other.kind == kind;
  }

  @override
  int get hashCode => Object.hash(target, kind);
}

const Set<String> _eventResourcePayloadKeys = {
  'url',
  'uri',
  'href',
  'link',
  'external_url',
  'externalurl',
  'external_link',
  'externallink',
  'action_url',
  'actionurl',
  'meeting_url',
  'meetingurl',
  'video_url',
  'videourl',
  'watch_url',
  'watchurl',
  'document_url',
  'documenturl',
  'map_url',
  'mapurl',
};

void _collectEventResourcePayloadTargets(
  Object? node,
  List<String> targets, [
  int depth = 0,
]) {
  if (node == null || depth > 4) return;
  if (node is Map) {
    for (final entry in node.entries) {
      final key = entry.key.toString().trim().toLowerCase();
      final normalizedKey = key.replaceAll(RegExp(r'[\s-]'), '_');
      final compactKey = normalizedKey.replaceAll('_', '');
      final value = entry.value;
      final isTargetKey =
          _eventResourcePayloadKeys.contains(normalizedKey) ||
          _eventResourcePayloadKeys.contains(compactKey);
      if (isTargetKey) {
        if (value is String) {
          targets.add(value);
        } else if (value is Iterable) {
          for (final item in value) {
            if (item is String) targets.add(item);
          }
        }
      }
      if (value is Map || value is Iterable) {
        _collectEventResourcePayloadTargets(value, targets, depth + 1);
      }
    }
  } else if (node is Iterable) {
    for (final item in node) {
      _collectEventResourcePayloadTargets(item, targets, depth + 1);
    }
  }
}

EventResource? resolveEventResourceFromRaw(
  String raw, {
  bool fallbackToMaps = false,
}) {
  final target = normalizeExternalLinkToken(raw);
  if (target.isEmpty) return null;
  final uri = buildExternalLaunchUri(target, fallbackToMaps: fallbackToMaps);
  if (uri == null) return null;
  return EventResource(target: target, kind: eventResourceKindForUri(uri));
}

EventResourceKind eventResourceKindForUri(Uri uri) {
  final scheme = uri.scheme.toLowerCase();
  final host = uri.host.toLowerCase();
  if (scheme == 'mailto') return EventResourceKind.email;
  if (scheme == 'tel') return EventResourceKind.phone;
  if (host.contains('maps.google') || host.contains('apple.com/maps')) {
    return EventResourceKind.map;
  }
  return EventResourceKind.web;
}

bool _eventResourceIsYouTube(Uri uri) {
  final host = uri.host.toLowerCase();
  return host.contains('youtube.com') || host.contains('youtu.be');
}

EventResource? resolveEventResource(EventResourceSource source) {
  final structuredTargets = <String>[];
  _collectEventResourcePayloadTargets(
    source.behaviorPayload,
    structuredTargets,
  );
  for (final raw in structuredTargets) {
    final resource = resolveEventResourceFromRaw(raw);
    if (resource != null) return resource;
  }

  final detail = source.detail;
  if (detail != null && detail.trim().isNotEmpty) {
    for (final match in externalLinkPattern.allMatches(detail)) {
      final raw = match.group(0);
      if (raw == null || !looksLikeLaunchTarget(raw)) continue;
      final resource = resolveEventResourceFromRaw(raw);
      if (resource != null) return resource;
    }
  }

  final location = source.location?.trim();
  if (location != null && location.isNotEmpty) {
    return resolveEventResourceFromRaw(location, fallbackToMaps: true);
  }

  return null;
}

EventResource? resolveEventResourceForDashboard(String? location) {
  return resolveEventResource(
    EventResourceSource(
      behaviorPayload: null,
      detail: null,
      location: location,
    ),
  );
}

bool eventResourceCameFromLocation(EventResourceSource source) {
  return resolveEventResource(
        EventResourceSource(
          behaviorPayload: source.behaviorPayload,
          detail: source.detail,
        ),
      ) ==
      null;
}

String eventResourceActionLabel(Uri uri, {required bool fallbackToMaps}) {
  final scheme = uri.scheme.toLowerCase();
  final host = uri.host.toLowerCase();
  if (scheme == 'mailto') return 'Email';
  if (scheme == 'tel') return 'Call';
  if (_eventResourceIsYouTube(uri)) return 'Watch on YouTube';
  if (host.contains('zoom.us') ||
      host.contains('meet.google') ||
      host.contains('teams.microsoft')) {
    return 'Join meeting';
  }
  if (fallbackToMaps ||
      host.contains('maps.google') ||
      host.contains('apple.com/maps')) {
    return 'Open map';
  }
  if (host.contains('docs.google') ||
      host.contains('notion.') ||
      uri.path.toLowerCase().endsWith('.pdf')) {
    return 'Open document';
  }
  return 'Open link';
}

IconData eventResourceActionIcon(Uri uri, {required bool fallbackToMaps}) {
  final scheme = uri.scheme.toLowerCase();
  final host = uri.host.toLowerCase();
  if (scheme == 'mailto') return Icons.mail_outline_rounded;
  if (scheme == 'tel') return Icons.call_outlined;
  if (_eventResourceIsYouTube(uri)) return Icons.play_arrow_rounded;
  if (host.contains('zoom.us') ||
      host.contains('meet.google') ||
      host.contains('teams.microsoft')) {
    return Icons.videocam_outlined;
  }
  if (fallbackToMaps ||
      host.contains('maps.google') ||
      host.contains('apple.com/maps')) {
    return Icons.map_outlined;
  }
  if (host.contains('docs.google') ||
      host.contains('notion.') ||
      uri.path.toLowerCase().endsWith('.pdf')) {
    return Icons.description_outlined;
  }
  return Icons.open_in_new_rounded;
}

bool eventResourceDashboardTokenLooksLikeYouTube(String token) {
  return normalizeExternalLinkToken(token).toLowerCase().contains('youtu');
}

String eventResourceDashboardLabel(EventResource resource) {
  if (eventResourceDashboardTokenLooksLikeYouTube(resource.target)) {
    return 'Watch on YouTube';
  }
  return 'Open Link';
}
