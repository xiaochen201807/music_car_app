import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:music_car_app/controllers/track_metadata_controller.dart';
import 'package:music_car_app/free_music_api.dart';

void main() {
  test('lyrics key tracks the song the lyrics belong to', () async {
    final _FakeTrackMetadataClient client = _FakeTrackMetadataClient();
    final TrackMetadataController controller = TrackMetadataController(
      client: client,
    );
    final FreeMusicSong song = _song('lanting');
    client.lyricsResults['lanting'] = const FreeMusicLyrics(
      raw: '[00:00.00]兰亭序',
      lines: <FreeMusicLyricLine>[
        FreeMusicLyricLine(time: Duration.zero, text: '兰亭序'),
      ],
    );

    await controller.loadLyricsForSong(song);

    expect(controller.currentLyrics, isNotNull);
    expect(
      controller.currentLyricsKey,
      TrackMetadataController.lyricsKeyFor(song),
    );

    controller.dispose();
  });

  test('stale lyrics response is dropped when a newer song loads', () async {
    final Completer<FreeMusicLyrics> slow = Completer<FreeMusicLyrics>();
    final Completer<FreeMusicLyrics> fast = Completer<FreeMusicLyrics>();
    final _FakeTrackMetadataClient client = _FakeTrackMetadataClient(
      onFetch: (FreeMusicSong song) {
        return song.id == 'stranded' ? slow.future : fast.future;
      },
    );
    final TrackMetadataController controller = TrackMetadataController(
      client: client,
    );
    final FreeMusicSong stranded = _song('stranded');
    final FreeMusicSong lanting = _song('lanting');

    // 先请求上一首（搁浅），响应尚未返回
    final Future<bool> firstLoad = controller.loadLyricsForSong(stranded);
    // 切到当前歌（兰亭序），其响应先返回
    final Future<bool> secondLoad = controller.loadLyricsForSong(lanting);

    fast.complete(
      const FreeMusicLyrics(
        raw: '[00:00.00]兰亭序',
        lines: <FreeMusicLyricLine>[
          FreeMusicLyricLine(time: Duration.zero, text: '兰亭序'),
        ],
      ),
    );
    expect(await secondLoad, isTrue);

    // 上一首的响应迟到返回，应被判为过期而丢弃
    slow.complete(
      const FreeMusicLyrics(
        raw: '[00:00.00]搁浅',
        lines: <FreeMusicLyricLine>[
          FreeMusicLyricLine(time: Duration.zero, text: '搁浅'),
        ],
      ),
    );
    expect(await firstLoad, isFalse);

    // 归属仍指向当前歌（兰亭序），且歌词为兰亭序而非搁浅
    expect(
      controller.currentLyricsKey,
      TrackMetadataController.lyricsKeyFor(lanting),
    );
    expect(controller.currentLyrics?.lines.single.text, '兰亭序');

    controller.dispose();
  });

  test('reset clears lyrics and the lyrics key', () async {
    final _FakeTrackMetadataClient client = _FakeTrackMetadataClient();
    final FreeMusicSong song = _song('lanting');
    client.lyricsResults['lanting'] = const FreeMusicLyrics(
      raw: '[00:00.00]兰亭序',
      lines: <FreeMusicLyricLine>[
        FreeMusicLyricLine(time: Duration.zero, text: '兰亭序'),
      ],
    );
    final TrackMetadataController controller = TrackMetadataController(
      client: client,
    );

    await controller.loadLyricsForSong(song);
    expect(controller.currentLyricsKey, isNotEmpty);

    controller.reset();

    expect(controller.currentLyrics, isNull);
    expect(controller.currentLyricsKey, isEmpty);

    controller.dispose();
  });
}

class _FakeTrackMetadataClient implements TrackMetadataClient {
  _FakeTrackMetadataClient({this.onFetch});

  final Future<FreeMusicLyrics> Function(FreeMusicSong song)? onFetch;
  final Map<String, FreeMusicLyrics> lyricsResults = <String, FreeMusicLyrics>{};

  @override
  Future<FreeMusicLyrics> fetchEnhancedLyrics(FreeMusicSong song) {
    final Future<FreeMusicLyrics> Function(FreeMusicSong song)? handler =
        onFetch;
    if (handler != null) {
      return handler(song);
    }
    final FreeMusicLyrics? result = lyricsResults[song.id];
    if (result == null) {
      return Future<FreeMusicLyrics>.value(
        const FreeMusicLyrics(raw: '', lines: <FreeMusicLyricLine>[]),
      );
    }
    return Future<FreeMusicLyrics>.value(result);
  }

  @override
  Future<FreeMusicQualityResult> fetchQualities(FreeMusicSong song) {
    return Future<FreeMusicQualityResult>.value(
      const FreeMusicQualityResult(
        matchedName: '',
        matchedArtist: '',
        qualities: <FreeMusicQuality>[],
      ),
    );
  }
}

FreeMusicSong _song(String id) {
  return FreeMusicSong(
    id: id,
    source: 'netease',
    name: 'Song $id',
    artist: '周杰伦',
    duration: 253,
  );
}
