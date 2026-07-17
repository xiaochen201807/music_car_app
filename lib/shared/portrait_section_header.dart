import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';
import 'portrait_chip.dart';

class PortraitSectionHeader extends StatelessWidget {
  const PortraitSectionHeader({
    super.key,
    required this.title,
    this.label,
    this.showLoading = false,
  });

  final String title;
  final String? label;
  final bool showLoading;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              // Section headers: w900; body hierarchy starts below this.
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        if (showLoading) ...<Widget>[
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
            ),
          ),
          const SizedBox(width: AppSpace.sm),
        ],
        if (label != null) PortraitChip(label: label!),
      ],
    );
  }
}
