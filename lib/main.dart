import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'native_audio_controller.dart';
import 'player_probe_script.dart';

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

  runApp(const MusicCarApp());
}

class MusicCarApp extends StatelessWidget {
  const MusicCarApp({super.key, this.webViewOverride});

  final Widget? webViewOverride;

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
      home: MusicCarWebViewPage(webViewOverride: webViewOverride),
    );
  }
}

class MusicCarWebViewPage extends StatefulWidget {
  const MusicCarWebViewPage({super.key, this.webViewOverride});

  final Widget? webViewOverride;

  @override
  State<MusicCarWebViewPage> createState() => _MusicCarWebViewPageState();
}

class _MusicCarWebViewPageState extends State<MusicCarWebViewPage>
    with WidgetsBindingObserver {
  InAppWebViewController? _controller;
  final NativeAudioController _nativeAudioController = NativeAudioController();
  double _progress = 0;
  bool _isLoading = true;
  bool _canGoBack = false;
  bool _canGoForward = false;
  bool _toolbarVisible = true;
  String _statusText = '加载中';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(WakelockPlus.disable());
    unawaited(_nativeAudioController.dispose());
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
        'audioUrl="${snapshot.audioUrl}" coverUrl="${snapshot.coverUrl}"',
      );
    }
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
                      onBack: _goBack,
                      onForward: _goForward,
                      onHome: _goHome,
                      onReload: _reload,
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
    required this.onBack,
    required this.onForward,
    required this.onHome,
    required this.onReload,
    required this.onHide,
  });

  final bool canGoBack;
  final bool canGoForward;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final VoidCallback onHome;
  final VoidCallback onReload;
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
