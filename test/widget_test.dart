import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
    expect(find.text('Portrait streaming deck'), findsOneWidget);
    expect(find.text('推荐歌单'), findsOneWidget);
    expect(find.text('百度 CarLife'), findsNothing);
    expect(find.text('播放'), findsOneWidget);
    expect(find.byIcon(Icons.lyrics_rounded), findsOneWidget);
    expect(find.byIcon(Icons.settings_rounded), findsOneWidget);

    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, -420),
    );
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('播放时间线'), findsOneWidget);

    await tester.tap(find.text('音乐库'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('音乐库'), findsWidgets);
    expect(find.text('收藏'), findsWidgets);
    expect(find.text('当前队列'), findsOneWidget);

    await tester.tap(find.text('播放'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('正在播放'), findsOneWidget);
    expect(find.text('等待品质信息'), findsOneWidget);
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

    expect(find.text('设置'), findsOneWidget);
    expect(find.text('主题模式'), findsOneWidget);
    expect(find.text('百度 CarLife'), findsOneWidget);
  });
}
