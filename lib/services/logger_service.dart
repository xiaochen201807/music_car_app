import 'package:flutter/foundation.dart';

class Logger {
  static final Logger _instance = Logger._internal();
  factory Logger() => _instance;
  Logger._internal();

  void log(String message, {Object? error, StackTrace? stackTrace}) {
    final timestamp = DateTime.now().toIso8601String();
    debugPrint('[$timestamp] $message');
    if (error != null) {
      debugPrint('Error: $error');
    }
    if (stackTrace != null) {
      debugPrint('StackTrace: $stackTrace');
    }
  }

  void info(String message) => log('[INFO] $message');
  void warn(String message) => log('[WARN] $message');
  void error(String message, {Object? error, StackTrace? stackTrace}) {
    log('[ERROR] $message', error: error, stackTrace: stackTrace);
  }
}
