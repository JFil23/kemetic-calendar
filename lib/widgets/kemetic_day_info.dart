/*
 * ═══════════════════════════════════════════════════════════════
 *   KEMETIC DAY CARD DATA
 * ═══════════════════════════════════════════════════════════════
 *
 * Day cards are keyed by Kemetic month/day/decan and reused every year.
 *
 * Gregorian labels in the UI come from [KemeticDayData.calculateGregorianDate]
 * (day key + Kemetic year), not from static strings on each card.
 *
 * Heriu Renpet is the exception: leap years expose a sixth threshold day.
 *
 * ═══════════════════════════════════════════════════════════════
 */

import 'package:flutter/material.dart';
import 'package:mobile/core/touch_targets.dart';
import 'package:mobile/widgets/kemetic_date_picker.dart';
import 'package:mobile/features/calendar/kemetic_month_metadata.dart';
import 'package:mobile/features/calendar/decan_metadata.dart';
import 'package:mobile/shared/glossy_text.dart';
import 'package:mobile/widgets/pronounce_icon_button.dart';
import 'package:mobile/services/speech/speech_service.dart';
import 'package:mobile/features/calendar/speech_resolver.dart';
import 'package:mobile/features/calendar/decan_id.dart';

part 'kemetic_day_models.dart';
part 'kemetic_day_data.dart';
part 'kemetic_day_data_core.dart';
part 'kemetic_day_data_flow_rows_1.dart';
part 'kemetic_day_data_flow_rows_2.dart';
part 'kemetic_day_data_entries_1.dart';
part 'kemetic_day_data_entries_2.dart';
part 'kemetic_day_data_compressed.dart';
part 'kemetic_day_data_map_1.dart';
part 'kemetic_day_data_map_2.dart';
part 'kemetic_day_data_map_3.dart';
part 'kemetic_day_data_map_4.dart';
part 'kemetic_day_data_map.dart';
part 'kemetic_day_dropdown.dart';
