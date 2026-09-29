import 'dart:io';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/decan_metadata.dart';
import 'package:mobile/features/calendar/kemetic_month_metadata.dart';
import 'package:mobile/features/calendar/pronunciation/pronunciation_catalog.dart';

const settings = PronunciationRenderSettings(
  voice: 'test-voice',
  locale: 'en-US',
  rate: '0%',
  pauseMilliseconds: 300,
  outputFormat: 'test-mp3',
  normalizationFilter: 'test-loudnorm',
  edgeTrimFilter: 'test-edge-trim',
  rendererVersion: 'test-1',
  ffmpegVersion: 'test-1',
);

PronunciationRecord fixture(
  PronunciationKey key, {
  String ipa = 'tɛst',
  String meaning = 'Test',
  String respelling = 'TEST',
  String input = 'test',
  int pause = 300,
  String? textHash,
  PronunciationAudioManifest? manifest,
  String? recordingHash,
  String? providerIpa,
  String? adaptationNote,
}) => PronunciationRecord(
  key: key,
  writtenTransliteration: 'test',
  pronunciationInput: input,
  displayName: 'Test',
  meaning: meaning,
  egyptologicalSpokenForm: 'TEST',
  ipa: ipa,
  readerRespelling: respelling,
  pauseMilliseconds: pause,
  sourceNotes: ['Synthetic fixture, not a catalog approval.'],
  reviewIssues: [],
  approvedTextHash: textHash,
  audioManifest: manifest,
  approvedRecordingHash: recordingHash,
  providerIpa: providerIpa,
  providerAdaptationNote: adaptationNote,
);

PronunciationRecord approvedFixture(PronunciationKey key, List<int> bytes) {
  final draft = fixture(key);
  final approved = fixture(key, textHash: draft.textFingerprint);
  final manifest = PronunciationAudioManifest(
    inputHash: approved.inputHash,
    renderFingerprint: approved.renderFingerprint(settings),
    settings: settings,
    outputSha256: sha256.convert(bytes).toString(),
  );
  final rendered = fixture(
    key,
    textHash: draft.textFingerprint,
    manifest: manifest,
  );
  return fixture(
    key,
    textHash: draft.textFingerprint,
    manifest: manifest,
    recordingHash: rendered.recordingApprovalHash,
  );
}

void main() {
  test('all 54 implementation approvals and bundled checksums are current', () {
    final rows = PronunciationCatalog.records;
    expect(
      rows.where((r) => r.textStatus == TextStatus.textApproved),
      hasLength(54),
    );
    expect(
      rows.every((r) => r.recordingStatus == RecordingStatus.rendered),
      isTrue,
    );
    final files = Directory(
      'assets/pronunciation',
    ).listSync().whereType<File>().toList();
    expect(files, hasLength(54));
    expect(
      PronunciationCatalog.releaseIssues(
        records: rows,
        settings: rows.first.audioManifest!.settings,
        assetBytes: {
          for (final row in rows)
            row.audioAsset: File(row.audioAsset).readAsBytesSync(),
        },
      ),
      isEmpty,
    );
    expect(
      PronunciationCatalog.releaseIssues(
        records: rows,
        settings: rows.first.audioManifest!.settings,
        assetBytes: {
          for (final row in rows)
            row.audioAsset: File(row.audioAsset).readAsBytesSync(),
        },
        requireListeningApproval: true,
      ),
      isNotEmpty,
    );
  });

  test('existing visible name spellings are frozen under user approval', () {
    final snapshot =
        jsonDecode(
              File(
                'test/fixtures/pronunciation_product_spellings.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    for (final month in snapshot['months'] as List) {
      final current = getMonthById(month['id'] as int);
      expect(current.displayShort, month['displayShort']);
      expect(current.displayTransliteration, month['displayTransliteration']);
    }
    for (final entry in (snapshot['decans'] as Map<String, dynamic>).entries) {
      expect(DecanMetadata.decanNames[int.parse(entry.key)], entry.value);
    }
    final source = File(
      'lib/widgets/kemetic_day_dropdown.dart',
    ).readAsStringSync().split('String _epagomenalDayTitle').last;
    for (final entry
        in (snapshot['birthdayDropdownLabels'] as Map<String, dynamic>)
            .entries) {
      expect(
        source,
        contains("case ${entry.key}:\n        return '${entry.value}';"),
      );
    }
  });

  test('exact 54-key set, unique structural identities and assets', () {
    final expected = <String>{
      for (var m = 1; m <= 12; m++) 'month.${m.toString().padLeft(2, '0')}',
      'heriu-renpet',
      for (var m = 1; m <= 12; m++)
        for (var d = 1; d <= 3; d++)
          'decan.${m.toString().padLeft(2, '0')}.${d.toString().padLeft(2, '0')}',
      for (var d = 1; d <= 5; d++) 'epagomenal.${d.toString().padLeft(2, '0')}',
    };
    final rows = PronunciationCatalog.records;
    expect(rows, hasLength(54));
    expect(rows.map((r) => r.key.value).toSet(), expected);
    expect(rows.map((r) => r.audioAsset).toSet(), hasLength(54));
    for (final row in rows) {
      expect(row.ipa, isNotEmpty);
      expect(row.readerRespelling, isNotEmpty);
      expect(row.sourceNotes, isNotEmpty);
      expect(row.pronunciationInput, isNot(contains('(')));
      expect(
        row.textStatus,
        row.reviewIssues.isEmpty
            ? TextStatus.textApproved
            : TextStatus.needsReview,
      );
      expect(row.recordingStatus, RecordingStatus.rendered);
    }
  });

  test(
    'written product spelling is copied exactly, not silently corrected',
    () {
      for (var m = 1; m <= 13; m++) {
        final row = PronunciationCatalog.lookup(PronunciationKey.month(m));
        expect(
          row.writtenTransliteration,
          getMonthById(m).displayTransliteration,
        );
      }
      for (var m = 1; m <= 12; m++) {
        for (var d = 1; d <= 3; d++) {
          expect(
            PronunciationCatalog.lookup(
              PronunciationKey.decan(m, d),
            ).writtenTransliteration,
            DecanMetadata.decanNames[m]![d - 1],
          );
        }
      }
      final heriu = PronunciationCatalog.lookup(PronunciationKey.month(13));
      expect(heriu.writtenTransliteration, 'ḥr.w rnpt');
      expect(heriu.pronunciationInput, 'ḥrjw-rnpt');
      expect(heriu.sourceNotes.join(' '), contains('PDF p.120'));
      for (var d = 1; d <= 5; d++) {
        expect(
          PronunciationCatalog.lookup(
            PronunciationKey.epagomenal(d),
          ).writtenTransliteration,
          isNull,
        );
      }
    },
  );

  test('legacy errors are not copied into the proposals', () {
    expect(
      PronunciationCatalog.lookup(PronunciationKey.month(1)).readerRespelling,
      isNot(contains('Thoth')),
    );
    expect(
      PronunciationCatalog.lookup(PronunciationKey.month(1)).meaning,
      isEmpty,
    );
    expect(
      PronunciationCatalog.lookup(
        PronunciationKey.decan(1, 2),
      ).readerRespelling.toLowerCase(),
      isNot(contains('hree')),
    );
    for (var d = 1; d <= 3; d++) {
      final row = PronunciationCatalog.lookup(PronunciationKey.decan(6, d));
      expect(row.readerRespelling.toLowerCase(), isNot(contains('khnum')));
      expect(row.meaning, isNotEmpty);
      expect(row.pronunciationInput, contains('ẖnmw'));
      expect(row.sourceNotes.join(' '), contains('knmw'));
      expect(row.reviewIssues, isEmpty);
    }
  });

  test('structural boundary mapping never invents month 13 decans', () {
    for (final pair in [(1, 1), (10, 1), (11, 2), (20, 2), (21, 3), (30, 3)]) {
      expect(
        PronunciationKey.forDay(1, pair.$1),
        PronunciationKey.decan(1, pair.$2),
      );
    }
    expect(PronunciationKey.forDay(2, 1).value, 'decan.02.01');
    expect(PronunciationKey.forDay(12, 30).value, 'decan.12.03');
    expect(PronunciationKey.month(12).value, 'month.12');
    expect(PronunciationKey.month(13).value, 'heriu-renpet');
    expect(PronunciationKey.forDay(13, 1).value, 'epagomenal.01');
    expect(PronunciationKey.forDay(13, 5).value, 'epagomenal.05');
    expect(() => PronunciationKey.decan(13, 1), throwsRangeError);
    expect(() => PronunciationKey.forDay(13, 6), throwsRangeError);
    expect(() => PronunciationKey.forDay(1, 0), throwsRangeError);
    expect(() => PronunciationKey.forDay(1, 31), throwsRangeError);
  });

  test('each text edit invalidates old text and recording approval', () {
    final original = approvedFixture(PronunciationKey.month(1), [1, 2, 3]);
    expect(original.recordingStatus, RecordingStatus.recordingApproved);
    final variants = [
      fixture(original.key, ipa: 'nɛw'),
      fixture(original.key, meaning: 'New'),
      fixture(original.key, input: 'new'),
      fixture(original.key, respelling: 'NEW'),
      fixture(original.key, pause: 400),
    ];
    for (final variant in variants) {
      final stale = fixture(
        original.key,
        ipa: variant.ipa,
        meaning: variant.meaning,
        input: variant.pronunciationInput,
        respelling: variant.readerRespelling,
        pause: variant.pauseMilliseconds,
        textHash: original.approvedTextHash,
        manifest: original.audioManifest,
        recordingHash: original.approvedRecordingHash,
      );
      expect(stale.inputHash, isNot(original.inputHash));
      expect(stale.textStatus, TextStatus.needsReview);
      expect(stale.recordingStatus, RecordingStatus.none);
    }
  });

  test(
    'provider adaptation preserves canonical IPA and invalidates approval',
    () {
      final original = approvedFixture(PronunciationKey.month(1), [1]);
      final changed = fixture(
        original.key,
        textHash: original.approvedTextHash,
        manifest: original.audioManifest,
        recordingHash: original.approvedRecordingHash,
        providerIpa: 't.est',
        adaptationNote: 'Representation changed; review required.',
      );
      expect(changed.ipa, original.ipa);
      expect(changed.textStatus, TextStatus.needsReview);
      expect(changed.recordingStatus, RecordingStatus.none);
    },
  );

  test('recording approval binds exact bytes even for an identical recipe', () {
    final original = approvedFixture(PronunciationKey.month(1), [1]);
    final replacement = PronunciationAudioManifest(
      inputHash: original.inputHash,
      renderFingerprint: original.renderFingerprint(settings),
      settings: settings,
      outputSha256: sha256.convert([2]).toString(),
    );
    final stale = fixture(
      original.key,
      textHash: original.approvedTextHash,
      manifest: replacement,
      recordingHash: original.approvedRecordingHash,
    );
    expect(stale.recordingStatus, RecordingStatus.rendered);
  });

  test(
    'release rejects partial, duplicate, stale-recipe, and corrupt bundles',
    () {
      final rows = [
        for (final key in PronunciationCatalog.expectedKeys)
          approvedFixture(key, [1, 2, 3]),
      ];
      final assets = {
        for (final row in rows) row.audioAsset: [1, 2, 3],
      };
      List<String> gate(
        List<PronunciationRecord> r,
        Map<String, List<int>> a, [
        PronunciationRenderSettings s = settings,
      ]) => PronunciationCatalog.releaseIssues(
        records: r,
        settings: s,
        assetBytes: a,
      );
      expect(gate(rows, assets), isEmpty);
      expect(
        gate(
          [rows.first],
          {
            rows.first.audioAsset: [1, 2, 3],
          },
        ),
        isNotEmpty,
      );
      expect(gate([...rows.skip(1), rows.last], assets), isNotEmpty);
      expect(
        gate(rows, {...assets, rows.first.audioAsset: []}),
        contains(contains('missing or empty')),
      );
      expect(
        gate(rows, {
          ...assets,
          rows.first.audioAsset: [9],
        }),
        contains(contains('checksum')),
      );
      for (final field in settings.toJson().keys) {
        final values = {
          ...settings.toJson(),
          field: field == 'pauseMilliseconds' ? 400 : 'changed',
        };
        final changed = PronunciationRenderSettings(
          voice: values['voice'] as String,
          locale: values['locale'] as String,
          rate: values['rate'] as String,
          pauseMilliseconds: values['pauseMilliseconds'] as int,
          outputFormat: values['outputFormat'] as String,
          normalizationFilter: values['normalizationFilter'] as String,
          edgeTrimFilter: values['edgeTrimFilter'] as String,
          rendererVersion: values['rendererVersion'] as String,
          ffmpegVersion: values['ffmpegVersion'] as String,
        );
        expect(
          gate(rows, assets, changed),
          contains(contains('configuration mismatch')),
          reason: field,
        );
      }
    },
  );

  test('cutover leaves no legacy authority or surface speech construction', () {
    final sources = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .map((f) => f.readAsStringSync())
        .join('\n');
    for (final symbol in [
      'SpeechResolver',
      'speech_overrides.dart',
      'isPhonetic',
      'speakPhonetic',
      'speechName',
      'class SpeechService',
    ]) {
      expect(sources, isNot(contains(symbol)));
    }
    for (var m = 1; m <= 12; m++) {
      for (var d = 1; d <= 3; d++) {
        final title =
            DecanMetadata.decanTitles[DecanMetadata.decanNames[m]![d - 1]]!;
        final gloss = RegExp(r'"([^"\n]+)"').firstMatch(title)!.group(1)!;
        expect(
          PronunciationCatalog.lookup(PronunciationKey.decan(m, d)).meaning,
          gloss,
        );
      }
    }
  });
}
