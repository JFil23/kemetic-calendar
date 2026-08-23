import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Cut 3 hard cutover. Locks the V1 Follow the Sky surface out of the tree so it
/// cannot be reintroduced by a later merge.
void main() {
  String read(String path) => File(path).readAsStringSync();

  const maatFlows = 'lib/features/calendar/calendar_maat_flows.dart';

  test('the V1 Track Sky scaffold and its join sheet are gone', () {
    final source = read(maatFlows);
    for (final symbol in const [
      '_buildTrackSkyScaffold',
      '_openTrackSkyJoinSheet',
      '_buildTrackSkyCategorySection',
      '_buildTrackSkyEventTile',
      '_trackSkyFuture',
    ]) {
      expect(
        source,
        isNot(contains(symbol)),
        reason: '$symbol belonged to the retired V1 detail surface',
      );
    }
  });

  test('there is no V1/V2 routing fork left', () {
    expect(
      File(
        'lib/features/calendar/follow_the_sky/follow_sky_v2_flags.dart',
      ).existsSync(),
      isFalse,
      reason: 'V2 is the only path; the flag file must be deleted',
    );

    final source = read(maatFlows);
    expect(source, isNot(contains('FollowSkyV2Flags')));
    expect(source, isNot(contains('useV2Production')));

    // The trackSky branch goes straight to V2 with no conditional.
    final detailState = source.substring(
      source.indexOf('class _MaatFlowTemplateDetailPageState'),
    );
    final branchStart = detailState.indexOf(
      'widget.template.kind == _MaatFlowTemplateKind.trackSky',
    );
    expect(branchStart, isNonNegative);
    final branch = detailState.substring(
      branchStart,
      detailState.indexOf(
        'widget.template.kind == _MaatFlowTemplateKind.dawnHouseRite',
        branchStart,
      ),
    );
    expect(branch, contains('FollowSkyDetailPage('));
    expect(branch, contains('joinTrackSkyV2Headless'));
  });

  test('the V1 parser data and markdown assets stay deleted', () {
    expect(
      File('lib/features/calendar/track_sky_flow_data.g.dart').existsSync(),
      isFalse,
    );
    expect(Directory('assets/ma_at_flows').existsSync(), isFalse);
    expect(
      read('pubspec.yaml'),
      isNot(contains('assets/ma_at_flows/')),
      reason: 'a declared-but-missing asset directory breaks release builds',
    );
    // The V1 asset path helper went with the markdown files.
    expect(
      read('lib/features/calendar/track_sky_timezone.dart'),
      isNot(contains('assets/ma_at_flows')),
    );
  });

  test('enrollment runs through the V2 catalog only', () {
    final joinService = read('lib/features/calendar/flow_join_service.dart');
    final headless = joinService.substring(
      joinService.indexOf('Future<FlowJoinResult> joinTrackSkyHeadless('),
    );
    final body = headless.substring(0, headless.indexOf('\n  Future<'));
    expect(body, contains('SkyCatalogRepository()'));
    expect(body, contains('TrackSkyEnrollmentService('));
    expect(body, contains('joinTrackSkyV2Headless'));
    // No V1 parser types may appear in the enrollment path.
    expect(body, isNot(contains('loadTrackSkyFlowData')));
    expect(body, isNot(contains('TrackSkyFlowData')));
  });
}
