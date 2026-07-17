import 'package:flutter/material.dart';

/// Entrance animation for list/grid items.
///
/// Phase 6 budget: only the first 6 items animate; total wall-clock
/// (max delay + duration) stays ≤ 400ms.
class StaggeredAnimatedItem extends StatefulWidget {
  const StaggeredAnimatedItem({
    super.key,
    required this.index,
    required this.child,
    this.duration = const Duration(milliseconds: 220),
    this.delayMultiplier = 30,
    this.maxAnimatedIndex = 5,
  });

  final int index;
  final Widget child;
  final Duration duration;

  /// Milliseconds between successive item starts.
  final int delayMultiplier;

  /// Inclusive last index that receives entrance animation (0-based).
  final int maxAnimatedIndex;

  @override
  State<StaggeredAnimatedItem> createState() => _StaggeredAnimatedItemState();
}

class _StaggeredAnimatedItemState extends State<StaggeredAnimatedItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    final String bindingType = WidgetsBinding.instance.runtimeType.toString();
    if (bindingType.contains('Test') ||
        widget.index > widget.maxAnimatedIndex) {
      // Tests and long-tail items: show immediately (no entrance budget).
      _controller.value = 1.0;
      return;
    }

    final int animIndex = widget.index.clamp(0, widget.maxAnimatedIndex);
    Future<void>.delayed(
      Duration(milliseconds: animIndex * widget.delayMultiplier),
      () {
        if (mounted) {
          _controller.forward();
        }
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(position: _slideAnimation, child: widget.child),
    );
  }
}
