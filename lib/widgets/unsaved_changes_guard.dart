import 'package:flutter/material.dart';

/// Protects a draft for system back, sheet dismissal and close buttons using
/// Navigator.maybePop. Saving may pop the route directly.
class UnsavedChangesGuard extends StatefulWidget {
  const UnsavedChangesGuard({
    super.key,
    required this.dirty,
    required this.child,
  });
  final bool dirty;
  final Widget child;

  @override
  State<UnsavedChangesGuard> createState() => _UnsavedChangesGuardState();
}

class _UnsavedChangesGuardState extends State<UnsavedChangesGuard> {
  bool _discard = false;
  bool _asking = false;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !widget.dirty || _discard,
    onPopInvokedWithResult: (didPop, result) async {
      if (didPop || _asking) return;
      _asking = true;
      final discard = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Bỏ nội dung đang viết?'),
          content: const Text('Nội dung chưa lưu sẽ mất nếu bạn đóng lúc này.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Viết tiếp'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Bỏ nội dung'),
            ),
          ],
        ),
      );
      _asking = false;
      if (discard != true || !mounted) return;
      setState(() => _discard = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop(result);
      });
    },
    child: widget.child,
  );
}
