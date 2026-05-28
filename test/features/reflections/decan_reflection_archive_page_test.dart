import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/decan_reflection_model.dart';
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

  test('prompt dismissed state is not an archive visibility filter', () async {
    final source = await File(
      'lib/features/reflections/decan_reflection_archive_page.dart',
    ).readAsString();

    expect(source, contains('final result = await _repo.listMineResult();'));
    expect(source, isNot(contains('hasInteracted(')));
    expect(source, isNot(contains('hasDismissed(')));
  });
}
