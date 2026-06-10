import 'package:flutter/material.dart';

class PortraitChip extends StatelessWidget {
  const PortraitChip({super.key, required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      backgroundColor: colors.surfaceContainerHighest.withValues(alpha: 0.7),
      side: BorderSide(color: colors.outlineVariant),
    );
  }
}
