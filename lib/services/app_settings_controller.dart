import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String themeModePreferenceKey = 'theme_mode';
const String preferredBitratePreferenceKey = 'preferred_bitrate';
const String defaultPreferredBitrate = '320kmp3';

class AppSettingsController extends ChangeNotifier {
  AppSettingsController({SharedPreferences? preferences})
    : _preferences = preferences;

  final SharedPreferences? _preferences;
  ThemeMode _themeMode = ThemeMode.system;
  String _preferredBitrate = defaultPreferredBitrate;

  ThemeMode get themeMode => _themeMode;

  String get preferredBitrate => _preferredBitrate;

  Future<void> load() async {
    try {
      final SharedPreferences preferences = await _getPreferences();
      final ThemeMode nextThemeMode = _themeModeFromName(
        preferences.getString(themeModePreferenceKey),
      );
      final String nextPreferredBitrate =
          preferences.getString(preferredBitratePreferenceKey) ??
          defaultPreferredBitrate;
      if (_themeMode == nextThemeMode &&
          _preferredBitrate == nextPreferredBitrate) {
        return;
      }
      _themeMode = nextThemeMode;
      _preferredBitrate = nextPreferredBitrate;
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
