import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile/features/calendar/maat_flow_visual_tokens.dart';
import 'package:mobile/features/calendar/presentation/maat_flow_detail_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

@immutable
class ArchivedMaatFlowEventFixture {
  const ArchivedMaatFlowEventFixture({
    required this.dateLabel,
    required this.title,
    required this.status,
  });

  final String dateLabel;
  final String title;
  final String status;
}

@immutable
class ArchivedMaatFlowResponseFixture {
  const ArchivedMaatFlowResponseFixture({
    required this.prompt,
    required this.response,
  });

  final String prompt;
  final String response;
}

@immutable
class ArchivedMaatFlowFixture {
  const ArchivedMaatFlowFixture({
    required this.flowKey,
    required this.title,
    required this.glyph,
    required this.dateRange,
    required this.events,
    required this.responses,
    this.ended = false,
  });

  final String flowKey;
  final String title;
  final String glyph;
  final String dateRange;
  final List<ArchivedMaatFlowEventFixture> events;
  final List<ArchivedMaatFlowResponseFixture> responses;
  final bool ended;
}

const ArchivedMaatFlowFixture
kArchivedMaatFlowVisualFixture = ArchivedMaatFlowFixture(
  flowKey: 'dawn-house-rite',
  title: 'Dawn House Rite',
  glyph: '𓇳',
  dateRange: 'Aug 12–Aug 18, 2026',
  events: <ArchivedMaatFlowEventFixture>[
    ArchivedMaatFlowEventFixture(
      dateLabel: 'AUG 12',
      title: 'Open the eastern room',
      status: 'Observed',
    ),
    ArchivedMaatFlowEventFixture(
      dateLabel: 'AUG 15',
      title: 'Meet the first light',
      status: 'Partly',
    ),
    ArchivedMaatFlowEventFixture(
      dateLabel: 'AUG 18',
      title: 'Carry dawn forward',
      status: 'Skipped',
    ),
  ],
  responses: <ArchivedMaatFlowResponseFixture>[
    ArchivedMaatFlowResponseFixture(
      prompt: 'What arrived with the light?',
      response:
          'A quieter beginning than I expected, and enough room to notice it.',
    ),
  ],
);

abstract final class ArchivedMaatFlowTokens {
  static const Color page = Color(0xFF060604);
  static const Color sheet = Color(0xFF0C0A07);
  static const Color gold = Color(0xFFD4AE43);
  static const Color bone = Color(0xFFE8E1D3);
  static const Color silver = Color(0xFF9A958C);
  static const Color low = Color(0xFF6E6961);
  static const Color separator = Color(0xFF2A2419);

  static const MaatFlowDetailTheme theme = MaatFlowDetailTheme(
    pageBackground: page,
    sheetBackground: sheet,
    sheetBorder: Color(0x665B4B28),
    accent: gold,
    primaryText: bone,
    secondaryText: silver,
    mutedText: low,
    separator: separator,
    glow: Color(0xFFE7C66C),
  );
}

/// Generic, read-only compatibility presentation for retired flow records.
///
/// The active implementation supplies decoded dates, events, and preserved
/// responses. This visual owns no scheduler, join path, or legacy state store.
class ArchivedMaatFlowDetailView extends StatefulWidget {
  const ArchivedMaatFlowDetailView({
    super.key,
    this.fixture = kArchivedMaatFlowVisualFixture,
    this.legacyLocalStateFlowId,
    this.onBack,
    this.onEndOrLeave,
    this.onDismiss,
  });

  final ArchivedMaatFlowFixture fixture;
  final int? legacyLocalStateFlowId;
  final VoidCallback? onBack;
  final VoidCallback? onEndOrLeave;
  final VoidCallback? onDismiss;

  @override
  State<ArchivedMaatFlowDetailView> createState() =>
      _ArchivedMaatFlowDetailViewState();
}

class _ArchivedMaatFlowDetailViewState
    extends State<ArchivedMaatFlowDetailView> {
  List<ArchivedMaatFlowResponseFixture> _localResponses =
      const <ArchivedMaatFlowResponseFixture>[];

  @override
  void initState() {
    super.initState();
    _loadLocalResponses();
  }

  @override
  void didUpdateWidget(covariant ArchivedMaatFlowDetailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fixture.flowKey != widget.fixture.flowKey ||
        oldWidget.legacyLocalStateFlowId != widget.legacyLocalStateFlowId) {
      _localResponses = const <ArchivedMaatFlowResponseFixture>[];
      _loadLocalResponses();
    }
  }

  Future<void> _loadLocalResponses() async {
    final flowId = widget.legacyLocalStateFlowId;
    if (flowId == null || flowId <= 0) return;
    final responses = await ArchivedMaatFlowLocalStateReader.load(
      flowKey: widget.fixture.flowKey,
      flowId: flowId,
    );
    if (!mounted) return;
    setState(() => _localResponses = responses);
  }

  ArchivedMaatFlowFixture get _fixture {
    if (_localResponses.isEmpty) return widget.fixture;
    final seen = <String>{};
    final responses = <ArchivedMaatFlowResponseFixture>[];
    for (final response in <ArchivedMaatFlowResponseFixture>[
      ...widget.fixture.responses,
      ..._localResponses,
    ]) {
      final identity = '${response.prompt}\u0000${response.response}';
      if (seen.add(identity)) responses.add(response);
    }
    return ArchivedMaatFlowFixture(
      flowKey: widget.fixture.flowKey,
      title: widget.fixture.title,
      glyph: widget.fixture.glyph,
      dateRange: widget.fixture.dateRange,
      events: widget.fixture.events,
      responses: List<ArchivedMaatFlowResponseFixture>.unmodifiable(responses),
      ended: widget.fixture.ended,
    );
  }

  @override
  Widget build(BuildContext context) {
    final fixture = _fixture;
    return Scaffold(
      backgroundColor: ArchivedMaatFlowTokens.page,
      body: Stack(
        children: <Widget>[
          MaatFlowDetailShell(
            theme: ArchivedMaatFlowTokens.theme,
            referenceHeroHeight: 258,
            referenceSheetOverlap: 26,
            scrollKey: const ValueKey<String>('archived-flow-scroll'),
            heroLayerKey: const ValueKey<String>('archived-flow-hero-layer'),
            sheetKey: const ValueKey<String>('archived-flow-sheet'),
            hero: _ArchivedHero(fixture: fixture),
            sheet: _ArchivedBody(
              fixture: fixture,
              onEndOrLeave: widget.onEndOrLeave,
              onDismiss: widget.onDismiss,
            ),
          ),
          Positioned(
            left: 4,
            top: MediaQuery.paddingOf(context).top + 4,
            child: BackButton(
              key: const ValueKey<String>('archived-flow-back'),
              color: ArchivedMaatFlowTokens.gold,
              onPressed: widget.onBack ?? () => popMaatFlowDetailOrGo(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small read-only bridge for the retired flows that historically kept user
/// answers in SharedPreferences. It never mutates or migrates those values.
abstract final class ArchivedMaatFlowLocalStateReader {
  static const Map<String, String> _prefixByFlowKey = <String, String>{
    'the-kept-word': 'kept_word_',
    'the-tending': 'tending_',
    'the-wag': 'the_wag_',
    'the-days-outside-the-year': 'days_outside_',
  };

  static Future<List<ArchivedMaatFlowResponseFixture>> load({
    required String flowKey,
    required int flowId,
    SharedPreferences? preferences,
  }) async {
    final basePrefix = _prefixByFlowKey[flowKey.trim()];
    if (basePrefix == null || flowId <= 0) {
      return const <ArchivedMaatFlowResponseFixture>[];
    }
    final prefs = preferences ?? await SharedPreferences.getInstance();
    final prefix = '$basePrefix${flowId}_';
    final keys =
        prefs
            .getKeys()
            .where((key) => key.startsWith(prefix))
            .toList(growable: false)
          ..sort();
    return List<ArchivedMaatFlowResponseFixture>.unmodifiable(
      <ArchivedMaatFlowResponseFixture>[
        for (final key in keys)
          if (_responseFor(key, prefix, prefs.get(key)) case final response?)
            response,
      ],
    );
  }

  static ArchivedMaatFlowResponseFixture? _responseFor(
    String key,
    String prefix,
    Object? raw,
  ) {
    if (raw == null) return null;
    final response = _readableValue(raw);
    if (response.isEmpty || response == 'false') return null;
    final suffix = key.substring(prefix.length);
    return ArchivedMaatFlowResponseFixture(
      prompt: _readableLabel(suffix),
      response: response == 'true' ? 'Completed' : response,
    );
  }

  static String _readableLabel(String suffix) {
    final withoutPrompt = suffix.startsWith('prompt_')
        ? suffix.substring('prompt_'.length)
        : suffix;
    final words = withoutPrompt
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .trim()
        .split(RegExp(r'\s+'));
    if (words.isEmpty || words.first.isEmpty) return 'Saved response';
    final label = words.join(' ');
    return '${label[0].toUpperCase()}${label.substring(1)}';
  }

  static String _readableValue(Object raw) {
    if (raw is List<String>) {
      return raw.where((value) => value.isNotEmpty).join('\n');
    }
    if (raw is! String) return raw.toString().trim();
    final text = raw.trim();
    if (text.isEmpty) return '';
    try {
      return _flattenJson(jsonDecode(text));
    } catch (_) {
      return text;
    }
  }

  static String _flattenJson(Object? value) {
    if (value is List) {
      return value
          .map(_flattenJson)
          .where((item) => item.isNotEmpty)
          .join('\n');
    }
    if (value is Map) {
      return value.entries
          .map((entry) {
            final nested = _flattenJson(entry.value);
            return nested.isEmpty
                ? ''
                : '${_readableLabel(entry.key.toString())}: $nested';
          })
          .where((item) => item.isNotEmpty)
          .join('\n');
    }
    return value?.toString().trim() ?? '';
  }
}

class _ArchivedHero extends StatelessWidget {
  const _ArchivedHero({required this.fixture});

  final ArchivedMaatFlowFixture fixture;

  @override
  Widget build(BuildContext context) {
    return MaatFlowDetailHero(
      theme: ArchivedMaatFlowTokens.theme,
      contentBottom: 30,
      glyphToTitleSpacing: 10,
      titleFontSize: 42,
      subtitleSpacing: 6,
      subtitleWidth: 255,
      subtitleFontSize: 15,
      glyph: fixture.glyph,
      title: fixture.title,
      subtitle: 'Preserved history · no new sittings',
      glyphGradient: const RadialGradient(
        center: Alignment(-0.3, -0.4),
        colors: <Color>[
          Color(0xFF67552D),
          Color(0xFF241D10),
          Color(0xFF090704),
        ],
      ),
      background: const DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.58, -0.55),
            radius: 1.15,
            colors: <Color>[
              Color(0xFF403315),
              Color(0xFF171208),
              Color(0xFF060604),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArchivedBody extends StatelessWidget {
  const _ArchivedBody({
    required this.fixture,
    this.onEndOrLeave,
    this.onDismiss,
  });

  final ArchivedMaatFlowFixture fixture;
  final VoidCallback? onEndOrLeave;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _Handle(),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 6, 22, 22),
          child: _ArchiveNotice(ended: fixture.ended),
        ),
        const Divider(height: 1, color: ArchivedMaatFlowTokens.separator),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const _Label('ORIGINAL DATES'),
              const SizedBox(height: 7),
              Text(fixture.dateRange, style: _display(fontSize: 22)),
              const SizedBox(height: 28),
              Text('Historical events', style: _display(fontSize: 29)),
              const SizedBox(height: 12),
              if (fixture.events.isEmpty)
                const _EmptyHistory('No historical events were preserved.')
              else
                for (final event in fixture.events)
                  _ArchivedEventRow(event: event),
              const SizedBox(height: 28),
              Text('Saved responses', style: _display(fontSize: 29)),
              const SizedBox(height: 12),
              if (fixture.responses.isEmpty)
                const _EmptyHistory('No saved responses for this flow.')
              else
                for (final response in fixture.responses)
                  _ArchivedResponseCard(response: response),
              const SizedBox(height: 26),
              const Text(
                'Journal entries and completion history stay where you left them.',
                style: TextStyle(
                  color: ArchivedMaatFlowTokens.low,
                  fontFamily: 'GentiumPlus',
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      key: const ValueKey<String>('archived-flow-end-leave'),
                      onPressed: onEndOrLeave,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ArchivedMaatFlowTokens.gold,
                        side: const BorderSide(
                          color: ArchivedMaatFlowTokens.separator,
                        ),
                        textStyle: const TextStyle(
                          fontFamily: MaatFlowListTokens.fontFamily,
                          fontSize: 15,
                        ),
                      ),
                      child: Text(fixture.ended ? 'Leave history' : 'End Flow'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextButton(
                      key: const ValueKey<String>('archived-flow-dismiss'),
                      onPressed: onDismiss,
                      style: TextButton.styleFrom(
                        foregroundColor: ArchivedMaatFlowTokens.silver,
                        textStyle: const TextStyle(
                          fontFamily: MaatFlowListTokens.fontFamily,
                          fontSize: 15,
                        ),
                      ),
                      child: const Text('Dismiss'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ArchiveNotice extends StatelessWidget {
  const _ArchiveNotice({required this.ended});

  final bool ended;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('archived-flow-notice'),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF151108),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFF4B3C1D)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.inventory_2_outlined,
            size: 19,
            color: ArchivedMaatFlowTokens.gold,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  ended ? 'Ended · archived' : 'This flow is archived',
                  style: _display(fontSize: 19),
                ),
                const SizedBox(height: 4),
                const Text(
                  'You can revisit what happened here, but this flow no longer creates or schedules new events.',
                  style: TextStyle(
                    color: ArchivedMaatFlowTokens.silver,
                    fontFamily: 'GentiumPlus',
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ArchivedEventRow extends StatelessWidget {
  const _ArchivedEventRow({required this.event});

  final ArchivedMaatFlowEventFixture event;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: ArchivedMaatFlowTokens.separator),
        ),
      ),
      child: Row(
        children: <Widget>[
          SizedBox(width: 58, child: _Label(event.dateLabel)),
          Expanded(child: Text(event.title, style: _display(fontSize: 18))),
          const SizedBox(width: 8),
          Text(
            event.status,
            style: const TextStyle(
              color: ArchivedMaatFlowTokens.silver,
              fontFamily: 'GentiumPlus',
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _ArchivedResponseCard extends StatelessWidget {
  const _ArchivedResponseCard({required this.response});

  final ArchivedMaatFlowResponseFixture response;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0D09),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: ArchivedMaatFlowTokens.separator),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            response.prompt,
            style: _display(
              fontSize: 16,
              color: ArchivedMaatFlowTokens.silver,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 9),
          Text(response.response, style: _display(fontSize: 18, height: 1.25)),
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Text(
        message,
        style: _display(
          fontSize: 16,
          color: ArchivedMaatFlowTokens.low,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 31,
      child: Align(
        alignment: Alignment(0, -0.25),
        child: SizedBox(
          width: 42,
          height: 4,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0xFF403827),
              borderRadius: BorderRadius.all(Radius.circular(99)),
            ),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: ArchivedMaatFlowTokens.gold,
        fontFamily: 'GentiumPlus',
        fontSize: 9,
        letterSpacing: 1.4,
      ),
    );
  }
}

TextStyle _display({
  required double fontSize,
  Color color = ArchivedMaatFlowTokens.bone,
  FontStyle? fontStyle,
  double? height,
}) {
  return TextStyle(
    color: color,
    fontFamily: MaatFlowListTokens.fontFamily,
    fontFamilyFallback: MaatFlowListTokens.fontFallback,
    fontSize: fontSize,
    fontStyle: fontStyle,
    height: height,
  );
}
