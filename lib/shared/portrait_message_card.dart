import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';
import '../widgets/glass_card.dart';

/// Unified empty / error / info card (Phase 4).
/// Layout: icon · title · guide message · optional primary action.
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
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final bool isLight = theme.brightness == Brightness.light;
    return GlassCard(
      radius: AppRadius.panel,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.xl,
        vertical: AppSpace.xl2,
      ),
      shadows: const <BoxShadow>[],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: AppSpace.xl4,
            height: AppSpace.xl4,
            decoration: BoxDecoration(
              color: isLight
                  ? colors.primaryContainer
                  : colors.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Icon(icon, size: AppSpace.xl2, color: colors.primary),
          ),
          const SizedBox(height: AppSpace.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
          if (action != null) ...<Widget>[
            const SizedBox(height: AppSpace.lg),
            action!,
          ],
        ],
      ),
    );
  }
}
