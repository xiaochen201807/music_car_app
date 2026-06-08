import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/app_update_info.dart';

class AppInstallerService {
  const AppInstallerService({
    MethodChannel channel = const MethodChannel('music_car_app/app_installer'),
  }) : _channel = channel;

  final MethodChannel _channel;

  Future<void> downloadAndInstallBestApk(List<AppReleaseAsset> assets) async {
    final AppReleaseAsset? asset = await selectBestApkAsset(assets);
    if (asset == null) {
      throw const AppInstallerException('未找到可安装的 Android APK。');
    }

    await _channel.invokeMethod<void>('downloadAndInstallApk', <String, String>{
      'url': asset.downloadUrl,
      'fileName': asset.name,
    });
  }

  @visibleForTesting
  Future<AppReleaseAsset?> selectBestApkAsset(
    List<AppReleaseAsset> assets,
  ) async {
    final List<AppReleaseAsset> apkAssets = assets
        .where(
          (AppReleaseAsset asset) => asset.name.toLowerCase().endsWith('.apk'),
        )
        .toList();
    if (apkAssets.isEmpty) {
      return null;
    }

    final List<String> supportedAbis = await _supportedAbis();
    for (final String abi in supportedAbis) {
      final String normalizedAbi = abi.toLowerCase();
      for (final AppReleaseAsset asset in apkAssets) {
        if (asset.name.toLowerCase().contains(normalizedAbi)) {
          return asset;
        }
      }
    }

    return apkAssets.first;
  }

  Future<List<String>> _supportedAbis() async {
    try {
      final List<dynamic>? raw = await _channel.invokeMethod<List<dynamic>>(
        'supportedAbis',
      );
      return (raw ?? <dynamic>[])
          .map((dynamic value) => value.toString())
          .where((String value) => value.isNotEmpty)
          .toList();
    } catch (_) {
      return <String>[];
    }
  }
}

class AppInstallerException implements Exception {
  const AppInstallerException(this.message);

  final String message;

  @override
  String toString() => message;
}
