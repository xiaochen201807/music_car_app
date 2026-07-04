import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:music_car_app/controllers/download_controller.dart';
import 'package:music_car_app/free_music_api.dart';
import 'package:music_car_app/models/cached_track.dart';

void main() {
  test('exposes downloaded keys and songs from cached tracks', () {
    final _FakeDownloadBackend backend = _FakeDownloadBackend(
      tracks: <CachedTrack>[_track('1')],
    );
    final DownloadController controller = DownloadController(
      backend: backend,
      qualityClient: _FakeDownloadQualityClient(),
    );

    expect(controller.downloadedSongKeys, <String>{'kuwo_1'});
    expect(controller.downloadedSongs, hasLength(1));
    expect(controller.downloadedSongs.single.name, 'Song 1');
    expect(controller.downloadedSongs.single.artist, 'Artist');

    controller.dispose();
  });

  test(
    'downloadSong selects the nearest quality and notifies on completion',
    () async {
      final _FakeDownloadBackend backend = _FakeDownloadBackend();
      final _FakeDownloadQualityClient qualityClient =
          _FakeDownloadQualityClient(
            qualities: <FreeMusicQuality>[
              const FreeMusicQuality(name: '标准', bitrate: '128kmp3'),
              const FreeMusicQuality(name: '无损', bitrate: '320kmp3'),
            ],
          );
      final DownloadController controller = DownloadController(
        backend: backend,
        qualityClient: qualityClient,
      );
      int notifyCount = 0;
      controller.addListener(() {
        notifyCount += 1;
      });

      await controller.downloadSong(_song('1'), preferredBitrate: '320kmp3');

      expect(backend.downloadedQualities.single.bitrate, '320kmp3');
      expect(notifyCount, 1);

      controller.dispose();
    },
  );

  test(
    'downloadSong falls back to default quality when quality lookup fails',
    () async {
      final _FakeDownloadBackend backend = _FakeDownloadBackend();
      final DownloadController controller = DownloadController(
        backend: backend,
        qualityClient: _FakeDownloadQualityClient(error: StateError('offline')),
      );

      await controller.downloadSong(_song('1'), preferredBitrate: '320kmp3');

      expect(backend.downloadedQualities.single.bitrate, '48kaac');

      controller.dispose();
    },
  );

  test('downloadSong reuses an active task for the same song', () async {
    final Completer<void> gate = Completer<void>();
    final _FakeDownloadBackend backend = _FakeDownloadBackend(gate: gate);
    final DownloadController controller = DownloadController(
      backend: backend,
      qualityClient: _FakeDownloadQualityClient(),
    );

    final Future<void> first = controller.downloadSong(
      _song('1'),
      preferredBitrate: '128kmp3',
    );
    final Future<void> second = controller.downloadSong(
      _song('1'),
      preferredBitrate: '128kmp3',
    );

    await Future<void>.delayed(Duration.zero);
    expect(backend.downloadedQualities, hasLength(1));

    gate.complete();
    await Future.wait(<Future<void>>[first, second]);

    controller.dispose();
  });

  test('downloadSong forwards stream errors', () async {
    final _FakeDownloadBackend backend = _FakeDownloadBackend(
      downloadError: StateError('disk full'),
    );
    final DownloadController controller = DownloadController(
      backend: backend,
      qualityClient: _FakeDownloadQualityClient(),
    );

    await expectLater(
      controller.downloadSong(_song('1'), preferredBitrate: '128kmp3'),
      throwsA(isA<StateError>()),
    );

    controller.dispose();
  });

  test('deleteSongCache delegates to backend and notifies listeners', () async {
    final _FakeDownloadBackend backend = _FakeDownloadBackend();
    final DownloadController controller = DownloadController(
      backend: backend,
      qualityClient: _FakeDownloadQualityClient(),
    );
    int notifyCount = 0;
    controller.addListener(() {
      notifyCount += 1;
    });

    await controller.deleteSongCache(_song('1'));

    expect(backend.deletedKeys, <String>['kuwo:1']);
    expect(notifyCount, 1);

    controller.dispose();
  });
}

class _FakeDownloadBackend implements DownloadControllerBackend {
  _FakeDownloadBackend({
    List<CachedTrack> tracks = const <CachedTrack>[],
    this.downloadError,
    this.gate,
  }) : _tracks = tracks;

  final List<CachedTrack> _tracks;
  final Object? downloadError;
  final Completer<void>? gate;
  final List<FreeMusicQuality> downloadedQualities = <FreeMusicQuality>[];
  final List<String> deletedKeys = <String>[];

  @override
  List<CachedTrack> getAllCachedTracks() => List<CachedTrack>.from(_tracks);

  @override
  Stream<double> downloadTrack(FreeMusicSong song, FreeMusicQuality quality) {
    downloadedQualities.add(quality);
    final Object? error = downloadError;
    if (error != null) {
      return Stream<double>.error(error);
    }
    final Completer<void>? currentGate = gate;
    if (currentGate != null) {
      return Stream<double>.fromFuture(currentGate.future.then((_) => 1.0));
    }
    return Stream<double>.fromIterable(<double>[1.0]);
  }

  @override
  Future<void> deleteTrack(String source, String id) async {
    deletedKeys.add('$source:$id');
  }
}

class _FakeDownloadQualityClient implements DownloadQualityClient {
  _FakeDownloadQualityClient({
    this.qualities = const <FreeMusicQuality>[],
    this.error,
  });

  final List<FreeMusicQuality> qualities;
  final Object? error;

  @override
  Future<FreeMusicQualityResult> fetchQualities(FreeMusicSong song) async {
    final Object? currentError = error;
    if (currentError != null) {
      throw currentError;
    }
    return FreeMusicQualityResult(
      matchedName: song.name,
      matchedArtist: song.artist,
      qualities: qualities,
    );
  }
}

CachedTrack _track(String id) {
  return CachedTrack(
    source: 'kuwo',
    id: id,
    localPath: 'music_downloads/$id.mp3',
    fileSize: 1024,
    quality: '320kmp3',
    title: 'Song $id',
    artist: 'Artist',
    cover: 'https://example.com/$id.jpg',
    duration: 120,
  );
}

FreeMusicSong _song(String id) {
  return FreeMusicSong(
    id: id,
    source: 'kuwo',
    name: 'Song $id',
    artist: 'Artist',
    duration: 120,
  );
}
