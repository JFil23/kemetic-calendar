import 'package:flutter/material.dart';
import 'package:mobile/widgets/day_sheet_components.dart';
import 'package:mobile/widgets/keyboard_aware.dart';

import 'follow_sky_v11_tokens.dart';

/// The single intention-editing surface used by Follow the Sky.
class FollowSkyIntentionEditor extends StatelessWidget {
  const FollowSkyIntentionEditor({
    super.key,
    required this.controller,
    required this.fieldKey,
    required this.saveKey,
    required this.onSetIntention,
  });

  final TextEditingController controller;
  final Key fieldKey;
  final Key saveKey;
  final ValueChanged<String> onSetIntention;

  void _commit(BuildContext context) {
    FocusScope.of(context).unfocus();
    onSetIntention(controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        DaySheetTextField(
          key: fieldKey,
          controller: controller,
          hint: 'Your intention…',
          scrollPadding: keyboardManagedTextFieldScrollPadding,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _commit(context),
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 48,
          child: ElevatedButton(
            key: saveKey,
            style: ElevatedButton.styleFrom(
              backgroundColor: FollowSkyV11Tokens.gold,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            onPressed: () => _commit(context),
            child: const Text('Set intention'),
          ),
        ),
      ],
    );
  }
}
