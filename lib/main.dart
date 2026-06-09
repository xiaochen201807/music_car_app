import 'dart:async';
import 'dart:math' as math;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'music_audio_handler.dart';
import 'models/app_update_info.dart';
import 'native_audio_controller.dart';
import 'services/app_installer_service.dart';
import 'services/carlife_service.dart';
import 'services/update_check_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await WakelockPlus.enable();

  final MusicAudioHandler audioHandler = await initMusicAudioHandler();

  runApp(MusicCarApp(audioHandler: audioHandler));
}

class MusicCarApp extends StatelessWidget {
  const MusicCarApp({
    super.key,
    this.homeOverride,
    this.audioHandler,
    this.autoCheckForUpdates = true,
  });

  final Widget? homeOverride;
  final MusicAudioHandler? audioHandler;
  final bool autoCheckForUpdates;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '车载音乐',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'sans',
        colorScheme: const ColorScheme.dark(
          primary: _AppColors.primary,
          secondary: _AppColors.accent,
          surface: _AppColors.surface,
          error: _AppColors.error,
        ),
        scaffoldBackgroundColor: _AppColors.background,
        splashFactory: NoSplash.splashFactory,
        useMaterial3: true,
      ),
      home:
          homeOverride ??
          NativeMusicHomePage(
            audioHandler: audioHandler,
            autoCheckForUpdates: autoCheckForUpdates,
          ),
    );
  }
}

class NativeMusicHomePage extends StatefulWidget {
  const NativeMusicHomePage({
    super.key,
    this.audioHandler,
    this.autoCheckForUpdates = true,
  });

  final MusicAudioHandler? audioHandler;
  final bool autoCheckForUpdates;

  @override
  State<NativeMusicHomePage> createState() => _NativeMusicHomePageState();
}

class _NativeMusicHomePageState extends State<NativeMusicHomePage>
    with WidgetsBindingObserver {
  late final NativeAudioController _nativeAudioController;
  final UpdateCheckService _updateCheckService = UpdateCheckService();
  final AppInstallerService _appInstallerService = const AppInstallerService();
  final CarLifeService _carLifeService = const CarLifeService();
  CarLifeStatus _carLifeStatus = const CarLifeStatus(
    available: false,
    installed: false,
    launchable: false,
    sdkLinked: false,
    reason: 'unchecked',
  );
  bool _isCheckingUpdate = false;
  bool _isInstallingUpdate = false;
  bool _isCheckingCarLife = false;
  bool _hasAutoCheckedUpdate = false;
  int _selectedTab = 0;
  int _selectedQueueIndex = 0;

  @override
  void initState() {
    super.initState();
    _nativeAudioController = NativeAudioController(player: widget.audioHandler);
    widget.audioHandler?.onPlayTrack = _resumeNativePlayback;
    widget.audioHandler?.onSkipToNextTrack = _skipToNextTrack;
    widget.audioHandler?.onSkipToPreviousTrack = _skipToPreviousTrack;
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_refreshCarLifeStatus());
      if (widget.autoCheckForUpdates) {
        unawaited(_autoCheckForUpdate());
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.audioHandler?.onSkipToNextTrack == _skipToNextTrack) {
      widget.audioHandler?.onSkipToNextTrack = null;
    }
    if (widget.audioHandler?.onSkipToPreviousTrack == _skipToPreviousTrack) {
      widget.audioHandler?.onSkipToPreviousTrack = null;
    }
    if (widget.audioHandler?.onPlayTrack == _resumeNativePlayback) {
      widget.audioHandler?.onPlayTrack = null;
    }
    unawaited(WakelockPlus.disable());
    unawaited(_nativeAudioController.dispose());
    _updateCheckService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(WakelockPlus.enable());
      unawaited(
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
      );
    }
  }

  Future<bool> _resumeNativePlayback() {
    return _nativeAudioController.resumePlayback();
  }

  Future<void> _skipToNextTrack() async {
    await _nativeAudioController.skipToNext();
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedQueueIndex = math.min(
        _selectedQueueIndex + 1,
        _demoQueue.length - 1,
      );
    });
  }

  Future<void> _skipToPreviousTrack() async {
    await _nativeAudioController.skipToPrevious();
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedQueueIndex = math.max(_selectedQueueIndex - 1, 0);
    });
  }

  Future<void> _togglePlayback(bool playing) async {
    final MusicAudioHandler? handler = widget.audioHandler;
    if (handler == null) {
      return;
    }
    if (playing) {
      await handler.pause();
    } else {
      await handler.play();
    }
  }

  Future<void> _refreshCarLifeStatus() async {
    if (_isCheckingCarLife || !mounted) {
      return;
    }
    setState(() {
      _isCheckingCarLife = true;
    });
    final CarLifeStatus status = await _carLifeService.getStatus();
    if (!mounted) {
      return;
    }
    setState(() {
      _carLifeStatus = status;
      _isCheckingCarLife = false;
    });
  }

  Future<void> _openCarLife() async {
    final CarLifeLaunchResult result = await _carLifeService.openCarLife();
    if (!mounted) {
      return;
    }
    await _refreshCarLifeStatus();
    if (result.launched) {
      _showSnack(
        result.reason == 'market_opened' || result.reason == 'web_opened'
            ? '未检测到 CarLife，已打开安装入口。'
            : '已尝试打开百度 CarLife。',
      );
    } else {
      _showSnack('未能打开百度 CarLife：${result.reason}');
    }
  }

  Future<void> _autoCheckForUpdate() async {
    if (_hasAutoCheckedUpdate || !mounted) {
      return;
    }
    _hasAutoCheckedUpdate = true;
    await _checkForUpdate(silentNoUpdate: true, silentErrors: true);
  }

  Future<void> _checkForUpdate({
    bool silentNoUpdate = false,
    bool silentErrors = false,
  }) async {
    if (_isCheckingUpdate) {
      return;
    }
    setState(() {
      _isCheckingUpdate = true;
    });

    try {
      final AppUpdateInfo updateInfo = await _updateCheckService
          .checkLatestRelease();
      if (!mounted) {
        return;
      }
      if (silentNoUpdate && !updateInfo.hasUpdate) {
        return;
      }
      await _showUpdateDialog(updateInfo);
    } on UpdateCheckException catch (error) {
      if (!silentErrors && mounted) {
        _showSnack(error.message);
      }
    } catch (error) {
      if (!silentErrors && mounted) {
        _showSnack('检查更新失败：$error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingUpdate = false;
        });
      }
    }
  }

  Future<void> _showUpdateDialog(AppUpdateInfo updateInfo) async {
    final String assetText = updateInfo.apkAssets.isEmpty
        ? '未找到 Android APK 下载资源'
        : updateInfo.apkAssets
              .map((AppReleaseAsset asset) {
                final String size = asset.sizeText.isEmpty
                    ? ''
                    : ' (${asset.sizeText})';
                final String abi = asset.abi.isEmpty ? '' : ' ${asset.abi}';
                return '${asset.name}$abi$size';
              })
              .join('\n');

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(updateInfo.hasUpdate ? '发现新版本' : '已是最新版本'),
          content: SingleChildScrollView(
            child: Text(
              <String>[
                '当前版本：${updateInfo.currentVersion}',
                '最新版本：${updateInfo.latestVersion}',
                if (updateInfo.releaseName.isNotEmpty)
                  '发布名称：${updateInfo.releaseName}',
                if (updateInfo.publishedAt != null)
                  '发布时间：${updateInfo.publishedAt!.toLocal()}',
                '',
                assetText,
              ].join('\n'),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('关闭'),
            ),
            if (updateInfo.hasUpdate && updateInfo.hasDownloadAssets)
              FilledButton(
                onPressed: _isInstallingUpdate
                    ? null
                    : () {
                        Navigator.of(dialogContext).pop();
                        unawaited(_installUpdate(updateInfo));
                      },
                child: const Text('立即更新'),
              ),
          ],
        );
      },
    );
  }

  Future<void> _installUpdate(AppUpdateInfo updateInfo) async {
    if (_isInstallingUpdate) {
      return;
    }
    setState(() {
      _isInstallingUpdate = true;
    });

    try {
      await _appInstallerService.downloadAndInstallBestApk(
        updateInfo.apkAssets,
      );
      if (mounted) {
        _showSnack('安装包开始下载，完成后会自动打开安装界面。');
      }
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }
      if (error.code == 'install_permission_required') {
        _showSnack(error.message ?? '请允许安装未知来源应用后重试。');
      } else if (updateInfo.releaseUrl.isNotEmpty) {
        await Clipboard.setData(ClipboardData(text: updateInfo.releaseUrl));
        _showSnack('自动下载安装失败，发布页链接已复制。');
      } else {
        _showSnack(error.message ?? '下载安装包失败。');
      }
    } on AppInstallerException catch (error) {
      if (mounted) {
        _showSnack(error.message);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isInstallingUpdate = false;
        });
      }
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: _PlaybackStateBuilder(
          audioHandler: widget.audioHandler,
          builder: (BuildContext context, PlaybackUiState playbackState) {
            final _DemoTrack currentTrack = _demoQueue[_selectedQueueIndex];
            return _NativeMusicScaffold(
              selectedTab: _selectedTab,
              selectedQueueIndex: _selectedQueueIndex,
              playbackState: playbackState,
              currentTrack: currentTrack,
              carLifeStatus: _carLifeStatus,
              updateBusy: _isCheckingUpdate || _isInstallingUpdate,
              carLifeBusy: _isCheckingCarLife,
              onSelectTab: (int index) {
                setState(() {
                  _selectedTab = index;
                });
              },
              onSelectQueueIndex: (int index) {
                setState(() {
                  _selectedQueueIndex = index;
                });
              },
              onPlayPause: () => _togglePlayback(playbackState.playing),
              onPrevious: _skipToPreviousTrack,
              onNext: _skipToNextTrack,
              onOpenCarLife: _openCarLife,
              onRefreshCarLife: _refreshCarLifeStatus,
              onCheckUpdate: _checkForUpdate,
            );
          },
        ),
      ),
    );
  }
}

class _PlaybackStateBuilder extends StatelessWidget {
  const _PlaybackStateBuilder({
    required this.audioHandler,
    required this.builder,
  });

  final MusicAudioHandler? audioHandler;
  final Widget Function(BuildContext context, PlaybackUiState state) builder;

  @override
  Widget build(BuildContext context) {
    final MusicAudioHandler? handler = audioHandler;
    if (handler == null) {
      return builder(context, const PlaybackUiState());
    }
    return StreamBuilder<PlaybackState>(
      stream: handler.playbackState,
      initialData: handler.playbackState.valueOrNull,
      builder: (BuildContext context, AsyncSnapshot<PlaybackState> snapshot) {
        return StreamBuilder<MediaItem?>(
          stream: handler.mediaItem,
          initialData: handler.mediaItem.valueOrNull,
          builder:
              (BuildContext context, AsyncSnapshot<MediaItem?> itemSnapshot) {
                return builder(
                  context,
                  PlaybackUiState.fromAudioService(
                    snapshot.data,
                    itemSnapshot.data,
                  ),
                );
              },
        );
      },
    );
  }
}

class PlaybackUiState {
  const PlaybackUiState({
    this.playing = false,
    this.title = '',
    this.artist = '',
    this.position = Duration.zero,
    this.duration,
  });

  factory PlaybackUiState.fromAudioService(
    PlaybackState? state,
    MediaItem? item,
  ) {
    return PlaybackUiState(
      playing: state?.playing ?? false,
      title: item?.title ?? '',
      artist: item?.artist ?? '',
      position: state?.position ?? Duration.zero,
      duration: item?.duration,
    );
  }

  final bool playing;
  final String title;
  final String artist;
  final Duration position;
  final Duration? duration;
}

class _NativeMusicScaffold extends StatelessWidget {
  const _NativeMusicScaffold({
    required this.selectedTab,
    required this.selectedQueueIndex,
    required this.playbackState,
    required this.currentTrack,
    required this.carLifeStatus,
    required this.updateBusy,
    required this.carLifeBusy,
    required this.onSelectTab,
    required this.onSelectQueueIndex,
    required this.onPlayPause,
    required this.onPrevious,
    required this.onNext,
    required this.onOpenCarLife,
    required this.onRefreshCarLife,
    required this.onCheckUpdate,
  });

  final int selectedTab;
  final int selectedQueueIndex;
  final PlaybackUiState playbackState;
  final _DemoTrack currentTrack;
  final CarLifeStatus carLifeStatus;
  final bool updateBusy;
  final bool carLifeBusy;
  final ValueChanged<int> onSelectTab;
  final ValueChanged<int> onSelectQueueIndex;
  final VoidCallback onPlayPause;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onOpenCarLife;
  final VoidCallback onRefreshCarLife;
  final VoidCallback onCheckUpdate;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        _AtmosphereBackground(track: currentTrack),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool showQueue = constraints.maxWidth >= 1360;
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: <Widget>[
                    Expanded(
                      child: Row(
                        children: <Widget>[
                          _SideNavigationRail(
                            compact: constraints.maxHeight < 620,
                            selectedIndex: selectedTab,
                            updateBusy: updateBusy,
                            onSelect: onSelectTab,
                            onCheckUpdate: onCheckUpdate,
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            flex: showQueue ? 5 : 6,
                            child: _HomePanel(
                              selectedTab: selectedTab,
                              carLifeStatus: carLifeStatus,
                              carLifeBusy: carLifeBusy,
                              onOpenCarLife: onOpenCarLife,
                              onRefreshCarLife: onRefreshCarLife,
                            ),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            flex: showQueue ? 4 : 5,
                            child: _NowPlayingPanel(
                              track: currentTrack,
                              playbackState: playbackState,
                              onPlayPause: onPlayPause,
                              onPrevious: onPrevious,
                              onNext: onNext,
                            ),
                          ),
                          if (showQueue) ...<Widget>[
                            const SizedBox(width: 18),
                            SizedBox(
                              width: 330,
                              child: _QueuePanel(
                                selectedIndex: selectedQueueIndex,
                                onSelect: onSelectQueueIndex,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _MiniPlayerBar(
                      track: currentTrack,
                      playbackState: playbackState,
                      onPlayPause: onPlayPause,
                      onPrevious: onPrevious,
                      onNext: onNext,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _AtmosphereBackground extends StatelessWidget {
  const _AtmosphereBackground({required this.track});

  final _DemoTrack track;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(-0.62, -0.74),
          radius: 1.35,
          colors: <Color>[
            track.color.withValues(alpha: 0.58),
            _AppColors.background,
            const Color(0xFF02040A),
          ],
          stops: const <double>[0, 0.52, 1],
        ),
      ),
      child: CustomPaint(painter: _NoiseRibbonPainter(track.color)),
    );
  }
}

class _NoiseRibbonPainter extends CustomPainter {
  const _NoiseRibbonPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Colors.white.withValues(alpha: 0.10),
          color.withValues(alpha: 0.18),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size);

    final Path path = Path()
      ..moveTo(size.width * 0.08, size.height * 0.12)
      ..cubicTo(
        size.width * 0.34,
        size.height * 0.04,
        size.width * 0.50,
        size.height * 0.44,
        size.width * 0.78,
        size.height * 0.20,
      )
      ..cubicTo(
        size.width * 1.05,
        size.height * -0.02,
        size.width * 1.08,
        size.height * 0.52,
        size.width * 0.74,
        size.height * 0.64,
      )
      ..cubicTo(
        size.width * 0.42,
        size.height * 0.76,
        size.width * 0.22,
        size.height * 0.44,
        size.width * 0.06,
        size.height * 0.58,
      )
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_NoiseRibbonPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _SideNavigationRail extends StatelessWidget {
  const _SideNavigationRail({
    required this.compact,
    required this.selectedIndex,
    required this.updateBusy,
    required this.onSelect,
    required this.onCheckUpdate,
  });

  final bool compact;
  final int selectedIndex;
  final bool updateBusy;
  final ValueChanged<int> onSelect;
  final VoidCallback onCheckUpdate;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      width: compact ? 92 : 104,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 10 : 14,
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: compact ? 48 : 58,
            height: compact ? 48 : 58,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(compact ? 18 : 22),
              gradient: const LinearGradient(
                colors: <Color>[_AppColors.primary, _AppColors.accent],
              ),
            ),
            child: Icon(Icons.music_note_rounded, size: compact ? 28 : 34),
          ),
          SizedBox(height: compact ? 10 : 18),
          for (int index = 0; index < _navItems.length; index += 1)
            _RailButton(
              item: _navItems[index],
              compact: compact,
              selected: selectedIndex == index,
              onTap: () => onSelect(index),
            ),
          const Spacer(),
          _RailIconButton(
            icon: Icons.system_update_rounded,
            label: '更新',
            enabled: !updateBusy,
            onTap: onCheckUpdate,
          ),
        ],
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.item,
    required this.compact,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool compact;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 6 : 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: compact ? 64 : 74,
          padding: EdgeInsets.symmetric(vertical: compact ? 7 : 10),
          decoration: BoxDecoration(
            color: selected
                ? _AppColors.primary.withValues(alpha: 0.24)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected
                  ? Colors.white.withValues(alpha: 0.20)
                  : Colors.transparent,
            ),
          ),
          child: Column(
            children: <Widget>[
              Icon(
                item.icon,
                color: selected ? Colors.white : _AppColors.textMuted,
                size: compact ? 22 : 26,
              ),
              SizedBox(height: compact ? 2 : 4),
              Text(
                item.label,
                style: TextStyle(
                  color: selected ? Colors.white : _AppColors.textMuted,
                  fontSize: compact ? 11 : 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RailIconButton extends StatelessWidget {
  const _RailIconButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = enabled
        ? _AppColors.textMuted
        : const Color(0x66FFFFFF);
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          children: <Widget>[
            Icon(icon, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomePanel extends StatelessWidget {
  const _HomePanel({
    required this.selectedTab,
    required this.carLifeStatus,
    required this.carLifeBusy,
    required this.onOpenCarLife,
    required this.onRefreshCarLife,
  });

  final int selectedTab;
  final CarLifeStatus carLifeStatus;
  final bool carLifeBusy;
  final VoidCallback onOpenCarLife;
  final VoidCallback onRefreshCarLife;

  @override
  Widget build(BuildContext context) {
    final _NavItem activeItem = _navItems[selectedTab];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    '车载音乐',
                    style: TextStyle(
                      color: _AppColors.textPrimary,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '原生播放器界面 · ${activeItem.label}',
                    style: const TextStyle(
                      color: _AppColors.textSecondary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const _SearchPill(),
          ],
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool showCarLifeCard = constraints.maxWidth >= 520;
            return Row(
              children: <Widget>[
                Expanded(
                  child: _GlassCard(
                    height: 188,
                    padding: const EdgeInsets.all(22),
                    child: LayoutBuilder(
                      builder: (BuildContext context, BoxConstraints constraints) {
                        final bool showHeroArt = constraints.maxWidth >= 430;
                        return Row(
                          children: <Widget>[
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  const Text(
                                    '推荐',
                                    style: TextStyle(
                                      color: _AppColors.textPrimary,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '为横屏车机重做的 iOS 风格音乐首页，后续会接入搜索、歌单、歌词和完整原生队列。',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: _AppColors.textSecondary
                                          .withValues(alpha: 0.92),
                                      fontSize: 15,
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: <Widget>[
                                      _ChipLabel(text: '大触控目标'),
                                      _ChipLabel(text: '后台媒体键'),
                                      _ChipLabel(text: '原生队列'),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (showHeroArt) ...const <Widget>[
                              SizedBox(width: 18),
                              _HeroEqualizer(),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                ),
                if (showCarLifeCard) ...<Widget>[
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 218,
                    child: _CarLifeCard(
                      status: carLifeStatus,
                      busy: carLifeBusy,
                      onOpen: onOpenCarLife,
                      onRefresh: onRefreshCarLife,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
        if (carLifeStatus.reason == 'unchecked')
          const SizedBox.shrink()
        else if (carLifeStatus.reason.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'CarLife 状态：${carLifeStatus.displayText}',
              style: const TextStyle(
                color: _AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        const SizedBox(height: 16),
        Expanded(
          child: Row(
            children: <Widget>[
              Expanded(
                child: _LibrarySection(title: '最近播放', tracks: _recentTracks),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _LibrarySection(title: '我的收藏', tracks: _favoriteTracks),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CarLifeCard extends StatelessWidget {
  const _CarLifeCard({
    required this.status,
    required this.busy,
    required this.onOpen,
    required this.onRefresh,
  });

  final CarLifeStatus status;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      height: 188,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: _AppColors.carlife.withValues(alpha: 0.24),
                ),
                child: const Icon(
                  Icons.directions_car_filled_rounded,
                  color: _AppColors.carlife,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  '百度 CarLife',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            status.displayText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            status.sdkLinked ? '可同步模板和控制。' : '已预留原生桥接，等待 SDK 接入。',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _AppColors.textMuted,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const Spacer(),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton(
                  onPressed: busy ? null : onOpen,
                  style: FilledButton.styleFrom(
                    backgroundColor: _AppColors.carlife,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(status.launchable ? '打开' : '安装'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: busy ? null : onRefresh,
                icon: busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
                color: _AppColors.textSecondary,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
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

class _SearchPill extends StatelessWidget {
  const _SearchPill();

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      width: 250,
      height: 56,
      borderRadius: 28,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: const Row(
        children: <Widget>[
          Icon(Icons.search_rounded, color: _AppColors.textSecondary),
          SizedBox(width: 10),
          Text(
            '搜索音乐',
            style: TextStyle(
              color: _AppColors.textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroEqualizer extends StatelessWidget {
  const _HeroEqualizer();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 126,
      height: 126,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(38),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          for (final double height in <double>[32, 72, 48, 88, 58])
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Container(
                width: 10,
                height: height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[_AppColors.accent, _AppColors.primary],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LibrarySection extends StatelessWidget {
  const _LibrarySection({required this.title, required this.tracks});

  final String title;
  final List<_DemoTrack> tracks;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              color: _AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: tracks.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (BuildContext context, int index) {
                final _DemoTrack track = tracks[index];
                return Row(
                  children: <Widget>[
                    _ArtworkTile(track: track, size: 46, radius: 14),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _AppColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            track.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      track.durationText,
                      style: const TextStyle(
                        color: _AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NowPlayingPanel extends StatelessWidget {
  const _NowPlayingPanel({
    required this.track,
    required this.playbackState,
    required this.onPlayPause,
    required this.onPrevious,
    required this.onNext,
  });

  final _DemoTrack track;
  final PlaybackUiState playbackState;
  final VoidCallback onPlayPause;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final String title = playbackState.title.isEmpty
        ? track.title
        : playbackState.title;
    final String artist = playbackState.artist.isEmpty
        ? track.artist
        : playbackState.artist;
    final Duration duration = playbackState.duration ?? track.duration;
    final double progress = duration == Duration.zero
        ? 0
        : (playbackState.position.inMilliseconds / duration.inMilliseconds)
              .clamp(0, 1)
              .toDouble();

    return _GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            '正在播放',
            style: TextStyle(
              color: _AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: Center(
              child: _ArtworkTile(track: track, size: 220, radius: 48),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _AppColors.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _AppColors.textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 7,
              value: progress,
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(track.color),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                _formatDuration(playbackState.position),
                style: const TextStyle(color: _AppColors.textMuted),
              ),
              Text(
                _formatDuration(duration),
                style: const TextStyle(color: _AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _TransportButton(
                icon: Icons.skip_previous_rounded,
                label: '上一曲',
                onTap: onPrevious,
              ),
              const SizedBox(width: 18),
              _TransportButton(
                icon: playbackState.playing
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                label: playbackState.playing ? '暂停' : '播放',
                primary: true,
                onTap: onPlayPause,
              ),
              const SizedBox(width: 18),
              _TransportButton(
                icon: Icons.skip_next_rounded,
                label: '下一曲',
                onTap: onNext,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QueuePanel extends StatelessWidget {
  const _QueuePanel({required this.selectedIndex, required this.onSelect});

  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(
                child: Text(
                  '播放队列',
                  style: TextStyle(
                    color: _AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _ChipLabel(text: '顺序'),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            '完整原生队列会在下一阶段接入真实搜索和歌单数据。',
            style: TextStyle(
              color: _AppColors.textSecondary,
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: _demoQueue.length,
              separatorBuilder: (_, _) => const SizedBox(height: 9),
              itemBuilder: (BuildContext context, int index) {
                final _DemoTrack track = _demoQueue[index];
                final bool selected = selectedIndex == index;
                return InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => onSelect(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: selected
                            ? track.color.withValues(alpha: 0.72)
                            : Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        _ArtworkTile(track: track, size: 48, radius: 15),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                track.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: selected
                                      ? _AppColors.textPrimary
                                      : _AppColors.textSecondary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                track.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _AppColors.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (selected)
                          const Icon(
                            Icons.graphic_eq_rounded,
                            color: _AppColors.primary,
                            size: 22,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniPlayerBar extends StatelessWidget {
  const _MiniPlayerBar({
    required this.track,
    required this.playbackState,
    required this.onPlayPause,
    required this.onPrevious,
    required this.onNext,
  });

  final _DemoTrack track;
  final PlaybackUiState playbackState;
  final VoidCallback onPlayPause;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final String title = playbackState.title.isEmpty
        ? track.title
        : playbackState.title;
    final String artist = playbackState.artist.isEmpty
        ? track.artist
        : playbackState.artist;
    return _GlassCard(
      height: 88,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: <Widget>[
          _ArtworkTile(track: track, size: 56, radius: 16),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Text(
            '歌词',
            style: TextStyle(
              color: _AppColors.textSecondary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 22),
          _MiniTransportButton(
            icon: Icons.skip_previous_rounded,
            onTap: onPrevious,
          ),
          _MiniTransportButton(
            icon: playbackState.playing
                ? Icons.pause_rounded
                : Icons.play_arrow_rounded,
            primary: true,
            onTap: onPlayPause,
          ),
          _MiniTransportButton(icon: Icons.skip_next_rounded, onTap: onNext),
        ],
      ),
    );
  }
}

class _TransportButton extends StatelessWidget {
  const _TransportButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(primary ? 34 : 28),
        onTap: onTap,
        child: Container(
          width: primary ? 76 : 62,
          height: primary ? 76 : 62,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: primary
                ? const LinearGradient(
                    colors: <Color>[_AppColors.primary, _AppColors.accent],
                  )
                : null,
            color: primary ? null : Colors.white.withValues(alpha: 0.10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            boxShadow: primary
                ? <BoxShadow>[
                    BoxShadow(
                      color: _AppColors.primary.withValues(alpha: 0.32),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: Icon(icon, size: primary ? 42 : 34, color: Colors.white),
        ),
      ),
    );
  }
}

class _MiniTransportButton extends StatelessWidget {
  const _MiniTransportButton({
    required this.icon,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 10),
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, size: primary ? 34 : 30),
        color: Colors.white,
        style: IconButton.styleFrom(
          fixedSize: Size.square(primary ? 58 : 50),
          backgroundColor: primary
              ? _AppColors.primary
              : Colors.white.withValues(alpha: 0.08),
          shape: const CircleBorder(),
        ),
      ),
    );
  }
}

class _ArtworkTile extends StatelessWidget {
  const _ArtworkTile({
    required this.track,
    required this.size,
    required this.radius,
  });

  final _DemoTrack track;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[track.color, track.color.withBlue(230), Colors.black],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: track.color.withValues(alpha: 0.24),
            blurRadius: size * 0.16,
            offset: Offset(0, size * 0.06),
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            right: -size * 0.12,
            top: -size * 0.08,
            child: Container(
              width: size * 0.70,
              height: size * 0.70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
          ),
          Center(
            child: Text(
              track.mark,
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.28,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.child,
    this.width,
    this.height,
    this.padding = EdgeInsets.zero,
    this.borderRadius = 30,
  });

  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: _AppColors.surface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 32,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ChipLabel extends StatelessWidget {
  const _ChipLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: _AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _AppColors {
  const _AppColors._();

  static const Color background = Color(0xFF07101C);
  static const Color surface = Color(0xCC151824);
  static const Color primary = Color(0xFFFF5C93);
  static const Color accent = Color(0xFFFFB86B);
  static const Color carlife = Color(0xFF2D7DFF);
  static const Color error = Color(0xFFFF5A5F);
  static const Color textPrimary = Color(0xFFF7F8FA);
  static const Color textSecondary = Color(0xFFAEB4C1);
  static const Color textMuted = Color(0xFF747D8C);
}

class _NavItem {
  const _NavItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class _DemoTrack {
  const _DemoTrack({
    required this.title,
    required this.artist,
    required this.duration,
    required this.color,
    required this.mark,
  });

  final String title;
  final String artist;
  final Duration duration;
  final Color color;
  final String mark;

  String get durationText => _formatDuration(duration);
}

const List<_NavItem> _navItems = <_NavItem>[
  _NavItem(icon: Icons.home_rounded, label: '首页'),
  _NavItem(icon: Icons.search_rounded, label: '搜索'),
  _NavItem(icon: Icons.queue_music_rounded, label: '队列'),
  _NavItem(icon: Icons.favorite_rounded, label: '收藏'),
];

const List<_DemoTrack> _demoQueue = <_DemoTrack>[
  _DemoTrack(
    title: 'Highway Morning',
    artist: 'Native Radio',
    duration: Duration(minutes: 3, seconds: 42),
    color: Color(0xFFFF5C93),
    mark: 'H',
  ),
  _DemoTrack(
    title: 'City Lights',
    artist: 'Drive Session',
    duration: Duration(minutes: 4, seconds: 8),
    color: Color(0xFF36C8FF),
    mark: 'C',
  ),
  _DemoTrack(
    title: 'Ocean Avenue',
    artist: 'Glass FM',
    duration: Duration(minutes: 3, seconds: 25),
    color: Color(0xFF65E4A3),
    mark: 'O',
  ),
  _DemoTrack(
    title: 'Late Night Loop',
    artist: 'CarPlay Mix',
    duration: Duration(minutes: 5, seconds: 1),
    color: Color(0xFFFFB86B),
    mark: 'L',
  ),
  _DemoTrack(
    title: 'Silent Dashboard',
    artist: 'iMusic Lab',
    duration: Duration(minutes: 2, seconds: 57),
    color: Color(0xFF9A7CFF),
    mark: 'S',
  ),
];

const List<_DemoTrack> _recentTracks = <_DemoTrack>[
  _DemoTrack(
    title: 'Morning Pulse',
    artist: 'Daily Drive',
    duration: Duration(minutes: 3, seconds: 9),
    color: Color(0xFF36C8FF),
    mark: 'M',
  ),
  _DemoTrack(
    title: 'Warm Start',
    artist: 'Engine Room',
    duration: Duration(minutes: 4, seconds: 12),
    color: Color(0xFFFFB86B),
    mark: 'W',
  ),
  _DemoTrack(
    title: 'Signal Green',
    artist: 'Route 88',
    duration: Duration(minutes: 3, seconds: 33),
    color: Color(0xFF65E4A3),
    mark: 'G',
  ),
];

const List<_DemoTrack> _favoriteTracks = <_DemoTrack>[
  _DemoTrack(
    title: 'Glass Sunset',
    artist: 'iOS Native',
    duration: Duration(minutes: 3, seconds: 51),
    color: Color(0xFFFF5C93),
    mark: 'G',
  ),
  _DemoTrack(
    title: 'Turn Signal',
    artist: 'Car Unit',
    duration: Duration(minutes: 4, seconds: 2),
    color: Color(0xFF9A7CFF),
    mark: 'T',
  ),
  _DemoTrack(
    title: 'Home Screen',
    artist: 'Native Music',
    duration: Duration(minutes: 2, seconds: 44),
    color: Color(0xFF65E4A3),
    mark: 'H',
  ),
];

String _formatDuration(Duration duration) {
  final int minutes = duration.inMinutes;
  final int seconds = duration.inSeconds.remainder(60);
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
