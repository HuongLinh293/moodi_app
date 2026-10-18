import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import '../core/garden_layout.dart';
import '../core/theme/colors.dart';
import '../core/theme/motion.dart';
import '../core/theme/typography.dart';
import '../models/emotion.dart';
import '../models/garden_moment.dart';
import '../models/journal_entry.dart';
import '../state/mindra_state.dart';
import 'garden_weather.dart';

class GardenBedView extends StatefulWidget {
  final MindraState state;
  final GardenBedGroup bed;
  final bool compact;
  final bool interactive;
  final bool reducedMotion;
  final ValueChanged<GardenMoment>? onOpenMoment;

  const GardenBedView({
    super.key,
    required this.state,
    required this.bed,
    this.compact = false,
    this.interactive = true,
    this.reducedMotion = false,
    this.onOpenMoment,
  });

  @override
  State<GardenBedView> createState() => _GardenBedViewState();
}

class _GardenBedViewState extends State<GardenBedView> {
  String? _selectedMomentId;
  GardenWeather? _weatherOverride;

  GardenWeather get _currentWeather {
    if (_weatherOverride != null) return _weatherOverride!;
    final emotionKeys = widget.bed.moments
        .map((m) => widget.state.entryById(m.entryId)?.emotionKey)
        .whereType<String>();
    return GardenWeather.inferFromEmotions(emotionKeys);
  }

  void _showWeatherDialog() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
            decoration: const BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.line,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(_currentWeather.icon, color: _currentWeather.color, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'Bầu không khí: ${_currentWeather.label}',
                      style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _currentWeather.description,
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: 16),
                Text(
                  'Chọn bầu không khí cho vườn:',
                  style: AppTypography.caption.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: GardenWeather.values.map((w) {
                    final selected = _currentWeather == w;
                    return ChoiceChip(
                      selected: selected,
                      avatar: Icon(w.icon, size: 16, color: selected ? Colors.white : w.color),
                      label: Text(w.label),
                      selectedColor: w.color,
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : AppColors.textPrimary,
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                      onSelected: (val) {
                        if (val) {
                          setState(() => _weatherOverride = w);
                          setSheetState(() {});
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    child: const Text('Đóng'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final height = widget.compact ? 160.0 : 320.0;
    GardenMoment? selectedMoment;
    JournalEntry? selectedEntry;
    if (_selectedMomentId != null) {
      for (final m in widget.bed.moments) {
        if (m.id == _selectedMomentId) {
          selectedMoment = m;
          selectedEntry = widget.state.entryById(m.entryId);
          break;
        }
      }
    }

    return Semantics(
      label: widget.bed.moments.isEmpty
          ? 'Luống vườn đang chờ khoảnh khắc đầu tiên.'
          : 'Luống vườn với ${widget.bed.moments.length} khoảnh khắc.',
      child: Container(
        height: height,
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.yellow,
          borderRadius: BorderRadius.circular(widget.compact ? 18 : 24),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) => Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: GardenBackdropPainter(compact: widget.compact),
                ),
              ),
              Positioned.fill(
                child: GardenWeatherAtmosphere(
                  weather: _currentWeather,
                  reducedMotion: widget.reducedMotion,
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: GardenStemsPainter(bed: widget.bed)),
                ),
              ),
              if (!widget.compact)
                Positioned(
                  top: 10,
                  right: 12,
                  child: GardenWeatherBadge(
                    weather: _currentWeather,
                    onTap: _showWeatherDialog,
                  ),
                ),
              if (_selectedMomentId != null)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () => setState(() => _selectedMomentId = null),
                  ),
                ),
              ...widget.bed.moments.map((moment) {
                final entry = widget.state.entryById(moment.entryId);
                if (entry == null) return const SizedBox.shrink();
                final slot = GardenLayout.slotAt(moment.slotIndex);
                final bloom = widget.compact ? slot.size * 0.72 : slot.size;
                final hit = math.max(bloom, 44.0);
                final isSelected = _selectedMomentId == moment.id;
                return Positioned(
                  left: constraints.maxWidth * slot.x - hit / 2,
                  top: constraints.maxHeight * slot.y - hit / 2,
                  width: hit,
                  height: hit,
                  child: Center(
                    child: SizedBox(
                      width: bloom,
                      height: bloom,
                      child: _MomentBloomButton(
                        moment: moment,
                        entry: entry,
                        bloomed: true,
                        interactive: widget.interactive,
                        reducedMotion: widget.reducedMotion,
                        isSelected: isSelected,
                        onTap: () {
                          MindraMotion(widget.reducedMotion).selection();
                          if (widget.compact) {
                            widget.onOpenMoment?.call(moment);
                            return;
                          }
                          if (_selectedMomentId == moment.id) {
                            widget.onOpenMoment?.call(moment);
                          } else {
                            setState(() => _selectedMomentId = moment.id);
                          }
                        },
                      ),
                    ),
                  ),
                );
              }),
              if (selectedMoment != null && selectedEntry != null && !widget.compact)
                _buildCalloutBubble(constraints, selectedMoment, selectedEntry),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalloutBubble(
    BoxConstraints constraints,
    GardenMoment moment,
    JournalEntry entry,
  ) {
    final slot = GardenLayout.slotAt(moment.slotIndex);
    final flowerX = constraints.maxWidth * slot.x;
    final flowerY = constraints.maxHeight * slot.y;
    final bubbleWidth = math.min(250.0, constraints.maxWidth - 24.0);
    final bubbleLeft = (flowerX - bubbleWidth / 2)
        .clamp(12.0, constraints.maxWidth - bubbleWidth - 12.0);

    final showAbove = slot.y > 0.44;
    final bubbleTop = showAbove
        ? math.max(8.0, flowerY - 118.0)
        : math.min(constraints.maxHeight - 110.0, flowerY + 34.0);

    return Positioned(
      left: bubbleLeft,
      top: bubbleTop,
      width: bubbleWidth,
      child: _GardenCalloutBubble(
        moment: moment,
        entry: entry,
        onClose: () => setState(() => _selectedMomentId = null),
        onDetails: () {
          setState(() => _selectedMomentId = null);
          widget.onOpenMoment?.call(moment);
        },
      ),
    );
  }
}

class _GardenCalloutBubble extends StatelessWidget {
  final GardenMoment moment;
  final JournalEntry entry;
  final VoidCallback onClose;
  final VoidCallback onDetails;

  const _GardenCalloutBubble({
    required this.moment,
    required this.entry,
    required this.onClose,
    required this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    final emotion = MindraEmotions.get(entry.emotionKey);
    final caption = GardenMoment.captionFor(entry);
    final emotionColor =
        GardenBloom.neonColors[entry.emotionKey] ?? AppColors.mint;

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: emotionColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    emotion.vi,
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  DateFormat('d/M').format(entry.timestamp),
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              caption.isEmpty
                  ? 'Khoảnh khắc ${emotion.vi.toLowerCase()} bạn muốn giữ lại.'
                  : caption,
              style: AppTypography.bodySmall.copyWith(
                fontSize: 12,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: onDetails,
                  child: Text(
                    'Chi tiết',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.blue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    minimumSize: const Size(0, 26),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: onClose,
                  child: Text(
                    'Đóng',
                    style: AppTypography.caption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MomentBloomButton extends StatefulWidget {
  final GardenMoment moment;
  final JournalEntry entry;
  final bool bloomed;
  final bool interactive;
  final bool reducedMotion;
  final bool isSelected;
  final VoidCallback onTap;

  const _MomentBloomButton({
    required this.moment,
    required this.entry,
    required this.bloomed,
    required this.interactive,
    this.reducedMotion = false,
    this.isSelected = false,
    required this.onTap,
  });

  @override
  State<_MomentBloomButton> createState() => _MomentBloomButtonState();
}

class _MomentBloomButtonState extends State<_MomentBloomButton>
    with TickerProviderStateMixin {
  AnimationController? _swayController;
  AnimationController? _bounceController;
  late Animation<double> _bounceAnimation;

  bool get _canAnimateSway {
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
    if (_canAnimateSway) {
      final durationMs = 2800 + (widget.moment.slotIndex % 5) * 260;
      _swayController = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: durationMs),
      );
      _swayController!.value = ((widget.moment.slotIndex * 0.23) % 1.0);
      _swayController!.repeat(reverse: true);
    }

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _bounceAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.85)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.85, end: 1.18)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.18, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30,
      ),
    ]).animate(_bounceController!);
  }

  @override
  void dispose() {
    _swayController?.dispose();
    _bounceController?.dispose();
    super.dispose();
  }

  void _onPressed() {
    _bounceController?.forward(from: 0.0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final emotion = MindraEmotions.get(widget.entry.emotionKey);
    final caption = GardenMoment.captionFor(widget.entry);

    Widget bloomWidget = GardenBloom(
      emotionKey: widget.entry.emotionKey,
      variant: widget.moment.appearanceVariant,
      bloomed: widget.bloomed,
    );

    if (widget.isSelected) {
      final emotionColor =
          GardenBloom.neonColors[widget.entry.emotionKey] ?? AppColors.mint;
      bloomWidget = Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: emotionColor.withValues(alpha: 0.25),
              boxShadow: [
                BoxShadow(
                  color: emotionColor.withValues(alpha: 0.4),
                  blurRadius: 10,
                  spreadRadius: 3,
                ),
              ],
            ),
          ),
          bloomWidget,
        ],
      );
    }

    Widget content = bloomWidget;

    if (_canAnimateSway) {
      final maxAngle = 0.05 + ((widget.moment.slotIndex % 3) * 0.015);
      content = AnimatedBuilder(
        animation: Listenable.merge([_swayController!, _bounceAnimation]),
        builder: (context, child) {
          final progress = _swayController!.value;
          final swayAngle = math.sin(progress * 2 * math.pi) * maxAngle;
          final scale = _bounceController!.isAnimating
              ? _bounceAnimation.value
              : (widget.isSelected ? 1.12 : 1.0);

          return Transform.rotate(
            angle: swayAngle,
            alignment: Alignment.bottomCenter,
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.bottomCenter,
              child: child,
            ),
          );
        },
        child: content,
      );
    } else {
      content = AnimatedBuilder(
        animation: _bounceAnimation,
        builder: (context, child) {
          final scale = _bounceController!.isAnimating
              ? _bounceAnimation.value
              : (widget.isSelected ? 1.12 : 1.0);
          return Transform.scale(
            scale: scale,
            child: child,
          );
        },
        child: content,
      );
    }

    if (!widget.interactive) return content;

    return Semantics(
      button: true,
      label:
          '${emotion.vi}. ${DateFormat('d/M').format(widget.entry.timestamp)}. ${caption.isEmpty ? 'Chạm để xem khoảnh khắc.' : caption}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey<String>('garden-flower-${widget.moment.entryId}'),
          customBorder: const CircleBorder(),
          onTap: _onPressed,
          child: content,
        ),
      ),
    );
  }
}

class GardenBloom extends StatelessWidget {
  final String emotionKey;
  final int variant;
  final bool bloomed;

  const GardenBloom({
    super.key,
    required this.emotionKey,
    this.variant = 0,
    this.bloomed = true,
  });

  static const neonColors = <String, Color>{
    'calm': Color(0xFF00E5A0),
    'happy': Color(0xFFFF6B00),
    'stressed': Color(0xFF9747FF),
    'sad': Color(0xFF2979FF),
    'anxious': Color(0xFFFF2D95),
    'tired': Color(0xFF647DFF),
    'angry': Color(0xFFFF3B30),
    'grateful': Color(0xFFDBEA00),
    'ashamed': Color(0xFFFF4FCE),
    'numb': Color(0xFF8E74FF),
  };

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/garden/flower_moment.svg',
      colorMapper: _FlowerColorMapper(
        neonColors[emotionKey] ?? neonColors['calm']!,
      ),
      fit: BoxFit.contain,
      excludeFromSemantics: true,
    );
  }
}

class _FlowerColorMapper extends ColorMapper {
  final Color petalColor;

  const _FlowerColorMapper(this.petalColor);

  @override
  Color substitute(
    String? id,
    String elementName,
    String attributeName,
    Color color,
  ) {
    return color == const Color(0xFF4A54A4) ? petalColor : color;
  }
}

void showGardenMomentSheet({
  required BuildContext context,
  required MindraState state,
  required GardenMoment moment,
  required VoidCallback onOpenJournal,
}) {
  final entry = state.entryById(moment.entryId);
  if (entry == null) return;
  final emotion = MindraEmotions.get(entry.emotionKey);
  final caption = GardenMoment.captionFor(entry);
  final dateLabel = DateFormat("d 'tháng' M, yyyy").format(entry.timestamp);

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
        decoration: const BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                SizedBox(
                  width: 48,
                  height: 48,
                  child: GardenBloom(
                    emotionKey: entry.emotionKey,
                    variant: moment.appearanceVariant,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        emotion.vi,
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dateLabel,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              caption.isEmpty
                  ? 'Một khoảnh khắc ${emotion.vi.toLowerCase()} bạn muốn giữ lại.'
                  : caption,
              style: AppTypography.bodyMedium,
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  onOpenJournal();
                },
                child: const Text('Xem trong Nhật ký'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton(
                onPressed: () async {
                  try {
                    await state.removeMoment(moment.id);
                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                  } catch (_) {
                    if (sheetContext.mounted) {
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Chưa bỏ được khoảnh khắc khỏi vườn. Hãy thử lại.',
                          ),
                        ),
                      );
                    }
                  }
                },
                child: const Text('Bỏ khỏi vườn'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: TextButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: const Text('Đóng'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class GardenStemsPainter extends CustomPainter {
  final GardenBedGroup bed;
  const GardenStemsPainter({required this.bed});

  @override
  void paint(Canvas canvas, Size size) {
    for (final moment in bed.moments) {
      final slot = GardenLayout.slotAt(moment.slotIndex);
      final top = Offset(size.width * slot.x, size.height * slot.y);
      final height = size.height - 16 - top.dy;
      final isGreen = moment.appearanceVariant.isEven;
      final sourceWidth = isGreen ? 153.0 : 228.0;
      final sourceHeight = isGreen ? 409.0 : 465.0;
      final width = slot.size * (isGreen ? 0.72 : 0.88);
      final stemCenter = isGreen ? 142.0 : 111.0;

      canvas.save();
      canvas.translate(top.dx - stemCenter * width / sourceWidth, top.dy);
      canvas.scale(width / sourceWidth, height / sourceHeight);
      if (isGreen) {
        final stem = Path()
          ..moveTo(131.501, 0)
          ..lineTo(110, 369.586)
          ..lineTo(146.407, 409)
          ..lineTo(153, 0)
          ..close();
        final leaf = Path()
          ..moveTo(109.038, 213.384)
          ..cubicTo(109.038, 213.384, 24.4104, 226.812, 5.4304, 192.819)
          ..cubicTo(-13.5496, 158.831, 23.3187, 137, 23.3187, 137)
          ..lineTo(146, 167.996)
          ..close();
        canvas.drawPath(stem, Paint()..color = const Color(0xFF007E3A));
        canvas.drawPath(leaf, Paint()..color = const Color(0xFF3C9B68));
      } else {
        final branches = Path()
          ..moveTo(106.031, 464.406)
          ..cubicTo(106.031, 464.406, 54.5104, 440.526, 37.1302, 415.615)
          ..cubicTo(19.75, 390.708, 0, 310.776, 0, 310.776)
          ..lineTo(28.0625, 287.932)
          ..lineTo(106.021, 448.839)
          ..cubicTo(106.021, 448.839, 165.271, 266.13, 176.703, 259.906)
          ..cubicTo(188.141, 253.682, 222.438, 235, 222.438, 235)
          ..lineTo(227.63, 313.891)
          ..lineTo(133.031, 454.036)
          ..lineTo(106.01, 464.417)
          ..close();
        final stem = Path()
          ..moveTo(100, 461)
          ..lineTo(101.855, 0)
          ..lineTo(120, 5.69317)
          ..lineTo(117.729, 443.91)
          ..close();
        final paint = Paint()..color = const Color(0xFF4A54A4);
        canvas.drawPath(branches, paint);
        canvas.drawPath(stem, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant GardenStemsPainter oldDelegate) =>
      oldDelegate.bed != bed;
}

class BloomPainter extends CustomPainter {
  final String emotionKey;
  final int variant;
  final bool bloomed;

  const BloomPainter({
    required this.emotionKey,
    required this.variant,
    required this.bloomed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * 0.43;
    final color = switch (emotionKey) {
      'calm' => const Color(0xFFFFF3DD),
      'happy' => const Color(0xFFC84338),
      'stressed' => const Color(0xFF625292),
      'sad' => const Color(0xFFEEF0FF),
      'anxious' => const Color(0xFFB53F72),
      'tired' => const Color(0xFFEEDAEF),
      'angry' => AppColors.orange,
      'grateful' => AppColors.yellow,
      'ashamed' => AppColors.softYellow,
      _ => AppColors.lavender,
    };
    final paint = Paint()..color = color;
    if (!bloomed) {
      final bud = Path()
        ..moveTo(center.dx, center.dy + radius * 0.65)
        ..quadraticBezierTo(
          center.dx - radius * 0.65,
          center.dy,
          center.dx,
          center.dy - radius * 0.7,
        )
        ..quadraticBezierTo(
          center.dx + radius * 0.65,
          center.dy,
          center.dx,
          center.dy + radius * 0.65,
        );
      canvas.drawPath(bud, paint);
      return;
    }
    final petals = 5 + (variant % 3);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    for (var i = 0; i < petals; i++) {
      canvas.save();
      canvas.rotate(i * math.pi * 2 / petals + 0.12);
      final petal = Path()
        ..moveTo(-radius * 0.16, 0)
        ..cubicTo(
          -radius * 0.62,
          -radius * 0.43,
          -radius * 0.46,
          -radius,
          0,
          -radius,
        )
        ..cubicTo(
          radius * 0.46,
          -radius,
          radius * 0.62,
          -radius * 0.43,
          radius * 0.16,
          0,
        )
        ..close();
      canvas.drawPath(petal, paint);
      canvas.restore();
    }
    canvas.drawCircle(
      Offset.zero,
      radius * 0.26,
      Paint()..color = const Color(0xFF234D43),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant BloomPainter oldDelegate) =>
      oldDelegate.emotionKey != emotionKey ||
      oldDelegate.variant != variant ||
      oldDelegate.bloomed != bloomed;
}

class GardenBackdropPainter extends CustomPainter {
  final bool compact;

  const GardenBackdropPainter({this.compact = false});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.yellow);

    if (!compact) {
      _fill(canvas, [
        Offset(size.width * 0.62, 18),
        Offset(size.width * 0.88, 38),
        Offset(size.width * 0.92, 78),
        Offset(size.width * 0.72, 108),
        Offset(size.width * 0.48, 86),
        Offset(size.width * 0.46, 42),
      ], AppColors.orange);
      _fill(canvas, [
        const Offset(18, 58),
        const Offset(48, 28),
        const Offset(108, 22),
        const Offset(158, 48),
        const Offset(148, 78),
        const Offset(72, 86),
      ], AppColors.mint);
      _fill(canvas, [
        Offset(0, size.height - 54),
        Offset(size.width * 0.28, size.height - 86),
        Offset(size.width * 0.58, size.height - 58),
        Offset(size.width, size.height - 78),
        Offset(size.width, size.height),
        Offset(0, size.height),
      ], AppColors.blue);
      return;
    }

    _fill(canvas, [
      Offset(size.width * 0.70, 18),
      Offset(size.width * 0.86, 30),
      Offset(size.width * 0.88, 54),
      Offset(size.width * 0.76, 72),
      Offset(size.width * 0.62, 59),
      Offset(size.width * 0.60, 33),
    ], AppColors.orange);

    _fill(canvas, [
      const Offset(18, 44),
      const Offset(36, 26),
      const Offset(72, 22),
      const Offset(102, 38),
      const Offset(96, 56),
      const Offset(50, 61),
    ], AppColors.mint);

    _fill(canvas, [
      Offset(0, size.height - 32),
      Offset(size.width * 0.28, size.height - 50),
      Offset(size.width * 0.58, size.height - 34),
      Offset(size.width, size.height - 46),
      Offset(size.width, size.height),
      Offset(0, size.height),
    ], AppColors.blue);
  }

  void _fill(Canvas canvas, List<Offset> points, Color color) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant GardenBackdropPainter oldDelegate) =>
      oldDelegate.compact != compact;
}
