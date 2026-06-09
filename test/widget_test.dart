import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_car_app/main.dart';

void main() {
  testWidgets('renders the native car music shell', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MusicCarApp(autoCheckForUpdates: false));

    expect(find.byType(NativeMusicHomePage), findsOneWidget);
    expect(find.text('车载音乐'), findsOneWidget);
    expect(find.text('搜索音乐'), findsWidgets);
    expect(find.text('推荐'), findsWidgets);
    expect(find.text('在线曲库'), findsOneWidget);
    expect(find.text('百度 CarLife'), findsNothing);
    expect(find.text('正在播放'), findsWidgets);
    expect(find.text('歌词'), findsOneWidget);
    expect(find.byIcon(Icons.system_update_rounded), findsOneWidget);

    await tester.tap(find.text('播放队列').first);
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('播放队列'), findsWidgets);
    expect(find.text('清空'), findsOneWidget);
    expect(find.text('编辑'), findsOneWidget);

    await tester.tap(find.text('正在播放').first);
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('等待品质信息'), findsOneWidget);
    expect(find.text('暂无当前歌词'), findsOneWidget);

    await tester.tap(find.text('设置'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('百度 CarLife'), findsOneWidget);
  });
}
