/// Curated phonetic strings for Kemetic months and decans.
/// These are engine-friendly (no diacritics) and use simple stress hints.

// Month ID -> phonetic
const Map<int, String> monthSpeech = {
  1: 'juh-HOO-tee',        // Thoth — Ḏḥwty
  2: 'men-KHET',           // Paopi — Mnḫt
  3: 'HOOT-hor',           // Hathor — Ḥwt-Ḥr
  4: 'kah her KAH',        // Ka-ḥer-Ka — Kȝ-ḥr-Kȝ
  5: 'shef BEH-det',       // Šef-Bedet — Šf-bdt
  6: 'rekh WER',           // Rekh-Wer — Rḫ-wr
  7: 'rekh NED-jes',       // Rekh-Nedjes — Rḫ-nḏs
  8: 'ren-NOOT',           // Renwet — Rnnwt
  9: 'HEN-soo',            // Hnsw — Ḥnsw
  10: 'HEN-tee HEH-tee',   // Ḥenti-ḥet — Ḥnt-ḥtj
  11: 'EE-pet HEH-met',    // Pa-Ipi — ỉpt-ḥmt
  12: 'MEH-soot rah',      // Mesut-Ra — Mswt-Rꜥ
  13: 'HEH-ree-oo REN-pet' // Heriu Renpet — ḥr.w rnpt
};

/// Decan speech ids: id = (monthIndex - 1) * 3 + decanInMonth (1..3), monthIndex 1..12.
const Map<int, String> decanSpeech = {
  // Month 1
  1:  'TEH-pee ah seh-BAH-oo',      // tpy-ꜣ sbꜣw
  2:  'HER-ee ib seh-BAH-oo',       // ḥry-ib sbꜣw
  3:  'seh-BAH-oo',                 // sbꜣw

  // Month 2
  4:  'ah-HAH-ee',                  // ꜥḥꜣy
  5:  'HER-ee ib ah-HAH-ee',        // ḥry-ib ꜥḥꜣy
  6:  'seh-BAH NEH-fer',            // sbꜣ nfr

  // Month 3
  7:  'sah',                        // sꜣḥ
  8:  'HER-ee ib sah',              // ḥry-ib sꜣḥ
  9:  'seh-BAH sah',                // sbꜣ sꜣḥ

  // Month 4
  10: 'mes-HET-yoo',                // msḥtjw
  11: 'HER-ee ib mes-HET-yoo',      // ḥry-ib msḥtjw
  12: 'seh-BAH mes-HET-yoo',        // sbꜣ msḥtjw

  // Month 5
  13: 'KHEN-tee her',               // ḫnty-ḥr
  14: 'HER-ee ib KHEN-tee her',     // ḥry-ib ḫnty-ḥr
  15: 'seh-BAH KHEN-tee her',       // sbꜣ ḫnty-ḥr

  // Month 6
  16: 'KHNOOM',                     // knmw
  17: 'HER-ee ib KHNOOM',           // ḥry-ib knmw
  18: 'seh-BAH KHNOOM',             // sbꜣ knmw

  // Month 7
  19: 'shep-SOOT',                  // špsswt
  20: 'HER-ee ib shep-SOOT',        // ḥry-ib špsswt
  21: 'seh-BAH shep-SOOT',          // sbꜣ špsswt

  // Month 8
  22: 'ah-PED-oo',                  // ꜥpdw
  23: 'HER-ee ib ah-PED-oo',        // ḥry-ib ꜥpdw
  24: 'seh-BAH ah-PED-oo',          // sbꜣ ꜥpdw

  // Month 9
  25: 'KHREE art',                  // ẖry ꜥrt
  26: 'reh-MEN HER-ee sah',         // rmn ḥry sꜣḥ
  27: 'reh-MEN KHREE sah',          // rmn ẖry sꜣḥ

  // Month 10
  28: 'HER-oo sah',                 // ḥr-sꜣḥ
  29: 'HER-ee ib HER-oo sah',       // ḥry-ib ḥr-sꜣḥ
  30: 'seh-BAH HER-oo sah',         // sbꜣ ḥr-sꜣḥ

  // Month 11
  31: 'seh-BAH NEH-fer',            // sbꜣ nfr
  32: 'HER-ee ib seh-BAH NEH-fer',  // ḥry-ib sbꜣ nfr
  33: 'TEH-pee ah SOP-det',         // tpy-ꜣ spdt

  // Month 12
  34: 'mes-HET-yoo khet',           // msḥtjw ḫt
  35: 'HER-ee ib mes-HET-yoo khet', // ḥry-ib msḥtjw ḫt
  36: 'seh-BAH mes-HET-yoo khet',   // sbꜣ msḥtjw ḫt
};
