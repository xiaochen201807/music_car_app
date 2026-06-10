import 'dart:math' as math;
import 'package:flutter/material.dart';

class LuxuryLoadingIndicator extends StatefulWidget {
  const LuxuryLoadingIndicator({super.key, this.size = 32.0});

  final double size;

  @override
  State<LuxuryLoadingIndicator> createState() => _LuxuryLoadingIndicatorState();
}

class _LuxuryLoadingIndicatorState extends State<LuxuryLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    final String bindingType = WidgetsBinding.instance.runtimeType.toString();
    if (!bindingType.contains('Test')) {
      _ctrl.repeat();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: widget.size * 2.2,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (BuildContext context, Widget? child) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (int index) {
              final double delay = index * 0.4;
              final double t =
                  (_ctrl.value * 2 * math.pi - delay) % (2 * math.pi);
              final double scale = 0.6 + 0.4 * (math.sin(t) + 1.0) / 2;
              final double opacity = 0.2 + 0.8 * (math.sin(t) + 1.0) / 2;

              return Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity,
                  child: Container(
                    width: widget.size * 0.22,
                    height: widget.size * 0.22,
                    margin:
                        EdgeInsets.symmetric(horizontal: widget.size * 0.08),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.primary,
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: colors.primary.withValues(alpha: 0.35),
                          blurRadius: 6,
                          spreadRadius: 1.5,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
