import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_car_app/features/player/player_seek_bar.dart';
import 'package:music_car_app/features/player/portrait_player_view.dart';
import 'package:music_car_app/features/search/portrait_search_view.dart';
import 'package:music_car_app/free_music_api.dart';
import 'package:music_car_app/main.dart';

void main() {
  testWidgets('renders the portrait native music shell', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> pumpUi() async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
    }

    await tester.pumpWidget(const MusicCarApp(autoCheckForUpdates: false));

    expect(find.byType(NativeMusicHomePage), findsOneWidget);
    expect(find.text('想听什么？'), findsOneWidget);
    expect(find.text('继续播放'), findsOneWidget);
    expect(find.text('Portrait streaming deck'), findsNothing);
    expect(find.text('推荐歌单'), findsOneWidget);
    expect(find.text('百度 CarLife'), findsNothing);
    expect(find.byIcon(Icons.equalizer_rounded), findsOneWidget);
    // Navigation bar is always visible now (no collapse/expand handle).
    expect(find.byType(NavigationBar), findsOneWidget);

    // Bottom nav has 首页, 搜索, 音乐库, 设置 (no longer 播放)
    expect(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.byIcon(Icons.settings_rounded),
      ),
      findsOneWidget,
    );

    await tester.drag(find.byType(PageView), const Offset(-390, 0));
    await pumpUi();
    expect(find.text('搜索'), findsWidgets);

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('首页'),
      ),
    );
    await pumpUi();
    expect(find.text('想听什么？'), findsOneWidget);
    expect(find.text('推荐歌单'), findsOneWidget);

    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, -520),
      warnIfMissed: false,
    );
    await pumpUi();
    // 首页推荐歌单区提供音源切换（网易云/酷狗/QQ/酷我）
    expect(find.text('网易云'), findsWidgets);

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('音乐库'),
      ),
    );
    await pumpUi();

    expect(find.text('音乐库'), findsWidgets);
    expect(find.text('收藏'), findsWidgets);
    // Queue is a first-class tab now (was a trailing section titled 当前队列).
    expect(find.text('队列'), findsWidgets);
    expect(find.text('离线'), findsWidgets);

    // Enter player by tapping the mini player metadata area.
    await tester.tap(
      find.byKey(const ValueKey<String>('portrait-mini-player-open-area')),
    );
    await pumpUi();

    expect(find.text('Highway Morning'), findsOneWidget);
    expect(find.text('Native Radio'), findsOneWidget);
    expect(find.text('等待歌词同步'), findsOneWidget);
    expect(find.text('音乐库'), findsWidgets);

    await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded).first);
    await pumpUi();
    expect(find.text('音乐库'), findsWidgets);

    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, 420),
      warnIfMissed: false,
    );
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('设置'),
      ),
    );
    await pumpUi();

    expect(find.text('设置'), findsWidgets);
    expect(find.text('音效'), findsOneWidget);
    expect(find.text('AI智能音效'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('应用'),
      700,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('应用'), findsOneWidget);
    expect(find.text('检查更新'), findsOneWidget);
    expect(find.text('车载互联'), findsOneWidget);
    expect(find.text('百度 CarLife'), findsOneWidget);
    expect(find.text('Apple CarPlay'), findsOneWidget);
  });

  testWidgets('search history starts empty and records user queries', (
    WidgetTester tester,
  ) async {
    final TextEditingController controller = TextEditingController();
    int searchCount = 0;
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          body: PortraitSearchView(
            controller: controller,
            songs: const <FreeMusicSong>[],
            busy: false,
            loadMoreBusy: false,
            canLoadMore: false,
            error: '',
            loadMoreError: '',
            query: '',
            favoriteSongKeys: const <String>{},
            downloadedSongKeys: const <String>{},
            onSearch: () {
              searchCount += 1;
            },
            onLoadMore: () {},
            onPlay: (_) {},
            onAddToQueue: (_) {},
            onToggleFavorite: (_) {},
            onDownload: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('NIGHT DANCER'), findsNothing);
    expect(find.byTooltip('清空历史'), findsNothing);

    await tester.enterText(find.byType(TextField), '晴天');
    await tester.tap(find.text('搜索').last);
    await tester.pump();

    expect(searchCount, 1);
    expect(find.text('晴天'), findsWidgets);
    expect(find.byTooltip('清空历史'), findsOneWidget);
  });

  testWidgets('quality chips use the four display tiers without duplicates', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: const Scaffold(
          body: QualityChips(
            busy: false,
            error: '',
            qualities: <FreeMusicQuality>[
              FreeMusicQuality(name: '标准', bitrate: '48kaac'),
              FreeMusicQuality(name: '标准', bitrate: '100kogg'),
              FreeMusicQuality(name: '较高 128K', bitrate: '128kmp3'),
              FreeMusicQuality(name: '较高 128K', bitrate: '192kogg'),
            ],
          ),
        ),
      ),
    );

    expect(find.text('标准'), findsOneWidget);
    expect(find.text('较高'), findsOneWidget);
    expect(find.text('极高'), findsOneWidget);
    expect(find.text('较高 128K'), findsNothing);
    expect(find.text('192kogg'), findsNothing);
    expect(find.text('无损'), findsNothing);
  });

  testWidgets('player seek bar exposes a large draggable seek target', (
    WidgetTester tester,
  ) async {
    Duration? seekedPosition;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          body: PlayerSeekBar(
            position: const Duration(seconds: 10),
            bufferedPosition: const Duration(seconds: 30),
            duration: const Duration(seconds: 100),
            busy: false,
            onSeek: (Duration position) {
              seekedPosition = position;
            },
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(PlayerSeekBar)).height, 48);

    await tester.drag(find.byType(Slider), const Offset(180, 0));
    await tester.pumpAndSettle();

    expect(seekedPosition, isNotNull);
    expect(seekedPosition!, greaterThan(const Duration(seconds: 10)));
  });
}
