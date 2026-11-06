import 'package:flutter/material.dart';

class AppColors {
  // Base Palette
  static const Color ink = Color(0xFF292B25);
  static const Color paper = Color(0xFFF8F3EA);
  static const Color cream = Color(0xFFFFFAF0);
  static const Color creamDark = Color(0xFFF2ECE1);
  static const Color yellow = Color(0xFFFFC629);
  static const Color orange = Color(0xFFFF5A1F);
  static const Color orangeText = Color(0xFFB83C0B);
  static const Color blue = Color(0xFF2366E8);
  static const Color mint = Color(0xFF31CF99);
  static const Color pink = Color(0xFFE56A9D);
  static const Color purple = Color(0xFF8B63E8);
  static const Color lavender = Color(0xFFB5A1F0);
  static const Color gray = Color(0xFF8FAAA2);
  static const Color softYellow = Color(0xFFE5B038);

  // Border & Dividers
  static const Color line = Color(0x29292B25); // rgba(41, 43, 37, 0.16)
  static const Color lineLight = Color(0x14292B25);

  // Text & Subtitles
  static const Color textPrimary = Color(0xFF292B25);
  static const Color textSecondary = Color(0xFF6E6C63);
  // Kept dark enough to remain legible on the paper surface at small sizes.
  static const Color textMuted = Color(0xFF706E64);
  static const Color textTertiary = Color(0xFF706E64);

  // Emotion Background & Foreground
  static const Map<String, Color> emotionTones = {
    'calm': mint,
    'happy': yellow,
    'stressed': orange,
    'sad': blue,
    'anxious': pink,
    'angry': orange,
    'tired': gray,
    'ashamed': softYellow,
    'grateful': yellow,
    'numb': lavender,
  };

  // Face Background and Outline (Cùng tone với màu nền, nền đậm hơn, icon nhạt hơn như calm)
  static const Map<String, List<Color>> facePalette = {
    'happy': [Color(0xFFFFF0A6), Color(0xFF4E3D12)],
    'calm': [Color(0xFFA9DCCB), Color(0xFF204B4A)],
    'sad': [Color(0xFFBDD4F8), Color(0xFF1B2A56)],
    'angry': [Color(0xFFF9A896), Color(0xFF48140F)],
    'anxious': [Color(0xFFF8C8DF), Color(0xFF4D1C35)],
    'stressed': [Color(0xFFFFBEA2), Color(0xFF4A1B12)],
    'ashamed': [Color(0xFFFDE8AA), Color(0xFF48360D)],
    'tired': [Color(0xFFDFEAE7), Color(0xFF283A36)],
    'neutral': [Color(0xFFE5E9EE), Color(0xFF363E48)],
  };

  /// Chữ trắng hay chữ đậm (ink) trên nền [background]: chọn bên có độ tương
  /// phản cao hơn, thay vì một ngưỡng độ sáng cố định (vd. hồng/cam/xám cần
  /// chữ đậm để đạt WCAG).
  static bool prefersLightText(Color background) {
    double contrast(Color a, Color b) {
      final la = a.computeLuminance();
      final lb = b.computeLuminance();
      return la > lb ? (la + 0.05) / (lb + 0.05) : (lb + 0.05) / (la + 0.05);
    }

    return contrast(Colors.white, background) > contrast(ink, background);
  }
}
