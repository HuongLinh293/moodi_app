import 'package:flutter/material.dart';

/// Allows a short, vertically spaced panel to grow into a scrollable page when
/// large text or the keyboard leaves less room than its content needs.
class ScrollablePanel extends StatelessWidget {
  const ScrollablePanel({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: IntrinsicHeight(child: child),
      ),
    ),
  );
}
