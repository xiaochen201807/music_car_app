import 'package:flutter/material.dart';

class PortraitCircleButton extends StatelessWidget {
  const PortraitCircleButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.large = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool selected;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: label,
      child: IconButton.filledTonal(
        style: IconButton.styleFrom(
          backgroundColor: selected ? colors.primaryContainer : null,
          fixedSize: Size.square(large ? 58 : 46),
        ),
        iconSize: large ? 30 : 24,
        onPressed: onTap,
        icon: Icon(icon),
      ),
    );
  }
}
