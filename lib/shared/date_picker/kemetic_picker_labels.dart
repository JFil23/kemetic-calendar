String kemeticPickerMonthLabel(int monthId) {
  if (monthId < 1 || monthId > kKemeticPickerMonthLabels.length) {
    throw RangeError.range(
      monthId,
      1,
      kKemeticPickerMonthLabels.length,
      'monthId',
      'Kemetic picker month ID must be 1-13',
    );
  }
  return kKemeticPickerMonthLabels[monthId - 1];
}

const kKemeticPickerMonthLabels = <String>[
  'Thoth',
  'Paopi',
  'Hathor',
  'Ka-her-Ka',
  'Shef-Bedet',
  'Rekh-Wer',
  'Rekh-Nedjes',
  'Renwet',
  'Hnsw',
  'Henti-het',
  'Pa-Ipi',
  'Mesut-Ra',
  'Heriu Renpet',
];
