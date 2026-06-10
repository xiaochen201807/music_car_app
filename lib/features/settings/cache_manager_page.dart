import 'package:flutter/material.dart';
import '../../models/cached_track.dart';
import '../../services/download_service.dart';
import '../../theme/design_tokens.dart';
import '../../shared/portrait_surface.dart';
import '../../shared/portrait_artwork.dart';
import '../../models/demo_track.dart';

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
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder:
          (BuildContext context) => AlertDialog(
            title: const Text('清空缓存'),
            content: const Text('确定要清空所有已下载的离线歌曲吗？这无法撤销。'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('确定'),
              ),
            ],
          ),
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
        title: const Text('缓存与存储管理'),
        actions: <Widget>[
          if (_tracks.isNotEmpty)
            TextButton.icon(
              onPressed: _busy ? null : _clearAll,
              icon: const Icon(Icons.delete_sweep_rounded),
              label: const Text('清空'),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpace.xl),
              color: colors.surfaceContainerLowest,
              child: Column(
                children: <Widget>[
                  Text(
                    _formatSize(_totalSize),
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: colors.primary,
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
            Expanded(
              child:
                  _tracks.isEmpty
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
                            Text(
                              '暂无离线缓存',
                              style: theme.textTheme.titleMedium,
                            ),
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
                      : ListView.separated(
                        padding: const EdgeInsets.all(AppSpace.xl),
                        itemCount: _tracks.length,
                        separatorBuilder:
                            (_, _) => const SizedBox(height: AppSpace.md),
                        itemBuilder: (BuildContext context, int index) {
                          final CachedTrack track = _tracks[index];
                          return PortraitSurface(
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
                                  onPressed:
                                      _busy ? null : () => _delete(track),
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
          ],
        ),
      ),
    );
  }
}
