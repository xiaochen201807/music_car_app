import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../music_audio_handler.dart';

const String audioEffectPresetPreferenceKey = 'audio_effect_preset';
const String audioEffectsEnabledPreferenceKey = 'audio_effects_enabled';
const String audioEffectBassBoostPreferenceKey = 'audio_effect_bass_boost';
const String audioEffectSurroundPreferenceKey = 'audio_effect_surround';
const String audioEffectClarityPreferenceKey = 'audio_effect_clarity';

class AudioEffectsController extends ChangeNotifier {
  AudioEffectsController({
    MethodChannel channel = const MethodChannel('music_car_app/audio_effects'),
    SharedPreferences? preferences,
    Future<SharedPreferences> Function()? preferencesLoader,
    bool? supportedOverride,
  }) : _channel = channel,
       _preferences = preferences,
       _preferencesLoader = preferencesLoader,
       _supportedOverride = supportedOverride;

  final MethodChannel _channel;
  final SharedPreferences? _preferences;
  final Future<SharedPreferences> Function()? _preferencesLoader;
  final bool? _supportedOverride;
  StreamSubscription<int?>? _audioSessionSub;
  int? _audioSessionId;
  AudioEffectsSettings _settings = AudioEffectsSettings.off;
  bool _applying = false;
  int _settingsRevision = 0;

  AudioEffectsSettings get settings => _settings;

  bool get applying => _applying;

  bool get supported {
    return _supportedOverride ??
        defaultTargetPlatform == TargetPlatform.android;
  }

  Future<void> init({MusicAudioHandler? audioHandler}) async {
    await load();
    attachToAudioHandler(audioHandler);
  }

  Future<void> load() async {
    try {
      final int revisionAtStart = _settingsRevision;
      final SharedPreferences preferences = await _getPreferences();
      if (revisionAtStart != _settingsRevision) {
        return;
      }
      _settings = AudioEffectsSettings(
        presetId:
            preferences.getString(audioEffectPresetPreferenceKey) ??
            AudioEffectPresetId.off,
        enabled: preferences.getBool(audioEffectsEnabledPreferenceKey) ?? false,
        bassBoost: preferences.getInt(audioEffectBassBoostPreferenceKey) ?? 0,
        surround: preferences.getInt(audioEffectSurroundPreferenceKey) ?? 0,
        clarity: preferences.getInt(audioEffectClarityPreferenceKey) ?? 0,
      ).normalized();
      notifyListeners();
    } catch (_) {}
  }

  void attachToAudioHandler(MusicAudioHandler? audioHandler) {
    unawaited(_audioSessionSub?.cancel());
    _audioSessionSub = null;
    if (audioHandler == null) {
      unawaited(bindAudioSession(null));
      return;
    }
    unawaited(bindAudioSession(audioHandler.androidAudioSessionId));
    _audioSessionSub = audioHandler.androidAudioSessionIdStream
        .distinct()
        .listen((int? sessionId) {
          unawaited(bindAudioSession(sessionId));
        });
  }

  @visibleForTesting
  Future<void> bindAudioSession(int? audioSessionId) async {
    if (_audioSessionId == audioSessionId) {
      return;
    }
    _audioSessionId = audioSessionId;
    await _apply();
  }

  Future<void> setEnabled(bool enabled) async {
    await _setSettings(_settings.copyWith(enabled: enabled));
  }

  Future<void> setPreset(String presetId) async {
    await _setSettings(AudioEffectsSettings.fromPreset(presetId));
  }

  Future<void> _setSettings(AudioEffectsSettings settings) async {
    final AudioEffectsSettings normalized = settings.normalized();
    if (_settings == normalized) {
      return;
    }
    _settingsRevision += 1;
    _settings = normalized;
    notifyListeners();
    await _persist();
    await _apply();
  }

  Future<void> _persist() async {
    try {
      final SharedPreferences preferences = await _getPreferences();
      await preferences.setString(
        audioEffectPresetPreferenceKey,
        _settings.presetId,
      );
      await preferences.setBool(
        audioEffectsEnabledPreferenceKey,
        _settings.enabled,
      );
      await preferences.setInt(
        audioEffectBassBoostPreferenceKey,
        _settings.bassBoost,
      );
      await preferences.setInt(
        audioEffectSurroundPreferenceKey,
        _settings.surround,
      );
      await preferences.setInt(
        audioEffectClarityPreferenceKey,
        _settings.clarity,
      );
    } catch (_) {}
  }

  Future<void> _apply() async {
    if (!supported) {
      return;
    }
    final int? sessionId = _audioSessionId;
    if (sessionId == null || sessionId <= 0) {
      return;
    }
    _applying = true;
    notifyListeners();
    try {
      await _channel.invokeMethod<void>('applySettings', <String, Object>{
        'audioSessionId': sessionId,
        'enabled': _settings.enabled,
        'presetId': _settings.presetId,
        'bassBoost': _settings.bassBoost,
        'surround': _settings.surround,
        'clarity': _settings.clarity,
        'eqGains': _settings.eqGains,
      });
    } catch (error) {
      debugPrint('[audio-effects] apply failed: $error');
    } finally {
      _applying = false;
      notifyListeners();
    }
  }

  Future<SharedPreferences> _getPreferences() async {
    final Future<SharedPreferences> Function()? loader = _preferencesLoader;
    if (loader != null) {
      return loader();
    }
    return _preferences ?? SharedPreferences.getInstance();
  }

  @override
  void dispose() {
    unawaited(_audioSessionSub?.cancel());
    if (supported) {
      unawaited(_channel.invokeMethod<void>('release'));
    }
    super.dispose();
  }
}

class AudioEffectsSettings {
  const AudioEffectsSettings({
    required this.presetId,
    required this.enabled,
    required this.bassBoost,
    required this.surround,
    required this.clarity,
  });

  factory AudioEffectsSettings.fromPreset(String presetId) {
    return AudioEffectPreset.presets
        .firstWhere(
          (AudioEffectPreset preset) => preset.id == presetId,
          orElse: () => AudioEffectPreset.presets.last,
        )
        .settings;
  }

  static const AudioEffectsSettings off = AudioEffectsSettings(
    presetId: AudioEffectPresetId.off,
    enabled: false,
    bassBoost: 0,
    surround: 0,
    clarity: 0,
  );

  final String presetId;
  final bool enabled;
  final int bassBoost;
  final int surround;
  final int clarity;

  List<int> get eqGains {
    if (!enabled) {
      return const <int>[0, 0, 0, 0, 0];
    }
    // Band units: whole dB, applied as milliBel on the native Equalizer.
    // Important: avoid net-negative curves. Android AudioEffect/Equalizer often
    // engages headroom limiting when effects are enabled, so a "boost some /
    // cut some" shape still sounds quieter than dry. Keep cuts mild and bias
    // the whole curve upward so every preset is at least as loud as off.
    final int bass = ((bassBoost - 25) / 12).round().clamp(0, 6);
    final int lowMid = ((bassBoost - 35) / 18).round().clamp(0, 4);
    final int mid = ((clarity - 30) / 16).round().clamp(0, 5);
    final int treble = ((clarity - 20) / 12).round().clamp(0, 6);
    final int air = ((surround + clarity - 60) / 18).round().clamp(0, 5);
    final List<int> shaped = <int>[bass, lowMid, mid, treble, air];

    // Loudness floor: ensure average gain is at least +2 dB when effects are on.
    final double avg = shaped.reduce((int a, int b) => a + b) / shaped.length;
    final int lift = avg < 2 ? (2 - avg).ceil() : 0;
    return shaped
        .map((int g) => (g + lift).clamp(0, 7))
        .toList(growable: false);
  }

  AudioEffectsSettings copyWith({
    String? presetId,
    bool? enabled,
    int? bassBoost,
    int? surround,
    int? clarity,
  }) {
    return AudioEffectsSettings(
      presetId: presetId ?? this.presetId,
      enabled: enabled ?? this.enabled,
      bassBoost: bassBoost ?? this.bassBoost,
      surround: surround ?? this.surround,
      clarity: clarity ?? this.clarity,
    ).normalized();
  }

  AudioEffectsSettings normalized() {
    return AudioEffectsSettings(
      presetId: AudioEffectPresetId.values.contains(presetId)
          ? presetId
          : AudioEffectPresetId.off,
      enabled: enabled,
      bassBoost: bassBoost.clamp(0, 100),
      surround: surround.clamp(0, 100),
      clarity: clarity.clamp(0, 100),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AudioEffectsSettings &&
        other.presetId == presetId &&
        other.enabled == enabled &&
        other.bassBoost == bassBoost &&
        other.surround == surround &&
        other.clarity == clarity;
  }

  @override
  int get hashCode {
    return Object.hash(presetId, enabled, bassBoost, surround, clarity);
  }
}

class AudioEffectPreset {
  const AudioEffectPreset({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.settings,
  });

  final String id;
  final String label;
  final String subtitle;
  final AudioEffectsSettings settings;

  static const List<AudioEffectPreset> presets = <AudioEffectPreset>[
    AudioEffectPreset(
      id: AudioEffectPresetId.ai,
      label: 'AI智能音效',
      subtitle: '智能适配不同歌曲',
      settings: AudioEffectsSettings(
        presetId: AudioEffectPresetId.ai,
        enabled: true,
        bassBoost: 58,
        surround: 52,
        clarity: 66,
      ),
    ),
    AudioEffectPreset(
      id: AudioEffectPresetId.hifi,
      label: '一键HiFi',
      subtitle: '原音重现，提升细节',
      settings: AudioEffectsSettings(
        presetId: AudioEffectPresetId.hifi,
        enabled: true,
        bassBoost: 38,
        surround: 18,
        clarity: 76,
      ),
    ),
    AudioEffectPreset(
      id: AudioEffectPresetId.bass,
      label: '超重低音',
      subtitle: '低而不浑，氛围更足',
      settings: AudioEffectsSettings(
        presetId: AudioEffectPresetId.bass,
        enabled: true,
        bassBoost: 86,
        surround: 18,
        clarity: 36,
      ),
    ),
    AudioEffectPreset(
      id: AudioEffectPresetId.surround,
      label: '3D环绕',
      subtitle: '立体环绕，不限设备',
      settings: AudioEffectsSettings(
        presetId: AudioEffectPresetId.surround,
        enabled: true,
        bassBoost: 34,
        surround: 92,
        clarity: 58,
      ),
    ),
    AudioEffectPreset(
      id: AudioEffectPresetId.live,
      label: '虚拟现场',
      subtitle: '身临其境，空间开阔',
      settings: AudioEffectsSettings(
        presetId: AudioEffectPresetId.live,
        enabled: true,
        bassBoost: 54,
        surround: 74,
        clarity: 48,
      ),
    ),
    AudioEffectPreset(
      id: AudioEffectPresetId.vocal,
      label: '人声清晰',
      subtitle: '突出歌声，降低浑浊',
      settings: AudioEffectsSettings(
        presetId: AudioEffectPresetId.vocal,
        enabled: true,
        bassBoost: 24,
        surround: 28,
        clarity: 88,
      ),
    ),
    AudioEffectPreset(
      id: AudioEffectPresetId.off,
      label: '原声',
      subtitle: '关闭增强，保留原始听感',
      settings: AudioEffectsSettings.off,
    ),
  ];
}

class AudioEffectPresetId {
  const AudioEffectPresetId._();

  static const String off = 'off';
  static const String ai = 'ai';
  static const String hifi = 'hifi';
  static const String bass = 'bass';
  static const String surround = 'surround';
  static const String live = 'live';
  static const String vocal = 'vocal';

  static const List<String> values = <String>[
    off,
    ai,
    hifi,
    bass,
    surround,
    live,
    vocal,
  ];
}
