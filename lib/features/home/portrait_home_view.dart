import 'package:flutter/material.dart';
import '../../free_music_api.dart';
import '../../models/demo_track.dart';
import '../../theme/design_tokens.dart';
import '../../utils/formatters.dart';
import '../../shared/portrait_artwork.dart';
import '../../shared/portrait_chip.dart';
import '../../shared/portrait_circle_button.dart';

import '../../shared/portrait_message_card.dart';
import '../../shared/portrait_section_header.dart';
import '../../shared/portrait_surface.dart';
import '../../shared/staggered_animated_item.dart';
import '../../widgets/glass_card.dart';

class PortraitHomeView extends StatefulWidget {
  const PortraitHomeView({
    super.key,
    required this.controller,
    required this.recommendedPlaylists,
    required this.recommendationsBusy,
    required this.recommendationError,
    required this.playlistSongsBusy,
    required this.queueSongs,
    required this.searchResults,
    required this.hotSearchKeywords,
    required this.musicSources,
    required this.sourceBusy,
    required this.sourceError,
    required this.onSearch,
    required this.onHotKeyword,
    required this.onSelectPlaylist,
  });

  final TextEditingController controller;
  final List<FreeMusicPlaylist> recommendedPlaylists;
  final bool recommendationsBusy;
  final String recommendationError;
  final bool playlistSongsBusy;
  final List<FreeMusicSong> queueSongs;
  final List<FreeMusicSong> searchResults;
  final List<String> hotSearchKeywords;
  final FreeMusicSources? musicSources;
  final bool sourceBusy;
  final String sourceError;
  final VoidCallback onSearch;
  final ValueChanged<String> onHotKeyword;
  final ValueChanged<FreeMusicPlaylist> onSelectPlaylist;

  @override
  State<PortraitHomeView> createState() => _PortraitHomeViewState();
}

class _PortraitHomeViewState extends State<PortraitHomeView> {
  List<String>? _history;

  @override
  void didUpdateWidget(covariant PortraitHomeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _history ??= <String>[];
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<FreeMusicSong> timelineSongs = widget.queueSongs.isNotEmpty
        ? widget.queueSongs.take(5).toList(growable: false)
        : widget.searchResults.take(5).toList(growable: false);

    _history ??= <String>[];

    return SafeArea(
      child: CustomScrollView(
        slivers: <Widget>[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.xl,
              AppSpace.lg,
              AppSpace.xl,
              118,
            ),
            sliver: SliverList.list(
              children: <Widget>[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Music Car',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.xl),
                PortraitSearchHero(
                  controller: widget.controller,
                  onSearch: _runSearch,
                ),
                if (_history != null && _history!.isNotEmpty) ...[
                  const SizedBox(height: AppSpace.md),
                  SizedBox(
                    height: 38,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _history!.length + 1,
                      itemBuilder: (BuildContext context, int index) {
                        if (index == _history!.length) {
                          return Padding(
                            padding: const EdgeInsets.only(left: AppSpace.xs),
                            child: IconButton(
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  _history!.clear();
                                });
                              },
                              tooltip: '清空历史',
                            ),
                          );
                        }
                        final String keyword = _history![index];
                        return Padding(
                          padding: const EdgeInsets.only(right: AppSpace.sm),
                          child: GestureDetector(
                            onLongPress: () {
                              setState(() {
                                _history!.removeAt(index);
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('已删除历史: $keyword'),
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                            },
                            child: PortraitChip(
                              label: keyword,
                              onTap: () => _useHistory(keyword),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: AppSpace.xl2),
                PortraitSectionHeader(
                  title: '推荐歌单',
                  label: widget.recommendationsBusy || widget.playlistSongsBusy
                      ? '同步中'
                      : null,
                ),
                const SizedBox(height: AppSpace.md),
                if (widget.recommendationError.isNotEmpty &&
                    widget.recommendedPlaylists.isEmpty)
                  PortraitMessageCard(
                    icon: Icons.cloud_off_rounded,
                    title: '推荐加载失败',
                    message: widget.recommendationError,
                  )
                else
                  PortraitPlaylistGrid(
                    playlists: widget.recommendedPlaylists,
                    busy: widget.playlistSongsBusy,
                    onSelect: widget.onSelectPlaylist,
                  ),
                const SizedBox(height: AppSpace.xl2),
                PortraitSectionHeader(
                  title: '播放时间线',
                  label: timelineSongs.isEmpty ? '待生成' : null,
                ),
                const SizedBox(height: AppSpace.md),
                if (timelineSongs.isEmpty)
                  const PortraitMessageCard(
                    icon: Icons.timeline_rounded,
                    title: '暂无播放时间线',
                    message: '搜索并播放歌曲后，这里会显示最近队列。',
                  )
                else
                  for (int index = 0; index < timelineSongs.length; index += 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.sm),
                      child: StaggeredAnimatedItem(
                        index: index,
                        child: PortraitTimelineTile(
                          song: timelineSongs[index],
                          index: index,
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _runSearch() {
    final String keyword = widget.controller.text.trim();
    if (keyword.isNotEmpty) {
      _addHistory(keyword);
    }
    widget.onSearch();
  }

  void _useHistory(String keyword) {
    widget.controller.text = keyword;
    widget.controller.selection = TextSelection.collapsed(
      offset: widget.controller.text.length,
    );
    widget.onHotKeyword(keyword);
  }

  void _addHistory(String keyword) {
    setState(() {
      _history ??= <String>[];
      _history!
        ..removeWhere((String item) => item == keyword)
        ..insert(0, keyword);
      if (_history!.length > 8) {
        _history!.removeRange(8, _history!.length);
      }
    });
  }
}

class PortraitSearchHero extends StatefulWidget {
  const PortraitSearchHero({
    super.key,
    required this.controller,
    required this.onSearch,
  });

  final TextEditingController controller;
  final VoidCallback onSearch;

  @override
  State<PortraitSearchHero> createState() => _PortraitSearchHeroState();
}

class _PortraitSearchHeroState extends State<PortraitSearchHero> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.panel),
        boxShadow: _isFocused
            ? <BoxShadow>[
                BoxShadow(
                  color: colors.primary.withValues(alpha: 0.08),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ]
            : const <BoxShadow>[],
      ),
      child: GlassCard(
        radius: AppRadius.panel,
        shadows: const <BoxShadow>[],
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.panel),
            border: Border.all(
              color: _isFocused
                  ? colors.primary.withValues(alpha: 0.45)
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.md,
            vertical: AppSpace.xs,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => widget.onSearch(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: _isFocused
                          ? colors.primary
                          : colors.onSurfaceVariant,
                    ),
                    hintText: '搜索歌曲、歌手或专辑',
                    hintStyle: TextStyle(
                      color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              BounceTouchable(
                onTap: widget.onSearch,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.lg,
                    vertical: AppSpace.sm,
                  ),
                  decoration: BoxDecoration(
                    color: _isFocused
                        ? colors.primary.withValues(alpha: 0.15)
                        : colors.onSurface.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                      color: _isFocused
                          ? colors.primary.withValues(alpha: 0.25)
                          : Colors.white.withValues(alpha: 0.05),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '搜索',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: _isFocused ? colors.primary : colors.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PortraitPlaylistGrid extends StatelessWidget {
  const PortraitPlaylistGrid({
    super.key,
    required this.playlists,
    required this.busy,
    required this.onSelect,
  });

  final List<FreeMusicPlaylist> playlists;
  final bool busy;
  final ValueChanged<FreeMusicPlaylist> onSelect;

  @override
  Widget build(BuildContext context) {
    final List<FreeMusicPlaylist> visible = playlists.take(6).toList();
    if (visible.isEmpty) {
      return const PortraitFallbackGrid();
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: visible.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppSpace.md,
        mainAxisSpacing: AppSpace.md,
        childAspectRatio: 0.88,
      ),
      itemBuilder: (BuildContext context, int index) {
        return StaggeredAnimatedItem(
          index: index,
          child: PortraitPlaylistCard(
            playlist: visible[index],
            visual: demoQueue[index % demoQueue.length],
            onTap: busy ? null : () => onSelect(visible[index]),
          ),
        );
      },
    );
  }
}

class PortraitPlaylistCard extends StatelessWidget {
  const PortraitPlaylistCard({
    super.key,
    required this.playlist,
    required this.visual,
    required this.onTap,
  });

  final FreeMusicPlaylist playlist;
  final DemoTrack visual;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.card),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.card),
              child: PortraitArtwork(
                visual: visual,
                imageUrl: playlist.cover,
                icon: Icons.queue_music_rounded,
              ),
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            playlist.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class PortraitFallbackGrid extends StatelessWidget {
  const PortraitFallbackGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppSpace.md,
        mainAxisSpacing: AppSpace.md,
        childAspectRatio: 0.82,
      ),
      itemBuilder: (BuildContext context, int index) {
        final DemoTrack track = demoQueue[index % demoQueue.length];
        return StaggeredAnimatedItem(
          index: index,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: PortraitArtwork(
                  visual: track,
                  imageUrl: '',
                  icon: Icons.album_rounded,
                ),
              ),
              const SizedBox(height: AppSpace.sm),
              Text(track.title, style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
        );
      },
    );
  }
}

class PortraitTimelineTile extends StatelessWidget {
  const PortraitTimelineTile({
    super.key,
    required this.song,
    required this.index,
  });

  final FreeMusicSong song;
  final int index;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return Row(
      children: <Widget>[
        SizedBox(
          width: AppSpace.xl3,
          child: Column(
            children: <Widget>[
              Container(
                width: AppSpace.sm,
                height: AppSpace.sm,
                decoration: BoxDecoration(
                  color: colors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(height: AppSpace.xs),
              Container(
                width: 2,
                height: AppSpace.xl3,
                color: colors.outlineVariant,
              ),
            ],
          ),
        ),
        Expanded(
          child: PortraitSurface(
            child: Row(
              children: <Widget>[
                PortraitArtwork(
                  visual: demoQueue[index % demoQueue.length],
                  imageUrl: song.cover,
                  size: 52,
                  icon: Icons.music_note_rounded,
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        song.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppSpace.xs),
                      Text(
                        song.artist.isEmpty ? song.source : song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  formatDuration(Duration(seconds: song.duration)),
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
