import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:music_car_app/free_music_api.dart';
import 'package:music_car_app/models/cached_track.dart';
import 'package:music_car_app/services/download_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel(
    'plugins.flutter.io/path_provider',
  );
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (MethodCall methodCall) async => '.',
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('DownloadService can init with empty cache', () async {
    final FreeMusicApi api = FreeMusicApi();
    final DownloadService service = DownloadService(api);

    await service.init();
    expect(service.getAllCachedTracks(), isEmpty);
  });

  test('DownloadService restores cached tracks from shared preferences', () async {
    const CachedTrack cached = CachedTrack(
      source: 'kuwo',
      id: '123',
      localPath: 'test/lyrics_sync_test.dart',
      fileSize: 100,
      quality: 'HQ',
      title: '测试歌曲',
      artist: '歌手',
      cover: '',
      duration: 120,
    );

    SharedPreferences.setMockInitialValues(<String, Object>{
      'cached_tracks': <String>[jsonEncode(cached.toJson())],
    });

    final FreeMusicApi api = FreeMusicApi();
    final DownloadService service = DownloadService(api);
    await service.init();

    expect(service.getAllCachedTracks(), hasLength(1));
    expect(service.isDownloaded('kuwo', '123'), isTrue);
    expect(service.getCachedTrack('kuwo', '123')?.title, '测试歌曲');
  });
}
