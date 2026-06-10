import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding = EdgeInsets.zero,
    this.radius = AppRadius.card,
    this.blur = AppSpace.xl,
    this.shadows = const <BoxShadow>[AppShadow.card],
  });

  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double blur;
  final List<BoxShadow> shadows;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          width: width,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: AppColor.glassTint.withValues(alpha: AppGlass.tintAlpha),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: AppColor.strokeHairline),
            boxShadow: shadows,
          ),
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(radius),
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[AppColor.sheenTop, Colors.transparent],
                      ),
                    ),
                  ),
                ),
              ),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class GlassPill extends StatelessWidget {
  const GlassPill({
    super.key,
    required this.child,
    this.onTap,
    this.height,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpace.md),
  });

  final Widget child;
  final VoidCallback? onTap;
  final double? height;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final Widget content = GlassCard(
      height: height,
      radius: AppRadius.pill,
      blur: AppSpace.lg,
      padding: padding,
      shadows: const <BoxShadow>[],
      child: Center(child: child),
    );
    if (onTap == null) {
      return content;
    }
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      onTap: onTap,
      child: content,
    );
  }
}
