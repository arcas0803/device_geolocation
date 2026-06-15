import 'dart:async';

import 'package:device_geolocation/device_geolocation.dart';
import 'package:device_geolocation/testing.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DeviceGeolocationMock mock;

  setUp(() {
    mock = DeviceGeolocationMock.install();
  });

  tearDown(() async {
    await mock.reset();
  });

  test('install registers the mock as the active platform', () {
    expect(DeviceGeolocationPlatform.instance, same(mock));
  });

  test('checkPermission returns the configured value', () async {
    mock.permission = DeviceLocationPermission.always;
    expect(
      await DeviceGeolocation.checkPermission(),
      DeviceLocationPermission.always,
    );
  });

  test('requestPermission records the background flag', () async {
    await DeviceGeolocation.requestPermission(requestBackground: true);
    expect(mock.lastRequestedBackground, isTrue);
  });

  test('isLocationServiceEnabled returns configured value', () async {
    mock.serviceEnabled = false;
    expect(await DeviceGeolocation.isLocationServiceEnabled(), isFalse);
  });

  test('getCurrentPosition returns configured position', () async {
    mock.setPosition(mock.makePosition(latitude: 10, longitude: 20));
    final p = await DeviceGeolocation.getCurrentPosition(
      deviceLocationSettings: const DeviceLocationSettings(
        accuracy: DeviceLocationAccuracy.low,
      ),
    );
    expect(p.latitude, 10);
    expect(p.longitude, 20);
    expect(
      mock.lastDeviceLocationSettings?.accuracy,
      DeviceLocationAccuracy.low,
    );
  });

  test('getCurrentPosition throws StateError when position is unset', () {
    expect(() => DeviceGeolocation.getCurrentPosition(), throwsStateError);
  });

  test('getPositionStream emits values via emitPosition', () async {
    final stream = DeviceGeolocation.getPositionStream();
    final received = <DevicePosition>[];
    final sub = stream.listen(received.add);
    final p = mock.makePosition(latitude: 5, longitude: 6);
    mock.emitPosition(p);
    await Future<void>.delayed(Duration.zero);
    expect(received, [p]);
    await sub.cancel();
  });

  test('getPermissionStream emits values via emitPermission', () async {
    final stream = DeviceGeolocation.getPermissionStream();
    final received = <DeviceLocationPermission>[];
    final sub = stream.listen(received.add);
    mock.emitPermission(DeviceLocationPermission.always);
    await Future<void>.delayed(Duration.zero);
    expect(received, [DeviceLocationPermission.always]);
    await sub.cancel();
  });

  test('getServiceStatusStream emits values via emitServiceStatus', () async {
    final stream = DeviceGeolocation.getServiceStatusStream();
    final received = <DeviceLocationServiceStatus>[];
    final sub = stream.listen(received.add);
    mock.emitServiceStatus(DeviceLocationServiceStatus.disabled);
    await Future<void>.delayed(Duration.zero);
    expect(received, [DeviceLocationServiceStatus.disabled]);
    await sub.cancel();
  });

  test('throwOnNext makes the next call throw and then resets', () async {
    mock.throwOnNext(PermissionDeniedException('test'));
    await expectLater(
      DeviceGeolocation.checkPermission(),
      throwsA(isA<PermissionDeniedException>()),
    );
    expect(
      await DeviceGeolocation.checkPermission(),
      DeviceLocationPermission.whileInUse,
    );
  });

  test('requestTemporaryFullAccuracy records purposeKey', () async {
    mock.temporaryAccuracyResult = DeviceLocationAccuracyStatus.reduced;
    final r = await DeviceGeolocation.requestTemporaryFullAccuracy(
      purposeKey: 'PreciseLocation',
    );
    expect(r, DeviceLocationAccuracyStatus.reduced);
    expect(mock.lastPurposeKey, 'PreciseLocation');
  });

  test('open*Settings return configured value', () async {
    mock.settingsOpened = false;
    expect(await DeviceGeolocation.openAppSettings(), isFalse);
    expect(await DeviceGeolocation.openLocationSettings(), isFalse);
  });

  test('reset clears configured state', () async {
    mock.permission = DeviceLocationPermission.deniedForever;
    mock.serviceEnabled = false;
    await mock.reset();
    expect(mock.permission, DeviceLocationPermission.whileInUse);
    expect(mock.serviceEnabled, isTrue);
  });

  test('lastForegroundNotificationConfig captures AndroidSettings', () async {
    const cfg = ForegroundNotificationConfig(
      notificationTitle: 'Tracking',
      notificationText: 'Sharing your location',
      enableWakeLock: true,
    );
    final stream = DeviceGeolocation.getPositionStream(
      deviceLocationSettings: const AndroidSettings(
        foregroundNotificationConfig: cfg,
      ),
    );
    final sub = stream.listen((_) {});
    await Future<void>.delayed(Duration.zero);
    expect(mock.lastForegroundNotificationConfig, equals(cfg));
    await sub.cancel();
  });

  test(
    'lastForegroundNotificationConfig is null without AndroidSettings',
    () async {
      final stream = DeviceGeolocation.getPositionStream(
        deviceLocationSettings: const DeviceLocationSettings(),
      );
      final sub = stream.listen((_) {});
      await Future<void>.delayed(Duration.zero);
      expect(mock.lastForegroundNotificationConfig, isNull);
      await sub.cancel();
    },
  );

  test('settingsOpenedStream emits true/false via lifecycle', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final received = <bool>[];
    final sub = DeviceGeolocation.settingsOpenedStream.listen(received.add);

    unawaited(
      DeviceGeolocation.openAppSettings(
        callback: (status, permission) {
          // callback expected
        },
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(received, [true]);

    // Simulate returning to the app.
    TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );
    await Future<void>.delayed(Duration.zero);
    expect(received, [true, false]);

    await sub.cancel();
  });
}
