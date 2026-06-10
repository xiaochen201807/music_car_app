import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_car_app/main.dart';
import 'package:music_car_app/features/player/portrait_player_view.dart';

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

    await tester.ensureVisible(find.text('播放时间线'));
    await tester.pumpAndSettle();
    expect(find.text('播放时间线'), findsOneWidget);

    await tester.tap(find.text('音乐库'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('音乐库'), findsWidgets);
    expect(find.text('收藏'), findsWidgets);
    expect(find.text('当前队列'), findsOneWidget);

    // Enter player by tapping the mini player bar
    await tester.tap(find.byType(PortraitMiniPlayerBar));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('正在播放'), findsOneWidget);
    expect(find.text('等待歌词同步'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded).first);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, 420),
      warnIfMissed: false,
    );
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.byIcon(Icons.settings_rounded).first);
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('设置'), findsWidgets);
    expect(find.text('主题模式'), findsOneWidget);
    expect(find.text('百度 CarLife'), findsOneWidget);
  });
}
