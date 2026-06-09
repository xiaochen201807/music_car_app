import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_car_app/services/carlife_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('test/carlife');
  final TestDefaultBinaryMessenger messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('getStatus parses native CarLife status payload', () async {
    messenger.setMockMethodCallHandler(channel, (MethodCall call) async {
      expect(call.method, 'getStatus');
      return <String, Object?>{
        'available': true,
        'installed': true,
        'launchable': true,
        'sdkLinked': false,
        'packageName': 'com.baidu.carlife',
        'integrationMode': 'package_probe',
        'reason': 'sdk_missing',
      };
    });

    final CarLifeStatus status = await const CarLifeService(
      channel: channel,
    ).getStatus();

    expect(status.available, isTrue);
    expect(status.installed, isTrue);
    expect(status.launchable, isTrue);
    expect(status.sdkLinked, isFalse);
    expect(status.packageName, 'com.baidu.carlife');
    expect(status.displayText, '已安装，可拉起');
  });

  test('openCarLife parses launch result', () async {
    messenger.setMockMethodCallHandler(channel, (MethodCall call) async {
      expect(call.method, 'openCarLife');
      return <String, Object?>{
        'launched': true,
        'packageName': 'com.baidu.carlife',
        'reason': 'launched',
      };
    });

    final CarLifeLaunchResult result = await const CarLifeService(
      channel: channel,
    ).openCarLife();

    expect(result.launched, isTrue);
    expect(result.packageName, 'com.baidu.carlife');
    expect(result.reason, 'launched');
  });

  test('syncPlaybackContext reports unsupported placeholder', () async {
    messenger.setMockMethodCallHandler(channel, (MethodCall call) async {
      expect(call.method, 'syncPlaybackContext');
      expect(call.arguments, containsPair('title', 'Highway Morning'));
      return <String, Object?>{'supported': false, 'reason': 'sdk_missing'};
    });

    final CarLifeSyncResult result =
        await const CarLifeService(channel: channel).syncPlaybackContext(
          title: 'Highway Morning',
          artist: 'Native Radio',
          playing: true,
        );

    expect(result.supported, isFalse);
    expect(result.reason, 'sdk_missing');
  });
}
