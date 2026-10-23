import 'package:flutter/material.dart';

import '../core/theme/colors.dart';
import '../core/theme/motion.dart';
import '../core/theme/shadows.dart';
import '../core/theme/typography.dart';
import '../state/mindra_state.dart';
import 'paper_release_sheet.dart';
import 'practice_session.dart';

class PracticeView extends StatefulWidget {
  final MindraState state;
  final VoidCallback onOpenPause;

  const PracticeView({
    super.key,
    required this.state,
    required this.onOpenPause,
  });

  @override
  State<PracticeView> createState() => _PracticeViewState();
}

class _PracticeViewState extends State<PracticeView> {
  String _selectedCategory = 'all';

  void _openSession(PracticeSessionConfig config) {
    MindraMotion.of(widget.state.lowStimulationMode).light();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PracticeSessionSheet(state: widget.state, config: config),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: MindraMotion.of(widget.state.lowStimulationMode).scrollPhysics,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: AppTypography.displayMedium.copyWith(fontSize: 32),
              children: [
                const TextSpan(text: 'Khoảng nghỉ cho\n'),
                TextSpan(
                  text: 'tâm trí bạn.',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: AppColors.orange,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Một bài tập ngắn. Có thể dừng giữa chừng. Không cần làm hoàn hảo.',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          _buildSosCard(),
          const SizedBox(height: 16),
          _buildPaperReleaseCard(),
          const SizedBox(height: 24),
          _buildCategoryFilter(),
          const SizedBox(height: 20),
          _buildExerciseList(),
          const SizedBox(height: 36),
        ],
      ),
    );
  }

  Widget _buildPaperReleaseCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF7F0),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.orange.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.description_outlined,
              color: AppColors.orange,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.orange.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'MỘT KHOẢNG DỪNG',
                        style: AppTypography.kicker.copyWith(
                          color: AppColors.orange,
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Vò giấy',
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Viết điều trong lòng lên giấy, vò lại rồi ném đi khi bạn muốn.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                  ),
                  onPressed: () {
                    PaperReleaseSheet.show(
                      context: context,
                      state: widget.state,
                    );
                  },
                  icon: const Icon(Icons.edit_note_rounded, size: 16),
                  label: const Text(
                    'Bắt đầu viết',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSosCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.orange.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'KHOẢNG DỪNG · 30 GIÂY',
              style: AppTypography.kicker.copyWith(
                color: AppColors.orange,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Đang thấy quá tải?',
            style: AppTypography.headlineMedium.copyWith(
              color: Colors.white,
              fontSize: 19,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Thả lỏng quai hàm, hạ vai, rồi thở chậm vài nhịp. Không cần viết gì.',
            style: AppTypography.bodySmall.copyWith(
              color: Colors.white.withValues(alpha: 0.75),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.yellow,
                foregroundColor: AppColors.ink,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: widget.onOpenPause,
              icon: const Icon(Icons.play_arrow_rounded, size: 20),
              label: Text(
                'Bắt đầu dừng lại',
                style: AppTypography.button.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    final categories = [
      ('all', 'Tất cả'),
      ('breath', 'Luyện thở'),
      ('sos', 'Hạ nhiệt'),
      ('cbt', 'Suy nghĩ'),
      ('body', 'Cơ thể'),
    ];

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: MindraMotion.of(widget.state.lowStimulationMode).scrollPhysics,
        children: categories.map((cat) {
          final isSelected = _selectedCategory == cat.$1;
          return Semantics(
            button: true,
            selected: isSelected,
            label: 'Danh mục ${cat.$2}${isSelected ? ', đang được chọn' : ''}',
            child: GestureDetector(
              onTap: () {
                MindraMotion.of(widget.state.lowStimulationMode).selection();
                setState(() => _selectedCategory = cat.$1);
              },
              behavior: HitTestBehavior.opaque,
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.ink : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? AppColors.ink : AppColors.line,
                  ),
                ),
                child: Text(
                  cat.$2,
                  style: AppTypography.caption.copyWith(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.white : AppColors.ink,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildExerciseList() {
    final exercises = _buildCatalog();
    final filtered = _selectedCategory == 'all'
        ? exercises
        : exercises.where((e) => e.category == _selectedCategory).toList();

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filtered.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final item = filtered[index];
        return Semantics(
          button: true,
          label: '${item.config.title}. ${item.config.durationLabel}.',
          child: GestureDetector(
            onTap: () => _openSession(item.config),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.cream,
                borderRadius: BorderRadius.circular(22),
                boxShadow: AppShadows.card,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: item.iconBg,
                    ),
                    child: Icon(item.icon, size: 24, color: item.iconColor),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.config.title,
                          style: AppTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.config.purpose,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          item.config.durationLabel,
                          style: AppTypography.caption.copyWith(
                            fontSize: 11,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: AppColors.textTertiary,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CatalogItem {
  final String category;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final PracticeSessionConfig config;

  const _CatalogItem({
    required this.category,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.config,
  });
}

List<_CatalogItem> _buildCatalog() => [
  _CatalogItem(
    category: 'breath',
    icon: Icons.air_rounded,
    iconBg: AppColors.mint.withValues(alpha: 0.2),
    iconColor: AppColors.mint,
    config: const PracticeSessionConfig(
      id: 'breath-478',
      title: 'Thở 4-7-8',
      purpose:
          'Một nhịp thở chậm để cơ thể hạ nhiệt trước khi ngủ hoặc khi lo âu.',
      durationLabel: '3 phút · 4 chu kỳ',
      accent: AppColors.mint,
      kind: PracticeKind.breath,
      breath: BreathPattern(
        inhaleSec: 4,
        holdSec: 7,
        exhaleSec: 8,
        totalCycles: 4,
      ),
    ),
  ),
  _CatalogItem(
    category: 'breath',
    icon: Icons.crop_square_rounded,
    iconBg: AppColors.blue.withValues(alpha: 0.18),
    iconColor: AppColors.blue,
    config: const PracticeSessionConfig(
      id: 'breath-box',
      title: 'Thở hộp',
      purpose:
          'Bốn nhịp đều nhau để lấy lại tập trung khi tâm trí đang lan man.',
      durationLabel: '2 phút · 4 chu kỳ',
      accent: AppColors.blue,
      kind: PracticeKind.breath,
      breath: BreathPattern(
        inhaleSec: 4,
        holdSec: 4,
        exhaleSec: 4,
        holdAfterExhaleSec: 4,
        totalCycles: 4,
      ),
    ),
  ),
  _CatalogItem(
    category: 'breath',
    icon: Icons.waves_rounded,
    iconBg: AppColors.lavender.withValues(alpha: 0.3),
    iconColor: AppColors.purple,
    config: const PracticeSessionConfig(
      id: 'breath-belly',
      title: 'Thở bụng êm dịu',
      purpose: 'Kéo dài hơi thở ra, không cần thở sâu hơn mức dễ chịu.',
      durationLabel: '2 phút · 5 chu kỳ',
      accent: AppColors.purple,
      kind: PracticeKind.breath,
      breath: BreathPattern(
        inhaleSec: 4,
        holdSec: 1,
        exhaleSec: 6,
        totalCycles: 5,
      ),
    ),
  ),
  _CatalogItem(
    category: 'sos',
    icon: Icons.fingerprint_rounded,
    iconBg: AppColors.orange.withValues(alpha: 0.18),
    iconColor: AppColors.orange,
    config: const PracticeSessionConfig(
      id: 'grounding',
      title: 'Neo về hiện tại',
      purpose: 'Dùng năm giác quan để trở lại khoảnh khắc này, từng bước một.',
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
    ),
  ),
  _CatalogItem(
    category: 'cbt',
    icon: Icons.psychology_rounded,
    iconBg: AppColors.yellow.withValues(alpha: 0.28),
    iconColor: AppColors.ink,
    config: const PracticeSessionConfig(
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
          title: 'Bạn sẽ nói gì với một người bạn?',
          body: 'Dùng giọng bạn sẽ dành cho người mình quý.',
          placeholder: 'Mình sẽ nói…',
        ),
        PracticePrompt(
          title: 'Một cách nhìn cân bằng hơn?',
          body: 'Không cần lạc quan. Chỉ cần công bằng hơn một chút.',
          placeholder: 'Có thể mình…',
        ),
      ],
    ),
  ),
  _CatalogItem(
    category: 'cbt',
    icon: Icons.favorite_rounded,
    iconBg: AppColors.pink.withValues(alpha: 0.18),
    iconColor: AppColors.pink,
    config: const PracticeSessionConfig(
      id: 'compassion',
      title: 'Lời dịu dàng',
      purpose: 'Viết điều bạn sẽ nói với một người bạn, rồi dành lại cho mình.',
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
    ),
  ),
  _CatalogItem(
    category: 'body',
    icon: Icons.accessibility_new_rounded,
    iconBg: AppColors.gray.withValues(alpha: 0.35),
    iconColor: AppColors.ink,
    config: const PracticeSessionConfig(
      id: 'body-scan',
      title: 'Quét và thả lỏng',
      purpose: 'Đi từng vùng cơ thể. Chỉ nhận biết, không cần sửa.',
      durationLabel: '3 phút · 5 bước',
      accent: AppColors.gray,
      kind: PracticeKind.steps,
      prompts: [
        PracticePrompt(
          title: 'Cơ mặt và quai hàm',
          body: 'Thả lỏng trán, tách nhẹ hai hàm răng, đưa lưỡi về vòm miệng.',
        ),
        PracticePrompt(
          title: 'Cổ và bờ vai',
          body: 'Nâng nhẹ hai vai rồi hạ rơi tự do. Cảm nhận khoảng trống vừa xuất hiện.',
        ),
        PracticePrompt(
          title: 'Lồng ngực và bụng',
          body: 'Để bụng phình tự nhiên khi thở. Không cần gồng nén.',
        ),
        PracticePrompt(
          title: 'Hai bàn tay',
          body: 'Xòe nhẹ các ngón. Cảm nhận hơi ấm nơi lòng bàn tay.',
        ),
        PracticePrompt(
          title: 'Bàn chân',
          body: 'Cảm nhận mặt đất đang nâng đỡ toàn bộ sức nặng cơ thể.',
        ),
      ],
    ),
  ),
];
