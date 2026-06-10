import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

    await tester.pumpWidget(const MusicCarApp(autoCheckForUpdates: false));

    expect(find.byType(NativeMusicHomePage), findsOneWidget);
    expect(find.text('Music Car'), findsOneWidget);
    expect(find.text('Portrait streaming deck'), findsNothing);
    expect(find.text('推荐歌单'), findsOneWidget);
    expect(find.text('百度 CarLife'), findsNothing);
    // Bottom nav has 首页, 搜索, 音乐库, 设置 (no longer 播放)
    expect(find.byIcon(Icons.equalizer_rounded), findsOneWidget);
    expect(find.byIcon(Icons.settings_rounded), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(-390, 0));
    await tester.pumpAndSettle();
    expect(find.text('搜索'), findsWidgets);

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('首页'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Music Car'), findsOneWidget);

    await tester.ensureVisible(find.text('播放时间线'));
    await tester.pumpAndSettle();
    expect(find.text('播放时间线'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('音乐库'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('音乐库'), findsWidgets);
    expect(find.text('收藏'), findsWidgets);
    expect(find.text('当前队列'), findsOneWidget);

    // Enter player by tapping the mini player metadata area.
    await tester.tap(
      find.byKey(const ValueKey<String>('portrait-mini-player-open-area')),
    );
    await tester.pumpAndSettle();

    expect(find.text('正在播放'), findsOneWidget);
    expect(find.text('等待歌词同步'), findsOneWidget);
    expect(find.text('音乐库'), findsWidgets);

    await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded).first);
    await tester.pumpAndSettle();
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
    await tester.pumpAndSettle();

    expect(find.text('设置'), findsWidgets);
    expect(find.text('主题模式'), findsOneWidget);
    await tester.drag(
      find.text('默认音质'),
      const Offset(0, -520),
      warnIfMissed: false,
    );
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('关于'), findsOneWidget);
    expect(find.text('检查更新'), findsOneWidget);
    expect(find.text('百度 CarLife'), findsNothing);
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
}
