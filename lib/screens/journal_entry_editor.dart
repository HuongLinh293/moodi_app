import 'package:flutter/material.dart';

import '../core/theme/colors.dart';
import '../models/emotion.dart';
import '../models/journal_entry.dart';
import '../state/mindra_state.dart';
import '../widgets/unsaved_changes_guard.dart';

class JournalEntryEditor extends StatefulWidget {
  const JournalEntryEditor({
    super.key,
    required this.state,
    required this.date,
    this.entry,
  });
  final MindraState state;
  final DateTime date;
  final JournalEntry? entry;
  @override
  State<JournalEntryEditor> createState() => _JournalEntryEditorState();
}

class _JournalEntryEditorState extends State<JournalEntryEditor> {
  late final TextEditingController _situation, _thought, _response;
  late String? _emotion;
  late String _trigger;
  late int _intensity;
  bool _saving = false;
  static const triggers = {
    'other': 'Chưa rõ / khác',
    'work': 'Công việc',
    'family': 'Gia đình',
    'friends': 'Bạn bè',
    'relationship': 'Tình cảm',
    'self_care': 'Bản thân',
    'health': 'Sức khỏe',
    'rest': 'Nghỉ ngơi',
    'finance': 'Tài chính',
    'study': 'Học tập',
  };
  @override
  void initState() {
    super.initState();
    _situation = TextEditingController(text: widget.entry?.situation ?? '');
    _thought = TextEditingController(text: widget.entry?.thought ?? '');
    _response = TextEditingController(text: widget.entry?.response ?? '');
    _emotion = widget.entry?.emotionKey;
    _trigger = widget.entry?.trigger ?? 'other';
    _intensity = widget.entry?.intensity ?? 3;
    for (final c in [_situation, _thought, _response]) {
      c.addListener(() {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _situation.dispose();
    _thought.dispose();
    _response.dispose();
    super.dispose();
  }

  bool get _dirty =>
      !_saving &&
      (_situation.text != (widget.entry?.situation ?? '') ||
          _thought.text != (widget.entry?.thought ?? '') ||
          _response.text != (widget.entry?.response ?? '') ||
          _emotion != widget.entry?.emotionKey ||
          _trigger != (widget.entry?.trigger ?? 'other') ||
          _intensity != (widget.entry?.intensity ?? 3));
  Future<void> _save() async {
    if (_saving || _emotion == null) return;
    setState(() => _saving = true);
    final now = DateTime.now();
    final base =
        widget.entry ??
        JournalEntry(
          id: 'entry-${now.microsecondsSinceEpoch}',
          timestamp: DateTime(
            widget.date.year,
            widget.date.month,
            widget.date.day,
            now.hour,
            now.minute,
          ),
          emotionKey: _emotion!,
          intensity: _intensity,
        );
    final saved = base.copyWith(
      emotionKey: _emotion,
      intensity: _intensity,
      trigger: _trigger,
      situation: _situation.text.trim(),
      thought: _thought.text.trim(),
      response: _response.text.trim(),
    );
    if (widget.entry == null) {
      widget.state.addEntry(saved);
    } else {
      widget.state.updateEntry(saved);
    }
    await widget.state.flushLocalData();
    if (!mounted) return;
    Navigator.pop(context, saved);
  }

  Widget _field(String label, TextEditingController controller) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextField(
      controller: controller,
      minLines: 2,
      maxLines: 6,
      maxLength: 4000,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => UnsavedChangesGuard(
    dirty: _dirty,
    child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .9,
        child: Material(
          color: AppColors.paper,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.entry == null
                              ? 'Ghi nhận cảm xúc · ${widget.date.day}/${widget.date.month}'
                              : 'Sửa nhật ký cảm xúc',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Đóng trình sửa nhật ký',
                        onPressed: () => Navigator.maybePop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Chọn cảm xúc gần nhất'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            for (final e in MindraEmotions.all.values)
                              ChoiceChip(
                                label: Text(e.vi),
                                selected: _emotion == e.key,
                                onSelected: (_) =>
                                    setState(() => _emotion = e.key),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text('Mức độ cảm nhận: $_intensity/5'),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (var i = 1; i <= 5; i++)
                              ChoiceChip(
                                label: Text('$i'),
                                selected: _intensity == i,
                                onSelected: (_) =>
                                    setState(() => _intensity = i),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: _trigger,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Tác nhân (tùy chọn)',
                          ),
                          items: [
                            for (final e in {
                              ...triggers,
                              if (!triggers.containsKey(_trigger))
                                _trigger: _trigger,
                            }.entries)
                              DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value),
                              ),
                          ],
                          onChanged: (v) =>
                              setState(() => _trigger = v ?? 'other'),
                        ),
                        const SizedBox(height: 20),
                        _field('Tình huống', _situation),
                        _field('Suy nghĩ', _thought),
                        _field('Phản ứng', _response),
                        FilledButton(
                          onPressed: _emotion == null || _saving ? null : _save,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Text(
                              _saving
                                  ? 'Đang lưu…'
                                  : widget.entry == null
                                  ? 'Lưu vào nhật ký'
                                  : 'Lưu thay đổi',
                            ),
                          ),
                        ),
                      ],
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
}
