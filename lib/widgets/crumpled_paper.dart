import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Photographic fold stages with short compression transitions. The atlas is
/// bundled locally; no writing or image data is sent to a server.
class CrumpledPaper extends StatefulWidget {
  static const assetPath = 'assets/paper/crumple-stages-v1.png';
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
  State<CrumpledPaper> createState() => _CrumpledPaperState();
}

class _CrumpledPaperState extends State<CrumpledPaper> {
  ImageStream? _stream;
  ImageInfo? _info;
  late final ImageStreamListener _listener = ImageStreamListener(
    (info, synchronousCall) {
      if (!mounted) {
        info.dispose();
        return;
      }
      setState(() {
        _info?.dispose();
        _info = info;
      });
    },
    onError: (Object error, StackTrace? stack) {
      // The flat-paper fallback still permits writing, throwing and undo.
      debugPrint('Paper illustration could not be loaded: $error');
    },
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = const AssetImage(CrumpledPaper.assetPath)
        .resolve(createLocalImageConfiguration(context));
    if (_stream?.key == next.key) return;
    _stream?.removeListener(_listener);
    _stream = next..addListener(_listener);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    _info?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: TweenAnimationBuilder<double>(
      tween: Tween<double>(
        begin: 0,
        end: (widget.amount.clamp(0, 1) * 4).round() / 4,
      ),
      duration: Duration(milliseconds: widget.reducedMotion ? 0 : 280),
      curve: Curves.easeInOutCubic,
      builder: (context, value, _) => CustomPaint(
        painter: _PaperStagesPainter(
          value,
          widget.text,
          _info?.image,
          widget.reducedMotion,
        ),
        size: const Size(240, 230),
      ),
    ),
  );
}

class _PaperStagesPainter extends CustomPainter {
  final double amount;
  final String text;
  final ui.Image? atlas;
  final bool reducedMotion;
  const _PaperStagesPainter(
    this.amount,
    this.text,
    this.atlas,
    this.reducedMotion,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final progress = amount * 4;
    final stage = progress.floor().clamp(0, 4);
    final mix = progress - stage;
    final squeeze = reducedMotion ? 0.0 : math.sin(mix * math.pi) * .045;
    final edge = size.shortestSide * (1 - amount * .12);
    canvas.drawOval(
      Rect.fromCenter(
        center: center + Offset(0, edge * .37),
        width: edge * .5,
        height: 12,
      ),
      Paint()
        ..color = const Color(0x163D362F)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(1 - squeeze, 1 + squeeze * .3);
    canvas.translate(-center.dx, -center.dy);
    final destination = Rect.fromCenter(
      center: center,
      width: edge,
      height: edge,
    );
    if (atlas == null || amount == 0) {
      _flat(canvas, destination);
    } else {
      // Add weighted layers on a transparent surface, avoiding dark fringes
      // during a crossfade between differently folded silhouettes.
      canvas.saveLayer(Offset.zero & size, Paint());
      _stage(canvas, destination, stage, 1 - mix);
      if (mix > 0 && stage < 4) _stage(canvas, destination, stage + 1, mix);
      canvas.restore();
    }
    canvas.restore();
  }

  void _stage(Canvas canvas, Rect destination, int stage, double opacity) {
    if (stage == 0) {
      canvas.saveLayer(
        destination,
        Paint()
          ..color = Colors.white.withValues(alpha: opacity)
          ..blendMode = BlendMode.plus,
      );
      _flat(canvas, destination);
      canvas.restore();
      return;
    }
    final image = atlas!;
    final index = stage - 1;
    final cellW = image.width / 2, cellH = image.height / 2;
    final source = Rect.fromLTWH(
      index % 2 * cellW,
      index ~/ 2 * cellH,
      cellW,
      cellH,
    );
    canvas.drawImageRect(
      image,
      source,
      destination,
      Paint()
        ..filterQuality = FilterQuality.medium
        ..color = Colors.white.withValues(alpha: opacity)
        ..blendMode = BlendMode.plus,
    );
  }

  void _flat(Canvas canvas, Rect rect) {
    final sheet = Rect.fromCenter(
      center: rect.center,
      width: rect.width * .74,
      height: rect.height * .88,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(sheet, const Radius.circular(2)),
      Paint()..color = const Color(0xFFFFFDF7),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(sheet, const Radius.circular(2)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .6
        ..color = const Color(0x246B6256),
    );
    if (text.trim().isNotEmpty) {
      final preview = TextPainter(
        text: TextSpan(
          text: text,
          style: const TextStyle(
            fontSize: 11,
            height: 1.8,
            color: Color(0xFF625F57),
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 7,
        ellipsis: '…',
      )..layout(maxWidth: sheet.width - 28);
      canvas.save();
      canvas.clipRect(sheet.deflate(12));
      preview.paint(canvas, sheet.topLeft + const Offset(14, 18));
      canvas.restore();
      preview.dispose();
    }
  }

  @override
  bool shouldRepaint(_PaperStagesPainter oldDelegate) =>
      amount != oldDelegate.amount ||
      text != oldDelegate.text ||
      atlas != oldDelegate.atlas ||
      reducedMotion != oldDelegate.reducedMotion;
}
