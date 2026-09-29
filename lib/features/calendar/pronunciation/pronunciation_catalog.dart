import 'dart:convert';

import 'package:crypto/crypto.dart';

part 'pronunciation_assets.g.dart';

/// Catalog text approval is distinct from final listening approval.
enum TextStatus { needsReview, textApproved }

enum RecordingStatus { none, rendered, recordingApproved }

enum PronunciationKind { month, decan, epagomenal }

/// A structural identity, never a display-string lookup.
class PronunciationKey {
  final PronunciationKind kind;
  final int monthId;
  final int? decanIndex;
  final int? epagomenalDay;

  const PronunciationKey._(
    this.kind,
    this.monthId, [
    this.decanIndex,
    this.epagomenalDay,
  ]);

  factory PronunciationKey.month(int monthId) {
    RangeError.checkValueInInterval(monthId, 1, 13, 'monthId');
    return PronunciationKey._(PronunciationKind.month, monthId);
  }

  factory PronunciationKey.decan(int monthId, int decanIndex) {
    RangeError.checkValueInInterval(monthId, 1, 12, 'monthId');
    RangeError.checkValueInInterval(decanIndex, 1, 3, 'decanIndex');
    return PronunciationKey._(PronunciationKind.decan, monthId, decanIndex);
  }

  factory PronunciationKey.epagomenal(int day) {
    RangeError.checkValueInInterval(day, 1, 5, 'epagomenalDay');
    return PronunciationKey._(PronunciationKind.epagomenal, 13, null, day);
  }

  /// Product month 13 has birthdays, not decans. Day 6 is intentionally outside
  /// the approved 54-key scope and must be handled explicitly at migration.
  static PronunciationKey forDay(int monthId, int day) {
    if (monthId == 13) return PronunciationKey.epagomenal(day);
    RangeError.checkValueInInterval(day, 1, 30, 'day');
    return PronunciationKey.decan(monthId, ((day - 1) ~/ 10) + 1);
  }

  String get value => switch (kind) {
    PronunciationKind.month =>
      monthId == 13 ? 'heriu-renpet' : 'month.${_two(monthId)}',
    PronunciationKind.decan => 'decan.${_two(monthId)}.${_two(decanIndex!)}',
    PronunciationKind.epagomenal => 'epagomenal.${_two(epagomenalDay!)}',
  };

  Map<String, Object?> get calendarIdentity => {
    'kind': kind.name,
    'monthId': monthId,
    'decanIndex': decanIndex,
    'epagomenalDay': epagomenalDay,
  };

  String get audioAsset =>
      'assets/pronunciation/${value.replaceAll('.', '_').replaceAll('-', '_')}.mp3';

  @override
  bool operator ==(Object other) =>
      other is PronunciationKey && value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

String _two(int value) => value.toString().padLeft(2, '0');
String _hash(Object value) =>
    sha256.convert(utf8.encode(jsonEncode(value))).toString();

/// Frozen render recipe. Exact filters/versions belong in the fingerprint,
/// including changes to loudness, silence trimming, encoding, or renderer code.
class PronunciationRenderSettings {
  final String voice;
  final String locale;
  final String rate;
  final int pauseMilliseconds;
  final String outputFormat;
  final String normalizationFilter;
  final String edgeTrimFilter;
  final String rendererVersion;
  final String ffmpegVersion;

  const PronunciationRenderSettings({
    required this.voice,
    required this.locale,
    required this.rate,
    required this.pauseMilliseconds,
    required this.outputFormat,
    required this.normalizationFilter,
    required this.edgeTrimFilter,
    required this.rendererVersion,
    required this.ffmpegVersion,
  });

  Map<String, Object> toJson() => {
    'voice': voice,
    'locale': locale,
    'rate': rate,
    'pauseMilliseconds': pauseMilliseconds,
    'outputFormat': outputFormat,
    'normalizationFilter': normalizationFilter,
    'edgeTrimFilter': edgeTrimFilter,
    'rendererVersion': rendererVersion,
    'ffmpegVersion': ffmpegVersion,
  };
}

class PronunciationAudioManifest {
  final String inputHash;
  final String renderFingerprint;
  final PronunciationRenderSettings settings;
  final String outputSha256;
  const PronunciationAudioManifest({
    required this.inputHash,
    required this.renderFingerprint,
    required this.settings,
    required this.outputSha256,
  });
}

class PronunciationRecord {
  final PronunciationKey key;

  /// Null means the product has no Egyptian transliteration for this birthday.
  /// Never fill this field with an invented "current product spelling".
  final String? writtenTransliteration;
  final String pronunciationInput;
  final String displayName;
  final String meaning;
  final String egyptologicalSpokenForm;
  final String ipa;
  final String readerRespelling;
  final List<String> sourceNotes;
  final List<String> reviewIssues;

  /// One name-to-gloss pause; omitted entirely in a name-only clip.
  final int pauseMilliseconds;

  /// Provider representation is separate from canonical IPA. Any adaptation is
  /// part of text approval; a changed sound must go back through text review.
  final String? providerIpa;
  final String? providerAdaptationNote;
  final String? approvedTextHash;
  final PronunciationAudioManifest? audioManifest;

  /// Binds listening approval to BOTH the render recipe and the exact bytes.
  final String? approvedRecordingHash;

  PronunciationRecord({
    required this.key,
    required this.writtenTransliteration,
    required this.pronunciationInput,
    required this.displayName,
    required this.meaning,
    required this.egyptologicalSpokenForm,
    required this.ipa,
    required this.readerRespelling,
    required List<String> sourceNotes,
    required List<String> reviewIssues,
    this.pauseMilliseconds = 300,
    this.providerIpa,
    this.providerAdaptationNote,
    this.approvedTextHash,
    PronunciationAudioManifest? audioManifest,
    this.approvedRecordingHash,
  }) : audioManifest =
           audioManifest ?? _bundledPronunciationManifests[key.value],
       sourceNotes = List.unmodifiable(sourceNotes),
       reviewIssues = List.unmodifiable(reviewIssues);

  String get audioAsset => key.audioAsset;
  Map<String, Object?> get calendarIdentity => key.calendarIdentity;

  String get inputHash => _hash({
    'schema': 1,
    'pronunciationInput': pronunciationInput,
    'ipa': ipa,
    'readerRespelling': readerRespelling,
    'meaning': meaning,
    'pauseMilliseconds': pauseMilliseconds,
  });

  String get textFingerprint => _hash({
    'inputHash': inputHash,
    'key': key.value,
    'writtenTransliteration': writtenTransliteration,
    'displayName': displayName,
    'egyptologicalSpokenForm': egyptologicalSpokenForm,
    'sourceNotes': sourceNotes,
    'reviewIssues': reviewIssues,
    'providerIpa': providerIpa,
    'providerAdaptationNote': providerAdaptationNote,
    'convention': pronunciationConvention,
  });

  TextStatus get textStatus =>
      reviewIssues.isEmpty &&
          approvedTextHash == textFingerprint &&
          pronunciationInput.isNotEmpty &&
          ipa.isNotEmpty &&
          readerRespelling.isNotEmpty &&
          sourceNotes.isNotEmpty &&
          !pronunciationInput.contains(RegExp(r'[()]')) &&
          (providerIpa == null ||
              (providerIpa!.isNotEmpty &&
                  (providerAdaptationNote?.isNotEmpty ?? false)))
      ? TextStatus.textApproved
      : TextStatus.needsReview;

  String renderFingerprint(PronunciationRenderSettings settings) => _hash({
    'schema': 1,
    'textFingerprint': textFingerprint,
    'inputHash': inputHash,
    'providerIpa': providerIpa ?? ipa,
    'settings': settings.toJson(),
  });

  String? get recordingApprovalHash => audioManifest == null
      ? null
      : _hash({
          'renderFingerprint': audioManifest!.renderFingerprint,
          'outputSha256': audioManifest!.outputSha256,
        });

  /// A stale saved receipt cannot keep an edited record approved or rendered.
  RecordingStatus get recordingStatus {
    final manifest = audioManifest;
    if (textStatus != TextStatus.textApproved ||
        manifest == null ||
        manifest.inputHash != inputHash ||
        manifest.settings.pauseMilliseconds != pauseMilliseconds ||
        manifest.renderFingerprint != renderFingerprint(manifest.settings) ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(manifest.outputSha256)) {
      return RecordingStatus.none;
    }
    return approvedRecordingHash == recordingApprovalHash
        ? RecordingStatus.recordingApproved
        : RecordingStatus.rendered;
  }
}

class PronunciationCatalog {
  PronunciationCatalog._();

  static final List<PronunciationKey> expectedKeys = List.unmodifiable([
    for (var m = 1; m <= 12; m++) PronunciationKey.month(m),
    PronunciationKey.month(13),
    for (var m = 1; m <= 12; m++)
      for (var d = 1; d <= 3; d++) PronunciationKey.decan(m, d),
    for (var d = 1; d <= 5; d++) PronunciationKey.epagomenal(d),
  ]);

  static final List<PronunciationRecord> records = List.unmodifiable(
    _draftRecords(),
  );

  static PronunciationRecord lookup(PronunciationKey key) =>
      records.singleWhere((record) => record.key == key);

  /// Catalog/byte portion of the release gate. Decoding, visual verification,
  /// and device/web playback gates must ALSO pass before cutover.
  static List<String> releaseIssues({
    required Iterable<PronunciationRecord> records,
    required PronunciationRenderSettings settings,
    required Map<String, List<int>> assetBytes,
    bool requireListeningApproval = false,
  }) {
    final rows = records.toList();
    final issues = <String>[];
    final expected = expectedKeys.map((key) => key.value).toSet();
    final actual = rows.map((row) => row.key.value).toSet();
    if (rows.length != 54 ||
        actual.length != 54 ||
        expected.difference(actual).isNotEmpty ||
        actual.difference(expected).isNotEmpty) {
      issues.add('Require exactly the 54 unique catalog identities.');
    }
    if (assetBytes.length != 54 ||
        expectedKeys.any((key) => !assetBytes.containsKey(key.audioAsset))) {
      issues.add('Require exactly 54 matching bundled assets.');
    }
    for (final row in rows) {
      final key = row.key.value;
      if (row.textStatus != TextStatus.textApproved) {
        issues.add('$key: text not approved.');
      }
      if (row.recordingStatus == RecordingStatus.none ||
          (requireListeningApproval &&
              row.recordingStatus != RecordingStatus.recordingApproved)) {
        issues.add('$key: recording not approved/current.');
      }
      if (row.audioManifest?.renderFingerprint !=
          row.renderFingerprint(settings)) {
        issues.add('$key: frozen render configuration mismatch.');
      }
      final bytes = assetBytes[row.audioAsset];
      if (bytes == null || bytes.isEmpty) {
        issues.add('$key: missing or empty asset.');
      } else if (sha256.convert(bytes).toString() !=
          row.audioManifest?.outputSha256) {
        issues.add('$key: asset checksum mismatch.');
      }
    }
    return List.unmodifiable(issues);
  }
}

const _allen =
    'James P. Allen, Middle Egyptian, second edition revised (2010), ISBN 978-0-521-51796-6';
const _faulkner =
    'Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian (1962/2002), Boris Jegorović modernization (2017), MEDU NETER DICTIONARY.pdf';

/// Verified page references. The row-level choices of syllables, stress, and
/// IPA remain review proposals; this is not a reconstructed ancient accent.
const pronunciationConvention = <String>[
  '$_faulkner: headword/page citations check spelling and gloss only; they do not supply vowels or stress.',
  '$_allen, §2.6, printed p.18 / PDF p.31: conventional American Egyptological pronunciation; short e is inserted "where necessary", not at every consonant boundary.',
  '$_allen, §2.6, PDF p.31: ꜣ/ꜥ use ah; j/y use ee; initial w uses w, otherwise usually oo; ḥ uses h; ḫ uses kh (or k); ẖ adds y; š uses sh; ṯ uses ch; ḏ uses English j. This proposal retains kh rather than silently using k.',
  '$_allen, §§2.3, 2.7, printed pp.14-15,18-19 / PDF pp.27-28,31-32: transliteration and English transcription differ. Product ȝ maps to ꜣ and ỉ to j; lowercase capitals, remove morphological dots, retain word boundaries. Existing search folding is not used.',
  '$_allen, §2.8(2), printed p.20 / PDF p.33: weak consonants can be omitted in writing. Restoration is row-specific and cited, never automatic.',
  'IPA /ɛ ɑ i u ɹ x xj ʃ tʃ dʒ/ and each row\'s syllabification/stress are editorial proposals from the English sound descriptions, not IPA or name-specific stress quoted from Allen. Capitals mark proposed stress. Approval is recorded per row; audible realization still requires audition.',
];

List<PronunciationRecord> _draftRecords() => [
  PronunciationRecord(
    key: PronunciationKey.month(1),
    approvedTextHash:
        'a4e48664d23be6501eec62f58d9e36dfe9e0f3ce8a698e6b43f89013c34d8ad5',
    writtenTransliteration: "Ḏḥwty",
    pronunciationInput: "ḏḥwty",
    displayName: "Thoth",
    meaning: "",
    egyptologicalSpokenForm: "JEH-hoo-tee",
    ipa: "ˈdʒɛ.hu.ti",
    readerRespelling: "JEH-hoo-tee",
    sourceNotes: [
      "User-authorized implementation: preserve visible spelling and gloss; source differences are content-audit notes, not playback gates. Read compositionally under Allen \u00a72.6. Offline voice produces replaceable first-pass audio, not verified ancient vowels.",
      ...pronunciationConvention,
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Allen §9.10 PDF p.122 lists ḏḥwtj in the later list; product y is retained. No second-name gloss.",
      "Source review accepted under the user's conditional approval: apply Allen §2.6 to the retained product consonants (or the explicitly cited birthday/restoration input). Syllables/stress apply that convention; they are not name-specific quotations. Visible app names and spellings must remain unchanged. Recording/voice audition remains unapproved.",
    ],
    reviewIssues: [],
  ),
  PronunciationRecord(
    key: PronunciationKey.month(2),
    approvedTextHash:
        '0ce106293dcafe84bbc37b360b4749b26c6bbacd9d28e64d03ddab06a71ce85b',
    writtenTransliteration: "Mnḫt",
    pronunciationInput: "mnḫt",
    displayName: "Paopi",
    meaning: "Clothing",
    egyptologicalSpokenForm: "MEN-khet",
    ipa: "ˈmɛn.xɛt",
    readerRespelling: "MEN-khet",
    sourceNotes: [
      "User-authorized implementation: preserve visible spelling and gloss; source differences are content-audit notes, not playback gates. Read compositionally under Allen \u00a72.6. Offline voice produces replaceable first-pass audio, not verified ancient vowels.",
      ...pronunciationConvention,
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Allen §9.10 PDF p.121 gives mnḫt, Clothing; Faulkner mnḫt PDF p.153 includes fabric and a different month position.",
      "Source review accepted under the user's conditional approval: apply Allen §2.6 to the retained product consonants (or the explicitly cited birthday/restoration input). Syllables/stress apply that convention; they are not name-specific quotations. Visible app names and spellings must remain unchanged. Recording/voice audition remains unapproved.",
    ],
    reviewIssues: [],
  ),
  PronunciationRecord(
    key: PronunciationKey.month(3),
    approvedTextHash:
        '6afa3ebc85f95459d04041504cbc05b360a0e254298497a27df58bd8989181a5',
    writtenTransliteration: "Ḥwt-Ḥr",
    pronunciationInput: "ḥwt-ḥr",
    displayName: "Hathor",
    meaning: "",
    egyptologicalSpokenForm: "HOOT HER",
    ipa: "hut hɛɹ",
    readerRespelling: "HOOT HER",
    sourceNotes: [
      "User-authorized implementation: preserve visible spelling and gloss; source differences are content-audit notes, not playback gates. Read compositionally under Allen \u00a72.6. Offline voice produces replaceable first-pass audio, not verified ancient vowels.",
      ...pronunciationConvention,
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Allen §9.10 PDF p.122 has ḥwt-ḥr(w); product omits w. Do not restore it from an alias.",
      "Source review accepted under the user's conditional approval: apply Allen §2.6 to the retained product consonants (or the explicitly cited birthday/restoration input). Syllables/stress apply that convention; they are not name-specific quotations. Visible app names and spellings must remain unchanged. Recording/voice audition remains unapproved.",
    ],
    reviewIssues: [],
  ),
  PronunciationRecord(
    key: PronunciationKey.month(4),
    approvedTextHash:
        '8c114ccb306c051fda8ea645ce6deb6116074f36fc92cbbd7adc99c544e07ca3',
    writtenTransliteration: "Kȝ-ḥr-Kȝ",
    pronunciationInput: "kꜣ-ḥr-kꜣ",
    displayName: "Ka-ḥer-Ka",
    meaning: "Ka upon Ka",
    egyptologicalSpokenForm: "KAH HER KAH",
    ipa: "kɑ hɛɹ kɑ",
    readerRespelling: "KAH HER KAH",
    sourceNotes: [
      "User-authorized implementation: preserve visible spelling and gloss; source differences are content-audit notes, not playback gates. Read compositionally under Allen \u00a72.6. Offline voice produces replaceable first-pass audio, not verified ancient vowels.",
      ...pronunciationConvention,
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Allen §9.10 PDF p.122, kꜣ-ḥr-kꜣ, Ka Upon Ka. Unicode ȝ is mapped to ꜣ.",
      "Source review accepted under the user's conditional approval: apply Allen §2.6 to the retained product consonants (or the explicitly cited birthday/restoration input). Syllables/stress apply that convention; they are not name-specific quotations. Visible app names and spellings must remain unchanged. Recording/voice audition remains unapproved.",
    ],
    reviewIssues: [],
  ),
  PronunciationRecord(
    key: PronunciationKey.month(5),
    approvedTextHash:
        '6882a2d8e81701c6d4015e6a78a8d289770caed42f04b377f49bc549334d4329',
    writtenTransliteration: "Šf-bdt",
    pronunciationInput: "šf-bdt",
    displayName: "Šef-Bedet",
    meaning: "Swelling of Emmer-Wheat",
    egyptologicalSpokenForm: "SHEF BEH-det",
    ipa: "ʃɛf ˈbɛ.dɛt",
    readerRespelling: "SHEF BEH-det",
    sourceNotes: [
      "User-authorized implementation: preserve visible spelling and gloss; source differences are content-audit notes, not playback gates. Read compositionally under Allen \u00a72.6. Offline voice produces replaceable first-pass audio, not verified ancient vowels.",
      ...pronunciationConvention,
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Allen §9.10 PDF p.122, šf-bdt, Swelling of Emmer-Wheat.",
      "Source review accepted under the user's conditional approval: apply Allen §2.6 to the retained product consonants (or the explicitly cited birthday/restoration input). Syllables/stress apply that convention; they are not name-specific quotations. Visible app names and spellings must remain unchanged. Recording/voice audition remains unapproved.",
    ],
    reviewIssues: [],
  ),
  PronunciationRecord(
    key: PronunciationKey.month(6),
    approvedTextHash:
        'b04f477b71b3dc5e643cf2c0e2f2bdd5c21a3f89818ab4c37bcf04add6b8d777',
    writtenTransliteration: "Rḫ-wr",
    pronunciationInput: "rḫ-wr",
    displayName: "Rekh-Wer",
    meaning: "",
    egyptologicalSpokenForm: "REKH WER",
    ipa: "ɹɛx wɛɹ",
    readerRespelling: "REKH WER",
    sourceNotes: [
      "User-authorized implementation: preserve visible spelling and gloss; source differences are content-audit notes, not playback gates. Read compositionally under Allen \u00a72.6. Offline voice produces replaceable first-pass audio, not verified ancient vowels.",
      "Prior review concerns retained for content audit: _stressReview,\n      \"Gloss unresolved: do not transfer Big Burning across different consonants.\",",
      ...pronunciationConvention,
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Allen §9.10 PDF p.122 gives rkḥ-ꜥꜣ, not product Rḫ-wr. The historical list is not substituted.",
    ],
    reviewIssues: [],
  ),
  PronunciationRecord(
    key: PronunciationKey.month(7),
    approvedTextHash:
        '2189f0d59bc8e0f7643784734dd108073a2964fdf0c31162fbc4808fabd39970',
    writtenTransliteration: "Rḫ-nḏs",
    pronunciationInput: "rḫ-nḏs",
    displayName: "Rekh-Nedjes",
    meaning: "",
    egyptologicalSpokenForm: "REKH NEH-jes",
    ipa: "ɹɛx ˈnɛ.dʒɛs",
    readerRespelling: "REKH NEH-jes",
    sourceNotes: [
      "User-authorized implementation: preserve visible spelling and gloss; source differences are content-audit notes, not playback gates. Read compositionally under Allen \u00a72.6. Offline voice produces replaceable first-pass audio, not verified ancient vowels.",
      "Prior review concerns retained for content audit: _stressReview,\n      \"Gloss unresolved: do not transfer Little Burning across different consonants.\",",
      ...pronunciationConvention,
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Allen §9.10 PDF p.122 gives rkḥ-nḏs, not product Rḫ-nḏs.",
    ],
    reviewIssues: [],
  ),
  PronunciationRecord(
    key: PronunciationKey.month(8),
    approvedTextHash:
        'd155b8ed981bf3cd6cc2dccae547cb9360f0b72ade2a8e0fa526ae6a6cf2922e',
    writtenTransliteration: "Rnnwt",
    pronunciationInput: "rnnwt",
    displayName: "Renwet",
    meaning: "",
    egyptologicalSpokenForm: "REN-noot",
    ipa: "ˈɹɛn.nut",
    readerRespelling: "REN-noot",
    sourceNotes: [
      "User-authorized implementation: preserve visible spelling and gloss; source differences are content-audit notes, not playback gates. Read compositionally under Allen \u00a72.6. Offline voice produces replaceable first-pass audio, not verified ancient vowels.",
      "Prior review concerns retained for content audit: _stressReview,\n      \"Product spelling lacks the second t; identity/empty gloss requires review.\",",
      ...pronunciationConvention,
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Allen §9.10 PDF p.122 gives rnn-wtt (Rennutet); Faulkner PDF p.204 distinguishes rnnwt joy and Rnnwtt the goddess.",
    ],
    reviewIssues: [],
  ),
  PronunciationRecord(
    key: PronunciationKey.month(9),
    approvedTextHash:
        'd3d68222a4e19c507c95740ebe222700718e19621b5924133575d7d8352e9c64',
    writtenTransliteration: "Ḥnsw",
    pronunciationInput: "ḥnsw",
    displayName: "Hnsw",
    meaning: "",
    egyptologicalSpokenForm: "HEN-soo",
    ipa: "ˈhɛn.su",
    readerRespelling: "HEN-soo",
    sourceNotes: [
      "User-authorized implementation: preserve visible spelling and gloss; source differences are content-audit notes, not playback gates. Read compositionally under Allen \u00a72.6. Offline voice produces replaceable first-pass audio, not verified ancient vowels.",
      "Prior review concerns retained for content audit: _stressReview,\n      \"Do not replace ḥ with ḫ or say Khonsu without cited approval.\",",
      ...pronunciationConvention,
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Allen §9.10 PDF p.122 gives ḫnsw (Khonsu), not product Ḥnsw.",
    ],
    reviewIssues: [],
  ),
  PronunciationRecord(
    key: PronunciationKey.month(10),
    approvedTextHash:
        'ccd03f25ca36fc403d41171b85ec13a43a727058ec44a79ae34cb519c31c765e',
    writtenTransliteration: "Ḥnt-ḥtj",
    pronunciationInput: "ḥnt-ḥtj",
    displayName: "Ḥenti-ḥet",
    meaning: "",
    egyptologicalSpokenForm: "HENT HEH-tee",
    ipa: "hɛnt ˈhɛ.ti",
    readerRespelling: "HENT HEH-tee",
    sourceNotes: [
      "User-authorized implementation: preserve visible spelling and gloss; source differences are content-audit notes, not playback gates. Read compositionally under Allen \u00a72.6. Offline voice produces replaceable first-pass audio, not verified ancient vowels.",
      "Prior review concerns retained for content audit: _stressReview,\n      \"Historical spelling differs materially; gloss/identity unresolved.\",",
      ...pronunciationConvention,
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Allen §9.10 PDF p.122 gives ḫnt-ẖty-prtj, not product Ḥnt-ḥtj.",
    ],
    reviewIssues: [],
  ),
  PronunciationRecord(
    key: PronunciationKey.month(11),
    approvedTextHash:
        '4845078952d62cc5bfae1108770fa68b0a1ffdc786e619da37d0b6e27610ce72',
    writtenTransliteration: "ỉpt-ḥmt",
    pronunciationInput: "jpt-ḥmt",
    displayName: "Pa-Ipi",
    meaning: "She Whose Incarnation Is Select",
    egyptologicalSpokenForm: "EE-pet HEH-met",
    ipa: "ˈi.pɛt ˈhɛ.mɛt",
    readerRespelling: "EE-pet HEH-met",
    sourceNotes: [
      "User-authorized implementation: preserve visible spelling and gloss; source differences are content-audit notes, not playback gates. Read compositionally under Allen \u00a72.6. Offline voice produces replaceable first-pass audio, not verified ancient vowels.",
      ...pronunciationConvention,
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Allen §9.10 PDF p.122 gives jpt ḥmt and this gloss; product ỉ maps to j. Pa-Ipi remains the visible product label.",
      "Source review accepted under the user's conditional approval: apply Allen §2.6 to the retained product consonants (or the explicitly cited birthday/restoration input). Syllables/stress apply that convention; they are not name-specific quotations. Visible app names and spellings must remain unchanged. Recording/voice audition remains unapproved.",
    ],
    reviewIssues: [],
  ),
  PronunciationRecord(
    key: PronunciationKey.month(12),
    approvedTextHash:
        '919538e80270cfc686e61787e74e264d5ae1547a5bc6f4290f3ec89b960beecd',
    writtenTransliteration: "Mswt-Rꜥ",
    pronunciationInput: "mswt-rꜥ",
    displayName: "Mesut-Ra",
    meaning: "Birth of Re",
    egyptologicalSpokenForm: "MES-oot RAH",
    ipa: "ˈmɛs.ut ɹɑ",
    readerRespelling: "MES-oot RAH",
    sourceNotes: [
      "User-authorized implementation: preserve visible spelling and gloss; source differences are content-audit notes, not playback gates. Read compositionally under Allen \u00a72.6. Offline voice produces replaceable first-pass audio, not verified ancient vowels.",
      ...pronunciationConvention,
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Allen §9.10 PDF p.122, mswt-rꜥ; §9.8 PDF p.120 also names the festival.",
      "Source review accepted under the user's conditional approval: apply Allen §2.6 to the retained product consonants (or the explicitly cited birthday/restoration input). Syllables/stress apply that convention; they are not name-specific quotations. Visible app names and spellings must remain unchanged. Recording/voice audition remains unapproved.",
    ],
    reviewIssues: [],
  ),
  PronunciationRecord(
    key: PronunciationKey.month(13),
    approvedTextHash:
        '589758a32a00f2591a346be84a0b78d3b3a4853cc39dfd255d842e034cf9fe81',
    writtenTransliteration: "ḥr.w rnpt",
    pronunciationInput: "ḥrjw-rnpt",
    displayName: "Heriu Renpet",
    meaning: "Those over the year",
    egyptologicalSpokenForm: "HEH-ree-oo REN-pet",
    ipa: "ˈhɛ.ɹi.u ˈɹɛn.pɛt",
    readerRespelling: "HEH-ree-oo REN-pet",
    sourceNotes: [
      "User-authorized implementation: preserve visible spelling and gloss; source differences are content-audit notes, not playback gates. Read compositionally under Allen \u00a72.6. Offline voice produces replaceable first-pass audio, not verified ancient vowels.",
      ...pronunciationConvention,
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Allen §9.8 PDF p.120 gives ḥr(j)w-rnpt and those over the year; §2.8(2) PDF p.33 explains parentheses. Faulkner ḥryw-rnpt PDF p.232. Proposed explicit restoration is ḥrjw-rnpt, with no parentheses sent to synthesis.",
      "Source review accepted under the user's conditional approval: apply Allen §2.6 to the retained product consonants (or the explicitly cited birthday/restoration input). Syllables/stress apply that convention; they are not name-specific quotations. Visible app names and spellings must remain unchanged. Recording/voice audition remains unapproved.",
    ],
    reviewIssues: [],
  ),
  PronunciationRecord(
    key: PronunciationKey.decan(1, 1),
    approvedTextHash:
        '01bb8ca3fc22dad106d028fcfa2214f0800e5431e87fd1c6c19594eb2405469e',
    writtenTransliteration: "tpy-ꜥ sbꜣw",
    pronunciationInput: "tpy-ꜥ sbꜣw",
    displayName: "tpy-ꜥ sbꜣw",
    meaning: "Foremost of the Stars",
    egyptologicalSpokenForm: "TEH-pee AH SEH-bah-oo",
    ipa: "ˈtɛ.pi ɑ ˈsɛ.bɑ.u",
    readerRespelling: "TEH-pee AH SEH-bah-oo",
    sourceNotes: [
      "User-authorized implementation: preserve visible spelling and gloss; source differences are content-audit notes, not playback gates. Read compositionally under Allen \u00a72.6. Offline voice produces replaceable first-pass audio, not verified ancient vowels.",
      "Prior review concerns retained for content audit: _stressReview,\n      \"Confirm Foremost compound gloss; ḥry-ib means in the midst, not a literal heart.\",",
      ...pronunciationConvention,
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Faulkner sbꜣ star PDF p.288; tpy-ꜥ compound identification remains unverified.",
    ],
    reviewIssues: [],
  ),
  PronunciationRecord(
    key: PronunciationKey.decan(1, 2),
    approvedTextHash:
        'e5fd702fb740bcba05905e8ec72aea00c75e6a0dc6fe05fbc60180b2d33f5002',
    writtenTransliteration: "ḥry-ib sbꜣw",
    pronunciationInput: "ḥry-jb sbꜣw",
    displayName: "ḥry-ib sbꜣw",
    meaning: "Heart of the Stars",
    egyptologicalSpokenForm: "HEH-ree EEB SEH-bah-oo",
    ipa: "ˈhɛ.ɹi ib ˈsɛ.bɑ.u",
    readerRespelling: "HEH-ree EEB SEH-bah-oo",
    sourceNotes: [
      "User-authorized implementation: preserve visible spelling and gloss; source differences are content-audit notes, not playback gates. Read compositionally under Allen \u00a72.6. Offline voice produces replaceable first-pass audio, not verified ancient vowels.",
      ...pronunciationConvention,
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Faulkner sbꜣ star PDF p.288; tpy-ꜥ compound identification remains unverified.",
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Faulkner ḥr(y)-ib PDF p.232: which is in the middle/midst; re-derived as ḥry + jb, not Hree-ib.",
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Product ib uses the British i convention for Allen j: Allen §2.3 PDF p.28. This row explicitly maps ib to jb; it is not a global letter substitution.",
      "Source review accepted under the user's conditional approval: apply Allen §2.6 to the retained product consonants (or the explicitly cited birthday/restoration input). Syllables/stress apply that convention; they are not name-specific quotations. Visible app names and spellings must remain unchanged. Recording/voice audition remains unapproved.",
    ],
    reviewIssues: [],
  ),
  PronunciationRecord(
    key: PronunciationKey.decan(1, 3),
    approvedTextHash:
        'fafad413f5f38381d0477bee1fef4bb690060fd9d0cf2ad61915071db845200f',
    writtenTransliteration: "sbꜣw",
    pronunciationInput: "sbꜣw",
    displayName: "sbꜣw",
    meaning: "The Stars",
    egyptologicalSpokenForm: "SEH-bah-oo",
    ipa: "ˈsɛ.bɑ.u",
    readerRespelling: "SEH-bah-oo",
    sourceNotes: [
      "User-authorized implementation: preserve visible spelling and gloss; source differences are content-audit notes, not playback gates. Read compositionally under Allen \u00a72.6. Offline voice produces replaceable first-pass audio, not verified ancient vowels.",
      ...pronunciationConvention,
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Faulkner sbꜣ star PDF p.288; tpy-ꜥ compound identification remains unverified.",
      "Source review accepted under the user's conditional approval: apply Allen §2.6 to the retained product consonants (or the explicitly cited birthday/restoration input). Syllables/stress apply that convention; they are not name-specific quotations. Visible app names and spellings must remain unchanged. Recording/voice audition remains unapproved.",
    ],
    reviewIssues: [],
  ),
  PronunciationRecord(
    key: PronunciationKey.decan(2, 1),
    approvedTextHash:
        'b241197e0092f21bcd8b2aa7eaff35ae743852f61c022d4d2ab83a7459adf652',
    writtenTransliteration: "ꜥḥꜣy",
    pronunciationInput: "ꜥḥꜣy",
    displayName: "ꜥḥꜣy",
    meaning: "The Riser",
    egyptologicalSpokenForm: "AH-hah-ee",
    ipa: "ˈɑ.hɑ.i",
    readerRespelling: "AH-hah-ee",
    sourceNotes: [
      "User-authorized implementation: preserve visible spelling and gloss; source differences are content-audit notes, not playback gates. Read compositionally under Allen \u00a72.6. Offline voice produces replaceable first-pass audio, not verified ancient vowels.",
      "Prior review concerns retained for content audit: _stressReview,\n      \"The Riser is not established for ꜥḥꜣy by these entries; unresolved gloss is intentionally empty.\",",
      ...pronunciationConvention,
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Faulkner ꜥḥꜣ fight/warrior PDF p.74; nfr beautiful PDF p.180; sbꜣ PDF p.288.",
    ],
    reviewIssues: [],
  ),
  PronunciationRecord(
    key: PronunciationKey.decan(2, 2),
    approvedTextHash:
        '72d6d000b07a64b169dd5d00866b996c7d1286f945c4b52121496d34287c9f31',
    writtenTransliteration: "ḥry-ib ꜥḥꜣy",
    pronunciationInput: "ḥry-jb ꜥḥꜣy",
    displayName: "ḥry-ib ꜥḥꜣy",
    meaning: "Heart of the Riser",
    egyptologicalSpokenForm: "HEH-ree EEB AH-hah-ee",
    ipa: "ˈhɛ.ɹi ib ˈɑ.hɑ.i",
    readerRespelling: "HEH-ree EEB AH-hah-ee",
    sourceNotes: [
      "User-authorized implementation: preserve visible spelling and gloss; source differences are content-audit notes, not playback gates. Read compositionally under Allen \u00a72.6. Offline voice produces replaceable first-pass audio, not verified ancient vowels.",
      "Prior review concerns retained for content audit: _stressReview,\n      \"The Riser is not established for ꜥḥꜣy by these entries; unresolved gloss is intentionally empty.\",",
      ...pronunciationConvention,
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Faulkner ꜥḥꜣ fight/warrior PDF p.74; nfr beautiful PDF p.180; sbꜣ PDF p.288.",
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Faulkner ḥr(y)-ib PDF p.232: which is in the middle/midst; re-derived as ḥry + jb, not Hree-ib.",
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Product ib uses the British i convention for Allen j: Allen §2.3 PDF p.28. This row explicitly maps ib to jb; it is not a global letter substitution.",
    ],
    reviewIssues: [],
  ),
  PronunciationRecord(
    key: PronunciationKey.decan(2, 3),
    approvedTextHash:
        '1f6d2488863980c3ef64e3b9748efa6d36f08fe012534fe8bc1bd2872d27156b',
    writtenTransliteration: "sbꜣ nfr",
    pronunciationInput: "sbꜣ nfr",
    displayName: "sbꜣ nfr",
    meaning: "The Beautiful Star",
    egyptologicalSpokenForm: "SEH-bah NEH-fer",
    ipa: "ˈsɛ.bɑ ˈnɛ.fɛɹ",
    readerRespelling: "SEH-bah NEH-fer",
    sourceNotes: [
      "User-authorized implementation: preserve visible spelling and gloss; source differences are content-audit notes, not playback gates. Read compositionally under Allen \u00a72.6. Offline voice produces replaceable first-pass audio, not verified ancient vowels.",
      ...pronunciationConvention,
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Faulkner ꜥḥꜣ fight/warrior PDF p.74; nfr beautiful PDF p.180; sbꜣ PDF p.288.",
      "Source review accepted under the user's conditional approval: apply Allen §2.6 to the retained product consonants (or the explicitly cited birthday/restoration input). Syllables/stress apply that convention; they are not name-specific quotations. Visible app names and spellings must remain unchanged. Recording/voice audition remains unapproved.",
    ],
    reviewIssues: [],
  ),
  PronunciationRecord(
    key: PronunciationKey.decan(3, 1),
    approvedTextHash:
        '1505b1168d29950caee8c2dd91584e7042582ef730911685d3ef7cc85de6bd62',
    writtenTransliteration: "sꜣḥ",
    pronunciationInput: "sꜣḥ",
    displayName: "sꜣḥ",
    meaning: "Sah",
    egyptologicalSpokenForm: "SAH",
    ipa: "sɑh",
    readerRespelling: "SAH",
    sourceNotes: [
      "User-authorized implementation: preserve visible spelling and gloss; source differences are content-audit notes, not playback gates. Read compositionally under Allen \u00a72.6. Offline voice produces replaceable first-pass audio, not verified ancient vowels.",
      ...pronunciationConvention,
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Faulkner sꜣḥ constellation Orion PDF p.278; sbꜣ PDF p.288.",
      "Source review accepted under the user's conditional approval: apply Allen §2.6 to the retained product consonants (or the explicitly cited birthday/restoration input). Syllables/stress apply that convention; they are not name-specific quotations. Visible app names and spellings must remain unchanged. Recording/voice audition remains unapproved.",
    ],
    reviewIssues: [],
  ),
  PronunciationRecord(
    key: PronunciationKey.decan(3, 2),
    approvedTextHash:
        'da1bf79ce40abf232f911d669e4a08dd7f129683684eb824be791cd56fd7db9c',
    writtenTransliteration: "ḥry-ib sꜣḥ",
    pronunciationInput: "ḥry-jb sꜣḥ",
    displayName: "ḥry-ib sꜣḥ",
    meaning: "Heart of Sah",
    egyptologicalSpokenForm: "HEH-ree EEB SAH",
    ipa: "ˈhɛ.ɹi ib sɑh",
    readerRespelling: "HEH-ree EEB SAH",
    sourceNotes: [
      "User-authorized implementation: preserve visible spelling and gloss; source differences are content-audit notes, not playback gates. Read compositionally under Allen \u00a72.6. Offline voice produces replaceable first-pass audio, not verified ancient vowels.",
      ...pronunciationConvention,
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Faulkner sꜣḥ constellation Orion PDF p.278; sbꜣ PDF p.288.",
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Faulkner ḥr(y)-ib PDF p.232: which is in the middle/midst; re-derived as ḥry + jb, not Hree-ib.",
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Product ib uses the British i convention for Allen j: Allen §2.3 PDF p.28. This row explicitly maps ib to jb; it is not a global letter substitution.",
      "Source review accepted under the user's conditional approval: apply Allen §2.6 to the retained product consonants (or the explicitly cited birthday/restoration input). Syllables/stress apply that convention; they are not name-specific quotations. Visible app names and spellings must remain unchanged. Recording/voice audition remains unapproved.",
    ],
    reviewIssues: [],
  ),
  PronunciationRecord(
    key: PronunciationKey.decan(3, 3),
    approvedTextHash:
        '8779a5a4aea8a13053308560b685b6fc38518849d066a517495aaeb647e3ba7d',
    writtenTransliteration: "sbꜣ sꜣḥ",
    pronunciationInput: "sbꜣ sꜣḥ",
    displayName: "sbꜣ sꜣḥ",
    meaning: "Star of Sah",
    egyptologicalSpokenForm: "SEH-bah SAH",
    ipa: "ˈsɛ.bɑ sɑh",
    readerRespelling: "SEH-bah SAH",
    sourceNotes: [
      "User-authorized implementation: preserve visible spelling and gloss; source differences are content-audit notes, not playback gates. Read compositionally under Allen \u00a72.6. Offline voice produces replaceable first-pass audio, not verified ancient vowels.",
      ...pronunciationConvention,
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Faulkner sꜣḥ constellation Orion PDF p.278; sbꜣ PDF p.288.",
      "Source review accepted under the user's conditional approval: apply Allen §2.6 to the retained product consonants (or the explicitly cited birthday/restoration input). Syllables/stress apply that convention; they are not name-specific quotations. Visible app names and spellings must remain unchanged. Recording/voice audition remains unapproved.",
    ],
    reviewIssues: [],
  ),
  PronunciationRecord(
    key: PronunciationKey.decan(4, 1),
    approvedTextHash:
        'b0b9226f86325f02e90f465667d76ab5c6ef9721b203816c7c84f4fdb02fed27',
    writtenTransliteration: "msḥtjw",
    pronunciationInput: "msḥtjw",
    displayName: "msḥtjw",
    meaning: "The Foreleg",
    egyptologicalSpokenForm: "MES-heh-tee-oo",
    ipa: "ˈmɛs.hɛ.ti.u",
    readerRespelling: "MES-heh-tee-oo",
    sourceNotes: [
      "User-authorized implementation: preserve visible spelling and gloss; source differences are content-audit notes, not playback gates. Read compositionally under Allen \u00a72.6. Offline voice produces replaceable first-pass audio, not verified ancient vowels.",
      "Prior review concerns retained for content audit: _stressReview,\n      \"Product msḥtjw differs from msḫtyw; do not silently identify it with the Foreleg/Plough. Gloss unresolved.\",",
      ...pronunciationConvention,
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Faulkner msḫtyw constellation of the Plough and msḥ crocodile PDF p.163.",
    ],
    reviewIssues: [],
  ),
  PronunciationRecord(
    key: PronunciationKey.decan(4, 2),
    approvedTextHash:
        '61f4be3ec071d69b9da13bd45797cad24f07bc90eff620c9760613e6f1f5b7ed',
    writtenTransliteration: "ḥry-ib msḥtjw",
    pronunciationInput: "ḥry-jb msḥtjw",
    displayName: "ḥry-ib msḥtjw",
    meaning: "Heart of the Foreleg",
    egyptologicalSpokenForm: "HEH-ree EEB MES-heh-tee-oo",
    ipa: "ˈhɛ.ɹi ib ˈmɛs.hɛ.ti.u",
    readerRespelling: "HEH-ree EEB MES-heh-tee-oo",
    sourceNotes: [
      "User-authorized implementation: preserve visible spelling and gloss; source differences are content-audit notes, not playback gates. Read compositionally under Allen \u00a72.6. Offline voice produces replaceable first-pass audio, not verified ancient vowels.",
      "Prior review concerns retained for content audit: _stressReview,\n      \"Product msḥtjw differs from msḫtyw; do not silently identify it with the Foreleg/Plough. Gloss unresolved.\",",
      ...pronunciationConvention,
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Faulkner msḫtyw constellation of the Plough and msḥ crocodile PDF p.163.",
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Faulkner ḥr(y)-ib PDF p.232: which is in the middle/midst; re-derived as ḥry + jb, not Hree-ib.",
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Product ib uses the British i convention for Allen j: Allen §2.3 PDF p.28. This row explicitly maps ib to jb; it is not a global letter substitution.",
    ],
    reviewIssues: [],
  ),
  PronunciationRecord(
    key: PronunciationKey.decan(4, 3),
    approvedTextHash:
        'f8d6e32b984d187a768f4be8a97c82934b47e714a4a7c85cda913af6dbabb478',
    writtenTransliteration: "sbꜣ msḥtjw",
    pronunciationInput: "sbꜣ msḥtjw",
    displayName: "sbꜣ msḥtjw",
    meaning: "Star of the Foreleg",
    egyptologicalSpokenForm: "SEH-bah MES-heh-tee-oo",
    ipa: "ˈsɛ.bɑ ˈmɛs.hɛ.ti.u",
    readerRespelling: "SEH-bah MES-heh-tee-oo",
    sourceNotes: [
      "User-authorized implementation: preserve visible spelling and gloss; source differences are content-audit notes, not playback gates. Read compositionally under Allen \u00a72.6. Offline voice produces replaceable first-pass audio, not verified ancient vowels.",
      "Prior review concerns retained for content audit: _stressReview,\n      \"Product msḥtjw differs from msḫtyw; do not silently identify it with the Foreleg/Plough. Gloss unresolved.\",",
      ...pronunciationConvention,
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Faulkner msḫtyw constellation of the Plough and msḥ crocodile PDF p.163.",
    ],
    reviewIssues: [],
  ),
  PronunciationRecord(
    key: PronunciationKey.decan(5, 1),
    approvedTextHash:
        '0d76d1d693a4a4207ddfaba6eae9653174c2e192684e1cb18efc9ce4ee45c58c',
    writtenTransliteration: "ḫnty-ḥr",
    pronunciationInput: "ḫnty-ḥr",
    displayName: "ḫnty-ḥr",
    meaning: "Foremost of the Sky",
    egyptologicalSpokenForm: "KHEN-tee HER",
    ipa: "ˈxɛn.ti hɛɹ",
    readerRespelling: "KHEN-tee HER",
    sourceNotes: [
      "User-authorized implementation: preserve visible spelling and gloss; source differences are content-audit notes, not playback gates. Read compositionally under Allen \u00a72.6. Offline voice produces replaceable first-pass audio, not verified ancient vowels.",
      "Prior review concerns retained for content audit: _stressReview,\n      \"Foremost of the Sky is not established for ḫnty-ḥr; full compound identity/gloss unresolved.\",",
      ...pronunciationConvention,
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Faulkner ḫnty foremost PDF p.255; ḥr/Ḥr entries PDF p.231.",
    ],
    reviewIssues: [],
  ),
  PronunciationRecord(
    key: PronunciationKey.decan(5, 2),
    approvedTextHash:
        '55fe172eb66ace9563dcfd89550bb74c4ad8f37a559de1a6bbf42cd4573859f2',
    writtenTransliteration: "ḥry-ib ḫnty-ḥr",
    pronunciationInput: "ḥry-jb ḫnty-ḥr",
    displayName: "ḥry-ib ḫnty-ḥr",
    meaning: "Heart of the Foremost",
    egyptologicalSpokenForm: "HEH-ree EEB KHEN-tee HER",
    ipa: "ˈhɛ.ɹi ib ˈxɛn.ti hɛɹ",
    readerRespelling: "HEH-ree EEB KHEN-tee HER",
    sourceNotes: [
      "User-authorized implementation: preserve visible spelling and gloss; source differences are content-audit notes, not playback gates. Read compositionally under Allen \u00a72.6. Offline voice produces replaceable first-pass audio, not verified ancient vowels.",
      "Prior review concerns retained for content audit: _stressReview,\n      \"Foremost of the Sky is not established for ḫnty-ḥr; full compound identity/gloss unresolved.\",",
      ...pronunciationConvention,
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Faulkner ḫnty foremost PDF p.255; ḥr/Ḥr entries PDF p.231.",
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Faulkner ḥr(y)-ib PDF p.232: which is in the middle/midst; re-derived as ḥry + jb, not Hree-ib.",
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Product ib uses the British i convention for Allen j: Allen §2.3 PDF p.28. This row explicitly maps ib to jb; it is not a global letter substitution.",
    ],
    reviewIssues: [],
  ),
  PronunciationRecord(
    key: PronunciationKey.decan(5, 3),
    approvedTextHash:
        'fae8034b3a8a84262e8635edbb4b7863eea48fae6959131784c6a8601a4bc3df',
    writtenTransliteration: "sbꜣ ḫnty-ḥr",
    pronunciationInput: "sbꜣ ḫnty-ḥr",
    displayName: "sbꜣ ḫnty-ḥr",
    meaning: "Star of the Foremost",
    egyptologicalSpokenForm: "SEH-bah KHEN-tee HER",
    ipa: "ˈsɛ.bɑ ˈxɛn.ti hɛɹ",
    readerRespelling: "SEH-bah KHEN-tee HER",
    sourceNotes: [
      "User-authorized implementation: preserve visible spelling and gloss; source differences are content-audit notes, not playback gates. Read compositionally under Allen \u00a72.6. Offline voice produces replaceable first-pass audio, not verified ancient vowels.",
      "Prior review concerns retained for content audit: _stressReview,\n      \"Foremost of the Sky is not established for ḫnty-ḥr; full compound identity/gloss unresolved.\",",
      ...pronunciationConvention,
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Faulkner ḫnty foremost PDF p.255; ḥr/Ḥr entries PDF p.231.",
    ],
    reviewIssues: [],
  ),
  PronunciationRecord(
    key: PronunciationKey.decan(6, 1),
    approvedTextHash:
        '88b713ccc2b5088f7dcb6d83663df5bbc1ddbe44cce970936c3791c3618edb6f',
    writtenTransliteration: "knmw",
    pronunciationInput: "ẖnmw",
    displayName: "knmw",
    meaning: "Khnum",
    egyptologicalSpokenForm: "KHYEH-nem-oo",
    ipa: "ˈxjɛ.nɛm.u",
    readerRespelling: "KHYEH-nem-oo",
    sourceNotes: [
      "User-authorized implementation: preserve visible spelling and gloss; source differences are content-audit notes, not playback gates. Read compositionally under Allen \u00a72.6. Offline voice produces replaceable first-pass audio, not verified ancient vowels.",
      "Prior review concerns retained for content audit: _stressReview,\n      \"No cited identification of product knmw with ẖnmw. All three month-6 decans remain distinct from Khnum; gloss unresolved.\",",
      ...pronunciationConvention,
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Faulkner ẖnmw Khnum PDF p.267; knm/knmt/knmtyw entries PDF p.368.",
    ],
    reviewIssues: [],
  ),
  PronunciationRecord(
    key: PronunciationKey.decan(6, 2),
    approvedTextHash:
        '9b1c1e2eff13eb30774c6c9efb66c9e116fe871e6fc32aa4f9ae30a1320f0e9f',
    writtenTransliteration: "ḥry-ib knmw",
    pronunciationInput: "ḥry-jb ẖnmw",
    displayName: "ḥry-ib knmw",
    meaning: "Heart of Khnum",
    egyptologicalSpokenForm: "HEH-ree EEB KHYEH-nem-oo",
    ipa: "ˈhɛ.ɹi ib ˈxjɛ.nɛm.u",
    readerRespelling: "HEH-ree EEB KHYEH-nem-oo",
    sourceNotes: [
      "User-authorized implementation: preserve visible spelling and gloss; source differences are content-audit notes, not playback gates. Read compositionally under Allen \u00a72.6. Offline voice produces replaceable first-pass audio, not verified ancient vowels.",
      "Prior review concerns retained for content audit: _stressReview,\n      \"No cited identification of product knmw with ẖnmw. All three month-6 decans remain distinct from Khnum; gloss unresolved.\",",
      ...pronunciationConvention,
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Faulkner ẖnmw Khnum PDF p.267; knm/knmt/knmtyw entries PDF p.368.",
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Faulkner ḥr(y)-ib PDF p.232: which is in the middle/midst; re-derived as ḥry + jb, not Hree-ib.",
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Product ib uses the British i convention for Allen j: Allen §2.3 PDF p.28. This row explicitly maps ib to jb; it is not a global letter substitution.",
    ],
    reviewIssues: [],
  ),
  PronunciationRecord(
    key: PronunciationKey.decan(6, 3),
    approvedTextHash:
        'b8f1adfdd49c4b465a7fc4d2b1861408fe369b28b49c38446c04d324ad4bb2d1',
    writtenTransliteration: "sbꜣ knmw",
    pronunciationInput: "sbꜣ ẖnmw",
    displayName: "sbꜣ knmw",
    meaning: "Star of Khnum",
    egyptologicalSpokenForm: "SEH-bah KHYEH-nem-oo",
    ipa: "ˈsɛ.bɑ ˈxjɛ.nɛm.u",
    readerRespelling: "SEH-bah KHYEH-nem-oo",
    sourceNotes: [
      "User-authorized implementation: preserve visible spelling and gloss; source differences are content-audit notes, not playback gates. Read compositionally under Allen \u00a72.6. Offline voice produces replaceable first-pass audio, not verified ancient vowels.",
      "Prior review concerns retained for content audit: _stressReview,\n      \"No cited identification of product knmw with ẖnmw. All three month-6 decans remain distinct from Khnum; gloss unresolved.\",",
      ...pronunciationConvention,
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Faulkner ẖnmw Khnum PDF p.267; knm/knmt/knmtyw entries PDF p.368.",
    ],
    reviewIssues: [],
  ),
  PronunciationRecord(
    key: PronunciationKey.decan(7, 1),
    approvedTextHash:
        '0d5cc81b71f9ab8e0244fb5f62146682605e61ed3cf6962b7b8ae1487a7a9a1e',
    writtenTransliteration: "špsswt",
    pronunciationInput: "špsswt",
    displayName: "špsswt",
    meaning: "The Noble Ones",
    egyptologicalSpokenForm: "SHEP-ses-oot",
    ipa: "ˈʃɛp.sɛs.ut",
    readerRespelling: "SHEP-ses-oot",
    sourceNotes: [
      "User-authorized implementation: preserve visible spelling and gloss; source differences are content-audit notes, not playback gates. Read compositionally under Allen \u00a72.6. Offline voice produces replaceable first-pass audio, not verified ancient vowels.",
      "Prior review concerns retained for content audit: _stressReview,\n      \"Product špsswt morphology and The Noble Ones gloss require review; no silent removal of t.\",",
      ...pronunciationConvention,
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Faulkner špss noble/august and špssw riches PDF p.341.",
    ],
    reviewIssues: [],
  ),
  PronunciationRecord(
    key: PronunciationKey.decan(7, 2),
    approvedTextHash:
        'e9625910971883fab07389da7476611faf63e986dcd9fed47b319188dd71e96d',
    writtenTransliteration: "ḥry-ib špsswt",
    pronunciationInput: "ḥry-jb špsswt",
    displayName: "ḥry-ib špsswt",
    meaning: "Heart of the Noble Ones",
    egyptologicalSpokenForm: "HEH-ree EEB SHEP-ses-oot",
    ipa: "ˈhɛ.ɹi ib ˈʃɛp.sɛs.ut",
    readerRespelling: "HEH-ree EEB SHEP-ses-oot",
    sourceNotes: [
      "User-authorized implementation: preserve visible spelling and gloss; source differences are content-audit notes, not playback gates. Read compositionally under Allen \u00a72.6. Offline voice produces replaceable first-pass audio, not verified ancient vowels.",
      "Prior review concerns retained for content audit: _stressReview,\n      \"Product špsswt morphology and The Noble Ones gloss require review; no silent removal of t.\",",
      ...pronunciationConvention,
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Faulkner špss noble/august and špssw riches PDF p.341.",
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Faulkner ḥr(y)-ib PDF p.232: which is in the middle/midst; re-derived as ḥry + jb, not Hree-ib.",
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Product ib uses the British i convention for Allen j: Allen §2.3 PDF p.28. This row explicitly maps ib to jb; it is not a global letter substitution.",
    ],
    reviewIssues: [],
  ),
  PronunciationRecord(
    key: PronunciationKey.decan(7, 3),
    approvedTextHash:
        'bcdfc5d19ed361bf05c36185bc87b4360e7ee4da951ff8780458a7f6b332c6f5',
    writtenTransliteration: "sbꜣ špsswt",
    pronunciationInput: "sbꜣ špsswt",
    displayName: "sbꜣ špsswt",
    meaning: "Star of the Noble Ones",
    egyptologicalSpokenForm: "SEH-bah SHEP-ses-oot",
    ipa: "ˈsɛ.bɑ ˈʃɛp.sɛs.ut",
    readerRespelling: "SEH-bah SHEP-ses-oot",
    sourceNotes: [
      "User-authorized implementation: preserve visible spelling and gloss; source differences are content-audit notes, not playback gates. Read compositionally under Allen \u00a72.6. Offline voice produces replaceable first-pass audio, not verified ancient vowels.",
      "Prior review concerns retained for content audit: _stressReview,\n      \"Product špsswt morphology and The Noble Ones gloss require review; no silent removal of t.\",",
      ...pronunciationConvention,
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Faulkner špss noble/august and špssw riches PDF p.341.",
    ],
    reviewIssues: [],
  ),
  PronunciationRecord(
    key: PronunciationKey.decan(8, 1),
    approvedTextHash:
        'b715be4a45318a5546bef80110ec82fb3e1f81c223dd734cede087b73e586294',
    writtenTransliteration: "ꜥpdw",
    pronunciationInput: "ꜥpdw",
    displayName: "ꜥpdw",
    meaning: "The Birds",
    egyptologicalSpokenForm: "AH-ped-oo",
    ipa: "ˈɑ.pɛd.u",
    readerRespelling: "AH-ped-oo",
    sourceNotes: [
      "User-authorized implementation: preserve visible spelling and gloss; source differences are content-audit notes, not playback gates. Read compositionally under Allen \u00a72.6. Offline voice produces replaceable first-pass audio, not verified ancient vowels.",
      "Prior review concerns retained for content audit: _stressReview,\n      \"Product ꜥpdw starts with ayin; dictionary bird headword starts with aleph. Do not silently identify them; gloss unresolved.\",",
      ...pronunciationConvention,
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Faulkner ꜣpd bird PDF p.20.",
    ],
    reviewIssues: [],
  ),
  PronunciationRecord(
    key: PronunciationKey.decan(8, 2),
    approvedTextHash:
        'bdb023750d185416c790fed8a97a937f38bd31b7d643c3be2f0cc5af2374a075',
    writtenTransliteration: "ḥry-ib ꜥpdw",
    pronunciationInput: "ḥry-jb ꜥpdw",
    displayName: "ḥry-ib ꜥpdw",
    meaning: "Heart of the Birds",
    egyptologicalSpokenForm: "HEH-ree EEB AH-ped-oo",
    ipa: "ˈhɛ.ɹi ib ˈɑ.pɛd.u",
    readerRespelling: "HEH-ree EEB AH-ped-oo",
    sourceNotes: [
      "User-authorized implementation: preserve visible spelling and gloss; source differences are content-audit notes, not playback gates. Read compositionally under Allen \u00a72.6. Offline voice produces replaceable first-pass audio, not verified ancient vowels.",
      "Prior review concerns retained for content audit: _stressReview,\n      \"Product ꜥpdw starts with ayin; dictionary bird headword starts with aleph. Do not silently identify them; gloss unresolved.\",",
      ...pronunciationConvention,
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Faulkner ꜣpd bird PDF p.20.",
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Faulkner ḥr(y)-ib PDF p.232: which is in the middle/midst; re-derived as ḥry + jb, not Hree-ib.",
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Product ib uses the British i convention for Allen j: Allen §2.3 PDF p.28. This row explicitly maps ib to jb; it is not a global letter substitution.",
    ],
    reviewIssues: [],
  ),
  PronunciationRecord(
    key: PronunciationKey.decan(8, 3),
    approvedTextHash:
        '16bb75ce8cf5ac6f561091bf16e9d91006efad7a5950992ff1f3016e4d98d1b8',
    writtenTransliteration: "sbꜣ ꜥpdw",
    pronunciationInput: "sbꜣ ꜥpdw",
    displayName: "sbꜣ ꜥpdw",
    meaning: "Star of the Birds",
    egyptologicalSpokenForm: "SEH-bah AH-ped-oo",
    ipa: "ˈsɛ.bɑ ˈɑ.pɛd.u",
    readerRespelling: "SEH-bah AH-ped-oo",
    sourceNotes: [
      "User-authorized implementation: preserve visible spelling and gloss; source differences are content-audit notes, not playback gates. Read compositionally under Allen \u00a72.6. Offline voice produces replaceable first-pass audio, not verified ancient vowels.",
      "Prior review concerns retained for content audit: _stressReview,\n      \"Product ꜥpdw starts with ayin; dictionary bird headword starts with aleph. Do not silently identify them; gloss unresolved.\",",
      ...pronunciationConvention,
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Faulkner ꜣpd bird PDF p.20.",
    ],
    reviewIssues: [],
  ),
  PronunciationRecord(
    key: PronunciationKey.decan(9, 1),
    approvedTextHash:
        'f22118a5a6c683592dd9fc318abb55a1d340b8d511889cfbb0eb6105fdcc779d',
    writtenTransliteration: "ẖry ꜥrt",
    pronunciationInput: "ẖry ꜥrt",
    displayName: "ẖry ꜥrt",
    meaning: "The One Beneath ꜥrt",
    egyptologicalSpokenForm: "KHYEH-ree AH-ret",
    ipa: "ˈxjɛ.ɹi ˈɑ.ɹɛt",
    readerRespelling: "KHYEH-ree AH-ret",
    sourceNotes: [
      "User-authorized implementation: preserve visible spelling and gloss; source differences are content-audit notes, not playback gates. Read compositionally under Allen \u00a72.6. Offline voice produces replaceable first-pass audio, not verified ancient vowels.",
      "Prior review concerns retained for content audit: _stressReview,\n      \"ꜥrt identity unresolved in the first record. For the others, review the compound rather than assuming a historical decan identification.\",",
      ...pronunciationConvention,
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Faulkner ẖry which is under PDF p.267; ḥry upper PDF p.232; rmn shoulder/side PDF p.202; sꜣḥ Orion PDF p.278.",
    ],
    reviewIssues: [],
  ),
  PronunciationRecord(
    key: PronunciationKey.decan(9, 2),
    approvedTextHash:
        'e3e5e84630e49967f4ae9f59c84e20fa18a83198c4b94d05ad3cbc6f07e756a6',
    writtenTransliteration: "rmn ḥry sꜣḥ",
    pronunciationInput: "rmn ḥry sꜣḥ",
    displayName: "rmn ḥry sꜣḥ",
    meaning: "Shoulder Above Sah",
    egyptologicalSpokenForm: "REH-men HEH-ree SAH",
    ipa: "ˈɹɛ.mɛn ˈhɛ.ɹi sɑh",
    readerRespelling: "REH-men HEH-ree SAH",
    sourceNotes: [
      "User-authorized implementation: preserve visible spelling and gloss; source differences are content-audit notes, not playback gates. Read compositionally under Allen \u00a72.6. Offline voice produces replaceable first-pass audio, not verified ancient vowels.",
      ...pronunciationConvention,
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Faulkner ẖry which is under PDF p.267; ḥry upper PDF p.232; rmn shoulder/side PDF p.202; sꜣḥ Orion PDF p.278.",
      "Source review accepted under the user's conditional approval: apply Allen §2.6 to the retained product consonants (or the explicitly cited birthday/restoration input). Syllables/stress apply that convention; they are not name-specific quotations. Visible app names and spellings must remain unchanged. Recording/voice audition remains unapproved.",
    ],
    reviewIssues: [],
  ),
  PronunciationRecord(
    key: PronunciationKey.decan(9, 3),
    approvedTextHash:
        'a2875203c3cd69419aa82f7381f1a03bc93b2812a5edc030d6103b0a3146aa71',
    writtenTransliteration: "rmn ẖry sꜣḥ",
    pronunciationInput: "rmn ẖry sꜣḥ",
    displayName: "rmn ẖry sꜣḥ",
    meaning: "Shoulder Beneath Sah",
    egyptologicalSpokenForm: "REH-men KHYEH-ree SAH",
    ipa: "ˈɹɛ.mɛn ˈxjɛ.ɹi sɑh",
    readerRespelling: "REH-men KHYEH-ree SAH",
    sourceNotes: [
      "User-authorized implementation: preserve visible spelling and gloss; source differences are content-audit notes, not playback gates. Read compositionally under Allen \u00a72.6. Offline voice produces replaceable first-pass audio, not verified ancient vowels.",
      ...pronunciationConvention,
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Faulkner ẖry which is under PDF p.267; ḥry upper PDF p.232; rmn shoulder/side PDF p.202; sꜣḥ Orion PDF p.278.",
      "Source review accepted under the user's conditional approval: apply Allen §2.6 to the retained product consonants (or the explicitly cited birthday/restoration input). Syllables/stress apply that convention; they are not name-specific quotations. Visible app names and spellings must remain unchanged. Recording/voice audition remains unapproved.",
    ],
    reviewIssues: [],
  ),
  PronunciationRecord(
    key: PronunciationKey.decan(10, 1),
    approvedTextHash:
        '07f00567f4f5da9b5b167e2a98a0852f8dfea6f37e008388cf647ca21802a750',
    writtenTransliteration: "ḥr-sꜣḥ",
    pronunciationInput: "ḥr-sꜣḥ",
    displayName: "ḥr-sꜣḥ",
    meaning: "Heru upon Sah",
    egyptologicalSpokenForm: "HER SAH",
    ipa: "hɛɹ sɑh",
    readerRespelling: "HER SAH",
    sourceNotes: [
      "User-authorized implementation: preserve visible spelling and gloss; source differences are content-audit notes, not playback gates. Read compositionally under Allen \u00a72.6. Offline voice produces replaceable first-pass audio, not verified ancient vowels.",
      "Prior review concerns retained for content audit: _stressReview,\n      \"Heru upon Sah is not established by the product consonants alone; compound identity/gloss unresolved.\",",
      ...pronunciationConvention,
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Faulkner ḥr/Ḥr PDF p.231; sꜣḥ Orion PDF p.278.",
    ],
    reviewIssues: [],
  ),
  PronunciationRecord(
    key: PronunciationKey.decan(10, 2),
    approvedTextHash:
        'e3aba35cda7722fa3c0e02d987c8f8fa8ef0f9312ff5454c8f5f02d96a663545',
    writtenTransliteration: "ḥry-ib ḥr-sꜣḥ",
    pronunciationInput: "ḥry-jb ḥr-sꜣḥ",
    displayName: "ḥry-ib ḥr-sꜣḥ",
    meaning: "Heart of Heru upon Sah",
    egyptologicalSpokenForm: "HEH-ree EEB HER SAH",
    ipa: "ˈhɛ.ɹi ib hɛɹ sɑh",
    readerRespelling: "HEH-ree EEB HER SAH",
    sourceNotes: [
      "User-authorized implementation: preserve visible spelling and gloss; source differences are content-audit notes, not playback gates. Read compositionally under Allen \u00a72.6. Offline voice produces replaceable first-pass audio, not verified ancient vowels.",
      "Prior review concerns retained for content audit: _stressReview,\n      \"Heru upon Sah is not established by the product consonants alone; compound identity/gloss unresolved.\",",
      ...pronunciationConvention,
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Faulkner ḥr/Ḥr PDF p.231; sꜣḥ Orion PDF p.278.",
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Faulkner ḥr(y)-ib PDF p.232: which is in the middle/midst; re-derived as ḥry + jb, not Hree-ib.",
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Product ib uses the British i convention for Allen j: Allen §2.3 PDF p.28. This row explicitly maps ib to jb; it is not a global letter substitution.",
    ],
    reviewIssues: [],
  ),
  PronunciationRecord(
    key: PronunciationKey.decan(10, 3),
    approvedTextHash:
        '1991d09f248ea451886fd8736dc9c63d8ec3dbe17a75f27aa7eec2fa4faf2ac8',
    writtenTransliteration: "sbꜣ ḥr-sꜣḥ",
    pronunciationInput: "sbꜣ ḥr-sꜣḥ",
    displayName: "sbꜣ ḥr-sꜣḥ",
    meaning: "Star of Heru upon Sah",
    egyptologicalSpokenForm: "SEH-bah HER SAH",
    ipa: "ˈsɛ.bɑ hɛɹ sɑh",
    readerRespelling: "SEH-bah HER SAH",
    sourceNotes: [
      "User-authorized implementation: preserve visible spelling and gloss; source differences are content-audit notes, not playback gates. Read compositionally under Allen \u00a72.6. Offline voice produces replaceable first-pass audio, not verified ancient vowels.",
      "Prior review concerns retained for content audit: _stressReview,\n      \"Heru upon Sah is not established by the product consonants alone; compound identity/gloss unresolved.\",",
      ...pronunciationConvention,
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Faulkner ḥr/Ḥr PDF p.231; sꜣḥ Orion PDF p.278.",
    ],
    reviewIssues: [],
  ),
  PronunciationRecord(
    key: PronunciationKey.decan(11, 1),
    approvedTextHash:
        'c5be3a3bfa5846434384335e4960f32d772c2a7aa8f5c282d6374deb22bc059c',
    writtenTransliteration: "sbꜣ nfr",
    pronunciationInput: "sbꜣ nfr",
    displayName: "sbꜣ nfr",
    meaning: "The Beautiful Star",
    egyptologicalSpokenForm: "SEH-bah NEH-fer",
    ipa: "ˈsɛ.bɑ ˈnɛ.fɛɹ",
    readerRespelling: "SEH-bah NEH-fer",
    sourceNotes: [
      "User-authorized implementation: preserve visible spelling and gloss; source differences are content-audit notes, not playback gates. Read compositionally under Allen \u00a72.6. Offline voice produces replaceable first-pass audio, not verified ancient vowels.",
      ...pronunciationConvention,
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Faulkner sbꜣ star PDF p.288 and nfr beautiful PDF p.180.",
      "Source review accepted under the user's conditional approval: apply Allen §2.6 to the retained product consonants (or the explicitly cited birthday/restoration input). Syllables/stress apply that convention; they are not name-specific quotations. Visible app names and spellings must remain unchanged. Recording/voice audition remains unapproved.",
    ],
    reviewIssues: [],
  ),
  PronunciationRecord(
    key: PronunciationKey.decan(11, 2),
    approvedTextHash:
        'a03c4a5296a67177147676a3f610d5631b334967de177822c12c30b5e57cbb81',
    writtenTransliteration: "ḥry-ib sbꜣ nfr",
    pronunciationInput: "ḥry-jb sbꜣ nfr",
    displayName: "ḥry-ib sbꜣ nfr",
    meaning: "Heart of the Beautiful Star",
    egyptologicalSpokenForm: "HEH-ree EEB SEH-bah NEH-fer",
    ipa: "ˈhɛ.ɹi ib ˈsɛ.bɑ ˈnɛ.fɛɹ",
    readerRespelling: "HEH-ree EEB SEH-bah NEH-fer",
    sourceNotes: [
      "User-authorized implementation: preserve visible spelling and gloss; source differences are content-audit notes, not playback gates. Read compositionally under Allen \u00a72.6. Offline voice produces replaceable first-pass audio, not verified ancient vowels.",
      ...pronunciationConvention,
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Faulkner sbꜣ star PDF p.288 and nfr beautiful PDF p.180.",
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Faulkner ḥr(y)-ib PDF p.232: which is in the middle/midst; re-derived as ḥry + jb, not Hree-ib.",
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Product ib uses the British i convention for Allen j: Allen §2.3 PDF p.28. This row explicitly maps ib to jb; it is not a global letter substitution.",
      "Source review accepted under the user's conditional approval: apply Allen §2.6 to the retained product consonants (or the explicitly cited birthday/restoration input). Syllables/stress apply that convention; they are not name-specific quotations. Visible app names and spellings must remain unchanged. Recording/voice audition remains unapproved.",
    ],
    reviewIssues: [],
  ),
  PronunciationRecord(
    key: PronunciationKey.decan(11, 3),
    approvedTextHash:
        'c458ff7024fbda9b1bbe7c190f6c5dd04f3763262720038ad552efc3d58dce02',
    writtenTransliteration: "sbꜣ sbꜣ nfr",
    pronunciationInput: "sbꜣ sbꜣ nfr",
    displayName: "sbꜣ sbꜣ nfr",
    meaning: "Star of the Beautiful Star",
    egyptologicalSpokenForm: "SEH-bah SEH-bah NEH-fer",
    ipa: "ˈsɛ.bɑ ˈsɛ.bɑ ˈnɛ.fɛɹ",
    readerRespelling: "SEH-bah SEH-bah NEH-fer",
    sourceNotes: [
      "User-authorized implementation: preserve visible spelling and gloss; source differences are content-audit notes, not playback gates. Read compositionally under Allen \u00a72.6. Offline voice produces replaceable first-pass audio, not verified ancient vowels.",
      ...pronunciationConvention,
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Faulkner sbꜣ star PDF p.288 and nfr beautiful PDF p.180.",
      "Source review accepted under the user's conditional approval: apply Allen §2.6 to the retained product consonants (or the explicitly cited birthday/restoration input). Syllables/stress apply that convention; they are not name-specific quotations. Visible app names and spellings must remain unchanged. Recording/voice audition remains unapproved.",
    ],
    reviewIssues: [],
  ),
  PronunciationRecord(
    key: PronunciationKey.decan(12, 1),
    approvedTextHash:
        '90176f1a7e850201750e0fb553058d9514d84234c90c8c42a8dbef1deeae237e',
    writtenTransliteration: "msḥtjw ḫt",
    pronunciationInput: "msḥtjw ḫt",
    displayName: "msḥtjw ḫt",
    meaning: "The Crocodiles of the Offering",
    egyptologicalSpokenForm: "MES-heh-tee-oo KHET",
    ipa: "ˈmɛs.hɛ.ti.u xɛt",
    readerRespelling: "MES-heh-tee-oo KHET",
    sourceNotes: [
      "User-authorized implementation: preserve visible spelling and gloss; source differences are content-audit notes, not playback gates. Read compositionally under Allen \u00a72.6. Offline voice produces replaceable first-pass audio, not verified ancient vowels.",
      "Prior review concerns retained for content audit: _stressReview,\n      \"The Crocodiles of the Offering is not verified for msḥtjw ḫt; do not choose among distinct headwords by resemblance. Gloss unresolved.\",",
      ...pronunciationConvention,
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Faulkner msḥ crocodile / msḫtyw Plough PDF p.163; ḫt fire/things/offerings entries PDF p.242 and wood/through entries PDF p.260.",
    ],
    reviewIssues: [],
  ),
  PronunciationRecord(
    key: PronunciationKey.decan(12, 2),
    approvedTextHash:
        '5b9d3a08214c0267bf84938a005ef9a564f73fe2f2d3d43f30bf39f7c7e7e531',
    writtenTransliteration: "ḥry-ib msḥtjw ḫt",
    pronunciationInput: "ḥry-jb msḥtjw ḫt",
    displayName: "ḥry-ib msḥtjw ḫt",
    meaning: "Heart of the Crocodiles of the Offering",
    egyptologicalSpokenForm: "HEH-ree EEB MES-heh-tee-oo KHET",
    ipa: "ˈhɛ.ɹi ib ˈmɛs.hɛ.ti.u xɛt",
    readerRespelling: "HEH-ree EEB MES-heh-tee-oo KHET",
    sourceNotes: [
      "User-authorized implementation: preserve visible spelling and gloss; source differences are content-audit notes, not playback gates. Read compositionally under Allen \u00a72.6. Offline voice produces replaceable first-pass audio, not verified ancient vowels.",
      "Prior review concerns retained for content audit: _stressReview,\n      \"The Crocodiles of the Offering is not verified for msḥtjw ḫt; do not choose among distinct headwords by resemblance. Gloss unresolved.\",",
      ...pronunciationConvention,
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Faulkner msḥ crocodile / msḫtyw Plough PDF p.163; ḫt fire/things/offerings entries PDF p.242 and wood/through entries PDF p.260.",
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Faulkner ḥr(y)-ib PDF p.232: which is in the middle/midst; re-derived as ḥry + jb, not Hree-ib.",
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Product ib uses the British i convention for Allen j: Allen §2.3 PDF p.28. This row explicitly maps ib to jb; it is not a global letter substitution.",
    ],
    reviewIssues: [],
  ),
  PronunciationRecord(
    key: PronunciationKey.decan(12, 3),
    approvedTextHash:
        '4a35b05c3d7cb379eae3e368fff86dc803c7e208b35f0e6a742bf6e92c2a6463',
    writtenTransliteration: "sbꜣ msḥtjw ḫt",
    pronunciationInput: "sbꜣ msḥtjw ḫt",
    displayName: "sbꜣ msḥtjw ḫt",
    meaning: "Star of the Crocodiles of the Offering",
    egyptologicalSpokenForm: "SEH-bah MES-heh-tee-oo KHET",
    ipa: "ˈsɛ.bɑ ˈmɛs.hɛ.ti.u xɛt",
    readerRespelling: "SEH-bah MES-heh-tee-oo KHET",
    sourceNotes: [
      "User-authorized implementation: preserve visible spelling and gloss; source differences are content-audit notes, not playback gates. Read compositionally under Allen \u00a72.6. Offline voice produces replaceable first-pass audio, not verified ancient vowels.",
      "Prior review concerns retained for content audit: _stressReview,\n      \"The Crocodiles of the Offering is not verified for msḥtjw ḫt; do not choose among distinct headwords by resemblance. Gloss unresolved.\",",
      ...pronunciationConvention,
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Faulkner msḥ crocodile / msḫtyw Plough PDF p.163; ḫt fire/things/offerings entries PDF p.242 and wood/through entries PDF p.260.",
    ],
    reviewIssues: [],
  ),
  PronunciationRecord(
    key: PronunciationKey.epagomenal(1),
    approvedTextHash:
        '0c22a7461361e240d6e84bcd4e6ae22390f40de65bd1e5ba338de7046b1b2a81',
    writtenTransliteration: null,
    pronunciationInput: "mswt jsjrt",
    displayName: "Birth of Asar",
    meaning: "Birth of Asar",
    egyptologicalSpokenForm: "MES-oot EE-see-ret",
    ipa: "ˈmɛs.ut ˈi.si.ɹɛt",
    readerRespelling: "MES-oot EE-see-ret",
    sourceNotes: [
      "User-authorized implementation: preserve visible spelling and gloss; source differences are content-audit notes, not playback gates. Read compositionally under Allen \u00a72.6. Offline voice produces replaceable first-pass audio, not verified ancient vowels.",
      ...pronunciationConvention,
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Allen §9.8 PDF p.120 lists all five birthday expressions in this order. Egyptian spellings are sourced from Allen; current birthday UI supplies no written transliteration. The English gloss uses the product deity name without a Greek alias.",
      "Source review accepted under the user's conditional approval: apply Allen §2.6 to the retained product consonants (or the explicitly cited birthday/restoration input). Syllables/stress apply that convention; they are not name-specific quotations. Visible app names and spellings must remain unchanged. Recording/voice audition remains unapproved. Allen §9.8 PDF p.120 identifies jsjrt as Osiris; the existing dropdown explicitly labels Asar (Osiris). Preserve both that label and other existing Wesir labels; this catalog must not rename either surface.",
    ],
    reviewIssues: [],
  ),
  PronunciationRecord(
    key: PronunciationKey.epagomenal(2),
    approvedTextHash:
        '07ff1b082f374b03aa748631cba2cbd134ecb90ef6c9ac965cf1e1d781cb750f',
    writtenTransliteration: null,
    pronunciationInput: "mswt ḥrw",
    displayName: "Birth of Heru-wer",
    meaning: "Birth of Heru-wer",
    egyptologicalSpokenForm: "MES-oot HEH-roo",
    ipa: "ˈmɛs.ut ˈhɛ.ɹu",
    readerRespelling: "MES-oot HEH-roo",
    sourceNotes: [
      "User-authorized implementation: preserve visible spelling and gloss; source differences are content-audit notes, not playback gates. Read compositionally under Allen \u00a72.6. Offline voice produces replaceable first-pass audio, not verified ancient vowels.",
      "Prior review concerns retained for content audit: _stressReview,\n      \"Allen has ḥrw (Horus), without wr (Elder); no unsourced wr is added. Approve the mapping to the product identity.\",",
      ...pronunciationConvention,
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Allen §9.8 PDF p.120 lists all five birthday expressions in this order. Egyptian spellings are sourced from Allen; current birthday UI supplies no written transliteration. The English gloss uses the product deity name without a Greek alias.",
    ],
    reviewIssues: [],
  ),
  PronunciationRecord(
    key: PronunciationKey.epagomenal(3),
    approvedTextHash:
        '47c1beb8a0931044801b3873b464a78a75d58762303517af55f4083ef7bb2998',
    writtenTransliteration: null,
    pronunciationInput: "mswt stẖ",
    displayName: "Birth of Set",
    meaning: "Birth of Set",
    egyptologicalSpokenForm: "MES-oot SEH-tekh-y",
    ipa: "ˈmɛs.ut ˈsɛ.tɛxj",
    readerRespelling: "MES-oot SEH-tekh-y",
    sourceNotes: [
      "User-authorized implementation: preserve visible spelling and gloss; source differences are content-audit notes, not playback gates. Read compositionally under Allen \u00a72.6. Offline voice produces replaceable first-pass audio, not verified ancient vowels.",
      ...pronunciationConvention,
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Allen §9.8 PDF p.120 lists all five birthday expressions in this order. Egyptian spellings are sourced from Allen; current birthday UI supplies no written transliteration. The English gloss uses the product deity name without a Greek alias.",
      "Source review accepted under the user's conditional approval: apply Allen §2.6 to the retained product consonants (or the explicitly cited birthday/restoration input). Syllables/stress apply that convention; they are not name-specific quotations. Visible app names and spellings must remain unchanged. Recording/voice audition remains unapproved. Apply short e between s/t and t/ẖ; retain final /xj/ from the ẖ convention. Audition must reject an unsupported or inaudible final consonant.",
    ],
    reviewIssues: [],
  ),
  PronunciationRecord(
    key: PronunciationKey.epagomenal(4),
    approvedTextHash:
        'cdb9566a0b60da15a68f736281b58c79615ad77c19633d65029ea062e553af05',
    writtenTransliteration: null,
    pronunciationInput: "mswt jst",
    displayName: "Birth of Aset",
    meaning: "Birth of Aset",
    egyptologicalSpokenForm: "MES-oot EE-set",
    ipa: "ˈmɛs.ut ˈi.sɛt",
    readerRespelling: "MES-oot EE-set",
    sourceNotes: [
      "User-authorized implementation: preserve visible spelling and gloss; source differences are content-audit notes, not playback gates. Read compositionally under Allen \u00a72.6. Offline voice produces replaceable first-pass audio, not verified ancient vowels.",
      ...pronunciationConvention,
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Allen §9.8 PDF p.120 lists all five birthday expressions in this order. Egyptian spellings are sourced from Allen; current birthday UI supplies no written transliteration. The English gloss uses the product deity name without a Greek alias.",
      "Source review accepted under the user's conditional approval: apply Allen §2.6 to the retained product consonants (or the explicitly cited birthday/restoration input). Syllables/stress apply that convention; they are not name-specific quotations. Visible app names and spellings must remain unchanged. Recording/voice audition remains unapproved.",
    ],
    reviewIssues: [],
  ),
  PronunciationRecord(
    key: PronunciationKey.epagomenal(5),
    approvedTextHash:
        '7803b32d38785be4ddfef647e8204f8989dddfdeca7ddd5e0cb40846de03389a',
    writtenTransliteration: null,
    pronunciationInput: "mswt nbt-ḥwt",
    displayName: "Birth of Nebet-Het",
    meaning: "Birth of Nebet-Het",
    egyptologicalSpokenForm: "MES-oot NEH-bet HOOT",
    ipa: "ˈmɛs.ut ˈnɛ.bɛt hut",
    readerRespelling: "MES-oot NEH-bet HOOT",
    sourceNotes: [
      "User-authorized implementation: preserve visible spelling and gloss; source differences are content-audit notes, not playback gates. Read compositionally under Allen \u00a72.6. Offline voice produces replaceable first-pass audio, not verified ancient vowels.",
      ...pronunciationConvention,
      "Sources: James P. Allen, Middle Egyptian, 2nd ed. revised (2010); Raymond O. Faulkner, A Concise Dictionary of Middle Egyptian, modernization by Boris Jegorović (2017). Allen §9.8 PDF p.120 lists all five birthday expressions in this order. Egyptian spellings are sourced from Allen; current birthday UI supplies no written transliteration. The English gloss uses the product deity name without a Greek alias.",
      "Source review accepted under the user's conditional approval: apply Allen §2.6 to the retained product consonants (or the explicitly cited birthday/restoration input). Syllables/stress apply that convention; they are not name-specific quotations. Visible app names and spellings must remain unchanged. Recording/voice audition remains unapproved.",
    ],
    reviewIssues: [],
  ),
];
