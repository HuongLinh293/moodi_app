import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// A continuous sheet that curls into itself. Faces are depth-sorted so folded
/// edges cover the writing instead of fading it under a shrinking polygon.
class CrumpledPaper extends StatelessWidget {
  final double amount;
  final String text;
  final bool reducedMotion;
  const CrumpledPaper({
    super.key,
    required this.amount,
    this.text = '',
    this.reducedMotion = false,
  });

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween<double>(begin: 0, end: amount),
    duration: Duration(milliseconds: reducedMotion ? 0 : 320),
    curve: Curves.easeInOutCubic,
    builder: (context, value, _) => CustomPaint(
      painter: _SheetPainter(value, text),
      size: const Size(240, 230),
    ),
  );
}

class _Point {
  final double x, y, z;
  const _Point(this.x, this.y, this.z);
  Offset get xy => Offset(x, y);
}

class _Face {
  final _Point a, b, c;
  final bool ink;
  _Face(this.a, this.b, this.c, this.ink);
  double get depth => (a.z + b.z + c.z) / 3;
}

class _SheetPainter extends CustomPainter {
  final double amount;
  final String text;
  const _SheetPainter(this.amount, this.text);
  static const divisions = 42;

  _Point _point(double u, double v) {
    final t = amount.clamp(0.0, 1.0);
    final r = math.sqrt(u * u + v * v);
    final angle = math.atan2(v, u);
    // Edges gather first. Unequal curl around the sheet avoids a uniform ball.
    final gather = Curves.easeInOut.transform(t);
    final curl = gather * r * (2.1 + .21 * math.sin(angle * 3 + .5));
    final sphericalR = r < .0001 ? 0.0 : math.sin(curl) * 59;
    final blend = (t * 1.6).clamp(0.0, 1.0);
    var x = u * 86 * (1 - blend) + math.cos(angle) * sphericalR * blend;
    var y = v * 102 * (1 - blend) + math.sin(angle) * sphericalR * blend;
    var z = (math.cos(curl) - 1) * 56 * blend;
    // Persistent creases, activated in stages rather than regenerated per frame.
    final wrinkle = math.pow(t, 1.2).toDouble();
    final ridge = math.sin(u * 17 + v * 8 + 1.2) * math.sin(v * 15 - u * 6);
    final fine = math.sin(u * 34 + v * 21) * math.sin(v * 27 - u * 13);
    z += (ridge * 9 + fine * 2.8) * wrinkle;
    x += math.sin(v * 17 + u * 7) * 3.5 * wrinkle;
    y += math.sin(u * 16 - v * 9) * 3.5 * wrinkle;
    // A small twist follows the folds, without rocking the whole object.
    final rotation = .13 * t;
    return _Point(
      x * math.cos(rotation) - y * math.sin(rotation),
      x * math.sin(rotation) + y * math.cos(rotation),
      z,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = amount.clamp(0.0, 1.0);
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, 107 - t * 40),
        width: 138 - t * 40,
        height: 11 + t * 7,
      ),
      Paint()
        ..color = const Color(0x30372F24)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );
    final grid = List.generate(
      divisions + 1,
      (y) => List.generate(
        divisions + 1,
        (x) => _point(x / divisions * 2 - 1, y / divisions * 2 - 1),
      ),
    );
    final faces = <_Face>[];
    final hasWriting = text.trim().isNotEmpty;
    for (var y = 0; y < divisions; y++) {
      for (var x = 0; x < divisions; x++) {
        final a = grid[y][x],
            b = grid[y][x + 1],
            c = grid[y + 1][x],
            d = grid[y + 1][x + 1];
        final ink =
            hasWriting &&
            y > 5 &&
            y < 20 &&
            y % 4 == 2 &&
            x > 4 &&
            x < 22 - y % 3;
        faces.add(_Face(a, b, d, ink));
        faces.add(_Face(a, d, c, ink));
      }
    }
    faces.sort((a, b) => a.depth.compareTo(b.depth));
    final lighting = <_Point, Color>{};
    for (var y = 0; y <= divisions; y++) {
      for (var x = 0; x <= divisions; x++) {
        final u = x / divisions * 2 - 1, v = y / divisions * 2 - 1;
        final l = _point(u - .006, v), r = _point(u + .006, v);
        final top = _point(u, v - .006), bottom = _point(u, v + .006);
        final ux = r.x - l.x, uy = r.y - l.y, uz = r.z - l.z;
        final vx = bottom.x - top.x,
            vy = bottom.y - top.y,
            vz = bottom.z - top.z;
        final nx = uy * vz - uz * vy,
            ny = uz * vx - ux * vz,
            nz = ux * vy - uy * vx;
        final length = math.sqrt(nx * nx + ny * ny + nz * nz);
        final light = length < .00001
            ? 1.0
            : ((-.32 * nx - .46 * ny + .83 * nz) * (nz < 0 ? -1 : 1) / length)
                  .clamp(0.0, 1.0);
        lighting[grid[y][x]] = Color.lerp(
          const Color(0xFFAAA397),
          const Color(0xFFFFFEF9),
          .22 + .78 * light,
        )!;
      }
    }
    final positions = <Offset>[];
    final colors = <Color>[];
    for (final face in faces) {
      for (final p in [face.a, face.b, face.c]) {
        positions.add(p.xy);
        colors.add(lighting[p]!);
      }
    }
    final mesh = ui.Vertices(
      ui.VertexMode.triangles,
      positions,
      colors: colors,
    );
    canvas.drawVertices(
      mesh,
      BlendMode.modulate,
      Paint()..color = Colors.white,
    );
    mesh.dispose();
    if (text.trim().isNotEmpty && t < .4) {
      final preview = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontSize: 11,
            height: 1.8,
            color: const Color(0xFF625F57).withValues(alpha: (1 - t / .4) * .8),
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 6,
        ellipsis: '…',
      )..layout(maxWidth: 132);
      canvas.save();
      canvas.scale(1 - t * 1.3, 1 - t * 1.3);
      preview.paint(canvas, const Offset(-66, -70));
      canvas.restore();
      preview.dispose();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SheetPainter oldDelegate) =>
      amount != oldDelegate.amount || text != oldDelegate.text;
}
