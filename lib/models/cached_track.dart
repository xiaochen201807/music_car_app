class CachedTrack {
  const CachedTrack({
    required this.source,
    required this.id,
    required this.localPath,
    required this.fileSize,
    required this.quality,
    required this.title,
    required this.artist,
    required this.cover,
    required this.duration,
  });

  final String source;
  final String id;
  final String localPath; // 存储相对路径，防止应用沙盒路径变化导致失效
  final int fileSize;
  final String quality;
  final String title;
  final String artist;
  final String cover;
  final int duration;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'source': source,
        'id': id,
        'localPath': localPath,
        'fileSize': fileSize,
        'quality': quality,
        'title': title,
        'artist': artist,
        'cover': cover,
        'duration': duration,
      };

  factory CachedTrack.fromJson(Map<String, dynamic> json) => CachedTrack(
        source: json['source'] as String,
        id: json['id'] as String,
        localPath: json['localPath'] as String,
        fileSize: json['fileSize'] as int,
        quality: json['quality'] as String,
        title: json['title'] as String? ?? '',
        artist: json['artist'] as String? ?? '',
        cover: json['cover'] as String? ?? '',
        duration: json['duration'] as int? ?? 0,
      );
}
