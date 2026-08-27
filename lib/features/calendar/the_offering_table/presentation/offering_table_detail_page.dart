import 'package:flutter/material.dart';

import 'package:mobile/features/calendar/maat_flow_visual_tokens.dart';
import 'package:mobile/features/calendar/presentation/maat_flow_detail_shell.dart';
import 'package:mobile/features/calendar/the_offering_table_flow.dart';
import 'package:mobile/features/calendar/track_sky_flow.dart';
import 'package:mobile/widgets/maat_flow_date_picker.dart';

typedef OfferingTableJoinCallback =
    Future<int> Function({
      required DateTime startDate,
      required TrackSkyTimeZone timezone,
      required OfferingTableLens lens,
      required bool noCupMode,
    });

abstract final class OfferingTableDetailTokens {
  static const Color pageBackground = Color(0xFF070502);
  static const Color sheetBackground = Color(0xFF0C0905);
  static const Color warmGold = Color(0xFFC99A3D);
  static const Color deepBrown = Color(0xFF5C3918);
  static const Color mutedIvory = Color(0xFFD7CDBA);
  static const Color silver = Color(0xFFA59D91);
  static const Color muted = Color(0xFF756C60);
  static const Color glow = Color(0xFFF0C96A);
  static const Color separator = Color(0xFF302313);

  static const MaatFlowDetailTheme theme = MaatFlowDetailTheme(
    pageBackground: pageBackground,
    sheetBackground: sheetBackground,
    sheetBorder: Color(0x4AC99A3D),
    accent: warmGold,
    primaryText: mutedIvory,
    secondaryText: silver,
    mutedText: muted,
    separator: separator,
    glow: glow,
  );
}

/// Dedicated presentation for The Offering Table. Scheduling, enrollment,
/// response persistence, and all event text remain owned by the existing
/// Offering Table domain layer and the parent Ma'at detail orchestrator.
class OfferingTableDetailPage extends StatefulWidget {
  const OfferingTableDetailPage({
    super.key,
    required this.timezone,
    required this.onJoin,
    this.initialPrompt,
    this.initialStartDate,
    this.alreadyJoined = false,
    this.showBackButton = true,
    this.resizeToAvoidBottomInset = true,
    this.onJoined,
  });

  final TrackSkyTimeZone timezone;
  final OfferingTableJoinCallback onJoin;
  final Widget? initialPrompt;
  final DateTime? initialStartDate;
  final bool alreadyJoined;
  final bool showBackButton;
  final bool resizeToAvoidBottomInset;
  final Future<void> Function(int flowId)? onJoined;

  @override
  State<OfferingTableDetailPage> createState() =>
      _OfferingTableDetailPageState();
}

class _OfferingTableDetailPageState extends State<OfferingTableDetailPage> {
  late DateTime _startDate;
  late bool _joined;
  OfferingTableLens _lens = OfferingTableLens.neutral;
  bool _noCupMode = false;
  bool _useKemetic = false;
  bool _joining = false;
  bool _showAllDays = false;

  @override
  void initState() {
    super.initState();
    _startDate = DateUtils.dateOnly(
      widget.initialStartDate ?? defaultOfferingTableStartDate(widget.timezone),
    );
    _joined = widget.alreadyJoined;
  }

  @override
  void didUpdateWidget(covariant OfferingTableDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.alreadyJoined != oldWidget.alreadyJoined) {
      _joined = widget.alreadyJoined;
    }
  }

  Future<void> _pickStartDate() async {
    final result = await MaatFlowDatePicker.show(
      context: context,
      initialDate: _startDate,
      initialMode: _useKemetic
          ? MaatFlowDatePickerMode.kemetic
          : MaatFlowDatePickerMode.gregorian,
    );
    if (result == null || !mounted) return;
    setState(() {
      _startDate = DateUtils.dateOnly(result.date);
      _useKemetic = result.mode == MaatFlowDatePickerMode.kemetic;
    });
  }

  Future<void> _join() async {
    if (_joining || _joined) return;
    setState(() => _joining = true);
    try {
      final id = await widget.onJoin(
        startDate: _startDate,
        timezone: widget.timezone,
        lens: _lens,
        noCupMode: _noCupMode,
      );
      if (!mounted) return;
      if (id > 0) {
        final onJoined = widget.onJoined;
        if (onJoined != null) {
          await onJoined(id);
        } else if (mounted) {
          setState(() {
            _joined = true;
            _joining = false;
          });
        }
        return;
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not join The Offering Table. Please retry.'),
        ),
      );
    }
    if (mounted) setState(() => _joining = false);
  }

  @override
  Widget build(BuildContext context) {
    final body = MaatFlowDetailShell(
      theme: OfferingTableDetailTokens.theme,
      scrollKey: const ValueKey<String>('offering-table-scroll'),
      heroLayerKey: const ValueKey<String>('offering-table-hero-layer'),
      sheetKey: const ValueKey<String>('offering-table-sheet'),
      hero: const _OfferingTableHero(),
      bottomDock: MaatFlowDetailDock(
        theme: OfferingTableDetailTokens.theme,
        joined: _joined,
        busy: _joining,
        onPressed: _join,
        actionLabel: 'Carry this table',
        actionNote: 'Nothing is added until you carry it.',
        joinedLabel: 'In your calendar',
        joinedNote: 'Return to the table each morning. Change anything later.',
        actionKey: const ValueKey<String>('offering-table-join'),
        joinedKey: const ValueKey<String>('offering-table-joined'),
      ),
      sheet: _buildSheet(context),
    );

    return Scaffold(
      resizeToAvoidBottomInset: widget.resizeToAvoidBottomInset,
      backgroundColor: OfferingTableDetailTokens.pageBackground,
      body: Stack(
        children: [
          body,
          if (widget.showBackButton)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 4,
              left: 4,
              child: IconButton(
                tooltip: 'Back',
                icon: const Icon(
                  Icons.arrow_back,
                  color: OfferingTableDetailTokens.warmGold,
                ),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSheet(BuildContext context) {
    final firstDay = kOfferingTableDays.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _ThirtyDayTableStrip(),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _OfferingSectionLabel('THE FIRST PRACTICE'),
              _OfferingDayCard(
                day: firstDay,
                lens: _lens,
                noCupMode: _noCupMode,
                expandedByDefault: true,
              ),
              if (widget.initialPrompt != null) ...[
                const _OfferingSeparator(),
                widget.initialPrompt!,
              ],
              const _OfferingSeparator(),
              const _OfferingSectionLabel('SET YOUR TABLE'),
              Text(
                kOfferingTableEnrollmentCopy,
                style: _bodyStyle(
                  OfferingTableDetailTokens.mutedIvory,
                ).copyWith(fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 18),
              _buildStartDateControl(context),
              const SizedBox(height: 24),
              const _OfferingSectionLabel('LENS'),
              Text(
                'A lens adds one short framing line. It does not change the thirty sittings, timing, or completion states.',
                style: _bodyStyle(OfferingTableDetailTokens.muted),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: OfferingTableLens.values
                    .map(_buildLensChoice)
                    .toList(growable: false),
              ),
              const SizedBox(height: 12),
              Text(
                _lensExplanation(_lens),
                key: const ValueKey<String>('offering-table-lens-explanation'),
                style: _bodyStyle(
                  OfferingTableDetailTokens.silver,
                ).copyWith(fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 16),
              _buildNoCupControl(),
              const _OfferingSeparator(),
              const _OfferingSectionLabel('THE FIRST FIVE DAYS'),
              for (final day in kOfferingTableDays.skip(1).take(4))
                _OfferingDayCard(day: day, lens: _lens, noCupMode: _noCupMode),
              if (!_showAllDays)
                OutlinedButton(
                  key: const ValueKey<String>('offering-table-show-all'),
                  style: _outlineButtonStyle(),
                  onPressed: () => setState(() => _showAllDays = true),
                  child: const Text('Show all 30 days'),
                )
              else ...[
                for (final section in const <String>[
                  'Personal Table',
                  'Household Table',
                  'Flowing Table',
                ]) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 24, bottom: 8),
                    child: Text(
                      section,
                      style: const TextStyle(
                        color: OfferingTableDetailTokens.warmGold,
                        fontFamily: MaatFlowListTokens.fontFamily,
                        fontFamilyFallback: MaatFlowListTokens.fontFallback,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  for (final day in kOfferingTableDays.where(
                    (candidate) =>
                        candidate.section == section && candidate.dayNumber > 5,
                  ))
                    _OfferingDayCard(
                      day: day,
                      lens: _lens,
                      noCupMode: _noCupMode,
                    ),
                ],
                TextButton(
                  key: const ValueKey<String>('offering-table-collapse-days'),
                  onPressed: () => setState(() => _showAllDays = false),
                  child: const Text('Show fewer days'),
                ),
              ],
              const _OfferingSeparator(),
              _OfferingDescription(overview: kOfferingTableOverview),
              const SizedBox(height: 24),
              Text(
                'This is a reflective practice, not medical, psychological, or professional advice. Adapt anything that does not suit you, and seek qualified help for health or crisis concerns.',
                key: const ValueKey<String>(
                  'maat_flow_practice_disclaimer_footer',
                ),
                style: _bodyStyle(
                  OfferingTableDetailTokens.muted,
                ).copyWith(fontSize: 11.5),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStartDateControl(BuildContext context) {
    final l10n = MaterialLocalizations.of(context);
    final schedule = offeringTableScheduleForDate(
      kOfferingTableDays.first,
      _startDate,
      widget.timezone,
    );
    final date = l10n.formatMediumDate(_startDate);
    final time = l10n.formatTimeOfDay(
      TimeOfDay.fromDateTime(schedule.startLocal),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton(
          key: const ValueKey<String>('offering-table-start-date'),
          style: _outlineButtonStyle(minimumHeight: 60),
          onPressed: _pickStartDate,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('Start: $date at $time'),
          ),
        ),
        const SizedBox(height: 7),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            _useKemetic ? 'Mode: Kemetic' : 'Mode: Gregorian',
            key: const ValueKey<String>('offering-table-date-mode'),
            style: _bodyStyle(
              OfferingTableDetailTokens.muted,
            ).copyWith(fontSize: 12, fontStyle: FontStyle.italic),
          ),
        ),
      ],
    );
  }

  Widget _buildLensChoice(OfferingTableLens lens) {
    final selected = lens == _lens;
    return ChoiceChip(
      key: ValueKey<String>('offering-table-lens-${lens.key}'),
      showCheckmark: false,
      label: Text(lens.label),
      selected: selected,
      onSelected: (_) => setState(() => _lens = lens),
      selectedColor: OfferingTableDetailTokens.warmGold,
      backgroundColor: OfferingTableDetailTokens.deepBrown.withValues(
        alpha: 0.34,
      ),
      side: BorderSide(
        color: selected
            ? OfferingTableDetailTokens.warmGold
            : OfferingTableDetailTokens.warmGold.withValues(alpha: 0.28),
      ),
      labelStyle: TextStyle(
        color: selected
            ? OfferingTableDetailTokens.pageBackground
            : OfferingTableDetailTokens.mutedIvory,
        fontFamily: MaatFlowListTokens.fontFamily,
        fontFamilyFallback: MaatFlowListTokens.fontFallback,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildNoCupControl() {
    return Container(
      decoration: BoxDecoration(
        color: OfferingTableDetailTokens.deepBrown.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: OfferingTableDetailTokens.warmGold.withValues(alpha: 0.24),
        ),
      ),
      child: SwitchListTile.adaptive(
        key: const ValueKey<String>('offering-table-no-cup'),
        value: _noCupMode,
        activeTrackColor: OfferingTableDetailTokens.warmGold,
        title: const Text(
          'Use the cup you’re already holding',
          style: TextStyle(
            color: OfferingTableDetailTokens.mutedIvory,
            fontFamily: MaatFlowListTokens.fontFamily,
            fontFamilyFallback: MaatFlowListTokens.fontFallback,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          'Commute alternative; the water step remains part of the sitting.',
          style: _bodyStyle(
            OfferingTableDetailTokens.silver,
          ).copyWith(fontSize: 12.5),
        ),
        onChanged: (value) => setState(() => _noCupMode = value),
      ),
    );
  }

  String _lensExplanation(OfferingTableLens lens) {
    return switch (lens) {
      OfferingTableLens.neutral =>
        'Neutral keeps the table focused on water, provision, and truthful care.',
      OfferingTableLens.hapy =>
        'Hapy adds a short abundance-and-flow line to each sitting.',
      OfferingTableLens.ausar =>
        'Ausar adds a short restoration line for provision that has gone dry.',
    };
  }
}

class _OfferingTableHero extends StatelessWidget {
  const _OfferingTableHero();

  @override
  Widget build(BuildContext context) {
    return MaatFlowDetailHero(
      theme: OfferingTableDetailTokens.theme,
      background: const _OfferingTableHeroBackdrop(),
      glyph: kOfferingTableGlyph,
      glyphKey: const ValueKey<String>('offering-table-hero-glyph'),
      glyphGradient: const RadialGradient(
        center: Alignment(-0.28, -0.42),
        radius: 0.92,
        colors: [Color(0xFFE2B559), Color(0xFF62401D), Color(0xFF120B04)],
      ),
      glyphBorder: OfferingTableDetailTokens.warmGold,
      glyphGlow: OfferingTableDetailTokens.glow,
      title: 'The Offering\nTable',
      subtitle: kOfferingTableTagline,
    );
  }
}

class _OfferingTableHeroBackdrop extends StatelessWidget {
  const _OfferingTableHeroBackdrop();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF160E05),
                  Color(0xFF0C0804),
                  Color(0xFF070502),
                ],
                stops: [0.0, 0.58, 1.0],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.48, -0.50),
                radius: 0.72,
                colors: [
                  Color(0x526F451B),
                  Color(0x142B1909),
                  Colors.transparent,
                ],
                stops: [0.0, 0.54, 1.0],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.70, 0.82),
                radius: 0.78,
                colors: [Color(0x384A2D13), Colors.transparent],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThirtyDayTableStrip extends StatelessWidget {
  const _ThirtyDayTableStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('offering-table-thirty-day-strip'),
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 20),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: OfferingTableDetailTokens.separator),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '30-DAY RHYTHM',
            style: TextStyle(
              color: OfferingTableDetailTokens.muted,
              fontFamily: MaatFlowListTokens.fontFamily,
              fontFamilyFallback: MaatFlowListTokens.fontFallback,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final entry in const <(String, String)>[
                ('Personal Table', 'Days 1–10'),
                ('Household Table', 'Days 11–20'),
                ('Flowing Table', 'Days 21–30'),
              ])
                Expanded(
                  child: _TableBand(title: entry.$1, range: entry.$2),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TableBand extends StatelessWidget {
  const _TableBand({required this.title, required this.range});

  final String title;
  final String range;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 3,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: const LinearGradient(
                colors: [
                  OfferingTableDetailTokens.deepBrown,
                  OfferingTableDetailTokens.warmGold,
                ],
              ),
            ),
          ),
          const SizedBox(height: 9),
          Text(
            title,
            maxLines: 2,
            style: const TextStyle(
              color: OfferingTableDetailTokens.mutedIvory,
              fontFamily: MaatFlowListTokens.fontFamily,
              fontFamilyFallback: MaatFlowListTokens.fontFallback,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              height: 1.12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            range,
            style: _bodyStyle(
              OfferingTableDetailTokens.muted,
            ).copyWith(fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _OfferingDayCard extends StatelessWidget {
  const _OfferingDayCard({
    required this.day,
    required this.lens,
    required this.noCupMode,
    this.expandedByDefault = false,
  });

  final OfferingTableDay day;
  final OfferingTableLens lens;
  final bool noCupMode;
  final bool expandedByDefault;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey<String>('offering-table-day-${day.dayNumber}'),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: OfferingTableDetailTokens.deepBrown.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: OfferingTableDetailTokens.warmGold.withValues(alpha: 0.18),
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: expandedByDefault,
          iconColor: OfferingTableDetailTokens.warmGold,
          collapsedIconColor: OfferingTableDetailTokens.muted,
          tilePadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(15, 0, 15, 16),
          title: Text(
            offeringTableEventTitle(day),
            style: const TextStyle(
              color: OfferingTableDetailTokens.mutedIvory,
              fontFamily: MaatFlowListTokens.fontFamily,
              fontFamilyFallback: MaatFlowListTokens.fontFallback,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1.15,
            ),
          ),
          subtitle: Text(
            '${day.section} · ${offeringTableTimingLabel(day)}',
            style: _bodyStyle(
              OfferingTableDetailTokens.muted,
            ).copyWith(fontSize: 11.5),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                offeringTableDetailText(day, lens: lens, noCupMode: noCupMode),
                style: _bodyStyle(OfferingTableDetailTokens.silver),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfferingDescription extends StatefulWidget {
  const _OfferingDescription({required this.overview});

  final String overview;

  @override
  State<_OfferingDescription> createState() => _OfferingDescriptionState();
}

class _OfferingDescriptionState extends State<_OfferingDescription> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextButton(
          key: const ValueKey<String>('offering-table-description-toggle'),
          style: TextButton.styleFrom(
            foregroundColor: OfferingTableDetailTokens.warmGold,
            alignment: Alignment.centerLeft,
            padding: EdgeInsets.zero,
          ),
          onPressed: () => setState(() => _expanded = !_expanded),
          child: Text(_expanded ? 'Hide full description' : 'Full description'),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 180),
          crossFadeState: _expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: const SizedBox.shrink(),
          secondChild: Text(
            widget.overview,
            style: _bodyStyle(OfferingTableDetailTokens.silver),
          ),
        ),
      ],
    );
  }
}

class _OfferingSeparator extends StatelessWidget {
  const _OfferingSeparator();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Divider(
        height: 1,
        thickness: 0.5,
        color: OfferingTableDetailTokens.separator,
      ),
    );
  }
}

class _OfferingSectionLabel extends StatelessWidget {
  const _OfferingSectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(
        label,
        style: const TextStyle(
          color: OfferingTableDetailTokens.warmGold,
          fontFamily: MaatFlowListTokens.fontFamily,
          fontFamilyFallback: MaatFlowListTokens.fontFallback,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.6,
          height: 1,
        ),
      ),
    );
  }
}

ButtonStyle _outlineButtonStyle({double minimumHeight = 52}) {
  return OutlinedButton.styleFrom(
    foregroundColor: OfferingTableDetailTokens.mutedIvory,
    backgroundColor: OfferingTableDetailTokens.deepBrown.withValues(
      alpha: 0.18,
    ),
    side: BorderSide(
      color: OfferingTableDetailTokens.warmGold.withValues(alpha: 0.32),
    ),
    minimumSize: Size.fromHeight(minimumHeight),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
    textStyle: const TextStyle(
      fontFamily: MaatFlowListTokens.fontFamily,
      fontFamilyFallback: MaatFlowListTokens.fontFallback,
      fontSize: 16,
      fontWeight: FontWeight.w500,
    ),
  );
}

TextStyle _bodyStyle(Color color) {
  return TextStyle(
    color: color,
    fontFamily: MaatFlowListTokens.fontFamily,
    fontFamilyFallback: MaatFlowListTokens.fontFallback,
    fontSize: 14,
    fontWeight: FontWeight.w300,
    height: 1.42,
  );
}
