import 'package:flutter_test/flutter_test.dart';
import 'package:music_car_app/features/settings/portrait_settings_view.dart';

void main() {
  test('qualityTierForBitrate matches exact option values first', () {
    expect(qualityTierForBitrate('48kaac'), '48kaac');
    expect(qualityTierForBitrate('128kmp3'), '128kmp3');
    expect(qualityTierForBitrate('320kmp3'), '320kmp3');
    expect(qualityTierForBitrate('flac'), 'flac');
  });

  test('qualityTierForBitrate falls back for legacy stored values', () {
    expect(qualityTierForBitrate('320'), '320kmp3');
    expect(qualityTierForBitrate('128k'), '128kmp3');
    expect(qualityTierForBitrate('lossless'), 'flac');
  });

  test('qualityOptionSelected tracks the tapped option immediately', () {
    expect(qualityOptionSelected('320kmp3', '320kmp3'), isTrue);
    expect(qualityOptionSelected('320kmp3', '128kmp3'), isFalse);
    expect(qualityOptionSelected('flac', 'flac'), isTrue);
  });
}
