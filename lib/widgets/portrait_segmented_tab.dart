import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/design_tokens.dart';
import 'glass_card.dart';

class PortraitSegmentedTab<T> extends StatelessWidget {
  const PortraitSegmentedTab({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onSelected,
  });

  final List<PortraitSegmentTabItem<T>> tabs;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return GlassCard(
      radius: AppRadius.control,
      shadows: const <BoxShadow>[],
      child: Container(
        padding: const EdgeInsets.all(AppSpace.xs),
        decoration: BoxDecoration(
          color: colors.surfaceContainer.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppRadius.control),
          border: Border.all(
            color: AppColor.strokeHairline,
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: tabs.map((PortraitSegmentTabItem<T> item) {
            final bool isSelected = item.value == selected;
            return GestureDetector(
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
                decoration: BoxDecoration(
                  color: isSelected
                      ? colors.primaryContainer.withValues(alpha: 0.65)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.control - 2),
                  border: Border.all(
                    color: isSelected
                        ? colors.primary.withValues(alpha: 0.4)
                        : Colors.transparent,
                    width: 1,
                  ),
                  boxShadow: isSelected
                      ? <BoxShadow>[
                          BoxShadow(
                            color: colors.primary.withValues(alpha: 0.15),
                            offset: const Offset(0, 2),
                            blurRadius: 8,
                          )
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
          }).toList(),
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
