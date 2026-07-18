import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_car_app/services/app_settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('loads persisted theme mode, preferred bitrate and backup flag', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      themeModePreferenceKey: ThemeMode.dark.name,
      preferredBitratePreferenceKey: 'flac',
      backupMusicSourcePreferenceKey: false,
    });
    final AppSettingsController controller = AppSettingsController();

    await controller.load();

    expect(controller.themeMode, ThemeMode.dark);
    expect(controller.preferredBitrate, 'flac');
    expect(controller.backupMusicSourceEnabled, isFalse);

    controller.dispose();
  });

  test('defaults backup music source to enabled', () async {
    final AppSettingsController controller = AppSettingsController();
    await controller.load();
    expect(controller.backupMusicSourceEnabled, isTrue);
    controller.dispose();
  });

  test('saves settings and notifies listeners when values change', () async {
    final AppSettingsController controller = AppSettingsController();
    int notifyCount = 0;
    controller.addListener(() {
      notifyCount += 1;
    });

    await controller.setThemeMode(ThemeMode.light);
    await controller.setPreferredBitrate('128kmp3');
    await controller.setPreferredBitrate('128kmp3');
    await controller.setBackupMusicSourceEnabled(false);
    await controller.setBackupMusicSourceEnabled(false);

    final SharedPreferences preferences = await SharedPreferences.getInstance();
    expect(controller.themeMode, ThemeMode.light);
    expect(controller.preferredBitrate, '128kmp3');
    expect(controller.backupMusicSourceEnabled, isFalse);
    expect(preferences.getString(themeModePreferenceKey), ThemeMode.light.name);
    expect(preferences.getString(preferredBitratePreferenceKey), '128kmp3');
    expect(preferences.getBool(backupMusicSourcePreferenceKey), isFalse);
    expect(notifyCount, 3);

    controller.dispose();
  });
}
