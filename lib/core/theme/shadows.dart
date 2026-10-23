import 'package:flutter/material.dart';

/// Shadow tokens for Mindra design system.
/// Replaces hard borders — use soft drop shadows to create elevation.
class AppShadows {
  AppShadows._();

  /// Standard card — resting state. blur 12px, ink 6%
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x0F292B25), blurRadius: 12, offset: Offset(0, 4)),
  ];

  /// Raised card — active / pressed state. blur 20px, ink 8%
  static const List<BoxShadow> cardRaised = [
    BoxShadow(color: Color(0x14292B25), blurRadius: 20, offset: Offset(0, 8)),
  ];

  /// Chip / pill (top-bar corner chips). blur 16px, ink 6%
  static const List<BoxShadow> chip = [
    BoxShadow(color: Color(0x0F292B25), blurRadius: 16, offset: Offset(0, 4)),
  ];
}
