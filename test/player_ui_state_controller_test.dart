import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_car_app/controllers/player_ui_state_controller.dart';
import 'package:music_car_app/models/playback_ui_state.dart';

void main() {
  test('starts with an empty playback UI state when no source is attached', () {
    final PlayerUiStateController controller = PlayerUiStateController();

    expect(controller.value.playing, isFalse);
    expect(controller.value.title, isEmpty);
    expect(controller.value.artist, isEmpty);
    expect(controller.value.coverUrl, isEmpty);
    expect(controller.value.position, Duration.zero);
    expect(controller.value.duration, isNull);

    controller.dispose();
  });

  test('emits playback updates from the attached source', () async {
    final _FakePlayerUiStateSource source = _FakePlayerUiStateSource();
    final PlayerUiStateController controller = PlayerUiStateController(
      source: source,
    );

    final Future<Duration> nextPosition = controller.stream
        .map((PlaybackUiState state) => state.position)
        .firstWhere(
          (Duration position) => position == const Duration(seconds: 9),
        );

    source.emitPlayback(
      PlaybackState(playing: true, updatePosition: const Duration(seconds: 9)),
    );

    expect(await nextPosition, const Duration(seconds: 9));
    expect(controller.value.playing, isTrue);
    expect(controller.value.position, const Duration(seconds: 9));

    controller.dispose();
    await source.close();
  });

  test('emits media item updates from the attached source', () async {
    final _FakePlayerUiStateSource source = _FakePlayerUiStateSource();
    final PlayerUiStateController controller = PlayerUiStateController(
      source: source,
    );

    final Future<String> nextTitle = controller.stream
        .map((PlaybackUiState state) => state.title)
        .firstWhere((String title) => title == 'Road Song');

    source.emitMediaItem(
      MediaItem(
        id: 'song-1',
        title: 'Road Song',
        artist: 'Driver',
        duration: const Duration(minutes: 3),
        artUri: Uri.parse('https://example.com/cover.jpg'),
      ),
    );

    expect(await nextTitle, 'Road Song');
    expect(controller.value.artist, 'Driver');
    expect(controller.value.duration, const Duration(minutes: 3));
    expect(controller.value.coverUrl, 'https://example.com/cover.jpg');

    controller.dispose();
    await source.close();
  });

  test('attaching null resets the current UI state', () async {
    final _FakePlayerUiStateSource source = _FakePlayerUiStateSource();
    final PlayerUiStateController controller = PlayerUiStateController(
      source: source,
    );

    source.emitPlayback(PlaybackState(playing: true));
    source.emitMediaItem(const MediaItem(id: 'song-1', title: 'Road Song'));

    expect(controller.value.playing, isTrue);
    expect(controller.value.title, 'Road Song');

    controller.attach(null);

    expect(controller.value.playing, isFalse);
    expect(controller.value.title, isEmpty);

    controller.dispose();
    await source.close();
  });

  test('dispose closes stream and ignores later source events', () async {
    final _FakePlayerUiStateSource source = _FakePlayerUiStateSource();
    final PlayerUiStateController controller = PlayerUiStateController(
      source: source,
    );
    final List<PlaybackUiState> emitted = <PlaybackUiState>[];
    final Completer<void> done = Completer<void>();
    controller.stream.listen(emitted.add, onDone: done.complete);

    controller.dispose();
    source.emitPlayback(PlaybackState(playing: true));
    await done.future;

    expect(emitted, isEmpty);
    await source.close();
  });
}

class _FakePlayerUiStateSource implements PlayerUiStateSource {
  final StreamController<PlaybackState> _playbackStateController =
      StreamController<PlaybackState>.broadcast(sync: true);
  final StreamController<MediaItem?> _mediaItemController =
      StreamController<MediaItem?>.broadcast(sync: true);

  PlaybackState? _playbackStateValue;
  MediaItem? _mediaItemValue;

  @override
  PlaybackState? get playbackStateValue => _playbackStateValue;

  @override
  MediaItem? get mediaItemValue => _mediaItemValue;

  @override
  Stream<PlaybackState> get playbackStateStream {
    return _playbackStateController.stream;
  }

  @override
  Stream<MediaItem?> get mediaItemStream {
    return _mediaItemController.stream;
  }

  void emitPlayback(PlaybackState state) {
    _playbackStateValue = state;
    _playbackStateController.add(state);
  }

  void emitMediaItem(MediaItem? item) {
    _mediaItemValue = item;
    _mediaItemController.add(item);
  }

  Future<void> close() async {
    await _playbackStateController.close();
    await _mediaItemController.close();
  }
}
