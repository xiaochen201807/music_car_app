import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class WaveformSeekBar extends StatefulWidget {
  const WaveformSeekBar({
    super.key,
    required this.value,
    required this.color,
    required this.trackColor,
    required this.onChanged,
  });

  final double value;
  final Color color;
  final Color trackColor;
  final ValueChanged<double>? onChanged;

  @override
  State<WaveformSeekBar> createState() => _WaveformSeekBarState();
}

class _WaveformSeekBarState extends State<WaveformSeekBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  double _lastVibratedValue = 0.0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onChanged == null
          ? null
          : (TapDownDetails details) {
              final RenderBox box = context.findRenderObject()! as RenderBox;
              final double newValue =
                  (details.localPosition.dx / box.size.width).clamp(0, 1);
              _lastVibratedValue = newValue;
              unawaited(HapticFeedback.lightImpact());
              widget.onChanged!(newValue);
            },
      onHorizontalDragUpdate: widget.onChanged == null
          ? null
          : (DragUpdateDetails details) {
              final RenderBox box = context.findRenderObject()! as RenderBox;
              final double newValue =
                  (details.localPosition.dx / box.size.width).clamp(0, 1);
              if ((newValue - _lastVibratedValue).abs() >= 0.02) {
                _lastVibratedValue = newValue;
                unawaited(HapticFeedback.selectionClick());
              }
              widget.onChanged!(newValue);
            },
      child: SizedBox(
        height: 52,
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (BuildContext context, Widget? child) {
            return CustomPaint(
              painter: WaveformSeekPainter(
                value: widget.value,
                color: widget.color,
                trackColor: widget.trackColor,
                phase: _animationController.value * math.pi * 2,
              ),
            );
          },
        ),
      ),
    );
  }
}

class WaveformSeekPainter extends CustomPainter {
  const WaveformSeekPainter({
    required this.value,
    required this.color,
    required this.trackColor,
    required this.phase,
  });

  final double value;
  final Color color;
  final Color trackColor;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    const int barCount = 48;
    final double gap = size.width / (barCount * 1.72);
    final double barWidth = gap * 0.72;
    final double progressX = size.width * value.clamp(0, 1);
    final Paint paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth;
    for (int index = 0; index < barCount; index += 1) {
      final double x = (index + 0.5) * size.width / barCount;
      final double wave = 0.38 +
          (math.sin(index * 0.72 + phase * 0.15) + 1) * 0.18 +
          (math.sin(index * 1.37 - phase * 0.1) + 1) * 0.09;
      final double height = size.height * wave;
      paint.color = x <= progressX ? color : trackColor;
      canvas.drawLine(
        Offset(x, (size.height - height) / 2),
        Offset(x, (size.height + height) / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(WaveformSeekPainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.phase != phase;
  }
}
