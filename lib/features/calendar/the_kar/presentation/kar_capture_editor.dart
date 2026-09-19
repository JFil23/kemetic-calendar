import 'dart:convert';

import 'package:flutter/material.dart';

import '../../maat_flow_visual_tokens.dart';
import '../the_kar_models.dart';

class KarCaptureEditor extends StatefulWidget {
  const KarCaptureEditor({
    super.key,
    required this.netjer,
    required this.stageIndex,
    required this.initialDraft,
    required this.onSaveDraft,
    required this.onPlace,
    this.placed = false,
    this.initialMode,
    this.showHeading = true,
    this.showModeSwitcher = true,
    this.showPlaceAction = true,
    this.onSaved,
  });

  final KarNetjer netjer;
  final int stageIndex;
  final KarDraft? initialDraft;
  final Future<void> Function(String kind, String content) onSaveDraft;
  final Future<void> Function() onPlace;
  final bool placed;
  final String? initialMode;
  final bool showHeading;
  final bool showModeSwitcher;
  final bool showPlaceAction;
  final VoidCallback? onSaved;

  @override
  State<KarCaptureEditor> createState() => _KarCaptureEditorState();
}

class _KarCaptureEditorState extends State<KarCaptureEditor> {
  late final TextEditingController _controller;
  final List<List<Offset>> _strokes = <List<Offset>>[];
  bool _draw = false;
  bool _saving = false;
  bool _hasDraft = false;

  @override
  void initState() {
    super.initState();
    final draft = widget.initialDraft;
    _draw =
        widget.initialMode == 'drawing' ||
        (widget.initialMode == null && draft?.kind == 'drawing');
    _controller = TextEditingController(
      text: draft?.kind == 'description' ? draft?.content : '',
    );
    _hasDraft = draft != null && draft.content.trim().isNotEmpty;
    if (draft?.kind == 'drawing') _restoreStrokes(draft!.content);
  }

  void _restoreStrokes(String raw) {
    try {
      final decoded = jsonDecode(raw) as List;
      for (final strokeRaw in decoded) {
        final stroke = <Offset>[];
        for (final pointRaw in strokeRaw as List) {
          final point = pointRaw as List;
          stroke.add(
            Offset((point[0] as num).toDouble(), (point[1] as num).toDouble()),
          );
        }
        if (stroke.isNotEmpty) _strokes.add(stroke);
      }
    } catch (_) {}
  }

  String _drawingJson() => jsonEncode([
    for (final stroke in _strokes)
      [
        for (final point in stroke) <double>[point.dx, point.dy],
      ],
  ]);

  Future<void> _save() async {
    final content = _draw ? _drawingJson() : _controller.text.trim();
    if ((_draw && _strokes.isEmpty) || (!_draw && content.isEmpty)) return;
    setState(() => _saving = true);
    try {
      await widget.onSaveDraft(_draw ? 'drawing' : 'description', content);
      if (mounted) {
        setState(() => _hasDraft = true);
        widget.onSaved?.call();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = Color(widget.netjer.accentValue);
    return Container(
      key: ValueKey<String>('kar-capture-editor-${widget.stageIndex}'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF070706),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: .25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (widget.showHeading) ...<Widget>[
            Text(
              'KEEP THE SCENE',
              style: _text(const Color(0xFF8A7030), 10, spacing: 1.4),
            ),
            const SizedBox(height: 10),
          ],
          if (widget.showModeSwitcher) ...<Widget>[
            SegmentedButton<bool>(
              segments: const <ButtonSegment<bool>>[
                ButtonSegment<bool>(value: false, label: Text('Describe')),
                ButtonSegment<bool>(value: true, label: Text('Draw')),
              ],
              selected: <bool>{_draw},
              onSelectionChanged: (value) =>
                  setState(() => _draw = value.first),
              style: ButtonStyle(
                foregroundColor: WidgetStateProperty.all(
                  Color(widget.netjer.accent2Value),
                ),
                side: WidgetStateProperty.all(
                  BorderSide(color: accent.withValues(alpha: .4)),
                ),
                textStyle: WidgetStateProperty.all(
                  _text(Color(widget.netjer.accent2Value), 13),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (_draw)
            _DrawingPad(
              strokes: _strokes,
              color: Color(widget.netjer.accent2Value),
              onChanged: () => setState(() => _hasDraft = false),
            )
          else
            TextField(
              key: const ValueKey<String>('kar-describe-field'),
              controller: _controller,
              minLines: 5,
              maxLines: 8,
              textInputAction: TextInputAction.newline,
              onChanged: (_) => setState(() => _hasDraft = false),
              style: _text(const Color(0xFFE8E2D6), 17, height: 1.35),
              decoration: InputDecoration(
                hintText: 'I picture…',
                hintStyle: _text(
                  const Color(0xFF5C5953),
                  17,
                  style: FontStyle.italic,
                ),
                filled: true,
                fillColor: const Color(0xFF050504),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(color: accent.withValues(alpha: .22)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(color: accent.withValues(alpha: .55)),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            _draw
                ? 'Bad drawings welcome.'
                : 'Describe what you picture. No explanation needed.',
            style: _text(
              const Color(0xFF625E57),
              11,
              style: FontStyle.italic,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          if (widget.showPlaceAction)
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    key: const ValueKey<String>('kar-save-draft'),
                    onPressed: _saving ? null : _save,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Color(widget.netjer.accent2Value),
                      side: BorderSide(color: accent.withValues(alpha: .45)),
                    ),
                    child: Text(
                      _saving
                          ? 'Saving…'
                          : _draw
                          ? 'Save drawing'
                          : 'Save description',
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: FilledButton(
                    key: const ValueKey<String>('kar-place-draft'),
                    onPressed: _hasDraft && !_saving ? widget.onPlace : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFD4AE43),
                      foregroundColor: const Color(0xFF050504),
                    ),
                    child: Text(
                      widget.placed ? 'Replace in the kꜣr' : 'Place in the kꜣr',
                    ),
                  ),
                ),
              ],
            )
          else
            OutlinedButton(
              key: const ValueKey<String>('kar-save-draft'),
              onPressed: _saving ? null : _save,
              style: OutlinedButton.styleFrom(
                foregroundColor: Color(widget.netjer.accent2Value),
                side: BorderSide(color: accent.withValues(alpha: .45)),
                minimumSize: const Size.fromHeight(44),
              ),
              child: Text(
                _saving
                    ? 'Saving…'
                    : _draw
                    ? 'Save drawing'
                    : 'Save description',
              ),
            ),
          const SizedBox(height: 6),
          Text(
            'One is enough. Saving keeps a draft; Place commits this scene.',
            textAlign: TextAlign.center,
            style: _text(
              const Color(0xFF625E57),
              10.5,
              style: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawingPad extends StatelessWidget {
  const _DrawingPad({
    required this.strokes,
    required this.color,
    required this.onChanged,
  });
  final List<List<Offset>> strokes;
  final Color color;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Column(
    children: <Widget>[
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          TextButton(
            onPressed: strokes.isEmpty
                ? null
                : () {
                    strokes.removeLast();
                    onChanged();
                  },
            child: const Text('Undo'),
          ),
          TextButton(
            onPressed: strokes.isEmpty
                ? null
                : () {
                    strokes.clear();
                    onChanged();
                  },
            child: const Text('Clear'),
          ),
        ],
      ),
      GestureDetector(
        key: const ValueKey<String>('kar-drawing-pad'),
        onPanStart: (details) {
          strokes.add(<Offset>[details.localPosition]);
          onChanged();
        },
        onPanUpdate: (details) {
          if (strokes.isNotEmpty) strokes.last.add(details.localPosition);
          onChanged();
        },
        child: Container(
          height: 285,
          decoration: BoxDecoration(
            color: const Color(0xFF050504),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: const Color(0x22E8E2D6)),
          ),
          clipBehavior: Clip.antiAlias,
          child: CustomPaint(
            painter: _DrawingPainter(strokes: strokes, color: color),
            size: Size.infinite,
          ),
        ),
      ),
    ],
  );
}

class _DrawingPainter extends CustomPainter {
  const _DrawingPainter({required this.strokes, required this.color});
  final List<List<Offset>> strokes;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final stroke in strokes) {
      if (stroke.length == 1) {
        canvas.drawCircle(stroke.first, 1.5, paint);
        continue;
      }
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (final point in stroke.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DrawingPainter oldDelegate) => true;
}

TextStyle _text(
  Color color,
  double size, {
  double? spacing,
  double? height,
  FontStyle? style,
}) => TextStyle(
  color: color,
  fontFamily: KarFlowVisualTokens.fontFamily,
  fontFamilyFallback: KarFlowVisualTokens.fontFallback,
  fontSize: size,
  letterSpacing: spacing,
  height: height,
  fontStyle: style,
);
