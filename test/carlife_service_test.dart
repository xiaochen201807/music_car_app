import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_car_app/free_music_api.dart';
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
        'sdkLinked': true,
        'appKeyConfigured': false,
        'sdkInitialized': false,
        'sdkConnected': false,
        'packageName': 'com.baidu.carlife',
        'integrationMode': 'sdk_platform_unconfigured',
        'reason': 'app_key_missing',
      };
    });

    final CarLifeStatus status = await const CarLifeService(
      channel: channel,
    ).getStatus();

    expect(status.available, isTrue);
    expect(status.installed, isTrue);
    expect(status.launchable, isTrue);
    expect(status.sdkLinked, isTrue);
    expect(status.appKeyConfigured, isFalse);
    expect(status.sdkInitialized, isFalse);
    expect(status.sdkConnected, isFalse);
    expect(status.packageName, 'com.baidu.carlife');
    expect(status.displayText, 'SDK 待配置 AppKey');
  });

  test('getStatus displays connected SDK state', () async {
    messenger.setMockMethodCallHandler(channel, (MethodCall call) async {
      expect(call.method, 'getStatus');
      return <String, Object?>{
        'available': true,
        'installed': true,
        'launchable': true,
        'sdkLinked': true,
        'appKeyConfigured': true,
        'sdkInitialized': true,
        'sdkConnected': true,
        'packageName': 'com.baidu.carlife',
        'integrationMode': 'sdk_platform',
        'reason': 'sdk_connected',
      };
    });

    final CarLifeStatus status = await const CarLifeService(
      channel: channel,
    ).getStatus();

    expect(status.sdkLinked, isTrue);
    expect(status.sdkInitialized, isTrue);
    expect(status.sdkConnected, isTrue);
    expect(status.displayText, 'SDK 已连接');
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

  test('syncPlaybackContext sends full playback context', () async {
    messenger.setMockMethodCallHandler(channel, (MethodCall call) async {
      expect(call.method, 'syncPlaybackContext');
      final Map<Object?, Object?> arguments = (call.arguments as Map).cast();
      expect(arguments['title'], 'Highway Morning');
      expect(arguments['artist'], 'Native Radio');
      expect(arguments['album'], 'Drive Time');
      expect(arguments['coverUrl'], 'https://example.com/cover.jpg');
      expect(arguments['audioUrl'], 'https://example.com/audio.mp3');
      expect(arguments['source'], 'netease');
      expect(arguments['songId'], 'song-1');
      expect(arguments['playing'], isTrue);
      expect(arguments['durationMs'], 182000);
      expect(arguments['positionMs'], 42000);
      expect(arguments['queueIndex'], 1);
      final List<Object?> queue = arguments['queue'] as List<Object?>;
      expect(queue, hasLength(2));
      expect(queue.last, containsPair('name', 'Highway Morning'));
      return <String, Object?>{
        'supported': false,
        'reason': 'sdk_missing',
        'packageName': 'com.baidu.carlife',
        'integrationMode': 'context_cache',
        'syncedQueueLength': 2,
        'syncedQueueIndex': 1,
        'syncedTitle': 'Highway Morning',
      };
    });

    final CarLifeSyncResult result =
        await const CarLifeService(channel: channel).syncPlaybackContext(
          title: 'Highway Morning',
          artist: 'Native Radio',
          playing: true,
          context: const CarLifePlaybackContext(
            title: 'Highway Morning',
            artist: 'Native Radio',
            album: 'Drive Time',
            coverUrl: 'https://example.com/cover.jpg',
            audioUrl: 'https://example.com/audio.mp3',
            source: 'netease',
            songId: 'song-1',
            playing: true,
            duration: Duration(seconds: 182),
            position: Duration(seconds: 42),
            queueIndex: 1,
            queue: <FreeMusicSong>[
              FreeMusicSong(
                id: 'song-0',
                source: 'netease',
                name: 'Warm Start',
                artist: 'Native Radio',
                duration: 200,
              ),
              FreeMusicSong(
                id: 'song-1',
                source: 'netease',
                name: 'Highway Morning',
                artist: 'Native Radio',
                album: 'Drive Time',
                duration: 182,
                cover: 'https://example.com/cover.jpg',
              ),
            ],
          ),
        );

    expect(result.supported, isFalse);
    expect(result.reason, 'sdk_missing');
    expect(result.packageName, 'com.baidu.carlife');
    expect(result.integrationMode, 'context_cache');
    expect(result.syncedQueueLength, 2);
    expect(result.syncedQueueIndex, 1);
    expect(result.syncedTitle, 'Highway Morning');
  });

  test('setControlHandler handles native CarLife control callbacks', () async {
    final List<CarLifeControlCommand> commands = <CarLifeControlCommand>[];
    const CarLifeService(channel: channel).setControlHandler((
      CarLifeControlCommand command,
    ) async {
      commands.add(command);
      return CarLifeControlResult(
        handled: command.action != CarLifeControlAction.unknown,
        reason: command.action.value,
        queueIndex: command.queueIndex,
      );
    });

    final Completer<ByteData?> reply = Completer<ByteData?>();
    await messenger.handlePlatformMessage(
      channel.name,
      channel.codec.encodeMethodCall(
        const MethodCall('onCarLifeControl', <String, Object?>{
          'action': 'selectQueueItem',
          'queueIndex': 3,
          'source': 'kuwo',
          'songId': 'song-3',
        }),
      ),
      reply.complete,
    );

    final ByteData? encodedReply = await reply.future;
    final Object? decoded = channel.codec.decodeEnvelope(encodedReply!);
    final Map<Object?, Object?> response = (decoded as Map).cast();
    expect(response['handled'], isTrue);
    expect(response['reason'], 'selectQueueItem');
    expect(response['queueIndex'], 3);
    expect(commands, hasLength(1));
    expect(commands.single.action, CarLifeControlAction.selectQueueItem);
    expect(commands.single.source, 'kuwo');
    expect(commands.single.songId, 'song-3');
  });
}
