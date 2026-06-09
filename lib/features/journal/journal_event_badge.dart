import 'package:flutter/material.dart';
import 'package:mobile/core/completion_status.dart';
import 'package:mobile/core/touch_targets.dart';
import 'package:mobile/shared/glossy_text.dart';

const Gradient _eventBadgeGoldGloss = LinearGradient(
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
  colors: [
    Color(0xFFFFF1BF),
    Color(0xFFF2CF63),
    Color(0xFFFFF8D9),
    Color(0xFFF4D97A),
  ],
  stops: [0.0, 0.34, 0.62, 1.0],
);

/// Snapshot of an event when it was added to the journal.
/// Stored as plain-text token and rendered inline via WidgetSpan.
class EventBadgeToken {
  final String id;
  final String? eventId;
  final String title;
  final DateTime? start;
  final DateTime? end;
  final Color color;
  final String? description;
  final CompletionStatus completionStatus;
  final CompletionSourceType? sourceType;

  const EventBadgeToken({
    required this.id,
    this.eventId,
    required this.title,
    this.start,
    this.end,
    required this.color,
    this.description,
    this.completionStatus = CompletionStatus.observed,
    this.sourceType,
  });

  static EventBadgeToken? parse(String raw) {
    final kv = <String, String>{};
    final regex = RegExp(r'(\w+)=(("[^"]*")|[^\s]+)', dotAll: true);
    for (final m in regex.allMatches(raw)) {
      final key = m.group(1);
      var val = m.group(2);
      if (key == null || val == null) continue;
      if (val.startsWith('"') && val.endsWith('"')) {
        val = val.substring(1, val.length - 1);
      }
      kv[key] = val;
    }

    final id = kv['id'] ?? kv['badgeId'];
    final title = kv['title'];
    final startStr = kv['start'];
    final endStr = kv['end'];
    final colorStr = kv['color'];
    final descStr = kv['description'] ?? kv['desc'];
    final completionStatus = CompletionStatusX.fromWireName(
      kv['completionStatus'] ?? kv['completion_status'] ?? kv['status'],
    );
    CompletionSourceType? sourceType;
    final rawSourceType = kv['sourceType'] ?? kv['source_type'];
    for (final value in CompletionSourceType.values) {
      if (value.wireName == rawSourceType) {
        sourceType = value;
        break;
      }
    }

    if (id == null || title == null || colorStr == null) return null;

    DateTime? parseDt(String? s) {
      if (s == null || s.isEmpty) return null;
      try {
        return DateTime.parse(s).toLocal();
      } catch (_) {
        return null;
      }
    }

    Color parseColor(String hex) {
      var h = hex.replaceFirst('#', '');
      if (h.length == 6) {
        h = 'FF$h';
      }
      final intColor = int.tryParse(h, radix: 16) ?? 0xFFFFC145;
      return Color(intColor);
    }

    String unescape(String s) => s.replaceAll('\\n', '\n');

    return EventBadgeToken(
      id: id,
      eventId: kv['eventId'],
      title: unescape(title),
      start: parseDt(startStr),
      end: parseDt(endStr),
      color: parseColor(colorStr),
      description: descStr != null ? unescape(descStr) : null,
      completionStatus: completionStatus == CompletionStatus.none
          ? CompletionStatus.observed
          : completionStatus,
      sourceType: sourceType,
    );
  }

  static String buildToken({
    required String id,
    String? eventId,
    required String title,
    DateTime? start,
    DateTime? end,
    required Color color,
    String? description,
    CompletionStatus completionStatus = CompletionStatus.observed,
    CompletionSourceType? sourceType,
  }) {
    String fmt(DateTime? dt) => dt?.toUtc().toIso8601String() ?? '';
    String hex(Color c) => '#${c.toARGB32().toRadixString(16).padLeft(8, '0')}';
    String esc(String s) => s.replaceAll('"', '\\"').replaceAll('\n', '\\n');

    final buffer = StringBuffer('⟦EVENT_BADGE ');
    buffer.write('id=$id ');
    if (eventId != null) buffer.write('eventId=$eventId ');
    buffer.write('title="${esc(title)}" ');
    final s = fmt(start);
    if (s.isNotEmpty) buffer.write('start="$s" ');
    final e = fmt(end);
    if (e.isNotEmpty) buffer.write('end="$e" ');
    if (description != null && description.trim().isNotEmpty) {
      buffer.write('description="${esc(description)}" ');
    }
    if (completionStatus != CompletionStatus.observed) {
      buffer.write('completionStatus=${completionStatus.wireName} ');
    }
    if (sourceType != null) {
      buffer.write('sourceType=${sourceType.wireName} ');
    }
    buffer.write('color="${hex(color)}"');
    buffer.write('⟧');
    return buffer.toString();
  }
}

IconData _badgeIconFor(CompletionStatus status) {
  switch (status) {
    case CompletionStatus.partial:
      return Icons.adjust_rounded;
    case CompletionStatus.skipped:
      return Icons.remove_circle_outline_rounded;
    case CompletionStatus.none:
    case CompletionStatus.observed:
      return Icons.check_circle;
  }
}

class EventBadgeWidget extends StatefulWidget {
  final EventBadgeToken token;
  final bool initialExpanded;
  final bool expandable;
  final ValueChanged<bool>? onToggle;

  const EventBadgeWidget({
    super.key,
    required this.token,
    this.initialExpanded = false,
    this.expandable = true,
    this.onToggle,
  });

  @override
  State<EventBadgeWidget> createState() => _EventBadgeWidgetState();
}

class _EventBadgeWidgetState extends State<EventBadgeWidget>
    with TickerProviderStateMixin {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initialExpanded;
  }

  @override
  void didUpdateWidget(covariant EventBadgeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialExpanded != widget.initialExpanded) {
      _expanded = widget.initialExpanded;
    }
  }

  void _toggle() {
    if (!widget.expandable) return;
    final next = !_expanded;
    setState(() => _expanded = next);
    widget.onToggle?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.of(context).size.width - 32;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: maxWidth.clamp(120.0, double.infinity),
      ),
      child: _expanded && widget.expandable
          ? _ExpandedEventBadge(token: widget.token, onTap: _toggle)
          : _CollapsedEventBadge(token: widget.token, onTap: _toggle),
    );
  }
}

class _CollapsedEventBadge extends StatelessWidget {
  final EventBadgeToken token;
  final VoidCallback onTap;

  const _CollapsedEventBadge({required this.token, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = token.color;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: minimumTouchTargetConstraints(context, minSize: 38),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withValues(alpha: 0.9), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _badgeIconFor(token.completionStatus),
                size: 14,
                color: color.withValues(alpha: 0.95),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: GlossyText(
                  text: token.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  gradient: _eventBadgeGoldGloss,
                  style:
                      Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ) ??
                      const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                ),
              ),
              if (token.start != null) ...[
                const SizedBox(width: 6),
                Text(
                  _shortTime(token.start!),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    color: Theme.of(
                      context,
                    ).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpandedEventBadge extends StatelessWidget {
  final EventBadgeToken token;
  final VoidCallback onTap;

  const _ExpandedEventBadge({required this.token, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = token.color;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: minimumTouchTargetConstraints(context),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.9), width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(9),
                        bottomLeft: Radius.circular(9),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _badgeIconFor(token.completionStatus),
                              size: 14,
                              color: color.withValues(alpha: 0.95),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: GlossyText(
                                text: token.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                softWrap: false,
                                gradient: _eventBadgeGoldGloss,
                                style:
                                    Theme.of(
                                      context,
                                    ).textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ) ??
                                    const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (token.start != null)
                          Text(
                            _formatRange(token.start, token.end),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  fontSize: 11,
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.color
                                      ?.withValues(alpha: 0.75),
                                ),
                          ),
                        if (token.description != null &&
                            token.description!.trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            token.description!,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _formatRange(DateTime? start, DateTime? end) {
  if (start == null) return '';
  final startStr = _shortTime(start);
  if (end == null) return startStr;
  final endStr = _shortTime(end);
  return '$startStr – $endStr';
}

String _shortTime(DateTime dt) {
  final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
  final m = dt.minute.toString().padLeft(2, '0');
  final suffix = dt.hour >= 12 ? 'p' : 'a';
  return '$h:$m$suffix';
}
