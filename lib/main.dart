import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'music_audio_handler.dart';
import 'models/app_update_info.dart';
import 'native_audio_controller.dart';
import 'player_probe_script.dart';
import 'services/app_installer_service.dart';
import 'services/update_check_service.dart';

final WebUri _musicHomeUrl = WebUri('https://music.sy110.eu.org/music');

final UnmodifiableListView<UserScript> _playerProbeScripts =
    UnmodifiableListView<UserScript>(<UserScript>[
      UserScript(
        source: playerProbeScriptSource,
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        contentWorld: ContentWorld.PAGE,
      ),
    ]);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await WakelockPlus.enable();

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await InAppWebViewController.setWebContentsDebuggingEnabled(kDebugMode);
  }

  final MusicAudioHandler audioHandler = await initMusicAudioHandler();

  runApp(MusicCarApp(audioHandler: audioHandler));
}

class MusicCarApp extends StatelessWidget {
  const MusicCarApp({
    super.key,
    this.webViewOverride,
    this.audioHandler,
    this.autoCheckForUpdates = true,
  });

  final Widget? webViewOverride;
  final MusicAudioHandler? audioHandler;
  final bool autoCheckForUpdates;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '车载音乐',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF14B8A6),
          secondary: Color(0xFFFFC857),
          surface: Color(0xFF101418),
          error: Color(0xFFFF5A5F),
        ),
        scaffoldBackgroundColor: Colors.black,
        splashFactory: NoSplash.splashFactory,
        useMaterial3: true,
      ),
      home: MusicCarWebViewPage(
        webViewOverride: webViewOverride,
        audioHandler: audioHandler,
        autoCheckForUpdates: autoCheckForUpdates,
      ),
    );
  }
}

class MusicCarWebViewPage extends StatefulWidget {
  const MusicCarWebViewPage({
    super.key,
    this.webViewOverride,
    this.audioHandler,
    this.autoCheckForUpdates = true,
  });

  final Widget? webViewOverride;
  final MusicAudioHandler? audioHandler;
  final bool autoCheckForUpdates;

  @override
  State<MusicCarWebViewPage> createState() => _MusicCarWebViewPageState();
}

class _MusicCarWebViewPageState extends State<MusicCarWebViewPage>
    with WidgetsBindingObserver {
  InAppWebViewController? _controller;
  late final NativeAudioController _nativeAudioController;
  final UpdateCheckService _updateCheckService = UpdateCheckService();
  final AppInstallerService _appInstallerService = const AppInstallerService();
  double _progress = 0;
  bool _isLoading = true;
  bool _isCheckingUpdate = false;
  bool _isInstallingUpdate = false;
  bool _hasAutoCheckedUpdate = false;
  bool _canGoBack = false;
  bool _canGoForward = false;
  bool _toolbarVisible = true;
  String _statusText = '加载中';

  @override
  void initState() {
    super.initState();
    _nativeAudioController = NativeAudioController(player: widget.audioHandler);
    widget.audioHandler?.onPlayTrack = _resumeNativePlayback;
    widget.audioHandler?.onSkipToNextTrack = _skipToNextTrack;
    widget.audioHandler?.onSkipToPreviousTrack = _skipToPreviousTrack;
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
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

  Future<void> _refreshNavigationState() async {
    final InAppWebViewController? controller = _controller;
    if (controller == null || !mounted) {
      return;
    }
    final bool canGoBack = await controller.canGoBack();
    final bool canGoForward = await controller.canGoForward();
    if (!mounted) {
      return;
    }
    setState(() {
      _canGoBack = canGoBack;
      _canGoForward = canGoForward;
    });
  }

  Future<void> _goBack() async {
    final InAppWebViewController? controller = _controller;
    if (controller != null && await controller.canGoBack()) {
      await controller.goBack();
      await _refreshNavigationState();
    }
  }

  Future<void> _goForward() async {
    final InAppWebViewController? controller = _controller;
    if (controller != null && await controller.canGoForward()) {
      await controller.goForward();
      await _refreshNavigationState();
    }
  }

  Future<void> _goHome() async {
    await _controller?.loadUrl(urlRequest: URLRequest(url: _musicHomeUrl));
  }

  Future<void> _reload() async {
    await _controller?.reload();
  }

  Future<void> _toggleToolbar() async {
    setState(() {
      _toolbarVisible = !_toolbarVisible;
    });
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
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

  Future<void> _skipToNextTrack() async {
    final bool handled = await _nativeAudioController.skipToNext();
    if (handled) {
      unawaited(_pauseWebAudioIfAvailable());
      return;
    }
    await _runMusicControlScript('next', clickNextTrackScript);
  }

  Future<void> _skipToPreviousTrack() async {
    final bool handled = await _nativeAudioController.skipToPrevious();
    if (handled) {
      unawaited(_pauseWebAudioIfAvailable());
      return;
    }
    await _runMusicControlScript('previous', clickPreviousTrackScript);
  }

  Future<bool> _resumeNativePlayback() {
    return _nativeAudioController.resumePlayback();
  }

  Future<void> _pauseWebAudioIfAvailable() async {
    try {
      await _controller
          ?.evaluateJavascript(source: pauseWebAudioScript)
          .timeout(const Duration(seconds: 1));
    } catch (error) {
      debugPrint('[native-audio] pause WebView audio skipped: $error');
    }
  }

  Future<void> _runMusicControlScript(String action, String source) async {
    final InAppWebViewController? controller = _controller;
    if (controller == null) {
      debugPrint('[native-audio] skip $action ignored: WebView not ready');
      return;
    }
    final Object? result = await controller.evaluateJavascript(source: source);
    debugPrint('[native-audio] skip $action dispatched: $result');
  }

  void _handlePlayerProbe(List<dynamic> arguments) {
    if (arguments.isEmpty) {
      return;
    }
    final Object? firstArgument = arguments.first;
    if (firstArgument is! Map) {
      if (kDebugMode) {
        debugPrint('[music-player-probe] unexpected payload: $firstArgument');
      }
      return;
    }
    final Map<Object?, Object?> payload = firstArgument;
    final PlayerProbeSnapshot snapshot = PlayerProbeSnapshot.fromPayload(
      payload,
    );
    if (kDebugMode) {
      final String reason = '${payload['reason'] ?? ''}';
      debugPrint(
        '[music-player-probe] reason=$reason playing=${snapshot.playing} '
        'time=${snapshot.currentTime.inMilliseconds / 1000}/'
        '${snapshot.duration.inMilliseconds / 1000} '
        'title="${snapshot.title}" artist="${snapshot.artist}" '
        'audioUrl="${snapshot.audioUrl}" coverUrl="${snapshot.coverUrl}" '
        'queue=${snapshot.playlist.length} index=${snapshot.currentIndex}',
      );
    }
    unawaited(_nativeAudioController.syncQueueFromProbe(snapshot));
    if (snapshot.hasAudioUrl || snapshot.canResolveAudioUrl) {
      unawaited(_syncNativeAudio(snapshot));
    }
  }

  Future<void> _syncNativeAudio(PlayerProbeSnapshot snapshot) async {
    try {
      final bool handled = await _nativeAudioController.syncFromProbe(snapshot);
      if (handled && snapshot.playing) {
        await _controller?.evaluateJavascript(source: pauseWebAudioScript);
      }
    } catch (error, stackTrace) {
      debugPrint('[native-audio] sync failed: $error');
      if (kDebugMode) {
        debugPrint('$stackTrace');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          unawaited(_goBack());
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: <Widget>[
              widget.webViewOverride ??
                  InAppWebView(
                    initialUrlRequest: URLRequest(url: _musicHomeUrl),
                    initialUserScripts: _playerProbeScripts,
                    initialSettings: InAppWebViewSettings(
                      isInspectable: kDebugMode,
                      mediaPlaybackRequiresUserGesture: false,
                      allowsInlineMediaPlayback: true,
                      javaScriptCanOpenWindowsAutomatically: true,
                      supportMultipleWindows: true,
                      useShouldOverrideUrlLoading: true,
                      thirdPartyCookiesEnabled: true,
                      transparentBackground: false,
                      disableContextMenu: true,
                    ),
                    onWebViewCreated: (InAppWebViewController controller) {
                      _controller = controller;
                      controller.addJavaScriptHandler(
                        handlerName: playerProbeHandlerName,
                        callback: _handlePlayerProbe,
                      );
                    },
                    onLoadStart:
                        (InAppWebViewController controller, WebUri? url) {
                          debugPrint('[music-webview] loadStart: $url');
                          if (!mounted) {
                            return;
                          }
                          setState(() {
                            _isLoading = true;
                            _statusText = '加载中';
                          });
                          unawaited(_refreshNavigationState());
                        },
                    onLoadStop:
                        (InAppWebViewController controller, WebUri? url) {
                          debugPrint('[music-webview] loadStop: $url');
                          if (!mounted) {
                            return;
                          }
                          setState(() {
                            _isLoading = false;
                            _progress = 1;
                            _statusText = '';
                          });
                          unawaited(_refreshNavigationState());
                        },
                    onProgressChanged:
                        (InAppWebViewController controller, int progress) {
                          if (!mounted) {
                            return;
                          }
                          setState(() {
                            _progress = progress / 100;
                            _isLoading = progress < 100;
                          });
                        },
                    onUpdateVisitedHistory:
                        (
                          InAppWebViewController controller,
                          WebUri? url,
                          bool? androidIsReload,
                        ) {
                          debugPrint('[music-webview] history: $url');
                          unawaited(_refreshNavigationState());
                        },
                    onConsoleMessage:
                        (
                          InAppWebViewController controller,
                          ConsoleMessage consoleMessage,
                        ) {
                          if (kDebugMode) {
                            debugPrint(
                              '[music-webview] console[${consoleMessage.messageLevel}]: '
                              '${consoleMessage.message}',
                            );
                          }
                        },
                    onCreateWindow:
                        (
                          InAppWebViewController controller,
                          CreateWindowAction createWindowAction,
                        ) async {
                          final WebUri? target = createWindowAction.request.url;
                          if (target != null) {
                            await controller.loadUrl(
                              urlRequest: URLRequest(url: target),
                            );
                          }
                          return false;
                        },
                    onReceivedError:
                        (
                          InAppWebViewController controller,
                          WebResourceRequest request,
                          WebResourceError error,
                        ) {
                          debugPrint(
                            '[music-webview] error: ${request.url} -> '
                            '${error.description}',
                          );
                          if (request.isForMainFrame ?? true) {
                            setState(() {
                              _isLoading = false;
                              _statusText = '页面加载失败';
                            });
                          }
                        },
                    shouldOverrideUrlLoading:
                        (
                          InAppWebViewController controller,
                          NavigationAction navigationAction,
                        ) async {
                          final WebUri? url = navigationAction.request.url;
                          if (url == null) {
                            return NavigationActionPolicy.ALLOW;
                          }
                          if (<String>{
                            'http',
                            'https',
                            'about',
                            'data',
                            'blob',
                            'file',
                            'javascript',
                          }.contains(url.scheme)) {
                            return NavigationActionPolicy.ALLOW;
                          }
                          debugPrint(
                            '[music-webview] blocked navigation: $url',
                          );
                          return NavigationActionPolicy.CANCEL;
                        },
                  ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AnimatedOpacity(
                  opacity: _isLoading ? 1 : 0,
                  duration: const Duration(milliseconds: 160),
                  child: LinearProgressIndicator(
                    minHeight: 3,
                    value: _progress <= 0 || _progress >= 1 ? null : _progress,
                    backgroundColor: const Color(0x22000000),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF14B8A6),
                    ),
                  ),
                ),
              ),
              if (_statusText.isNotEmpty)
                Positioned(
                  left: 24,
                  bottom: 24,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xCC0B0F14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      child: Text(
                        _statusText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: 12,
                left: 16,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 180),
                  offset: _toolbarVisible ? Offset.zero : const Offset(-1.2, 0),
                  child: AnimatedOpacity(
                    opacity: _toolbarVisible ? 1 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: _ControlStrip(
                      canGoBack: _canGoBack,
                      canGoForward: _canGoForward,
                      updateBusy: _isCheckingUpdate || _isInstallingUpdate,
                      onBack: _goBack,
                      onForward: _goForward,
                      onHome: _goHome,
                      onReload: _reload,
                      onCheckUpdate: _checkForUpdate,
                      onHide: _toggleToolbar,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 16,
                child: _RoundIconButton(
                  icon: _toolbarVisible ? Icons.fullscreen : Icons.menu,
                  tooltip: _toolbarVisible ? '隐藏控制栏' : '显示控制栏',
                  onPressed: _toggleToolbar,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ControlStrip extends StatelessWidget {
  const _ControlStrip({
    required this.canGoBack,
    required this.canGoForward,
    required this.updateBusy,
    required this.onBack,
    required this.onForward,
    required this.onHome,
    required this.onReload,
    required this.onCheckUpdate,
    required this.onHide,
  });

  final bool canGoBack;
  final bool canGoForward;
  final bool updateBusy;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final VoidCallback onHome;
  final VoidCallback onReload;
  final VoidCallback onCheckUpdate;
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xD60B0F14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x33FFFFFF)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _RoundIconButton(
              icon: Icons.arrow_back,
              tooltip: '后退',
              enabled: canGoBack,
              onPressed: onBack,
            ),
            _RoundIconButton(
              icon: Icons.arrow_forward,
              tooltip: '前进',
              enabled: canGoForward,
              onPressed: onForward,
            ),
            _RoundIconButton(
              icon: Icons.home,
              tooltip: '主页',
              onPressed: onHome,
            ),
            _RoundIconButton(
              icon: Icons.refresh,
              tooltip: '刷新',
              onPressed: onReload,
            ),
            _RoundIconButton(
              icon: Icons.system_update,
              tooltip: '检查更新',
              enabled: !updateBusy,
              onPressed: onCheckUpdate,
            ),
            _RoundIconButton(
              icon: Icons.fullscreen,
              tooltip: '隐藏控制栏',
              onPressed: onHide,
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.enabled = true,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final Color foreground = enabled ? Colors.white : const Color(0x66FFFFFF);
    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: SizedBox.square(
          dimension: 50,
          child: IconButton(
            onPressed: enabled ? onPressed : null,
            icon: Icon(icon, size: 27),
            color: foreground,
            disabledColor: foreground,
            style: IconButton.styleFrom(
              backgroundColor: const Color(0x3314B8A6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
