import '../widgets/entry_sync_notice.dart';
import '../core/garden_actions.dart';

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

class JournalView extends StatefulWidget {
  final MindraState state;

  const JournalView({super.key, required this.state});

  @override
  State<JournalView> createState() => _JournalViewState();
}

class _JournalViewState extends State<JournalView> {
  late DateTime _selectedDate;
  late DateTime _displayedMonth;
  final TextEditingController _searchController = TextEditingController();
  String? _selectedFilterKey;
  String _searchQuery = '';
  String? _selectedTriggerFilter;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _displayedMonth = DateTime(now.year, now.month, 1);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesSearch(JournalEntry e) {
    if (_searchQuery.isEmpty) return true;
    final q = _searchQuery.toLowerCase();
    return e.situation.toLowerCase().contains(q) ||
        e.thought.toLowerCase().contains(q) ||
        e.response.toLowerCase().contains(q);
  }

  bool _matchesTriggerFilter(JournalEntry e) {
    if (_selectedTriggerFilter == null) return true;
    return e.trigger == _selectedTriggerFilter;
  }

  bool _isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  bool _isToday(DateTime d) {
    return _isSameDay(d, DateTime.now());
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
      _selectedFilterKey = null;
      _selectedTriggerFilter = null;
    });
  }

  void _nextMonth() {
    MindraMotion.of(widget.state.lowStimulationMode).light();
    setState(() {
      _displayedMonth = DateTime(
        _displayedMonth.year,
        _displayedMonth.month + 1,
        1,
      );
      _selectedDate = _displayedMonth;
      _selectedFilterKey = null;
      _selectedTriggerFilter = null;
    });
  }

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
  void _openQuickLogForDate(
    DateTime targetDate, [
    JournalEntry? existingEntry,
  ]) {
    MindraMotion.of(widget.state.lowStimulationMode).medium();
    final isEditing = existingEntry != null;
    String selectedKey = existingEntry?.emotionKey ?? 'calm';
    int intensity = existingEntry?.intensity ?? 3;
    final noteController = TextEditingController(
      text: existingEntry?.situation ?? '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalContext).viewInsets.bottom + 24,
                top: 20,
                left: 20,
                right: 20,
              ),
              decoration: const BoxDecoration(
                color: AppColors.cream,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: AppColors.line,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isEditing
                                    ? 'SỬA NHẬT KÝ CẢM XÚC'
                                    : 'GHI NHẬN CẢM XÚC',
                                style: AppTypography.kicker,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatDateHeader(targetDate),
                                style: AppTypography.titleLarge.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(modalContext),
                          icon: const Icon(Icons.close_rounded, size: 24),
                          color: AppColors.textTertiary,
                          constraints: const BoxConstraints(
                            minWidth: 44,
                            minHeight: 44,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Chọn cảm xúc (Faces)
                    Text(
                      'Bạn cảm thấy thế nào vào ngày này?',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 84,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        physics: MindraMotion.of(
                          widget.state.lowStimulationMode,
                        ).scrollPhysics,
                        children: MindraEmotions.primaryKeys.map((key) {
                          final emo = MindraEmotions.get(key);
                          final isSelected = selectedKey == key;
                          return GestureDetector(
                            onTap: () {
                              MindraMotion.of(widget.state.lowStimulationMode)
                                  .selection();
                              setModalState(() => selectedKey = key);
                            },
                            child: AnimatedContainer(
                              duration: MindraMotion.of(
                                widget.state.lowStimulationMode,
                              ).duration,
                              margin: const EdgeInsets.only(right: 12),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.ink
                                      : AppColors.line,
                                  width: isSelected ? 1.8 : 1.0,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: AppColors.ink.withValues(
                                            alpha: 0.08,
                                          ),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  MoodFace(faceType: emo.face, size: 36),
                                  const SizedBox(height: 6),
                                  Text(
                                    emo.vi,
                                    style: AppTypography.caption.copyWith(
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? AppColors.ink
                                          : AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 18),
                    // Chọn mức độ (1-5)
                    Row(
                      children: [
                        Text('Mức độ: ', style: AppTypography.bodyMedium),
                        Text(
                          '$intensity/5',
                          style: AppTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        ...List.generate(5, (index) {
                          final lvl = index + 1;
                          final isReached = lvl <= intensity;
                          return GestureDetector(
                            onTap: () {
                              MindraMotion.of(widget.state.lowStimulationMode)
                                  .selection();
                              setModalState(() => intensity = lvl);
                            },
                            behavior: HitTestBehavior.opaque,
                            child: SizedBox(
                              width: 36,
                              height: 44, // 44pt touch area
                              child: Center(
                                child: Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isReached
                                        ? AppColors.ink
                                        : AppColors.line,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),

                    const SizedBox(height: 14),
                    // Ghi chú ngắn
                    TextField(
                      maxLength: 4000,
                      controller: noteController,
                      maxLines: 2,
                      style: AppTypography.bodyMedium,
                      decoration: InputDecoration(
                        hintText: 'Thêm vài dòng ghi chép nhẹ nhàng (không bắt buộc)...',
                        hintStyle: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textTertiary,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.all(14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: AppColors.line),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: AppColors.line),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: AppColors.ink,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                    // Nút lưu / cập nhật
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.ink,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        onPressed: () {
                          MindraMotion.of(widget.state.lowStimulationMode)
                              .medium();
                          late final String savedId;
                          if (isEditing) {
                            savedId = existingEntry.id;
                            final updatedEntry = existingEntry.copyWith(
                              emotionKey: selectedKey,
                              intensity: intensity,
                              situation: noteController.text.trim(),
                            );
                            widget.state.updateEntry(updatedEntry);
                          } else {
                            final newEntry = JournalEntry(
                              id: 'entry-${DateTime.now().millisecondsSinceEpoch}',
                              timestamp: DateTime(
                                targetDate.year,
                                targetDate.month,
                                targetDate.day,
                                DateTime.now().hour,
                                DateTime.now().minute,
                              ),
                              emotionKey: selectedKey,
                              intensity: intensity,
                              situation: noteController.text.trim(),
                            );
                            savedId = newEntry.id;
                            widget.state.addEntry(newEntry);
                          }
                          Navigator.pop(modalContext);
                          setState(() {
                            _selectedDate = targetDate;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                widget.state.entrySaveMessage(savedId),
                              ),
                              backgroundColor: AppColors.ink,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        child: Text(
                          isEditing ? 'Lưu thay đổi' : 'Lưu vào nhật ký',
                          style: AppTypography.titleMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    if (isEditing) ...[
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.orange,
                            minimumSize: const Size(44, 44),
                          ),
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                          ),
                          label: Text(
                            'Xóa ghi chép này',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.orange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(modalContext);
                            _confirmDeleteEntry(existingEntry);
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Hộp thoại xác nhận xóa entry
  void _confirmDeleteEntry(JournalEntry entry) {
    MindraMotion.of(widget.state.lowStimulationMode).light();
    final emo = MindraEmotions.get(entry.emotionKey);
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
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
            onPressed: () => Navigator.pop(dialogCtx),
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
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () async {
              try {
                await widget.state.removeEntry(entry.id);
              } catch (_) {
                if (!dialogCtx.mounted) return;
                ScaffoldMessenger.of(dialogCtx).showSnackBar(
                  const SnackBar(
                    content: Text('Chưa xóa được ghi chép. Hãy thử lại.'),
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
            child: const Text('Xóa'),
          ),
        ],
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
                          selected: isSelected,
                          label: tooltipText,
                          child: GestureDetector(
                            onTap: () => _onDateSelected(cellDate),
                            behavior: HitTestBehavior.opaque,
                            child: AnimatedContainer(
                              duration: MindraMotion.of(
                                widget.state.lowStimulationMode,
                              ).duration,
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              height: 52,
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
                                                : AppColors.textMuted),
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
                        color: AppColors.orange,
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
                  constraints: const BoxConstraints(minHeight: 36),
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
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () async {
                                if (widget.state.isPlanted(entry.id)) {
                                  widget.state.openGarden();
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
                          if (widget.state.reflectionForEntry(entry.id) != null)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () {
                                  final reflection = widget.state
                                      .reflectionForEntry(entry.id);
                                  if (reflection == null) return;
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
                                label: const Text('Xem phản tư'),
                              ),
                            ),
                          if (entry.exerciseDone &&
                              entry.exerciseId != null) ...[
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

  // ignore: unused_element — preserved for future reactivation
  Widget _buildTimelineView() {
    var allEntries = List<JournalEntry>.from(widget.state.entries)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Apply all three filters: emotion, trigger, search query
    if (_selectedFilterKey != null) {
      allEntries = allEntries
          .where((e) => e.emotionKey == _selectedFilterKey)
          .toList();
    }
    allEntries = allEntries.where(_matchesTriggerFilter).toList();
    allEntries = allEntries.where(_matchesSearch).toList();

    final triggers = <String>[];
    for (final e in widget.state.entries) {
      if (e.trigger.isNotEmpty &&
          e.trigger != 'other' &&
          !triggers.contains(e.trigger)) {
        triggers.add(e.trigger);
      }
    }

    final triggerLabels = {
      'work': 'Công việc',
      'family': 'Gia đình',
      'social': 'Quan hệ',
      'friends': 'Bạn bè',
      'relationship': 'Tình cảm',
      'health': 'Sức khỏe',
      'self_care': 'Bản thân',
      'rest': 'Nghỉ ngơi',
      'finance': 'Tài chính',
      'study': 'Học tập',
      'uncertainty': 'Chưa rõ',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search bar
        Container(
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 12),
                child: Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: AppColors.gray,
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: AppTypography.bodySmall,
                  decoration: InputDecoration(
                    hintText: 'Tìm theo tình huống, suy nghĩ...',
                    hintStyle: AppTypography.bodySmall.copyWith(
                      color: AppColors.gray,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    isDense: true,
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),
              if (_searchQuery.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16),
                  color: AppColors.gray,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Trigger filter chips (only shown when there are trigger values)
        if (triggers.isNotEmpty) ...[
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: MindraMotion.of(widget.state.lowStimulationMode)
                  .scrollPhysics,
              children: [
                if (_selectedTriggerFilter != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Semantics(
                      button: true,
                      label: 'Xóa bộ lọc tác nhân',
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () =>
                            setState(() => _selectedTriggerFilter = null),
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 44),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.ink,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.tag_rounded,
                                size: 12,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                triggerLabels[_selectedTriggerFilter] ??
                                    _selectedTriggerFilter!,
                                style: AppTypography.caption.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.close_rounded,
                                size: 12,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ...triggers.map((t) {
                  final isSelected = _selectedTriggerFilter == t;
                  if (isSelected) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Semantics(
                      button: true,
                      label: 'Lọc theo tác nhân ${triggerLabels[t] ?? t}',
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          MindraMotion.of(widget.state.lowStimulationMode)
                              .selection();
                          setState(() => _selectedTriggerFilter = t);
                        },
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 44),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.paper,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.line),
                          ),
                          child: Text(
                            triggerLabels[t] ?? t,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],

        // Bộ lọc cảm xúc nhanh (Touch target >= 44pt theo spec)
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: MindraMotion.of(widget.state.lowStimulationMode)
                .scrollPhysics,
            children: [
              _buildFilterChip(
                label: 'Tất cả (${widget.state.entries.length})',
                isSelected: _selectedFilterKey == null,
                onTap: () => setState(() => _selectedFilterKey = null),
              ),
              ...MindraEmotions.primaryKeys.map((key) {
                final emo = MindraEmotions.get(key);
                final count = widget.state.entries
                    .where((e) => e.emotionKey == key)
                    .length;
                if (count == 0) return const SizedBox.shrink();
                return _buildFilterChip(
                  label: '${emo.vi} ($count)',
                  isSelected: _selectedFilterKey == key,
                  onTap: () => setState(() => _selectedFilterKey = key),
                  leadingFace: emo.face,
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (allEntries.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.circular(24),
              boxShadow: AppShadows.card,
            ),
            child: Center(
              child: Text(
                'Không có ghi chép nào phù hợp.',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: allEntries.length,
            separatorBuilder: (_, _) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final entry = allEntries[index];
              final emo = MindraEmotions.get(entry.emotionKey);

              return Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.cream,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: AppShadows.card,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        MoodFace(faceType: emo.face, size: 36),
                        const SizedBox(width: 12),
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
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    DateFormat('dd/MM/yyyy · HH:mm')
                                        .format(entry.timestamp),
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.textTertiary,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: emo.tone.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Mức ${entry.intensity}/5',
                                      style: AppTypography.caption.copyWith(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.ink,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
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
                            onPressed: () =>
                                _openQuickLogForDate(entry.timestamp, entry),
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
                            onPressed: () => _confirmDeleteEntry(entry),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (entry.situation.isNotEmpty)
                      Text(
                        entry.situation,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.ink,
                          height: 1.4,
                        ),
                      ),
                    if (entry.thought.isNotEmpty &&
                        entry.thought != entry.situation) ...[
                      const SizedBox(height: 6),
                      Text(
                        '“${entry.thought}”',
                        style: AppTypography.bodySmall.copyWith(
                          fontStyle: FontStyle.italic,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    String? leadingFace,
  }) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: 'Lọc $label',
      child: GestureDetector(
        onTap: () {
          MindraMotion.of(widget.state.lowStimulationMode).selection();
          onTap();
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.ink : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isSelected ? AppColors.ink : AppColors.line,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leadingFace != null) ...[
                MoodFace(faceType: leadingFace, size: 16),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: AppTypography.caption.copyWith(
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
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
                  text: TextSpan(
                    style: AppTypography.displayMedium.copyWith(fontSize: 22),
                    children: [
                      TextSpan(
                        text: monthName.toUpperCase(),
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: AppColors.orange,
                        ),
                      ),
                      TextSpan(
                        text: ' ${_displayedMonth.year}',
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
                onTap: _nextMonth,
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
                      Icons.chevron_right_rounded,
                      size: 22,
                      color: AppColors.ink,
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
