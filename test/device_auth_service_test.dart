import 'package:flutter_test/flutter_test.dart';
import 'package:music_car_app/services/device_auth_service.dart';

void main() {
  test('LicensePlan parses wire values and labels', () {
    expect(LicensePlan.fromWire('month'), LicensePlan.month);
    expect(LicensePlan.fromWire('quarter'), LicensePlan.quarter);
    expect(LicensePlan.fromWire('year'), LicensePlan.year);
    expect(LicensePlan.fromWire('lifetime'), LicensePlan.lifetime);
    expect(LicensePlan.fromWire('终身'), LicensePlan.lifetime);
    expect(LicensePlan.month.labelZh, '月卡');
    expect(LicensePlan.quarter.labelZh, '季卡');
    expect(LicensePlan.year.labelZh, '年卡');
    expect(LicensePlan.lifetime.labelZh, '终身');
  });

  test('testActivatedOverride forces ensureActivated result', () async {
    final DeviceAuthService service = DeviceAuthService(
      baseUrl: 'https://example.test',
    );
    DeviceAuthService.testActivatedOverride = false;
    expect(await service.ensureActivated(), isFalse);
    DeviceAuthService.testActivatedOverride = true;
    expect(await service.ensureActivated(), isTrue);
    DeviceAuthService.testActivatedOverride = null;
  });

  test('deviceAuthIsExpired treats null expiry as not expired', () {
    const DeviceAuthSnapshot lifetime = DeviceAuthSnapshot(
      activated: true,
      deviceId: 'device-1',
      plan: LicensePlan.lifetime,
    );
    expect(deviceAuthIsExpired(lifetime), isFalse);

    final DeviceAuthSnapshot expired = DeviceAuthSnapshot(
      activated: true,
      deviceId: 'device-1',
      plan: LicensePlan.month,
      expiresAt: DateTime.now().subtract(const Duration(days: 1)),
    );
    expect(deviceAuthIsExpired(expired), isTrue);

    final DeviceAuthSnapshot active = DeviceAuthSnapshot(
      activated: true,
      deviceId: 'device-1',
      plan: LicensePlan.year,
      expiresAt: DateTime.now().add(const Duration(days: 10)),
    );
    expect(deviceAuthIsExpired(active), isFalse);
  });

  test('statusText describes activation plans', () {
    const DeviceAuthSnapshot inactive = DeviceAuthSnapshot(
      activated: false,
      deviceId: 'device-1',
      message: '请输入激活码',
    );
    expect(inactive.statusText, '请输入激活码');

    const DeviceAuthSnapshot lifetime = DeviceAuthSnapshot(
      activated: true,
      deviceId: 'device-1',
      plan: LicensePlan.lifetime,
    );
    expect(lifetime.statusText, contains('终身'));
  });
}
