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
    expect(find.text('搜索音乐'), findsOneWidget);
    expect(find.text('推荐'), findsOneWidget);
    expect(find.text('百度 CarLife'), findsOneWidget);
    expect(find.text('正在播放'), findsOneWidget);
    expect(find.text('歌词'), findsOneWidget);
    expect(find.byIcon(Icons.system_update_rounded), findsOneWidget);
  });
}
