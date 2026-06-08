class AppUpdateInfo {
  const AppUpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseUrl,
    required this.releaseName,
    required this.publishedAt,
    required this.apkAssets,
    required this.hasUpdate,
  });

  final String currentVersion;
  final String latestVersion;
  final String releaseUrl;
  final String releaseName;
  final DateTime? publishedAt;
  final List<AppReleaseAsset> apkAssets;
  final bool hasUpdate;

  bool get hasDownloadAssets => apkAssets.isNotEmpty;
}

class AppReleaseAsset {
  const AppReleaseAsset({
    required this.name,
    required this.downloadUrl,
    required this.size,
    this.abi = '',
    this.sha256 = '',
    this.fallbackUrls = const <String>[],
  });

  final String name;
  final String downloadUrl;
  final int size;
  final String abi;
  final String sha256;
  final List<String> fallbackUrls;

  String get sizeText {
    if (size <= 0) {
      return '';
    }
    final double mib = size / 1024 / 1024;
    return '${mib.toStringAsFixed(mib >= 10 ? 0 : 1)} MB';
  }
}
