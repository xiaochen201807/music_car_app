import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/app_update_info.dart';

class AppInstallerService {
  const AppInstallerService({
    MethodChannel channel = const MethodChannel('music_car_app/app_installer'),
    http.Client? httpClient,
    Future<Directory> Function()? temporaryDirectoryProvider,
  }) : _channel = channel,
       _httpClient = httpClient,
       _temporaryDirectoryProvider = temporaryDirectoryProvider;

  final MethodChannel _channel;
  final http.Client? _httpClient;
  final Future<Directory> Function()? _temporaryDirectoryProvider;

  Future<void> downloadAndInstallBestApk(
    List<AppReleaseAsset> assets, {
    ValueChanged<AppInstallProgress>? onProgress,
  }) async {
    final AppReleaseAsset? asset = await selectBestApkAsset(assets);
    if (asset == null) {
      throw const AppInstallerException('未找到可安装的 Android APK。');
    }

    await ensureInstallPermission();
    final File apkFile = await _downloadApkAsset(asset, onProgress);
    onProgress?.call(
      AppInstallProgress.openingInstaller(
        assetName: asset.name,
        downloadedBytes: await apkFile.length(),
        totalBytes: asset.size > 0 ? asset.size : await apkFile.length(),
      ),
    );
    await installDownloadedApkFile(apkFile.path, fileName: asset.name);
  }

  @visibleForTesting
  Future<void> ensureInstallPermission() async {
    await _channel.invokeMethod<void>('ensureInstallPermission');
  }

  @visibleForTesting
  Future<void> installDownloadedApkFile(
    String filePath, {
    String fileName = '',
  }) async {
    await _channel.invokeMethod<void>('installApkFile', <String, String>{
      'filePath': filePath,
      'fileName': fileName,
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

  Future<File> _downloadApkAsset(
    AppReleaseAsset asset,
    ValueChanged<AppInstallProgress>? onProgress,
  ) async {
    final List<String> urls = <String>[
      asset.downloadUrl,
      ...asset.fallbackUrls,
    ].where((String url) => url.trim().isNotEmpty).toList();
    if (urls.isEmpty) {
      throw const AppInstallerException('APK 下载地址为空。');
    }

    Object? lastError;
    for (final String url in urls) {
      try {
        return await _downloadApkFromUrl(url, asset, onProgress);
      } catch (error) {
        lastError = error;
      }
    }

    if (lastError is AppInstallerException) {
      throw lastError;
    }
    throw AppInstallerException('下载安装包失败：$lastError');
  }

  Future<File> _downloadApkFromUrl(
    String url,
    AppReleaseAsset asset,
    ValueChanged<AppInstallProgress>? onProgress,
  ) async {
    final Directory updateDir = await _updateDirectory();
    final File outputFile = File(
      '${updateDir.path}/${sanitizeApkFileName(asset.name)}',
    );
    if (await outputFile.exists()) {
      await outputFile.delete();
    }

    final http.Client client = _httpClient ?? http.Client();
    IOSink? output;
    try {
      final http.Request request = http.Request('GET', Uri.parse(url));
      final http.StreamedResponse response = await client.send(request);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AppInstallerException('下载安装包失败：HTTP ${response.statusCode}');
      }

      final int totalBytes = response.contentLength ?? asset.size;
      var downloadedBytes = 0;
      output = outputFile.openWrite();
      onProgress?.call(
        AppInstallProgress.downloading(
          assetName: asset.name,
          downloadedBytes: downloadedBytes,
          totalBytes: totalBytes,
        ),
      );
      await for (final List<int> chunk in response.stream) {
        downloadedBytes += chunk.length;
        output.add(chunk);
        onProgress?.call(
          AppInstallProgress.downloading(
            assetName: asset.name,
            downloadedBytes: downloadedBytes,
            totalBytes: totalBytes,
          ),
        );
      }
      await output.close();
      output = null;

      if (downloadedBytes <= 0) {
        throw const AppInstallerException('下载完成但安装包为空。');
      }
      return outputFile;
    } catch (_) {
      try {
        await output?.close();
      } catch (_) {}
      if (await outputFile.exists()) {
        await outputFile.delete();
      }
      rethrow;
    } finally {
      if (_httpClient == null) {
        client.close();
      }
    }
  }

  Future<Directory> _updateDirectory() async {
    final Future<Directory> Function()? temporaryDirectoryProvider =
        _temporaryDirectoryProvider;
    final Directory cacheDir = temporaryDirectoryProvider == null
        ? await getTemporaryDirectory()
        : await temporaryDirectoryProvider();
    final Directory updateDir = Directory('${cacheDir.path}/app_updates');
    if (!await updateDir.exists()) {
      await updateDir.create(recursive: true);
    }
    return updateDir;
  }

  @visibleForTesting
  static String sanitizeApkFileName(String fileName) {
    final String normalized = fileName.trim().isEmpty
        ? 'music-car-app-update.apk'
        : fileName.trim().replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '-');
    if (normalized.toLowerCase().endsWith('.apk')) {
      return normalized;
    }
    return '$normalized.apk';
  }
}

enum AppInstallProgressStage { downloading, openingInstaller }

class AppInstallProgress {
  const AppInstallProgress({
    required this.stage,
    required this.assetName,
    required this.downloadedBytes,
    required this.totalBytes,
  });

  factory AppInstallProgress.downloading({
    required String assetName,
    required int downloadedBytes,
    required int totalBytes,
  }) {
    return AppInstallProgress(
      stage: AppInstallProgressStage.downloading,
      assetName: assetName,
      downloadedBytes: downloadedBytes,
      totalBytes: totalBytes,
    );
  }

  factory AppInstallProgress.openingInstaller({
    required String assetName,
    required int downloadedBytes,
    required int totalBytes,
  }) {
    return AppInstallProgress(
      stage: AppInstallProgressStage.openingInstaller,
      assetName: assetName,
      downloadedBytes: downloadedBytes,
      totalBytes: totalBytes,
    );
  }

  final AppInstallProgressStage stage;
  final String assetName;
  final int downloadedBytes;
  final int totalBytes;

  double? get fraction {
    if (totalBytes <= 0) {
      return null;
    }
    return (downloadedBytes / totalBytes).clamp(0, 1).toDouble();
  }

  int? get percent {
    final double? value = fraction;
    if (value == null) {
      return null;
    }
    return (value * 100).round().clamp(0, 100);
  }
}

class AppInstallerException implements Exception {
  const AppInstallerException(this.message);

  final String message;

  @override
  String toString() => message;
}
