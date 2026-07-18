import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String themeModePreferenceKey = 'theme_mode';
const String preferredBitratePreferenceKey = 'preferred_bitrate';
const String backupMusicSourcePreferenceKey = 'backup_music_source_enabled';
const String defaultPreferredBitrate = '320kmp3';
const bool defaultBackupMusicSourceEnabled = true;

class AppSettingsController extends ChangeNotifier {
  AppSettingsController({SharedPreferences? preferences})
    : _preferences = preferences;

  final SharedPreferences? _preferences;
  ThemeMode _themeMode = ThemeMode.system;
  String _preferredBitrate = defaultPreferredBitrate;
  bool _backupMusicSourceEnabled = defaultBackupMusicSourceEnabled;

  ThemeMode get themeMode => _themeMode;

  String get preferredBitrate => _preferredBitrate;

  /// When true, FreeMusicApi falls back to ChKSz after sy110 failures.
  bool get backupMusicSourceEnabled => _backupMusicSourceEnabled;

  Future<void> load() async {
    try {
      final SharedPreferences preferences = await _getPreferences();
      final ThemeMode nextThemeMode = _themeModeFromName(
        preferences.getString(themeModePreferenceKey),
      );
      final String nextPreferredBitrate =
          preferences.getString(preferredBitratePreferenceKey) ??
          defaultPreferredBitrate;
      final bool nextBackupEnabled =
          preferences.getBool(backupMusicSourcePreferenceKey) ??
          defaultBackupMusicSourceEnabled;
      if (_themeMode == nextThemeMode &&
          _preferredBitrate == nextPreferredBitrate &&
          _backupMusicSourceEnabled == nextBackupEnabled) {
        return;
      }
      _themeMode = nextThemeMode;
      _preferredBitrate = nextPreferredBitrate;
      _backupMusicSourceEnabled = nextBackupEnabled;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) {
      return;
    }
    _themeMode = mode;
    notifyListeners();
    try {
      final SharedPreferences preferences = await _getPreferences();
      await preferences.setString(themeModePreferenceKey, mode.name);
    } catch (_) {}
  }

  Future<void> setPreferredBitrate(String bitrate) async {
    if (_preferredBitrate == bitrate) {
      return;
    }
    _preferredBitrate = bitrate;
    notifyListeners();
    try {
      final SharedPreferences preferences = await _getPreferences();
      await preferences.setString(preferredBitratePreferenceKey, bitrate);
    } catch (_) {}
  }

  Future<void> setBackupMusicSourceEnabled(bool enabled) async {
    if (_backupMusicSourceEnabled == enabled) {
      return;
    }
    _backupMusicSourceEnabled = enabled;
    notifyListeners();
    try {
      final SharedPreferences preferences = await _getPreferences();
      await preferences.setBool(backupMusicSourcePreferenceKey, enabled);
    } catch (_) {}
  }

  Future<SharedPreferences> _getPreferences() async {
    return _preferences ?? SharedPreferences.getInstance();
  }
}

ThemeMode _themeModeFromName(String? name) {
  if (name == null) {
    return ThemeMode.system;
  }
  return ThemeMode.values.firstWhere(
    (ThemeMode mode) => mode.name == name,
    orElse: () => ThemeMode.system,
  );
}
