import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

class PortraitSurface extends StatelessWidget {
  const PortraitSurface({
    super.key,
    required this.child,
    this.onTap,
    this.selected = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final BorderRadius radius = BorderRadius.circular(AppRadius.card);
    final Widget content = Ink(
      decoration: BoxDecoration(
        color: selected
            ? colors.primaryContainer.withValues(alpha: 0.62)
            : colors.surfaceContainerHighest.withValues(alpha: 0.72),
        borderRadius: radius,
        border: Border.all(
          color: selected ? colors.primary : colors.outlineVariant,
        ),
      ),
      padding: const EdgeInsets.all(AppSpace.md),
      child: child,
    );
    if (onTap == null) {
      return content;
    }
    return InkWell(borderRadius: radius, onTap: onTap, child: content);
  }
}
