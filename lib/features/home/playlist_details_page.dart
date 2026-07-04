import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../favorite_song_store.dart';
import '../../free_music_api.dart';
import '../../models/demo_track.dart';
import '../../theme/design_tokens.dart';
import '../../utils/formatters.dart';
import '../../shared/portrait_artwork.dart';
import '../../shared/portrait_surface.dart';
import '../../shared/staggered_animated_item.dart';
import '../../widgets/glass_card.dart';

class PlaylistDetailsPage extends StatefulWidget {
  const PlaylistDetailsPage({
    super.key,
    required this.playlist,
    required this.api,
    required this.favoriteSongKeys,
    required this.downloadedSongKeys,
    required this.onPlay,
    required this.onToggleFavorite,
    required this.onDownload,
    required this.onDeleteCache,
  });

  final FreeMusicPlaylist playlist;
  final FreeMusicApi api;
  final Set<String> favoriteSongKeys;
  final Set<String> downloadedSongKeys;
  final Function(List<FreeMusicSong> songs, int index, {bool append}) onPlay;
  final ValueChanged<FreeMusicSong> onToggleFavorite;
  final ValueChanged<FreeMusicSong> onDownload;
  final ValueChanged<FreeMusicSong> onDeleteCache;

  @override
  State<PlaylistDetailsPage> createState() => _PlaylistDetailsPageState();
}

class _PlaylistDetailsPageState extends State<PlaylistDetailsPage> {
  final List<FreeMusicSong> _songs = <FreeMusicSong>[];
  bool _busy = false;
  String _error = '';
  int _total = 0;
  int _offset = 0;

  @override
  void initState() {
    super.initState();
    _loadSongs(reset: true);
  }

  Future<void> _loadSongs({required bool reset}) async {
    if (_busy) return;
    final int targetOffset = reset ? 0 : _offset;
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final FreeMusicPlaylistPage page = await widget.api.fetchPlaylistSongs(
        widget.playlist,
        offset: targetOffset,
        size: 30,
      );
      if (!mounted) return;
      setState(() {
        if (reset) {
          _songs.clear();
        }
        _songs.addAll(page.songs);
        _total = page.total;
        _offset = _songs.length;
        _busy = false;
        if (page.songs.isEmpty && reset) {
          _error = '歌单暂无可播放歌曲';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '加载失败：$e';
      });
    }
  }

  void _showPlayOptions() {
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.play_arrow_rounded),
                title: const Text('播放'),
                subtitle: const Text('替换当前播放队列'),
                onTap: () {
                  Navigator.pop(context);
                  widget.onPlay(_songs, 0, append: false);
                },
              ),
              ListTile(
                leading: const Icon(Icons.playlist_add_rounded),
                title: const Text('追加到队列'),
                subtitle: const Text('添加到播放队列末尾'),
                onTap: () {
                  Navigator.pop(context);
                  widget.onPlay(_songs, 0, append: true);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Scaffold(
      body: Stack(
        children: <Widget>[
          // 封面高斯模糊背景
          if (widget.playlist.cover.isNotEmpty)
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: CachedNetworkImageProvider(widget.playlist.cover),
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(
                        colors.surface.withValues(alpha: 0.76),
                        BlendMode.darken,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          // 渐变过渡遮罩
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    colors.surface.withValues(alpha: 0.12),
                    colors.surface.withValues(alpha: 0.78),
                    colors.surface,
                  ],
                  stops: const <double>[0, 0.48, 1],
                ),
              ),
            ),
          ),
          // 滚动内容
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: <Widget>[
              SliverAppBar(
                expandedHeight: 280,
                pinned: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const <StretchMode>[
                    StretchMode.zoomBackground,
                    StretchMode.blurBackground,
                  ],
                  background: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.xl,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          const SizedBox(height: 36),
                          Hero(
                            tag: 'playlist_cover_${widget.playlist.id}',
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(
                                AppRadius.card,
                              ),
                              child: PortraitArtwork(
                                visual: demoQueue.first,
                                imageUrl: widget.playlist.cover,
                                size: 128,
                                icon: Icons.queue_music_rounded,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpace.md),
                          Text(
                            widget.playlist.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: AppSpace.xs),
                          Text(
                            <String>[
                              if (widget.playlist.creator.isNotEmpty)
                                widget.playlist.creator,
                              widget.playlist.source,
                              '${_songs.length}/${_total == 0 ? '?' : _total} 首',
                            ].join(' · '),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // 播放操作栏
              if (_songs.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.xl,
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: GlassPill(
                            onTap: _songs.isEmpty ? null : _showPlayOptions,
                            height: AppSpace.xl4,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpace.md,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Icon(
                                  Icons.play_arrow_rounded,
                                  color: colors.primary,
                                ),
                                const SizedBox(width: AppSpace.xs),
                                Text(
                                  '播放全部',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpace.md)),
              // 歌曲列表或异常占位
              if (_songs.isEmpty && _busy)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_songs.isEmpty && _error.isNotEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        const Icon(Icons.error_outline_rounded, size: 48),
                        const SizedBox(height: AppSpace.md),
                        Text(_error, style: theme.textTheme.titleMedium),
                        const SizedBox(height: AppSpace.md),
                        GlassPill(
                          onTap: () => _loadSongs(reset: true),
                          height: AppSpace.xl4,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpace.xl,
                          ),
                          child: Text(
                            '重试',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                // 禁用列表项的 BackdropFilter 以降低 GPU 渲染压力
                GlassPerformanceMode(
                  enabled: true,
                  child: SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpace.xl,
                      0,
                      AppSpace.xl,
                      120,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((
                        BuildContext context,
                        int index,
                      ) {
                        if (index == _songs.length) {
                          final bool canLoadMore =
                              _total == 0 || _songs.length < _total;
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpace.md,
                            ),
                            child: Center(
                              child: TextButton.icon(
                                onPressed: canLoadMore && !_busy
                                    ? () => _loadSongs(reset: false)
                                    : null,
                                icon: _busy
                                    ? const SizedBox.square(
                                        dimension: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.expand_more_rounded),
                                label: Text(
                                  _busy
                                      ? '加载中'
                                      : canLoadMore
                                      ? '加载更多'
                                      : '已加载全部',
                                ),
                              ),
                            ),
                          );
                        }
                        final FreeMusicSong song = _songs[index];
                        final Widget songRow = PlaylistSongRow(
                          song: song,
                          visual: demoQueue[index % demoQueue.length],
                          index: index,
                          favorite: widget.favoriteSongKeys.contains(
                            favoriteSongKey(song),
                          ),
                          downloaded: widget.downloadedSongKeys.contains(
                            '${song.source}_${song.id}',
                          ),
                          onTap: () => widget.onPlay(_songs, index),
                          onToggleFavorite: () {
                            widget.onToggleFavorite(song);
                            setState(() {});
                          },
                          onDownload: () => widget.onDownload(song),
                          onDeleteCache: () => widget.onDeleteCache(song),
                        );
                        // 仅前 6 项启用入场动画，后续项直接显示避免大量 AnimationController 开销
                        return index < 6
                            ? StaggeredAnimatedItem(
                                index: index,
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: AppSpace.sm,
                                  ),
                                  child: songRow,
                                ),
                              )
                            : Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpace.sm,
                                ),
                                child: songRow,
                              );
                      }, childCount: _songs.length + 1),
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

class PlaylistSongRow extends StatelessWidget {
  const PlaylistSongRow({
    super.key,
    required this.song,
    required this.visual,
    required this.index,
    required this.favorite,
    required this.downloaded,
    required this.onTap,
    required this.onToggleFavorite,
    this.onDownload,
    this.onDeleteCache,
  });

  final FreeMusicSong song;
  final DemoTrack visual;
  final int index;
  final bool favorite;
  final bool downloaded;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;
  final VoidCallback? onDownload;
  final VoidCallback? onDeleteCache;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.card),
      onTap: onTap,
      child: PortraitSurface(
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 28,
              child: Text(
                '${index + 1}',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: AppSpace.xs),
            PortraitArtwork(
              visual: visual,
              imageUrl: song.cover,
              size: 48,
              icon: Icons.album_rounded,
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      if (downloaded)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Icon(
                            Icons.check_circle_rounded,
                            size: 14,
                            color: colors.primary,
                          ),
                        ),
                      Expanded(
                        child: Text(
                          song.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    <String>[
                      song.artist,
                      if (song.album.isNotEmpty) song.album,
                    ].where((String val) => val.isNotEmpty).join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: favorite ? '取消收藏' : '收藏',
              onPressed: onToggleFavorite,
              icon: Icon(
                favorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: favorite ? colors.primary : colors.onSurfaceVariant,
              ),
            ),
            Text(
              formatDuration(Duration(seconds: song.duration)),
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            if (onDownload != null || onDeleteCache != null)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (String value) {
                  if (value == 'download') {
                    onDownload?.call();
                  } else if (value == 'delete_cache') {
                    onDeleteCache?.call();
                  }
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  if (onDownload != null && !downloaded)
                    const PopupMenuItem<String>(
                      value: 'download',
                      child: Row(
                        children: <Widget>[
                          Icon(Icons.download_rounded),
                          SizedBox(width: AppSpace.sm),
                          Text('下载到本地'),
                        ],
                      ),
                    ),
                  if (onDeleteCache != null && downloaded)
                    const PopupMenuItem<String>(
                      value: 'delete_cache',
                      child: Row(
                        children: <Widget>[
                          Icon(Icons.delete_outline_rounded, color: Colors.red),
                          SizedBox(width: AppSpace.sm),
                          Text('删除缓存', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
