part of 'calendar_page.dart';

// ========================================
// CUSTOM REPEAT PAGE
// ========================================

class _CustomRepeatPage extends StatefulWidget {
  final SimpleRecurrenceFrequency initialFrequency;
  final int initialInterval;

  const _CustomRepeatPage({
    required this.initialFrequency,
    required this.initialInterval,
  });

  @override
  State<_CustomRepeatPage> createState() => _CustomRepeatPageState();
}

class _CustomRepeatPageState extends State<_CustomRepeatPage> {
  late SimpleRecurrenceFrequency _freq;
  late int _interval;

  @override
  void initState() {
    super.initState();
    _freq = widget.initialFrequency;
    _interval = widget.initialInterval.clamp(1, 999);
  }

  String _freqLabel(SimpleRecurrenceFrequency f) {
    switch (f) {
      case SimpleRecurrenceFrequency.daily:
        return 'Daily';
      case SimpleRecurrenceFrequency.weekly:
        return 'Weekly';
      case SimpleRecurrenceFrequency.monthly:
        return 'Monthly';
      case SimpleRecurrenceFrequency.yearly:
        return 'Yearly';
    }
  }

  String _unitLabel() {
    switch (_freq) {
      case SimpleRecurrenceFrequency.daily:
        return _interval == 1 ? 'day' : 'days';
      case SimpleRecurrenceFrequency.weekly:
        return _interval == 1 ? 'week' : 'weeks';
      case SimpleRecurrenceFrequency.monthly:
        return _interval == 1 ? 'month' : 'months';
      case SimpleRecurrenceFrequency.yearly:
        return _interval == 1 ? 'year' : 'years';
    }
  }

  Widget _divider() => Container(
    height: 1,
    color: Colors.white12,
    margin: const EdgeInsets.symmetric(horizontal: 16),
  );

  Widget _row({
    required String label,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GlossyText(
              text: label,
              gradient: goldGloss,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.none,
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }

  Future<void> _showFrequencySheet() async {
    final result = await showCupertinoModalPopup<SimpleRecurrenceFrequency>(
      context: context,
      builder: (_) {
        return CupertinoActionSheet(
          title: const GlossyText(
            text: 'Frequency',
            gradient: silverGloss,
            style: TextStyle(fontSize: 18),
          ),
          actions: [
            for (final f in SimpleRecurrenceFrequency.values)
              CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.pop(context, f);
                },
                child: GlossyText(
                  text: _freqLabel(f),
                  gradient: goldGloss,
                  style: const TextStyle(fontSize: 17),
                ),
              ),
          ],
          cancelButton: CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        );
      },
    );

    if (result != null) {
      setState(() => _freq = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: Colors.black,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: Colors.black,
        border: null,
        previousPageTitle: 'Repeat',
        middle: const GlossyText(
          text: 'Custom',
          gradient: silverGloss,
          style: TextStyle(fontSize: 18),
        ),
        trailing: CupertinoButton(
          padding: useExpandedTouchTargets(context)
              ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
              : EdgeInsets.zero,
          onPressed: () {
            Navigator.pop<Map<String, dynamic>>(context, {
              'frequency': _freq,
              'interval': _interval,
            });
          },
          child: GlossyText(
            text: 'Done',
            gradient: goldGloss,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: 20),

            // MAIN CARD
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12, width: 1),
                ),
                child: Column(
                  children: [
                    _row(
                      label: 'Frequency',
                      trailing: Row(
                        children: [
                          GlossyText(
                            text: _freqLabel(_freq),
                            gradient: silverGloss,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.none,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.keyboard_arrow_down,
                            color: Colors.white54,
                          ),
                        ],
                      ),
                      onTap: _showFrequencySheet,
                    ),

                    _divider(),

                    _row(
                      label: 'Every',
                      trailing: GlossyText(
                        text: _unitLabel().capitalizeFirst(),
                        gradient: goldGloss,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),

                    _divider(),

                    // INTERVAL PICKER
                    SizedBox(
                      height: 160,
                      child: CupertinoPicker(
                        itemExtent: 34,
                        scrollController: FixedExtentScrollController(
                          initialItem: (_interval - 1).clamp(0, 998),
                        ),
                        onSelectedItemChanged: (index) {
                          setState(() {
                            _interval = index + 1;
                          });
                        },
                        backgroundColor: Colors.black,
                        children: List.generate(999, (i) {
                          final v = i + 1;
                          return Center(
                            child: GlossyText(
                              text: '$v',
                              gradient: silverGloss,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // SUMMARY
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GlossyText(
                text: 'Event will occur every $_interval ${_unitLabel()}.',
                gradient: silverGloss,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Keeps editor controllers alive until the bottom sheet subtree is unmounted.
