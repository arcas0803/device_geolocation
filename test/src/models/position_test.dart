import 'package:device_geolocation/device_geolocation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DevicePosition', () {
    final timestamp = DateTime.fromMillisecondsSinceEpoch(
      1700000000000,
      isUtc: true,
    );

    DevicePosition sample({bool isMocked = false, int? floor}) =>
        DevicePosition(
          latitude: 41.3851,
          longitude: 2.1734,
          timestamp: timestamp,
          accuracy: 5.0,
          altitude: 12.0,
          altitudeAccuracy: 1.5,
          heading: 90.0,
          headingAccuracy: 0.5,
          speed: 1.2,
          speedAccuracy: 0.1,
          floor: floor,
          isMocked: isMocked,
        );

    test('toJson <-> fromMap is a round-trip', () {
      final original = sample(isMocked: true, floor: 3);
      final restored = DevicePosition.fromMap(original.toJson());
      expect(restored, equals(original));
    });

    test('fromMap fills optional fields with defaults', () {
      final p = DevicePosition.fromMap(<String, dynamic>{
        'latitude': 1.0,
        'longitude': 2.0,
      });
      expect(p.latitude, 1.0);
      expect(p.longitude, 2.0);
      expect(p.accuracy, 0.0);
      expect(p.altitude, 0.0);
      expect(p.floor, isNull);
      expect(p.isMocked, isFalse);
    });

    test('fromMap throws when latitude is missing', () {
      expect(
        () => DevicePosition.fromMap(<String, dynamic>{'longitude': 1.0}),
        throwsArgumentError,
      );
    });

    test('fromMap throws when longitude is missing', () {
      expect(
        () => DevicePosition.fromMap(<String, dynamic>{'latitude': 1.0}),
        throwsArgumentError,
      );
    });

    test('equality and hashCode are value-based', () {
      expect(sample(), equals(sample()));
      expect(sample().hashCode, equals(sample().hashCode));
    });

    test('toString includes coordinates', () {
      expect(sample().toString(), contains('41.3851'));
      expect(sample().toString(), contains('2.1734'));
    });
  });
}
