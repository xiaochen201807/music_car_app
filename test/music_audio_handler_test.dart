import 'package:flutter_test/flutter_test.dart';
import 'package:music_car_app/music_audio_handler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('autoSkipToNextAfterCompletion triggers next once', () async {
    final MusicAudioHandler handler = MusicAudioHandler();
    int nextCalls = 0;
    handler.onSkipToNextTrack = () async {
      nextCalls += 1;
    };

    await handler.autoSkipToNextAfterCompletion();
    await handler.autoSkipToNextAfterCompletion();

    expect(nextCalls, 1);

    await handler.dispose();
  });
}
