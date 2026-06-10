import 'package:flutter/material.dart';

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
