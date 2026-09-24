import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/profile/profile_backdrop_timeline.dart';

void main() {
  test('normalizes device clock samples to local time', () {
    final utcNow = DateTime.utc(2026, 4, 26, 18, 30, 45);

    expect(profileBackdropPhoneLocalNow(() => utcNow), utcNow.toLocal());
  });

  test('blends across the curated dawn interval', () {
    final blend = ProfileBackdropBlend.forTime(
      DateTime(2026, 4, 26, 5, 37, 30),
    );

    expect(
      blend.current.assetPath,
      endsWith('/Gemini_Generated_Image_tj7dxltj7dxltj7d.png'),
    );
    expect(
      blend.next.assetPath,
      endsWith('/Gemini_Generated_Image_fzalkbfzalkbfzal.png'),
    );
    expect(blend.t, closeTo(22.5 / 45, 0.0001));
  });

  test('wraps from the evening anchor back into the overnight sequence', () {
    final blend = ProfileBackdropBlend.forTime(DateTime(2026, 4, 26, 23, 30));

    expect(
      blend.current.assetPath,
      endsWith('/Gemini_Generated_Image_vc4fm5vc4fm5vc4f.png'),
    );
    expect(
      blend.next.assetPath,
      endsWith('/Gemini_Generated_Image_ud0tf5ud0tf5ud0t.png'),
    );
    expect(blend.t, closeTo(195 / 255, 0.0001));
  });

  test('waits until the next minute blend tick', () {
    final delay = profileBackdropDelayUntilNextBlendTick(
      DateTime(2026, 4, 26, 9, 15, 30, 250),
    );

    expect(delay, const Duration(seconds: 29, milliseconds: 750));
  });

  test('keeps the intended profile day-cycle backdrop assets registered', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final assetFiles = Directory(profileBackdropAssetDirectory)
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.png'))
        .toList();

    expect(pubspec, contains('assets/profile/day_cycle_alt_2/'));
    expect(assetFiles, hasLength(profileBackdropFrames.length));
    for (final frame in profileBackdropFrames) {
      expect(File(frame.assetPath).existsSync(), isTrue);
    }
  });

  test('obsolete painted pyramid fallback is not reachable from Profile', () {
    final profileSource = File(
      'lib/features/profile/profile_page.dart',
    ).readAsStringSync();
    final backdropSource = File(
      'lib/features/profile/profile_backdrop_timeline.dart',
    ).readAsStringSync();
    final combinedSource = '$profileSource\n$backdropSource';

    expect(combinedSource, isNot(contains('_ProfileBackdropPainter')));
    expect(combinedSource, isNot(contains('_paintPyramid')));
    expect(
      combinedSource,
      isNot(contains('CustomPaint(painter: _ProfileBackdropPainter())')),
    );
    expect(backdropSource, contains('profileBackdropNeutralPlaceholderKey'));
  });

  test('community flow posts open the canonical detail surface', () {
    final profileSource = File(
      'lib/features/profile/profile_page.dart',
    ).readAsStringSync();
    final socialTileSource = File(
      'lib/features/profile/social_flow_post_tile.dart',
    ).readAsStringSync();
    final tileSource = _methodSource(
      profileSource,
      'Widget _buildFeedFlowTile(',
      'Widget _buildFeedInsightTile(',
    );
    expect(tileSource, contains('SocialFlowPostTile('));
    expect(tileSource, contains('onOpenFlow: () => _openFeedFlowPost(post)'));
    expect(socialTileSource, contains('PostedFlowArtifact('));
    expect(socialTileSource, contains('FlowPostEngagementRow('));
    expect(socialTileSource, contains('additionalActions:'));
    expect(socialTileSource, contains('relationshipLabel:'));
    expect(socialTileSource, contains('color: Colors.black'));
    expect(
      socialTileSource,
      isNot(contains('borderRadius: BorderRadius.circular(22)')),
    );
    expect(tileSource, contains('FlowPostShareActions.open(context, post)'));
    expect(tileSource, isNot(contains('copyWith(clearImage: true)')));
    expect(tileSource, isNot(contains("label: 'Begin'")));
    expect(tileSource, isNot(contains('_openPostDetails')));
    expect(tileSource, isNot(contains('FlowPostDetailPage')));
    expect(profileSource, isNot(contains('_buildExpandedFlowDetailCard')));
  });

  test('feed owns one full-frame pyramid hero below the app bar', () {
    final profileSource = File(
      'lib/features/profile/profile_page.dart',
    ).readAsStringSync();
    final feedSource = _methodSource(
      profileSource,
      'Widget _buildFeedMode()',
      'Widget _buildHeroSection(',
    );

    expect(feedSource, contains('padding: EdgeInsets.only(top: appBarBottom)'));
    expect(feedSource, contains('const heroExtent = 168.0'));
    expect(feedSource, contains('_ProfileFeedHeroHeaderDelegate('));
    expect(profileSource, contains("'profile-feed-pyramid-hero'"));
    expect(profileSource, contains('fit: BoxFit.cover'));
    expect(profileSource, contains('offset: Offset(0, shrinkOffset * 0.34)'));
    expect(profileSource, contains('if (showBackdrop && !_feedRevealed)'));
  });

  testWidgets(
    'uses a neutral placeholder until the intended backdrop asset resolves',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final imageInfo = Completer<ImageInfo>();
      final requestedPaths = <String>[];
      DateTime clock() => DateTime(2026, 4, 26, 9, 30);
      final expectedBlend = ProfileBackdropBlend.forTime(clock());

      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox.expand(
            child: ProfileDayCycleBackdrop(
              clock: clock,
              imageProviderFactory: (_, assetPath, _) => _DelayedImageProvider(
                assetPath: assetPath,
                requestedPaths: requestedPaths,
                imageInfo: imageInfo.future,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(profileBackdropNeutralPlaceholderKey), findsOneWidget);
      expect(find.byKey(profileBackdropResolvedImagesKey), findsNothing);
      expect(find.byType(Image), findsNothing);
      expect(_obsoleteProfileBackdropPainters(), findsNothing);
      expect(requestedPaths, contains(expectedBlend.current.assetPath));

      final resolvedImage = await tester.runAsync(() => createTestImage());
      expect(resolvedImage, isNotNull);
      imageInfo.complete(ImageInfo(image: resolvedImage!));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      expect(find.byKey(profileBackdropNeutralPlaceholderKey), findsOneWidget);
      expect(find.byKey(profileBackdropResolvedImagesKey), findsOneWidget);
      expect(_obsoleteProfileBackdropPainters(), findsNothing);

      final images = tester.widgetList<Image>(find.byType(Image)).toList();
      expect(images, hasLength(1));
      final finalProvider = images.single.image;
      expect(finalProvider, isA<_DelayedImageProvider>());
      expect(
        (finalProvider as _DelayedImageProvider).assetPath,
        expectedBlend.current.assetPath,
      );

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

String _methodSource(String source, String startMarker, String endMarker) {
  final start = source.indexOf(startMarker);
  final end = source.indexOf(endMarker, start + startMarker.length);

  expect(start, isNonNegative, reason: startMarker);
  expect(end, isNonNegative, reason: endMarker);

  return source.substring(start, end);
}

Finder _obsoleteProfileBackdropPainters() {
  return find.byWidgetPredicate(
    (widget) =>
        widget is CustomPaint &&
        '${widget.painter}'.contains('_ProfileBackdropPainter'),
  );
}

class _DelayedImageProvider extends ImageProvider<_DelayedImageProvider> {
  const _DelayedImageProvider({
    required this.assetPath,
    required this.requestedPaths,
    required this.imageInfo,
  });

  final String assetPath;
  final List<String> requestedPaths;
  final Future<ImageInfo> imageInfo;

  @override
  Future<_DelayedImageProvider> obtainKey(ImageConfiguration configuration) {
    return Future<_DelayedImageProvider>.value(this);
  }

  @override
  ImageStreamCompleter loadImage(
    _DelayedImageProvider key,
    ImageDecoderCallback decode,
  ) {
    requestedPaths.add(assetPath);
    return OneFrameImageStreamCompleter(imageInfo);
  }

  @override
  bool operator ==(Object other) {
    return other is _DelayedImageProvider && other.assetPath == assetPath;
  }

  @override
  int get hashCode => assetPath.hashCode;
}
