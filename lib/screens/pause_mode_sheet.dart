import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/colors.dart';
import '../core/theme/motion.dart';
import '../core/theme/typography.dart';
import '../models/journal_entry.dart';
import '../models/emotion.dart';
import '../state/mindra_state.dart';
import '../widgets/mood_face.dart';

class PauseModeSheet extends StatefulWidget {
  final MindraState state;
  final VoidCallback onClose;
  final VoidCallback onOpenFullCheckin;
  final VoidCallback onOpenPractice;

  const PauseModeSheet({
    super.key,
    required this.state,
    required this.onClose,
    required this.onOpenFullCheckin,
    required this.onOpenPractice,
  });

  @override
  State<PauseModeSheet> createState() => _PauseModeSheetState();
}

class _PauseModeSheetState extends State<PauseModeSheet>
    with TickerProviderStateMixin {
  int _currentStep = 0; // 0: Body, 1: Breath, 2: Emotion, 3: Action

  // Step 1: Body Sensation
  String? _selectedSensation;
  final List<({String icon, String label, String desc})> _sensations = const [
    (
      icon: '🌬️',
      label: 'Căng cơ vai / gáy / cổ',
      desc: 'Cơ thể đang gồng cứng lại',
    ),
    (
      icon: '💓',
      label: 'Thắt nghẹn / tức ở ngực',
      desc: 'Hơi thở nông, tim đập nhanh',
    ),
    (
      icon: '🌀',
      label: 'Bồn chồn / quặn ở bụng',
      desc: 'Cảm giác lo âu hoặc bất an',
    ),
    (
      icon: '🧠',
      label: 'Căng trán / nặng đầu',
      desc: 'Suy nghĩ dồn dập, quá tải',
    ),
    (
      icon: '🌿',
      label: 'Kiệt sức / rã rời toàn thân',
      desc: 'Cạn năng lượng, cần nghỉ ngơi',
    ),
    (
      icon: '⚪',
      label: 'Không rõ / Chưa cảm nhận được',
      desc: 'Cảm giác mơ hồ, tê liệt',
    ),
  ];

  // Step 2: Guided Breath
  late AnimationController _breathController;
  late Animation<double> _breathScale;
  Timer? _breathPhaseTimer;
  String _breathPhaseText = 'Hít vào chậm...';
  int _breathCyclesLeft = 3;

  // Step 3: Emotion Labeling
  String _selectedEmotionKey = 'stressed';
  bool _isNotSure = false;

  // Step 4: Next Action
  String _selectedAction = 'Uống một ngụm nước ấm';
  final List<({String icon, String title, String subtitle})> _actions = const [
    (
      icon: '💧',
      title: 'Uống một ngụm nước ấm',
      subtitle: 'Kích hoạt phản xạ xoa dịu thần kinh',
    ),
    (
      icon: '🚶',
      title: 'Rời màn hình 3 - 5 phút',
      subtitle: 'Thay đổi không gian thị giác và cơ thể',
    ),
    (
      icon: '🛋️',
      title: 'Nghỉ ngơi không phán xét',
      subtitle: 'Cho phép mình được tạm dừng hoàn toàn',
    ),
    (
      icon: '🧘',
      title: 'Thực hành bài tập điều hòa',
      subtitle: 'Tiếp đất 5-4-3-2-1 hoặc Response Pause',
    ),
    (
      icon: '📝',
      title: 'Viết ra những suy nghĩ này',
      subtitle: 'Mở check-in chi tiết để gỡ rối tâm trí',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initBreathAnimation();
  }

  void _initBreathAnimation() {
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    _breathScale = Tween<double>(begin: 0.85, end: 1.25).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOutSine),
    );

    _breathController.addStatusListener((status) {
      if (!mounted) return;
      if (status == AnimationStatus.completed) {
        setState(() {
          _breathPhaseText = 'Thở ra nhẹ nhàng...';
        });
        _breathController.reverse();
      } else if (status == AnimationStatus.dismissed) {
        if (_breathCyclesLeft > 1) {
          setState(() {
            _breathCyclesLeft--;
            _breathPhaseText = 'Hít vào chậm...';
          });
          _breathController.forward();
        } else {
          // Finished breath cycles
          MindraMotion.of(widget.state.lowStimulationMode).light();
          setState(() {
            _breathPhaseText = 'Tốt lắm, cơ thể đã nhận được oxy.';
          });
        }
      }
    });

    _breathController.forward();
  }

  @override
  void dispose() {
    _breathPhaseTimer?.cancel();
    _breathController.dispose();
    super.dispose();
  }

  void _savePauseModeEntry() {
    MindraMotion.of(widget.state.lowStimulationMode).medium();
    final emoKey = _isNotSure ? 'calm' : _selectedEmotionKey;
    final emo = MindraEmotions.get(emoKey);

    final entry = JournalEntry(
      id: 'pause-${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      emotionKey: emoKey,
      intensity: 3,
      trigger: 'Tạm dừng khi quá tải',
      situation:
          'Pause Mode: ${_selectedSensation ?? "Cơ thể căng thẳng"} · Tiếp theo: $_selectedAction',
      thought: _isNotSure
          ? 'Tôi chưa rõ cảm xúc hiện tại, nhưng tôi đã cho phép mình dừng lại 1 phút.'
          : emo.defaultThought,
      response: _selectedAction,
      exerciseDone: true,
      exerciseId: 'response-pause',
      afterIntensity: 2,
    );

    widget.state.addEntry(entry);
    widget.onClose();

    if (_selectedAction == 'Thực hành bài tập điều hòa') {
      widget.onOpenPractice();
    } else if (_selectedAction == 'Viết ra những suy nghĩ này') {
      widget.onOpenFullCheckin();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Text('🌿', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Đã ghi nhận nhịp dừng. Hãy thực hiện "$_selectedAction" bạn nhé.',
                  style: AppTypography.bodySmall.copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.ink,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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

            // Top Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 14, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.blue.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'KHOẢNG NGHỈ',
                          style: AppTypography.kicker.copyWith(
                            color: AppColors.blue,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Bước ${_currentStep + 1}/4',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textTertiary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: widget.onClose,
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 22,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),

            // Progress bar
            LinearProgressIndicator(
              value: (_currentStep + 1) / 4,
              backgroundColor: AppColors.lineLight,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.blue),
              minHeight: 3,
            ),

            // Body content
            Expanded(
              child: AnimatedSwitcher(
                duration: MindraMotion.of(widget.state.lowStimulationMode)
                    .mediumDuration,
                child: KeyedSubtree(
                  key: ValueKey<int>(_currentStep),
                  child: _buildCurrentStepView(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStepView() {
    switch (_currentStep) {
      case 0:
        return _buildStep1BodySensation();
      case 1:
        return _buildStep2Breath();
      case 2:
        return _buildStep3Emotion();
      case 3:
        return _buildStep4Action();
      default:
        return const SizedBox.shrink();
    }
  }

  // BƯỚC 1: NHẬN BIẾT CẢM GIÁC CƠ THỂ
  Widget _buildStep1BodySensation() {
    return SingleChildScrollView(
      physics: MindraMotion.of(widget.state.lowStimulationMode).scrollPhysics,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '1. Lắng nghe cơ thể',
            style: AppTypography.kicker.copyWith(color: AppColors.orange),
          ),
          const SizedBox(height: 6),
          Text(
            'Lúc này cơ thể bạn đang cảm thấy thế nào?',
            style: AppTypography.displayMedium.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Khi cảm xúc dồn nén, cơ thể thường phản ứng trước suy nghĩ. Hãy dừng lại 5 giây và nhận diện vùng căng cứng nhất:',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),

          ..._sensations.map((item) {
            final isSelected = _selectedSensation == item.label;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () {
                  MindraMotion.of(widget.state.lowStimulationMode).selection();
                  setState(() => _selectedSensation = item.label);
                },
                borderRadius: BorderRadius.circular(18),
                child: AnimatedContainer(
                  duration: MindraMotion.of(widget.state.lowStimulationMode)
                      .duration,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.creamDark : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected ? AppColors.ink : AppColors.line,
                      width: isSelected ? 1.8 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(item.icon, style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.label,
                              style: AppTypography.bodyMedium.copyWith(
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.desc,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.ink,
                          size: 20,
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                MindraMotion.of(widget.state.lowStimulationMode).light();
                setState(() => _currentStep = 1);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.ink,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: const Text('Tiếp tục với nhịp thở (Bước 2/4)'),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // BƯỚC 2: MỘT NHỊP THỞ CHẬM
  Widget _buildStep2Breath() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '2. Thở chậm lại',
                  style: AppTypography.kicker.copyWith(color: AppColors.mint),
                ),
                const SizedBox(height: 6),
                Text(
                  'Thả lỏng hai vai & đón không khí',
                  style: AppTypography.displayMedium.copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Một nhịp thở không thể giải quyết ngay mọi vấn đề, nhưng sẽ giúp tim bạn đập chậm lại.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Breathing Animated Orb
          AnimatedBuilder(
            animation: _breathScale,
            builder: (context, child) {
              return Transform.scale(
                scale: _breathScale.value,
                child: Container(
                  width: 170,
                  height: 170,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.mint.withValues(alpha: 0.4),
                        AppColors.blue.withValues(alpha: 0.15),
                        Colors.transparent,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.mint.withValues(alpha: 0.25),
                        blurRadius: 36,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      child: const Center(
                        child: Text('🌱', style: TextStyle(fontSize: 40)),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 32),
          Text(
            _breathPhaseText,
            style: AppTypography.titleLarge.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Chu kỳ thở còn: $_breathCyclesLeft',
            style: AppTypography.caption.copyWith(
              color: AppColors.textTertiary,
            ),
          ),

          const Spacer(),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    MindraMotion.of(widget.state.lowStimulationMode).light();
                    setState(() => _currentStep = 2);
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.line),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'Bỏ qua thở',
                    style: TextStyle(color: AppColors.textTertiary),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () {
                    MindraMotion.of(widget.state.lowStimulationMode).light();
                    setState(() => _currentStep = 2);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.ink,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Đã thấy dịu hơn →'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // BƯỚC 3: GỌI TÊN CẢM XÚC GẦN NHẤT
  Widget _buildStep3Emotion() {
    final quickEmotions = [
      ('stressed', 'Căng thẳng'),
      ('anxious', 'Lo lắng'),
      ('tired', 'Mệt mỏi'),
      ('angry', 'Bực bội'),
      ('sad', 'Buồn bã'),
      ('calm', 'Bình yên'),
    ];

    return SingleChildScrollView(
      physics: MindraMotion.of(widget.state.lowStimulationMode).scrollPhysics,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '3. Gọi tên cảm xúc',
            style: AppTypography.kicker.copyWith(color: AppColors.blue),
          ),
          const SizedBox(height: 6),
          Text(
            'Điều gì đang diễn ra trong tâm trí bạn?',
            style: AppTypography.displayMedium.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Chỉ cần chọn cảm xúc gần nhất. Nếu cảm thấy quá hỗn độn, bạn hoàn toàn có thể chọn "Tôi không chắc".',
            style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 24),

          // Lưới cảm xúc nhanh
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: quickEmotions.map((item) {
              final key = item.$1;
              final name = item.$2;
              final emo = MindraEmotions.get(key);
              final isSelected = !_isNotSure && _selectedEmotionKey == key;

              return InkWell(
                onTap: () {
                  MindraMotion.of(widget.state.lowStimulationMode).selection();
                  setState(() {
                    _isNotSure = false;
                    _selectedEmotionKey = key;
                  });
                },
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: MindraMotion.of(widget.state.lowStimulationMode)
                      .duration,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.ink : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? AppColors.ink : AppColors.line,
                      width: isSelected ? 1.8 : 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MoodFace(faceType: emo.face, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        name,
                        style: AppTypography.bodySmall.copyWith(
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isSelected ? Colors.white : AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 16),

          // Lựa chọn "Tôi không chắc" theo chuẩn đặc tả S06-P
          InkWell(
            onTap: () {
              MindraMotion.of(widget.state.lowStimulationMode).selection();
              setState(() {
                _isNotSure = true;
              });
            },
            borderRadius: BorderRadius.circular(20),
            child: AnimatedContainer(
              duration: MindraMotion.of(widget.state.lowStimulationMode)
                  .duration,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isNotSure
                    ? AppColors.yellow.withValues(alpha: 0.2)
                    : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _isNotSure ? AppColors.orange : AppColors.line,
                  width: _isNotSure ? 2.0 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  const Text('❓', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tôi không chắc / Rất mơ hồ',
                          style: AppTypography.bodyMedium.copyWith(
                            fontWeight: _isNotSure
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                        Text(
                          'Không sao cả, bạn không nhất thiết phải dán nhãn mọi thứ ngay.',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isNotSure)
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.orange,
                      size: 20,
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                MindraMotion.of(widget.state.lowStimulationMode).light();
                setState(() => _currentStep = 3);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.ink,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: const Text('Chọn hành động tiếp theo (Bước 4/4)'),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // BƯỚC 4: CHỌN HÀNH ĐỘNG NHỎ TIẾP THEO
  Widget _buildStep4Action() {
    return SingleChildScrollView(
      physics: MindraMotion.of(widget.state.lowStimulationMode).scrollPhysics,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '4. Bước đi nhỏ',
            style: AppTypography.kicker.copyWith(color: AppColors.orange),
          ),
          const SizedBox(height: 6),
          Text(
            'Bây giờ, bạn muốn làm gì tiếp theo?',
            style: AppTypography.displayMedium.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Chọn một hành động vừa sức nhất để xoa dịu bản thân lúc này:',
            style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 18),

          ..._actions.map((item) {
            final isSelected = _selectedAction == item.title;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () {
                  MindraMotion.of(widget.state.lowStimulationMode).selection();
                  setState(() => _selectedAction = item.title);
                },
                borderRadius: BorderRadius.circular(18),
                child: AnimatedContainer(
                  duration: MindraMotion.of(widget.state.lowStimulationMode)
                      .duration,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.creamDark : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected ? AppColors.ink : AppColors.line,
                      width: isSelected ? 1.8 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(item.icon, style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: AppTypography.bodyMedium.copyWith(
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.subtitle,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.ink,
                          size: 20,
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _savePauseModeEntry,
              icon: const Icon(Icons.check_rounded, size: 20),
              label: const Text('Hoàn thành & Lưu nhịp dừng'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.ink,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
