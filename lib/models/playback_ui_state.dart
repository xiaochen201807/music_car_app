import 'package:audio_service/audio_service.dart';

class PlaybackUiState {
  const PlaybackUiState({
    this.playing = false,
    this.title = '',
    this.artist = '',
    this.coverUrl = '',
    this.position = Duration.zero,
    this.bufferedPosition = Duration.zero,
    this.duration,
    this.processingState = AudioProcessingState.idle,
  });

  factory PlaybackUiState.fromAudioService(
    PlaybackState? state,
    MediaItem? item,
  ) {
    return PlaybackUiState(
      playing: state?.playing ?? false,
      title: item?.title ?? '',
      artist: item?.artist ?? '',
      coverUrl: item?.artUri?.toString() ?? '',
      position: state?.position ?? Duration.zero,
      bufferedPosition: state?.bufferedPosition ?? Duration.zero,
      duration: item?.duration,
      processingState: state?.processingState ?? AudioProcessingState.idle,
    );
  }

  final bool playing;
  final String title;
  final String artist;
  final String coverUrl;
  final Duration position;
  final Duration bufferedPosition;
  final Duration? duration;
  final AudioProcessingState processingState;

  bool get isLoading {
    return processingState == AudioProcessingState.loading;
  }

  bool get isBuffering {
    return processingState == AudioProcessingState.buffering;
  }

  bool get isBusy => isLoading || isBuffering;

  String get statusLabel {
    if (isLoading) {
      return '正在解析音源';
    }
    if (isBuffering) {
      return '正在缓冲';
    }
    return playing ? '播放中' : '已暂停';
  }

  bool hasSameStableFields(PlaybackUiState other) {
    return playing == other.playing &&
        title == other.title &&
        artist == other.artist &&
        coverUrl == other.coverUrl &&
        duration == other.duration &&
        processingState == other.processingState;
  }

  bool hasSamePositionFields(PlaybackUiState other) {
    return position == other.position &&
        bufferedPosition == other.bufferedPosition &&
        duration == other.duration &&
        playing == other.playing &&
        processingState == other.processingState;
  }
}
