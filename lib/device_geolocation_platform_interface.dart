import 'dart:async';
import 'dart:math' as math;

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'device_geolocation_method_channel.dart';
import 'src/enums/enums.dart';
import 'src/models/models.dart';

/// Interface that all platform implementations of `device_geolocation` must
/// implement.
///
/// Platform implementations should `extend` this class — not `implement` it —
/// so that future additions do not break them.
abstract class DeviceGeolocationPlatform extends PlatformInterface {
  DeviceGeolocationPlatform() : super(token: _token);

  static final Object _token = Object();

  static DeviceGeolocationPlatform _instance = MethodChannelDeviceGeolocation();

  /// Currently registered platform implementation.
  static DeviceGeolocationPlatform get instance => _instance;

  static set instance(DeviceGeolocationPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<LocationPermission> checkPermission() {
    throw UnimplementedError('checkPermission() has not been implemented.');
  }

  Future<LocationPermission> requestPermission({
    bool requestBackground = false,
  }) {
    throw UnimplementedError('requestPermission() has not been implemented.');
  }

  Future<bool> isLocationServiceEnabled() {
    throw UnimplementedError(
      'isLocationServiceEnabled() has not been implemented.',
    );
  }

  Future<Position?> getLastKnownPosition({bool forceLocationManager = false}) {
    throw UnimplementedError(
      'getLastKnownPosition() has not been implemented.',
    );
  }

  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) {
    throw UnimplementedError('getCurrentPosition() has not been implemented.');
  }

  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    throw UnimplementedError('getPositionStream() has not been implemented.');
  }

  Stream<ServiceStatus> getServiceStatusStream() {
    throw UnimplementedError(
      'getServiceStatusStream() has not been implemented.',
    );
  }

  Future<LocationAccuracyStatus> getLocationAccuracy() {
    throw UnimplementedError('getLocationAccuracy() has not been implemented.');
  }

  Future<LocationAccuracyStatus> requestTemporaryFullAccuracy({
    required String purposeKey,
  }) {
    throw UnimplementedError(
      'requestTemporaryFullAccuracy() has not been implemented.',
    );
  }

  Future<bool> openAppSettings() {
    throw UnimplementedError('openAppSettings() has not been implemented.');
  }

  Future<bool> openLocationSettings() {
    throw UnimplementedError(
      'openLocationSettings() has not been implemented.',
    );
  }

  /// Great-circle distance between two coordinates in meters (Haversine).
  double distanceBetween(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    const earthRadius = 6378137.0;
    final dLat = _radians(endLatitude - startLatitude);
    final dLon = _radians(endLongitude - startLongitude);
    final a =
        math.pow(math.sin(dLat / 2), 2) +
        math.pow(math.sin(dLon / 2), 2) *
            math.cos(_radians(startLatitude)) *
            math.cos(_radians(endLatitude));
    return earthRadius * 2 * math.asin(math.sqrt(a));
  }

  /// Initial bearing (forward azimuth) from start to end coordinates,
  /// expressed in degrees.
  double bearingBetween(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    final startLat = _radians(startLatitude);
    final startLon = _radians(startLongitude);
    final endLat = _radians(endLatitude);
    final endLon = _radians(endLongitude);

    final y = math.sin(endLon - startLon) * math.cos(endLat);
    final x =
        math.cos(startLat) * math.sin(endLat) -
        math.sin(startLat) * math.cos(endLat) * math.cos(endLon - startLon);
    return _degrees(math.atan2(y, x));
  }

  static double _radians(double degrees) => degrees * math.pi / 180.0;
  static double _degrees(double radians) => radians * 180.0 / math.pi;
}
