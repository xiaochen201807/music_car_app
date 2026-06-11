import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../free_music_api.dart';
import '../models/cached_track.dart';

class DownloadService {
  DownloadService(this._api);

  final FreeMusicApi _api;
  final Map<String, CachedTrack> _cacheMap = <String, CachedTrack>{};
  final Set<String> _downloadingKeys = <String>{};
  late final SharedPreferences _prefs;
  bool _initialized = false;

  static String _cacheKey(String source, String id) => '${source}_$id';

  Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    final List<String> cachedList =
        _prefs.getStringList('cached_tracks') ?? <String>[];

    final Directory appDir = await getApplicationDocumentsDirectory();
    final String appDirPath = appDir.path;

    for (final String jsonStr in cachedList) {
      try {
        final Map<String, dynamic> map =
            jsonDecode(jsonStr) as Map<String, dynamic>;
        final CachedTrack track = CachedTrack.fromJson(map);

        final File file = File('$appDirPath/${track.localPath}');
        if (await file.exists()) {
          _cacheMap[_cacheKey(track.source, track.id)] = track;
        }
      } catch (_) {}
    }
    _initialized = true;
    await _saveToPrefs();
    unawaited(_cleanupDirtyCacheFiles(appDirPath));
  }

  Future<void> _cleanupDirtyCacheFiles(String appDirPath) async {
    try {
      final Directory downloadDir = Directory('$appDirPath/music_downloads');
      if (await downloadDir.exists()) {
        final List<FileSystemEntity> files = await downloadDir.list().toList();
        for (final FileSystemEntity entity in files) {
          if (entity is File && entity.path.endsWith('.mp3')) {
            final String fileName = entity.path.split('/').last;
            final RegExp reg = RegExp(r'music_cache_(.+?)_(.+?)\.mp3$');
            final Match? match = reg.firstMatch(fileName);
            if (match != null) {
              final String source = match.group(1)!;
              final String id = match.group(2)!;
              final String key = _cacheKey(source, id);
              if (!_cacheMap.containsKey(key)) {
                await entity.delete();
              }
            }
          }
        }
      }
    } catch (_) {}
  }

  bool isDownloaded(String source, String id) {
    return _cacheMap.containsKey(_cacheKey(source, id));
  }

  CachedTrack? getCachedTrack(String source, String id) {
    return _cacheMap[_cacheKey(source, id)];
  }

  Future<String> getPhysicalPath(CachedTrack track) async {
    final Directory appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/${track.localPath}';
  }

  List<CachedTrack> getAllCachedTracks() {
    return _cacheMap.values.toList();
  }

  Future<void> _saveToPrefs() async {
    final List<String> list =
        _cacheMap.values
            .map((CachedTrack t) => jsonEncode(t.toJson()))
            .toList();
    await _prefs.setStringList('cached_tracks', list);
  }

  Future<void> deleteTrack(String source, String id) async {
    final String key = _cacheKey(source, id);
    final CachedTrack? track = _cacheMap[key];
    if (track == null) return;

    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final File file = File('${appDir.path}/${track.localPath}');
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}

    _cacheMap.remove(key);
    await _saveToPrefs();
  }

  Future<void> clearAll() async {
    final Directory appDir = await getApplicationDocumentsDirectory();
    for (final CachedTrack track in _cacheMap.values) {
      try {
        final File file = File('${appDir.path}/${track.localPath}');
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
    }
    _cacheMap.clear();
    await _saveToPrefs();
  }

  Stream<double> downloadTrack(FreeMusicSong song, FreeMusicQuality quality) {
    final StreamController<double> controller = StreamController<double>();
    final String key = _cacheKey(song.source, song.id);

    if (_downloadingKeys.contains(key)) {
      controller.addError(Exception('该歌曲正在下载中，请勿重复操作'));
      controller.close();
      return controller.stream;
    }
    _downloadingKeys.add(key);

    unawaited(
      () async {
        try {
          final FreeMusicResolvedUrl? resolved = await _api.resolveSongUrl(
            song,
            bitrate: quality.bitrate,
          );
          final String? url = resolved?.url;
          if (url == null || url.isEmpty) {
            throw Exception('无法解析该音质的下载地址');
          }

          final Directory appDir = await getApplicationDocumentsDirectory();
          final Directory downloadDir = Directory(
            '${appDir.path}/music_downloads',
          );
          if (!await downloadDir.exists()) {
            await downloadDir.create(recursive: true);
          }

          final String relativePath =
              'music_downloads/music_cache_${song.source}_${song.id}.mp3';
          final File targetFile = File('${appDir.path}/$relativePath');

          final http.Client client = http.Client();
          final http.Request request = http.Request('GET', Uri.parse(url));
          final http.StreamedResponse response = await client.send(request);

          if (response.statusCode != 200) {
            client.close();
            throw Exception('下载请求失败，HTTP Code: ${response.statusCode}');
          }

          final int totalBytes = response.contentLength ?? 0;
          int receivedBytes = 0;

          final IOSink sink = targetFile.openWrite();
          await response.stream.forEach((List<int> chunk) {
            sink.add(chunk);
            receivedBytes += chunk.length;
            if (totalBytes > 0) {
              final double progress = receivedBytes / totalBytes;
              controller.add(progress);
            }
          });

          await sink.flush();
          await sink.close();
          client.close();

          final CachedTrack track = CachedTrack(
            source: song.source,
            id: song.id,
            localPath: relativePath,
            fileSize: receivedBytes,
            quality: quality.name.isNotEmpty ? quality.name : quality.bitrate,
            title: song.name,
            artist: song.artist,
            cover: song.cover,
            duration: song.duration,
          );

          _cacheMap[_cacheKey(song.source, song.id)] = track;
          await _saveToPrefs();

          controller.add(1.0);
          await controller.close();
        } catch (e) {
          controller.addError(e);
          await controller.close();
        } finally {
          _downloadingKeys.remove(key);
        }
      }(),
    );

    return controller.stream;
  }
}
