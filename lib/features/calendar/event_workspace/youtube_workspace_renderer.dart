import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../event_resource.dart';

const Color _workspaceCanvas = Color(0xFF060504);
const Color _workspaceInk = Color(0xFFF3E6D0);

const Key youtubeWorkspacePlayerKey = ValueKey<String>(
  'event-workspace-youtube-player',
);
const Key youtubeWorkspaceFallbackKey = ValueKey<String>(
  'event-workspace-youtube-fallback',
);
const Key youtubeWorkspaceLoaderKey = ValueKey<String>(
  'event-workspace-youtube-loader',
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

class _YouTubeEmbedFrame extends StatefulWidget {
  const _YouTubeEmbedFrame({required this.videoId});

  final String videoId;

  @override
  State<_YouTubeEmbedFrame> createState() => _YouTubeEmbedFrameState();
}

class _YouTubeEmbedFrameState extends State<_YouTubeEmbedFrame> {
  bool _ready = false;

  void _markReady() {
    if (!mounted || _ready) return;
    setState(() {
      _ready = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final embedUrl = youtubeEmbedUrlForVideoId(widget.videoId);
    return ColoredBox(
      color: _workspaceCanvas,
      child: Stack(
        fit: StackFit.expand,
        children: [
          HtmlElementView.fromTagName(
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
              iframe.style.display = 'block';
              iframe.style.backgroundColor = '#060504';
              iframe.addEventListener('load', (dynamic _) {
                _markReady();
              });
              Future<void>.delayed(
                const Duration(milliseconds: 1200),
                _markReady,
              );
            },
          ),
          if (!_ready) const _YouTubeWorkspaceLoader(),
        ],
      ),
    );
  }
}

class _YouTubeWorkspaceLoader extends StatelessWidget {
  const _YouTubeWorkspaceLoader();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      key: youtubeWorkspaceLoaderKey,
      color: _workspaceCanvas,
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 1.6,
            color: Color(0x99F3E6D0),
          ),
        ),
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
      color: _workspaceCanvas,
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
                  color: _workspaceInk,
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
