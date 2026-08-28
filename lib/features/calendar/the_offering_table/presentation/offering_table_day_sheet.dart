import 'package:flutter/material.dart';

import '../../maat_flow_visual_tokens.dart';
import '../../presentation/maat_flow_preview_day.dart';
import '../../the_offering_table_flow.dart';

@immutable
class OfferingTablePreviewOccurrence {
  const OfferingTablePreviewOccurrence({
    required this.day,
    required this.date,
    required this.startLocal,
  });

  final OfferingTableDay day;
  final DateTime date;
  final DateTime startLocal;
}

Future<void> showOfferingTableDaySheet({
  required BuildContext context,
  required OfferingTablePreviewOccurrence occurrence,
  required OfferingTableLens lens,
  required bool noCupMode,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: const Color(0xFF0C0905),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      side: BorderSide(color: Color(0x4AC99A3D)),
    ),
    builder: (context) => OfferingTableDaySheet(
      occurrence: occurrence,
      lens: lens,
      noCupMode: noCupMode,
    ),
  );
}

class OfferingTableDaySheet extends StatelessWidget {
  const OfferingTableDaySheet({
    super.key,
    required this.occurrence,
    required this.lens,
    required this.noCupMode,
  });

  final OfferingTablePreviewOccurrence occurrence;
  final OfferingTableLens lens;
  final bool noCupMode;

  static const _gold = Color(0xFFC99A3D);
  static const _ivory = Color(0xFFD7CDBA);
  static const _silver = Color(0xFFA59D91);
  static const _separator = Color(0xFF302313);

  @override
  Widget build(BuildContext context) {
    final day = occurrence.day;
    final sections = _detailSections(
      offeringTableDetailText(day, lens: lens, noCupMode: noCupMode),
    );

    return SafeArea(
      key: const ValueKey<String>('offering-table-day-sheet'),
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
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
                    color: const Color(0xFF4B4033),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'DAY ${day.dayNumber.toString().padLeft(2, '0')} · ${day.section.toUpperCase()}',
                style: const TextStyle(
                  color: _gold,
                  fontFamily: MaatFlowListTokens.fontFamily,
                  fontFamilyFallback: MaatFlowListTokens.fontFallback,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                day.title,
                style: const TextStyle(
                  color: _ivory,
                  fontFamily: MaatFlowListTokens.fontFamily,
                  fontFamilyFallback: MaatFlowListTokens.fontFallback,
                  fontSize: 28,
                  fontWeight: FontWeight.w500,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${gregorianDateLabel(occurrence.date)}, ${occurrence.date.year} · ${_formatTime(occurrence.startLocal)}',
                style: const TextStyle(
                  color: _silver,
                  fontFamily: MaatFlowListTokens.fontFamily,
                  fontFamilyFallback: MaatFlowListTokens.fontFallback,
                  fontSize: 12,
                  letterSpacing: 0.45,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Divider(color: _separator, height: 1),
              ),
              for (var index = 0; index < sections.length; index++) ...[
                _OfferingDetailSection(section: sections[index]),
                if (index != sections.length - 1) const SizedBox(height: 18),
              ],
              if (day.sourceNote?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 18),
                _OfferingDetailSection(
                  section: _DetailSection(
                    label: 'Context',
                    body: day.sourceNote!.trim(),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              TextButton(
                key: const ValueKey<String>('offering-table-day-sheet-close'),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close', style: TextStyle(color: _gold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfferingDetailSection extends StatelessWidget {
  const _OfferingDetailSection({required this.section});

  final _DetailSection section;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          section.label.toUpperCase(),
          style: const TextStyle(
            color: OfferingTableDaySheet._gold,
            fontFamily: MaatFlowListTokens.fontFamily,
            fontFamilyFallback: MaatFlowListTokens.fontFallback,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.8,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          section.body,
          style: const TextStyle(
            color: OfferingTableDaySheet._ivory,
            fontFamily: MaatFlowListTokens.fontFamily,
            fontFamilyFallback: MaatFlowListTokens.fontFallback,
            fontSize: 15.5,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _DetailSection {
  const _DetailSection({required this.label, required this.body});

  final String label;
  final String body;
}

List<_DetailSection> _detailSections(String detail) {
  return [
    for (final block in detail.split('\n\n'))
      if (block.trim().isNotEmpty)
        () {
          final lines = block.trim().split('\n');
          return _DetailSection(
            label: lines.first,
            body: lines.skip(1).join('\n').trim(),
          );
        }(),
  ];
}

String _formatTime(DateTime date) {
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final suffix = date.hour < 12 ? 'AM' : 'PM';
  return '$hour:$minute $suffix';
}
