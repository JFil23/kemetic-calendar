/* 
 * ═══════════════════════════════════════════════════════════════
 *   ⚠️  KEMETIC YEAR 1 ONLY - HARDCODED DATES
 * ═══════════════════════════════════════════════════════════════
 * 
 * Valid Period: March 20, 2025 - March 19, 2026 (Gregorian)
 * 
 * Gregorian labels in the UI come from [KemeticDayData.calculateGregorianDate]
 * (day key + Kemetic year), not from static strings on each card.
 * 
 * For multi-year support, see: docs/MULTI_YEAR_MIGRATION.md
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
part 'kemetic_day_dropdown.dart';
