import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_car_app/models/app_update_info.dart';
import 'package:music_car_app/services/app_installer_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel(
    'music_car_app/app_installer_test',
  );
  final List<MethodCall> calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          calls.add(call);
          if (call.method == 'supportedAbis') {
            return <String>['arm64-v8a', 'armeabi-v7a'];
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('selectBestApkAsset prefers supported ABI', () async {
    const AppInstallerService service = AppInstallerService(channel: channel);

    final AppReleaseAsset? selected = await service
        .selectBestApkAsset(const <AppReleaseAsset>[
          AppReleaseAsset(
            name: 'app-x86_64-release.apk',
            downloadUrl: 'https://example.com/x86.apk',
            size: 1,
          ),
          AppReleaseAsset(
            name: 'app-arm64-v8a-release.apk',
            downloadUrl: 'https://example.com/arm64.apk',
            size: 1,
          ),
        ]);

    expect(selected?.downloadUrl, 'https://example.com/arm64.apk');
  });

  test('downloadAndInstallBestApk invokes native installer', () async {
    const AppInstallerService service = AppInstallerService(channel: channel);

    await service.downloadAndInstallBestApk(const <AppReleaseAsset>[
      AppReleaseAsset(
        name: 'app-release.apk',
        downloadUrl: 'https://example.com/app.apk',
        size: 1,
      ),
    ]);

    expect(calls.map((MethodCall call) => call.method), <String>[
      'supportedAbis',
      'downloadAndInstallApk',
    ]);
    expect(calls.last.arguments, <String, String>{
      'url': 'https://example.com/app.apk',
      'fileName': 'app-release.apk',
    });
  });
}
