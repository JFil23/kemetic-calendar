import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:mobile/services/speech/speech_catalog.g.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/kemetic_month_metadata.dart';
import 'package:mobile/features/calendar/decan_metadata.dart';
import 'package:mobile/features/calendar/speech_resolver.dart';
import 'package:mobile/widgets/kemetic_day_info.dart';

void main() {
  test('every current month and decan variant has verified G/H audio', () {
    final entries = <String, String>{};
    for (final month in kKemeticMonths.skip(1)) {
      entries['month-${month.id.toString().padLeft(2, '0')}'] =
          SpeechResolver.month(month: month);
    }
    for (var id = 1; id <= 36; id++) {
      final label = DecanMetadata.decanNames[(id - 1) ~/ 3 + 1]![(id - 1) % 3];
      final key = id.toString().padLeft(2, '0');
      entries['decan-$key'] = SpeechResolver.decan(
        decanId: id,
        displayName: label,
      );
      final title = DecanMetadata.decanTitles[label];
      final cue = title == null
          ? null
          : RegExp(r'"([^"]+)"').firstMatch(title)?.group(1);
      entries['decan-$key-cue'] = SpeechResolver.decan(
        decanId: id,
        displayName: label,
        englishCue: cue,
      );
    }
    for (var day = 1; day <= 6; day++) {
      final info = KemeticDayData.getInfoForDay('epagomenal_${day}_1');
      if (info != null) {
        entries['epagomenal-$day'] = SpeechResolver.decan(
          decanId: 0,
          displayName: info.decanName.split('(').first.trim(),
        );
      }
    }
    final dedup = <String, Map<String, Object>>{};
    for (final entry in entries.entries) {
      final row = dedup.putIfAbsent(
        entry.value,
        () => {'id': entry.key, 'text': entry.value, 'aliases': <String>[]},
      );
      (row['aliases'] as List<String>).add(entry.key);
    }
    expect(entries.keys.where((key) => key.startsWith('month-')).length, 13);
    expect(
      entries.keys
          .where((key) => key.startsWith('decan-') && !key.endsWith('-cue'))
          .length,
      36,
    );
    expect(dedup.length, 84);
    final manifest =
        jsonDecode(File('config/speech_library.v1.json').readAsStringSync())
            as Map<String, dynamic>;
    expect(manifest['phrases'], dedup.values.toList());
    for (final entry in dedup.entries) {
      expect(speechClipIds[entry.key], entry.value['id'], reason: entry.key);
      for (final voice in ['G', 'H']) {
        final asset = 'speech/library/$voice/${entry.value['id']}.m4a';
        final file = File('assets/$asset');
        expect(file.existsSync(), isTrue, reason: asset);
        expect(
          sha256.convert(file.readAsBytesSync()).toString(),
          speechAssetDigests[asset],
          reason: asset,
        );
      }
    }
    expect(speechAssetDigests.length, 170);
    for (final asset in speechAssetDigests.entries) {
      expect(
        sha256
            .convert(File('assets/${asset.key}').readAsBytesSync())
            .toString(),
        asset.value,
      );
    }
  });
}
