import 'package:flutter/material.dart';
import 'package:mobile/widgets/day_sheet_components.dart';

import '../../domain/sky_observing_night.dart';
import '../../../maat_flow_visual_tokens.dart';
import '../turning_meaning.dart';
import 'follow_sky_v11_tokens.dart';

Future<void> showFollowSkyTurningSheet({
  required BuildContext context,
  required SkyObservingNight night,
  required TurningMeaning meaning,
  required String initialIntention,
  required ValueChanged<String> onSetIntention,
}) {
  final controller = TextEditingController(text: initialIntention);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: FollowSkyV11Tokens.sheetBg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      side: BorderSide(color: Color(0xFF2A2518)),
    ),
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          20 + MediaQuery.viewInsetsOf(ctx).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3A3743),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'In Kemet',
                style: TextStyle(
                  color: FollowSkyV11Tokens.gold,
                  fontFamily: MaatFlowListTokens.fontFamily,
                  fontFamilyFallback: MaatFlowListTokens.fontFallback,
                  fontSize: 12,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                night.displayName,
                style: const TextStyle(
                  color: FollowSkyV11Tokens.silverHi,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                meaning.observation,
                style: const TextStyle(
                  color: FollowSkyV11Tokens.silverHi,
                  fontSize: 15,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                meaning.significanceLabel,
                style: const TextStyle(
                  color: FollowSkyV11Tokens.gold,
                  letterSpacing: 2.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                meaning.personalQuestion,
                style: const TextStyle(
                  color: FollowSkyV11Tokens.silverHi,
                  fontStyle: FontStyle.italic,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              DaySheetTextField(
                controller: controller,
                hintText: 'Your intention…',
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FollowSkyV11Tokens.gold,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  onPressed: () {
                    onSetIntention(controller.text.trim());
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('Set intention'),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text(
                  'Leave it open',
                  style: TextStyle(color: FollowSkyV11Tokens.silverMid),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
