import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/design_tokens.dart';

class PortraitSegmentedTab<T> extends StatelessWidget {
  const PortraitSegmentedTab({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onSelected,
    this.expands = false,
  });

  final List<PortraitSegmentTabItem<T>> tabs;
  final T selected;
  final ValueChanged<T> onSelected;
  final bool expands;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final bool isLight = theme.brightness == Brightness.light;

    final BorderRadius radius = BorderRadius.circular(AppRadius.control);

    Widget buildItem(PortraitSegmentTabItem<T> item) {
      final bool isSelected = item.value == selected;
      final Widget content = GestureDetector(
        onTap: () {
          if (!isSelected) {
            HapticFeedback.selectionClick();
            onSelected(item.value);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.md,
            vertical: AppSpace.sm,
          ),
          width: expands ? double.infinity : null,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? isLight
                      ? colors.primaryContainer
                      : colors.primaryContainer.withValues(alpha: 0.65)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.control - 2),
            boxShadow: isSelected && !isLight
                ? <BoxShadow>[
                    BoxShadow(
                      color: colors.primary.withValues(alpha: 0.15),
                      offset: const Offset(0, 2),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                item.icon,
                size: 16,
                color: isSelected
                    ? colors.onPrimaryContainer
                    : colors.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpace.xs),
              Text(
                item.label,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                  color: isSelected
                      ? colors.onPrimaryContainer
                      : colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
      if (!expands) {
        return content;
      }
      return Expanded(child: content);
    }

    return ClipRRect(
      borderRadius: radius,
      child: Container(
        padding: const EdgeInsets.all(AppSpace.xs),
        decoration: BoxDecoration(
          color: isLight
              ? AppColor.paperGlassTint
              : colors.surfaceContainer.withValues(alpha: 0.15),
          borderRadius: radius,
          border: isLight ? null : Border.all(color: colors.outline),
        ),
        child: Row(
          mainAxisSize: expands ? MainAxisSize.max : MainAxisSize.min,
          children: tabs.map(buildItem).toList(),
        ),
      ),
    );
  }
}

class PortraitSegmentTabItem<T> {
  const PortraitSegmentTabItem({
    required this.value,
    required this.label,
    required this.icon,
  });

  final T value;
  final String label;
  final IconData icon;
}
