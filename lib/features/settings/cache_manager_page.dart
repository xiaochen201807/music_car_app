import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/cached_track.dart';
import '../../services/download_service.dart';
import '../../theme/design_tokens.dart';
import '../../shared/portrait_artwork.dart';
import '../../models/demo_track.dart';
import '../../widgets/glass_card.dart';

class CacheManagerPage extends StatefulWidget {
  const CacheManagerPage({super.key, required this.downloadService});

  final DownloadService downloadService;

  @override
  State<CacheManagerPage> createState() => _CacheManagerPageState();
}

class _CacheManagerPageState extends State<CacheManagerPage> {
  List<CachedTrack> _tracks = <CachedTrack>[];
  int _totalSize = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _tracks = widget.downloadService.getAllCachedTracks();
      _totalSize = _tracks.fold(
        0,
        (int sum, CachedTrack t) => sum + t.fileSize,
      );
    });
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const List<String> suffixes = <String>['B', 'KB', 'MB', 'GB'];
    int i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }

  Future<void> _delete(CachedTrack track) async {
    setState(() {
      _busy = true;
    });
    await widget.downloadService.deleteTrack(track.source, track.id);
    _refresh();
    setState(() {
      _busy = false;
    });
  }

  Future<void> _clearAll() async {
    final bool? confirm = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder:
          (BuildContext ctx, Animation<double> anim1, Animation<double> anim2) {
            final ThemeData theme = Theme.of(context);
            final ColorScheme colors = theme.colorScheme;
            return Center(
              child: Material(
                color: Colors.transparent,
                child: GlassCard(
                  width: 320,
                  padding: const EdgeInsets.all(AppSpace.xl),
                  radius: AppRadius.card,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Icon(
                            Icons.warning_amber_rounded,
                            color: colors.error,
                            size: 24,
                          ),
                          const SizedBox(width: AppSpace.sm),
                          Text(
                            '清空缓存',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpace.md),
                      Text(
                        '确定要清空所有已下载的离线歌曲吗？这无法撤销。',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpace.xl),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: <Widget>[
                          GlassPill(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              Navigator.of(ctx).pop(false);
                            },
                            height: AppSpace.xl3 + AppSpace.xs,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpace.md,
                            ),
                            child: Text(
                              '取消',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpace.sm),
                          GlassPill(
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              Navigator.of(ctx).pop(true);
                            },
                            height: AppSpace.xl3 + AppSpace.xs,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpace.md,
                            ),
                            child: Center(
                              widthFactor: 1.0,
                              heightFactor: 1.0,
                              child: Text(
                                '确定清空',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: colors.error,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1.0).animate(
              CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        );
      },
    );
    if (confirm != true) return;

    setState(() {
      _busy = true;
    });
    await widget.downloadService.clearAll();
    _refresh();
    setState(() {
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('缓存与存储管理'),
        // Offline downloads only; streaming/lyrics caches auto-prune.
        actions: <Widget>[
          if (_tracks.isNotEmpty)
            TextButton.icon(
              onPressed: _busy
                  ? null
                  : () {
                      HapticFeedback.mediumImpact();
                      _clearAll();
                    },
              icon: const Icon(Icons.delete_sweep_rounded),
              label: const Text('清空'),
            ),
        ],
      ),
      body: SafeArea(
        child: _tracks.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      Icons.cloud_done_rounded,
                      size: 48,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(height: AppSpace.md),
                    Text('暂无离线下载', style: theme.textTheme.titleMedium),
                    const SizedBox(height: AppSpace.xs),
                    Text(
                      '在播放页或歌单中下载歌曲后，将可以在这里查看和管理。',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              )
            : SingleChildScrollView(
                child: Column(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.xl,
                        vertical: AppSpace.md,
                      ),
                      child: GlassCard(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpace.xl),
                        radius: AppRadius.card,
                        child: Column(
                          children: <Widget>[
                            Text(
                              _formatSize(_totalSize),
                              style: theme.textTheme.headlineLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: colors.onSurface,
                                shadows: <Shadow>[
                                  Shadow(
                                    color: colors.primary.withValues(
                                      alpha: 0.35,
                                    ),
                                    offset: const Offset(0, 2),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSpace.xs),
                            Text(
                              '已缓存 ${_tracks.length} 首歌曲',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colors.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.xl,
                      ),
                      child: GlassCard(
                        radius: AppRadius.card,
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(AppSpace.md),
                          itemCount: _tracks.length,
                          separatorBuilder: (_, _) => Divider(
                            color: AppColor.strokeHairline,
                            height: 1,
                          ),
                          itemBuilder: (BuildContext context, int index) {
                            final CachedTrack track = _tracks[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpace.sm,
                              ),
                              child: Row(
                                children: <Widget>[
                                  PortraitArtwork(
                                    visual: demoQueue[index % demoQueue.length],
                                    imageUrl: track.cover,
                                    size: 48,
                                    icon: Icons.music_note_rounded,
                                  ),
                                  const SizedBox(width: AppSpace.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          track.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w900,
                                              ),
                                        ),
                                        const SizedBox(height: AppSpace.xs),
                                        Text(
                                          '${track.artist} · ${_formatSize(track.fileSize)}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: colors.onSurfaceVariant,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: '删除此缓存',
                                    onPressed: _busy
                                        ? null
                                        : () {
                                            HapticFeedback.mediumImpact();
                                            _delete(track);
                                          },
                                    icon: Icon(
                                      Icons.delete_outline_rounded,
                                      color: colors.error,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 140),
                  ],
                ),
              ),
      ),
    );
  }
}
