import 'package:flutter/material.dart';

class OnboardingPalette {
  const OnboardingPalette._(this.dark);

  final bool dark;

  factory OnboardingPalette.of(BuildContext context) {
    return OnboardingPalette._(Theme.of(context).brightness == Brightness.dark);
  }

  static const Color gold = Color(0xFFC9A24A);
  static const Color goldStrong = Color(0xFFB58C33);
  static const Color goldDeep = Color(0xFF85621D);

  Color get background =>
      dark ? const Color(0xFF121212) : const Color(0xFFF7F2E9);
  Color get paper => dark ? const Color(0xFF1E1B16) : const Color(0xFFFFFDF8);
  Color get ink => dark ? const Color(0xFFF7F2E9) : const Color(0xFF1E1B16);
  Color get muted => dark ? const Color(0xFFA9A295) : const Color(0xFF6B6457);
  Color get line => dark ? const Color(0xFF3A342B) : const Color(0xFFE5DCCB);
  Color get champagne =>
      dark ? const Color(0xFF2C261D) : const Color(0xFFEFE4CC);
  Color get brandSurface =>
      dark ? const Color(0xFF2A2A2A) : const Color(0xFF1E1B16);
  Color get deepAccent => dark ? const Color(0xFFD7B25C) : goldDeep;
  Color get softShadow =>
      dark ? Colors.black.withValues(alpha: 0.45) : const Color(0x331E1B16);
}
