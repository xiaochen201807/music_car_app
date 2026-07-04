import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';
import '../widgets/glass_card.dart';

class PortraitMessageCard extends StatelessWidget {
  const PortraitMessageCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return GlassCard(
      radius: AppRadius.panel,
      padding: const EdgeInsets.all(AppSpace.xl),
      shadows: const <BoxShadow>[],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          GlassCard(
            width: AppSpace.xl4,
            height: AppSpace.xl4,
            radius: AppRadius.pill,
            padding: EdgeInsets.zero,
            shadows: const <BoxShadow>[],
            child: Icon(icon, size: AppSpace.xl2, color: colors.primary),
          ),
          const SizedBox(height: AppSpace.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppType.cardTitle.copyWith(color: colors.onSurface),
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppType.body.copyWith(color: colors.onSurfaceVariant),
          ),
          if (action != null) ...<Widget>[
            const SizedBox(height: AppSpace.md),
            action!,
          ],
        ],
      ),
    );
  }
}
