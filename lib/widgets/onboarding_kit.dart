import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:zcanopy/utils/onboarding_palette.dart';

enum GoldButtonVariant { primary, outline, ghost }

class GoldButton extends StatelessWidget {
  const GoldButton({
    super.key,
    this.label,
    this.child,
    this.onPressed,
    this.variant = GoldButtonVariant.primary,
    this.loading = false,
    this.height = 56,
    this.icon,
  });

  final String? label;
  final Widget? child;
  final VoidCallback? onPressed;
  final GoldButtonVariant variant;
  final bool loading;
  final double height;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final palette = OnboardingPalette.of(context);
    final content = loading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: palette.ink,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: palette.ink),
                const SizedBox(width: 8),
              ],
              Flexible(
                child:
                    child ??
                    Text(
                      label ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: palette.ink,
                      ),
                    ),
              ),
            ],
          );

    if (variant == GoldButtonVariant.ghost) {
      return SizedBox(
        width: double.infinity,
        height: height,
        child: TextButton(
          onPressed: loading ? null : onPressed,
          style: TextButton.styleFrom(
            foregroundColor: palette.ink,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: content,
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: height,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: variant == GoldButtonVariant.primary
              ? OnboardingPalette.gold
              : palette.paper,
          foregroundColor: palette.ink,
          disabledBackgroundColor: variant == GoldButtonVariant.primary
              ? OnboardingPalette.gold.withValues(alpha: 0.45)
              : palette.paper,
          disabledForegroundColor: palette.ink.withValues(alpha: 0.55),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: variant == GoldButtonVariant.outline
                ? BorderSide(color: palette.line)
                : BorderSide.none,
          ),
        ),
        child: content,
      ),
    );
  }
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.small = false, this.showText = true});

  final bool small;
  final bool showText;

  @override
  Widget build(BuildContext context) {
    final palette = OnboardingPalette.of(context);
    final box = small ? 32.0 : 40.0;
    final icon = small ? 18.0 : 22.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: box,
          height: box,
          decoration: BoxDecoration(
            color: palette.brandSurface,
            borderRadius: BorderRadius.circular(small ? 10 : 12),
          ),
          padding: EdgeInsets.all(small ? 6 : 8),
          child: CustomPaint(
            painter: _CanopyPainter(color: OnboardingPalette.gold),
            size: Size.square(icon),
          ),
        ),
        if (showText) ...[
          SizedBox(width: small ? 8 : 10),
          Text(
            'Zcanopy',
            style: TextStyle(
              fontSize: small ? 18 : 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              color: palette.ink,
            ),
          ),
        ],
      ],
    );
  }
}

class OnboardingIconButton extends StatelessWidget {
  const OnboardingIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 40,
    this.iconSize = 20,
    this.background,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final double iconSize;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final palette = OnboardingPalette.of(context);
    return Material(
      color: background ?? Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: iconSize, color: palette.ink),
        ),
      ),
    );
  }
}

class OnboardingReveal extends StatefulWidget {
  const OnboardingReveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 420),
    this.offset = const Offset(0, 0.08),
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset offset;

  @override
  State<OnboardingReveal> createState() => _OnboardingRevealState();
}

class _OnboardingRevealState extends State<OnboardingReveal> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _shown ? 1 : 0,
      duration: widget.duration,
      curve: Curves.easeOutCubic,
      child: AnimatedSlide(
        offset: _shown ? Offset.zero : widget.offset,
        duration: widget.duration,
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

class OnboardingFloating extends StatefulWidget {
  const OnboardingFloating({
    super.key,
    required this.child,
    this.distance = 6,
    this.duration = const Duration(seconds: 6),
  });

  final Widget child;
  final double distance;
  final Duration duration;

  @override
  State<OnboardingFloating> createState() => _OnboardingFloatingState();
}

class _OnboardingFloatingState extends State<OnboardingFloating>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final eased = Curves.easeInOut.transform(_controller.value);
        return Transform.translate(
          offset: Offset(0, -widget.distance * eased),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class OnboardingImageFrame extends StatelessWidget {
  const OnboardingImageFrame({
    super.key,
    required this.asset,
    this.borderRadius = 32,
    this.topLeft,
    this.bottomRight,
    this.bottomCenter,
    this.imageAlignment = Alignment.center,
  });

  final String asset;
  final double borderRadius;
  final Widget? topLeft;
  final Widget? bottomRight;
  final Widget? bottomCenter;
  final Alignment imageAlignment;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            asset,
            fit: BoxFit.cover,
            alignment: imageAlignment,
            errorBuilder: (context, error, stackTrace) => Container(
              color: const Color(0xFFB8975E).withValues(alpha: 0.25),
              child: Icon(
                Icons.home_work_outlined,
                size: 64,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  const Color(0xFF1E1B16).withValues(alpha: 0.28),
                ],
                stops: const [0.55, 1],
              ),
            ),
          ),
          if (topLeft != null) Positioned(top: 16, left: 16, child: topLeft!),
          if (bottomRight != null)
            Positioned(bottom: 16, right: 16, child: bottomRight!),
          if (bottomCenter != null)
            Positioned(
              bottom: 14,
              left: 0,
              right: 0,
              child: Center(child: bottomCenter!),
            ),
        ],
      ),
    );
  }
}

class OnboardingStatusPill extends StatelessWidget {
  const OnboardingStatusPill({
    super.key,
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = OnboardingPalette.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
      decoration: BoxDecoration(
        color: palette.paper,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: palette.softShadow,
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: palette.champagne,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 14, color: palette.deepAccent),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: palette.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingPriceTag extends StatelessWidget {
  const OnboardingPriceTag({
    super.key,
    required this.price,
    required this.label,
  });

  final String price;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = OnboardingPalette.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 9),
      decoration: BoxDecoration(
        color: palette.brandSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: palette.softShadow,
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            price,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: OnboardingPalette.gold,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.verified_outlined,
                size: 12,
                color: OnboardingPalette.gold,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: palette.dark
                      ? palette.ink.withValues(alpha: 0.7)
                      : const Color(0xFFEFE4CC),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class OnboardingSeal extends StatelessWidget {
  const OnboardingSeal({super.key, this.size = 80});

  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = OnboardingPalette.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: OnboardingPalette.gold,
        shape: BoxShape.circle,
        border: Border.all(color: palette.background, width: 4),
        boxShadow: [
          BoxShadow(
            color: palette.softShadow,
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Icon(Icons.check_rounded, size: size * 0.42, color: palette.ink),
    );
  }
}

class OnboardingSparkle extends StatelessWidget {
  const OnboardingSparkle({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.auto_awesome,
      size: size,
      color: OnboardingPalette.gold.withValues(alpha: 0.9),
    );
  }
}

class OnboardingDots extends StatelessWidget {
  const OnboardingDots({
    super.key,
    required this.count,
    required this.index,
    required this.onTap,
  });

  final int count;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final palette = OnboardingPalette.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        final active = i == index;
        return GestureDetector(
          onTap: () => onTap(i),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            width: active ? 28 : 8,
            height: 8,
            margin: EdgeInsets.only(right: i == count - 1 ? 0 : 8),
            decoration: BoxDecoration(
              color: active ? OnboardingPalette.gold : palette.line,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        );
      }),
    );
  }
}

class OnboardingProgressButton extends StatelessWidget {
  const OnboardingProgressButton({
    super.key,
    required this.progress,
    required this.isLast,
    required this.onTap,
  });

  final double progress;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = OnboardingPalette.of(context);
    return Semantics(
      button: true,
      label: isLast ? 'Get started' : 'Next',
      child: SizedBox(
        width: 76,
        height: 76,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 76,
              height: 76,
              child: CircularProgressIndicator(
                value: progress.clamp(0, 1),
                strokeWidth: 2.5,
                strokeCap: StrokeCap.round,
                backgroundColor: palette.line,
                color: OnboardingPalette.gold,
              ),
            ),
            Material(
              color: OnboardingPalette.gold,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: Icon(
                    isLast ? Icons.check_rounded : Icons.arrow_forward_rounded,
                    size: 22,
                    color: palette.ink,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CanopyPainter extends CustomPainter {
  const _CanopyPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width, size.height) / 24;
    canvas.save();
    canvas.scale(scale, scale);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final arch = Path()
      ..moveTo(3, 11.5)
      ..cubicTo(3, 6.8, 7, 3.5, 12, 3.5)
      ..cubicTo(17, 3.5, 21, 6.8, 21, 11.5);

    final house = Path()
      ..moveTo(7, 20)
      ..lineTo(7, 14)
      ..lineTo(12, 10)
      ..lineTo(17, 14)
      ..lineTo(17, 20);

    final door = Path()
      ..moveTo(10.5, 20)
      ..lineTo(10.5, 17)
      ..lineTo(13.5, 17)
      ..lineTo(13.5, 20);

    canvas.drawPath(arch, paint);
    canvas.drawPath(house, paint);
    canvas.drawPath(door, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CanopyPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
