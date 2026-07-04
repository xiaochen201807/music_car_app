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
    final BorderRadiusGeometry borderRadius = BorderRadius.circular(radius);
    final bool isLight = Theme.of(context).brightness == Brightness.light;
    final bool ancestorHasBlur = GlassBackdropScope.hasBlur(context);
    final double effectiveBlur = 0;
    final List<BoxShadow> effectiveShadows = const <BoxShadow>[];
    final BoxDecoration decoration = BoxDecoration(
      color: isLight
          ? AppColor.paperGlassTint
          : AppColor.glassTint.withValues(alpha: AppGlass.tintAlpha),
      borderRadius: borderRadius,
      border: Border.all(
        color: isLight ? AppColor.paperStrokeHairline : AppColor.strokeHairline,
      ),
      boxShadow: effectiveShadows,
    );
    final Widget content = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: decoration,
      child: child,
    );

    return GlassBackdropScope(
      hasActiveBlur: ancestorHasBlur || effectiveBlur > 0,
      child: content,
    );
  }
}

class GlassBackdropScope extends InheritedWidget {
  const GlassBackdropScope({
    super.key,
    required this.hasActiveBlur,
    required super.child,
  });

  final bool hasActiveBlur;

  static bool hasBlur(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<GlassBackdropScope>()
            ?.hasActiveBlur ??
        false;
  }

  @override
  bool updateShouldNotify(GlassBackdropScope oldWidget) {
    return hasActiveBlur != oldWidget.hasActiveBlur;
  }
}

class GlassPerformanceMode extends InheritedWidget {
  const GlassPerformanceMode({
    super.key,
    required this.enabled,
    required super.child,
  });

  final bool enabled;

  static bool of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<GlassPerformanceMode>()
            ?.enabled ??
        false;
  }

  @override
  bool updateShouldNotify(GlassPerformanceMode oldWidget) {
    return enabled != oldWidget.enabled;
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
