import 'pages_sheet_graphic.dart';
import '../calendar/calendar_page.dart'
    show buildCalendarMonthCardPreview, MonthExpansionLevel;
import '../../widgets/kemetic_date_picker.dart' show KemeticMath;
import 'package:flutter/material.dart';
import '../profile/posted_flow_artifact.dart';
import '../rhythm/widgets/planner/maat_scale.dart';
import '../rhythm/planner/planner_scale_math.dart';
import '../../widgets/profile_avatar.dart';
import 'pages_models.dart';

const pagesGold = Color(0xffd4af37);
const pagesBone = Color(0xfff2ece0);
TextStyle pagesSerif(
  double size, {
  Color color = pagesBone,
  bool italic = false,
}) => TextStyle(
  fontFamily: 'CormorantGaramond',
  fontSize: size,
  fontWeight: FontWeight.w400,
  fontStyle: italic ? FontStyle.italic : FontStyle.normal,
  height: 1.12,
  color: color,
);

/// Geometry shared by every board; selection never changes pane positions.
class PagesBoard extends StatelessWidget {
  const PagesBoard({
    super.key,
    required this.large,
    required this.upper,
    required this.lower,
  });
  final Widget large, upper, lower;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xff050403),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 2, child: large),
        const SizedBox(width: 2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: upper),
              const SizedBox(height: 2),
              Expanded(child: lower),
            ],
          ),
        ),
      ],
    ),
  );
}

class PagesTile extends StatelessWidget {
  const PagesTile({super.key, required this.card, required this.onTap});
  final PagesCard card;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Open ${card.title}',
    value: _accessibleSummary,
    excludeSemantics: true,
    onTap: onTap,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1.49,
            child: RepaintBoundary(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (card.state != PagesLoadState.ready &&
                        card.destination == PagesDestination.calendar)
                      _signal(
                        PagesSignal(
                          card.state == PagesLoadState.failed
                              ? 'Unavailable'
                              : 'Loading…',
                        ),
                      )
                    else if (card.state != PagesLoadState.ready)
                      PagesBoard(
                        large: _signal(
                          PagesSignal(
                            card.state == PagesLoadState.failed
                                ? 'Unavailable'
                                : 'Loading…',
                          ),
                        ),
                        upper: _signal(const PagesSignal('')),
                        lower: _signal(const PagesSignal('')),
                      )
                    else if (card.destination == PagesDestination.calendar)
                      _calendar()
                    else
                      PagesBoard(
                        large: _large(),
                        upper: _upper(),
                        lower: _lower(),
                      ),
                    IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: pagesBone.withValues(alpha: .06),
                          ),
                        ),
                      ),
                    ),
                    if (card.unread > 0)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(minWidth: 20),
                          decoration: BoxDecoration(
                            color: const Color(0xffc73b3b),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${card.unread}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
            child: Text(
              card.title,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 18 / 14,
                color: pagesBone,
              ),
              maxLines: 1,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 2, 6, 0),
            child: Text(
              _caption.isEmpty ? ' ' : _caption,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 10.5,
                height: 15 / 10.5,
                color: Color(0xffb8b2a7),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    ),
  );

  // Presentation only: retain every selected signal for assistive technology.
  String get _accessibleSummary => [
    card.meta,
    for (final f in card.companionFlows) f.name,
    if (card.flow != null) ...[
      card.flow!.name,
      if (card.flow!.total > 0)
        '${card.flow!.completed} of ${card.flow!.total} steps',
    ],
    for (final signal in [card.primary, card.upper, card.lower]) ...[
      signal.label,
      signal.title,
      signal.status,
      signal.detail,
      if (signal.progress != null) '${signal.progress!.round()}%',
    ],
    if (card.unread > 0) '${card.unread} unread',
    if (card.week.isNotEmpty)
      '${card.week.where((v) => v).length} days this week',
  ].where((v) => v.isNotEmpty).join(', ');

  String get _caption {
    if (card.state != PagesLoadState.ready) return card.meta;
    return switch (card.destination) {
      PagesDestination.inbox =>
        card.unread > 0 ? '${card.unread} new' : 'No new updates',
      PagesDestination.studio => '',
      _ => card.meta,
    };
  }

  Widget _flowPicture(PagesFlow f, {bool lead = false}) => PagesSheetGraphic(
    key: ValueKey('pages-sheet-${lead ? "lead" : f.id}'),
    flow: f,
  );

  Widget _companion(int index) => card.companionFlows.length > index
      ? _flowPicture(card.companionFlows[index])
      : const ColoredBox(color: Color(0xff090b0f));

  Widget _large() {
    switch (card.destination) {
      case PagesDestination.feed:
        final f = card.flow;
        if (f == null) return _signal(card.primary);
        return LayoutBuilder(
          builder: (context, box) => PostedFlowArtifact(
            artworkOnly: true,
            allowImageFetch: false,
            imageCacheWidth:
                (box.maxWidth * MediaQuery.devicePixelRatioOf(context)).ceil(),
            name: f.name,
            color: f.color,
            appearance: f.appearance,
            localImageBytes: f.imageBytes,
            startDate: f.start,
            endDate: f.end,
          ),
        );
      case PagesDestination.planner:
        final percent = card.primary.progress;
        if (percent == null) return _signal(card.primary);
        return _ground(
          const Color(0xff100d08),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 55,
                child: OverflowBox(
                  maxWidth: 210,
                  minWidth: 210,
                  child: MaatScale(
                    animate: false,
                    showBacklight: false,
                    tiltDegrees: plannerScaleTiltDegrees(percent.round()),
                    progress: percent / 100,
                  ),
                ),
              ),
            ],
          ),
        );
      case PagesDestination.studio:
        final f = card.flow;
        if (f == null) return _signal(card.primary);
        return _flowPicture(f, lead: true);
      case PagesDestination.journal:
        return _ground(
          const Color(0xff0b0911),
          Padding(
            padding: const EdgeInsets.all(11),
            child: _fitPane(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Color(card.primary.color).withValues(alpha: .14),
                      border: Border.all(color: Color(card.primary.color)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (card.primary.status.isNotEmpty) ...[
                              Icon(
                                switch (card.primary.status) {
                                  '✓' => Icons.check,
                                  '◐' => Icons.incomplete_circle_rounded,
                                  _ => Icons.remove,
                                },
                                size: 16,
                                color: Color(card.primary.color),
                              ),
                              const SizedBox(width: 5),
                            ],
                            Expanded(
                              child: Text(
                                card.primary.title,
                                style: pagesSerif(
                                  14,
                                  color: const Color(0xfff2cf63),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      case PagesDestination.library:
        return _ground(
          const Color(0xff110e08),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(child: Center(child: _glyph(card.primary.glyph, 44))),
                if (card.primary.progress != null)
                  LinearProgressIndicator(
                    value: card.primary.progress! / 100,
                    minHeight: 2,
                    color: pagesGold,
                    backgroundColor: const Color(0xff4b412c),
                  ),
              ],
            ),
          ),
        );
      case PagesDestination.inbox:
        return _signal(
          card.primary,
          large: true,
          avatar: card.primary.detail.isNotEmpty,
          base: const Color(0xff0f0c07),
          ink: const Color(0xfff0e5c8),
          pictureOnly: true,
        );
      case PagesDestination.calendars:
        return _signal(
          card.primary,
          large: true,
          base: const Color(0xff0b0a12),
          ink: const Color(0xffc3b8ff),
          pictureOnly: true,
        );
      case PagesDestination.calendar:
        return _calendar();
    }
  }

  Widget _upper() {
    if (card.destination == PagesDestination.studio) return _companion(0);
    if (card.destination == PagesDestination.planner) {
      return _ground(
        const Color(0xff100d08),
        Center(
          child: SizedBox(
            width: 34,
            height: 34,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: (card.primary.progress ?? 0) / 100,
                  color: pagesGold,
                  backgroundColor: const Color(0xff3d3420),
                  strokeWidth: 3,
                ),
                _glyph('𓆄', 18),
              ],
            ),
          ),
        ),
      );
    }
    if (card.destination == PagesDestination.journal) {
      final draft = card.upper.detail == 'Unsaved draft';
      final saved = card.upper.detail == '✓ Saved';
      return _ground(
        const Color(0xff141006),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Opacity(opacity: saved || draft ? 1 : .4, child: _glyph('𓏞', 30)),
          ],
        ),
      );
    }
    return _signal(
      card.upper,
      pictureOnly: true,
      base: switch (card.destination) {
        PagesDestination.studio => const Color(0xff090c10),
        PagesDestination.calendars => const Color(0xff07110d),
        PagesDestination.inbox => const Color(0xff0d0b07),
        PagesDestination.journal => const Color(0xff141006),
        _ => const Color(0xff0d0b08),
      },
      ink: switch (card.destination) {
        PagesDestination.studio => const Color(0xffc9d5e2),
        PagesDestination.calendars => const Color(0xff7fdcbc),
        PagesDestination.journal => const Color(0xffd7c49a),
        _ => const Color(0xffdcb850),
      },
      avatar:
          card.destination == PagesDestination.inbox ||
          card.destination == PagesDestination.feed,
    );
  }

  Widget _lower() {
    if (card.destination == PagesDestination.studio) return _companion(1);
    if (card.destination == PagesDestination.planner) {
      final day = (KemeticMath.fromGregorian(DateTime.now()).kDay - 1) % 10;
      return _ground(
        const Color(0xff100d08),
        Center(
          child: SizedBox(
            width: 46,
            child: Wrap(
              spacing: 4,
              runSpacing: 5,
              children: [
                for (var i = 0; i < 10; i++)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == day
                          ? pagesGold
                          : i < day
                          ? const Color(0xff8a7336)
                          : const Color(0xff4a3d22),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }
    if (card.destination == PagesDestination.journal) {
      return _ground(
        const Color(0xff0d0a06),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: card.week
                  .map(
                    (on) => Container(
                      width: 4,
                      height: on ? 24 : 7,
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      decoration: BoxDecoration(
                        color: on ? pagesGold : const Color(0xff4d4127),
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      );
    }
    if (card.destination == PagesDestination.calendars) {
      return _ground(
        const Color(0xff0d0b08),
        Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: 39,
              child: Wrap(
                spacing: 5,
                runSpacing: 4,
                children: card.calendars
                    .map(
                      (c) => Opacity(
                        opacity: c.visible ? 1 : .35,
                        child: Container(
                          width: 17,
                          height: 10,
                          padding: const EdgeInsets.all(1),
                          decoration: BoxDecoration(
                            color: Color(c.color).withValues(alpha: .3),
                            border: Border.all(color: Color(c.color)),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          alignment: c.visible
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(c.color),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ),
      );
    }
    if (card.destination == PagesDestination.library &&
        card.lower.progress != null) {
      return _ground(
        const Color(0xff0e0c08),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 34,
              height: 34,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: card.lower.progress! / 100,
                    color: pagesGold,
                    backgroundColor: const Color(0xff3d3420),
                    strokeWidth: 3,
                  ),
                  if (card.lower.glyph.isNotEmpty) _glyph(card.lower.glyph, 16),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return _signal(
      card.lower,
      pictureOnly: true,
      base: switch (card.destination) {
        PagesDestination.feed => const Color(0xff07110e),
        PagesDestination.inbox => const Color(0xff07110d),
        PagesDestination.studio => const Color(0xff090b0f),
        PagesDestination.library => const Color(0xff111009),
        _ => const Color(0xff0c0a06),
      },
      ink: switch (card.destination) {
        PagesDestination.feed => const Color(0xffd3e5d9),
        PagesDestination.inbox => const Color(0xff6fd0ae),
        PagesDestination.studio => const Color(0xffc9d5e2),
        _ => const Color(0xffdcc37c),
      },
      titleSize: card.destination == PagesDestination.studio ? 23 : null,
    );
  }

  Widget _calendar() {
    final date = card.calendarDate;
    if (date == null) return _signal(const PagesSignal('Loading calendar…'));
    final k = KemeticMath.fromGregorian(date);
    return _ground(
      const Color(0xff0c0a06),
      IgnorePointer(
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: 390,
            child: buildCalendarMonthCardPreview(
              kYear: k.kYear,
              kMonth: k.kMonth,
              todayDay: k.kDay,
              expansionLevel: MonthExpansionLevel.compact,
              showGregorian: card.showGregorian,
              notesForDay: (day) => card.calendarNotes[day] ?? const [],
              colorsForDay: (day) =>
                  (card.days.where((d) => d.day == day).firstOrNull?.colors ??
                          const <int>[])
                      .map(Color.new)
                      .toList(),
              flowNameForNote: (note) => card.calendarFlowNames[note.flowId],
            ),
          ),
        ),
      ),
    );
  }
}

// Each role has an explicit dark base. No shared glow or overlay lifts panes.
Widget _ground(Color color, Widget child) =>
    ColoredBox(color: color, child: child);
Widget _micro(String value, {bool tracked = false}) => Text(
  value,
  textAlign: TextAlign.center,
  maxLines: 2,
  overflow: TextOverflow.ellipsis,
  style: TextStyle(
    fontFamily: tracked ? 'Inter' : 'GentiumPlus',
    fontSize: tracked ? 6 : 8,
    height: 1.2,
    letterSpacing: tracked ? 1 : .1,
    color: tracked ? const Color(0xff9b8a5e) : const Color(0xffa39d92),
  ),
);
Widget _glyph(String value, double size) => Text(
  value,
  style: TextStyle(
    fontFamily: 'Noto Sans Egyptian Hieroglyphs',
    fontSize: size,
    color: pagesGold,
    height: 1,
  ),
);
Widget _signal(
  PagesSignal s, {
  bool large = false,
  bool avatar = false,
  Color base = const Color(0xff0f0c08),
  Color ink = const Color(0xffdcc37c),
  double? titleSize,
  bool pictureOnly = false,
  bool showDetail = false,
}) => _ground(
  base,
  Padding(
    padding: EdgeInsets.all(large ? 6 : 4),
    child: LayoutBuilder(
      builder: (context, box) => FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: box.maxWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (s.people.isNotEmpty) ...[
                _memberCoins(s.people, large ? 32 : 23),
                const SizedBox(height: 6),
              ] else if (avatar && s.title.isNotEmpty && s.glyph.isEmpty) ...[
                _memberCoins([
                  PagesPerson(s.title, glyphIds: s.glyphIds),
                ], large ? 42 : 28),
                const SizedBox(height: 4),
              ],
              if (s.glyph.isNotEmpty) ...[
                Text(
                  s.glyph,
                  style: TextStyle(
                    fontFamily: 'Noto Sans Egyptian Hieroglyphs',
                    fontSize: large ? 30 : 22,
                    height: 1,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 3),
              ],
              if (s.label.toLowerCase() == 'complete')
                Icon(Icons.check, color: ink, size: 15),
              if (pictureOnly && s.people.isEmpty && s.glyph.isEmpty && !avatar)
                Icon(
                  s.label == 'Commons'
                      ? Icons.groups_outlined
                      : s.label.toLowerCase() == 'complete'
                      ? Icons.bookmark_outline
                      : Icons.auto_stories_outlined,
                  color: ink,
                  size: large ? 34 : 25,
                ),
              if (!pictureOnly)
                Text(
                  s.label == 'Commons' ? 'Commons' : s.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: pagesSerif(titleSize ?? (large ? 16 : 11), color: ink),
                ),
              if (showDetail && s.detail.isNotEmpty) ...[
                const SizedBox(height: 3),
                _micro(s.detail),
              ],
            ],
          ),
        ),
      ),
    ),
  ),
);

Widget _fitPane(Widget child) => LayoutBuilder(
  builder: (context, box) => FittedBox(
    fit: BoxFit.scaleDown,
    child: SizedBox(width: box.maxWidth, child: child),
  ),
);

Widget _memberCoins(List<PagesPerson> people, double diameter) {
  final shown = people.take(3).toList();
  return SizedBox(
    width: diameter + (shown.length - 1) * (diameter - 9),
    height: diameter,
    child: Stack(
      children: [
        for (var i = 0; i < shown.length; i++)
          Positioned(
            left: i * (diameter - 9),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: Alignment(-.32, -.44),
                  radius: .8,
                  stops: [0, .4, .88],
                  colors: [
                    Color(0xfffbe7a4),
                    Color(0xffdcb44b),
                    Color(0xff9c7420),
                  ],
                ),
              ),
              child: ProfileAvatar(
                displayName: shown[i].name,
                avatarGlyphIds: shown[i].glyphIds,
                radius: diameter / 2,
                backgroundColor: Colors.transparent,
                foregroundColor: const Color(0xff171006),
                initialFontSize: 13,
                borderColor: const Color(0xff0f0c08),
                borderWidth: 1.5,
              ),
            ),
          ),
      ],
    ),
  );
}
