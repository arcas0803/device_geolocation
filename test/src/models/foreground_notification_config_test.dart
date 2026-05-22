import 'package:device_geolocation/device_geolocation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AndroidResource', () {
    test('defaults match the launcher icon', () {
      const r = AndroidResource();
      expect(r.name, 'ic_launcher');
      expect(r.defType, 'mipmap');
      expect(r.toJson(), {'name': 'ic_launcher', 'defType': 'mipmap'});
    });

    test('equality and hashCode', () {
      const a = AndroidResource(name: 'ic_stat', defType: 'drawable');
      const b = AndroidResource(name: 'ic_stat', defType: 'drawable');
      const c = AndroidResource(name: 'ic_stat', defType: 'mipmap');
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
    });
  });

  group('ForegroundNotificationConfig', () {
    test('toJson emits all keys with defaults', () {
      const cfg = ForegroundNotificationConfig(
        notificationTitle: 'Tracking',
        notificationText: 'Sharing your location',
      );
      expect(cfg.toJson(), {
        'notificationTitle': 'Tracking',
        'notificationText': 'Sharing your location',
        'notificationChannelName': 'Background Location',
        'notificationIcon': {'name': 'ic_launcher', 'defType': 'mipmap'},
        'enableWakeLock': false,
        'enableWifiLock': false,
        'setOngoing': false,
        'color': null,
      });
    });

    test('toJson reflects custom values', () {
      const cfg = ForegroundNotificationConfig(
        notificationTitle: 'Run',
        notificationText: 'Recording route',
        notificationChannelName: 'Activity tracking',
        notificationIcon: AndroidResource(
          name: 'ic_stat_notify',
          defType: 'drawable',
        ),
        enableWakeLock: true,
        enableWifiLock: true,
        setOngoing: true,
        color: 0xFF2196F3,
      );
      final json = cfg.toJson();
      expect(json['notificationChannelName'], 'Activity tracking');
      expect(json['notificationIcon'], {
        'name': 'ic_stat_notify',
        'defType': 'drawable',
      });
      expect(json['enableWakeLock'], true);
      expect(json['enableWifiLock'], true);
      expect(json['setOngoing'], true);
      expect(json['color'], 0xFF2196F3);
    });

    test('equality and hashCode', () {
      const a = ForegroundNotificationConfig(
        notificationTitle: 't',
        notificationText: 'x',
      );
      const b = ForegroundNotificationConfig(
        notificationTitle: 't',
        notificationText: 'x',
      );
      const c = ForegroundNotificationConfig(
        notificationTitle: 't',
        notificationText: 'y',
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
    });
  });

  group('AndroidSettings.foregroundNotificationConfig', () {
    test('toJson omits key when null', () {
      const s = AndroidSettings();
      expect(s.toJson().containsKey('foregroundNotificationConfig'), isFalse);
    });

    test('toJson nests config when present', () {
      const s = AndroidSettings(
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationTitle: 'Tracking',
          notificationText: 'Sharing your location',
        ),
      );
      final json = s.toJson();
      expect(json['foregroundNotificationConfig'], isA<Map<String, dynamic>>());
      expect(
        json['foregroundNotificationConfig']['notificationTitle'],
        'Tracking',
      );
    });
  });
}
