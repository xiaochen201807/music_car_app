import 'package:flutter_test/flutter_test.dart';
import 'package:music_car_app/player_probe_script.dart';

void main() {
  test('player probe script installs the expected Flutter bridge', () {
    expect(playerProbeHandlerName, 'musicPlayerProbe');
    expect(
      playerProbeScriptSource,
      contains("bridge.callHandler('musicPlayerProbe', payload)"),
    );
  });

  test('player probe script observes audio and page metadata', () {
    expect(
      playerProbeScriptSource,
      contains("document.querySelector('audio')"),
    );
    expect(playerProbeScriptSource, contains('currentSrc'));
    expect(playerProbeScriptSource, contains('audioUrl'));
    expect(playerProbeScriptSource, contains('title'));
    expect(playerProbeScriptSource, contains('artist'));
    expect(playerProbeScriptSource, contains('coverUrl'));
    expect(playerProbeScriptSource, contains('MutationObserver'));
  });

  test('player probe script throttles duplicate time updates', () {
    expect(playerProbeScriptSource, contains('lastSignature'));
    expect(playerProbeScriptSource, contains('lastSentAt'));
    expect(playerProbeScriptSource, contains("eventName !== 'timeupdate'"));
  });

  test('player probe script suppresses native audio pause feedback', () {
    expect(playerProbeScriptSource, contains('__musicCarSuppressPauseUntil'));
    expect(playerProbeScriptSource, contains("reason === 'audio:pause'"));
  });
}
