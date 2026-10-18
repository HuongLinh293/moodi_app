import '../widgets/crumpled_paper.dart';

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/colors.dart';
import '../state/mindra_state.dart';

/// An ephemeral writing ritual. Drafts never enter journal or garden storage.
class PaperReleaseSheet extends StatefulWidget {
  final MindraState state;
  final String? initialEmotionKey;
  final VoidCallback? onCompleted;

  const PaperReleaseSheet({
    super.key,
    required this.state,
    this.initialEmotionKey,
    this.onCompleted,
  });

  static Future<void> show({
    required BuildContext context,
    required MindraState state,
    String? initialEmotionKey,
    VoidCallback? onCompleted,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (_) => PaperReleaseSheet(
      state: state,
      initialEmotionKey: initialEmotionKey,
      onCompleted: onCompleted,
    ),
  );

  @override
  State<PaperReleaseSheet> createState() => _PaperReleaseSheetState();
}

enum _Stage { writing, crumpling, thrown }

class _PaperReleaseSheetState extends State<PaperReleaseSheet> {
  static const _green = Color(0xFF4A54A4);
  final _text = TextEditingController();
  _Stage _stage = _Stage.writing;
  double _crumple = 0;
  Offset _drag = Offset.zero;
  Offset _flight = Offset.zero;
  Timer? _hold;
  Timer? _expiry;
  bool _undoAvailable = false;

  bool get _quiet =>
      widget.state.lowStimulationMode ||
      MediaQuery.of(context).disableAnimations;

  @override
  void dispose() {
    _hold?.cancel();
    _expiry?.cancel();
    _text.dispose();
    super.dispose();
  }

  void _press() {
    if (_stage != _Stage.crumpling || _crumple >= 1) return;
    if (!_quiet) {
      if (_crumple >= 0.7) {
        HapticFeedback.lightImpact();
      } else {
        HapticFeedback.selectionClick();
      }
    }
    setState(() => _crumple = (_crumple + .16).clamp(0, 1));
  }

  void _startHold() {
    _hold?.cancel();
    _press();
    _hold = Timer.periodic(const Duration(milliseconds: 240), (_) => _press());
  }

  void _stopHold() {
    _hold?.cancel();
    _hold = null;
  }

  void _throwPaper([Offset direction = const Offset(0, -1)]) {
    if (_stage != _Stage.crumpling) return;
    _stopHold();
    if (!_quiet) HapticFeedback.lightImpact();
    final distance = direction.distance;
    final unit = distance == 0 ? const Offset(0, -1) : direction / distance;
    setState(() {
      _crumple = 1;
      _flight = unit * MediaQuery.sizeOf(context).longestSide * 1.3;
      _stage = _Stage.thrown;
      _undoAvailable = true;
    });
    _expiry = Timer(const Duration(seconds: 8), () {
      _text.clear();
      if (mounted) setState(() => _undoAvailable = false);
    });
  }

  void _undo() {
    _expiry?.cancel();
    setState(() {
      _stage = _Stage.writing;
      _crumple = 0;
      _drag = Offset.zero;
      _flight = Offset.zero;
      _undoAvailable = false;
    });
  }

  Future<void> _close() async {
    _stopHold();
    if (_stage != _Stage.thrown && _text.text.trim().isNotEmpty) {
      final leave = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Bỏ tờ giấy này?'),
          content: const Text(
            'Lời viết chưa được lưu. Đóng phiên sẽ xóa nội dung này.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Viết tiếp'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Bỏ tờ giấy'),
            ),
          ],
        ),
      );
      if (leave != true || !mounted) return;
    }
    if (!mounted) return;
    _text.clear();
    Navigator.pop(context);
    if (_stage == _Stage.thrown) widget.onCompleted?.call();
  }

  @override
  Widget build(BuildContext context) {
    final writing = _stage == _Stage.writing;
    final thrown = _stage == _Stage.thrown;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .92,
          child: Material(
            color: AppColors.paper,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            clipBehavior: Clip.antiAlias,
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.description_outlined,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Vò giấy',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Đóng',
                          onPressed: _close,
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              writing
                                  ? 'Những điều khó nói,\ncứ để giấy nghe.'
                                  : thrown
                                  ? 'Ở đây,\nkhông cần vội.'
                                  : 'Đặt điều nặng lòng\nvào tờ giấy.',
                              style: const TextStyle(
                                fontSize: 30,
                                height: 1.25,
                                letterSpacing: -.6,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              writing
                                  ? 'Không ai chấm điểm. Không cần viết cho hay.'
                                  : thrown
                                  ? 'Cứ ở đây một chút nếu bạn muốn.'
                                  : _crumple < 1
                                  ? 'Chạm hoặc giữ để vò. Vuốt để ném.'
                                  : 'Bạn có thể vuốt theo bất kỳ hướng nào để ném.',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                height: 1.6,
                              ),
                            ),
                            const SizedBox(height: 24),
                            if (writing)
                              _writingPaper(constraints.maxHeight)
                            else
                              SizedBox(
                                height: math.max(
                                  190,
                                  math.min(300, constraints.maxHeight - 160),
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  clipBehavior: Clip.none,
                                  children: [
                                    Positioned.fill(
                                      child: IgnorePointer(
                                        child: CustomPaint(
                                          painter: _QuietSpacePainter(
                                            thrown: thrown,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (thrown)
                                      Semantics(
                                        liveRegion: true,
                                        child: Text(
                                          'Chỉ một khoảng yên.',
                                          style: TextStyle(
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ExcludeSemantics(
                                      excluding: thrown,
                                      child: IgnorePointer(
                                        ignoring: thrown,
                                        child: AnimatedContainer(
                                          duration: Duration(
                                            milliseconds: _quiet
                                                ? 0
                                                : thrown
                                                ? 420
                                                : 100,
                                          ),
                                          curve: thrown
                                              ? Curves.easeInCubic
                                              : Curves.easeOut,
                                          transform: Matrix4.translationValues(
                                            thrown ? _flight.dx : _drag.dx,
                                            thrown ? _flight.dy : _drag.dy,
                                            0,
                                          ),
                                          child: AnimatedOpacity(
                                            duration: Duration(
                                              milliseconds: _quiet ? 0 : 350,
                                            ),
                                            opacity: thrown ? 0 : 1,
                                            child: Semantics(
                                              label:
                                                  'Tờ giấy, đã vò ${(_crumple * 100).round()} phần trăm',
                                              button: true,
                                              onTap: _press,
                                              child: GestureDetector(
                                                key: const ValueKey(
                                                  'crumple-paper',
                                                ),
                                                onTap: _press,
                                                onLongPressStart: (_) =>
                                                    _startHold(),
                                                onLongPressEnd: (_) =>
                                                    _stopHold(),
                                                onLongPressCancel: _stopHold,
                                                onVerticalDragUpdate:
                                                    (details) => setState(
                                                      () => _drag +=
                                                          details.delta,
                                                    ),
                                                onVerticalDragEnd: (details) {
                                                  final velocity = details
                                                      .velocity
                                                      .pixelsPerSecond;
                                                  if (_drag.distance > 48 ||
                                                      velocity.distance > 350) {
                                                    _throwPaper(
                                                      velocity.distance > 350
                                                          ? velocity
                                                          : _drag,
                                                    );
                                                  } else {
                                                    setState(
                                                      () => _drag = Offset.zero,
                                                    );
                                                  }
                                                },
                                                onVerticalDragCancel: () =>
                                                    setState(
                                                      () => _drag = Offset.zero,
                                                    ),
                                                onHorizontalDragUpdate:
                                                    (details) => setState(
                                                      () => _drag +=
                                                          details.delta,
                                                    ),
                                                onHorizontalDragEnd: (details) {
                                                  final velocity = details
                                                      .velocity
                                                      .pixelsPerSecond;
                                                  if (_drag.distance > 48 ||
                                                      velocity.distance > 350) {
                                                    _throwPaper(
                                                      velocity.distance > 350
                                                          ? velocity
                                                          : _drag,
                                                    );
                                                  } else {
                                                    setState(
                                                      () => _drag = Offset.zero,
                                                    );
                                                  }
                                                },
                                                onHorizontalDragCancel: () =>
                                                    setState(
                                                      () => _drag = Offset.zero,
                                                    ),
                                                child: SizedBox(
                                                  width: 240,
                                                  height: 230,
                                                  child: CrumpledPaper(
                                                    amount: _crumple,
                                                    text: _text.text,
                                                    reducedMotion: _quiet,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (writing)
                              const Padding(
                                padding: EdgeInsets.only(top: 16),
                                child: Text(
                                  'Chỉ ở đây, trong phiên này. Không lưu vào Nhật ký.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.5,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            if (!writing && !thrown)
                              TextButton(
                                onPressed: () {
                                  _stopHold();
                                  setState(() {
                                    _stage = _Stage.writing;
                                    _drag = Offset.zero;
                                  });
                                },
                                child: const Text('Mở giấy · Viết tiếp'),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FilledButton(
                          key: const ValueKey('paper-primary'),
                          style: FilledButton.styleFrom(
                            backgroundColor: _green,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(56),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                          onPressed: writing
                              ? () {
                                  FocusScope.of(context).unfocus();
                                  setState(() {
                                    _stage = _Stage.crumpling;
                                    _crumple = 0;
                                  });
                                }
                              : thrown
                              ? _close
                              : _throwPaper,
                          child: Text(
                            writing
                                ? 'Vò tờ giấy'
                                : thrown
                                ? 'Kết thúc'
                                : 'Ném đi',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (thrown && _undoAvailable)
                          TextButton(
                            key: const ValueKey('paper-undo'),
                            onPressed: _undo,
                            child: const Text('Hoàn tác · Lấy lại tờ giấy'),
                          ),
                        if (thrown)
                          Text(
                            _undoAvailable
                                ? 'Có thể hoàn tác trong 8 giây. Đóng sẽ xóa lời viết.'
                                : 'Lời viết đã được xóa.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.6,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
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

  Widget _writingPaper(double height) => Container(
    decoration: BoxDecoration(
      color: const Color(0xFFF1EFFA),
      borderRadius: BorderRadius.circular(6),
      boxShadow: const [
        BoxShadow(
          color: Color(0x14292B25),
          blurRadius: 24,
          offset: Offset(0, 10),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: CustomPaint(
        painter: const _WritingPaperPainter(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(26, 18, 22, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.edit_outlined,
                    size: 14,
                    color: AppColors.textMuted,
                  ),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'GỬI NHỮNG ĐIỀU TRONG LÒNG',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: .8,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                key: const ValueKey('paper-writing'),
                controller: _text,
                minLines: height > 450 ? 8 : 4,
                maxLines: 12,
                maxLength: 4000,
                cursorColor: _green,
                textCapitalization: TextCapitalization.sentences,
                keyboardType: TextInputType.multiline,
                style: const TextStyle(
                  fontSize: 17,
                  height: 1.9,
                  color: AppColors.ink,
                ),
                decoration: const InputDecoration(
                  hintText: 'Hôm nay, mình…',
                  hintStyle: TextStyle(
                    color: AppColors.textMuted,
                    fontStyle: FontStyle.italic,
                  ),
                  semanticCounterText: 'Tối đa 4000 ký tự',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// Faceted paper uses the same indigo folds and green leaves as the garden.
class _WritingPaperPainter extends CustomPainter {
  const _WritingPaperPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(0, 38)
        ..close(),
      paint..color = const Color(0xFFE3E0F3),
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width - 34, 0)
        ..lineTo(size.width - 34, 34)
        ..lineTo(size.width, 34)
        ..close(),
      paint..color = const Color(0xFFC4BFE4),
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width - 34, 0)
        ..lineTo(size.width, 34)
        ..lineTo(size.width, 0)
        ..close(),
      paint..color = AppColors.paper,
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height - 34)
        ..lineTo(30, size.height)
        ..lineTo(0, size.height)
        ..close(),
      paint..color = const Color(0xFFD8D4ED),
    );
    final line = Paint()
      ..color = const Color(0x124A54A4)
      ..strokeWidth = .7;
    for (double y = 84; y < size.height - 36; y += 32.3) {
      canvas.drawLine(Offset(26, y), Offset(size.width - 22, y), line);
    }
  }

  @override
  bool shouldRepaint(_WritingPaperPainter oldDelegate) => false;
}

class _QuietSpacePainter extends CustomPainter {
  final bool thrown;
  const _QuietSpacePainter({required this.thrown});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    if (thrown) {
      final c = Offset(size.width / 2, size.height * .24);
      canvas.drawPath(
        Path()
          ..moveTo(c.dx - 20, c.dy)
          ..lineTo(c.dx, c.dy + 7)
          ..lineTo(c.dx + 24, c.dy - 12)
          ..lineTo(c.dx + 4, c.dy + 15)
          ..close(),
        paint..color = const Color(0xFFB5A1F0),
      );
      canvas.drawPath(
        Path()
          ..moveTo(c.dx - 20, c.dy)
          ..lineTo(c.dx - 5, c.dy + 20)
          ..lineTo(c.dx + 4, c.dy + 15)
          ..close(),
        paint..color = const Color(0xFF7975B8),
      );
    }
  }

  @override
  bool shouldRepaint(_QuietSpacePainter oldDelegate) =>
      thrown != oldDelegate.thrown;
}
