import 'package:audio_service/audio_service.dart';

class PlaybackUiState {
  const PlaybackUiState({
    this.playing = false,
    this.title = '',
    this.artist = '',
    this.coverUrl = '',
    this.position = Duration.zero,
    this.duration,
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
      duration: item?.duration,
    );
  }

  final bool playing;
  final String title;
  final String artist;
  final String coverUrl;
  final Duration position;
  final Duration? duration;
}
