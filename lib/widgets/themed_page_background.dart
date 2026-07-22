import 'package:flutter/material.dart';

/// Page wrapper that shows the photo background in light mode and a solid
/// themed surface in dark mode, with an optional light-mode overlay.
class ThemedPageBackground extends StatelessWidget {
  final Widget child;
  final bool lightOverlay;
  final double lightOverlayOpacity;

  const ThemedPageBackground({
    super.key,
    required this.child,
    this.lightOverlay = false,
    this.lightOverlayOpacity = 0.85,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? theme.scaffoldBackgroundColor : null,
        image: isDark
            ? null
            : const DecorationImage(
                image: AssetImage('assets/background.jpg'),
                fit: BoxFit.cover,
              ),
      ),
      child: lightOverlay && !isDark
          ? Container(
              color: Colors.white.withOpacity(lightOverlayOpacity),
              child: child,
            )
          : child,
    );
  }
}
