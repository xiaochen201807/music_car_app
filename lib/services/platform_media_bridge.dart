import 'dart:async';

import 'package:audio_service/audio_service.dart';

import '../controllers/playback_controller.dart';
import '../controllers/queue_controller.dart';
import '../controllers/track_metadata_controller.dart';
import '../music_audio_handler.dart';
import '../services/carlife_service.dart';
import '../services/carplay_service.dart';
import '../free_music_api.dart';

typedef TrackChangedCallback = void Function(FreeMusicSong song);
typedef QueueItemSelectedCallback = Future<bool> Function(int index);
typedef RepeatModeCallback = Future<void> Function(AudioServiceRepeatMode mode);
typedef ShuffleModeCallback =
    Future<void> Function(AudioServiceShuffleMode mode);

class PlatformMediaBridge {
  PlatformMediaBridge({
    required PlaybackController playbackController,
    required QueueController queueController,
    required TrackMetadataController trackMetadataController,
    required CarLifeService carLifeService,
    CarPlayService? carPlayService,
  }) : _playbackController = playbackController,
       _queueController = queueController,
       _carLifeService = carLifeService;

  final PlaybackController _playbackController;
  final QueueController _queueController;
  final CarLifeService _carLifeService;

  TrackChangedCallback? onTrackChanged;
  QueueItemSelectedCallback? onQueueItemSelected;
  RepeatModeCallback? onSetRepeatMode;
  ShuffleModeCallback? onSetShuffleMode;

  void attachToAudioHandler(MusicAudioHandler? handler) {
    if (handler == null) return;
    handler.onPlayTrack = _handlePlay;
    handler.onPauseTrack = _handlePause;
    handler.onSkipToNextTrack = _handleNext;
    handler.onSkipToPreviousTrack = _handlePrevious;
    handler.onSkipToQueueItem = _handleSkipToQueueItem;
    handler.onSetRepeatMode = _handleSetRepeatMode;
    handler.onSetShuffleMode = _handleSetShuffleMode;
  }

  void detachFromAudioHandler(MusicAudioHandler? handler) {
    if (handler == null) return;
    if (handler.onPlayTrack == _handlePlay) handler.onPlayTrack = null;
    if (handler.onPauseTrack == _handlePause) handler.onPauseTrack = null;
    if (handler.onSkipToNextTrack == _handleNext) {
      handler.onSkipToNextTrack = null;
    }
    if (handler.onSkipToPreviousTrack == _handlePrevious) {
      handler.onSkipToPreviousTrack = null;
    }
  }

  void attachToCarLife() {
    _carLifeService.setControlHandler(_handleCarLifeControl);
  }

  Future<bool> _handlePlay() async {
    return _playbackController.resumeNativePlayback();
  }

  Future<void> _handlePause() async {
    await _playbackController.pauseNativePlayback();
  }

  Future<bool> _handleNext() async {
    final bool handled = await _playbackController.skipToNext();
    if (handled) {
      final FreeMusicSong? song = _queueController.currentSong;
      if (song != null) {
        onTrackChanged?.call(song);
      }
    }
    return handled;
  }

  Future<bool> _handlePrevious() async {
    final bool handled = await _playbackController.skipToPrevious();
    if (handled) {
      final FreeMusicSong? song = _queueController.currentSong;
      if (song != null) {
        onTrackChanged?.call(song);
      }
    }
    return handled;
  }

  Future<bool> _handleSkipToQueueItem(int index) async {
    final QueueItemSelectedCallback? callback = onQueueItemSelected;
    if (callback != null) {
      return callback(index);
    }
    return false;
  }

  Future<void> _handleSetRepeatMode(AudioServiceRepeatMode mode) async {
    final RepeatModeCallback? callback = onSetRepeatMode;
    if (callback != null) {
      await callback(mode);
    }
  }

  Future<void> _handleSetShuffleMode(AudioServiceShuffleMode mode) async {
    final ShuffleModeCallback? callback = onSetShuffleMode;
    if (callback != null) {
      await callback(mode);
    }
  }

  Future<CarLifeControlResult> _handleCarLifeControl(
    CarLifeControlCommand command,
  ) async {
    switch (command.action) {
      case CarLifeControlAction.play:
        await _handlePlay();
        return CarLifeControlResult(handled: true, reason: 'played');
      case CarLifeControlAction.pause:
        await _handlePause();
        return CarLifeControlResult(handled: true, reason: 'paused');
      case CarLifeControlAction.next:
        final bool handled = await _handleNext();
        return CarLifeControlResult(
          handled: handled,
          reason: handled ? 'next' : 'next_unavailable',
        );
      case CarLifeControlAction.previous:
        final bool handled = await _handlePrevious();
        return CarLifeControlResult(
          handled: handled,
          reason: handled ? 'previous' : 'previous_unavailable',
        );
      case CarLifeControlAction.selectQueueItem:
        final int index = command.queueIndex;
        if (index < 0) {
          return const CarLifeControlResult(
            handled: false,
            reason: 'queue_item_not_found',
          );
        }
        final QueueItemSelectedCallback? callback = onQueueItemSelected;
        if (callback != null) {
          final bool handled = await callback(index);
          return CarLifeControlResult(
            handled: handled,
            reason: handled ? 'queue_item_selected' : 'queue_item_failed',
          );
        }
        return const CarLifeControlResult(
          handled: false,
          reason: 'no_callback',
        );
      case CarLifeControlAction.unknown:
        return const CarLifeControlResult(
          handled: false,
          reason: 'unknown_action',
        );
    }
  }
}
