import 'package:device_geolocation/device_geolocation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('distanceBetween', () {
    const amsterdamLat = 52.2165157;
    const amsterdamLon = 6.9437819;
    const enschedeLat = 52.3546274;
    const enschedeLon = 4.8285838;

    test('Amsterdam <-> Enschede ~145 km with Vincenty', () {
      final d = DeviceGeolocation.distanceBetween(
        amsterdamLat,
        amsterdamLon,
        enschedeLat,
        enschedeLon,
      );
      expect(d, closeTo(145150, 1000));
    });

    test('Amsterdam <-> Enschede ~145 km with Haversine', () {
      final d = DeviceGeolocation.distanceBetween(
        amsterdamLat,
        amsterdamLon,
        enschedeLat,
        enschedeLon,
        algorithm: GeospatialAlgorithm.haversine,
      );
      expect(d, closeTo(145150, 2000));
    });

    test('same point is 0', () {
      expect(DeviceGeolocation.distanceBetween(41, 2, 41, 2), 0);
    });

    test('crosses antimeridian using shortest path', () {
      final d = DeviceGeolocation.distanceBetween(0, 179, 0, -179);
      expect(d, closeTo(222390, 1000));
    });
  });

  group('distanceBetweenIsolate', () {
    test('matches synchronous Vincenty result', () async {
      const startLat = 10.0;
      const startLon = 20.0;
      const endLat = 30.0;
      const endLon = 40.0;

      final sync = DeviceGeolocation.distanceBetween(
        startLat,
        startLon,
        endLat,
        endLon,
      );
      final async = await DeviceGeolocation.distanceBetweenIsolate(
        startLat,
        startLon,
        endLat,
        endLon,
      );
      expect(async, sync);
    });

    test('matches synchronous Haversine result', () async {
      const startLat = 10.0;
      const startLon = 20.0;
      const endLat = 30.0;
      const endLon = 40.0;

      final sync = DeviceGeolocation.distanceBetween(
        startLat,
        startLon,
        endLat,
        endLon,
        algorithm: GeospatialAlgorithm.haversine,
      );
      final async = await DeviceGeolocation.distanceBetweenIsolate(
        startLat,
        startLon,
        endLat,
        endLon,
        algorithm: GeospatialAlgorithm.haversine,
      );
      expect(async, sync);
    });
  });

  group('bearingBetween', () {
    test('due east is ~90 deg', () {
      final b = DeviceGeolocation.bearingBetween(0, 0, 0, 1);
      expect(b, closeTo(90, 0.01));
    });

    test('due north is ~0 deg', () {
      final b = DeviceGeolocation.bearingBetween(0, 0, 1, 0);
      expect(b, closeTo(0, 0.01));
    });
  });

  group('bearingBetweenIsolate', () {
    test('matches synchronous bearing result', () async {
      const startLat = 10.0;
      const startLon = 20.0;
      const endLat = 30.0;
      const endLon = 40.0;

      final sync = DeviceGeolocation.bearingBetween(
        startLat,
        startLon,
        endLat,
        endLon,
      );
      final async = await DeviceGeolocation.bearingBetweenIsolate(
        startLat,
        startLon,
        endLat,
        endLon,
      );
      expect(async, sync);
    });
  });
}
