import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'journal_v2_document_model.dart';

/// Drawing tool types
enum DrawingTool {
  pen,
  highlighter,
  eraser,
}

/// Drawing canvas with pen, highlighter, and eraser
class DrawingCanvas extends StatefulWidget {
  final DrawingBlock initialBlock;
  final Function(DrawingBlock) onChanged;
  final DrawingTool currentTool;
  final Color currentColor;
  final double currentWidth;

  const DrawingCanvas({
    Key? key,
    required this.initialBlock,
    required this.onChanged,
    this.currentTool = DrawingTool.pen,
    this.currentColor = Colors.white,
    this.currentWidth = 2.0,
  }) : super(key: key);

  @override
  State<DrawingCanvas> createState() => _DrawingCanvasState();
}

class _DrawingCanvasState extends State<DrawingCanvas> {
  DrawingBlock _currentBlock = DrawingBlock(id: '', strokes: []);
  List<Offset> _currentStrokePoints = [];
  ui.Picture? _cachedPicture;
  bool _needsRepaint = true;

  @override
  void initState() {
    super.initState();
    _currentBlock = widget.initialBlock;
  }

  @override
  void didUpdateWidget(DrawingCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialBlock != widget.initialBlock) {
      _currentBlock = widget.initialBlock;
      _needsRepaint = true;
    }
  }

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _currentStrokePoints = [details.localPosition];
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _currentStrokePoints.add(details.localPosition);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_currentStrokePoints.isEmpty) return;

    // Smooth the stroke using Catmull-Rom spline
    final smoothedPoints = _smoothStroke(_currentStrokePoints);

    // Create stroke object with proper StrokePoint conversion
    final stroke = DrawingStroke(
      points: smoothedPoints.map((p) => StrokePoint(x: p.dx, y: p.dy)).toList(),
      color: widget.currentTool == DrawingTool.highlighter
          ? widget.currentColor.withOpacity(0.25).value  // Get int value from Color
          : widget.currentColor.value,  // Get int value from Color
      width: widget.currentTool == DrawingTool.highlighter
          ? widget.currentWidth * 4
          : widget.currentWidth,
      tool: widget.currentTool == DrawingTool.pen ? 'pen' : 'highlighter',
    );

    // Add to block
    final newBlock = DrawingBlock(
      id: _currentBlock.id,
      strokes: [..._currentBlock.strokes, stroke],
      transform: _currentBlock.transform,
    );

    setState(() {
      _currentBlock = newBlock;
      _currentStrokePoints = [];
      _needsRepaint = true;
    });

    widget.onChanged(newBlock);
  }

  /// Smooth stroke using Catmull-Rom spline
  List<Offset> _smoothStroke(List<Offset> points) {
    if (points.length < 3) return points;

    final smoothed = <Offset>[];
    
    // Keep first point
    smoothed.add(points.first);

    // Smooth intermediate points
    for (int i = 1; i < points.length - 1; i++) {
      final p0 = i > 0 ? points[i - 1] : points[i];
      final p1 = points[i];
      final p2 = points[i + 1];
      final p3 = i < points.length - 2 ? points[i + 2] : points[i + 1];

      // Generate curve segments
      for (double t = 0; t < 1.0; t += 0.25) {
        final t2 = t * t;
        final t3 = t2 * t;

        final x = 0.5 * ((2 * p1.dx) +
            (-p0.dx + p2.dx) * t +
            (2 * p0.dx - 5 * p1.dx + 4 * p2.dx - p3.dx) * t2 +
            (-p0.dx + 3 * p1.dx - 3 * p2.dx + p3.dx) * t3);

        final y = 0.5 * ((2 * p1.dy) +
            (-p0.dy + p2.dy) * t +
            (2 * p0.dy - 5 * p1.dy + 4 * p2.dy - p3.dy) * t2 +
            (-p0.dy + 3 * p1.dy - 3 * p2.dy + p3.dy) * t3);

        smoothed.add(Offset(x, y));
      }
    }

    // Keep last point
    smoothed.add(points.last);

    return smoothed;
  }

  void _handleEraserTap(Offset position) {
    // Find and remove stroke at tap position
    for (int i = _currentBlock.strokes.length - 1; i >= 0; i--) {
      final stroke = _currentBlock.strokes[i];
      
      // Check if tap is within stroke bounds
      for (final point in stroke.points) {
        final distance = (Offset(point.x, point.y) - position).distance;
        if (distance < stroke.width + 10) {
          // Remove this stroke
          final newBlock = DrawingBlock(
            id: _currentBlock.id,
            strokes: _currentBlock.strokes.where((s) => s != stroke).toList(),
            transform: _currentBlock.transform,
          );

          setState(() {
            _currentBlock = newBlock;
            _needsRepaint = true;
          });

          widget.onChanged(newBlock);
          return;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: widget.currentTool == DrawingTool.eraser ? null : _onPanStart,
      onPanUpdate: widget.currentTool == DrawingTool.eraser ? null : _onPanUpdate,
      onPanEnd: widget.currentTool == DrawingTool.eraser ? null : _onPanEnd,
      onTapDown: widget.currentTool == DrawingTool.eraser
          ? (details) => _handleEraserTap(details.localPosition)
          : null,
      child: CustomPaint(
        painter: DrawingPainter(
          block: _currentBlock,
          currentStroke: _currentStrokePoints,
          currentColor: widget.currentTool == DrawingTool.highlighter
              ? widget.currentColor.withOpacity(0.25)
              : widget.currentColor,
          currentWidth: widget.currentTool == DrawingTool.highlighter
              ? widget.currentWidth * 4
              : widget.currentWidth,
          cachedPicture: _cachedPicture,
          needsRepaint: _needsRepaint,
        ),
        child: Container(color: Colors.transparent),
      ),
    );
  }
}

/// Custom painter for drawing strokes
class DrawingPainter extends CustomPainter {
  final DrawingBlock block;
  final List<Offset> currentStroke;
  final Color currentColor;
  final double currentWidth;
  final ui.Picture? cachedPicture;
  final bool needsRepaint;

  DrawingPainter({
    required this.block,
    required this.currentStroke,
    required this.currentColor,
    required this.currentWidth,
    this.cachedPicture,
    this.needsRepaint = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw cached strokes if available
    if (cachedPicture != null && !needsRepaint) {
      canvas.drawPicture(cachedPicture!);
    } else {
      // Draw all committed strokes
      for (final stroke in block.strokes) {
        final paint = Paint()
          ..color = Color(stroke.color)
          ..strokeWidth = stroke.width
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke;

        if (stroke.points.length > 1) {
          final path = Path();
          path.moveTo(stroke.points.first.x, stroke.points.first.y);
          
          for (int i = 1; i < stroke.points.length; i++) {
            path.lineTo(stroke.points[i].x, stroke.points[i].y);
          }

          canvas.drawPath(path, paint);
        }
      }
    }

    // Draw current stroke (in progress)
    if (currentStroke.isNotEmpty) {
      final paint = Paint()
        ..color = currentColor
        ..strokeWidth = currentWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      if (currentStroke.length > 1) {
        final path = Path();
        path.moveTo(currentStroke.first.dx, currentStroke.first.dy);
        
        for (int i = 1; i < currentStroke.length; i++) {
          path.lineTo(currentStroke[i].dx, currentStroke[i].dy);
        }

        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(DrawingPainter oldDelegate) {
    return needsRepaint ||
        currentStroke != oldDelegate.currentStroke ||
        block.strokes.length != oldDelegate.block.strokes.length;
  }
}
