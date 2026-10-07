import 'journal_recovery_action.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/navigation_fallback.dart';
import '../reflections/decan_review_views.dart';
import '../reflections/decan_review_widgets.dart';
import 'journal_controller.dart';
import 'journal_v2_document_model.dart';
import 'journal_badge_utils.dart';
import 'journal_v2_rich_text.dart';
import 'journal_v2_toolbar.dart';

/// A data-kind extension of the canonical Journal. Every Journal entry point
/// uses this owner for documents with decan contributions, preserving all blocks.
class JournalDocumentView extends StatefulWidget {
  const JournalDocumentView({
    super.key,
    required this.controller,
    required this.onClose,
  });
  final JournalController controller;
  final VoidCallback onClose;
  static bool containsDecan(JournalDocument? doc) =>
      doc?.blocks.any((b) => b.id.startsWith('decan_reflection:')) == true;
  @override
  State<JournalDocumentView> createState() => _JournalDocumentViewState();
}

class _JournalDocumentViewState extends State<JournalDocumentView> {
  String? _editing;
  final _text = TextEditingController();
  String? _notice;
  TextAttrs _attrs = const TextAttrs();
  VoidCallback? _oldDraft, _oldSync;
  @override
  void initState() {
    super.initState();
    _oldDraft = widget.controller.onDraftChanged;
    _oldSync = widget.controller.onSyncStatusChanged;
    widget.controller.onDraftChanged = _changed;
    widget.controller.onSyncStatusChanged = _syncChanged;
  }

  void _changed() {
    _oldDraft?.call();
    if (mounted) setState(() {});
  }

  void _syncChanged() {
    if (widget.controller.syncStatus == JournalSyncStatus.synced)
      _notice = null;
    _oldSync?.call();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.onDraftChanged = _oldDraft;
    widget.controller.onSyncStatusChanged = _oldSync;
    _text.dispose();
    super.dispose();
  }

  String _plain(ParagraphBlock b) => b.ops.map((o) => o.insert).join();
  Future<void> _editText(String id, String value) async {
    final doc = widget.controller.currentDocument!;
    await widget.controller.updateDocument(
      doc.copyWith(
        blocks: [
          for (final b in doc.blocks)
            if (b.id == id)
              ParagraphBlock(
                id: id,
                ops: [TextOp(insert: value)],
              )
            else
              b,
        ],
      ),
    );
  }

  Future<void> _save() async {
    final ok = await widget.controller.forceSave();
    if (!mounted) return;
    setState(() {
      if (ok) {
        _editing = null;
        _notice = null;
      } else {
        _notice =
            widget.controller.lastSyncError?.toString() ??
            'Your draft is kept on this device. Try saving again.';
      }
    });
  }

  Future<void> _remove(String id) async {
    final doc = widget.controller.currentDocument!;
    await widget.controller.updateDocument(
      doc.copyWith(blocks: doc.blocks.where((b) => b.id != id).toList()),
    );
    await _save();
  }

  String _date(DateTime d) =>
      '${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][d.month - 1]} ${d.day}';
  @override
  Widget build(BuildContext context) {
    final doc = widget.controller.currentDocument;
    final date = widget.controller.currentDate ?? DateTime.now();
    final today = DateUtils.isSameDay(date, DateTime.now());
    final rawSources = doc?.meta['decan_sources'];
    final sources = rawSources is Map ? rawSources : const {};
    var wrotePriorLabel = false;
    return DecanReviewCanvas(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: widget.onClose,
            child: Text('‹ Back', style: DecanReviewStyle.ui(12.5)),
          ),
        ),
        DecanReviewIntro(
          eyebrow: 'Journal',
          title: today ? 'Today' : _date(date),
          subtitle: 'Your writing, kept together.',
          compact: true,
        ),
        if (doc == null) const Center(child: CircularProgressIndicator()),
        if (doc != null)
          for (final block in doc.blocks) ...[
            if (block is ParagraphBlock &&
                block.id.startsWith('decan_reflection:'))
              ..._contribution(block, sources),
            if (block is ParagraphBlock &&
                !block.id.startsWith('decan_reflection:') &&
                (_plain(block).trim().isNotEmpty || _editing == block.id)) ...[
              if (!wrotePriorLabel)
                Builder(
                  builder: (_) {
                    wrotePriorLabel = true;
                    return DecanReviewLabel(
                      today ? 'Earlier today' : 'Your writing',
                    );
                  },
                ),
              if (_editing == block.id) ...[
                RichTextEditor(
                  key: ValueKey('journal-paragraph-${block.id}'),
                  initialBlock: block,
                  currentAttrs: _attrs,
                  transparentDecoration: true,
                  textStyle: DecanReviewStyle.serif(23, height: 1.42),
                  onChanged: (next) => unawaited(
                    widget.controller.updateDocument(
                      doc.copyWith(
                        blocks: [
                          for (final b in doc.blocks)
                            b.id == next.id ? next : b,
                        ],
                      ),
                    ),
                  ),
                ),
                JournalV2Toolbar(
                  controller: widget.controller,
                  compact: true,
                  onFormatChanged: (a) => setState(() => _attrs = a),
                  onModeChanged: (_) {},
                  onUndo: () {},
                  onRedo: () {},
                  onInsertChart: () {},
                ),
                DecanReviewButton(
                  'Save writing',
                  onPressed: () => unawaited(_save()),
                  quiet: true,
                ),
              ] else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: SelectableText.rich(
                    TextSpan(
                      style: DecanReviewStyle.serif(
                        23,
                        color: DecanReviewStyle.soft,
                        height: 1.42,
                      ),
                      children: [
                        for (final op in block.ops)
                          TextSpan(
                            text: JournalBadgeUtils.stripBadges(op.insert),
                            style: TextStyle(
                              fontWeight: op.attrs?.bold == true
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              fontStyle: op.attrs?.italic == true
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                              decoration: TextDecoration.combine([
                                if (op.attrs?.underline == true)
                                  TextDecoration.underline,
                                if (op.attrs?.strikethrough == true)
                                  TextDecoration.lineThrough,
                              ]),
                              color: _color(op.attrs?.color),
                              backgroundColor: _color(
                                op.attrs?.backgroundColor,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => setState(() => _editing = block.id),
                    child: Text('Edit writing', style: DecanReviewStyle.ui(12)),
                  ),
                ),
              ],
            ],
            if (block is DrawingBlock)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Semantics(
                  label: 'Journal drawing',
                  image: true,
                  child: AspectRatio(
                    aspectRatio: 1.25,
                    child: CustomPaint(painter: _JournalDrawingPainter(block)),
                  ),
                ),
              ),
            if (block is ChartBlock) ...[
              Text(block.options.title, style: DecanReviewStyle.serif(23)),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: [
                    const DataColumn(label: Text('')),
                    for (final series in block.data.series)
                      DataColumn(label: Text(series.name)),
                  ],
                  rows: [
                    for (var i = 0; i < block.data.labels.length; i++)
                      DataRow(
                        cells: [
                          DataCell(Text(block.data.labels[i])),
                          for (final series in block.data.series)
                            DataCell(
                              Text(
                                i < series.values.length
                                    ? '${series.values[i]}'
                                    : '—',
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ],
        DecanReviewButton(
          'Write in Journal',
          quiet: true,
          onPressed: () async {
            if (doc == null) return;
            final block = ParagraphBlock(
              id: 'p-${DateTime.now().microsecondsSinceEpoch}',
              ops: const [TextOp(insert: '')],
            );
            setState(() => _editing = block.id);
            await widget.controller.updateDocument(
              doc.copyWith(blocks: [...doc.blocks, block]),
            );
          },
        ),
        JournalRecoveryAction(controller: widget.controller),
        if (_notice != null) DecanReviewNotice(_notice!),
        const DecanReviewFooter('Private, unless you choose to post.'),
      ],
    );
  }

  List<Widget> _contribution(ParagraphBlock block, Map sources) {
    final id = block.id.substring('decan_reflection:'.length);
    final raw = sources[id];
    final meta = raw is Map ? raw : const {};
    final start = DateTime.tryParse(meta['start']?.toString() ?? '');
    final end = DateTime.tryParse(meta['end']?.toString() ?? '');
    final editing = _editing == block.id;
    final question = meta['question'] as String? ?? 'Your decan reflection';
    return [
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Divider(color: DecanReviewStyle.line, height: 1),
      ),
      DecanJournalContribution(
        response: _plain(block),
        question: question,
        rangeLabel: start == null || end == null
            ? 'Days 1–10'
            : '${_date(start)}–${_date(end)}',
        days: (meta['days'] as List? ?? const [])
            .whereType<num>()
            .map((d) => d.toInt())
            .where((d) => d >= 1 && d <= 10)
            .toSet(),
        onReflection: () =>
            unawaited(openDetailRoute(context, '/reflections/$id')),
        onEdit: () {
          setState(() {
            _editing = block.id;
            _text.text = _plain(block);
            _notice = null;
          });
        },
        onPost: () =>
            unawaited(openDetailRoute(context, '/reflections/$id?compose=1')),
        answerController: editing ? _text : null,
        onAnswerChanged: (s) => unawaited(_editText(block.id, s)),
        onSave: () => unawaited(_save()),
        saving: widget.controller.syncStatus == JournalSyncStatus.saving,
        pending: widget.controller.syncStatus == JournalSyncStatus.saveFailed,
      ),
      if (editing) ...[
        const DecanReviewNotice(
          'If you shared these words, removing them from Journal leaves your post in place. Open your reflection to manage the post.',
        ),
        DecanReviewButton(
          'Remove these words from Journal',
          onPressed: () => unawaited(_remove(block.id)),
          quiet: true,
        ),
      ],
    ];
  }

  Color? _color(String? raw) {
    if (raw == null) return null;
    final hex = raw.replaceFirst('#', '');
    final v = int.tryParse(hex, radix: 16);
    return v == null ? null : Color(hex.length == 6 ? 0xff000000 | v : v);
  }
}

/// Uses the same stroke/path construction as the existing Kꜣr drawing renderer,
/// retaining each stored stroke's width, color, tool and document transform.
class _JournalDrawingPainter extends CustomPainter {
  _JournalDrawingPainter(this.block);
  final DrawingBlock block;
  @override
  void paint(Canvas canvas, Size size) {
    final points = block.strokes.expand((s) => s.points).toList();
    if (points.isEmpty) return;
    final maxX = points.fold<double>(1, (a, p) => math.max(a, p.x + 12));
    final maxY = points.fold<double>(1, (a, p) => math.max(a, p.y + 12));
    final scale = math.min(size.width / maxX, size.height / maxY);
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.scale(scale);
    final transform = block.transform;
    if (transform != null) {
      canvas.translate(transform.translateX, transform.translateY);
      canvas.rotate(transform.rotation);
      canvas.scale(transform.scaleX, transform.scaleY);
    }
    for (final stroke in block.strokes) {
      if (stroke.points.isEmpty) continue;
      final paint = Paint()
        ..color = Color(stroke.color)
        ..strokeWidth = stroke.width
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      if (stroke.tool == 'eraser') paint.blendMode = BlendMode.clear;
      if (stroke.tool == 'highlighter')
        paint.color = paint.color.withValues(alpha: .35);
      if (stroke.points.length == 1) {
        canvas.drawCircle(
          Offset(stroke.points.first.x, stroke.points.first.y),
          stroke.width / 2,
          paint,
        );
        continue;
      }
      final path = Path()..moveTo(stroke.points.first.x, stroke.points.first.y);
      for (final point in stroke.points.skip(1)) {
        path.lineTo(point.x, point.y);
      }
      canvas.drawPath(path, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_JournalDrawingPainter oldDelegate) =>
      oldDelegate.block != block;
}
