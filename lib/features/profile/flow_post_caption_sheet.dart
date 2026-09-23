import 'package:flutter/material.dart';

import '../../widgets/keyboard_aware.dart';
import 'package:mobile/shared/glossy_text.dart';

const int kFlowPostCaptionMaxLength = 280;

Future<String?> showFlowPostCaptionSheet({
  required BuildContext context,
  String? initialCaption,
  required String actionLabel,
  Widget? preview,
}) {
  return showEditableModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => _FlowPostCaptionSheet(
      initialCaption: initialCaption,
      actionLabel: actionLabel,
      preview: preview,
    ),
  );
}

class _FlowPostCaptionSheet extends StatefulWidget {
  const _FlowPostCaptionSheet({
    required this.initialCaption,
    required this.actionLabel,
    required this.preview,
  });

  final String? initialCaption;
  final String actionLabel;
  final Widget? preview;

  @override
  State<_FlowPostCaptionSheet> createState() => _FlowPostCaptionSheetState();
}

class _FlowPostCaptionSheetState extends State<_FlowPostCaptionSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialCaption ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardAwareEditableSurface(
      child: Material(
        color: const Color(0xFF080705),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.26),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Say something about this flow',
                  style: TextStyle(
                    color: Color(0xFFF2ECE0),
                    fontFamily: 'CormorantGaramond',
                    fontFamilyFallback: <String>[
                      'GentiumPlus',
                      'Georgia',
                      'serif',
                    ],
                    fontSize: 25,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Optional. Your words appear above the flow.',
                  style: TextStyle(
                    color: const Color(0xFFA69A83).withValues(alpha: 0.84),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const ValueKey<String>('flow-post-caption-field'),
                  controller: _controller,
                  autofocus: widget.preview == null,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: kFlowPostCaptionMaxLength,
                  style: const TextStyle(
                    color: Color(0xFFF2ECE0),
                    fontFamily: 'CormorantGaramond',
                    fontFamilyFallback: <String>[
                      'GentiumPlus',
                      'Georgia',
                      'serif',
                    ],
                    fontSize: 19,
                    height: 1.35,
                  ),
                  decoration: InputDecoration(
                    hintText: 'What does this practice change for you?',
                    hintStyle: TextStyle(
                      color: const Color(0xFFA69A83).withValues(alpha: 0.55),
                      fontStyle: FontStyle.italic,
                    ),
                    filled: true,
                    fillColor: const Color(0xFF0D0B08),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: KemeticGold.base.withValues(alpha: 0.24),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: KemeticGold.base.withValues(alpha: 0.24),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: KemeticGold.base,
                        width: 1.4,
                      ),
                    ),
                  ),
                ),
                if (widget.preview != null) ...<Widget>[
                  const SizedBox(height: 14),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _controller,
                    child: widget.preview,
                    builder: (context, value, preview) {
                      final caption = value.text.trim();
                      return Container(
                        key: const ValueKey<String>(
                          'flow-post-live-caption-preview',
                        ),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D0B08),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: KemeticGold.base.withValues(alpha: 0.20),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            if (caption.isNotEmpty) ...<Widget>[
                              Text(
                                caption,
                                key: const ValueKey<String>(
                                  'flow-post-live-caption-text',
                                ),
                                style: const TextStyle(
                                  color: Color(0xFFF2ECE0),
                                  fontFamily: 'CormorantGaramond',
                                  fontFamilyFallback: <String>[
                                    'GentiumPlus',
                                    'Georgia',
                                    'serif',
                                  ],
                                  fontSize: 20,
                                  fontWeight: FontWeight.w500,
                                  height: 1.30,
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            preview!,
                          ],
                        ),
                      );
                    },
                  ),
                ],
                const SizedBox(height: 18),
                Row(
                  children: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const Spacer(),
                    FilledButton(
                      key: const ValueKey<String>('flow-post-caption-submit'),
                      style: FilledButton.styleFrom(
                        backgroundColor: KemeticGold.base,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 13,
                        ),
                      ),
                      onPressed: () =>
                          Navigator.of(context).pop(_controller.text.trim()),
                      child: Text(widget.actionLabel),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
