import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../core/theme/colors.dart';
import '../core/theme/motion.dart';
import '../core/theme/shadows.dart';
import '../core/theme/typography.dart';
import '../models/emotion.dart';
import '../state/mindra_state.dart';
import 'today_view.dart';
import 'checkin_view.dart';
import 'practice_view.dart';
import 'garden_view.dart';
import 'journal_view.dart';
import 'explore_view.dart';
import 'settings_view.dart';
import 'pause_mode_sheet.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<MindraState>();
    final currentTab = state.currentTab;

    final motion = MindraMotion.of(state.lowStimulationMode);
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: PreferredSize(
        // PreferredSize must include the status-bar inset because the custom
        // app bar also uses SafeArea internally.
        preferredSize: Size.fromHeight(80 + MediaQuery.paddingOf(context).top),
        child: _buildFlexibleAppBar(context, state, currentTab, motion),
      ),
      body: AnimatedSwitcher(
        duration: motion.mediumDuration,
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        child: KeyedSubtree(
          key: ValueKey<int>(currentTab),
          child: _buildView(state, currentTab),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(context, state, currentTab, motion),
    );
  }

  Widget _buildFlexibleAppBar(
    BuildContext context,
    MindraState state,
    int currentTab,
    MindraMotion motion,
  ) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
        child: AnimatedSwitcher(
          duration: motion.duration,
          child: KeyedSubtree(
            key: ValueKey<int>(currentTab),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 380;
                return SizedBox(
                  height: 64,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Flexible(
                        flex: 0,
                        child: _cornerChip(
                          padding: currentTab == 0
                              ? const EdgeInsets.symmetric(horizontal: 16)
                              : const EdgeInsets.symmetric(horizontal: 14),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: _buildAppBarLeading(
                              context,
                              state,
                              currentTab,
                              isCompact,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: _buildAppBarTrailing(
                              context,
                              state,
                              currentTab,
                              isCompact,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBarLeading(
    BuildContext context,
    MindraState state,
    int currentTab,
    bool isCompact,
  ) {
    switch (currentTab) {
      case 0:
        // Trang Hôm nay: Wordmark thương hiệu
        return RichText(
          text: TextSpan(
            style: AppTypography.headlineLarge.copyWith(
              fontSize: isCompact ? 19 : 23,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.2,
            ),
            children: [
              const TextSpan(text: 'm'),
              TextSpan(
                text: 'oo',
                style: TextStyle(
                  color: AppColors.orange,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const TextSpan(text: 'd'),
              TextSpan(
                text: 'i',
                style: TextStyle(
                  color: AppColors.blue,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        );

      case 1:
        // Calendar
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.orange.withValues(alpha: 0.16),
              ),
              child: const Center(
                child: Icon(
                  Icons.calendar_month_rounded,
                  size: 18,
                  color: AppColors.orange,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Nhật ký',
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ],
        );

      case 2:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.mint.withValues(alpha: 0.2),
              ),
              child: const Center(
                child: Icon(
                  Icons.local_florist_rounded,
                  size: 18,
                  color: AppColors.ink,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Khu vườn',
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ],
        );

      case 3:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.blue.withValues(alpha: 0.16),
              ),
              child: const Center(
                child: Icon(
                  Icons.explore_outlined,
                  size: 18,
                  color: AppColors.blue,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Khám phá',
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildAppBarTrailing(
    BuildContext context,
    MindraState state,
    int currentTab,
    bool isCompact,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Streak indicator (ở tab Hôm nay)
        if (currentTab == 0)
          Semantics(
            label: 'Chuỗi hiện diện: ${state.consecutiveWeeks} tuần',
            child: Padding(
              padding: EdgeInsets.only(right: isCompact ? 6 : 10),
              child: _cornerChip(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                    Text(
                      isCompact
                          ? '${state.consecutiveWeeks}'
                          : '${state.consecutiveWeeks} tuần',
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Mục Tôi mở hồ sơ, cài đặt và thông tin.
        _cornerChip(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Semantics(
            button: true,
            label: 'Tôi: hồ sơ và cài đặt',
            child: InkWell(
              onTap: () => _openProfileModal(context, state),
              borderRadius: BorderRadius.circular(48),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: isCompact ? 28 : 32,
                    height: isCompact ? 28 : 32,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF292B25),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      state.userInitial,
                      style: AppTypography.button.copyWith(
                        fontSize: 13,
                        color: AppColors.yellow,
                      ),
                    ),
                  ),
                  SizedBox(width: isCompact ? 4 : 7),
                  Text(
                    'Tôi',
                    style: AppTypography.button.copyWith(
                      fontSize: isCompact ? 11 : 13,
                      color: AppColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _openProfileModal(BuildContext context, MindraState state) {
    MindraMotion.of(state.lowStimulationMode).medium();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (modalCtx) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
          decoration: const BoxDecoration(
            color: AppColors.paper,
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
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.line,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.ink,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        state.userInitial,
                        style: AppTypography.headlineMedium.copyWith(
                          color: AppColors.yellow,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.userName,
                          style: AppTypography.titleLarge.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          state.userEmail.isEmpty
                              ? 'Tài khoản khách'
                              : state.userEmail,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.creamDark,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: AppShadows.card,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text(
                            '${state.totalCheckins}',
                            style: AppTypography.titleLarge.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text('Lần check-in', style: AppTypography.caption),
                        ],
                      ),
                      Container(height: 28, width: 1, color: AppColors.line),
                      Column(
                        children: [
                          Text(
                            '${state.consecutiveWeeks} tuần',
                            style: AppTypography.titleLarge.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text('Kiên trì', style: AppTypography.caption),
                        ],
                      ),
                      Container(height: 28, width: 1, color: AppColors.line),
                      Column(
                        children: [
                          Text(
                            '${state.uniqueCheckinDays}',
                            style: AppTypography.titleLarge.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.mint,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text('Ngày ghi nhận', style: AppTypography.caption),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Material(
                  color: Colors.transparent,
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.settings_rounded,
                          color: AppColors.ink,
                        ),
                        title: Text(
                          'Cài đặt & Bảo mật',
                          style: AppTypography.bodyMedium,
                        ),
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                        ),
                        onTap: () {
                          Navigator.pop(modalCtx);
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => Scaffold(
                                backgroundColor: AppColors.paper,
                                appBar: AppBar(
                                  backgroundColor: AppColors.paper,
                                  elevation: 0,
                                  scrolledUnderElevation: 0,
                                  leading: IconButton(
                                    icon: const Icon(
                                      Icons.arrow_back_rounded,
                                      color: AppColors.ink,
                                    ),
                                    onPressed: () => Navigator.pop(context),
                                  ),
                                  title: Text(
                                    'Cài đặt & Riêng tư',
                                    style: AppTypography.titleMedium.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  centerTitle: false,
                                ),
                                body: SettingsView(state: state),
                              ),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.info_outline_rounded,
                          color: AppColors.ink,
                        ),
                        title: Text(
                          'Về Mindra',
                          style: AppTypography.bodyMedium,
                        ),
                        trailing: Text('v1.0.0', style: AppTypography.caption),
                        onTap: () => Navigator.pop(modalCtx),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.logout_rounded,
                          color: Colors.red.shade700,
                        ),
                        title: Text(
                          'Đăng xuất',
                          style: AppTypography.bodyMedium.copyWith(
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: Colors.red.shade300,
                        ),
                        onTap: () {
                          Navigator.pop(modalCtx);
                          _showLogoutDialog(context, state);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLogoutDialog(BuildContext context, MindraState state) {
    MindraMotion.of(state.lowStimulationMode).light();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(
          'Đăng xuất khỏi Mindra?',
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Bạn sẽ cần đăng nhập lại để truy cập không gian cá nhân và các tính năng đồng bộ.',
          style: AppTypography.bodySmall,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Ở lại',
              style: TextStyle(color: AppColors.textTertiary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              unawaited(state.logout());
            },
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
  }

  Future<void> _openCheckinModal(
    BuildContext context,
    MindraState state,
  ) async {
    final prevCount = state.entries.length;
    MindraMotion.of(state.lowStimulationMode).light();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(modalCtx).viewInsets.bottom,
          ),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.90,
            decoration: const BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.ink.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 14, 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Check-in cảm xúc',
                          style: AppTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 22,
                            color: AppColors.ink,
                          ),
                          onPressed: () => Navigator.pop(modalCtx),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.line),
                  Expanded(
                    child: CheckinView(
                      state: state,
                      onClose: () => Navigator.pop(modalCtx),
                      onOpenJournal: () {
                        Navigator.pop(modalCtx);
                        state.setTab(1); // Calendar tab
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (!context.mounted) return;
    if (state.entries.length > prevCount) {
      _showPlantingCelebration(context, state);
    }
  }

  void _showPlantingCelebration(BuildContext context, MindraState state) {
    final latestEntry = state.entries.isNotEmpty ? state.entries.first : null;
    final emotion = latestEntry != null
        ? MindraEmotions.get(latestEntry.emotionKey)
        : state.selectedEmotion;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          decoration: const BoxDecoration(
            color: AppColors.cream,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.ink.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: emotion.tone.withValues(alpha: 0.35),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Text('🌱', style: TextStyle(fontSize: 32)),
                ),
                const SizedBox(height: 16),
                Text(
                  'Đã gieo một hạt mầm bình yên',
                  style: AppTypography.titleLarge.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Cảm xúc "${emotion.vi}" đã được ôm ấp và giữ lại trong Khu vườn tháng ${DateTime.now().month}. Cảm ơn bạn vì đã dành thời gian cho chính mình.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          foregroundColor: AppColors.ink,
                          side: const BorderSide(color: AppColors.line),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text('Đóng'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          state.setTab(2); // Go to Garden tab
                        },
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          backgroundColor: AppColors.ink,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Text('🌸', style: TextStyle(fontSize: 16)),
                        label: const Text(
                          'Xem khu vườn',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openPauseModeModal(BuildContext context, MindraState state) {
    MindraMotion.of(state.lowStimulationMode).light();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.90,
          decoration: const BoxDecoration(
            color: AppColors.paper,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.ink.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 14, 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.mint.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.pause_circle_filled_rounded,
                                  size: 16,
                                  color: AppColors.ink,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Khoảng nghỉ',
                                  style: AppTypography.caption.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Dừng lại 30s',
                            style: AppTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 22,
                          color: AppColors.ink,
                        ),
                        onPressed: () => Navigator.pop(modalCtx),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.line),
                Expanded(
                  child: PauseModeSheet(
                    state: state,
                    onClose: () => Navigator.pop(modalCtx),
                    onOpenFullCheckin: () {
                      Navigator.pop(modalCtx);
                      _openCheckinModal(context, state);
                    },
                    onOpenPractice: () {
                      Navigator.pop(modalCtx);
                      _openPracticePage(state);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openPracticePage(MindraState state) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: AppColors.paper,
          appBar: AppBar(
            backgroundColor: AppColors.paper,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: Text(
              'Bài tập ngắn',
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          body: PracticeView(state: state),
        ),
      ),
    );
  }

  Widget _buildView(MindraState state, int tab) {
    switch (tab) {
      case 0: // Home
        return TodayView(
          state: state,
          onOpenCheckin: () => _openCheckinModal(context, state),
          onOpenJournal: () => state.setTab(1),
          onOpenPause: () => _openPauseModeModal(context, state),
          onOpenPractice: () => _openPracticePage(state),
          onOpenGarden: () => state.setTab(2),
        );
      case 1:
        return JournalView(state: state);
      case 2:
        return GardenView(
          state: state,
          onOpenCheckin: () => _openCheckinModal(context, state),
          onOpenJournal: () => state.setTab(1),
        );
      case 3:
        return ExploreView(
          state: state,
          onOpenCheckin: () => _openCheckinModal(context, state),
        );
      default:
        return TodayView(
          state: state,
          onOpenCheckin: () => _openCheckinModal(context, state),
          onOpenJournal: () => state.setTab(1),
          onOpenPause: () => _openPauseModeModal(context, state),
          onOpenPractice: () => _openPracticePage(state),
          onOpenGarden: () => state.setTab(2),
        );
    }
  }

  Widget _buildBottomNav(
    BuildContext context,
    MindraState state,
    int currentTab,
    MindraMotion motion,
  ) {
    final textScale = MediaQuery.textScalerOf(context).scale(9) / 9;
    final navContentHeight = textScale > 1 ? 52 + 16 * (textScale - 1) : 52.0;
    final items = [
      (icon: CupertinoIcons.house, label: 'Hôm nay'),
      (icon: CupertinoIcons.book, label: 'Nhật ký'),
      (icon: Icons.local_florist_outlined, label: 'Khu vườn'),
      (icon: CupertinoIcons.compass, label: 'Khám phá'),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.paper,
        border: Border(
          top: BorderSide(
            color: AppColors.line.withValues(alpha: 0.6),
            width: 0.6,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: navContentHeight,
          child: Row(
            children: items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isActive = currentTab == index;

              return Expanded(
                child: Semantics(
                  button: true,
                  selected: isActive,
                  label: '${item.label}${isActive ? ', selected' : ''}',
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => state.setTab(index),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              item.icon,
                              size: 22,
                              shadows: isActive
                                  ? const [
                                      Shadow(
                                        color: AppColors.orange,
                                        offset: Offset(0.35, 0),
                                      ),
                                      Shadow(
                                        color: AppColors.orange,
                                        offset: Offset(-0.35, 0),
                                      ),
                                    ]
                                  : null,
                              color: isActive
                                  ? AppColors.orange
                                  : AppColors.textMuted,
                            ),
                            const SizedBox(height: 3),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                item.label,
                                maxLines: 1,
                                textAlign: TextAlign.center,
                                style: AppTypography.kicker.copyWith(
                                  fontSize: 11,
                                  letterSpacing: 0,
                                  color: isActive
                                      ? AppColors.orange
                                      : AppColors.textMuted,
                                  fontWeight: isActive
                                      ? FontWeight.w800
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _cornerChip({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(horizontal: 14),
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(48),
        boxShadow: AppShadows.chip,
      ),
      child: Container(
        height: 52,
        padding: padding,
        child: Center(widthFactor: 1.0, child: child),
      ),
    );
  }
}
