import 'dart:async';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'device_geolocation_method_channel.dart';
import 'src/enums/enums.dart';
import 'src/geospatial/geospatial_algorithm.dart';
import 'src/geospatial/geospatial_calculator.dart';
import 'src/models/models.dart';

/// Signature for callbacks invoked when the user returns from the system
/// settings screen.
typedef DeviceGeolocationSettingsCallback =
    void Function(
      DeviceLocationServiceStatus serviceStatus,
      DeviceLocationPermission permission,
    );

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

  Future<DeviceLocationPermission> checkPermission() {
    throw UnimplementedError('checkPermission() has not been implemented.');
  }

  Future<DeviceLocationPermission> requestPermission({
    bool requestBackground = false,
  }) {
    throw UnimplementedError('requestPermission() has not been implemented.');
  }

  Future<bool> isLocationServiceEnabled() {
    throw UnimplementedError(
      'isLocationServiceEnabled() has not been implemented.',
    );
  }

  Future<DevicePosition> getCurrentPosition({
    DeviceLocationSettings? deviceLocationSettings,
  }) {
    throw UnimplementedError('getCurrentPosition() has not been implemented.');
  }

  Stream<DevicePosition> getPositionStream({
    DeviceLocationSettings? deviceLocationSettings,
  }) {
    throw UnimplementedError('getPositionStream() has not been implemented.');
  }

  Stream<DeviceLocationPermission> getPermissionStream({
    Duration pollingInterval = const Duration(seconds: 1),
  }) {
    throw UnimplementedError('getPermissionStream() has not been implemented.');
  }

  Stream<DeviceLocationServiceStatus> getServiceStatusStream() {
    throw UnimplementedError(
      'getServiceStatusStream() has not been implemented.',
    );
  }

  Future<DeviceLocationAccuracyStatus> getLocationAccuracy() {
    throw UnimplementedError('getLocationAccuracy() has not been implemented.');
  }

  Future<DeviceLocationAccuracyStatus> requestTemporaryFullAccuracy({
    required String purposeKey,
  }) {
    throw UnimplementedError(
      'requestTemporaryFullAccuracy() has not been implemented.',
    );
  }

  Future<bool> openAppSettings({DeviceGeolocationSettingsCallback? callback}) {
    throw UnimplementedError('openAppSettings() has not been implemented.');
  }

  Future<bool> openLocationSettings({
    DeviceGeolocationSettingsCallback? callback,
  }) {
    throw UnimplementedError(
      'openLocationSettings() has not been implemented.',
    );
  }

  /// Stream that emits `true` when a system settings panel is opened by this
  /// plugin and `false` when the app returns to the foreground.
  Stream<bool> get settingsOpenedStream {
    throw UnimplementedError('settingsOpenedStream has not been implemented.');
  }

  /// Great-circle distance between two coordinates in meters.
  ///
  /// [algorithm] selects the geodetic formula. [GeospatialAlgorithm.vincenty]
  /// (default) is more accurate; [GeospatialAlgorithm.haversine] is faster.
  double distanceBetween(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude, {
    GeospatialAlgorithm algorithm = GeospatialAlgorithm.vincenty,
  }) => calculateDistance(
    startLatitude,
    startLongitude,
    endLatitude,
    endLongitude,
    algorithm: algorithm,
  );

  /// Initial bearing (forward azimuth) from start to end coordinates,
  /// expressed in degrees.
  double bearingBetween(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) => calculateBearing(
    startLatitude,
    startLongitude,
    endLatitude,
    endLongitude,
  );
}
