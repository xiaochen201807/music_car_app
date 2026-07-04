import 'dart:async';

import 'package:flutter/foundation.dart';

import '../free_music_api.dart';
import '../models/cached_track.dart';
import '../services/download_service.dart';
import '../services/app_telemetry.dart';

abstract class DownloadControllerBackend {
  List<CachedTrack> getAllCachedTracks();

  Stream<double> downloadTrack(FreeMusicSong song, FreeMusicQuality quality);

  Future<void> deleteTrack(String source, String id);
}

abstract class DownloadQualityClient {
  Future<FreeMusicQualityResult> fetchQualities(FreeMusicSong song);
}

class DownloadServiceBackend implements DownloadControllerBackend {
  const DownloadServiceBackend(this._service);

  final DownloadService _service;

  @override
  List<CachedTrack> getAllCachedTracks() => _service.getAllCachedTracks();

  @override
  Stream<double> downloadTrack(FreeMusicSong song, FreeMusicQuality quality) {
    return _service.downloadTrack(song, quality);
  }

  @override
  Future<void> deleteTrack(String source, String id) {
    return _service.deleteTrack(source, id);
  }
}

class FreeMusicDownloadQualityClient implements DownloadQualityClient {
  const FreeMusicDownloadQualityClient(this._api);

  final FreeMusicApi _api;

  @override
  Future<FreeMusicQualityResult> fetchQualities(FreeMusicSong song) {
    return _api.fetchQualities(song).timeout(const Duration(seconds: 5));
  }
}

class DownloadController extends ChangeNotifier {
  DownloadController({
    required DownloadControllerBackend backend,
    required DownloadQualityClient qualityClient,
    AppTelemetry? telemetry,
  }) : _backend = backend,
       _qualityClient = qualityClient,
       _telemetry = telemetry ?? AppTelemetry.instance;

  final DownloadControllerBackend _backend;
  final DownloadQualityClient _qualityClient;
  final AppTelemetry _telemetry;
  final List<StreamSubscription<double>> _downloadSubscriptions =
      <StreamSubscription<double>>[];
  final Map<String, Future<void>> _activeDownloads = <String, Future<void>>{};

  Set<String> get downloadedSongKeys {
    return _backend
        .getAllCachedTracks()
        .map<String>((CachedTrack t) => '${t.source}_${t.id}')
        .toSet();
  }

  List<FreeMusicSong> get downloadedSongs {
    return _backend
        .getAllCachedTracks()
        .map<FreeMusicSong>((CachedTrack track) {
          return FreeMusicSong(
            id: track.id,
            source: track.source,
            name: track.title,
            artist: track.artist,
            cover: track.cover,
            duration: track.duration,
          );
        })
        .toList(growable: false);
  }

  Future<void> downloadSong(
    FreeMusicSong song, {
    required String preferredBitrate,
  }) async {
    final String key = '${song.source}_${song.id}';
    final Future<void>? active = _activeDownloads[key];
    if (active != null) {
      return active;
    }
    final Future<void> task = _downloadSong(
      song,
      preferredBitrate: preferredBitrate,
    );
    _activeDownloads[key] = task;
    try {
      await task;
    } finally {
      _activeDownloads.remove(key);
    }
  }

  Future<void> _downloadSong(
    FreeMusicSong song, {
    required String preferredBitrate,
  }) async {
    final Stopwatch stopwatch = Stopwatch()..start();
    List<FreeMusicQuality> qualities = const <FreeMusicQuality>[];
    try {
      final FreeMusicQualityResult result = await _qualityClient.fetchQualities(
        song,
      );
      qualities = result.qualities;
    } catch (_) {
      qualities = const <FreeMusicQuality>[];
    }
    final FreeMusicQuality targetQuality = _findBestQuality(
      qualities,
      preferredBitrate,
    );
    final Completer<void> downloadCompleter = Completer<void>();
    late final StreamSubscription<double> subscription;
    subscription = _backend
        .downloadTrack(song, targetQuality)
        .listen(
          (double progress) {
            if (progress >= 1.0 && !downloadCompleter.isCompleted) {
              downloadCompleter.complete();
              _telemetry.record(
                'download_track',
                duration: stopwatch.elapsed,
                attributes: <String, Object?>{
                  'source': song.source,
                  'quality': targetQuality.bitrate,
                },
              );
              notifyListeners();
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!downloadCompleter.isCompleted) {
              _telemetry.record(
                'download_track.error',
                duration: stopwatch.elapsed,
                attributes: <String, Object?>{
                  'source': song.source,
                  'quality': targetQuality.bitrate,
                },
                error: error,
              );
              downloadCompleter.completeError(error, stackTrace);
            }
          },
          onDone: () {
            if (!downloadCompleter.isCompleted) {
              downloadCompleter.complete();
              _telemetry.record(
                'download_track',
                duration: stopwatch.elapsed,
                attributes: <String, Object?>{
                  'source': song.source,
                  'quality': targetQuality.bitrate,
                },
              );
              notifyListeners();
            }
          },
          cancelOnError: true,
        );
    _downloadSubscriptions.add(subscription);
    try {
      await downloadCompleter.future;
    } finally {
      await subscription.cancel();
      _downloadSubscriptions.remove(subscription);
    }
  }

  Future<void> deleteSongCache(FreeMusicSong song) async {
    await _backend.deleteTrack(song.source, song.id);
    notifyListeners();
  }

  @override
  void dispose() {
    for (final StreamSubscription<double> subscription
        in _downloadSubscriptions) {
      unawaited(subscription.cancel());
    }
    _downloadSubscriptions.clear();
    _activeDownloads.clear();
    super.dispose();
  }
}

FreeMusicQuality _findBestQuality(
  List<FreeMusicQuality> qualities,
  String preferredBitrate,
) {
  if (qualities.isEmpty) {
    return const FreeMusicQuality(name: '标准', bitrate: '48kaac');
  }
  final int targetValue = _parseBitrateValue(preferredBitrate);
  FreeMusicQuality bestQuality = qualities.first;
  int minDifference = (targetValue - _parseBitrateValue(bestQuality.bitrate))
      .abs();

  for (final FreeMusicQuality quality in qualities) {
    final int value = _parseBitrateValue(quality.bitrate);
    final int diff = (targetValue - value).abs();
    if (diff < minDifference) {
      minDifference = diff;
      bestQuality = quality;
    }
  }
  return bestQuality;
}

int _parseBitrateValue(String bitrate) {
  final String str = bitrate.toLowerCase();
  final RegExpMatch? match = RegExp(r'\d+').firstMatch(str);
  if (match != null) {
    return int.tryParse(match.group(0)!) ?? 128;
  }
  if (str.contains('aac')) {
    return 48;
  }
  if (str.contains('mp3')) {
    return 128;
  }
  return 128;
}
