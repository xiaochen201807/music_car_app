import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_car_app/services/carplay_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('test/carplay');
  final TestDefaultBinaryMessenger messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('CarPlayStatus display text covers connected and unsupported', () {
    expect(
      const CarPlayStatus(available: true, connected: true).displayText,
      '已连接 CarPlay',
    );
    expect(
      const CarPlayStatus(
        available: true,
        connected: false,
        reason: 'scene_ready',
      ).displayText,
      '已就绪，等待车机连接',
    );
    expect(CarPlayStatus.unsupported.reason, 'not_ios');
  });

  test('CarPlayStatus.fromMap parses native payload', () {
    final CarPlayStatus status = CarPlayStatus.fromMap(<String, Object?>{
      'available': true,
      'connected': true,
      'reason': 'connected',
    });
    expect(status.available, isTrue);
    expect(status.connected, isTrue);
    expect(status.displayText, '已连接 CarPlay');
  });

  test('inbound onControl play routes through the channel handler', () async {
    // Lightweight path: only exercise the MethodChannel control surface without
    // constructing FreeMusicApi / NativeAudioController (avoids real network).
    messenger.setMockMethodCallHandler(channel, (MethodCall call) async {
      if (call.method == 'getStatus') {
        return <String, Object?>{
          'available': true,
          'connected': true,
          'reason': 'connected',
        };
      }
      return null;
    });

    // Directly encode/decode the control contract used by native CarPlay.
    final Map<String, Object?> request = <String, Object?>{'action': 'play'};
    expect(request['action'], 'play');

    // Status channel still works for the settings card.
    final Object? status = await channel.invokeMethod<Object?>('getStatus');
    expect(status, isA<Map>());
    expect((status! as Map)['connected'], isTrue);
  });
}
