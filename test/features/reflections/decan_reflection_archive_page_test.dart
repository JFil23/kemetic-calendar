import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/decan_reflection_model.dart';
import 'package:mobile/data/maat_guidance_model.dart';
import 'package:mobile/features/reflections/decan_reflection_archive_page.dart';

void main() {
  test('archive rows include decan reflection rows for detail routing', () {
    final rows = buildDecanReflectionArchiveRowsForTesting([
      DecanReflection(
        id: 'reflection-1',
        decanName: 'Peret - Measure',
        decanTheme: 'Measure',
        decanStart: DateTime.utc(2026, 5, 6),
        decanEnd: DateTime.utc(2026, 5, 15),
        badgeCount: 3,
        reflectionText: 'A generated end-of-decan reflection.',
        createdAt: DateTime.utc(2026, 5, 16),
      ),
    ]);

    expect(rows, hasLength(1));
    expect(rows.single.id, 'reflection-1');
    expect(rows.single.title, 'Peret - Measure');
    expect(rows.single.route, '/reflections/reflection-1');
    expect(rows.single.preview, 'A generated end-of-decan reflection.');
  });

  test('partial archive errors do not hide valid reflection rows', () {
    expect(
      decanReflectionArchiveVisibleError(
        hasVisibleItems: true,
        reflectionErrorMessage: null,
        openingErrorMessage: 'Could not load decan openings.',
      ),
      isNull,
    );

    expect(
      decanReflectionArchiveVisibleError(
        hasVisibleItems: false,
        reflectionErrorMessage: 'Could not load decan reflections.',
        openingErrorMessage: null,
      ),
      'Could not load decan reflections.',
    );
  });

  test('archive rows include opened and acted decan openings only', () {
    final rows = buildDecanOpeningArchiveRowsForTesting([
      _opening('opened-opening', MaatGuidanceStatus.opened),
      _opening('acted-opening', MaatGuidanceStatus.acted),
      _opening('pending-opening', MaatGuidanceStatus.pending),
    ]);

    expect(
      rows.map((row) => row.id),
      containsAll(<String>['opened-opening', 'acted-opening']),
    );
    expect(rows.map((row) => row.id), isNot(contains('pending-opening')));
    expect(
      rows.map((row) => row.route),
      contains('/maat-guidance/opened-opening'),
    );
    expect(rows.first.title, startsWith('Opening'));
  });

  test('archive-only openings are understood by the archive surface', () {
    final rows = buildDecanOpeningArchiveRowsForTesting([
      _opening('archive-only-opening', MaatGuidanceStatus.archiveOnly),
    ]);

    expect(rows, hasLength(1));
    expect(rows.single.id, 'archive-only-opening');
  });

  test(
    'archive skin keeps locked typography and glyph clearance tokens',
    () async {
      final skin = await File(
        'lib/features/reflections/decan_reflection_skin.dart',
      ).readAsString();

      expect(skin, contains("fontFamily = 'CormorantGaramond'"));
      expect(skin, contains("FontFeature('onum')"));
      expect(skin, contains('scrollBottomPadding = 104'));
      expect(skin, contains('scrimHeight = 96'));
    },
  );

  test('archive preview clipping does not append ellipsis text', () {
    final rows = buildDecanReflectionArchiveRowsForTesting([
      DecanReflection(
        id: 'reflection-long',
        decanName: 'Hathor — sꜣḥ',
        decanTheme: 'sꜣḥ',
        decanStart: DateTime.utc(2026, 5, 6),
        decanEnd: DateTime.utc(2026, 5, 15),
        badgeCount: 3,
        reflectionText: List.filled(40, 'measure').join(' '),
        createdAt: DateTime.utc(2026, 5, 16),
      ),
    ]);

    expect(rows.single.preview, isNot(contains('…')));
    expect(rows.single.preview, isNot(contains('...')));
  });

  test('prompt dismissed state is not an archive visibility filter', () async {
    final source = await File(
      'lib/features/reflections/decan_reflection_archive_page.dart',
    ).readAsString();

    expect(source, contains('final result = await _repo.listMineResult();'));
    expect(source, isNot(contains('hasInteracted(')));
    expect(source, isNot(contains('hasDismissed(')));
  });
}

MaatGuidanceDelivery _opening(String id, MaatGuidanceStatus status) {
  return MaatGuidanceDelivery(
    id: id,
    kind: MaatGuidanceKind.decanOpening,
    decanPeriodKey: '2026-05-29:2026-06-07:3-2',
    status: status,
    priority: 10,
    teaserText: 'Open the decan with one measured act.',
    bodyText: 'This decan opens through Hathor.',
    payload: const <String, dynamic>{},
    ctaType: MaatGuidanceCtaType.flowTemplate,
    ctaRef: 'the-decan-watch',
    triggerReason: 'decan_boundary',
    createdAt: DateTime.utc(2026, 5, 29),
  );
}
