import 'package:device_geolocation/device_geolocation_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

class _Helpers extends DeviceGeolocationPlatform {}

void main() {
  final h = _Helpers();

  test('distanceBetween Amsterdam <-> Enschede ~143 km', () {
    final d = h.distanceBetween(52.2165157, 6.9437819, 52.3546274, 4.8285838);
    expect(d, closeTo(143000, 2000));
  });

  test('distanceBetween same point is 0', () {
    expect(h.distanceBetween(41, 2, 41, 2), 0);
  });

  test('bearingBetween due east is ~90 deg', () {
    final b = h.bearingBetween(0, 0, 0, 1);
    expect(b, closeTo(90, 0.01));
  });

  test('bearingBetween due north is ~0 deg', () {
    final b = h.bearingBetween(0, 0, 1, 0);
    expect(b, closeTo(0, 0.01));
  });
}
