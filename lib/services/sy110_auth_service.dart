import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Sy110 认证服务
///
/// 自动管理登录状态和 token，使用固定的用户凭证。
/// Token 存储在本地，自动刷新过期的 token。
class Sy110AuthService {
  Sy110AuthService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  static const String _baseUrl = 'https://music.sy110.eu.org';
  static const String _username = 'xiaochen';
  static const String _password = 'guan5952';

  // SharedPreferences keys
  static const String _keyAccessToken = 'sy110_access_token';
  static const String _keyRefreshToken = 'sy110_refresh_token';
  static const String _keyTokenExpiry = 'sy110_token_expiry';

  String? _accessToken;
  String? _refreshToken;
  DateTime? _tokenExpiry;

  /// 获取当前的 access token
  ///
  /// 如果 token 不存在或已过期，会自动登录/刷新
  Future<String?> getAccessToken() async {
    // 如果已有 token 且未过期，直接返回
    if (_accessToken != null && _tokenExpiry != null) {
      if (DateTime.now().isBefore(_tokenExpiry!)) {
        return _accessToken;
      }
    }

    // Token 过期或不存在，尝试从本地加载
    await _loadTokensFromStorage();

    // 检查加载的 token 是否有效
    if (_accessToken != null && _tokenExpiry != null) {
      if (DateTime.now().isBefore(_tokenExpiry!)) {
        return _accessToken;
      }
    }

    // Token 无效，尝试刷新或重新登录
    if (_refreshToken != null) {
      final bool refreshed = await _refreshAccessToken();
      if (refreshed) {
        return _accessToken;
      }
    }

    // 刷新失败，重新登录
    final bool loggedIn = await _login();
    return loggedIn ? _accessToken : null;
  }

  /// 获取当前的 refresh token
  Future<String?> getRefreshToken() async {
    if (_refreshToken != null) {
      return _refreshToken;
    }

    await _loadTokensFromStorage();
    return _refreshToken;
  }

  /// 执行登录
  Future<bool> _login() async {
    try {
      final Uri uri = Uri.parse('$_baseUrl/api/v1/auth/login');
      final http.Response response = await _client.post(
        uri,
        headers: <String, String>{
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, String>{
          'username': _username,
          'password': _password,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Object? decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded['code'] == 0) {
          final Map<String, dynamic>? data =
              decoded['data'] as Map<String, dynamic>?;
          if (data != null) {
            _accessToken = data['access_token'] as String?;
            _refreshToken = data['refresh_token'] as String?;

            // Token 有效期为 7200 秒（2小时）
            final int expiresIn = data['expires_in'] as int? ?? 7200;
            _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));

            await _saveTokensToStorage();
            return true;
          }
        }
      }
    } catch (e) {
      // 登录失败，静默处理
    }

    return false;
  }

  /// 刷新 access token
  Future<bool> _refreshAccessToken() async {
    if (_refreshToken == null) {
      return false;
    }

    try {
      final Uri uri = Uri.parse('$_baseUrl/api/v1/auth/refresh');
      final http.Response response = await _client.post(
        uri,
        headers: <String, String>{
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, String>{
          'refresh_token': _refreshToken!,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Object? decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded['code'] == 0) {
          final Map<String, dynamic>? data =
              decoded['data'] as Map<String, dynamic>?;
          if (data != null) {
            _accessToken = data['access_token'] as String?;

            // 新的 access token 有效期
            final int expiresIn = data['expires_in'] as int? ?? 7200;
            _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));

            // 可能返回新的 refresh token
            if (data.containsKey('refresh_token')) {
              _refreshToken = data['refresh_token'] as String?;
            }

            await _saveTokensToStorage();
            return true;
          }
        }
      }
    } catch (e) {
      // 刷新失败，静默处理
    }

    return false;
  }

  /// 从本地存储加载 tokens
  Future<void> _loadTokensFromStorage() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      _accessToken = prefs.getString(_keyAccessToken);
      _refreshToken = prefs.getString(_keyRefreshToken);

      final int? expiryMillis = prefs.getInt(_keyTokenExpiry);
      if (expiryMillis != null) {
        _tokenExpiry = DateTime.fromMillisecondsSinceEpoch(expiryMillis);
      }
    } catch (e) {
      // 加载失败，静默处理
    }
  }

  /// 保存 tokens 到本地存储
  Future<void> _saveTokensToStorage() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      if (_accessToken != null) {
        await prefs.setString(_keyAccessToken, _accessToken!);
      }

      if (_refreshToken != null) {
        await prefs.setString(_keyRefreshToken, _refreshToken!);
      }

      if (_tokenExpiry != null) {
        await prefs.setInt(
          _keyTokenExpiry,
          _tokenExpiry!.millisecondsSinceEpoch,
        );
      }
    } catch (e) {
      // 保存失败，静默处理
    }
  }

  /// 清除本地存储的 tokens
  Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    _tokenExpiry = null;

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyAccessToken);
      await prefs.remove(_keyRefreshToken);
      await prefs.remove(_keyTokenExpiry);
    } catch (e) {
      // 清除失败，静默处理
    }
  }

  /// 获取认证请求头（Cookie）
  ///
  /// 返回包含 access_token 和 refresh_token 的 Cookie 头
  Future<Map<String, String>> getAuthHeaders() async {
    final String? accessToken = await getAccessToken();
    final String? refreshToken = await getRefreshToken();

    if (accessToken == null) {
      return <String, String>{};
    }

    final StringBuffer cookie = StringBuffer('access_token=$accessToken');

    if (refreshToken != null) {
      cookie.write('; refresh_token=$refreshToken');
    }

    cookie.write('; session_id=1004');

    return <String, String>{
      'Cookie': cookie.toString(),
    };
  }

  void close() {
    _client.close();
  }
}
