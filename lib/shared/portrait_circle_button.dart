import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// 具有物理阻尼回弹效果的交互包装组件
class BounceTouchable extends StatefulWidget {
  const BounceTouchable({super.key, required this.child, required this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<BounceTouchable> createState() => _BounceTouchableState();
}

class _BounceTouchableState extends State<BounceTouchable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.0,
      upperBound: 0.1,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.92,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onTap != null) {
      _controller.forward();
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.onTap != null) {
      _controller.reverse();
      widget.onTap!();
    }
  }

  void _onTapCancel() {
    if (widget.onTap != null) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
    );
  }
}

/// 高阶圆角中性微光图标按钮
class PortraitCircleButton extends StatelessWidget {
  const PortraitCircleButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.large = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool selected;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final double size = large ? 58 : 46;

    final Widget button = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppColor.fillNeutralHover : AppColor.fillNeutral,
        border: Border.all(
          color: selected
              ? AppColor.strokeStrong
              : colors.outline.withValues(alpha: 0.7),
          width: 1.0,
        ),
      ),
      child: Icon(
        icon,
        size: large ? 30 : 24,
        color: selected ? colors.primary : colors.onSurface,
      ),
    );

    return Tooltip(
      message: label,
      child: BounceTouchable(onTap: onTap, child: button),
    );
  }
}
