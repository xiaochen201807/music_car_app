import 'package:flutter_test/flutter_test.dart';
import 'package:music_car_app/features/settings/portrait_settings_view.dart';

void main() {
  test('releaseApkUrlForVersion builds arm64 CDN path', () {
    expect(
      releaseApkUrlForVersion('1.0.88'),
      'https://s3.sy110.eu.org/music_car_app/v1.0.88/app-arm64-v8a-release.apk',
    );
    expect(
      releaseApkUrlForVersion('v1.0.87'),
      'https://s3.sy110.eu.org/music_car_app/v1.0.87/app-arm64-v8a-release.apk',
    );
    expect(
      releaseApkUrlForVersion('1.0.88+10088'),
      'https://s3.sy110.eu.org/music_car_app/v1.0.88/app-arm64-v8a-release.apk',
    );
  });
}
