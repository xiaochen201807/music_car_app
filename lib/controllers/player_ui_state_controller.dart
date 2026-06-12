import 'dart:async';

import 'package:audio_service/audio_service.dart';

import '../models/playback_ui_state.dart';

abstract class PlayerUiStateSource {
  PlaybackState? get playbackStateValue;

  MediaItem? get mediaItemValue;

  Stream<PlaybackState> get playbackStateStream;

  Stream<MediaItem?> get mediaItemStream;
}

class AudioHandlerPlayerUiStateSource implements PlayerUiStateSource {
  const AudioHandlerPlayerUiStateSource(this._audioHandler);

  final AudioHandler _audioHandler;

  @override
  PlaybackState? get playbackStateValue {
    return _audioHandler.playbackState.valueOrNull;
  }

  @override
  MediaItem? get mediaItemValue {
    return _audioHandler.mediaItem.valueOrNull;
  }

  @override
  Stream<PlaybackState> get playbackStateStream {
    return _audioHandler.playbackState;
  }

  @override
  Stream<MediaItem?> get mediaItemStream {
    return _audioHandler.mediaItem;
  }
}

class PlayerUiStateController {
  PlayerUiStateController({PlayerUiStateSource? source}) {
    attach(source);
  }

  final StreamController<PlaybackUiState> _controller =
      StreamController<PlaybackUiState>.broadcast();

  StreamSubscription<PlaybackState>? _playbackStateSub;
  StreamSubscription<MediaItem?>? _mediaItemSub;
  PlayerUiStateSource? _source;
  PlaybackUiState _value = const PlaybackUiState();

  Stream<PlaybackUiState> get stream => _controller.stream;

  PlaybackUiState get value => _value;

  void attach(PlayerUiStateSource? source) {
    _playbackStateSub?.cancel();
    _mediaItemSub?.cancel();
    _playbackStateSub = null;
    _mediaItemSub = null;
    _source = source;

    if (source == null) {
      _emit(const PlaybackUiState());
      return;
    }

    _playbackStateSub = source.playbackStateStream.listen((
      PlaybackState state,
    ) {
      if (!identical(_source, source)) {
        return;
      }
      _emitFrom(source);
    });
    _mediaItemSub = source.mediaItemStream.listen((MediaItem? item) {
      if (!identical(_source, source)) {
        return;
      }
      _emitFrom(source);
    });
    _emitFrom(source);
  }

  void _emitFrom(PlayerUiStateSource source) {
    _emit(
      PlaybackUiState.fromAudioService(
        source.playbackStateValue,
        source.mediaItemValue,
      ),
    );
  }

  void _emit(PlaybackUiState state) {
    _value = state;
    if (_controller.isClosed) {
      return;
    }
    _controller.add(state);
  }

  void dispose() {
    _playbackStateSub?.cancel();
    _mediaItemSub?.cancel();
    _playbackStateSub = null;
    _mediaItemSub = null;
    _source = null;
    _controller.close();
  }
}
