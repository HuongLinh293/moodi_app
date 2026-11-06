import '../core/garden_actions.dart';
import '../widgets/entry_sync_notice.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/theme/colors.dart';
import '../core/theme/motion.dart';
import '../core/theme/shadows.dart';
import '../core/theme/typography.dart';
import '../models/emotion.dart';
import '../models/journal_entry.dart';
import '../state/mindra_state.dart';
import '../widgets/mood_face.dart';
import 'ai_reflection_view.dart';
import 'journal_entry_editor.dart';

class JournalView extends StatefulWidget {
  final MindraState state;

  const JournalView({super.key, required this.state});

  @override
  State<JournalView> createState() => _JournalViewState();
}

class _JournalViewState extends State<JournalView> {
  late DateTime _selectedDate;
  late DateTime _displayedMonth;
  int _seenFocus = 0;

  @override
  void initState() {
    super.initState();
    final now = widget.state.journalFocusDate ?? DateTime.now();
    _seenFocus = widget.state.journalFocusSeq;
    _selectedDate = DateTime(now.year, now.month, now.day);
    _displayedMonth = DateTime(now.year, now.month, 1);
  }

  @override
  void didUpdateWidget(covariant JournalView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_seenFocus == widget.state.journalFocusSeq) return;
    _seenFocus = widget.state.journalFocusSeq;
    final date = widget.state.journalFocusDate ?? DateTime.now();
    _selectedDate = DateTime(date.year, date.month, date.day);
    _displayedMonth = DateTime(date.year, date.month, 1);
  }

  bool _isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  bool _isToday(DateTime d) {
    return _isSameDay(d, DateTime.now());
  }

  bool _isFuture(DateTime d) {
    final now = DateTime.now();
    return DateTime(
      d.year,
      d.month,
      d.day,
    ).isAfter(DateTime(now.year, now.month, now.day));
  }

  bool get _isDisplayingCurrentMonth {
    final now = DateTime.now();
    return _displayedMonth.year == now.year &&
        _displayedMonth.month == now.month;
  }

  void _onDateSelected(DateTime date) {
    MindraMotion.of(widget.state.lowStimulationMode).light();
    setState(() {
      _selectedDate = date;
    });
  }

  void _previousMonth() {
    MindraMotion.of(widget.state.lowStimulationMode).light();
    setState(() {
      _displayedMonth = DateTime(
        _displayedMonth.year,
        _displayedMonth.month - 1,
        1,
      );
      _selectedDate = _displayedMonth;
    });
  }

  void _nextMonth() {
    if (_isDisplayingCurrentMonth) return;
    MindraMotion.of(widget.state.lowStimulationMode).light();
    setState(() {
      _displayedMonth = DateTime(
        _displayedMonth.year,
        _displayedMonth.month + 1,
        1,
      );
      _selectedDate = _displayedMonth;
    });
  }

  String _triggerLabel(String value) =>
      const {
        'work': 'Công việc',
        'family': 'Gia đình',
        'friends': 'Bạn bè',
        'relationship': 'Tình cảm',
        'self_care': 'Bản thân',
        'health': 'Sức khỏe',
        'rest': 'Nghỉ ngơi',
        'finance': 'Tài chính',
        'study': 'Học tập',
      }[value] ??
      value;

  String _formatTimestamp(DateTime dt) {
    return DateFormat('HH:mm').format(dt);
  }

  String _formatDateHeader(DateTime dt) {
    final viDays = [
      '',
      'Thứ Hai',
      'Thứ Ba',
      'Thứ Tư',
      'Thứ Năm',
      'Thứ Sáu',
      'Thứ Bảy',
      'Chủ Nhật',
    ];
    final dayOfWeek = viDays[dt.weekday];
    return '$dayOfWeek, ${dt.day} tháng ${dt.month}';
  }

  // Lấy các entry cho 1 ngày cụ thể
  List<JournalEntry> _getEntriesForDate(DateTime date) {
    return widget.state.entries
        .where((e) => _isSameDay(e.timestamp, date))
        .toList();
  }

  // Mở BottomSheet ghi nhận / chỉnh sửa cảm xúc cho ngày được chọn (Emolog style)
  Future<void> _openQuickLogForDate(
    DateTime targetDate, [
    JournalEntry? existingEntry,
  ]) async {
    if (existingEntry == null && _isFuture(targetDate)) return;
    final saved = await showModalBottomSheet<JournalEntry>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => JournalEntryEditor(
        state: widget.state,
        date: targetDate,
        entry: existingEntry,
      ),
    );
    if (saved == null || !mounted) return;
    setState(() => _selectedDate = targetDate);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(widget.state.entrySaveMessage(saved.id))),
    );
  }

  void _confirmDeleteEntry(JournalEntry entry) {
    MindraMotion.of(widget.state.lowStimulationMode).light();
    final emo = MindraEmotions.get(entry.emotionKey);
    var deleting = false;
    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Text(
            'Xóa nhật ký?',
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'Bạn có chắc muốn xóa ghi chép cảm xúc "${emo.vi}" (${_formatTimestamp(entry.timestamp)}) ngày ${_formatDateHeader(entry.timestamp)}?',
            style: AppTypography.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: deleting ? null : () => Navigator.pop(dialogCtx),
              child: Text(
                'Hủy',
                style: AppTypography.button.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orange,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.orange.withValues(
                  alpha: 0.6,
                ),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: deleting
                  ? null
                  : () async {
                      setDialogState(() => deleting = true);
                      try {
                        await widget.state.removeEntry(entry.id);
                      } catch (_) {
                        if (!dialogCtx.mounted) return;
                        setDialogState(() => deleting = false);
                        ScaffoldMessenger.of(dialogCtx).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Chưa xóa được ghi chép. Hãy thử lại.',
                            ),
                          ),
                        );
                        return;
                      }
                      if (!mounted || !dialogCtx.mounted) return;
                      Navigator.pop(dialogCtx);
                      setState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Đã xóa ghi chép cảm xúc'),
                          backgroundColor: AppColors.ink,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
              child: deleting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Xóa'),
            ),
          ],
        ),
      ),
    );
  }

  // Tóm tắt cảm xúc tháng (Emolog Monthly Mood Stats)
  Widget _buildMonthStatsBar() {
    final entriesInMonth = widget.state.entries.where((e) {
      return e.timestamp.year == _displayedMonth.year &&
          e.timestamp.month == _displayedMonth.month;
    }).toList();

    // Tập hợp số ngày đã check-in
    final activeDays = entriesInMonth
        .map((e) => e.timestamp.day)
        .toSet()
        .length;

    // Đếm cảm xúc phổ biến
    final emotionCounts = <String, int>{};
    for (final e in entriesInMonth) {
      emotionCounts[e.emotionKey] = (emotionCounts[e.emotionKey] ?? 0) + 1;
    }

    final sortedEmotions = emotionCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.creamDark,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.creamDark,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.event_available_rounded,
                  size: 16,
                  color: AppColors.ink,
                ),
                const SizedBox(width: 6),
                Text(
                  '$activeDays ngày đã ghi',
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: sortedEmotions.isEmpty
                ? Text(
                    'Bắt đầu ghi lại cảm xúc tháng này',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textTertiary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'Chủ đạo: ',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                        ...sortedEmotions.take(3).map((entry) {
                          final emo = MindraEmotions.get(entry.key);
                          return Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Tooltip(
                              message: '${emo.vi} (${entry.value})',
                              child: MoodFace(faceType: emo.face, size: 22),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // Lưới lịch tháng đặc trưng Emolog (Mood Mosaic Grid)
  Widget _buildEmologMonthCalendar() {
    final year = _displayedMonth.year;
    final month = _displayedMonth.month;

    // Số ngày trong tháng
    final daysInMonth = DateUtils.getDaysInMonth(year, month);
    // Ngày đầu tiên của tháng bắt đầu vào thứ mấy (1 = T2 ... 7 = CN)
    final firstDayWeekday = DateTime(year, month, 1).weekday; // 1 to 7

    final weekDays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

    // Tính tổng số ô cần render (leading empty cells + days)
    final leadingEmptyCells = firstDayWeekday - 1;
    final totalCells = leadingEmptyCells + daysInMonth;
    final totalRows = (totalCells / 7).ceil();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          // Header các thứ trong tuần
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: weekDays.map((d) {
                final isWeekend = d == 'T7' || d == 'CN';
                return Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: AppTypography.kicker.copyWith(
                        fontSize: 11,
                        color: isWeekend
                            ? AppColors.orange
                            : AppColors.textTertiary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Lưới ngày
          Column(
            children: List.generate(totalRows, (rowIndex) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: List.generate(7, (colIndex) {
                    final cellIndex = rowIndex * 7 + colIndex;
                    final dayNum = cellIndex - leadingEmptyCells + 1;

                    if (dayNum < 1 || dayNum > daysInMonth) {
                      // Ô trống ngoài tháng
                      return const Expanded(child: SizedBox(height: 52));
                    }

                    final cellDate = DateTime(year, month, dayNum);
                    final isSelected = _isSameDay(cellDate, _selectedDate);
                    final isToday = _isToday(cellDate);
                    final isFuture = _isFuture(cellDate);

                    final dayEntries = _getEntriesForDate(cellDate);
                    final hasEntry = dayEntries.isNotEmpty;
                    final primaryEntry = hasEntry ? dayEntries.first : null;
                    final primaryEmo = primaryEntry != null
                        ? MindraEmotions.get(primaryEntry.emotionKey)
                        : null;

                    final emoLabels = dayEntries
                        .map((e) => MindraEmotions.get(e.emotionKey).vi)
                        .join(', ');
                    final tooltipText = hasEntry
                        ? (dayEntries.length > 1
                              ? 'Ngày $dayNum tháng $month: ${dayEntries.length} cảm xúc ($emoLabels)'
                              : 'Ngày $dayNum tháng $month: ${primaryEmo!.vi}')
                        : 'Ngày $dayNum tháng $month: Chưa có ghi chép';

                    return Expanded(
                      child: Tooltip(
                        message: tooltipText,
                        preferBelow: false,
                        child: Semantics(
                          button: true,
                          enabled: !isFuture,
                          selected: isSelected,
                          label: tooltipText,
                          child: GestureDetector(
                            onTap: isFuture
                                ? null
                                : () => _onDateSelected(cellDate),
                            behavior: HitTestBehavior.opaque,
                            child: AnimatedContainer(
                              duration: MindraMotion.of(
                                widget.state.lowStimulationMode,
                              ).duration,
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              height:
                                  52 +
                                  (MediaQuery.textScalerOf(context).scale(11) -
                                          11)
                                      .clamp(0, 36),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.creamDark
                                    : (isToday
                                          ? AppColors.cream
                                          : Colors.transparent),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.ink
                                      : (isToday
                                            ? AppColors.orange.withValues(
                                                alpha: 0.5,
                                              )
                                            : Colors.transparent),
                                  width: isSelected ? 1.6 : 1.0,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Số ngày
                                  Text(
                                    '$dayNum',
                                    style: AppTypography.caption.copyWith(
                                      fontSize: 11,
                                      fontWeight: isSelected || isToday
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? AppColors.ink
                                          : (isToday
                                                ? AppColors.orange
                                                : (isFuture
                                                      ? AppColors.textTertiary
                                                            .withValues(
                                                              alpha: 0.5,
                                                            )
                                                      : AppColors.textMuted)),
                                    ),
                                  ),
                                  const SizedBox(height: 2),

                                  // Emoji mặt cảm xúc phong cách Emolog
                                  if (primaryEmo != null)
                                    Stack(
                                      clipBehavior: Clip.none,
                                      alignment: Alignment.bottomRight,
                                      children: [
                                        MoodFace(
                                          faceType: primaryEmo.face,
                                          size: 24,
                                        ),
                                        if (dayEntries.length > 1)
                                          Positioned(
                                            right: -4,
                                            bottom: -2,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 3,
                                                    vertical: 1,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: AppColors.ink,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: Colors.white,
                                                  width: 1,
                                                ),
                                              ),
                                              child: Text(
                                                '+${dayEntries.length - 1}',
                                                style: const TextStyle(
                                                  fontSize: 8,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.white,
                                                  height: 1,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    )
                                  else
                                    const SizedBox(height: 24),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // Thẻ chi tiết ngày đang chọn (Selected Day Card)
  Widget _buildSelectedDayDetailCard() {
    final entries = _getEntriesForDate(_selectedDate);
    final isSelectedToday = _isToday(_selectedDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tiêu đề ngày được chọn
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 6,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  _formatDateHeader(_selectedDate),
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                if (isSelectedToday)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Hôm nay',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.orangeText,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ),
                if (entries.length > 1)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.creamDark,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${entries.length} cảm xúc',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            ),
            if (entries.isNotEmpty)
              GestureDetector(
                onTap: () => _openQuickLogForDate(_selectedDate),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.add_rounded,
                        size: 18,
                        color: AppColors.ink,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        'Thêm',
                        style: AppTypography.bodySmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 12),

        if (entries.isEmpty)
          // Empty State ngày này chưa có ghi chép
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            decoration: BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.circular(22),
              boxShadow: AppShadows.card,
            ),
            child: Column(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.cream,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.edit_calendar_outlined,
                      size: 26,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Chưa có ghi nhận trong ngày này',
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Bạn có thể bắt đầu bằng một check-in ngắn, không cần viết hết.',
                  textAlign: TextAlign.center,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 44, // Touch target >= 44pt
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.ink, width: 1.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                    ),
                    onPressed: () => _openQuickLogForDate(_selectedDate),
                    icon: const Icon(
                      Icons.add_rounded,
                      size: 18,
                      color: AppColors.ink,
                    ),
                    label: Text(
                      'Ghi nhận cảm xúc ngày này',
                      style: AppTypography.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          // Danh sách các entry của ngày
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: entries.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final entry = entries[index];
              final emo = MindraEmotions.get(entry.emotionKey);

              return Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.cream,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: AppShadows.card,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MoodFace(faceType: emo.face, size: 48),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      emo.vi,
                                      style: AppTypography.titleMedium.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: emo.tone.withValues(
                                              alpha: 0.2,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            'Mức ${entry.intensity}/5',
                                            style: AppTypography.caption
                                                .copyWith(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.ink,
                                                ),
                                          ),
                                        ),
                                        Text(
                                          _formatTimestamp(entry.timestamp),
                                          style: AppTypography.caption.copyWith(
                                            color: AppColors.textTertiary,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Semantics(
                                    button: true,
                                    label: 'Sửa nhật ký cảm xúc ${emo.vi}',
                                    child: IconButton(
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        size: 18,
                                        color: AppColors.ink,
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 44,
                                        minHeight: 44,
                                      ),
                                      padding: const EdgeInsets.all(8),
                                      tooltip: 'Sửa',
                                      onPressed: () => _openQuickLogForDate(
                                        entry.timestamp,
                                        entry,
                                      ),
                                    ),
                                  ),
                                  Semantics(
                                    button: true,
                                    label: 'Xóa nhật ký cảm xúc ${emo.vi}',
                                    child: IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        size: 18,
                                        color: AppColors.textTertiary,
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 44,
                                        minHeight: 44,
                                      ),
                                      padding: const EdgeInsets.all(8),
                                      tooltip: 'Xóa',
                                      onPressed: () =>
                                          _confirmDeleteEntry(entry),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (entry.situation.isNotEmpty)
                            Text(
                              entry.situation,
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.ink,
                                height: 1.4,
                              ),
                            )
                          else if (entry.thought.isNotEmpty)
                            Text(
                              entry.thought,
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.ink,
                                height: 1.4,
                              ),
                            )
                          else
                            Text(
                              emo.promptSubtitle,
                              style: AppTypography.bodyMedium.copyWith(
                                fontStyle: FontStyle.italic,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          if (entry.situation.isNotEmpty &&
                              entry.thought.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'Suy nghĩ: ${entry.thought}',
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppColors.ink,
                                ),
                              ),
                            ),
                          if (entry.response.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'Phản ứng: ${entry.response}',
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppColors.ink,
                                ),
                              ),
                            ),
                          if (entry.trigger != 'other' &&
                              entry.trigger.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'Tác nhân: ${_triggerLabel(entry.trigger)}',
                                style: AppTypography.caption,
                              ),
                            ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () async {
                                final moment = widget.state.momentForEntry(
                                  entry.id,
                                );
                                if (moment != null) {
                                  widget.state.openGarden(
                                    monthKey: moment.monthKey,
                                  );
                                  return;
                                }
                                final success = await runGardenAction(
                                  context,
                                  () async {
                                    await widget.state.plantMoment(entry.id);
                                  },
                                );
                                if (!success || !context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Khoảnh khắc đã được giữ lại.',
                                    ),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.ink,
                                minimumSize: const Size(44, 44),
                              ),
                              icon: Icon(
                                widget.state.isPlanted(entry.id)
                                    ? Icons.local_florist_rounded
                                    : Icons.local_florist_outlined,
                                size: 18,
                              ),
                              label: Text(
                                widget.state.isPlanted(entry.id)
                                    ? 'Xem trong vườn'
                                    : 'Giữ trong vườn',
                              ),
                            ),
                          ),
                          if (widget.state.aiConsent ||
                              widget.state.reflectionForEntry(entry.id) != null)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => AIReflectionView(
                                        entry: entry,
                                        state: widget.state,
                                        onOpenJournal: () {},
                                      ),
                                    ),
                                  );
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.blue,
                                  minimumSize: const Size(44, 44),
                                ),
                                icon: const Icon(
                                  Icons.auto_awesome_outlined,
                                  size: 18,
                                ),
                                label: Text(
                                  widget.state.reflectionForEntry(entry.id) ==
                                          null
                                      ? 'Tạo gợi ý phản tư'
                                      : 'Xem phản tư',
                                ),
                              ),
                            ),
                          if ((entry.exerciseDone &&
                                  entry.exerciseId != null) ||
                              widget.state.practiceRecords.any(
                                (r) => r.sourceEntryId == entry.id,
                              )) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.mint.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 6,
                                children: [
                                  const Icon(
                                    Icons.check_circle_outline_rounded,
                                    size: 14,
                                    color: AppColors.ink,
                                  ),
                                  Text(
                                    'Đã hoàn thành bài tập nhẹ',
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.ink,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final monthName = 'Tháng ${_displayedMonth.month}';

    return SingleChildScrollView(
      physics: MindraMotion.of(widget.state.lowStimulationMode).scrollPhysics,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EntrySyncNotice(state: widget.state),

          // Month header + navigation — compact, top-aligned
          Row(
            children: [
              Expanded(
                child: RichText(
                  textScaler: MediaQuery.textScalerOf(context),
                  text: TextSpan(
                    style: AppTypography.displayMedium.copyWith(fontSize: 22),
                    children: [
                      TextSpan(
                        text: monthName.toUpperCase(),
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: AppColors.orangeText,
                        ),
                      ),
                      TextSpan(
                        // Khoảng rộng (en space): chữ nghiêng "11" dính vào
                        // năm nên trông như "112026" với dấu cách thường.
                        text: '\u2002${_displayedMonth.year}',
                        style: const TextStyle(color: AppColors.ink),
                      ),
                    ],
                  ),
                ),
              ),
              GestureDetector(
                onTap: _previousMonth,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.line),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.chevron_left_rounded,
                      size: 22,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: _isDisplayingCurrentMonth ? null : _nextMonth,
                behavior: HitTestBehavior.opaque,
                child: Opacity(
                  opacity: _isDisplayingCurrentMonth ? 0.35 : 1,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.line),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.chevron_right_rounded,
                        size: 22,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Monthly stats bar
          _buildMonthStatsBar(),

          const SizedBox(height: 12),

          // Calendar grid
          _buildEmologMonthCalendar(),

          const SizedBox(height: 16),

          // Selected day detail
          _buildSelectedDayDetailCard(),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
