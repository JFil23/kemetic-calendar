import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mobile/core/day_key.dart';
import 'package:mobile/features/calendar/decan_metadata.dart';
import 'package:mobile/features/calendar/kemetic_month_metadata.dart';
import 'package:mobile/features/onboarding/onboarding_overlay.dart';

class DecanCompassCopyRepo {
  DecanCompassCopyRepo(this._client);

  final SupabaseClient _client;

  Future<HawCompassCopy> loadForDay({
    required int kMonth,
    required int kDay,
  }) async {
    final fallback = fallbackForDay(kMonth: kMonth, kDay: kDay);
    try {
      final row = await _client
          .from('decan_compass_copy')
          .select(
            'decan_key,rhythm_phrase,orientation_question,day_aligned_return_key',
          )
          .eq('decan_key', fallback.decanKey)
          .maybeSingle();
      if (row == null) return fallback;
      final map = Map<String, dynamic>.from(row);
      return HawCompassCopy(
        decanKey: (map['decan_key'] as String?)?.trim().isNotEmpty == true
            ? (map['decan_key'] as String).trim()
            : fallback.decanKey,
        dateLabel: fallback.dateLabel,
        decanName: fallback.decanName,
        decanOrdinalLabel: fallback.decanOrdinalLabel,
        monthName: fallback.monthName,
        rhythmPhrase:
            ((map['rhythm_phrase'] as String?)?.trim().isNotEmpty == true)
            ? (map['rhythm_phrase'] as String).trim()
            : fallback.rhythmPhrase,
        orientationQuestion:
            ((map['orientation_question'] as String?)?.trim().isNotEmpty ==
                true)
            ? (map['orientation_question'] as String).trim()
            : fallback.orientationQuestion,
        dayAlignedReturnKey:
            ((map['day_aligned_return_key'] as String?)?.trim().isNotEmpty ==
                true)
            ? (map['day_aligned_return_key'] as String).trim()
            : fallback.dayAlignedReturnKey,
      );
    } catch (e) {
      debugPrint('[DecanCompassCopyRepo] load failed: $e');
      return fallback;
    }
  }

  static HawCompassCopy fallbackForDay({
    required int kMonth,
    required int kDay,
  }) {
    final month = getMonthById(kMonth.clamp(1, 13).toInt());
    final decan = decanForDay(kDay);
    final decanKey = kMonth == 13
        ? 'epagomenal'
        : 'm${kMonth.toString().padLeft(2, '0')}_d$decan';
    final decanName = kMonth == 13
        ? 'Heriu Renpet'
        : DecanMetadata.decanNameFor(
            kMonth: kMonth.clamp(1, 12).toInt(),
            kDay: kDay,
          );
    final ordinal = switch (decan) {
      1 => 'first',
      2 => 'second',
      3 => 'third',
      _ => 'threshold',
    };
    final monthName = month.displayShort;
    final dateLabel = kMonth == 13 ? '$monthName $kDay' : '$monthName $kDay';
    final fallbackCopy = _fallbackCompassCopy[decanKey];

    return HawCompassCopy(
      decanKey: decanKey,
      dateLabel: dateLabel,
      decanName: fallbackCopy?.decanName ?? decanName,
      decanOrdinalLabel: ordinal,
      monthName: monthName,
      rhythmPhrase:
          fallbackCopy?.rhythmPhrase ??
          '$decanName centers this stretch of $monthName on returning to the day with attention.',
      orientationQuestion:
          fallbackCopy?.orientationQuestion ??
          'What is asking to be met without force today?',
      dayAlignedReturnKey:
          fallbackCopy?.dayAlignedReturnKey ?? 'return_to_attention',
    );
  }
}

class _FallbackCompassCopy {
  const _FallbackCompassCopy({
    this.decanName,
    required this.rhythmPhrase,
    required this.orientationQuestion,
    required this.dayAlignedReturnKey,
  });

  final String? decanName;
  final String rhythmPhrase;
  final String orientationQuestion;
  final String dayAlignedReturnKey;
}

const Map<String, _FallbackCompassCopy> _fallbackCompassCopy = {
  'm01_d1': _FallbackCompassCopy(
    rhythmPhrase:
        'The first decan of Thoth centers on beginning with a clean measure.',
    orientationQuestion: 'What deserves your first clear return today?',
    dayAlignedReturnKey: 'begin_cleanly',
  ),
  'm01_d2': _FallbackCompassCopy(
    rhythmPhrase:
        'The second decan of Thoth centers on keeping the measure once it is named.',
    orientationQuestion: 'What can stay measured without becoming rigid?',
    dayAlignedReturnKey: 'keep_measure',
  ),
  'm01_d3': _FallbackCompassCopy(
    rhythmPhrase:
        'The third decan of Thoth centers on letting the record become useful.',
    orientationQuestion: 'What should be recorded before the day moves on?',
    dayAlignedReturnKey: 'make_record_useful',
  ),
  'm02_d1': _FallbackCompassCopy(
    rhythmPhrase:
        'The first decan of Phaophi centers on rising without scattering force.',
    orientationQuestion: 'Where can attention rise without hurry?',
    dayAlignedReturnKey: 'rise_with_attention',
  ),
  'm02_d2': _FallbackCompassCopy(
    rhythmPhrase:
        'The second decan of Phaophi centers on holding the living center.',
    orientationQuestion: 'What needs a steadier center today?',
    dayAlignedReturnKey: 'hold_center',
  ),
  'm02_d3': _FallbackCompassCopy(
    rhythmPhrase:
        'The third decan of Phaophi centers on beauty that restores order.',
    orientationQuestion:
        'What small restoration would make the day more beautiful?',
    dayAlignedReturnKey: 'restore_beauty',
  ),
  'm03_d1': _FallbackCompassCopy(
    rhythmPhrase:
        'The first decan of Hathor centers on what has arrived from the flood.',
    orientationQuestion: 'What has been deposited here for you to notice?',
    dayAlignedReturnKey: 'notice_deposit',
  ),
  'm03_d2': _FallbackCompassCopy(
    rhythmPhrase:
        'The second decan of Hathor centers on sorting what arrival brought.',
    orientationQuestion: 'What belongs with you, and what can pass by?',
    dayAlignedReturnKey: 'sort_arrival',
  ),
  'm03_d3': _FallbackCompassCopy(
    decanName: 'Sb: Sṯḥ',
    rhythmPhrase: 'Sb: Sṯḥ centers on the settling of what the flood brought.',
    orientationQuestion: 'What remains when the water recedes?',
    dayAlignedReturnKey: 'settle_after_flood',
  ),
  'm04_d1': _FallbackCompassCopy(
    rhythmPhrase:
        'The first decan of Khoiak centers on structure before display.',
    orientationQuestion: 'What needs its first sound shape today?',
    dayAlignedReturnKey: 'shape_first',
  ),
  'm04_d2': _FallbackCompassCopy(
    rhythmPhrase:
        'The second decan of Khoiak centers on strengthening what can carry weight.',
    orientationQuestion:
        'What should be reinforced before it is asked to hold more?',
    dayAlignedReturnKey: 'reinforce_weight',
  ),
  'm04_d3': _FallbackCompassCopy(
    rhythmPhrase:
        'The third decan of Khoiak centers on completing the support beneath the work.',
    orientationQuestion: 'What support is unfinished but necessary?',
    dayAlignedReturnKey: 'complete_support',
  ),
  'm05_d1': _FallbackCompassCopy(
    rhythmPhrase: 'The first decan of Tybi centers on seeing the forward edge.',
    orientationQuestion: 'What is ahead that needs a calmer approach?',
    dayAlignedReturnKey: 'see_forward_edge',
  ),
  'm05_d2': _FallbackCompassCopy(
    rhythmPhrase:
        'The second decan of Tybi centers on staying with the middle passage.',
    orientationQuestion: 'What can continue without being forced?',
    dayAlignedReturnKey: 'stay_middle',
  ),
  'm05_d3': _FallbackCompassCopy(
    rhythmPhrase:
        'The third decan of Tybi centers on bringing the forward work into form.',
    orientationQuestion: 'What form is asking to be made visible?',
    dayAlignedReturnKey: 'bring_forward_form',
  ),
  'm06_d1': _FallbackCompassCopy(
    rhythmPhrase:
        'The first decan of Mechir centers on forming what is still soft.',
    orientationQuestion: 'What needs patient shaping today?',
    dayAlignedReturnKey: 'shape_patiently',
  ),
  'm06_d2': _FallbackCompassCopy(
    rhythmPhrase:
        'The second decan of Mechir centers on tending the forming center.',
    orientationQuestion: 'What is fragile but worth tending?',
    dayAlignedReturnKey: 'tend_formation',
  ),
  'm06_d3': _FallbackCompassCopy(
    rhythmPhrase:
        'The third decan of Mechir centers on giving the formed thing a place.',
    orientationQuestion: 'Where should the formed work belong?',
    dayAlignedReturnKey: 'place_formation',
  ),
  'm07_d1': _FallbackCompassCopy(
    rhythmPhrase: 'The first decan of Phamenoth centers on noble restraint.',
    orientationQuestion: 'What power should be held in reserve?',
    dayAlignedReturnKey: 'reserve_power',
  ),
  'm07_d2': _FallbackCompassCopy(
    rhythmPhrase:
        'The second decan of Phamenoth centers on dignity inside repetition.',
    orientationQuestion: 'Where can repetition become dignified practice?',
    dayAlignedReturnKey: 'dignify_repetition',
  ),
  'm07_d3': _FallbackCompassCopy(
    rhythmPhrase:
        'The third decan of Phamenoth centers on making the noble thing usable.',
    orientationQuestion: 'What noble intention needs a practical step?',
    dayAlignedReturnKey: 'make_noble_practical',
  ),
  'm08_d1': _FallbackCompassCopy(
    rhythmPhrase:
        'The first decan of Pharmuthi centers on messages crossing the air.',
    orientationQuestion: 'What signal should you listen for before acting?',
    dayAlignedReturnKey: 'listen_for_signal',
  ),
  'm08_d2': _FallbackCompassCopy(
    rhythmPhrase:
        'The second decan of Pharmuthi centers on movement with orientation.',
    orientationQuestion: 'What movement needs direction, not more speed?',
    dayAlignedReturnKey: 'orient_movement',
  ),
  'm08_d3': _FallbackCompassCopy(
    rhythmPhrase:
        'The third decan of Pharmuthi centers on choosing what will fly forward.',
    orientationQuestion: 'What is ready to be released with care?',
    dayAlignedReturnKey: 'release_with_care',
  ),
  'm09_d1': _FallbackCompassCopy(
    rhythmPhrase:
        'The first decan of Pachons centers on what rests beneath the visible work.',
    orientationQuestion: 'What hidden support needs attention?',
    dayAlignedReturnKey: 'attend_hidden_support',
  ),
  'm09_d2': _FallbackCompassCopy(
    rhythmPhrase:
        'The second decan of Pachons centers on the shoulder that bears the load.',
    orientationQuestion: 'What load should be carried deliberately?',
    dayAlignedReturnKey: 'carry_deliberately',
  ),
  'm09_d3': _FallbackCompassCopy(
    rhythmPhrase:
        'The third decan of Pachons centers on lowering what no longer needs to be held.',
    orientationQuestion: 'What can be set down before it becomes disorder?',
    dayAlignedReturnKey: 'set_down_load',
  ),
  'm10_d1': _FallbackCompassCopy(
    rhythmPhrase:
        'The first decan of Paoni centers on the figure standing upon the star road.',
    orientationQuestion: 'What can stand upright without strain today?',
    dayAlignedReturnKey: 'stand_upright',
  ),
  'm10_d2': _FallbackCompassCopy(
    rhythmPhrase:
        'The second decan of Paoni centers on courage held in the heart.',
    orientationQuestion: 'What asks for courage without spectacle?',
    dayAlignedReturnKey: 'quiet_courage',
  ),
  'm10_d3': _FallbackCompassCopy(
    rhythmPhrase:
        'The third decan of Paoni centers on the star that follows through.',
    orientationQuestion: 'What deserves follow-through before the day closes?',
    dayAlignedReturnKey: 'follow_through',
  ),
  'm11_d1': _FallbackCompassCopy(
    rhythmPhrase:
        'The first decan of Epiphi centers on the beautiful star as a clear standard.',
    orientationQuestion: 'What standard should guide the next action?',
    dayAlignedReturnKey: 'clear_standard',
  ),
  'm11_d2': _FallbackCompassCopy(
    rhythmPhrase:
        'The second decan of Epiphi centers on keeping beauty at the heart of action.',
    orientationQuestion: 'Where can care make the action cleaner?',
    dayAlignedReturnKey: 'care_clean_action',
  ),
  'm11_d3': _FallbackCompassCopy(
    rhythmPhrase:
        'The third decan of Epiphi centers on beauty made repeatable.',
    orientationQuestion: 'What should become a repeatable form of care?',
    dayAlignedReturnKey: 'repeatable_care',
  ),
  'm12_d1': _FallbackCompassCopy(
    rhythmPhrase:
        'The first decan of Mesore centers on what must be offered before harvest ends.',
    orientationQuestion: 'What offering is still owed?',
    dayAlignedReturnKey: 'name_offering',
  ),
  'm12_d2': _FallbackCompassCopy(
    rhythmPhrase:
        'The second decan of Mesore centers on the heart of the final accounting.',
    orientationQuestion: 'What needs honest accounting today?',
    dayAlignedReturnKey: 'honest_accounting',
  ),
  'm12_d3': _FallbackCompassCopy(
    rhythmPhrase:
        'The third decan of Mesore centers on closure before the threshold.',
    orientationQuestion: 'What should close cleanly before it crosses forward?',
    dayAlignedReturnKey: 'close_cleanly',
  ),
  'epagomenal': _FallbackCompassCopy(
    rhythmPhrase:
        'The days upon the year center on threshold, birth, danger, and clean passage.',
    orientationQuestion: 'What should not cross into the opened year?',
    dayAlignedReturnKey: 'guard_threshold',
  ),
};
