import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_car_app/main.dart';

void main() {
  testWidgets('renders the car music shell controls', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MusicCarApp(webViewOverride: ColoredBox(color: Colors.black)),
    );

    expect(find.byType(MusicCarWebViewPage), findsOneWidget);
    expect(find.byIcon(Icons.home), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsOneWidget);
    expect(find.byIcon(Icons.fullscreen), findsNWidgets(2));
  });
}
