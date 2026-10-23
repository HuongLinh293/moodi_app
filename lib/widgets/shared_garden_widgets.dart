import '../core/garden_actions.dart';

import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/garden_layout.dart';
import '../core/theme/colors.dart';
import '../core/theme/motion.dart';
import '../core/theme/typography.dart';
import '../models/emotion.dart';
import '../models/shared_garden.dart';
import '../state/mindra_state.dart';
import 'garden_weather.dart';
import 'origami_garden.dart';

/// 1. Bed view cho Vườn sẻ chia (Hiển thị hoa của cả 2 thành viên)
class SharedGardenBedView extends StatelessWidget {
  final MindraState state;
  final List<SharedMoment> moments;
  final ValueChanged<SharedMoment> onOpenMoment;
  final String emptyTitle;
  final String emptyMessage;

  const SharedGardenBedView({
    super.key,
    required this.state,
    required this.moments,
    required this.onOpenMoment,
    this.emptyTitle = 'Mảnh đất đang chờ đón',
    this.emptyMessage =
        'Hãy gieo một cảm xúc để bạn đồng hành cùng ngắm nhìn và tưới nước.',
  });

  @override
  Widget build(BuildContext context) {
    final beds = moments.map((m) => m.bedIndex).toSet().toList()..sort();
    if (beds.length > 1) {
      return Column(
        children: [
          for (final bed in beds) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('Luống ${bed + 1}'),
            ),
            SharedGardenBedView(
              state: state,
              moments: moments.where((m) => m.bedIndex == bed).toList(),
              onOpenMoment: onOpenMoment,
            ),
          ],
        ],
      );
    }
    const height = 320.0;
    final weather = GardenWeather.inferFromEmotions(
      moments.map((m) => m.emotionKey),
    );
    return Semantics(
      label: moments.isEmpty
          ? 'Luống vườn sẻ chia đang chờ khoảnh khắc đầu tiên.'
          : 'Luống vườn sẻ chia với ${moments.length} khoảnh khắc.',
      child: Container(
        height: height,
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.yellow,
          borderRadius: BorderRadius.circular(24),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) => Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: GardenBackdropPainter(compact: false),
                ),
              ),
              Positioned.fill(
                child: GardenWeatherAtmosphere(
                  weather: weather,
                  reducedMotion: state.lowStimulationMode,
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: SharedGardenStemsPainter(moments: moments),
                  ),
                ),
              ),
              Positioned(
                top: 10,
                right: 12,
                child: GardenWeatherBadge(
                  weather: weather,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Thời tiết vườn sẻ chia: ${weather.label} - ${weather.description}',
                        ),
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  },
                ),
              ),
              if (moments.isEmpty)
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    margin: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.cream.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.favorite_rounded,
                          color: AppColors.orange,
                          size: 28,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          emptyTitle,
                          style: AppTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          emptyMessage,
                          textAlign: TextAlign.center,
                          style: AppTypography.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ...moments.map((moment) {
                final slot = GardenLayout.slotAt(moment.slotIndex);
                final bloom = slot.size;
                final hit = math.max(bloom, 44.0);
                final isMe = moment.authorId == (state.currentUserId ?? '');

                return Positioned(
                  key: ValueKey('shared-flower-${moment.id}'),
                  left: constraints.maxWidth * slot.x - hit / 2,
                  top: constraints.maxHeight * slot.y - hit / 2,
                  width: hit,
                  height: hit,
                  child: Center(
                    child: _SharedSwayingFlower(
                      moment: moment,
                      bloomSize: bloom,
                      isMe: isMe,
                      reducedMotion: state.lowStimulationMode,
                      onTap: () {
                        MindraMotion.of(state.lowStimulationMode).selection();
                        onOpenMoment(moment);
                      },
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _SharedSwayingFlower extends StatefulWidget {
  final SharedMoment moment;
  final double bloomSize;
  final bool isMe;
  final bool reducedMotion;
  final VoidCallback onTap;

  const _SharedSwayingFlower({
    required this.moment,
    required this.bloomSize,
    required this.isMe,
    required this.reducedMotion,
    required this.onTap,
  });

  @override
  State<_SharedSwayingFlower> createState() => _SharedSwayingFlowerState();
}

class _SharedSwayingFlowerState extends State<_SharedSwayingFlower>
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
        tween: Tween<double>(
          begin: 1.0,
          end: 0.85,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.85,
          end: 1.18,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.18,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
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
    Widget content = Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: widget.bloomSize,
          height: widget.bloomSize,
          child: GardenBloom(
            emotionKey: widget.moment.emotionKey,
            variant: widget.moment.appearanceVariant,
          ),
        ),
        // Author indicator badge
        Positioned(
          right: -2,
          bottom: -2,
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: widget.isMe ? AppColors.blue : AppColors.orange,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: Text(
              widget.moment.authorName.isNotEmpty
                  ? widget.moment.authorName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        // Care badge (water or sun)
        if (widget.moment.waterCount > 0 || widget.moment.sunCount > 0)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.paper,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.line),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Text(
                widget.moment.waterCount >= widget.moment.sunCount
                    ? '💧'
                    : '☀️',
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
      ],
    );

    if (_canAnimateSway) {
      final maxAngle = 0.05 + ((widget.moment.slotIndex % 3) * 0.015);
      content = AnimatedBuilder(
        animation: Listenable.merge([_swayController!, _bounceAnimation]),
        builder: (context, child) {
          final progress = _swayController!.value;
          final swayAngle = math.sin(progress * 2 * math.pi) * maxAngle;
          final scale = _bounceController!.isAnimating
              ? _bounceAnimation.value
              : 1.0;

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
              : 1.0;
          return Transform.scale(scale: scale, child: child);
        },
        child: content,
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _onPressed,
      child: content,
    );
  }
}

/// 2. Modal chi tiết bông hoa trong vườn sẻ chia & tương tác Tưới nước / Gửi nắng
void showSharedMomentSheet({
  required BuildContext context,
  required MindraState state,
  required SharedMoment moment,
}) {
  final emotion = MindraEmotions.get(moment.emotionKey);
  final timeStr = DateFormat("d 'tháng' M 'lúc' HH:mm")
      .format(moment.plantedAt);

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (ctx, setSheetState) {
        // Lấy dữ liệu moment cập nhật thời gian thực từ state
        final liveMoment = state.sharedMoments.firstWhere(
          (m) => m.id == moment.id,
          orElse: () => moment,
        );

        return SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
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
                      width: 56,
                      height: 56,
                      child: GardenBloom(
                        emotionKey: liveMoment.emotionKey,
                        variant: 1,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(emotion.vi, style: AppTypography.titleLarge),
                          const SizedBox(height: 2),
                          Text(
                            'Gieo bởi ${liveMoment.authorName} • $timeStr',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (liveMoment.caption.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.cream,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Text(
                      liveMoment.caption,
                      style: AppTypography.bodyMedium,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                // Chỉ số chăm sóc
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.mint.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        '🌱 Tình trạng:',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '💧 ${liveMoment.waterCount} lần tưới',
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '☀️ ${liveMoment.sunCount} tia nắng',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
                if (liveMoment.lastInteraction != null &&
                    liveMoment.lastInteraction!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    liveMoment.lastInteraction!,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                // Nút hành động tương tác thời gian thực
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton.icon(
                          icon: const Text(
                            '💧',
                            style: TextStyle(fontSize: 18),
                          ),
                          label: const Text('Tưới nước'),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: AppColors.blue,
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () async {
                            final success = await runGardenAction(
                              context,
                              () => state.sendCareReaction(
                                momentId: liveMoment.id,
                                isWater: true,
                              ),
                            );
                            if (!success || !ctx.mounted) return;
                            setSheetState(() {});
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Đã gửi giọt nước tươi mát đến bông hoa 💧',
                                  ),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          icon: const Text(
                            '☀️',
                            style: TextStyle(fontSize: 18),
                          ),
                          label: const Text('Gửi tia nắng'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.orange,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () async {
                            final success = await runGardenAction(
                              context,
                              () => state.sendCareReaction(
                                momentId: liveMoment.id,
                                isWater: false,
                              ),
                            );
                            if (!success || !ctx.mounted) return;
                            setSheetState(() {});
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Đã gửi tia nắng ấm áp đến bông hoa ☀️',
                                  ),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                if (liveMoment.authorId == state.currentUserId) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton.icon(
                      key: const ValueKey('shared-remove-moment'),
                      icon: const Icon(Icons.undo_rounded, size: 18),
                      label: const Text('Gỡ bông hoa này'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        minimumSize: const Size(44, 44),
                      ),
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: ctx,
                          builder: (dialogCtx) => AlertDialog(
                            title: const Text('Gỡ bông hoa này?'),
                            content: const Text(
                              'Bạn đồng hành sẽ không còn thấy khoảnh khắc này. Ghi chép trong nhật ký của bạn vẫn được giữ nguyên.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dialogCtx),
                                child: const Text('Hủy'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(dialogCtx, true),
                                child: const Text('Gỡ'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed != true || !context.mounted) return;
                        final success = await runGardenAction(
                          context,
                          () => state.removeSharedMoment(liveMoment.id),
                        );
                        if (success && sheetContext.mounted) {
                          Navigator.pop(sheetContext);
                        }
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    ),
  );
}

/// 3. Bưu thiếp kỷ niệm (Mindful Postcard Generator)
void showSharedGardenPostcardDialog({
  required BuildContext context,
  required MindraState state,
  required SharedGarden garden,
  required List<SharedMoment> moments,
}) {
  final monthStr = 'Tháng ${DateTime.now().month}/${DateTime.now().year}';
  final memberNames = garden.memberNames.values.join(' & ');
  final totalWater = moments.fold(0, (sum, m) => sum + m.waterCount);
  final totalSun = moments.fold(0, (sum, m) => sum + m.sunCount);

  showDialog<void>(
    context: context,
    builder: (dialogCtx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.line, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Postcard Header: Vintage postal stamp look
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.orange, width: 1.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    '📮 MOODI',
                    style: TextStyle(
                      color: AppColors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'BƯU THIẾP TÂM TRÍ',
                    style: AppTypography.caption.copyWith(
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(monthStr, style: AppTypography.caption),
              ],
            ),
            const Divider(height: 24, thickness: 1, color: AppColors.line),
            // Title & Members
            Text(
              garden.name,
              style: AppTypography.titleLarge.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 22,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Gieo trồng bởi $memberNames',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            // Mini constellation preview
            Container(
              height: 140,
              decoration: BoxDecoration(
                color: AppColors.yellow,
                borderRadius: BorderRadius.circular(16),
              ),
              child: moments.isEmpty
                  ? Center(
                      child: Text(
                        'Chưa có hoa nào nở trong tháng này.',
                        style: AppTypography.bodySmall,
                      ),
                    )
                  : Center(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (final m in moments.take(8)) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                child: SizedBox(
                                  width: 44,
                                  height: 44,
                                  child: GardenBloom(
                                    emotionKey: m.emotionKey,
                                    variant: 1,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            // Statistics banner
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              decoration: BoxDecoration(
                color: AppColors.cream,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _StatItem(
                      label: 'Đoá hoa',
                      value: '${moments.length} 🌸',
                    ),
                  ),
                  Expanded(
                    child: _StatItem(
                      label: 'Tưới nước',
                      value: '$totalWater 💧',
                    ),
                  ),
                  Expanded(
                    child: _StatItem(label: 'Tia nắng', value: '$totalSun ☀️'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // Mindful quote
            Text(
              '“Khi hai tâm hồn cùng chăm sóc một khu vườn, cảm xúc không còn là gánh nặng đơn độc.”',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(
                fontStyle: FontStyle.italic,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    child: const Text('Đóng'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: const Text('Chia sẻ'),
                    onPressed: () {
                      Navigator.pop(dialogCtx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Đã sao chép liên kết bưu thiếp kỷ niệm! 💌',
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTypography.caption.copyWith(color: AppColors.textMuted),
        ),
      ],
    );
  }
}

/// 4. Dialog nhập mã kết nối tham gia vườn
void showJoinGardenDialog({
  required BuildContext context,
  required MindraState state,
}) {
  final controller = TextEditingController();
  final nameController = TextEditingController(
    text: state.sharedDisplayNameSuggestion,
  );
  bool isLoading = false;
  String? errorText;

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (ctx, setDialogState) => SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
            decoration: const BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: GestureDetector(
              onTap: () => FocusScope.of(sheetContext).unfocus(),
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
                Text('Tham gia vườn sẻ chia', style: AppTypography.titleMedium),
                const SizedBox(height: 6),
                Text(
                  'Dán mã mời bắt đầu bằng "MD-" mà bạn đồng hành gửi cho bạn.',
                  style: AppTypography.bodySmall,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'Dán mã mời từ bạn đồng hành',
                    errorText: errorText,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.vpn_key_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('shared-display-name'),
                  controller: nameController,
                  maxLength: 40,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Tên bạn đồng hành sẽ thấy',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.person_outline_rounded),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: isLoading
                        ? null
                        : () async {
                            final code = controller.text.trim();
                            final name = nameController.text.trim();
                            if (code.isEmpty || name.isEmpty) {
                              setDialogState(
                                () => errorText = code.isEmpty
                                    ? 'Vui lòng nhập mã'
                                    : 'Hãy nhập tên để bạn đồng hành nhận ra bạn',
                              );
                              return;
                            }
                            setDialogState(() {
                              isLoading = true;
                              errorText = null;
                            });
                            bool success;
                            try {
                              success = await state.joinSharedGarden(
                                code,
                                displayName: name,
                              );
                            } catch (error) {
                              if (sheetContext.mounted) {
                                setDialogState(() {
                                  isLoading = false;
                                  errorText = gardenErrorMessage(error);
                                });
                              }
                              return;
                            }
                            if (!sheetContext.mounted) return;
                            if (success) {
                              if (sheetContext.mounted) {
                                Navigator.pop(sheetContext);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Đã tham gia vườn sẻ chia thành công! 🌱',
                                    ),
                                  ),
                                );
                              }
                            } else {
                              setDialogState(() {
                                isLoading = false;
                                errorText = 'Không tìm thấy vườn với mã này. Hãy kiểm tra lại nhé.';
                              });
                            }
                          },
                    child: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Tham gia ngay'),
                  ),
                ),
              ],
            ),
            ),
          ),
        ),
      ),
    ),
  );
}

class SharedGardenStemsPainter extends CustomPainter {
  final List<SharedMoment> moments;
  const SharedGardenStemsPainter({required this.moments});

  @override
  void paint(Canvas canvas, Size size) {
    for (final moment in moments) {
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
  bool shouldRepaint(covariant SharedGardenStemsPainter oldDelegate) =>
      oldDelegate.moments != moments;
}
