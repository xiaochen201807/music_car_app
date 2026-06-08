import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:music_car_app/services/update_check_service.dart';

void main() {
  test('checkLatestReleaseForVersion parses update manifest first', () async {
    final UpdateCheckService service = UpdateCheckService(
      updateManifestUrl: 'https://download.example.com/music-car/update.json',
      client: MockClient((http.Request request) async {
        expect(
          request.url.toString(),
          'https://download.example.com/music-car/update.json',
        );
        return http.Response('''
{
  "versionName": "1.0.2",
  "tagName": "v1.0.2",
  "releaseName": "music_car_app v1.0.2",
  "releaseUrl": "https://github.com/xiaoguan521/music_car_app/releases/tag/v1.0.2",
  "publishedAt": "2026-06-08T00:00:00Z",
  "assets": [
    {
      "name": "app-release.apk",
      "url": "https://download.example.com/music-car/v1.0.2/app-release.apk",
      "size": 12345678,
      "abi": "arm64-v8a",
      "sha256": "abc123",
      "fallbackUrls": [
        "https://github.com/xiaoguan521/music_car_app/releases/download/v1.0.2/app-release.apk"
      ]
    }
  ]
}
''', 200);
      }),
    );

    final updateInfo = await service.checkLatestReleaseForVersion(
      currentVersion: '1.0.0+1',
    );

    expect(updateInfo.hasUpdate, isTrue);
    expect(updateInfo.latestVersion, '1.0.2');
    expect(updateInfo.releaseName, 'music_car_app v1.0.2');
    expect(updateInfo.apkAssets.single.abi, 'arm64-v8a');
    expect(
      updateInfo.apkAssets.single.downloadUrl,
      'https://download.example.com/music-car/v1.0.2/app-release.apk',
    );
    expect(updateInfo.apkAssets.single.fallbackUrls.single, contains('github'));
    expect(updateInfo.apkAssets.single.sha256, 'abc123');

    service.dispose();
  });

  test(
    'checkLatestReleaseForVersion falls back to GitHub latest release',
    () async {
      final UpdateCheckService service = UpdateCheckService(
        client: MockClient((http.Request request) async {
          expect(
            request.url.toString(),
            'https://api.github.com/repos/xiaoguan521/music_car_app/releases/latest',
          );
          return http.Response('''
{
  "tag_name": "v1.0.3",
  "name": "music_car_app v1.0.3",
  "html_url": "https://github.com/xiaoguan521/music_car_app/releases/tag/v1.0.3",
  "published_at": "2026-06-08T00:00:00Z",
  "assets": [
    {
      "name": "app-release.apk",
      "browser_download_url": "https://github.com/xiaoguan521/music_car_app/releases/download/v1.0.3/app-release.apk",
      "size": 1000
    },
    {
      "name": "notes.txt",
      "browser_download_url": "https://example.com/notes.txt",
      "size": 20
    }
  ]
}
''', 200);
        }),
      );

      final updateInfo = await service.checkLatestReleaseForVersion(
        currentVersion: '1.0.2',
      );

      expect(updateInfo.hasUpdate, isTrue);
      expect(updateInfo.latestVersion, '1.0.3');
      expect(updateInfo.apkAssets, hasLength(1));
      expect(updateInfo.apkAssets.single.name, 'app-release.apk');

      service.dispose();
    },
  );

  test('compareVersions handles v-prefix and build numbers', () {
    expect(UpdateCheckService.compareVersions('v1.0.10', '1.0.5+6'), 1);
    expect(UpdateCheckService.compareVersions('1.0.5', 'v1.0.5'), 0);
    expect(UpdateCheckService.compareVersions('1.0.4', '1.0.5'), -1);
  });
}
