import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_car_app/free_music_api.dart';
import 'package:music_car_app/music_audio_handler.dart';
import 'package:music_car_app/native_audio_controller.dart';

class _FakeNativeAudioPlayer implements NativeAudioPlayer {
  bool isPlaying = false;
  int stopCalls = 0;
  Duration currentPosition = Duration.zero;
  final Set<String> failSetUrl = <String>{};

  @override
  Duration get bufferedPosition => Duration.zero;

  @override
  bool get playing => isPlaying;

  @override
  Stream<PlaybackEvent> get playbackEventStream =>
      const Stream<PlaybackEvent>.empty();

  @override
  PlaybackEvent get playbackEvent => PlaybackEvent();

  @override
  Duration get position => currentPosition;

  @override
  ProcessingState get processingState => ProcessingState.idle;

  @override
  double get speed => 1;

  @override
  Future<void> dispose() async {}

  @override
  Future<void> loadFromSnapshot(
    String url,
    PlayerProbeSnapshot snapshot,
  ) async {}

  @override
  Future<void> pause() async {
    isPlaying = false;
  }

  @override
  Future<void> pauseDirect() async {
    await pause();
  }

  @override
  Future<void> play() async {
    isPlaying = true;
  }

  @override
  Future<void> playDirect() async {
    await play();
  }

  double volume = 1.0;

  @override
  Future<void> seek(Duration position) async {
    currentPosition = position;
  }

  @override
  Future<void> setVolume(double val) async {
    volume = val;
  }

  @override
  Future<Duration?> setUrl(String url) async {
    if (failSetUrl.contains(url)) {
      throw StateError('failed to set $url');
    }
    return Duration.zero;
  }

  @override
  Future<void> stop() async {
    stopCalls += 1;
    isPlaying = false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('autoSkipToNextAfterCompletion triggers next on each call', () async {
    final MusicAudioHandler handler = MusicAudioHandler();
    int nextCalls = 0;
    handler.onSkipToNextTrack = () async {
      nextCalls += 1;
      return true;
    };

    await handler.autoSkipToNextAfterCompletion();
    await handler.autoSkipToNextAfterCompletion();

    expect(nextCalls, 2);

    await handler.dispose();
  });

  test(
    'autoSkipToNextAfterCompletion stops when no next item exists',
    () async {
      final _FakeNativeAudioPlayer player = _FakeNativeAudioPlayer()
        ..isPlaying = true;
      final MusicAudioHandler handler = MusicAudioHandler(player: player);
      int nextCalls = 0;
      handler.onSkipToNextTrack = () async {
        nextCalls += 1;
        return false;
      };

      await handler.autoSkipToNextAfterCompletion();

      expect(nextCalls, 1);
      expect(player.stopCalls, 1);
      expect(player.isPlaying, isFalse);

      await handler.dispose();
    },
  );

  test('loadFromSnapshot exposes current item as a browsable queue', () async {
    final MusicAudioHandler handler = MusicAudioHandler(
      player: _FakeNativeAudioPlayer(),
    );

    await handler.loadFromSnapshot(
      'https://example.com/song.mp3',
      const PlayerProbeSnapshot(
        audioUrl: 'https://example.com/song.mp3',
        playing: true,
        title: '晴天',
        artist: '周杰伦',
      ),
    );

    final children = await handler.getChildren('root');

    expect(children, hasLength(1));
    expect(children.single.title, '晴天');
    expect(children.single.artist, '周杰伦');
    expect(children.single.playable, isTrue);

    await handler.dispose();
  });

  test(
    'loadFromSnapshot publishes complete probe queue and active index',
    () async {
      final MusicAudioHandler handler = MusicAudioHandler(
        player: _FakeNativeAudioPlayer(),
      );

      await handler.loadFromSnapshot(
        'https://example.com/2.mp3',
        const PlayerProbeSnapshot(
          audioUrl: 'https://example.com/2.mp3',
          playing: true,
          currentIndex: 1,
          song: FreeMusicSong(
            id: '2',
            source: 'kuwo',
            name: '晴天',
            artist: '周杰伦',
            duration: 269,
          ),
          playlist: <FreeMusicSong>[
            FreeMusicSong(
              id: '1',
              source: 'kuwo',
              name: '七里香',
              artist: '周杰伦',
              duration: 290,
              album: '七里香',
              cover: 'https://example.com/cover-1.jpg',
            ),
            FreeMusicSong(
              id: '2',
              source: 'kuwo',
              name: '晴天',
              artist: '周杰伦',
              duration: 269,
            ),
          ],
        ),
      );

      final children = await handler.getChildren('root');

      expect(children, hasLength(2));
      expect(children.first.title, '七里香');
      expect(children.first.album, '七里香');
      expect(
        children.first.artUri,
        Uri.parse('https://example.com/cover-1.jpg'),
      );
      expect(children.last.id, 'https://example.com/2.mp3');
      expect(children.last.extras?['songId'], '2');
      expect(handler.playbackState.value.queueIndex, 1);

      await handler.dispose();
    },
  );

  test('loadFromSnapshot does not publish failed media item', () async {
    final _FakeNativeAudioPlayer player = _FakeNativeAudioPlayer()
      ..failSetUrl.add('https://example.com/bad.mp3');
    final MusicAudioHandler handler = MusicAudioHandler(player: player);

    await expectLater(
      handler.loadFromSnapshot(
        'https://example.com/bad.mp3',
        const PlayerProbeSnapshot(
          audioUrl: 'https://example.com/bad.mp3',
          playing: true,
          title: '坏音源',
        ),
      ),
      throwsA(isA<StateError>()),
    );

    expect(handler.mediaItem.valueOrNull, isNull);
    expect(handler.queue.valueOrNull, isEmpty);

    await handler.loadFromSnapshot(
      'https://example.com/good.mp3',
      const PlayerProbeSnapshot(
        audioUrl: 'https://example.com/good.mp3',
        playing: true,
        title: '可播放',
      ),
    );

    expect(handler.mediaItem.valueOrNull?.title, '可播放');
    expect(handler.queue.valueOrNull, hasLength(1));

    await handler.dispose();
  });

  test(
    'skipToQueueItem calls native queue callback for another item',
    () async {
      final MusicAudioHandler handler = MusicAudioHandler(
        player: _FakeNativeAudioPlayer(),
      );
      final List<int> selectedIndexes = <int>[];
      handler.onSkipToQueueItem = (int index) async {
        selectedIndexes.add(index);
      };

      await handler.loadFromSnapshot(
        'https://example.com/1.mp3',
        const PlayerProbeSnapshot(
          audioUrl: 'https://example.com/1.mp3',
          playing: true,
          currentIndex: 0,
          song: FreeMusicSong(
            id: '1',
            source: 'kuwo',
            name: '七里香',
            artist: '周杰伦',
            duration: 290,
          ),
          playlist: <FreeMusicSong>[
            FreeMusicSong(
              id: '1',
              source: 'kuwo',
              name: '七里香',
              artist: '周杰伦',
              duration: 290,
            ),
            FreeMusicSong(
              id: '2',
              source: 'kuwo',
              name: '晴天',
              artist: '周杰伦',
              duration: 269,
            ),
          ],
        ),
      );

      await handler.skipToQueueItem(1);
      await handler.skipToQueueItem(9);

      expect(selectedIndexes, <int>[1]);

      await handler.dispose();
    },
  );

  test('play uses external resume callback when it handles playback', () async {
    final _FakeNativeAudioPlayer player = _FakeNativeAudioPlayer();
    final MusicAudioHandler handler = MusicAudioHandler(player: player);
    int callbackCalls = 0;
    handler.onPlayTrack = () async {
      callbackCalls += 1;
      return true;
    };

    await handler.play();

    expect(callbackCalls, 1);
    expect(player.isPlaying, isTrue);

    await handler.dispose();
  });

  test(
    'play falls back to native player when resume callback cannot handle',
    () async {
      final _FakeNativeAudioPlayer player = _FakeNativeAudioPlayer();
      final MusicAudioHandler handler = MusicAudioHandler(player: player);
      int callbackCalls = 0;
      handler.onPlayTrack = () async {
        callbackCalls += 1;
        return false;
      };

      await handler.play();

      expect(callbackCalls, 1);
      expect(player.isPlaying, isTrue);

      await handler.dispose();
    },
  );

  test('pause callback can pause the same handler without recursion', () async {
    final _FakeNativeAudioPlayer player = _FakeNativeAudioPlayer()
      ..isPlaying = true;
    final MusicAudioHandler handler = MusicAudioHandler(player: player);
    int callbackCalls = 0;
    handler.onPauseTrack = () async {
      callbackCalls += 1;
      await handler.pause();
    };

    await handler.pause();

    expect(callbackCalls, 1);
    expect(player.isPlaying, isFalse);
    expect(handler.playbackState.value.playing, isFalse);

    await handler.dispose();
  });

  test('playback state suppresses unchanged broadcasts', () async {
    final _FakeNativeAudioPlayer player = _FakeNativeAudioPlayer();
    final MusicAudioHandler handler = MusicAudioHandler(player: player);
    final List<PlaybackState> states = <PlaybackState>[];
    final StreamSubscription<PlaybackState> subscription = handler.playbackState
        .listen(states.add);
    await Future<void>.delayed(Duration.zero);

    final int initialCount = states.length;
    await handler.playDirect();
    await Future<void>.delayed(Duration.zero);
    final int afterPlayCount = states.length;
    await handler.playDirect();
    await Future<void>.delayed(Duration.zero);

    expect(afterPlayCount, greaterThan(initialCount));
    expect(states.length, afterPlayCount);

    player.currentPosition = const Duration(seconds: 2);
    await handler.playDirect();
    await Future<void>.delayed(Duration.zero);

    expect(states.length, afterPlayCount + 1);

    await subscription.cancel();
    await handler.dispose();
  });

  test('fastForward and rewind seek within track bounds', () async {
    final _FakeNativeAudioPlayer player = _FakeNativeAudioPlayer();
    final MusicAudioHandler handler = MusicAudioHandler(player: player);

    await handler.loadFromSnapshot(
      'https://example.com/song.mp3',
      const PlayerProbeSnapshot(
        audioUrl: 'https://example.com/song.mp3',
        playing: true,
        title: '晴天',
        duration: Duration(seconds: 60),
      ),
    );

    player.currentPosition = const Duration(seconds: 50);
    await handler.fastForward();
    expect(player.currentPosition, const Duration(seconds: 60));

    player.currentPosition = const Duration(seconds: 10);
    await handler.rewind();
    expect(player.currentPosition, Duration.zero);

    player.currentPosition = const Duration(seconds: 20);
    await handler.fastForward();
    expect(player.currentPosition, const Duration(seconds: 35));

    await handler.dispose();
  });

  test(
    'seekForward and seekBackward perform immediate relative seek',
    () async {
      final _FakeNativeAudioPlayer player = _FakeNativeAudioPlayer();
      final MusicAudioHandler handler = MusicAudioHandler(player: player);

      await handler.loadFromSnapshot(
        'https://example.com/song.mp3',
        const PlayerProbeSnapshot(
          audioUrl: 'https://example.com/song.mp3',
          playing: true,
          title: '晴天',
          duration: Duration(seconds: 60),
        ),
      );

      player.currentPosition = const Duration(seconds: 20);
      await handler.seekForward(true);
      expect(player.currentPosition, const Duration(seconds: 35));
      await handler.seekForward(false);

      await handler.seekBackward(true);
      expect(player.currentPosition, const Duration(seconds: 20));
      await handler.seekBackward(false);

      await handler.dispose();
    },
  );

  test('setRepeatMode and setShuffleMode publish playback state', () async {
    final MusicAudioHandler handler = MusicAudioHandler(
      player: _FakeNativeAudioPlayer(),
    );
    final List<AudioServiceRepeatMode> repeatModes = <AudioServiceRepeatMode>[];
    final List<AudioServiceShuffleMode> shuffleModes =
        <AudioServiceShuffleMode>[];
    handler.onSetRepeatMode = (AudioServiceRepeatMode repeatMode) async {
      repeatModes.add(repeatMode);
    };
    handler.onSetShuffleMode = (AudioServiceShuffleMode shuffleMode) async {
      shuffleModes.add(shuffleMode);
    };

    await handler.setRepeatMode(AudioServiceRepeatMode.all);
    await handler.setShuffleMode(AudioServiceShuffleMode.all);

    expect(handler.playbackState.value.repeatMode, AudioServiceRepeatMode.all);
    expect(
      handler.playbackState.value.shuffleMode,
      AudioServiceShuffleMode.all,
    );
    expect(repeatModes, <AudioServiceRepeatMode>[AudioServiceRepeatMode.all]);
    expect(shuffleModes, <AudioServiceShuffleMode>[
      AudioServiceShuffleMode.all,
    ]);

    await handler.dispose();
  });

  test(
    'checkForPlaybackStall skips next after ten seconds without progress',
    () async {
      final _FakeNativeAudioPlayer player = _FakeNativeAudioPlayer()
        ..isPlaying = true
        ..currentPosition = const Duration(seconds: 30);
      final MusicAudioHandler handler = MusicAudioHandler(player: player);
      int nextCalls = 0;
      handler.onSkipToNextTrack = () async {
        nextCalls += 1;
        return true;
      };

      await handler.loadFromSnapshot(
        'https://example.com/song.mp3',
        const PlayerProbeSnapshot(
          audioUrl: 'https://example.com/song.mp3',
          playing: true,
          title: '晴天',
        ),
      );

      final DateTime start = DateTime(2026, 1, 1, 12);
      await handler.checkForPlaybackStall(start);
      await handler.checkForPlaybackStall(
        start.add(const Duration(seconds: 9)),
      );
      expect(nextCalls, 0);

      await handler.checkForPlaybackStall(
        start.add(const Duration(seconds: 10)),
      );
      expect(nextCalls, 1);

      await handler.checkForPlaybackStall(
        start.add(const Duration(seconds: 12)),
      );
      expect(nextCalls, 1);

      await handler.dispose();
    },
  );

  test('checkForPlaybackStall ignores paused playback', () async {
    final _FakeNativeAudioPlayer player = _FakeNativeAudioPlayer()
      ..isPlaying = false
      ..currentPosition = const Duration(seconds: 30);
    final MusicAudioHandler handler = MusicAudioHandler(player: player);
    int nextCalls = 0;
    handler.onSkipToNextTrack = () async {
      nextCalls += 1;
      return true;
    };

    await handler.loadFromSnapshot(
      'https://example.com/song.mp3',
      const PlayerProbeSnapshot(
        audioUrl: 'https://example.com/song.mp3',
        playing: false,
        title: '晴天',
      ),
    );

    final DateTime start = DateTime(2026, 1, 1, 12);
    await handler.checkForPlaybackStall(start);
    await handler.checkForPlaybackStall(start.add(const Duration(seconds: 30)));

    expect(nextCalls, 0);

    await handler.dispose();
  });
}
