import 'package:device_geolocation/device_geolocation_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

/// Bare extension that does not override any method, so calls fall through
/// to the default `UnimplementedError`-throwing implementations.
class _BareImpl extends DeviceGeolocationPlatform {}

void main() {
  final p = _BareImpl();

  test(
    'every overridable method throws UnimplementedError by default',
    () async {
      expect(p.checkPermission, throwsUnimplementedError);
      expect(p.requestPermission, throwsUnimplementedError);
      expect(p.isLocationServiceEnabled, throwsUnimplementedError);
      expect(p.getCurrentPosition, throwsUnimplementedError);
      expect(() => p.getPositionStream(), throwsUnimplementedError);
      expect(() => p.getPermissionStream(), throwsUnimplementedError);
      expect(p.getServiceStatusStream, throwsUnimplementedError);
      expect(p.getLocationAccuracy, throwsUnimplementedError);
      expect(
        () => p.requestTemporaryFullAccuracy(purposeKey: 'k'),
        throwsUnimplementedError,
      );
      expect(p.openAppSettings, throwsUnimplementedError);
      expect(p.openLocationSettings, throwsUnimplementedError);
      expect(() => p.settingsOpenedStream, throwsUnimplementedError);
    },
  );

  test('setting instance to a non-mock subclass requires the token', () {
    // Reassigning a properly-extended subclass is fine.
    DeviceGeolocationPlatform.instance = _BareImpl();
    expect(DeviceGeolocationPlatform.instance, isA<_BareImpl>());
  });
}
