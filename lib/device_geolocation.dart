import 'dart:async';

import 'device_geolocation_platform_interface.dart';
import 'src/enums/enums.dart';
import 'src/models/models.dart';

export 'device_geolocation_linux.dart'
    if (dart.library.js_interop) 'src/stubs/device_geolocation_linux_stub.dart';
export 'src/enums/enums.dart';
export 'src/errors/geolocation_exceptions.dart';
export 'src/models/models.dart';

/// Public, app-facing API of the `device_geolocation` plugin.
///
/// All methods are static and delegate to the registered
/// [DeviceGeolocationPlatform] implementation.
class DeviceGeolocation {
  DeviceGeolocation._();

  /// Returns the current permission status for accessing the device's
  /// location.
  static Future<LocationPermission> checkPermission() =>
      DeviceGeolocationPlatform.instance.checkPermission();

  /// Asks the user for permission to access the device's location.
  ///
  /// On Android 10+, set [requestBackground] to `true` to also request the
  /// `ACCESS_BACKGROUND_LOCATION` permission after the foreground permission
  /// has been granted. On other platforms the flag is ignored.
  static Future<LocationPermission> requestPermission({
    bool requestBackground = false,
  }) => DeviceGeolocationPlatform.instance.requestPermission(
    requestBackground: requestBackground,
  );

  /// Returns whether the device's location services are enabled.
  static Future<bool> isLocationServiceEnabled() =>
      DeviceGeolocationPlatform.instance.isLocationServiceEnabled();

  /// Returns the last cached position, or `null` if none is available.
  static Future<Position?> getLastKnownPosition({
    bool forceAndroidLocationManager = false,
  }) => DeviceGeolocationPlatform.instance.getLastKnownPosition(
    forceLocationManager: forceAndroidLocationManager,
  );

  /// Requests a fresh position from the device.
  static Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) => DeviceGeolocationPlatform.instance.getCurrentPosition(
    locationSettings: locationSettings,
  );

  /// Stream of positions emitted as the device moves.
  static Stream<Position> getPositionStream({
    LocationSettings? locationSettings,
  }) => DeviceGeolocationPlatform.instance.getPositionStream(
    locationSettings: locationSettings,
  );

  /// Stream emitting whenever the device location service is enabled or
  /// disabled.
  static Stream<ServiceStatus> getServiceStatusStream() =>
      DeviceGeolocationPlatform.instance.getServiceStatusStream();

  /// Returns the granted location accuracy (precise vs. reduced).
  static Future<LocationAccuracyStatus> getLocationAccuracy() =>
      DeviceGeolocationPlatform.instance.getLocationAccuracy();

  /// Requests temporary precise accuracy access (iOS 14+).
  static Future<LocationAccuracyStatus> requestTemporaryFullAccuracy({
    required String purposeKey,
  }) => DeviceGeolocationPlatform.instance.requestTemporaryFullAccuracy(
    purposeKey: purposeKey,
  );

  /// Opens the OS-level app settings screen for this application.
  static Future<bool> openAppSettings() =>
      DeviceGeolocationPlatform.instance.openAppSettings();

  /// Opens the OS-level location settings screen.
  static Future<bool> openLocationSettings() =>
      DeviceGeolocationPlatform.instance.openLocationSettings();

  /// Great-circle distance between two coordinates in meters.
  static double distanceBetween(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) => DeviceGeolocationPlatform.instance.distanceBetween(
    startLatitude,
    startLongitude,
    endLatitude,
    endLongitude,
  );

  /// Initial bearing from one coordinate to another in degrees.
  static double bearingBetween(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) => DeviceGeolocationPlatform.instance.bearingBetween(
    startLatitude,
    startLongitude,
    endLatitude,
    endLongitude,
  );
}
