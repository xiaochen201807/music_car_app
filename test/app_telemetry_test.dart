import 'package:flutter_test/flutter_test.dart';
import 'package:music_car_app/services/app_telemetry.dart';

void main() {
  test('keeps a bounded event buffer', () {
    final AppTelemetry telemetry = AppTelemetry(maxEvents: 2);

    telemetry
      ..record('one')
      ..record('two')
      ..record('three');

    expect(telemetry.events.map((AppTelemetryEvent e) => e.name), <String>[
      'two',
      'three',
    ]);
  });

  test('exports diagnostics with sensitive fields redacted', () {
    final AppTelemetry telemetry = AppTelemetry(maxEvents: 5);

    telemetry.record(
      'url_resolve',
      attributes: <String, Object?>{
        'source': 'kuwo',
        'token': 'secret',
        'url': 'https://example.com/play?id=1&token=secret',
      },
    );

    final String json = telemetry.exportJson(
      app: <String, Object?>{'cookie': 'private'},
    );

    expect(json, contains('"token": "<redacted>"'));
    expect(json, contains('"cookie": "<redacted>"'));
    expect(json, contains('https://example.com/play'));
    expect(json, isNot(contains('token=secret')));
  });
}
