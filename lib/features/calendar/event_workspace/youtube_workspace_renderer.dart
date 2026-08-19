import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../event_resource.dart';

const Key youtubeWorkspacePlayerKey = ValueKey<String>(
  'event-workspace-youtube-player',
);
const Key youtubeWorkspaceFallbackKey = ValueKey<String>(
  'event-workspace-youtube-fallback',
);

class YouTubeWorkspaceRenderer extends StatelessWidget {
  const YouTubeWorkspaceRenderer({
    super.key,
    required this.sourceUrl,
    required this.onOpenExternally,
  });

  final String sourceUrl;
  final Future<void> Function(String target) onOpenExternally;

  @override
  Widget build(BuildContext context) {
    final videoId = parseYouTubeVideoId(sourceUrl);
    if (videoId == null || !kIsWeb) {
      return _YouTubeWorkspaceFallback(
        onOpen: () => onOpenExternally(sourceUrl),
      );
    }
    return _YouTubeEmbedFrame(videoId: videoId);
  }
}

class _YouTubeEmbedFrame extends StatelessWidget {
  const _YouTubeEmbedFrame({required this.videoId});

  final String videoId;

  @override
  Widget build(BuildContext context) {
    final embedUrl = youtubeEmbedUrlForVideoId(videoId);
    return ColoredBox(
      color: const Color(0xFF111111),
      child: HtmlElementView.fromTagName(
        key: youtubeWorkspacePlayerKey,
        tagName: 'iframe',
        onElementCreated: (Object element) {
          final iframe = element as dynamic;
          iframe.src = embedUrl;
          iframe.allowFullscreen = true;
          iframe.allow =
              'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share';
          iframe.style.border = '0';
          iframe.style.width = '100%';
          iframe.style.height = '100%';
        },
      ),
    );
  }
}

class _YouTubeWorkspaceFallback extends StatelessWidget {
  const _YouTubeWorkspaceFallback({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: youtubeWorkspaceFallbackKey,
      color: const Color(0xFF161310),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'This YouTube video can’t play inside Hꜣw.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFF3E6D0),
                  fontSize: 16,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onOpen,
                child: const Text('Open on YouTube'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
