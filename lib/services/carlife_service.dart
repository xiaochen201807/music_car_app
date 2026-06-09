import 'package:flutter/services.dart';

class CarLifeService {
  const CarLifeService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('music_car_app/carlife');

  final MethodChannel _channel;

  Future<CarLifeStatus> getStatus() async {
    try {
      final Object? result = await _channel.invokeMethod<Object?>('getStatus');
      return CarLifeStatus.fromMap(_asStringKeyMap(result));
    } on MissingPluginException {
      return const CarLifeStatus(
        available: false,
        installed: false,
        launchable: false,
        sdkLinked: false,
        reason: 'not_android',
      );
    } on PlatformException catch (error) {
      return CarLifeStatus(
        available: false,
        installed: false,
        launchable: false,
        sdkLinked: false,
        reason: error.code,
      );
    }
  }

  Future<CarLifeLaunchResult> openCarLife() async {
    try {
      final Object? result = await _channel.invokeMethod<Object?>(
        'openCarLife',
      );
      return CarLifeLaunchResult.fromMap(_asStringKeyMap(result));
    } on MissingPluginException {
      return const CarLifeLaunchResult(launched: false, reason: 'not_android');
    } on PlatformException catch (error) {
      return CarLifeLaunchResult(launched: false, reason: error.code);
    }
  }

  Future<CarLifeSyncResult> syncPlaybackContext({
    required String title,
    required String artist,
    required bool playing,
  }) async {
    try {
      final Object? result = await _channel.invokeMethod<Object?>(
        'syncPlaybackContext',
        <String, Object?>{'title': title, 'artist': artist, 'playing': playing},
      );
      return CarLifeSyncResult.fromMap(_asStringKeyMap(result));
    } on MissingPluginException {
      return const CarLifeSyncResult(supported: false, reason: 'not_android');
    } on PlatformException catch (error) {
      return CarLifeSyncResult(supported: false, reason: error.code);
    }
  }
}

class CarLifeStatus {
  const CarLifeStatus({
    required this.available,
    required this.installed,
    required this.launchable,
    required this.sdkLinked,
    this.packageName = '',
    this.integrationMode = '',
    this.reason = '',
  });

  factory CarLifeStatus.fromMap(Map<String, Object?> map) {
    return CarLifeStatus(
      available: map['available'] == true,
      installed: map['installed'] == true,
      launchable: map['launchable'] == true,
      sdkLinked: map['sdkLinked'] == true,
      packageName: _stringValue(map['packageName']),
      integrationMode: _stringValue(map['integrationMode']),
      reason: _stringValue(map['reason']),
    );
  }

  final bool available;
  final bool installed;
  final bool launchable;
  final bool sdkLinked;
  final String packageName;
  final String integrationMode;
  final String reason;

  String get displayText {
    if (sdkLinked) {
      return 'SDK 已接入';
    }
    if (launchable) {
      return '已安装，可拉起';
    }
    if (installed) {
      return '已安装，未找到启动入口';
    }
    return '未检测到 CarLife';
  }
}

class CarLifeLaunchResult {
  const CarLifeLaunchResult({
    required this.launched,
    this.packageName = '',
    this.reason = '',
  });

  factory CarLifeLaunchResult.fromMap(Map<String, Object?> map) {
    return CarLifeLaunchResult(
      launched: map['launched'] == true,
      packageName: _stringValue(map['packageName']),
      reason: _stringValue(map['reason']),
    );
  }

  final bool launched;
  final String packageName;
  final String reason;
}

class CarLifeSyncResult {
  const CarLifeSyncResult({required this.supported, this.reason = ''});

  factory CarLifeSyncResult.fromMap(Map<String, Object?> map) {
    return CarLifeSyncResult(
      supported: map['supported'] == true,
      reason: _stringValue(map['reason']),
    );
  }

  final bool supported;
  final String reason;
}

Map<String, Object?> _asStringKeyMap(Object? value) {
  if (value is Map) {
    return value.map(
      (Object? key, Object? value) => MapEntry<String, Object?>('$key', value),
    );
  }
  return const <String, Object?>{};
}

String _stringValue(Object? value) {
  if (value == null) {
    return '';
  }
  return '$value'.trim();
}
