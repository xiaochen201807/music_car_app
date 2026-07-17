import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// License plan granularity for one-device activation.
enum LicensePlan {
  month,
  quarter,
  year,
  lifetime,
  custom;

  static LicensePlan fromWire(String? raw) {
    switch ((raw ?? '').toLowerCase().trim()) {
      case 'month':
      case '月':
        return LicensePlan.month;
      case 'quarter':
      case '季':
        return LicensePlan.quarter;
      case 'year':
      case '年':
        return LicensePlan.year;
      case 'lifetime':
      case 'forever':
      case 'permanent':
      case '终身':
        return LicensePlan.lifetime;
      default:
        return LicensePlan.custom;
    }
  }

  String get wireValue {
    switch (this) {
      case LicensePlan.month:
        return 'month';
      case LicensePlan.quarter:
        return 'quarter';
      case LicensePlan.year:
        return 'year';
      case LicensePlan.lifetime:
        return 'lifetime';
      case LicensePlan.custom:
        return 'custom';
    }
  }

  String get labelZh {
    switch (this) {
      case LicensePlan.month:
        return '月卡';
      case LicensePlan.quarter:
        return '季卡';
      case LicensePlan.year:
        return '年卡';
      case LicensePlan.lifetime:
        return '终身';
      case LicensePlan.custom:
        return '自定义';
    }
  }
}

bool deviceAuthIsExpired(DeviceAuthSnapshot snapshot) {
  final DateTime? expiresAt = snapshot.expiresAt;
  if (expiresAt == null) {
    return false;
  }
  return DateTime.now().isAfter(expiresAt);
}

class DeviceAuthSnapshot {
  const DeviceAuthSnapshot({
    required this.activated,
    required this.deviceId,
    this.authCode = '',
    this.plan = LicensePlan.custom,
    this.expiresAt,
    this.username = '',
    this.lastVerifyTime,
    this.message = '',
  });

  final bool activated;
  final String deviceId;
  final String authCode;
  final LicensePlan plan;
  final DateTime? expiresAt;
  final String username;
  final DateTime? lastVerifyTime;
  final String message;


  String get statusText {
    if (!activated) {
      return message.isEmpty ? '未激活' : message;
    }
    if (plan == LicensePlan.lifetime || expiresAt == null) {
      return '已激活 · 终身';
    }
    final String date =
        '${expiresAt!.year}-${expiresAt!.month.toString().padLeft(2, '0')}-${expiresAt!.day.toString().padLeft(2, '0')}';
    if (deviceAuthIsExpired(this)) {
      return '已过期 · ${plan.labelZh} · $date';
    }
    return '已激活 · ${plan.labelZh} · 至 $date';
  }
}

/// One-device activation client against the Cloudflare Worker.
///
/// Policy for music_car_app:
/// - Unactivated: hard gate (no app usage)
/// - Plans: month / quarter / year / lifetime
/// - Offline grace: 7 days after last successful online verify
/// - After grace without network: block until online verify succeeds
class DeviceAuthService {
  DeviceAuthService({
    http.Client? client,
    String? baseUrl,
    this.offlineGrace = const Duration(days: 7),
  }) : _client = client ?? http.Client(),
       _baseUrl = (baseUrl ?? defaultBaseUrl).replaceAll(RegExp(r'/+$'), '');

  /// Override at build time:
  /// `--dart-define=DEVICE_AUTH_BASE_URL=https://your-worker.workers.dev`
  static const String defaultBaseUrl = String.fromEnvironment(
    'DEVICE_AUTH_BASE_URL',
    defaultValue: 'https://music.yosyou.com',
  );

  static const MethodChannel _channel = MethodChannel(
    'music_car_app/device_auth',
  );
  static const String _authFileName = 'device_auth_config.json';
  static const String _fallbackIdFileName = 'fallback_device_id.txt';

  final http.Client _client;
  final String _baseUrl;
  final Duration offlineGrace;

  String? _cachedDeviceId;
  DeviceAuthSnapshot? _cachedSnapshot;

  /// For tests: force activation state without network.
  static bool? testActivatedOverride;

  Future<String> getDeviceId() async {
    if (_cachedDeviceId != null && _cachedDeviceId!.isNotEmpty) {
      return _cachedDeviceId!;
    }
    String? deviceId;
    try {
      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS)) {
        deviceId = await _channel.invokeMethod<String>('getDeviceId');
      }
    } catch (error) {
      debugPrint('[device-auth] native getDeviceId failed: $error');
    }
    if (deviceId == null || deviceId.trim().isEmpty) {
      deviceId = await _getOrCreateFallbackDeviceId();
    }
    _cachedDeviceId = deviceId.trim();
    return _cachedDeviceId!;
  }

  Future<DeviceAuthSnapshot> currentSnapshot() async {
    if (testActivatedOverride != null) {
      final String id = await getDeviceId();
      return DeviceAuthSnapshot(
        activated: testActivatedOverride!,
        deviceId: id,
        message: testActivatedOverride! ? '测试放行' : '测试未激活',
      );
    }
    final DeviceAuthSnapshot? cached = _cachedSnapshot;
    if (cached != null) {
      return cached;
    }
    final Map<String, dynamic>? local = await _readLocalConfig();
    final String deviceId = await getDeviceId();
    if (local == null || (local['authCode']?.toString().isEmpty ?? true)) {
      final DeviceAuthSnapshot empty = DeviceAuthSnapshot(
        activated: false,
        deviceId: deviceId,
        message: '未激活',
      );
      _cachedSnapshot = empty;
      return empty;
    }
    final DeviceAuthSnapshot snapshot = _snapshotFromLocal(local, deviceId);
    _cachedSnapshot = snapshot;
    return snapshot;
  }

  /// Startup check: local cache + online verify when possible.
  /// Returns true only when the device may enter the app.
  Future<bool> ensureActivated({bool forceOnline = false}) async {
    if (testActivatedOverride != null) {
      return testActivatedOverride!;
    }
    final String deviceId = await getDeviceId();
    final Map<String, dynamic>? local = await _readLocalConfig();
    final String authCode = local?['authCode']?.toString() ?? '';
    if (authCode.isEmpty) {
      // Register pending request so admin can see the device.
      unawaited(_verifyRemote(deviceId: deviceId, authCode: ''));
      _cachedSnapshot = DeviceAuthSnapshot(
        activated: false,
        deviceId: deviceId,
        message: '请输入激活码',
      );
      return false;
    }

    final DateTime now = DateTime.now();
    final int lastVerifyMs =
        int.tryParse(local?['lastVerifyTime']?.toString() ?? '') ?? 0;
    final DateTime? lastVerify = lastVerifyMs > 0
        ? DateTime.fromMillisecondsSinceEpoch(lastVerifyMs)
        : null;
    final bool withinGrace =
        lastVerify != null && now.difference(lastVerify) <= offlineGrace;

    if (!forceOnline && withinGrace) {
      final DeviceAuthSnapshot snap = _snapshotFromLocal(local!, deviceId);
      if (deviceAuthIsExpired(snap)) {
        _cachedSnapshot = snap.copyWith(
          activated: false,
          message: '授权已过期，请联系管理员续期',
        );
        return false;
      }
      _cachedSnapshot = snap;
      // Fire-and-forget soft revalidate.
      unawaited(verifyActivation(authCode, silent: true));
      return true;
    }

    final DeviceAuthSnapshot online = await verifyActivation(
      authCode,
      silent: false,
    );
    return online.activated && !deviceAuthIsExpired(online);
  }

  Future<DeviceAuthSnapshot> verifyActivation(
    String authCode, {
    bool silent = false,
  }) async {
    final String deviceId = await getDeviceId();
    final String code = authCode.trim();
    if (code.isEmpty) {
      final DeviceAuthSnapshot empty = DeviceAuthSnapshot(
        activated: false,
        deviceId: deviceId,
        message: '请输入激活码',
      );
      if (!silent) {
        _cachedSnapshot = empty;
      }
      return empty;
    }

    try {
      final Map<String, dynamic> body = await _verifyRemote(
        deviceId: deviceId,
        authCode: code,
      );
      final bool success = body['success'] == true;
      if (!success) {
        // Hard reject (revoked / wrong code): clear local grant.
        await _clearLocalConfig();
        final DeviceAuthSnapshot denied = DeviceAuthSnapshot(
          activated: false,
          deviceId: deviceId,
          message: body['msg']?.toString() ?? '激活失败',
        );
        _cachedSnapshot = denied;
        return denied;
      }

      final LicensePlan plan = LicensePlan.fromWire(
        body['plan']?.toString() ?? '',
      );
      DateTime? expiresAt;
      final Object? expiresRaw = body['expiresAt'] ?? body['expires_at'];
      if (expiresRaw is int) {
        expiresAt = DateTime.fromMillisecondsSinceEpoch(expiresRaw);
      } else if (expiresRaw is String && expiresRaw.isNotEmpty) {
        expiresAt = DateTime.tryParse(expiresRaw);
      }

      final Map<String, dynamic> local = <String, dynamic>{
        'deviceId': deviceId,
        'authCode': code,
        'plan': plan.wireValue,
        'expiresAt': expiresAt?.millisecondsSinceEpoch,
        'username': body['username']?.toString() ?? '',
        'lastVerifyTime': DateTime.now().millisecondsSinceEpoch,
      };
      await _writeLocalConfig(local);
      final DeviceAuthSnapshot ok = _snapshotFromLocal(local, deviceId).copyWith(
        activated: true,
        message: body['msg']?.toString() ?? '激活成功',
      );
      _cachedSnapshot = ok;
      return ok;
    } on SocketException {
      return _offlineFallback(
        deviceId: deviceId,
        authCode: code,
        message: '网络不可用',
      );
    } on TimeoutException {
      return _offlineFallback(
        deviceId: deviceId,
        authCode: code,
        message: '网络超时',
      );
    } catch (error) {
      debugPrint('[device-auth] verify failed: $error');
      return _offlineFallback(
        deviceId: deviceId,
        authCode: code,
        message: '校验异常：$error',
      );
    }
  }

  Future<void> clearActivation() async {
    await _clearLocalConfig();
    _cachedSnapshot = DeviceAuthSnapshot(
      activated: false,
      deviceId: await getDeviceId(),
      message: '已清除本地激活',
    );
  }

  Future<DeviceAuthSnapshot> _offlineFallback({
    required String deviceId,
    required String authCode,
    required String message,
  }) async {
    final Map<String, dynamic>? local = await _readLocalConfig();
    if (local == null || (local['authCode']?.toString().isEmpty ?? true)) {
      final DeviceAuthSnapshot denied = DeviceAuthSnapshot(
        activated: false,
        deviceId: deviceId,
        message: message,
      );
      _cachedSnapshot = denied;
      return denied;
    }
    final int lastVerifyMs =
        int.tryParse(local['lastVerifyTime']?.toString() ?? '') ?? 0;
    final DateTime? lastVerify = lastVerifyMs > 0
        ? DateTime.fromMillisecondsSinceEpoch(lastVerifyMs)
        : null;
    final bool withinGrace =
        lastVerify != null &&
        DateTime.now().difference(lastVerify) <= offlineGrace;
    final DeviceAuthSnapshot snap = _snapshotFromLocal(local, deviceId);
    if (withinGrace && !deviceAuthIsExpired(snap)) {
      final DeviceAuthSnapshot ok = snap.copyWith(
        activated: true,
        message: '$message（离线宽限中）',
      );
      _cachedSnapshot = ok;
      return ok;
    }
    final DeviceAuthSnapshot denied = snap.copyWith(
      activated: false,
      message: withinGrace ? message : '离线超过 $offlineGrace，请联网重新验证',
    );
    _cachedSnapshot = denied;
    return denied;
  }

  Future<Map<String, dynamic>> _verifyRemote({
    required String deviceId,
    required String authCode,
  }) async {
    final Uri uri = Uri.parse('$_baseUrl/verify');
    final http.Response response = await _client
        .post(
          uri,
          headers: const <String, String>{
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(<String, Object?>{
            'deviceId': deviceId,
            'authCode': authCode,
          }),
        )
        .timeout(const Duration(seconds: 8));
    final Object? decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.map(
        (Object? key, Object? value) => MapEntry<String, dynamic>('$key', value),
      );
    }
    return <String, dynamic>{
      'success': false,
      'msg': '无效响应 (${response.statusCode})',
    };
  }

  DeviceAuthSnapshot _snapshotFromLocal(
    Map<String, dynamic> local,
    String deviceId,
  ) {
    final String authCode = local['authCode']?.toString() ?? '';
    final LicensePlan plan = LicensePlan.fromWire(local['plan']?.toString());
    DateTime? expiresAt;
    final Object? expiresRaw = local['expiresAt'];
    if (expiresRaw is int) {
      expiresAt = DateTime.fromMillisecondsSinceEpoch(expiresRaw);
    } else if (expiresRaw is String) {
      final int? ms = int.tryParse(expiresRaw);
      if (ms != null) {
        expiresAt = DateTime.fromMillisecondsSinceEpoch(ms);
      }
    }
    final int lastVerifyMs =
        int.tryParse(local['lastVerifyTime']?.toString() ?? '') ?? 0;
    return DeviceAuthSnapshot(
      activated: authCode.isNotEmpty,
      deviceId: deviceId,
      authCode: authCode,
      plan: plan,
      expiresAt: expiresAt,
      username: local['username']?.toString() ?? '',
      lastVerifyTime: lastVerifyMs > 0
          ? DateTime.fromMillisecondsSinceEpoch(lastVerifyMs)
          : null,
    );
  }

  Future<Map<String, dynamic>?> _readLocalConfig() async {
    try {
      final File file = await _authFile();
      if (!await file.exists()) {
        return null;
      }
      final Object? decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.map(
          (Object? key, Object? value) =>
              MapEntry<String, dynamic>('$key', value),
        );
      }
    } catch (error) {
      debugPrint('[device-auth] read local failed: $error');
    }
    return null;
  }

  Future<void> _writeLocalConfig(Map<String, dynamic> data) async {
    final File file = await _authFile();
    await file.writeAsString(jsonEncode(data));
  }

  Future<void> _clearLocalConfig() async {
    try {
      final File file = await _authFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  Future<File> _authFile() async {
    final Directory dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_authFileName');
  }

  Future<String> _getOrCreateFallbackDeviceId() async {
    try {
      final Directory dir = await getApplicationDocumentsDirectory();
      final File file = File('${dir.path}/$_fallbackIdFileName');
      if (await file.exists()) {
        final String existing = (await file.readAsString()).trim();
        if (existing.isNotEmpty) {
          return existing;
        }
      }
      final String id = 'FALLBACK-${_uuidV4()}';
      await file.writeAsString(id);
      return id;
    } catch (_) {
      return 'FALLBACK-TEMP-${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  String _uuidV4() {
    final Random random = Random.secure();
    final List<int> bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < 16; i++) {
      if (i == 4 || i == 6 || i == 8 || i == 10) {
        buffer.write('-');
      }
      buffer.write(bytes[i].toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }
}

extension on DeviceAuthSnapshot {
  DeviceAuthSnapshot copyWith({
    bool? activated,
    String? deviceId,
    String? authCode,
    LicensePlan? plan,
    DateTime? expiresAt,
    String? username,
    DateTime? lastVerifyTime,
    String? message,
  }) {
    return DeviceAuthSnapshot(
      activated: activated ?? this.activated,
      deviceId: deviceId ?? this.deviceId,
      authCode: authCode ?? this.authCode,
      plan: plan ?? this.plan,
      expiresAt: expiresAt ?? this.expiresAt,
      username: username ?? this.username,
      lastVerifyTime: lastVerifyTime ?? this.lastVerifyTime,
      message: message ?? this.message,
    );
  }
}
