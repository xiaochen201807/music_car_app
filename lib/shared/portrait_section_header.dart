import 'package:flutter/material.dart';
import 'portrait_chip.dart';

class PortraitSectionHeader extends StatelessWidget {
  const PortraitSectionHeader({
    super.key,
    required this.title,
    required this.label,
  });

  final String title;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        PortraitChip(label: label),
      ],
    );
  }
}
