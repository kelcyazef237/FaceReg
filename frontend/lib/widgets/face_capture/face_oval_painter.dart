import 'package:flutter/material.dart';

/// Paints an oval face guide with animated scan line and corner accents.
class FaceOvalPainter extends CustomPainter {
  const FaceOvalPainter({
    required this.progress,
    required this.color,
    this.scanLineY,
    this.showScanLine = false,
  });

  final double progress;
  final Color color;
  final double? scanLineY;
  final bool showScanLine;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final rx = size.width * 0.38;
    final ry = size.height * 0.46;

    final ovalRect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: rx * 2,
      height: ry * 2,
    );

    final outerPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final ovalPath = Path()..addOval(ovalRect);
    final dimPath = Path.combine(PathOperation.difference, outerPath, ovalPath);
    canvas.drawPath(dimPath, Paint()..color = Colors.black.withAlpha(140));

    final arcPaint = Paint()
      ..color = color.withAlpha(230)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(ovalRect, -1.5708, 6.2832 * progress, false, arcPaint);

    _drawCornerAccent(canvas, ovalRect, 0, color);
    _drawCornerAccent(canvas, ovalRect, 1, color);
    _drawCornerAccent(canvas, ovalRect, 2, color);
    _drawCornerAccent(canvas, ovalRect, 3, color);

    if (showScanLine && scanLineY != null) {
      final sy = ovalRect.top + ovalRect.height * scanLineY!;
      canvas.save();
      canvas.clipPath(ovalPath);
      canvas.drawLine(
        Offset(ovalRect.left, sy),
        Offset(ovalRect.right, sy),
        Paint()
          ..color = color.withAlpha(100)
          ..strokeWidth = 1.5,
      );
      final gradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withAlpha(0), color.withAlpha(20)],
      );
      canvas.drawRect(
        Rect.fromLTRB(ovalRect.left, ovalRect.top, ovalRect.right, sy),
        Paint()..shader = gradient.createShader(ovalRect),
      );
      canvas.restore();
    }
  }

  void _drawCornerAccent(Canvas canvas, Rect ovalRect, int corner, Color color) {
    const len = 20.0;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    const angleValues = <List<double>>[
      [-0.6, -0.6],
      [0.6, -0.6],
      [0.6, 0.6],
      [-0.6, 0.6],
    ];
    final a = angleValues[corner];
    final acx = ovalRect.center.dx + (ovalRect.width / 2) * a[0] * 0.9;
    final acy = ovalRect.center.dy + (ovalRect.height / 2) * a[1] * 0.9;

    final dx = a[0] > 0 ? -1.0 : 1.0;
    final dy = a[1] > 0 ? -1.0 : 1.0;

    canvas.drawLine(
      Offset(acx, acy),
      Offset(acx + dx * len * 0.7, acy),
      paint,
    );
    canvas.drawLine(
      Offset(acx, acy),
      Offset(acx, acy + dy * len * 0.7),
      paint,
    );
  }

  @override
  bool shouldRepaint(FaceOvalPainter old) =>
      old.progress != progress ||
      old.scanLineY != scanLineY ||
      old.showScanLine != showScanLine;
}
