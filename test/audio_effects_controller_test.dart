import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_car_app/services/audio_effects_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel(
    'music_car_app/audio_effects_test',
  );
  final List<MethodCall> calls = <MethodCall>[];

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          calls.add(call);
          return true;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('setPreset persists and applies fixed audio effect preset', () async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final AudioEffectsController controller = AudioEffectsController(
      channel: channel,
      preferences: preferences,
      supportedOverride: true,
    );

    await controller.load();
    await controller.bindAudioSession(42);
    calls.clear();

    await controller.setPreset(AudioEffectPresetId.surround);

    expect(controller.settings.presetId, AudioEffectPresetId.surround);
    expect(controller.settings.enabled, isTrue);
    expect(
      preferences.getString(audioEffectPresetPreferenceKey),
      AudioEffectPresetId.surround,
    );
    expect(calls.single.method, 'applySettings');
    final Map<dynamic, dynamic> arguments =
        calls.single.arguments as Map<dynamic, dynamic>;
    expect(arguments['audioSessionId'], 42);
    expect(arguments['enabled'], isTrue);
    expect(arguments['presetId'], AudioEffectPresetId.surround);
    expect(arguments['eqGains'], isA<List>());
    expect(arguments['eqGains'], hasLength(5));
  });

  test('off preset disables audio effects', () async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final AudioEffectsController controller = AudioEffectsController(
      channel: channel,
      preferences: preferences,
      supportedOverride: true,
    );

    await controller.bindAudioSession(42);
    await controller.setPreset(AudioEffectPresetId.bass);
    calls.clear();

    await controller.setPreset(AudioEffectPresetId.off);

    expect(controller.settings.enabled, isFalse);
    expect(calls.single.method, 'applySettings');
    final Map<dynamic, dynamic> arguments =
        calls.single.arguments as Map<dynamic, dynamic>;
    expect(arguments['enabled'], isFalse);
    expect(arguments['presetId'], AudioEffectPresetId.off);
  });

  test('stale async load cannot overwrite a user selected preset', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      audioEffectPresetPreferenceKey: AudioEffectPresetId.off,
      audioEffectsEnabledPreferenceKey: false,
    });
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final Completer<SharedPreferences> preferencesGate =
        Completer<SharedPreferences>();
    final AudioEffectsController controller = AudioEffectsController(
      channel: channel,
      preferencesLoader: () => preferencesGate.future,
      supportedOverride: true,
    );

    final Future<void> loadFuture = controller.load();
    final Future<void> setPresetFuture = controller.setPreset(
      AudioEffectPresetId.surround,
    );

    expect(controller.settings.presetId, AudioEffectPresetId.surround);
    expect(controller.settings.enabled, isTrue);

    preferencesGate.complete(preferences);
    await Future.wait(<Future<void>>[loadFuture, setPresetFuture]);

    expect(controller.settings.presetId, AudioEffectPresetId.surround);
    expect(controller.settings.enabled, isTrue);
    expect(
      preferences.getString(audioEffectPresetPreferenceKey),
      AudioEffectPresetId.surround,
    );
  });
}
