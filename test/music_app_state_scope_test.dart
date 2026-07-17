import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_car_app/app/music_app_state_scope.dart';
import 'package:music_car_app/free_music_api.dart';
import 'package:music_car_app/main.dart';
import 'package:music_car_app/native_audio_controller.dart';
import 'package:music_car_app/services/audio_effects_controller.dart';

void main() {
  test('updateShouldNotify is true when audioEffectsSettings changes', () {
    final MusicAppStateScope before = _scope(
      effects: AudioEffectsSettings.off,
      preferredBitrate: '320kmp3',
    );
    final MusicAppStateScope after = _scope(
      effects: AudioEffectsSettings.fromPreset(AudioEffectPresetId.surround),
      preferredBitrate: '320kmp3',
    );
    expect(after.updateShouldNotify(before), isTrue);
  });

  test('updateShouldNotify is true when preferredBitrate changes', () {
    final MusicAppStateScope before = _scope(
      effects: AudioEffectsSettings.off,
      preferredBitrate: '128kmp3',
    );
    final MusicAppStateScope after = _scope(
      effects: AudioEffectsSettings.off,
      preferredBitrate: '320kmp3',
    );
    expect(after.updateShouldNotify(before), isTrue);
  });

  test('updateShouldNotify is true when themeMode changes', () {
    final MusicAppStateScope before = _scope(
      effects: AudioEffectsSettings.off,
      preferredBitrate: '320kmp3',
      themeMode: ThemeMode.system,
    );
    final MusicAppStateScope after = _scope(
      effects: AudioEffectsSettings.off,
      preferredBitrate: '320kmp3',
      themeMode: ThemeMode.dark,
    );
    expect(after.updateShouldNotify(before), isTrue);
  });

  test('updateShouldNotify is false when scoped settings are unchanged', () {
    final MusicAppStateScope before = _scope(
      effects: AudioEffectsSettings.fromPreset(AudioEffectPresetId.hifi),
      preferredBitrate: '320kmp3',
    );
    final MusicAppStateScope after = _scope(
      effects: AudioEffectsSettings.fromPreset(AudioEffectPresetId.hifi),
      preferredBitrate: '320kmp3',
    );
    expect(after.updateShouldNotify(before), isFalse);
  });

  testWidgets(
    'dependent Builder rebuilds when scoped audio effect preset changes',
    (WidgetTester tester) async {
      int buildCount = 0;
      AudioEffectsSettings effects = AudioEffectsSettings.off;
      late StateSetter rootSetState;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            rootSetState = setState;
            return MaterialApp(
              home: MusicAppStateScope(
                state: _UnusedHomeState(),
                currentSong: null,
                selectedQueueIndex: 0,
                playbackQueue: const <FreeMusicSong>[],
                playbackMode: NativePlaybackMode.repeatAll,
                searchResults: const <FreeMusicSong>[],
                favoriteSongs: const <FreeMusicSong>[],
                selectedTab: 5,
                isLoadingRecommendations: false,
                isLoadingApiBootstrap: false,
                recommendationError: '',
                apiBootstrapError: '',
                preferredBitrate: '320kmp3',
                audioEffectsSettings: effects,
                themeMode: ThemeMode.system,
                child: Builder(
                  builder: (BuildContext context) {
                    final MusicAppStateScope scope = context
                        .dependOnInheritedWidgetOfExactType<
                          MusicAppStateScope
                        >()!;
                    buildCount += 1;
                    return Text(scope.audioEffectsSettings.presetId);
                  },
                ),
              ),
            );
          },
        ),
      );

      expect(find.text(AudioEffectPresetId.off), findsOneWidget);
      final int afterFirstBuild = buildCount;

      rootSetState(() {
        effects = AudioEffectsSettings.fromPreset(AudioEffectPresetId.bass);
      });
      await tester.pump();

      expect(find.text(AudioEffectPresetId.bass), findsOneWidget);
      expect(buildCount, greaterThan(afterFirstBuild));
    },
  );
}

MusicAppStateScope _scope({
  required AudioEffectsSettings effects,
  required String preferredBitrate,
  ThemeMode themeMode = ThemeMode.system,
}) {
  return MusicAppStateScope(
    state: _UnusedHomeState(),
    currentSong: null,
    selectedQueueIndex: 0,
    playbackQueue: const <FreeMusicSong>[],
    playbackMode: NativePlaybackMode.repeatAll,
    searchResults: const <FreeMusicSong>[],
    favoriteSongs: const <FreeMusicSong>[],
    selectedTab: 5,
    isLoadingRecommendations: false,
    isLoadingApiBootstrap: false,
    recommendationError: '',
    apiBootstrapError: '',
    preferredBitrate: preferredBitrate,
    audioEffectsSettings: effects,
    themeMode: themeMode,
    child: const SizedBox.shrink(),
  );
}

/// Stand-in for pure InheritedWidget notify tests; never mounted.
class _UnusedHomeState extends NativeMusicHomePageState {}
