import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:music_car_app/models/app_update_info.dart';
import 'package:music_car_app/services/app_installer_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel(
    'music_car_app/app_installer_test',
  );
  final List<MethodCall> calls = <MethodCall>[];
  Directory? tempDir;

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
    tempDir?.deleteSync(recursive: true);
    tempDir = null;
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

  test('downloadAndInstallBestApk downloads before native installer', () async {
    tempDir = await Directory.systemTemp.createTemp('app_installer_test_');
    final List<AppInstallProgress> progress = <AppInstallProgress>[];
    final http.Client httpClient = _FakeHttpClient(
      bodyChunks: <List<int>>[
        <int>[1, 2],
        <int>[3, 4],
      ],
      contentLength: 4,
    );
    final AppInstallerService service = AppInstallerService(
      channel: channel,
      httpClient: httpClient,
      temporaryDirectoryProvider: () async => tempDir!,
    );

    await service.downloadAndInstallBestApk(const <AppReleaseAsset>[
      AppReleaseAsset(
        name: 'app-release.apk',
        downloadUrl: 'https://example.com/app.apk',
        size: 1,
      ),
    ], onProgress: progress.add);

    expect(calls.map((MethodCall call) => call.method), <String>[
      'supportedAbis',
      'ensureInstallPermission',
      'installApkFile',
    ]);
    final Map<dynamic, dynamic> arguments =
        calls.last.arguments as Map<dynamic, dynamic>;
    expect(arguments['fileName'], 'app-release.apk');
    expect(arguments['filePath'], endsWith('/app_updates/app-release.apk'));
    expect(File(arguments['filePath'] as String).readAsBytesSync(), <int>[
      1,
      2,
      3,
      4,
    ]);
    expect(progress.map((AppInstallProgress item) => item.percent), <int?>[
      0,
      50,
      100,
      100,
    ]);
    expect(progress.last.stage, AppInstallProgressStage.openingInstaller);
  });

  test('installDownloadedApkFile invokes native local installer', () async {
    const AppInstallerService service = AppInstallerService(channel: channel);

    await service.installDownloadedApkFile(
      '/tmp/app.apk',
      fileName: 'app-release.apk',
    );

    expect(calls.last.method, 'installApkFile');
    expect(calls.last.arguments, <String, String>{
      'filePath': '/tmp/app.apk',
      'fileName': 'app-release.apk',
    });
  });

  test('sanitizeApkFileName keeps installer path safe', () {
    expect(AppInstallerService.sanitizeApkFileName('车载 音乐.apk'), '-----.apk');
    expect(AppInstallerService.sanitizeApkFileName('release'), 'release.apk');
  });
}

class _FakeHttpClient extends http.BaseClient {
  _FakeHttpClient({required this.bodyChunks, required this.contentLength});

  final List<List<int>> bodyChunks;
  final int contentLength;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream<List<int>>.fromIterable(bodyChunks),
      200,
      contentLength: contentLength,
    );
  }
}
