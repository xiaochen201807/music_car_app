import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/carlife_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/portrait_segmented_tab.dart';
import '../../widgets/luxury_loading_indicator.dart';

class PortraitSettingsView extends StatelessWidget {
  const PortraitSettingsView({
    super.key,
    required this.themeMode,
    required this.preferredBitrate,
    required this.updateBusy,
    required this.carLifeStatus,
    required this.carLifeSyncing,
    required this.onThemeModeChanged,
    required this.onPreferredBitrateChanged,
    required this.onCheckUpdate,
    required this.onOpenDownloads,
    required this.onSyncCarLife,
    required this.onCopyDiagnostics,
  });

  final ThemeMode themeMode;
  final String preferredBitrate;
  final bool updateBusy;
  final CarLifeStatus carLifeStatus;
  final bool carLifeSyncing;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueChanged<String> onPreferredBitrateChanged;
  final VoidCallback onCheckUpdate;
  final VoidCallback onOpenDownloads;
  final VoidCallback onSyncCarLife;
  final VoidCallback onCopyDiagnostics;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.xl,
          AppSpace.lg,
          AppSpace.xl,
          140,
        ),
        children: <Widget>[
          _SettingsHeroHeader(
            updateBusy: updateBusy,
            onCheckUpdate: onCheckUpdate,
          ),
          const SizedBox(height: AppSpace.lg),
          _SettingsProfileCard(onCheckUpdate: onCheckUpdate, busy: updateBusy),
          const SizedBox(height: AppSpace.xl),
          _SettingsSection(
            title: '播放',
            subtitle: '默认音质会在搜索和歌单播放时优先使用',
            children: <Widget>[
              _buildQualityOption(
                context: context,
                value: '48kaac',
                title: '标准',
                subtitle: '低码率，弱网更稳',
                icon: Icons.network_check_rounded,
              ),
              _buildQualityOption(
                context: context,
                value: '128kmp3',
                title: '较高',
                subtitle: '日常播放均衡选择',
                icon: Icons.music_note_rounded,
              ),
              _buildQualityOption(
                context: context,
                value: '320kmp3',
                title: '极高',
                subtitle: '优先高品质音源',
                icon: Icons.high_quality_rounded,
              ),
              _buildQualityOption(
                context: context,
                value: 'flac',
                title: '无损',
                subtitle: '可用时尝试无损',
                icon: Icons.spatial_audio_off_rounded,
              ),
            ],
          ),
          const SizedBox(height: AppSpace.lg),
          _SettingsSection(
            title: '外观',
            subtitle: '界面跟随当前使用环境',
            framed: false,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
                child: PortraitSegmentedTab<ThemeMode>(
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
                  expands: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.lg),
          _SettingsSection(
            title: '存储',
            subtitle: '离线内容与缓存入口',
            children: <Widget>[
              _SettingsRow(
                icon: Icons.download_rounded,
                title: '存储与缓存管理',
                subtitle: '查看离线歌曲和缓存',
                onTap: onOpenDownloads,
              ),
            ],
          ),
          _SettingsSection(
            title: '应用',
            subtitle: '版本与远程发布',
            children: <Widget>[
              _SettingsRow(
                icon: Icons.system_update_rounded,
                title: updateBusy ? '正在检查更新' : '检查更新',
                subtitle: 'Android APK 由 GitHub Actions 发布',
                trailing: updateBusy
                    ? LuxuryLoadingIndicator(size: 14)
                    : const Icon(Icons.chevron_right_rounded),
                onTap: updateBusy ? null : onCheckUpdate,
              ),
              _SettingsRow(
                icon: Icons.bug_report_outlined,
                title: '复制诊断信息',
                subtitle: '最近播放、搜索、下载和性能事件',
                trailing: const Icon(Icons.copy_rounded),
                onTap: onCopyDiagnostics,
              ),
              _SettingsRow(
                icon: Icons.info_outline_rounded,
                title: 'Music Car',
                subtitle: '版本 1.0.78 · 车载音乐播放器',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQualityOption({
    required BuildContext context,
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final bool isLight = theme.brightness == Brightness.light;
    final bool isSelected = _qualityTier(preferredBitrate) == value;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.tile),
      onTap: () {
        HapticFeedback.selectionClick();
        onPreferredBitrateChanged(value);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.md,
          vertical: AppSpace.sm,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? isLight
                    ? colors.primaryContainer
                    : colors.primaryContainer.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.tile),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.control),
                color: isSelected
                    ? isLight
                          ? colors.primaryContainer
                          : colors.primary.withValues(alpha: 0.16)
                    : isLight
                    ? colors.surfaceContainer
                    : colors.surfaceContainerHighest.withValues(alpha: 0.3),
              ),
              child: Icon(
                icon,
                size: 20,
                color: isSelected ? colors.primary : colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: isSelected
                          ? FontWeight.w900
                          : FontWeight.w700,
                      color: isSelected ? colors.primary : colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: colors.primary, size: 20),
          ],
        ),
      ),
    );
  }

  String _qualityTier(String bitrate) {
    final String value = bitrate.toLowerCase();
    if (value.contains('flac') ||
        value.contains('lossless') ||
        value.contains('无损')) {
      return 'flac';
    }
    final int bitrateValue =
        int.tryParse(RegExp(r'\d+').firstMatch(value)?.group(0) ?? '') ?? 128;
    if (bitrateValue >= 192) {
      return '320kmp3';
    }
    if (bitrateValue >= 128) {
      return '128kmp3';
    }
    return '48kaac';
  }
}

class _SettingsProfileCard extends StatelessWidget {
  const _SettingsProfileCard({required this.onCheckUpdate, required this.busy});

  final VoidCallback onCheckUpdate;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final bool isLight = theme.brightness == Brightness.light;
    return GlassCard(
      radius: AppRadius.panel,
      padding: const EdgeInsets.all(AppSpace.lg),
      shadows: const <BoxShadow>[],
      child: Row(
        children: <Widget>[
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.tile),
              color: isLight
                  ? colors.primaryContainer
                  : colors.onSurface.withValues(alpha: 0.08),
            ),
            child: Icon(
              Icons.music_note_rounded,
              color: colors.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Music Car',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '车载音乐播放器',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: busy ? '检查中' : '检查更新',
            onPressed: busy
                ? null
                : () {
                    HapticFeedback.lightImpact();
                    onCheckUpdate();
                  },
            icon: busy
                ? LuxuryLoadingIndicator(size: 16)
                : const Icon(Icons.system_update_rounded),
          ),
        ],
      ),
    );
  }
}

class _SettingsHeroHeader extends StatelessWidget {
  const _SettingsHeroHeader({
    required this.updateBusy,
    required this.onCheckUpdate,
  });

  final bool updateBusy;
  final VoidCallback onCheckUpdate;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return GlassCard(
      radius: AppRadius.panel,
      padding: const EdgeInsets.all(AppSpace.lg),
      shadows: const <BoxShadow>[],
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '设置',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: AppSpace.xs),
                Text(
                  '播放偏好、离线缓存和版本更新',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          GlassPill(
            onTap: updateBusy
                ? null
                : () {
                    HapticFeedback.lightImpact();
                    onCheckUpdate();
                  },
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (updateBusy)
                  LuxuryLoadingIndicator(size: 14)
                else
                  Icon(
                    Icons.system_update_rounded,
                    size: 18,
                    color: colors.primary,
                  ),
                const SizedBox(width: AppSpace.xs),
                Text(
                  updateBusy ? '检查中' : '检查更新',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.children,
    this.subtitle,
    this.framed = true,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final bool framed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpace.sm),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (subtitle != null) ...<Widget>[
                      const SizedBox(height: AppSpace.xs),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        if (framed)
          GlassCard(
            radius: AppRadius.panel,
            padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
            shadows: const <BoxShadow>[],
            child: Column(children: children),
          )
        else
          Column(children: children),
      ],
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final bool isLight = theme.brightness == Brightness.light;
    final Widget row = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.md,
        vertical: AppSpace.sm,
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.control),
              color: isLight
                  ? colors.primaryContainer
                  : colors.primary.withValues(alpha: 0.12),
            ),
            child: Icon(icon, color: colors.primary, size: 20),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpace.sm),
            IconTheme(
              data: IconThemeData(color: colors.onSurfaceVariant, size: 20),
              child: trailing!,
            ),
          ],
        ],
      ),
    );

    if (onTap == null) {
      return row;
    }
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap!();
      },
      child: row,
    );
  }
}
