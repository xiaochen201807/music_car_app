import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/carlife_service.dart';
import '../../theme/design_tokens.dart';
import '../../shared/portrait_surface.dart';
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
                  expands: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          PortraitSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('默认音质', style: theme.textTheme.titleLarge),
                const SizedBox(height: AppSpace.md),
                _buildQualityOption(
                  context: context,
                  value: '48kaac',
                  title: '标准',
                  subtitle: '较低码率，保证播放与传输极致流畅',
                  icon: Icons.network_check_rounded,
                ),
                const SizedBox(height: AppSpace.xs),
                _buildQualityOption(
                  context: context,
                  value: '128kmp3',
                  title: '较高',
                  subtitle: '高清压缩，细节饱满的经典均衡听感',
                  icon: Icons.music_note_rounded,
                ),
                const SizedBox(height: AppSpace.xs),
                _buildQualityOption(
                  context: context,
                  value: '320kmp3',
                  title: '极高',
                  subtitle: '极高品质，清晰呈现原声音轨的所有细节',
                  icon: Icons.high_quality_rounded,
                ),
                const SizedBox(height: AppSpace.xs),
                _buildQualityOption(
                  context: context,
                  value: 'flac',
                  title: '无损',
                  subtitle: '母带级音质，智能座舱极致纯净震撼声场',
                  icon: Icons.spatial_audio_off_rounded,
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.md,
                    ),
                    child: Center(
                      widthFactor: 1.0,
                      heightFactor: 1.0,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          Padding(
                            padding: const EdgeInsets.only(top: 1.0),
                            child: Icon(
                              Icons.download_rounded,
                              size: 18,
                              color: colors.primary,
                            ),
                          ),
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
          PortraitSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('百度 CarLife 车机同步', style: theme.textTheme.titleLarge),
                const SizedBox(height: AppSpace.sm),
                Text(
                  '支持将歌名、歌手名、播放进度与当前队列同步至车机，让出行播放更加无缝智能。',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: AppSpace.md),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Icon(
                                carLifeStatus.available
                                    ? Icons.link_rounded
                                    : Icons.link_off_rounded,
                                size: 16,
                                color: carLifeStatus.available
                                    ? Colors.green
                                    : colors.onSurfaceVariant,
                              ),
                              const SizedBox(width: AppSpace.xs),
                              Text(
                                carLifeStatus.available ? '连接状态：已连接车机' : '连接状态：未连接',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: carLifeStatus.available
                                      ? Colors.green
                                      : colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpace.xs),
                          Text(
                            '状态详情：${carLifeStatus.reason}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpace.md),
                    GlassPill(
                      onTap: carLifeSyncing
                          ? null
                          : () {
                              HapticFeedback.lightImpact();
                              onSyncCarLife();
                            },
                      height: 38,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.md,
                      ),
                      child: Center(
                        widthFactor: 1.0,
                        heightFactor: 1.0,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: <Widget>[
                            if (carLifeSyncing)
                              LuxuryLoadingIndicator(size: 14)
                            else
                              Icon(
                                Icons.sync_rounded,
                                size: 18,
                                color: colors.primary,
                              ),
                            const SizedBox(width: AppSpace.xs),
                            Text(
                              carLifeSyncing ? '同步中' : '手动同步',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: colors.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          PortraitSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('关于', style: theme.textTheme.titleLarge),
                const SizedBox(height: AppSpace.md),
                Row(
                  children: <Widget>[
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.tile),
                        gradient: AppColor.accentGradient,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.music_note_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Music Car 车载系统',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '版本 1.0.0 (Build 20260610)',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.md),
                Text(
                  '千万级智能车载座舱专属音频系统，为您带来极致物理触感交互与震撼纯净音质体验。',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: AppSpace.sm),
                Text(
                  '© 2026 Music Car Team. 保留所有权利。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          GlassCard(
            height: 46,
            radius: AppRadius.pill,
            padding: EdgeInsets.zero,
            shadows: const <BoxShadow>[],
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              onTap: updateBusy
                  ? null
                  : () {
                      HapticFeedback.lightImpact();
                      onCheckUpdate();
                    },
              child: Center(
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

  Widget _buildQualityOption({
    required BuildContext context,
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
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
              ? colors.primaryContainer.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.tile),
          border: Border.all(
            color: isSelected
                ? colors.primary.withValues(alpha: 0.3)
                : Colors.transparent,
            width: 1.0,
          ),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.control),
                color: isSelected
                    ? colors.primary.withValues(alpha: 0.16)
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
