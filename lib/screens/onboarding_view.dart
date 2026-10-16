import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/colors.dart';
import '../core/theme/motion.dart';
import '../core/theme/typography.dart';
import '../state/mindra_state.dart';

class OnboardingView extends StatefulWidget {
  final VoidCallback? onFinished;

  const OnboardingView({super.key, this.onFinished});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // S02 Goals state
  final Set<String> _selectedGoals = {
    'Hiểu cảm xúc của tôi',
    'Giảm căng thẳng hằng ngày',
  };

  // S03 Reminder state
  String _selectedReminderKey =
      'evening'; // morning, afternoon, evening, custom, none
  TimeOfDay _customTime = const TimeOfDay(hour: 20, minute: 0);

  final List<String> _allGoals = const [
    'Hiểu cảm xúc của tôi',
    'Giảm căng thẳng hằng ngày',
    'Phản hồi bình tĩnh hơn',
    'Xây dựng khả năng nhận biết cảm xúc',
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  MindraMotion _motion(BuildContext context) {
    return MindraMotion.of(context.read<MindraState>().lowStimulationMode);
  }

  void _nextPage() {
    final motion = _motion(context);
    motion.light();
    if (_currentPage < 3) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: motion.mediumDuration,
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _finishOnboarding(MindraState state) {
    MindraMotion.of(state.lowStimulationMode).medium();
    // Save goals
    for (final goal in _selectedGoals) {
      if (!state.userGoals.contains(goal)) {
        state.toggleGoal(goal);
      }
    }
    // Save reminder
    if (_selectedReminderKey == 'none') {
      state.setReminderEnabled(false);
    } else {
      state.setReminderEnabled(true);
      if (_selectedReminderKey == 'morning') {
        state.setReminderTime('08:00');
      } else if (_selectedReminderKey == 'afternoon') {
        state.setReminderTime('14:00');
      } else if (_selectedReminderKey == 'evening') {
        state.setReminderTime('21:00');
      } else if (_selectedReminderKey == 'custom') {
        final h = _customTime.hour.toString().padLeft(2, '0');
        final m = _customTime.minute.toString().padLeft(2, '0');
        state.setReminderTime('$h:$m');
      }
    }

    state.completeOnboarding();
    // Không authenticate ở đây — sau onboarding sẽ chuyển đến LoginView thật
    if (widget.onFinished != null) {
      widget.onFinished!();
    }
  }

  void _showHowItWorksModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        decoration: const BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
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
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.yellow.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('✨', style: TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 12),
                Text(
                  'Mindra hoạt động ra sao?',
                  style: AppTypography.headlineMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildHowItWorksStep(
              number: '1',
              title: 'Gọi tên cảm xúc & cường độ',
              desc: 'Dừng lại 30 giây để nhận biết điều gì đang diễn ra bên trong bạn mà không phán xét.',
              color: AppColors.yellow,
            ),
            const SizedBox(height: 14),
            _buildHowItWorksStep(
              number: '2',
              title: 'Phản tư có hướng dẫn',
              desc: 'Tách biệt giữa sự thật khách quan và các suy nghĩ đang phóng đại cảm xúc khó.',
              color: AppColors.blue,
            ),
            const SizedBox(height: 14),
            _buildHowItWorksStep(
              number: '3',
              title: 'Rèn luyện công cụ & khu vườn',
              desc: 'Thực hành các kỹ thuật tiếp đất, tự trắc ẩn và nuôi dưỡng sự kiên định trong khu vườn tâm trí.',
              color: AppColors.mint,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.ink,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text('Đã hiểu', style: AppTypography.button),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHowItWorksStep({
    required String number,
    required String title,
    required String desc,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1.5),
          ),
          child: Text(
            number,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showPrivacyDetailsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        decoration: const BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
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
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Icon(Icons.lock_outline, color: AppColors.ink, size: 24),
                const SizedBox(width: 10),
                Text(
                  'Cam kết quyền riêng tư',
                  style: AppTypography.headlineMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '• Dữ liệu nhật ký được mã hóa và lưu trữ an toàn trên thiết bị của bạn.\n'
              '• Phản tư AI chỉ sử dụng các từ khóa cảm xúc tối thiểu và không liên kết danh tính cá nhân.\n'
              '• Không bán dữ liệu, không chia sẻ với bên thứ ba cho mục đích quảng cáo.\n'
              '• Bạn có toàn quyền xuất hoặc xóa vĩnh viễn toàn bộ dữ liệu bất kỳ lúc nào trong phần Cài đặt.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.ink,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text('Đóng', style: AppTypography.button),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MindraState>();

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: Column(
          children: [
            // Top indicator bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                      color: AppColors.ink,
                      onPressed: () {
                        _pageController.previousPage(
                          duration: _motion(context).mediumDuration,
                          curve: Curves.easeInOut,
                        );
                      },
                    )
                  else
                    const SizedBox(width: 40),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (index) {
                        final isActive = index == _currentPage;
                        return AnimatedContainer(
                          duration: _motion(context).mediumDuration,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: isActive ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isActive ? AppColors.ink : AppColors.line,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),

            // Page View
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: [
                  _buildS01Welcome(),
                  _buildS02Goals(),
                  _buildS03Reminders(),
                  _buildS04Safety(state),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // S01: Welcome Screen
  Widget _buildS01Welcome() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          // Visual Icon Orb
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  AppColors.yellow.withValues(alpha: 0.35),
                  AppColors.mint.withValues(alpha: 0.2),
                  Colors.transparent,
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.cream,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.line, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.ink.withValues(alpha: 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text('🌱', style: TextStyle(fontSize: 34)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Mindra',
            style: AppTypography.displayMedium.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Hiểu cảm xúc. Chủ động chọn cách phản hồi.',
            textAlign: TextAlign.center,
            style: AppTypography.headlineMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Không gian riêng tư để phản tư cảm xúc, nhận diện pattern và giảm căng thẳng hằng ngày.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _nextPage,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.ink,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 0,
              ),
              child: Text(
                'Bắt đầu',
                style: AppTypography.button.copyWith(fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => _showHowItWorksModal(context),
            child: Text(
              'Mindra hoạt động như thế nào?',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // S02: Select Goals
  Widget _buildS02Goals() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            'Mục tiêu của bạn',
            style: AppTypography.caption.copyWith(
              color: AppColors.orange,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Bạn muốn tập trung vào điều gì?',
            style: AppTypography.displayLarge.copyWith(
              fontSize: 26,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Chọn một hoặc nhiều mục tiêu để Mindra đồng hành cùng bạn.',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.separated(
              itemCount: _allGoals.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final goal = _allGoals[index];
                final isSelected = _selectedGoals.contains(goal);

                return InkWell(
                  onTap: () {
                    _motion(context).selection();
                    setState(() {
                      if (isSelected) {
                        if (_selectedGoals.length > 1) {
                          _selectedGoals.remove(goal);
                        }
                      } else {
                        _selectedGoals.add(goal);
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.yellow.withValues(alpha: 0.16)
                          : AppColors.cream,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isSelected ? AppColors.yellow : AppColors.line,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.ink
                                : Colors.transparent,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.ink
                                  : AppColors.line,
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  size: 16,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            goal,
                            style: AppTypography.bodyMedium.copyWith(
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedGoals.isNotEmpty ? _nextPage : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.ink,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 0,
              ),
              child: Text(
                'Tiếp tục',
                style: AppTypography.button.copyWith(fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // S03: Reminders setup
  Widget _buildS03Reminders() {
    final reminderOptions = [
      {
        'key': 'morning',
        'title': 'Buổi sáng (08:00)',
        'desc': 'Khởi đầu ngày mới với sự tĩnh lặng',
      },
      {
        'key': 'afternoon',
        'title': 'Buổi chiều (14:00)',
        'desc': 'Dừng lại nạp năng lượng giữa ngày',
      },
      {
        'key': 'evening',
        'title': 'Buổi tối (21:00)',
        'desc': 'Lắng đọng và thư giãn trước giấc ngủ',
      },
      {
        'key': 'custom',
        'title': 'Giờ tùy chỉnh',
        'desc': 'Chọn thời gian phù hợp nhất với bạn',
      },
      {
        'key': 'none',
        'title': 'Không nhắc',
        'desc': 'Tự mở ứng dụng khi bạn muốn',
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            'Nhịp điệu hằng ngày',
            style: AppTypography.caption.copyWith(
              color: AppColors.mint,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Khi nào bạn muốn dừng lại?',
            style: AppTypography.displayLarge.copyWith(
              fontSize: 26,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Một lời nhắc nhẹ nhàng mỗi ngày để bạn kết nối lại với chính mình.',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.separated(
              itemCount: reminderOptions.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final opt = reminderOptions[index];
                final isSelected = _selectedReminderKey == opt['key'];

                return InkWell(
                  onTap: () async {
                    _motion(context).selection();
                    if (opt['key'] == 'custom') {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _customTime,
                      );
                      if (picked != null) {
                        setState(() {
                          _customTime = picked;
                          _selectedReminderKey = 'custom';
                        });
                      }
                    } else {
                      setState(() {
                        _selectedReminderKey = opt['key']!;
                      });
                    }
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.mint.withValues(alpha: 0.14)
                          : AppColors.cream,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? AppColors.mint : AppColors.line,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: isSelected ? AppColors.ink : AppColors.line,
                          size: 22,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                opt['key'] == 'custom'
                                    ? 'Giờ tùy chỉnh (${_customTime.format(context)})'
                                    : opt['title']!,
                                style: AppTypography.bodyMedium.copyWith(
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                  color: AppColors.ink,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                opt['desc']!,
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _nextPage,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.ink,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 0,
              ),
              child: Text(
                'Tiếp tục',
                style: AppTypography.button.copyWith(fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // S04: Safety & Disclaimer
  Widget _buildS04Safety(MindraState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            'Cam kết an toàn',
            style: AppTypography.caption.copyWith(
              color: AppColors.blue,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Không gian riêng tư của bạn',
            style: AppTypography.displayLarge.copyWith(
              fontSize: 26,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 24),
          // Safety card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.line),
              boxShadow: [
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.blue.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.shield_outlined,
                        color: AppColors.blue,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Tự phản tư & hỗ trợ',
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Mindra hỗ trợ bạn tự phản tư và quản lý căng thẳng thường ngày.\n\n'
                  'Ứng dụng không chẩn đoán tình trạng sức khỏe tinh thần, không cung cấp trị liệu y khoa và không thay thế hỗ trợ chuyên môn.\n\n'
                  'Mọi dữ liệu phản tư hoàn toàn thuộc về bạn và nằm trong tầm kiểm soát của bạn.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _finishOnboarding(state),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.ink,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 0,
              ),
              child: Text(
                'Tôi hiểu và bắt đầu',
                style: AppTypography.button.copyWith(fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: TextButton(
              onPressed: () => _showPrivacyDetailsModal(context),
              child: Text(
                'Chi tiết về quyền riêng tư',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
