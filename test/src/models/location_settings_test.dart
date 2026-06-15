import 'package:device_geolocation/device_geolocation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DeviceLocationSettings', () {
    test('defaults', () {
      const s = DeviceLocationSettings();
      expect(s.accuracy, DeviceLocationAccuracy.best);
      expect(s.distanceFilter, 0);
      expect(s.timeLimit, isNull);
      expect(s.toJson(), {
        'accuracy': DeviceLocationAccuracy.best.index,
        'distanceFilter': 0,
      });
    });

    test('serializes timeLimit when set', () {
      const s = DeviceLocationSettings(timeLimit: Duration(seconds: 5));
      expect(s.toJson()['timeLimit'], 5000);
    });
  });

  group('AndroidSettings', () {
    test('toJson includes Android keys', () {
      const s = AndroidSettings(
        accuracy: DeviceLocationAccuracy.high,
        distanceFilter: 10,
        forceLocationManager: true,
        intervalDuration: Duration(seconds: 2),
      );
      final json = s.toJson();
      expect(json['accuracy'], DeviceLocationAccuracy.high.index);
      expect(json['distanceFilter'], 10);
      expect(json['forceLocationManager'], true);
      expect(json['intervalDuration'], 2000);
    });
  });

  group('AppleSettings', () {
    test('toJson includes Apple keys', () {
      const s = AppleSettings(
        activityType: ActivityType.fitness,
        pauseLocationUpdatesAutomatically: true,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );
      final json = s.toJson();
      expect(json['activityType'], ActivityType.fitness.index);
      expect(json['pauseLocationUpdatesAutomatically'], true);
      expect(json['showBackgroundLocationIndicator'], true);
      expect(json['allowBackgroundLocationUpdates'], true);
    });
  });

  group('WebSettings', () {
    test('toJson includes maximumAge', () {
      const s = WebSettings(maximumAge: Duration(seconds: 30));
      expect(s.toJson()['maximumAge'], 30000);
    });
  });
}
