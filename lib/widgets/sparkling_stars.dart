import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// 动态取色背景渐变层。
/// 根据传入的 [seedColor] 自动进行柔和插值过渡。
class PortraitDynamicBackground extends StatelessWidget {
  const PortraitDynamicBackground({
    super.key,
    required this.seedColor,
    required this.child,
    this.effectsPaused = false,
  });

  final Color seedColor;
  final Widget child;
  final bool effectsPaused;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    if (Theme.of(context).brightness == Brightness.light) {
      return DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              AppColor.paperWarm,
              AppColor.paperBase,
              AppColor.paperCool,
            ],
            stops: <double>[0, 0.54, 1],
          ),
        ),
        child: CustomPaint(painter: const _PaperTexturePainter(), child: child),
      );
    }

    return TweenAnimationBuilder<Color?>(
      duration: effectsPaused
          ? Duration.zero
          : const Duration(milliseconds: 1500),
      curve: Curves.easeInOut,
      tween: ColorTween(end: seedColor),
      builder:
          (BuildContext context, Color? animatedColor, Widget? childWidget) {
            final Color currentSeed = animatedColor ?? seedColor;
            return DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    currentSeed.withValues(alpha: 0.32),
                    colors.surface,
                    colors.surface,
                  ],
                  stops: const <double>[0, 0.38, 1],
                ),
              ),
              child: childWidget ?? const SizedBox.shrink(),
            );
          },
      child: child,
    );
  }
}

class _PaperTexturePainter extends CustomPainter {
  const _PaperTexturePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint fiberPaint = Paint()
      ..color = AppColor.paperFiber
      ..strokeWidth = 0.55
      ..strokeCap = StrokeCap.round;
    final Paint porePaint = Paint()
      ..color = AppColor.paperFiber.withValues(alpha: 0.55)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 72; i += 1) {
      final double x = (i * 41 % 100) / 100 * size.width;
      final double y = (i * 67 % 100) / 100 * size.height;
      final double length = 4 + (i % 5) * 1.2;
      final double drift = ((i % 7) - 3) * 0.35;
      canvas.drawLine(
        Offset(x, y),
        Offset(
          (x + length).clamp(0, size.width),
          (y + drift).clamp(0, size.height),
        ),
        fiberPaint,
      );
    }

    for (int i = 0; i < 46; i += 1) {
      final double x = (i * 53 % 100) / 100 * size.width;
      final double y = (i * 29 % 100) / 100 * size.height;
      canvas.drawCircle(Offset(x, y), 0.45 + (i % 3) * 0.18, porePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PaperTexturePainter oldDelegate) => false;
}
