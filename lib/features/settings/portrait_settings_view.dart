import 'package:flutter/material.dart';
import '../../services/carlife_service.dart';
import '../../theme/design_tokens.dart';
import '../../shared/portrait_surface.dart';

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
                SegmentedButton<ThemeMode>(
                  segments: const <ButtonSegment<ThemeMode>>[
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.system,
                      label: Text('系统'),
                      icon: Icon(Icons.brightness_auto_rounded),
                    ),
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.light,
                      label: Text('白天'),
                      icon: Icon(Icons.light_mode_rounded),
                    ),
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.dark,
                      label: Text('黑夜'),
                      icon: Icon(Icons.dark_mode_rounded),
                    ),
                  ],
                  selected: <ThemeMode>{themeMode},
                  onSelectionChanged: (Set<ThemeMode> modes) {
                    onThemeModeChanged(modes.single);
                  },
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
                FilledButton.tonalIcon(
                  onPressed: onOpenDownloads,
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('存储与缓存管理'),
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
          FilledButton.icon(
            onPressed: updateBusy ? null : onCheckUpdate,
            icon: const Icon(Icons.system_update_rounded),
            label: Text(updateBusy ? '检查中' : '检查更新'),
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
                child: FilledButton(
                  onPressed: busy ? null : onOpen,
                  style: FilledButton.styleFrom(
                    backgroundColor: carlifeColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.tile),
                    ),
                  ),
                  child: Text(status.launchable ? '打开' : '安装'),
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              IconButton.filledTonal(
                tooltip: '同步当前播放',
                onPressed: busy ? null : onSync,
                icon: const Icon(Icons.sync_rounded),
              ),
              const SizedBox(width: AppSpace.sm),
              IconButton.filledTonal(
                tooltip: '刷新连接',
                onPressed: busy ? null : onRefresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
