import 'package:flutter/material.dart';

import '../core/theme/colors.dart';
import '../core/theme/motion.dart';
import '../core/theme/typography.dart';
import '../state/mindra_state.dart';
import 'practice_view.dart';
import 'progress_view.dart';

class ExploreView extends StatefulWidget {
  final MindraState state;
  final VoidCallback onOpenCheckin;

  const ExploreView({
    super.key,
    required this.state,
    required this.onOpenCheckin,
  });

  @override
  State<ExploreView> createState() => _ExploreViewState();
}

class _ExploreViewState extends State<ExploreView> {
  int _section = 1;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('KHÁM PHÁ', style: AppTypography.kicker),
              const SizedBox(height: 6),
              Text(
                'Nhìn lại và thử\nmột bước nhỏ.',
                style: AppTypography.displayMedium.copyWith(fontSize: 30),
              ),
              const SizedBox(height: 6),
              Text(
                'Chọn một bài thực hành, hoặc mở Tiến trình để nhìn lại các ghi chép.',
                style: AppTypography.bodySmall,
              ),
              const SizedBox(height: 16),
              _buildSectionSwitcher(),
            ],
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _section,
            children: [
              ProgressView(
                state: widget.state,
                onOpenCheckin: widget.onOpenCheckin,
              ),
              PracticeView(state: widget.state),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionSwitcher() {
    final sections = [
      (icon: Icons.auto_graph_outlined, label: 'Tiến trình'),
      (icon: Icons.self_improvement_outlined, label: 'Thực hành'),
    ];

    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.creamDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: sections.asMap().entries.map((entry) {
          final index = entry.key;
          final section = entry.value;
          final isSelected = _section == index;

          return Expanded(
            child: Semantics(
              button: true,
              selected: isSelected,
              label: '${section.label}${isSelected ? ', đang chọn' : ''}',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => setState(() => _section = index),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: MindraMotion.of(widget.state.lowStimulationMode)
                        .duration,
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppColors.ink.withValues(alpha: 0.08),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            section.icon,
                            size: 17,
                            color: isSelected
                                ? AppColors.ink
                                : AppColors.textMuted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            section.label,
                            style: AppTypography.caption.copyWith(
                              color: isSelected
                                  ? AppColors.ink
                                  : AppColors.textMuted,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
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
        }).toList(),
      ),
    );
  }
}
