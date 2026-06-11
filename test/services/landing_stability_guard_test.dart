import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('landing stability guards', () {
    test(
      'Planner keeps the route scaffold stable while data is loading',
      () async {
        final source = await File(
          'lib/features/rhythm/pages/todays_alignment_page.dart',
        ).readAsString();
        final plannerContent = _sourceBetween(
          source,
          'Widget _plannerContent({bool embedded = false})',
          'PreferredSizeWidget _buildAppBar()',
        );

        expect(plannerContent, contains('final plannerLoading ='));
        expect(plannerContent, contains('_buildPlannerLoadingSlot('));
        expect(plannerContent, contains('label: \'Restoring commitments\''));
        expect(
          plannerContent,
          contains('label: \'Restoring completed moments\''),
        );
        expect(plannerContent, isNot(contains('child: RhythmLoadingShell()')));
        expect(
          plannerContent,
          isNot(
            contains(
              'snapshot.connectionState == ConnectionState.waiting) {\n'
              '          return',
            ),
          ),
        );
      },
    );

    test(
      'Profile renders a shaped loading shell instead of a blank void',
      () async {
        final source = await File(
          'lib/features/profile/profile_page.dart',
        ).readAsString();
        final buildMethod = _sourceBetween(
          source,
          'Widget build(BuildContext context)',
          'Widget _buildNoProfile()',
        );
        final loadingShell = _sourceBetween(
          source,
          'Widget _buildProfileLoadingShell()',
          'Widget _buildNoProfile()',
        );
        final backdropSource = await File(
          'lib/features/profile/profile_backdrop_timeline.dart',
        ).readAsString();

        expect(
          source,
          contains('const Positioned.fill(child: ProfileDayCycleBackdrop())'),
        );

        expect(buildMethod, contains('final loadingProfileShell ='));
        expect(
          buildMethod,
          contains(
            'final showBackdrop = _profile != null || loadingProfileShell',
          ),
        );
        expect(buildMethod, contains('? _buildProfileLoadingShell()'));
        expect(buildMethod, isNot(contains('? const SizedBox.expand()')));
        expect(
          buildMethod,
          isNot(
            contains(
              '? const Center(\n'
              '                child: CircularProgressIndicator',
            ),
          ),
        );
        expect(loadingShell, contains('final heroHeight ='));
        expect(loadingShell, contains('_profileSkeletonTile'));
        expect(
          backdropSource,
          contains('profileBackdropNeutralPlaceholderKey'),
        );
        expect(source, isNot(contains('_ProfileBackdropPainter')));
        expect(source, isNot(contains('_paintPyramid')));
        expect(
          source,
          isNot(contains('CustomPaint(painter: _ProfileBackdropPainter())')),
        );
      },
    );

    test('detached calendar actions close before dispatch', () async {
      final source = await File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsString();
      final panel = _sourceBetween(
        source,
        'static Widget buildDetachedActionsMenuPanel',
        'static Future<void> openQuickAddFromAnyContext',
      );

      expect(panel, contains('await closeMenu();'));
      expect(panel, contains('await action.onSelected();'));
      expect(
        panel.indexOf('await closeMenu();'),
        lessThan(panel.indexOf('await action.onSelected();')),
      );
      expect(panel, isNot(contains('if (action.dispatchBeforeClose)')));
    });
  });
}

String _sourceBetween(String source, String start, String end) {
  final startIndex = source.indexOf(start);
  expect(startIndex, isNonNegative, reason: 'Missing source start: $start');
  final endIndex = source.indexOf(end, startIndex + start.length);
  expect(endIndex, isNonNegative, reason: 'Missing source end: $end');
  return source.substring(startIndex, endIndex);
}
