import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/carlife_service.dart';
import '../../theme/design_tokens.dart';
import '../../shared/portrait_surface.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/portrait_segmented_tab.dart';

class PortraitSettingsView extends StatelessWidget {
  const PortraitSettingsView({
    super.key,
    required this.themeMode,
    required this.carLifeStatus,
    required this.carLifeBusy,
    required this.updateBusy,
    required this.onThemeModeChanged,
    required this.onOpenCarLife,
    required this.onSyncCarLife,
    required this.onRefreshCarLife,
    required this.onCheckUpdate,
    required this.onOpenDownloads,
  });

  final ThemeMode themeMode;
  final CarLifeStatus carLifeStatus;
  final bool carLifeBusy;
  final bool updateBusy;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final VoidCallback onOpenCarLife;
  final VoidCallback onSyncCarLife;
  final VoidCallback onRefreshCarLife;
  final VoidCallback onCheckUpdate;
  final VoidCallback onOpenDownloads;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.xl,
          AppSpace.lg,
          AppSpace.xl,
          140,
        ),
        children: <Widget>[
          Text(
            '设置',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: AppSpace.xl),
          PortraitSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('主题模式', style: theme.textTheme.titleLarge),
                const SizedBox(height: AppSpace.md),
                PortraitSegmentedTab<ThemeMode>(
                  tabs: const <PortraitSegmentTabItem<ThemeMode>>[
                    PortraitSegmentTabItem<ThemeMode>(
                      value: ThemeMode.system,
                      label: '系统',
                      icon: Icons.brightness_auto_rounded,
                    ),
                    PortraitSegmentTabItem<ThemeMode>(
                      value: ThemeMode.light,
                      label: '白天',
                      icon: Icons.light_mode_rounded,
                    ),
                    PortraitSegmentTabItem<ThemeMode>(
                      value: ThemeMode.dark,
                      label: '黑夜',
                      icon: Icons.dark_mode_rounded,
                    ),
                  ],
                  selected: themeMode,
                  onSelected: onThemeModeChanged,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          PortraitSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('离线缓存', style: theme.textTheme.titleLarge),
                const SizedBox(height: AppSpace.sm),
                Text(
                  '播放层会保持优先缓存本地文件，未命中再走在线 URL，支持离线无网播放。',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpace.md),
                Align(
                  alignment: Alignment.centerLeft,
                  child: GlassPill(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onOpenDownloads();
                    },
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
                    child: Center(
                      widthFactor: 1.0,
                      heightFactor: 1.0,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(Icons.download_rounded, size: 18, color: colors.primary),
                          const SizedBox(width: AppSpace.xs),
                          Text(
                            '存储与缓存管理',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: colors.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          CarLifeCard(
            status: carLifeStatus,
            busy: carLifeBusy,
            onOpen: onOpenCarLife,
            onSync: onSyncCarLife,
            onRefresh: onRefreshCarLife,
          ),
          const SizedBox(height: AppSpace.lg),
          Align(
            alignment: Alignment.center,
            child: GlassPill(
              onTap: updateBusy
                  ? null
                  : () {
                      HapticFeedback.lightImpact();
                      onCheckUpdate();
                    },
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
              child: Center(
                widthFactor: 1.0,
                heightFactor: 1.0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.system_update_rounded,
                      size: 18,
                      color: updateBusy
                          ? colors.onSurface.withValues(alpha: 0.38)
                          : colors.primary,
                    ),
                    const SizedBox(width: AppSpace.xs),
                    Text(
                      updateBusy ? '检查中' : '检查更新',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: updateBusy
                            ? colors.onSurface.withValues(alpha: 0.38)
                            : colors.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CarLifeCard extends StatelessWidget {
  const CarLifeCard({
    super.key,
    required this.status,
    required this.busy,
    required this.onOpen,
    required this.onSync,
    required this.onRefresh,
  });

  final CarLifeStatus status;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onSync;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final Color carlifeColor = const Color(0xFF0056C6);

    return PortraitSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.tile),
                  color: carlifeColor.withValues(alpha: 0.16),
                ),
                child: Icon(
                  Icons.directions_car_filled_rounded,
                  color: carlifeColor,
                ),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Text(
                  '百度 CarLife',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          Text(
            status.displayText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            status.sdkLinked ? '可同步模板和控制。' : '可缓存当前队列，等待 SDK 接入。',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpace.md),
          Row(
            children: <Widget>[
              Expanded(
                child: GestureDetector(
                  onTap: busy
                      ? null
                      : () {
                          HapticFeedback.lightImpact();
                          onOpen();
                        },
                  child: GlassCard(
                    radius: AppRadius.tile,
                    height: 40,
                    shadows: const <BoxShadow>[],
                    child: Container(
                      decoration: BoxDecoration(
                        color: busy
                            ? Colors.transparent
                            : carlifeColor.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(AppRadius.tile),
                      ),
                      child: Center(
                        child: Text(
                          status.launchable ? '打开' : '安装',
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: busy
                                ? colors.onSurface.withValues(alpha: 0.38)
                                : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              GlassPill(
                onTap: busy
                    ? null
                    : () {
                        HapticFeedback.lightImpact();
                        onSync();
                      },
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
                child: Center(
                  widthFactor: 1.0,
                  heightFactor: 1.0,
                  child: Icon(
                    Icons.sync_rounded,
                    color: busy
                        ? colors.onSurface.withValues(alpha: 0.38)
                        : colors.primary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              GlassPill(
                onTap: busy
                    ? null
                    : () {
                        HapticFeedback.lightImpact();
                        onRefresh();
                      },
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
                child: Center(
                  widthFactor: 1.0,
                  heightFactor: 1.0,
                  child: Icon(
                    Icons.refresh_rounded,
                    color: busy
                        ? colors.onSurface.withValues(alpha: 0.38)
                        : colors.primary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
