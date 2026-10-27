import 'package:flutter/material.dart';
import '../../core/theme/app_fonts.dart';
import '../../shared/kemetic_text.dart';
import 'ask_haw_response.dart';

/// One compact response inside Quick Add, also used by decan continuations.
/// Navigation and account mutations remain with the supplied action owner.
class AskHawResponseView extends StatelessWidget {
  const AskHawResponseView({
    super.key,
    required this.response,
    required this.onChoose,
    this.busy = false,
    this.onClose,
  });
  final AskHawResponse response;
  final ValueChanged<String> onChoose;
  final bool busy;
  final VoidCallback? onClose;
  static const _gold = Color(0xFFD4AE43);
  static const _text = Color(0xFFF2ECE0);

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('ask-haw-response'),
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
    decoration: BoxDecoration(
      color: const Color(0xFF15140F),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _gold.withValues(alpha: .22)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Expanded(
              child: KemeticText(
                'ASK ḥꜣw',
                style: TextStyle(
                  color: _gold,
                  fontFamily: AppFonts.ui,
                  fontSize: 10.5,
                  letterSpacing: 1.8,
                ),
              ),
            ),
            if (busy)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: _gold,
                ),
              ),
            if (onClose != null)
              IconButton(
                tooltip: 'Dismiss answer',
                onPressed: onClose,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 28,
                  height: 28,
                ),
                icon: const Icon(
                  Icons.close,
                  color: Color(0xFF9A948A),
                  size: 16,
                ),
              ),
          ],
        ),
        const SizedBox(height: 7),
        KemeticText(
          response.title,
          style: const TextStyle(
            color: _text,
            fontFamily: 'CormorantGaramond',
            fontSize: 22,
            height: 1.2,
          ),
        ),
        if (response.body case final body?) ...[
          const SizedBox(height: 7),
          KemeticText(
            body,
            style: const TextStyle(
              color: Color(0xFFD8D1C4),
              fontFamily: 'CormorantGaramond',
              fontSize: 17,
              height: 1.35,
            ),
          ),
        ],
        for (final option in response.options) ...[
          const SizedBox(height: 10),
          Material(
            color: Colors.transparent,
            child: InkWell(
              key: ValueKey('ask-haw-option-${option.id}'),
              borderRadius: BorderRadius.circular(10),
              onTap: busy ? null : () => onChoose(option.id),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _gold.withValues(alpha: option.secondary ? .12 : .3),
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: KemeticText(
                            option.label,
                            style: TextStyle(
                              color: option.secondary
                                  ? const Color(0xFFBEB6A7)
                                  : _gold,
                              fontFamily: 'CormorantGaramond',
                              fontSize: 18,
                              height: 1.2,
                            ),
                          ),
                        ),
                        if (option.menuOptions.isNotEmpty)
                          PopupMenuButton<String>(
                            tooltip: 'Options for ${option.label}',
                            enabled: !busy,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 180,
                              maxWidth: 280,
                            ),
                            icon: const Icon(
                              Icons.more_horiz,
                              color: _gold,
                              size: 20,
                            ),
                            onSelected: onChoose,
                            itemBuilder: (_) => [
                              for (final action in option.menuOptions)
                                PopupMenuItem(
                                  value: action.id,
                                  child: KemeticText(
                                    action.label,
                                    style: const TextStyle(
                                      color: _text,
                                      fontFamily: 'CormorantGaramond',
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
                    if (option.detail case final detail?) ...[
                      const SizedBox(height: 4),
                      KemeticText(
                        detail,
                        style: const TextStyle(
                          color: _text,
                          fontFamily: AppFonts.ui,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                    if (option.reason case final reason?) ...[
                      const SizedBox(height: 4),
                      KemeticText(
                        reason,
                        style: const TextStyle(
                          color: Color(0xFFADA594),
                          fontFamily: AppFonts.ui,
                          fontSize: 11.5,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}
