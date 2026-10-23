import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/theme/colors.dart';
import '../core/theme/motion.dart';
import '../state/mindra_state.dart';
import 'garden_view.dart';
import 'journal_view.dart';

class PersonalSpaceView extends StatefulWidget {
  final MindraState state;
  final VoidCallback onOpenCheckin;

  const PersonalSpaceView({
    super.key,
    required this.state,
    required this.onOpenCheckin,
  });

  @override
  State<PersonalSpaceView> createState() => _PersonalSpaceViewState();
}

class _PersonalSpaceViewState extends State<PersonalSpaceView> {
  late int _section;

  @override
  void initState() {
    super.initState();
    _section = widget.state.personalSpaceSection;
    widget.state.addListener(_onStateChange);
  }

  @override
  void dispose() {
    widget.state.removeListener(_onStateChange);
    super.dispose();
  }

  void _onStateChange() {
    if (_section != widget.state.personalSpaceSection && mounted) {
      setState(() {
        _section = widget.state.personalSpaceSection;
      });
    }
  }

  void _setSection(int index) {
    widget.state.setPersonalSpaceSection(index);
    setState(() => _section = index);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
          child: _buildSectionSwitcher(),
        ),
        Expanded(
          // IndexedStack giữ trạng thái (tháng, ngày đang chọn) khi chuyển mục.
          child: IndexedStack(
            index: _section,
            children: [
              JournalView(state: widget.state),
              GardenView(
                state: widget.state,
                onOpenCheckin: widget.onOpenCheckin,
                onOpenJournal: () => _setSection(0),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionSwitcher() {
    final sections = [
      (icon: CupertinoIcons.book, label: 'Nhật ký'),
      (icon: Icons.local_florist_outlined, label: 'Khu vườn'),
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
                  onTap: () => _setSection(index),
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
                            size: 18,
                            color: isSelected
                                ? AppColors.ink
                                : AppColors.textMuted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            section.label,
                            style: TextStyle(
                              fontSize: 14,
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
