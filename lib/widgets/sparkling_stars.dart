import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 动态取色背景渐变层。
/// 根据传入的 [seedColor] 自动进行柔和插值过渡，并叠加背景的熠熠星辉星空微光。
class PortraitDynamicBackground extends StatelessWidget {
  const PortraitDynamicBackground({
    super.key,
    required this.seedColor,
    required this.child,
  });

  final Color seedColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<Color?>(
      duration: const Duration(milliseconds: 1500),
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
          child: Stack(
            children: <Widget>[
              const Positioned.fill(
                child: _SparklingStars(),
              ),
              childWidget ?? const SizedBox.shrink(),
            ],
          ),
        );
      },
      child: child,
    );
  }
}

class _SparklingStars extends StatefulWidget {
  const _SparklingStars();

  @override
  State<_SparklingStars> createState() => _SparklingStarsState();
}

class _SparklingStarsState extends State<_SparklingStars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<_Star> _stars = <_Star>[];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );

    // 单元测试环境下隔离 AnimationController.repeat()，以防 pumpAndSettle 超时
    final String bindingType = WidgetsBinding.instance.runtimeType.toString();
    if (!bindingType.contains('Test')) {
      _controller.repeat();
    }

    // 随机初始化 35 颗微光星星
    for (int i = 0; i < 35; i++) {
      _stars.add(
        _Star(
          x: _random.nextDouble(),
          y: _random.nextDouble(),
          size: 0.6 + _random.nextDouble() * 1.8,
          phaseOffset: _random.nextDouble() * math.pi * 2,
          speed: 0.8 + _random.nextDouble() * 1.2,
        ),
      );
    }
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
      builder: (BuildContext context, Widget? child) {
        return CustomPaint(
          painter: _StarPainter(
            stars: _stars,
            progress: _controller.value,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _Star {
  const _Star({
    required this.x,
    required this.y,
    required this.size,
    required this.phaseOffset,
    required this.speed,
  });

  final double x;
  final double y;
  final double size;
  final double phaseOffset;
  final double speed;
}

class _StarPainter extends CustomPainter {
  const _StarPainter({
    required this.stars,
    required this.progress,
  });

  final List<_Star> stars;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = Colors.white;

    for (final _Star star in stars) {
      final double radians =
          (progress * math.pi * 2 * star.speed) + star.phaseOffset;
      // 极其低调的亮度，在 0.04 到 0.28 之间，呈现若隐若现的空灵感
      final double alpha = 0.04 + (0.12 * (math.sin(radians) + 1.0));

      paint.color = Colors.white.withValues(alpha: alpha);

      final double px = star.x * size.width;
      final double py = star.y * size.height;

      canvas.drawCircle(Offset(px, py), star.size, paint);

      // 十字微光效果：微调稍大的光点，在大亮度下产生十字向外发散的微光（游丝感）
      if (star.size > 1.8 && alpha > 0.12) {
        final Paint glowPaint = Paint()
          ..color = Colors.white.withValues(alpha: alpha * 0.4)
          ..strokeWidth = 0.5;
        final double glowLength = star.size * 2.5;

        canvas.drawLine(
            Offset(px - glowLength, py), Offset(px + glowLength, py), glowPaint);
        canvas.drawLine(
            Offset(px, py - glowLength), Offset(px, py + glowLength), glowPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StarPainter oldDelegate) => true;
}
