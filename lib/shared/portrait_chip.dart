import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';
import '../widgets/glass_card.dart';

class PortraitChip extends StatelessWidget {
  const PortraitChip({super.key, required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GlassPill(
      onTap: onTap,
      height: 32,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.md,
        vertical: AppSpace.xs,
      ),
      child: Center(
        widthFactor: 1.0,
        heightFactor: 1.0,
        child: Text(
          label,
          style: AppType.caption,
        ),
      ),
    );
  }
}
