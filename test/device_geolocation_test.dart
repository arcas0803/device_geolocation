import 'package:device_geolocation/device_geolocation.dart';
import 'package:device_geolocation/device_geolocation_method_channel.dart';
import 'package:device_geolocation/device_geolocation_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockDeviceGeolocationPlatform
    with MockPlatformInterfaceMixin
    implements DeviceGeolocationPlatform {
  @override
  Future<DeviceLocationPermission> checkPermission() async =>
      DeviceLocationPermission.whileInUse;

  @override
  Future<DeviceLocationPermission> requestPermission({
    bool requestBackground = false,
  }) async => DeviceLocationPermission.whileInUse;

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  DeviceLocationSettings? lastDeviceLocationSettings;

  @override
  Future<DevicePosition> getCurrentPosition({
    DeviceLocationSettings? deviceLocationSettings,
  }) async {
    lastDeviceLocationSettings = deviceLocationSettings;
    return _samplePosition();
  }

  @override
  Stream<DevicePosition> getPositionStream({
    DeviceLocationSettings? deviceLocationSettings,
  }) {
    lastDeviceLocationSettings = deviceLocationSettings;
    return Stream<DevicePosition>.value(_samplePosition());
  }

  @override
  Stream<DeviceLocationPermission> getPermissionStream({
    Duration pollingInterval = const Duration(seconds: 1),
  }) => Stream<DeviceLocationPermission>.value(DeviceLocationPermission.whileInUse);

  @override
  Stream<DeviceLocationServiceStatus> getServiceStatusStream() =>
      Stream<DeviceLocationServiceStatus>.value(
        DeviceLocationServiceStatus.enabled,
      );

  @override
  Future<DeviceLocationAccuracyStatus> getLocationAccuracy() async =>
      DeviceLocationAccuracyStatus.precise;

  @override
  Future<DeviceLocationAccuracyStatus> requestTemporaryFullAccuracy({
    required String purposeKey,
  }) async => DeviceLocationAccuracyStatus.precise;

  @override
  Future<bool> openAppSettings({
    DeviceGeolocationSettingsCallback? callback,
  }) async => true;

  @override
  Future<bool> openLocationSettings({
    DeviceGeolocationSettingsCallback? callback,
  }) async => true;

  @override
  Stream<bool> get settingsOpenedStream => Stream<bool>.empty();

  @override
  double distanceBetween(
    double startLat,
    double startLon,
    double endLat,
    double endLon, {
    GeospatialAlgorithm algorithm = GeospatialAlgorithm.vincenty,
  }) => 0;

  @override
  double bearingBetween(
    double startLat,
    double startLon,
    double endLat,
    double endLon,
  ) => 0;

  DevicePosition _samplePosition() => DevicePosition(
    latitude: 1.0,
    longitude: 2.0,
    timestamp: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    accuracy: 1,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}

void main() {
  final initialPlatform = DeviceGeolocationPlatform.instance;

  test('MethodChannelDeviceGeolocation is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelDeviceGeolocation>());
  });

  test('checkPermission delegates to platform', () async {
    DeviceGeolocationPlatform.instance = MockDeviceGeolocationPlatform();
    expect(
      await DeviceGeolocation.checkPermission(),
      DeviceLocationPermission.whileInUse,
    );
  });

  test('getCurrentPosition delegates to platform', () async {
    DeviceGeolocationPlatform.instance = MockDeviceGeolocationPlatform();
    final position = await DeviceGeolocation.getCurrentPosition();
    expect(position.latitude, 1.0);
    expect(position.longitude, 2.0);
  });

  group('configure', () {
    tearDown(() => DeviceGeolocation.configure(const DeviceLocationSettings()));

    test('uses configured settings when override is null', () async {
      DeviceGeolocationPlatform.instance = MockDeviceGeolocationPlatform();
      DeviceGeolocation.configure(
        const DeviceLocationSettings(
          accuracy: DeviceLocationAccuracy.high,
          distanceFilter: 42,
        ),
      );
      await DeviceGeolocation.getCurrentPosition();
      final platform = DeviceGeolocationPlatform.instance
          as MockDeviceGeolocationPlatform;
      expect(
        platform.lastDeviceLocationSettings?.accuracy,
        DeviceLocationAccuracy.high,
      );
      expect(platform.lastDeviceLocationSettings?.distanceFilter, 42);
    });

    test('uses explicit settings over configured settings', () async {
      DeviceGeolocationPlatform.instance = MockDeviceGeolocationPlatform();
      DeviceGeolocation.configure(
        const DeviceLocationSettings(
          accuracy: DeviceLocationAccuracy.high,
        ),
      );
      await DeviceGeolocation.getCurrentPosition(
        deviceLocationSettings: const DeviceLocationSettings(
          accuracy: DeviceLocationAccuracy.low,
        ),
      );
      final platform = DeviceGeolocationPlatform.instance
          as MockDeviceGeolocationPlatform;
      expect(
        platform.lastDeviceLocationSettings?.accuracy,
        DeviceLocationAccuracy.low,
      );
    });
  });
}
