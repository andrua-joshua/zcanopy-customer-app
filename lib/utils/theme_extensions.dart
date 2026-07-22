import 'package:flutter/material.dart';

extension AppThemeContext on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  Color get appPrimary => Theme.of(this).colorScheme.primary;

  Color get appSurface => Theme.of(this).colorScheme.surface;

  Color get appOnSurface => Theme.of(this).colorScheme.onSurface;

  Color get appCardColor =>
      Theme.of(this).cardTheme.color ?? Theme.of(this).colorScheme.surface;

  Color get appScaffoldColor => Theme.of(this).scaffoldBackgroundColor;

  /// The app's signature brown, consistent across both themes.
  Color get appPrimaryBrown => const Color(0xFFA9710E);

  /// Subtle divider color appropriate for the current brightness.
  Color get appDividerColor =>
      isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200;

  /// A muted text color for secondary labels.
  Color get appMutedTextColor =>
      isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700;

  /// Convenience for the text field fill color used across forms.
  Color get appInputFillColor =>
      isDarkMode ? const Color(0xFF2A2A2A) : const Color(0x59B7B7B7);
}
