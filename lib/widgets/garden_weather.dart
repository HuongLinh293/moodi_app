import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../core/theme/colors.dart';
import '../core/theme/typography.dart';

enum GardenWeather {
  sunny(
    label: 'Nắng ấm',
    icon: Icons.wb_sunny_rounded,
    color: Color(0xFFE5A93C),
    description: 'Nắng dịu ấm áp chiếu rọi, nuôi dưỡng những mầm hoa bình yên và vui tươi.',
  ),
  breezy(
    label: 'Gió lành',
    icon: Icons.air_rounded,
    color: Color(0xFF5B8DEF),
    description: 'Làn gió nhẹ cuốn đi những xao động và căng thẳng, trả lại sự thanh thản.',
  ),
  rainy(
    label: 'Mưa mát',
    icon: Icons.grain_rounded,
    color: Color(0xFF6B7280),
    description: 'Cơn mưa phùn mát lành tưới mát mảnh đất, dịu đi những nỗi buồn và mỏi mệt.',
  );

  final String label;
  final IconData icon;
  final Color color;
  final String description;

  const GardenWeather({
    required this.label,
    required this.icon,
    required this.color,
    required this.description,
  });

  static GardenWeather inferFromEmotions(Iterable<String> emotionKeys) {
    if (emotionKeys.isEmpty) return GardenWeather.sunny;

    int sunnyScore = 0;
    int rainyScore = 0;
    int breezyScore = 0;

    for (final key in emotionKeys) {
      switch (key) {
        case 'happy':
        case 'grateful':
        case 'calm':
          sunnyScore += 2;
          break;
        case 'sad':
        case 'tired':
          rainyScore += 2;
          break;
        case 'anxious':
        case 'stressed':
        case 'angry':
          breezyScore += 2;
          break;
      }
    }

    if (rainyScore > sunnyScore && rainyScore >= breezyScore) {
      return GardenWeather.rainy;
    }
    if (breezyScore > sunnyScore && breezyScore > rainyScore) {
      return GardenWeather.breezy;
    }
    return GardenWeather.sunny;
  }
}

class GardenWeatherAtmosphere extends StatefulWidget {
  final GardenWeather weather;
  final bool reducedMotion;

  const GardenWeatherAtmosphere({
    super.key,
    required this.weather,
    this.reducedMotion = false,
  });

  @override
  State<GardenWeatherAtmosphere> createState() => _GardenWeatherAtmosphereState();
}

class _GardenWeatherAtmosphereState extends State<GardenWeatherAtmosphere>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  bool get _canAnimate {
    if (widget.reducedMotion) return false;
    if (kIsWeb) return true;
    try {
      if (Platform.environment.containsKey('FLUTTER_TEST')) return false;
    } catch (_) {}
    return true;
  }

  @override
  void initState() {
    super.initState();
    if (_canAnimate) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 8),
      )..repeat();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_canAnimate) {
      return CustomPaint(
        painter: _WeatherStaticPainter(weather: widget.weather),
      );
    }

    return AnimatedBuilder(
      animation: _controller!,
      builder: (context, _) {
        return CustomPaint(
          painter: _WeatherDynamicPainter(
            weather: widget.weather,
            progress: _controller!.value,
          ),
        );
      },
    );
  }
}

class _WeatherStaticPainter extends CustomPainter {
  final GardenWeather weather;
  const _WeatherStaticPainter({required this.weather});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = true;
    switch (weather) {
      case GardenWeather.sunny:
        paint.color = const Color(0xFFFFF7D6).withValues(alpha: 0.35);
        canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.15), 45, paint);
        break;
      case GardenWeather.breezy:
        paint.color = const Color(0xFFE0F2FE).withValues(alpha: 0.3);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(size.width * 0.5, size.height * 0.2),
            width: size.width * 0.8,
            height: 30,
          ),
          paint,
        );
        break;
      case GardenWeather.rainy:
        paint.color = const Color(0xFF94A3B8).withValues(alpha: 0.2);
        canvas.drawRect(Offset.zero & size, paint);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _WeatherStaticPainter oldDelegate) =>
      oldDelegate.weather != weather;
}

class _WeatherDynamicPainter extends CustomPainter {
  final GardenWeather weather;
  final double progress;

  _WeatherDynamicPainter({
    required this.weather,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    switch (weather) {
      case GardenWeather.sunny:
        _drawSunny(canvas, size);
        break;
      case GardenWeather.breezy:
        _drawBreezy(canvas, size);
        break;
      case GardenWeather.rainy:
        _drawRainy(canvas, size);
        break;
    }
  }

  void _drawSunny(Canvas canvas, Size size) {
    // Tia nắng dịu và các đốm sáng lơ lửng (sun particles)
    final sunGlow = Paint()
      ..color = const Color(0xFFFDE68A).withValues(alpha: 0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28);
    canvas.drawCircle(Offset(size.width * 0.82, size.height * 0.12), 48, sunGlow);

    final sparklePaint = Paint()..style = PaintingStyle.fill;
    const count = 7;
    for (int i = 0; i < count; i++) {
      final seed = (i * 1.37);
      final p = (progress + seed) % 1.0;
      final x = (size.width * (0.15 + (i * 0.12))) % size.width;
      final y = size.height * (0.1 + 0.65 * (1.0 - p));
      final radius = 2.0 + math.sin(p * math.pi) * 2.5;
      final alpha = (math.sin(p * math.pi) * 0.35).clamp(0.0, 0.4);

      sparklePaint.color = const Color(0xFFFDE047).withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, y), radius, sparklePaint);
    }
  }

  void _drawBreezy(Canvas canvas, Size size) {
    // Cánh hoa / hạt phấn nhẹ nhàng bay lượn từ trái sang phải
    final petalPaint = Paint()..style = PaintingStyle.fill;
    const count = 6;
    for (int i = 0; i < count; i++) {
      final seed = (i * 0.21);
      final p = (progress + seed) % 1.0;
      final x = -20.0 + (size.width + 40.0) * p;
      final yBase = size.height * (0.15 + (i * 0.12));
      final yOffset = math.sin(p * math.pi * 3) * 14.0;
      final y = yBase + yOffset;
      final alpha = (math.sin(p * math.pi) * 0.3).clamp(0.0, 0.35);

      petalPaint.color = const Color(0xFFF472B6).withValues(alpha: alpha);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p * math.pi * 2);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 7, height: 4),
        petalPaint,
      );
      canvas.restore();
    }
  }

  void _drawRainy(Canvas canvas, Size size) {
    // Những vệt mưa phùn nghiêng nhẹ, trong suốt
    final rainPaint = Paint()
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    const count = 10;
    for (int i = 0; i < count; i++) {
      final seed = (i * 0.31);
      final p = (progress * 2.5 + seed) % 1.0;
      final x = size.width * (0.05 + (i * 0.09));
      final y = -20.0 + (size.height + 40.0) * p;
      final alpha = (0.15 + (i % 3) * 0.06).clamp(0.0, 0.28);

      rainPaint.color = const Color(0xFF64748B).withValues(alpha: alpha);
      canvas.drawLine(
        Offset(x, y),
        Offset(x - 5.0, y + 14.0),
        rainPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WeatherDynamicPainter oldDelegate) =>
      oldDelegate.weather != weather || oldDelegate.progress != progress;
}

class GardenWeatherBadge extends StatelessWidget {
  final GardenWeather weather;
  final VoidCallback onTap;

  const GardenWeatherBadge({
    super.key,
    required this.weather,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.paper.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.line.withValues(alpha: 0.7)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(weather.icon, size: 14, color: weather.color),
            const SizedBox(width: 5),
            Text(
              weather.label,
              style: AppTypography.caption.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
