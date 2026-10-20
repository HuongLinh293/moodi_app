import '../core/garden_actions.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/theme/colors.dart';
import '../core/theme/motion.dart';
import '../core/theme/typography.dart';
import '../models/emotion.dart';
import '../models/garden_moment.dart';
import '../models/journal_entry.dart';
import '../state/mindra_state.dart';
import '../widgets/origami_garden.dart';

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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.ink,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: const StadiumBorder(),
                  ),
                  child: Text(
                    liveMoments.isEmpty
                        ? 'Giữ khoảnh khắc đầu tiên'
                        : 'Giữ thêm từ nhật ký',
                  ),
                ),
              ),
              if (liveMoments.isNotEmpty) ...[
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: TextButton(
                    onPressed: () => _openMomentList(liveMoments),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.ink,
                    ),
                    child: Text(
                      'Xem ${liveMoments.length} khoảnh khắc đã giữ',
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 32),
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
