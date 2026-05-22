import 'package:device_geolocation/device_geolocation.dart';
import 'package:device_geolocation/device_geolocation_method_channel.dart';
import 'package:device_geolocation/device_geolocation_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockDeviceGeolocationPlatform
    with MockPlatformInterfaceMixin
    implements DeviceGeolocationPlatform {
  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<LocationPermission> requestPermission({
    bool requestBackground = false,
  }) async => LocationPermission.whileInUse;

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<Position?> getLastKnownPosition({
    bool forceLocationManager = false,
  }) async => _samplePosition();

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async => _samplePosition();

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) =>
      Stream<Position>.value(_samplePosition());

  @override
  Stream<ServiceStatus> getServiceStatusStream() =>
      Stream<ServiceStatus>.value(ServiceStatus.enabled);

  @override
  Future<LocationAccuracyStatus> getLocationAccuracy() async =>
      LocationAccuracyStatus.precise;

  @override
  Future<LocationAccuracyStatus> requestTemporaryFullAccuracy({
    required String purposeKey,
  }) async => LocationAccuracyStatus.precise;

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;

  @override
  double distanceBetween(
    double startLat,
    double startLon,
    double endLat,
    double endLon,
  ) => 0;

  @override
  double bearingBetween(
    double startLat,
    double startLon,
    double endLat,
    double endLon,
  ) => 0;

  Position _samplePosition() => Position(
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
      LocationPermission.whileInUse,
    );
  });

  test('getCurrentPosition delegates to platform', () async {
    DeviceGeolocationPlatform.instance = MockDeviceGeolocationPlatform();
    final position = await DeviceGeolocation.getCurrentPosition();
    expect(position.latitude, 1.0);
    expect(position.longitude, 2.0);
  });
}
