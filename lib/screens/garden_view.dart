import '../core/garden_actions.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../core/theme/colors.dart';
import '../core/theme/motion.dart';
import '../core/theme/typography.dart';
import '../models/emotion.dart';
import '../models/garden_moment.dart';
import '../models/journal_entry.dart';
import '../models/shared_garden.dart';
import '../state/mindra_state.dart';
import '../widgets/origami_garden.dart';
import '../widgets/shared_garden_widgets.dart';

class GardenView extends StatefulWidget {
  final MindraState state;
  final VoidCallback? onOpenCheckin;
  final VoidCallback? onOpenJournal;

  const GardenView({
    super.key,
    required this.state,
    this.onOpenCheckin,
    this.onOpenJournal,
  });

  @override
  State<GardenView> createState() => _GardenViewState();
}

class _GardenViewState extends State<GardenView> {
  late String _monthKey;
  bool _sharedBusy = false;

  Future<bool> _runShared(Future<void> Function() action) async {
    if (_sharedBusy) return false;
    setState(() => _sharedBusy = true);
    final success = await runGardenAction(context, action);
    if (mounted) setState(() => _sharedBusy = false);
    return success;
  }

  @override
  void initState() {
    super.initState();
    _monthKey = widget.state.currentGardenMonthKey();
  }

  String _monthTitle(String monthKey) {
    final parts = monthKey.split('-');
    final month = int.tryParse(parts.last) ?? 1;
    return 'Tháng $month của bạn';
  }

  void _openMoment(GardenMoment moment) {
    showGardenMomentSheet(
      context: context,
      state: widget.state,
      moment: moment,
      onOpenJournal: () {
        widget.onOpenJournal?.call();
      },
    );
  }

  void _openPlantPicker() {
    MindraMotion.of(widget.state.lowStimulationMode).selection();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Container(
            height: MediaQuery.of(context).size.height * 0.72,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: const BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
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
                const SizedBox(height: 16),
                Text('Giữ một khoảnh khắc', style: AppTypography.titleMedium),
                const SizedBox(height: 6),
                Text(
                  'Chọn một ghi chép bạn muốn nhớ. Check-in vẫn được giữ nếu bạn bỏ hoa sau này.',
                  style: AppTypography.bodySmall,
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    children: [
                      for (final entry in widget.state.entries)
                        _PlantEntryTile(
                          entry: entry,
                          planted: widget.state.isPlanted(entry.id),
                          onPlant: () async {
                            GardenMoment? moment;
                            final success = await runGardenAction(
                              context,
                              () async {
                                moment = await widget.state.plantMoment(
                                  entry.id,
                                );
                              },
                            );
                            if (!success || !mounted || !sheetContext.mounted) {
                              return;
                            }
                            Navigator.pop(sheetContext);
                            if (moment != null) {
                              setState(() => _monthKey = moment!.monthKey);
                            }
                          },
                        ),
                    ],
                  ),
                ),
                if (widget.onOpenCheckin != null)
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        widget.onOpenCheckin!();
                      },
                      child: const Text('Check-in mới'),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openMomentList(List<GardenMoment> moments) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Container(
            height: MediaQuery.of(context).size.height * 0.72,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: const BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
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
                const SizedBox(height: 16),
                Text('Ngắm từng khoảnh khắc', style: AppTypography.titleMedium),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    children: [
                      for (final moment in moments)
                        _MomentListTile(
                          state: widget.state,
                          moment: moment,
                          onTap: () {
                            Navigator.pop(sheetContext);
                            _openMoment(moment);
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openSharedPlantPicker() {
    MindraMotion.of(widget.state.lowStimulationMode).selection();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Container(
            height: MediaQuery.of(context).size.height * 0.72,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: const BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
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
                const SizedBox(height: 16),
                Text('Gieo vào vườn sẻ chia', style: AppTypography.titleMedium),
                const SizedBox(height: 6),
                Text(
                  'Chọn một ghi chép cảm xúc để gửi vào không gian chung của hai người.',
                  style: AppTypography.bodySmall,
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    children: [
                      for (final entry in widget.state.entries)
                        _PlantEntryTile(
                          entry: entry,
                          planted: false,
                          onPlant: () async {
                            final success = await _runShared(
                              () => widget.state.plantInSharedGarden(entry.id),
                            );
                            if (!success) return;
                            if (sheetContext.mounted) {
                              Navigator.pop(sheetContext);
                            }
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Đã gieo đóa hoa vào vườn sẻ chia! 🌸',
                                  ),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCreatedGardenDialog(SharedGarden garden) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.paper,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Khu vườn đã sẵn sàng! 🌱'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Gửi mã kết nối này cho bạn đồng hành để cùng nhau bước vào khu vườn:',
            ),
            const SizedBox(height: 14),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.yellow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.line),
                ),
                child: Text(
                  garden.code,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: garden.code));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Đã sao chép mã kết nối vào bộ nhớ tạm!'),
                ),
              );
            },
            child: const Text('Sao chép mã'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Vào vườn ngay'),
          ),
        ],
      ),
    );
  }

  Widget _buildSharedGardenContent(MindraState state, MindraMotion motion) {
    if (state.sharedGardenLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (state.sharedGardenError != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              color: AppColors.textMuted,
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              state.sharedGardenError!,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: state.retrySharedGarden,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Thử lại'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: state.loadDemoSharedGarden,
              icon: const Icon(Icons.park_rounded, size: 18),
              label: const Text('Khám phá Vườn mẫu'),
            ),
          ],
        ),
      );
    }
    final garden = state.sharedGarden;
    if (garden == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Vườn sẻ chia',
            style: AppTypography.displayMedium.copyWith(fontSize: 28),
          ),
          const SizedBox(height: 8),
          Text(
            'Gieo những đóa hoa cảm xúc và cùng nhau vun đắp mỗi ngày trong không gian riêng tư.',
            style: AppTypography.bodyMedium,
          ),
          const SizedBox(height: 20),
          SharedGardenBedView(
            state: state,
            moments: const [],
            onOpenMoment: (_) {},
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add_circle_outline_rounded),
              label: const Text('Tạo khu vườn mới'),
              onPressed: _sharedBusy
                  ? null
                  : () async {
                      await _runShared(() async {
                        final newGarden = await state.createSharedGarden();
                        if (mounted) _showCreatedGardenDialog(newGarden);
                      });
                    },
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.link_rounded),
              label: const Text('Nhập mã kết nối'),
              onPressed: () =>
                  showJoinGardenDialog(context: context, state: state),
            ),
          ),
          const SizedBox(height: 32),
        ],
      );
    }

    final moments = state.sharedMoments;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    garden.name,
                    style: AppTypography.displayMedium.copyWith(fontSize: 26),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Cùng ${garden.memberNames.values.join(', ')}',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: garden.code));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Đã sao chép mã vườn: ${garden.code}'),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.cream,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.line),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.copy_rounded,
                      size: 14,
                      color: AppColors.blue,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Sao chép mã',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppColors.blue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: AppColors.ink),
              onSelected: (val) {
                if (val == 'invite') {
                  _runShared(() async {
                    final code = await state.refreshSharedInvite();
                    await Clipboard.setData(ClipboardData(text: code));
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Đã sao chép mã mời mới.'),
                        ),
                      );
                    }
                  });
                }
                if (val == 'leave') {
                  _runShared(state.leaveSharedGarden);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'invite',
                  child: Text('Tạo và sao chép mã mời mới'),
                ),
                const PopupMenuItem(
                  value: 'leave',
                  child: Text('Rời khu vườn'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        SharedGardenBedView(
          state: state,
          moments: moments,
          onOpenMoment: (m) =>
              showSharedMomentSheet(context: context, state: state, moment: m),
        ),
        const SizedBox(height: 18),
        Text(
          moments.isEmpty
              ? 'Chưa có khoảnh khắc nào trong vườn chung.'
              : '${moments.length} khoảnh khắc được cùng nhau gieo trồng',
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Chạm vào bông hoa để tưới nước 💧 hoặc gửi tia nắng ấm ☀️ cho bạn đồng hành.',
          style: AppTypography.bodySmall,
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.local_florist_rounded),
            onPressed: _openSharedPlantPicker,
            label: const Text('Gieo cảm xúc vào vườn chung'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            icon: const Text('💌', style: TextStyle(fontSize: 18)),
            label: const Text('Bưu thiếp kỷ niệm'),
            onPressed: () => showSharedGardenPostcardDialog(
              context: context,
              state: state,
              garden: garden,
              moments: moments,
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final months = state.gardenMonthKeys();
    final monthKey = months.contains(_monthKey)
        ? _monthKey
        : state.currentGardenMonthKey();
    final canPop = Navigator.canPop(context);
    final motion = MindraMotion.of(state.lowStimulationMode);

    final body = ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final liveBeds = state.bedsInMonth(monthKey);
        final liveMoments = state.momentsInMonth(monthKey);
        return SingleChildScrollView(
          physics: motion.scrollPhysics,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Chuyển đổi giữa Vườn của tôi và Vườn sẻ chia
              Center(
                child: SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: false,
                      label: Text('Vườn của tôi'),
                      icon: Icon(Icons.person_outline_rounded, size: 18),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text('Vườn sẻ chia'),
                      icon: Icon(Icons.favorite_border_rounded, size: 18),
                    ),
                  ],
                  selected: {state.isSharedGardenMode},
                  onSelectionChanged: (set) {
                    state.toggleGardenMode(set.first);
                  },
                ),
              ),
              const SizedBox(height: 18),
              if (state.isSharedGardenMode)
                _buildSharedGardenContent(state, motion)
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _monthTitle(monthKey),
                        style: AppTypography.displayMedium.copyWith(
                          fontSize: 28,
                        ),
                      ),
                    ),
                    if (months.length > 1)
                      TextButton(
                        onPressed: () => _pickMonth(months),
                        child: const Text('Chọn tháng'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  liveMoments.isEmpty
                      ? 'Những điều bạn muốn giữ lại sẽ nở ở đây.'
                      : 'Những điều bạn muốn giữ lại.',
                  style: AppTypography.bodyMedium,
                ),
                const SizedBox(height: 20),
                for (final bed in liveBeds) ...[
                  GardenBedView(
                    state: state,
                    bed: bed,
                    reducedMotion: state.lowStimulationMode,
                    onOpenMoment: _openMoment,
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  liveMoments.isEmpty
                      ? 'Chưa có khoảnh khắc nào trong tháng này.'
                      : '${liveMoments.length} khoảnh khắc đã giữ lại',
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Mỗi bông hoa là một ghi chép bạn chọn giữ. Bỏ hoa không xóa ghi chép trong Nhật ký.',
                  style: AppTypography.bodySmall,
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _openPlantPicker,
                    child: Text(
                      liveMoments.isEmpty
                          ? 'Giữ khoảnh khắc đầu tiên'
                          : 'Giữ một khoảnh khắc',
                    ),
                  ),
                ),
                if (liveMoments.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () => _openMomentList(liveMoments),
                      child: const Text('Ngắm từng khoảnh khắc'),
                    ),
                  ),
                ],
                const SizedBox(height: 32),
              ],
            ],
          ),
        );
      },
    );

    if (canPop) {
      return Scaffold(
        backgroundColor: AppColors.paper,
        appBar: AppBar(
          backgroundColor: AppColors.paper,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.ink),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Khu vườn tâm trí',
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          centerTitle: false,
        ),
        body: body,
      );
    }
    return body;
  }

  void _pickMonth(List<String> months) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.paper,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final month in months)
                ListTile(
                  title: Text(_monthTitle(month)),
                  subtitle: Text(
                    '${widget.state.momentsInMonth(month).length} khoảnh khắc',
                  ),
                  onTap: () {
                    setState(() => _monthKey = month);
                    Navigator.pop(sheetContext);
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PlantEntryTile extends StatelessWidget {
  final JournalEntry entry;
  final bool planted;
  final VoidCallback onPlant;

  const _PlantEntryTile({
    required this.entry,
    required this.planted,
    required this.onPlant,
  });

  @override
  Widget build(BuildContext context) {
    final emotion = MindraEmotions.get(entry.emotionKey);
    final caption = GardenMoment.captionFor(entry);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: SizedBox(
        width: 36,
        height: 36,
        child: GardenBloom(emotionKey: entry.emotionKey, variant: 1),
      ),
      title: Text(emotion.vi),
      subtitle: Text(
        caption.isEmpty ? DateFormat('d/M').format(entry.timestamp) : caption,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: planted
          ? Text(
              'Đã có trong vườn',
              style: AppTypography.caption.copyWith(color: AppColors.textMuted),
            )
          : TextButton(onPressed: onPlant, child: const Text('Giữ lại')),
    );
  }
}

class _MomentListTile extends StatelessWidget {
  final MindraState state;
  final GardenMoment moment;
  final VoidCallback onTap;

  const _MomentListTile({
    required this.state,
    required this.moment,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final entry = state.entryById(moment.entryId);
    if (entry == null) return const SizedBox.shrink();
    final emotion = MindraEmotions.get(entry.emotionKey);
    final caption = GardenMoment.captionFor(entry);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: SizedBox(
        width: 36,
        height: 36,
        child: GardenBloom(
          emotionKey: entry.emotionKey,
          variant: moment.appearanceVariant,
        ),
      ),
      title: Text(emotion.vi),
      subtitle: Text(
        caption.isEmpty ? DateFormat('d/M').format(entry.timestamp) : caption,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: onTap,
    );
  }
}
