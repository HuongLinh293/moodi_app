import 'package:flutter/material.dart';

import '../core/theme/colors.dart';

class AirmailBorderPainter extends CustomPainter {
  const AirmailBorderPainter({this.radius = 22, this.inset = 5});

  final double radius;
  final double inset;

  @override
  void paint(Canvas canvas, Size size) {
    final outer = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    canvas.save();
    canvas.clipRRect(outer);
    canvas.drawRRect(outer, Paint()..color = AppColors.cream);

    const stripeWidth = 15.0;
    const stripeGap = 5.0;
    final paint = Paint();
    var stripeIndex = 0;
    for (
      double x = -size.height - stripeWidth;
      x < size.width + size.height;
      x += stripeWidth + stripeGap
    ) {
      paint.color = stripeIndex.isEven
          ? const Color(0xFFF19B8D)
          : const Color(0xFF9DD9E1);
      canvas.drawPath(
        Path()
          ..moveTo(x, 0)
          ..lineTo(x + stripeWidth, 0)
          ..lineTo(x + stripeWidth + size.height, size.height)
          ..lineTo(x + size.height, size.height)
          ..close(),
        paint,
      );
      stripeIndex++;
    }

    final inner = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        inset,
        inset,
        size.width - inset * 2,
        size.height - inset * 2,
      ),
      Radius.circular(radius - inset),
    );
    canvas.drawRRect(inner, Paint()..color = AppColors.cream);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant AirmailBorderPainter oldDelegate) =>
      radius != oldDelegate.radius || inset != oldDelegate.inset;
}
