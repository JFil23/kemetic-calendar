import 'package:mobile/core/theme/app_fonts.dart';
import '../profile/commons_practice_card.dart';
import '../profile/commons_question_block.dart';
import '../rhythm/widgets/planner/planner_note_text.dart';
import 'pages_feed_rotation.dart';
import '../profile/commons_rhythm_block.dart';
import 'pages_studio_graphic.dart';
import '../journal/journal_badges_area.dart';
import '../rhythm/widgets/planner/planner_visual_tokens.dart';
import '../calendar/calendar_completion.dart';
import '../../core/completion_status.dart';
import 'pages_feature_previews.dart';
import '../calendar/calendar_page.dart'
    show buildCalendarMonthCardPreview, MonthExpansionLevel;
import '../../widgets/kemetic_date_picker.dart' show KemeticMath;
import 'package:flutter/material.dart';
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
                    ColorFiltered(
                      colorFilter: const ColorFilter.matrix([
                        1.110236,
                        -.100128,
                        -.010108,
                        0,
                        0,
                        -.029764,
                        1.039872,
                        -.010108,
                        0,
                        0,
                        -.029764,
                        -.100128,
                        1.129892,
                        0,
                        0,
                        0,
                        0,
                        0,
                        1,
                        0,
                      ]),
                      child: _preview(),
                    ),
                    IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: const Alignment(0, -.2),
                            radius: .8,
                            colors: [
                              _accent.withValues(alpha: .09),
                              Colors.transparent,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _accent.withValues(alpha: .15),
                          ),
                        ),
                      ),
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
                              fontFamily: AppFonts.ui,
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
            padding: const EdgeInsets.fromLTRB(10.6, 7.5, 6, 0),
            child: Text(
              card.title.toUpperCase(),
              style: PlannerVisualTokens.plateLabelStyle.copyWith(
                fontSize: 7.7,
                letterSpacing: 2.8,
                color: pagesBone,
                height: 1.3,
              ),
              maxLines: 1,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10.6, 4, 6, 0),
            child: Text(
              card.meta.isEmpty ? ' ' : card.meta,
              style: PlannerVisualTokens.inputHint.copyWith(
                fontSize: 11.2,
                color: const Color(0xffa39d92),
                height: 1.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _preview() {
    if (card.state != PagesLoadState.ready) {
      return _signal(
        PagesSignal(
          card.state == PagesLoadState.failed ? 'Unavailable' : 'Loading…',
        ),
      );
    }
    if (card.destination == PagesDestination.calendar) return _calendar();
    if (card.destination == PagesDestination.calendars) {
      return PagesBoard(large: _large(), upper: _upper(), lower: _lower());
    }
    return _large();
  }

  Color get _accent => switch (card.destination) {
    PagesDestination.studio => const Color(0xff258eea),
    PagesDestination.journal ||
    PagesDestination.calendars => const Color(0xff8e7cff),
    PagesDestination.inbox => const Color(0xffedc956),
    PagesDestination.library => const Color(0xffdcbc62),
    _ => pagesGold,
  };
  Widget _large() {
    switch (card.destination) {
      case PagesDestination.feed:
        if (card.feedDisplay == PagesFeedDisplay.answer &&
            card.answer != null) {
          return CommonsAnswerCard(
            answer: card.answer!,
            pane: true,
            onAction: (_) {},
          );
        }
        if (card.feedDisplay == PagesFeedDisplay.practice &&
            card.practice != null) {
          return CommonsPracticeCard(room: card.practice!, pane: true);
        }
        return card.feedDisplay == PagesFeedDisplay.publicRhythm &&
                card.rhythm != null
            ? CommonsRhythmBlock(summary: card.rhythm, pane: true)
            : PagesQuestionPreview(question: card.question);
      case PagesDestination.planner:
        if (card.plannerDisplay != PagesPlannerDisplay.scale) {
          return _ground(
            const Color(0xff100d08),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _micro(card.primary.label.toUpperCase(), tracked: true),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Center(
                      child: card.plannerDisplay == PagesPlannerDisplay.note
                          ? PlannerNoteText(
                              card.primary.title,
                              fontSize: 18,
                              maxLines: 3,
                            )
                          : Text(
                              card.primary.title,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: PlannerVisualTokens.plateBody.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  if (card.primary.detail.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      card.primary.detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: pagesSerif(11, color: const Color(0xffb0b0b0)),
                    ),
                  ],
                ],
              ),
            ),
          );
        }
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
              Text(
                '${percent.round()}%',
                style: pagesSerif(28, color: const Color(0xffecd48f)),
              ),
              const SizedBox(height: 4),
              _micro('ALIGNED', tracked: true),
            ],
          ),
        );
      case PagesDestination.studio:
        final f = card.flow;
        if (f == null) return _signal(card.primary);
        return _ground(
          const Color(0xff07080d),
          Column(
            children: [
              Expanded(
                child: PagesStudioGraphic(
                  flow: f,
                  event: card.event,
                  snapshot: card.studioSnapshot,
                ),
              ),
              IgnorePointer(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(9, 3, 9, 9),
                  child: CalendarCompletionPicker(
                    current:
                        card.studioSnapshot?.completion ??
                        CompletionStatus.none,
                    onChanged: (_) {},
                    style: const CalendarCompletionPickerStyle(
                      label: '',
                      labelGap: 0,
                      containerPadding: EdgeInsets.zero,
                      containerColor: Colors.transparent,
                      containerBorderColor: Colors.transparent,
                      containerBorderWidth: 0,
                      buttonGap: 4,
                      buttonRadius: 7,
                      buttonFontFamily: 'GentiumPlus',
                      buttonFontSize: 9,
                      buttonFontWeight: FontWeight.w400,
                      buttonPadding: EdgeInsets.zero,
                      buttonMinimumSize: Size(0, 24),
                      buttonTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      buttonVisualDensity: VisualDensity.compact,
                      unselectedForegroundColor: Color(0xFFB6BAC5),
                      unselectedBorderColor: Color(0xFF303440),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      case PagesDestination.journal:
        return IgnorePointer(
          child: LayoutBuilder(
            builder: (context, box) => JournalBadgesArea(
              pane: true,
              height: box.maxHeight,
              badges: card.badges,
            ),
          ),
        );
      case PagesDestination.library:
        return _ground(
          const Color(0xff110e08),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: Center(child: _glyph(card.primary.glyph, 38))),
                const SizedBox(height: 5),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        card.primary.title,
                        style: pagesSerif(18, color: const Color(0xffe6c86f)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (card.primary.progress != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        '${card.primary.progress!.round()}%',
                        style: pagesSerif(11, color: const Color(0xffa39d92)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 7),
                if (card.primary.progress != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: card.primary.progress! / 100,
                      minHeight: 2,
                      color: pagesGold,
                      backgroundColor: const Color(0xff39301e),
                    ),
                  ),
              ],
            ),
          ),
        );
      case PagesDestination.inbox:
        return _signal(
          card.primary,
          large: true,
          avatar: true,
          base: const Color(0xff0f0c07),
          ink: const Color(0xfff0e5c8),
          titleSize: 13.5,
        );
      case PagesDestination.calendars:
        return _ground(
          const Color(0xff0b0a12),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (card.primary.people.isNotEmpty)
                  _memberCoins(card.primary.people, 25),
                const SizedBox(height: 8),
                Text(
                  card.primary.title,
                  textAlign: TextAlign.center,
                  style: pagesSerif(17, color: const Color(0xffc3b8ff)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  card.primary.detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: pagesSerif(10, color: const Color(0xffa39d92)),
                ),
              ],
            ),
          ),
        );
      case PagesDestination.calendar:
        return _calendar();
    }
  }

  Widget _upper() => card.destination == PagesDestination.calendars
      ? _ground(
          const Color(0xff07110d),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (card.upper.glyph.isNotEmpty)
                  Text(
                    card.upper.glyph,
                    style: const TextStyle(
                      fontFamily: 'Noto Sans Egyptian Hieroglyphs',
                      fontSize: 23,
                      height: 1,
                      color: Color(0xff7fdcbc),
                    ),
                  ),
                const SizedBox(height: 3),
                Flexible(
                  child: Text(
                    card.upper.title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: pagesSerif(11, color: const Color(0xff7fdcbc)),
                  ),
                ),
              ],
            ),
          ),
        )
      : _signal(
          card.upper,
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
  Widget _lower() {
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
            const SizedBox(height: 5),
            _micro('this week'),
          ],
        ),
      );
    }
    if (card.destination == PagesDestination.calendars) {
      return _ground(
        const Color(0xff0d0b08),
        Center(
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
                  Text(
                    '${card.lower.progress!.round()}%',
                    style: pagesSerif(11),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            _micro(card.lower.title),
          ],
        ),
      );
    }
    return _signal(
      card.lower,
      large: card.destination == PagesDestination.studio,
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
    fontFamily: tracked ? AppFonts.ui : 'GentiumPlus',
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
              if (s.label.isNotEmpty) ...[
                _micro(s.label.toUpperCase(), tracked: true),
                const SizedBox(height: 3),
              ],
              if (s.people.isNotEmpty) ...[
                _memberCoins(s.people, large ? 25 : 20),
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
              Text(
                s.title,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: pagesSerif(titleSize ?? (large ? 16 : 11), color: ink),
              ),
              if (s.detail.isNotEmpty) ...[
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
