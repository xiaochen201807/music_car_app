import 'dart:convert';

import 'package:flutter/foundation.dart';

class AppTelemetryEvent {
  const AppTelemetryEvent({
    required this.name,
    required this.timestamp,
    this.duration,
    this.attributes = const <String, Object?>{},
    this.error,
  });

  final String name;
  final DateTime timestamp;
  final Duration? duration;
  final Map<String, Object?> attributes;
  final String? error;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'name': name,
      'timestamp': timestamp.toIso8601String(),
      if (duration != null) 'durationMs': duration!.inMilliseconds,
      if (attributes.isNotEmpty) 'attributes': attributes,
      if (error != null && error!.isNotEmpty) 'error': error,
    };
  }
}

class AppTelemetry {
  AppTelemetry({this.maxEvents = 200});

  static final AppTelemetry instance = AppTelemetry();

  final int maxEvents;
  final List<AppTelemetryEvent> _events = <AppTelemetryEvent>[];

  List<AppTelemetryEvent> get events =>
      List<AppTelemetryEvent>.unmodifiable(_events);

  void record(
    String name, {
    Duration? duration,
    Map<String, Object?> attributes = const <String, Object?>{},
    Object? error,
  }) {
    final AppTelemetryEvent event = AppTelemetryEvent(
      name: name,
      timestamp: DateTime.now(),
      duration: duration,
      attributes: _sanitizeAttributes(attributes),
      error: _sanitizeError(error),
    );
    _events.add(event);
    if (_events.length > maxEvents) {
      _events.removeRange(0, _events.length - maxEvents);
    }
    debugPrint('[telemetry] ${jsonEncode(event.toJson())}');
  }

  Future<T> time<T>(
    String name,
    Future<T> Function() action, {
    Map<String, Object?> attributes = const <String, Object?>{},
  }) async {
    final Stopwatch stopwatch = Stopwatch()..start();
    try {
      final T result = await action();
      record(name, duration: stopwatch.elapsed, attributes: attributes);
      return result;
    } catch (error) {
      record(
        '$name.error',
        duration: stopwatch.elapsed,
        attributes: attributes,
        error: error,
      );
      rethrow;
    }
  }

  String exportJson({Map<String, Object?> app = const <String, Object?>{}}) {
    return const JsonEncoder.withIndent('  ').convert(<String, Object?>{
      'schema': 1,
      'generatedAt': DateTime.now().toIso8601String(),
      'app': _sanitizeAttributes(app),
      'events': _events
          .map<Map<String, Object?>>(
            (AppTelemetryEvent event) => event.toJson(),
          )
          .toList(growable: false),
    });
  }

  void clear() {
    _events.clear();
  }
}

Map<String, Object?> _sanitizeAttributes(Map<String, Object?> attributes) {
  final Map<String, Object?> sanitized = <String, Object?>{};
  for (final MapEntry<String, Object?> entry in attributes.entries) {
    final String key = entry.key;
    final String lowerKey = key.toLowerCase();
    if (lowerKey.contains('cookie') ||
        lowerKey.contains('token') ||
        lowerKey.contains('secret') ||
        lowerKey.contains('authorization')) {
      sanitized[key] = '<redacted>';
      continue;
    }
    final Object? value = entry.value;
    if (value is Uri) {
      sanitized[key] = value.replace(query: '').toString();
    } else if (value is String && _looksLikeUrl(value)) {
      sanitized[key] = _redactUrl(value);
    } else {
      sanitized[key] = value;
    }
  }
  return sanitized;
}

String? _sanitizeError(Object? error) {
  if (error == null) {
    return null;
  }
  final String value = error.toString();
  return _looksLikeUrl(value) ? _redactUrl(value) : value;
}

bool _looksLikeUrl(String value) {
  return value.startsWith('http://') || value.startsWith('https://');
}

String _redactUrl(String value) {
  final Uri? uri = Uri.tryParse(value);
  if (uri == null || !uri.hasScheme) {
    return '<redacted-url>';
  }
  final String port = uri.hasPort ? ':${uri.port}' : '';
  return '${uri.scheme}://${uri.host}$port${uri.path}';
}
