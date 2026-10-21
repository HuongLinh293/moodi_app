import '../widgets/entry_sync_notice.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/colors.dart';
import '../core/theme/shadows.dart';
import '../core/theme/typography.dart';
import '../models/ai_reflection.dart';
import '../models/ai_reframing_lens.dart';
import '../models/journal_entry.dart';
import '../state/mindra_state.dart';
import 'practice_session.dart';

class AIReflectionView extends StatefulWidget {
  final JournalEntry entry;
  final MindraState state;
  final VoidCallback onOpenJournal;

  const AIReflectionView({
    super.key,
    required this.entry,
    required this.state,
    required this.onOpenJournal,
  });

  @override
  State<AIReflectionView> createState() => _AIReflectionViewState();
}

class _AIReflectionViewState extends State<AIReflectionView>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  bool _hasError = false;
  late AIReflection _reflection;
  String? _userFeedback;
  bool _microGoalSaved = false;
  late List<String> _possibleEmotions;
  late String _possibleTrigger;
  late String _intensifyingThought;
  late String _balancedThought;
  late String _reflectionQuestion;
  late String _recommendedExercise;
  late String _recommendationReason;
  late String _microGoalPrompt;
  bool _recommendationsDismissed = false;
  ReframingLensType? _selectedLens;

  AIReflection get _currentReflection => _reflection.copyWith(
    possibleEmotions: _possibleEmotions,
    possibleTrigger: _possibleTrigger,
    intensifyingThought: _intensifyingThought,
    balancedThought: _balancedThought,
    reflectionQuestion: _reflectionQuestion,
    recommendedExercise: _recommendedExercise,
    recommendationReason: _recommendationReason,
    microGoalPrompt: _microGoalPrompt,
    userFeedback: _userFeedback,
    recommendationsDismissed: _recommendationsDismissed,
  );

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _reflection =
        widget.state.reflectionForEntry(widget.entry.id) ??
        AIReflection.forEmotion(
          emotionKey: widget.entry.emotionKey,
          intensity: widget.entry.intensity,
          situation: widget.entry.situation,
          thought: widget.entry.thought,
        );
    if (widget.state.reflectionForEntry(widget.entry.id) == null) {
      unawaited(_loadServerReflection());
    } else {
      widget.state.cacheAIReflection(widget.entry.id, _reflection);
    }
    _possibleEmotions = List.of(_reflection.possibleEmotions);
    _possibleTrigger = _reflection.possibleTrigger;
    _intensifyingThought = _reflection.intensifyingThought;
    _balancedThought = _reflection.balancedThought;
    _reflectionQuestion = _reflection.reflectionQuestion;
    _recommendedExercise = _reflection.recommendedExercise;
    _recommendationReason = _reflection.recommendationReason;
    _microGoalPrompt = _reflection.microGoalPrompt;
    _userFeedback = _reflection.userFeedback;
    _recommendationsDismissed = _reflection.recommendationsDismissed;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _startLoading();
  }

  Future<void> _loadServerReflection() async {
    try {
      final generated = await widget.state.fetchOrGenerateAIReflection(
        widget.entry,
      );
      if (!mounted) return;
      _applyReflection(generated);
    } catch (_) {
      if (mounted) widget.state.cacheAIReflection(widget.entry.id, _reflection);
    }
  }

  void _applyReflection(AIReflection reflection) {
    setState(() {
      _reflection = reflection;
      _possibleEmotions = List.of(reflection.possibleEmotions);
      _possibleTrigger = reflection.possibleTrigger;
      _intensifyingThought = reflection.intensifyingThought;
      _balancedThought = reflection.balancedThought;
      _reflectionQuestion = reflection.reflectionQuestion;
      _recommendedExercise = reflection.recommendedExercise;
      _recommendationReason = reflection.recommendationReason;
      _microGoalPrompt = reflection.microGoalPrompt;
      _userFeedback = reflection.userFeedback;
      _recommendationsDismissed = reflection.recommendationsDismissed;
    });
  }

  void _startLoading() {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    final delay = widget.state.lowStimulationMode
        ? const Duration(milliseconds: 200)
        : const Duration(milliseconds: 200);
    Timer(delay, () {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = false;
      });
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _launchExercise(String exerciseId) {
    HapticFeedback.mediumImpact();
    final config = _getExerciseConfig(exerciseId);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PracticeSessionSheet(state: widget.state, config: config),
    );
  }

  void _selectReframingLens(ReframingLensType type) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedLens == type) {
        _selectedLens = null;
        _balancedThought = _reflection.balancedThought;
      } else {
        _selectedLens = type;
        _balancedThought = ReframingLens.getThoughtFor(
          type: type,
          emotionKey: widget.entry.emotionKey,
          defaultThought: _reflection.balancedThought,
        );
      }
    });
  }

  Future<void> _openReflectionEditor() async {
    final edits = await showModalBottomSheet<_ReflectionEdits>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReflectionEditSheet(reflection: _reflection),
    );
    if (edits == null || !mounted) return;

    final updatedReflection = _reflection.copyWith(
      possibleEmotions: edits.possibleEmotions,
      possibleTrigger: edits.possibleTrigger,
      intensifyingThought: edits.intensifyingThought,
      balancedThought: edits.balancedThought,
      reflectionQuestion: edits.reflectionQuestion,
      recommendedExercise: edits.recommendedExercise,
      recommendationReason: edits.recommendationReason,
      microGoalPrompt: edits.microGoalPrompt,
      userFeedback: 'needs_edit',
      recommendationsDismissed: false,
    );
    widget.state.updateAIReflection(widget.entry.id, updatedReflection);

    setState(() {
      _possibleEmotions = edits.possibleEmotions;
      _possibleTrigger = edits.possibleTrigger;
      _intensifyingThought = edits.intensifyingThought;
      _balancedThought = edits.balancedThought;
      _reflectionQuestion = edits.reflectionQuestion;
      _recommendedExercise = edits.recommendedExercise;
      _recommendationReason = edits.recommendationReason;
      _microGoalPrompt = edits.microGoalPrompt;
      _recommendationsDismissed = false;
      _userFeedback = 'needs_edit';
    });
  }

  PracticeSessionConfig _getExerciseConfig(String id) {
    switch (id) {
      case 'grounding':
        return const PracticeSessionConfig(
          id: 'grounding',
          title: 'Neo về hiện tại (5-4-3-2-1)',
          purpose:
              'Dùng năm giác quan để trở lại khoảnh khắc này, từng bước một.',
          durationLabel: '2 phút · 5 bước',
          accent: AppColors.orange,
          kind: PracticeKind.steps,
          prompts: [
            PracticePrompt(
              title: 'Nhìn 5 thứ',
              body: 'Tìm năm đồ vật quanh bạn. Không cần đặt tên hay đánh giá.',
            ),
            PracticePrompt(
              title: 'Chạm 4 bề mặt',
              body: 'Cảm nhận bốn bề mặt: ấm, lạnh, nhám, mịn.',
            ),
            PracticePrompt(
              title: 'Nghe 3 âm thanh',
              body: 'Để tai mở. Ba âm thanh gần hoặc xa đều được.',
            ),
            PracticePrompt(
              title: 'Ngửi 2 mùi',
              body: 'Hai mùi thoảng qua không gian, dù rất nhẹ.',
            ),
            PracticePrompt(
              title: 'Nếm 1 vị',
              body: 'Cảm nhận vị đang đọng lại nơi miệng, rồi thở ra một nhịp.',
            ),
          ],
        );
      case 'thought_reframing':
      case 'reframe':
        return const PracticeSessionConfig(
          id: 'reframe',
          title: 'Nhìn lại suy nghĩ',
          purpose: 'Tách sự thật khỏi phỏng đoán. Mọi ô đều có thể bỏ qua.',
          durationLabel: '3 phút · 5 bước',
          accent: AppColors.yellow,
          kind: PracticeKind.write,
          prompts: [
            PracticePrompt(
              title: 'Suy nghĩ đó là gì?',
              body: 'Viết điều vừa lướt qua tâm trí, dù còn vụn.',
              placeholder: 'Mình đang nghĩ rằng…',
            ),
            PracticePrompt(
              title: 'Điều gì ủng hộ nó?',
              body: 'Chỉ những gì đã thật sự xảy ra, không phải dự đoán.',
              placeholder: 'Điều đã xảy ra là…',
            ),
            PracticePrompt(
              title: 'Điều gì chưa ủng hộ nó?',
              body: 'Có chi tiết nào cho thấy bức tranh khác không?',
              placeholder: 'Cũng có thể là…',
            ),
            PracticePrompt(
              title: 'Một cách nhìn cân bằng hơn?',
              body: 'Không cần lạc quan. Chỉ cần công bằng hơn một chút.',
              placeholder: 'Có thể mình…',
            ),
          ],
        );
      case 'self_compassion':
      case 'compassion':
        return const PracticeSessionConfig(
          id: 'compassion',
          title: 'Lời dịu dàng',
          purpose:
              'Viết điều bạn sẽ nói với một người bạn, rồi dành lại cho mình.',
          durationLabel: '2 phút · 2 bước',
          accent: AppColors.pink,
          kind: PracticeKind.write,
          prompts: [
            PracticePrompt(
              title: 'Bạn sẽ nói gì với một người bạn?',
              body: 'Nếu người ấy đang cảm thấy giống bạn lúc này.',
              placeholder: 'Mình sẽ nói…',
            ),
            PracticePrompt(
              title: 'Nói lại điều đó với chính mình',
              body: 'Không cần tin hoàn toàn. Chỉ cần viết, nếu muốn.',
              placeholder: 'Mình cũng xứng đáng…',
            ),
          ],
        );
      default:
        return const PracticeSessionConfig(
          id: 'pause',
          title: 'Khoảng dừng 60 giây',
          purpose: 'Dừng lại, thở chậm, rồi chọn một bước nhỏ tiếp theo khi đã dịu hơn.',
          durationLabel: '1 phút',
          accent: AppColors.orange,
          kind: PracticeKind.breath,
          breath: BreathPattern(
            inhaleSec: 4,
            holdSec: 2,
            exhaleSec: 6,
            totalCycles: 5,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.state.aiConsent) {
      return _buildDisabledState();
    }

    if (_isLoading) {
      return _buildS09Loading();
    }

    if (_hasError) {
      return _buildErrorState();
    }

    if (_reflection.safetyFlag) {
      return _buildS21SafetyCrisis();
    }

    return _buildS10ReflectionResult();
  }

  // S09 Loading Screen
  Widget _buildS09Loading() {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          AppColors.purple.withValues(alpha: 0.3),
                          AppColors.yellow.withValues(alpha: 0.15),
                          Colors.transparent,
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppColors.cream,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.line),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.ink.withValues(alpha: 0.06),
                              blurRadius: 14,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text('✨', style: TextStyle(fontSize: 28)),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Moodi đang suy ngẫm...',
                  style: AppTypography.headlineMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Lắng nghe và tách rời sự thật khỏi cảm xúc dồn nén.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDisabledState() {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.ink),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.visibility_off_outlined,
                size: 36,
                color: AppColors.ink,
              ),
              const SizedBox(height: 18),
              Text(
                'Gợi ý phản tư đang tắt',
                style: AppTypography.headlineMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Bạn có thể kiểm tra ghi chép trong Nhật ký và bật gợi ý phản tư trong Cài đặt.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Quay lại'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.ink),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.refresh_rounded, size: 36, color: AppColors.ink),
              const SizedBox(height: 18),
              Text(
                'Chưa tạo được góc nhìn lần này',
                style: AppTypography.headlineMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Check-in vẫn được lưu. Bạn có thể thử lại hoặc quay lại nhật ký.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _startLoading,
                child: const Text('Thử lại'),
              ),
              TextButton(
                onPressed: widget.onOpenJournal,
                child: const Text('Xem nhật ký'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // S21 Safety & Crisis Support Screen
  Widget _buildS21SafetyCrisis() {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7F5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.ink),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Hỗ trợ an toàn',
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.orange.withValues(alpha: 0.3),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.orange.withValues(alpha: 0.08),
                    blurRadius: 12,
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
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.orange.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.favorite,
                          color: AppColors.orange,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'Bạn không phải một mình',
                          style: AppTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Chúng tôi nhận thấy bạn đang trải qua những cảm xúc rất nặng nề hoặc đau đớn. '
                    'Moodi là công cụ tự phản tư thường ngày và không thể thay thế sự trợ giúp chuyên môn khi bạn cần an toàn tức thời.',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'ĐƯỜNG DÂY NÓNG HỖ TRỢ KHẨN CẤP (MIỄN PHÍ)',
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 12),
            _buildHotlineCard(
              name: 'Đường dây nóng Ngày Mai (Hỗ trợ khủng hoảng tâm lý)',
              phone: '096 306 1414',
              time: '13:00 - 20:30 hằng ngày',
            ),
            const SizedBox(height: 10),
            _buildHotlineCard(
              name: 'Tổng đài Quốc gia Bảo vệ Trẻ em & Thanh thiếu niên',
              phone: '111',
              time: '24/7 Miễn phí',
            ),
            const SizedBox(height: 10),
            _buildHotlineCard(
              name: 'Viện Sức khỏe Tâm thần (Bệnh viện Bạch Mai)',
              phone: '024 3869 3731',
              time: 'Cấp cứu & Hỗ trợ y tế khẩn cấp',
            ),
            const SizedBox(height: 28),
            // Calming exercise CTA
            ElevatedButton.icon(
              onPressed: () => _launchExercise('grounding'),
              icon: const Icon(Icons.spa_outlined),
              label: Text(
                'Thực hành tiếp đất để bình tĩnh lại',
                style: AppTypography.button,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.ink,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onOpenJournal();
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: AppColors.line),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Text(
                'Quay về trang chính',
                style: AppTypography.button.copyWith(color: AppColors.ink),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildHotlineCard({
    required String name,
    required String phone,
    required String time,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  time,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  phone,
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.orange,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: phone));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Đã sao chép số điện thoại: $phone'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.phone),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.orange.withValues(alpha: 0.15),
              foregroundColor: AppColors.orange,
            ),
          ),
        ],
      ),
    );
  }

  // S10: AI Reflection Result View
  Widget _buildS10ReflectionResult() {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.ink),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('✨', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 6),
            Text(
              'Gợi ý phản tư',
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  'Gợi ý từ mẫu có sẵn, không phải phân tích AI cá nhân. Chỉ giữ điều phù hợp với bạn.',
                  style: TextStyle(color: AppColors.textSecondary, height: 1.5),
                ),
              ),
              // Emotion tags
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _possibleEmotions.map((emo) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.cream,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.yellow,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          emo,
                          style: AppTypography.caption.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),

              // Card 1: Trigger & Intensifying thought — only what the user gave us.
              if (_possibleTrigger.isNotEmpty ||
                  _intensifyingThought.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.cream,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: AppShadows.card,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_possibleTrigger.isNotEmpty) ...[
                        Row(
                          children: [
                            const Text('🔍', style: TextStyle(fontSize: 16)),
                            const SizedBox(width: 8),
                            Text(
                              'Tác nhân nhận thấy',
                              style: AppTypography.caption.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _possibleTrigger,
                          style: AppTypography.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                      ],
                      if (_possibleTrigger.isNotEmpty &&
                          _intensifyingThought.isNotEmpty)
                        const Divider(height: 24),
                      if (_intensifyingThought.isNotEmpty) ...[
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            const Text('💭', style: TextStyle(fontSize: 16)),
                            Text(
                              'Suy nghĩ có thể đang phóng đại',
                              style: AppTypography.caption.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.orange,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '“$_intensifyingThought”',
                          style: AppTypography.bodyMedium.copyWith(
                            fontStyle: FontStyle.italic,
                            color: AppColors.ink,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Card 2: Balanced perspective
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.mint.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: AppShadows.card,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('🌿', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Text(
                          'Góc nhìn cân bằng hơn',
                          style: AppTypography.caption.copyWith(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1E634F),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _balancedThought,
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Divider(
                      height: 1,
                      color: const Color(0xFF1E634F).withValues(alpha: 0.15),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'ĐỔI LĂNG KÍNH SUY NGHĨ:',
                      style: AppTypography.kicker.copyWith(
                        fontSize: 10,
                        color: const Color(0xFF1E634F),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: ReframingLens.all.map((lens) {
                        final isSelected = _selectedLens == lens.type;
                        return InkWell(
                          onTap: () => _selectReframingLens(lens.type),
                          borderRadius: BorderRadius.circular(10),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF1E634F)
                                  : Colors.white.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF1E634F)
                                    : const Color(0xFF1E634F)
                                          .withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  lens.emoji,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  lens.label,
                                  style: AppTypography.caption.copyWith(
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                    color: isSelected
                                        ? Colors.white
                                        : const Color(0xFF1E634F),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _selectedLens == null
                          ? 'Chạm một lăng kính để đọc lại suy nghĩ cân bằng qua góc nhìn đó.'
                          : ReframingLens.all
                                .firstWhere((l) => l.type == _selectedLens)
                                .description,
                      style: AppTypography.caption.copyWith(
                        color: const Color(0xFF1E634F),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Card 3: Reflection question
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.blue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: AppShadows.card,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        const Text('💡', style: TextStyle(fontSize: 16)),
                        Text(
                          'Câu hỏi suy ngẫm cho bạn',
                          style: AppTypography.caption.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _reflectionQuestion,
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w500,
                        color: AppColors.ink,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Feedback buttons (S10)
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 8,
                children: [
                  Text(
                    'Phản tư này:',
                    style: AppTypography.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  _buildFeedbackChip(label: 'Rất đúng 👍', key: 'accurate'),
                  _buildFeedbackChip(label: 'Cần sửa ✏️', key: 'needs_edit'),
                  _buildFeedbackChip(label: 'Chưa hợp ✕', key: 'inaccurate'),
                ],
              ),
              const SizedBox(height: 24),
              if (_userFeedback == 'inaccurate') ...[
                Text(
                  'Không sao. Bạn có thể bỏ qua các gợi ý này.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() => _recommendationsDismissed = true);
                      widget.state.updateAIReflection(
                        widget.entry.id,
                        _currentReflection,
                      );
                    },
                    style: TextButton.styleFrom(
                      minimumSize: const Size(44, 44),
                    ),
                    icon: const Icon(Icons.visibility_off_outlined, size: 18),
                    label: const Text('Bỏ qua gợi ý'),
                  ),
                ),
              ],

              // S11: Next Step / Recommended Exercise
              if (!_recommendationsDismissed)
                Container(
                  padding: const EdgeInsets.all(20),
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
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.yellow.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              '🧘',
                              style: TextStyle(fontSize: 20),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Bước tiếp theo đề xuất',
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.orange,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  _getExerciseTitle(_recommendedExercise),
                                  style: AppTypography.titleMedium.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _recommendationReason,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () =>
                              _launchExercise(_recommendedExercise),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.ink,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'Bắt đầu bài tập này',
                            style: AppTypography.button,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (!_recommendationsDismissed) const SizedBox(height: 14),

              // S11-G: Micro-Goal
              if (!_recommendationsDismissed && _microGoalPrompt.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.cream,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: AppShadows.card,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          const Text('🎯', style: TextStyle(fontSize: 18)),
                          Text(
                            'Một bước nhỏ',
                            style: AppTypography.caption.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _microGoalPrompt,
                        style: AppTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_microGoalSaved)
                        Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: AppColors.mint,
                              size: 20,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Đã thêm vào các bước nhỏ của bạn',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.mint,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        )
                      else
                        OutlinedButton.icon(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            widget.state.addMicroGoal(_microGoalPrompt);
                            setState(() => _microGoalSaved = true);
                          },
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Giữ bước nhỏ này'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.ink,
                            side: const BorderSide(color: AppColors.line),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),

              // Sync status sits at the end so it doesn't open the reflection
              // with a warning right after every save.
              EntrySyncNotice(state: widget.state),

              // Done button
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onOpenJournal();
                  },
                  child: Text(
                    'Xem trong Lịch & Nhật ký →',
                    style: AppTypography.button.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeedbackChip({required String label, required String key}) {
    final isSelected = _userFeedback == key;
    return InkWell(
      onTap: () async {
        HapticFeedback.selectionClick();
        if (key == 'needs_edit') {
          await _openReflectionEditor();
        } else {
          setState(() => _userFeedback = key);
          widget.state.updateAIReflection(widget.entry.id, _currentReflection);
        }
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.ink : AppColors.cream,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.ink : AppColors.line,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.ink,
          ),
        ),
      ),
    );
  }

  String _getExerciseTitle(String id) {
    switch (id) {
      case 'grounding':
        return 'Kỹ thuật tiếp đất 5-4-3-2-1';
      case 'thought_reframing':
        return 'Tái đóng khung suy nghĩ';
      case 'self_compassion':
        return 'Khoảnh khắc tự trắc ẩn';
      case 'response_pause':
        return 'Tạm dừng phản ứng';
      default:
        return 'Bài tập hít thở chánh niệm';
    }
  }
}

class _ReflectionEdits {
  final List<String> possibleEmotions;
  final String possibleTrigger;
  final String intensifyingThought;
  final String balancedThought;
  final String reflectionQuestion;
  final String recommendedExercise;
  final String recommendationReason;
  final String microGoalPrompt;

  const _ReflectionEdits({
    required this.possibleEmotions,
    required this.possibleTrigger,
    required this.intensifyingThought,
    required this.balancedThought,
    required this.reflectionQuestion,
    required this.recommendedExercise,
    required this.recommendationReason,
    required this.microGoalPrompt,
  });
}

class _ReflectionEditSheet extends StatefulWidget {
  final AIReflection reflection;

  const _ReflectionEditSheet({required this.reflection});

  @override
  State<_ReflectionEditSheet> createState() => _ReflectionEditSheetState();
}

class _ReflectionEditSheetState extends State<_ReflectionEditSheet> {
  late final TextEditingController _emotionsController;
  late final TextEditingController _triggerController;
  late final TextEditingController _thoughtController;
  late final TextEditingController _balancedController;
  late final TextEditingController _questionController;
  late final TextEditingController _reasonController;
  late final TextEditingController _microGoalController;
  late String _recommendedExercise;

  static const _exerciseLabels = {
    'grounding': 'Tiếp đất 5-4-3-2-1',
    'thought_reframing': 'Nhìn lại suy nghĩ',
    'self_compassion': 'Lời dịu dàng',
    'response_pause': 'Tạm dừng phản ứng',
  };

  @override
  void initState() {
    super.initState();
    final reflection = widget.reflection;
    _emotionsController = TextEditingController(
      text: reflection.possibleEmotions.join(', '),
    );
    _triggerController = TextEditingController(
      text: reflection.possibleTrigger,
    );
    _thoughtController = TextEditingController(
      text: reflection.intensifyingThought,
    );
    _balancedController = TextEditingController(
      text: reflection.balancedThought,
    );
    _questionController = TextEditingController(
      text: reflection.reflectionQuestion,
    );
    _reasonController = TextEditingController(
      text: reflection.recommendationReason,
    );
    _microGoalController = TextEditingController(
      text: reflection.microGoalPrompt,
    );
    _recommendedExercise =
        _exerciseLabels.containsKey(reflection.recommendedExercise)
        ? reflection.recommendedExercise
        : 'grounding';
  }

  @override
  void dispose() {
    _emotionsController.dispose();
    _triggerController.dispose();
    _thoughtController.dispose();
    _balancedController.dispose();
    _questionController.dispose();
    _reasonController.dispose();
    _microGoalController.dispose();
    super.dispose();
  }

  Widget _textField(
    String label,
    TextEditingController controller, {
    int maxLines = 3,
  }) {
    return TextField(
      key: ValueKey<String>(label),
      controller: controller,
      minLines: maxLines == 1 ? 1 : 2,
      maxLines: maxLines,
      textCapitalization: TextCapitalization.sentences,
      keyboardType: maxLines > 1 ? TextInputType.multiline : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        helperText: 'Để trống để bỏ mục này',
        alignLabelWithHint: maxLines > 1,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.line),
        ),
      ),
    );
  }

  void _save() {
    final emotions = _emotionsController.text
        .split(',')
        .map((emotion) => emotion.trim())
        .where((emotion) => emotion.isNotEmpty)
        .toList();

    Navigator.pop(
      context,
      _ReflectionEdits(
        possibleEmotions: emotions,
        possibleTrigger: _triggerController.text.trim(),
        intensifyingThought: _thoughtController.text.trim(),
        balancedThought: _balancedController.text.trim(),
        reflectionQuestion: _questionController.text.trim(),
        recommendedExercise: _recommendedExercise,
        recommendationReason: _reasonController.text.trim(),
        microGoalPrompt: _microGoalController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        height: MediaQuery.sizeOf(context).height * 0.88,
        decoration: const BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Chỉnh sửa phản tư',
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Đóng',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      'Bạn có thể sửa hoặc xóa từng mục cho đúng với trải nghiệm của mình.',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _textField(
                      'Cảm xúc có thể liên quan, cách nhau bằng dấu phẩy',
                      _emotionsController,
                    ),
                    const SizedBox(height: 14),
                    _textField('Tác nhân', _triggerController, maxLines: 2),
                    const SizedBox(height: 14),
                    _textField(
                      'Suy nghĩ có thể đang làm cảm xúc mạnh hơn',
                      _thoughtController,
                    ),
                    const SizedBox(height: 14),
                    _textField('Góc nhìn cân bằng', _balancedController),
                    const SizedBox(height: 14),
                    _textField('Câu hỏi suy ngẫm', _questionController),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: _recommendedExercise,
                      decoration: const InputDecoration(
                        labelText: 'Bài tập đề xuất',
                        border: OutlineInputBorder(),
                      ),
                      items: _exerciseLabels.entries
                          .map(
                            (entry) => DropdownMenuItem<String>(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _recommendedExercise = value);
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    _textField('Lý do đề xuất', _reasonController),
                    const SizedBox(height: 14),
                    _textField('Mục tiêu nhỏ', _microGoalController),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.ink,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Lưu chỉnh sửa'),
                  ),
                ),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}
