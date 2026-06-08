import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../models/app_update_info.dart';

class UpdateCheckService {
  UpdateCheckService({http.Client? client, String? updateManifestUrl})
    : _client = client ?? http.Client(),
      _updateManifestUrl =
          updateManifestUrl ??
          const String.fromEnvironment('MUSIC_CAR_UPDATE_MANIFEST_URL');

  static const String _latestReleaseEndpoint =
      'https://api.github.com/repos/xiaoguan521/music_car_app/releases/latest';

  final http.Client _client;
  final String _updateManifestUrl;

  Future<AppUpdateInfo> checkLatestRelease({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final PackageInfo packageInfo = await PackageInfo.fromPlatform();
    return checkLatestReleaseForVersion(
      currentVersion: packageInfo.version,
      timeout: timeout,
    );
  }

  Future<AppUpdateInfo> checkLatestReleaseForVersion({
    required String currentVersion,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    if (_updateManifestUrl.trim().isNotEmpty) {
      try {
        return await _checkUpdateManifestForVersion(
          currentVersion: currentVersion,
          timeout: timeout,
        );
      } catch (_) {}
    }

    return _checkGitHubLatestReleaseForVersion(
      currentVersion: currentVersion,
      timeout: timeout,
    );
  }

  Future<AppUpdateInfo> _checkUpdateManifestForVersion({
    required String currentVersion,
    required Duration timeout,
  }) async {
    final http.Response response = await _client
        .get(Uri.parse(_updateManifestUrl.trim()))
        .timeout(timeout);

    if (response.statusCode != 200) {
      throw UpdateCheckException('检查更新失败，HTTP ${response.statusCode}');
    }

    final Map<String, dynamic> payload = _decodeJsonObject(response.body);
    final String latestVersion = normalizeVersion(
      _firstText(<Object?>[
        payload['versionName'],
        payload['latestVersion'],
        payload['tagName'],
        payload['tag_name'],
      ]),
    );
    if (latestVersion.isEmpty) {
      throw const UpdateCheckException('最新版本信息为空。');
    }

    return AppUpdateInfo(
      currentVersion: normalizeVersion(currentVersion),
      latestVersion: latestVersion,
      releaseUrl: _firstText(<Object?>[
        payload['releaseUrl'],
        payload['html_url'],
      ]),
      releaseName: _firstText(<Object?>[
        payload['releaseName'],
        payload['name'],
        payload['tagName'],
      ]),
      publishedAt: DateTime.tryParse(
        _firstText(<Object?>[payload['publishedAt'], payload['published_at']]),
      ),
      apkAssets: _parseManifestApkAssets(payload['assets']),
      hasUpdate: compareVersions(latestVersion, currentVersion) > 0,
    );
  }

  Future<AppUpdateInfo> _checkGitHubLatestReleaseForVersion({
    required String currentVersion,
    required Duration timeout,
  }) async {
    final http.Response response = await _client
        .get(
          Uri.parse(_latestReleaseEndpoint),
          headers: const <String, String>{
            'Accept': 'application/vnd.github+json',
            'X-GitHub-Api-Version': '2022-11-28',
          },
        )
        .timeout(timeout);

    if (response.statusCode != 200) {
      throw UpdateCheckException('检查更新失败，HTTP ${response.statusCode}');
    }

    final Map<String, dynamic> payload = _decodeJsonObject(response.body);
    final String tagName = (payload['tag_name'] ?? '').toString().trim();
    final String latestVersion = normalizeVersion(tagName);
    if (latestVersion.isEmpty) {
      throw const UpdateCheckException('最新版本信息为空。');
    }

    return AppUpdateInfo(
      currentVersion: normalizeVersion(currentVersion),
      latestVersion: latestVersion,
      releaseUrl: (payload['html_url'] ?? '').toString(),
      releaseName: (payload['name'] ?? tagName).toString(),
      publishedAt: DateTime.tryParse(
        (payload['published_at'] ?? '').toString(),
      ),
      apkAssets: _parseApkAssets(payload['assets']),
      hasUpdate: compareVersions(latestVersion, currentVersion) > 0,
    );
  }

  void dispose() {
    _client.close();
  }

  static String normalizeVersion(String value) {
    String normalized = value.trim();
    if (normalized.startsWith('refs/tags/')) {
      normalized = normalized.substring('refs/tags/'.length);
    }
    if (normalized.startsWith('v') || normalized.startsWith('V')) {
      normalized = normalized.substring(1);
    }
    final int buildIndex = normalized.indexOf('+');
    if (buildIndex != -1) {
      normalized = normalized.substring(0, buildIndex);
    }
    return normalized.trim();
  }

  static int compareVersions(String left, String right) {
    final List<int> leftParts = _versionParts(left);
    final List<int> rightParts = _versionParts(right);
    final int length = leftParts.length > rightParts.length
        ? leftParts.length
        : rightParts.length;

    for (int index = 0; index < length; index += 1) {
      final int leftValue = index < leftParts.length ? leftParts[index] : 0;
      final int rightValue = index < rightParts.length ? rightParts[index] : 0;
      if (leftValue != rightValue) {
        return leftValue.compareTo(rightValue);
      }
    }

    return 0;
  }

  static List<int> _versionParts(String version) {
    final Iterable<RegExpMatch> matches = RegExp(
      r'\d+',
    ).allMatches(normalizeVersion(version));
    return matches
        .map((RegExpMatch match) => int.tryParse(match.group(0) ?? '') ?? 0)
        .toList();
  }

  static Map<String, dynamic> _decodeJsonObject(String raw) {
    final Object decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.map<String, dynamic>(
        (dynamic key, dynamic value) => MapEntry(key.toString(), value),
      );
    }
    throw const UpdateCheckException('更新响应不是对象。');
  }

  static List<AppReleaseAsset> _parseApkAssets(Object? rawAssets) {
    final List<dynamic> assets = rawAssets is List ? rawAssets : <dynamic>[];
    return assets
        .whereType<Map>()
        .map(
          (Map<dynamic, dynamic> raw) => raw.map<String, dynamic>(
            (dynamic key, dynamic value) => MapEntry(key.toString(), value),
          ),
        )
        .where((Map<String, dynamic> asset) {
          final String name = (asset['name'] ?? '').toString().toLowerCase();
          return name.endsWith('.apk');
        })
        .map(
          (Map<String, dynamic> asset) => AppReleaseAsset(
            name: (asset['name'] ?? '').toString(),
            downloadUrl: (asset['browser_download_url'] ?? '').toString(),
            size: asset['size'] is int ? asset['size'] as int : 0,
          ),
        )
        .where((AppReleaseAsset asset) => asset.downloadUrl.isNotEmpty)
        .toList();
  }

  static List<AppReleaseAsset> _parseManifestApkAssets(Object? rawAssets) {
    final List<dynamic> assets = rawAssets is List ? rawAssets : <dynamic>[];
    return assets
        .whereType<Map>()
        .map(
          (Map<dynamic, dynamic> raw) => raw.map<String, dynamic>(
            (dynamic key, dynamic value) => MapEntry(key.toString(), value),
          ),
        )
        .where((Map<String, dynamic> asset) {
          final String name = (asset['name'] ?? '').toString().toLowerCase();
          return name.endsWith('.apk');
        })
        .map((Map<String, dynamic> asset) {
          final Object? rawFallbackUrls = asset['fallbackUrls'];
          final List<String> fallbackUrls = rawFallbackUrls is List
              ? rawFallbackUrls
                    .map((dynamic value) => value.toString())
                    .where((String value) => value.trim().isNotEmpty)
                    .toList()
              : const <String>[];
          return AppReleaseAsset(
            name: (asset['name'] ?? '').toString(),
            downloadUrl: _firstText(<Object?>[
              asset['url'],
              asset['downloadUrl'],
              asset['browser_download_url'],
            ]),
            size: asset['size'] is int ? asset['size'] as int : 0,
            abi: (asset['abi'] ?? '').toString(),
            sha256: (asset['sha256'] ?? '').toString(),
            fallbackUrls: fallbackUrls,
          );
        })
        .where((AppReleaseAsset asset) => asset.downloadUrl.isNotEmpty)
        .toList();
  }

  static String _firstText(List<Object?> values) {
    for (final Object? value in values) {
      final String text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) {
        return text;
      }
    }
    return '';
  }
}

class UpdateCheckException implements Exception {
  const UpdateCheckException(this.message);

  final String message;

  @override
  String toString() => message;
}
