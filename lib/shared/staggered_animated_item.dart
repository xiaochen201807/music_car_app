import 'package:flutter/material.dart';

class StaggeredAnimatedItem extends StatefulWidget {
  const StaggeredAnimatedItem({
    super.key,
    required this.index,
    required this.child,
    this.duration = const Duration(milliseconds: 380),
    this.delayMultiplier = 50,
  });

  final int index;
  final Widget child;
  final Duration duration;
  final int delayMultiplier;

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

    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.16),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    final int animIndex = widget.index.clamp(0, 6);
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
