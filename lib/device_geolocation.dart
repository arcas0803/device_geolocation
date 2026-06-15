import 'dart:async';

import 'device_geolocation_platform_interface.dart';
import 'src/enums/enums.dart';
import 'src/geospatial/geospatial_algorithm.dart';
import 'src/geospatial/geospatial_calculator.dart';
import 'src/geospatial/isolate_runner.dart'
    if (dart.library.js_interop) 'src/geospatial/isolate_runner_web.dart';
import 'src/models/models.dart';
import 'src/settings_panel_lifecycle.dart';

export 'device_geolocation_linux.dart'
    if (dart.library.js_interop) 'src/stubs/device_geolocation_linux_stub.dart';
export 'src/enums/enums.dart';
export 'src/errors/geolocation_exceptions.dart';
export 'src/geospatial/geospatial_algorithm.dart';
export 'src/models/models.dart';

/// Public, app-facing API of the `device_geolocation` plugin.
///
/// All methods are static and delegate to the registered
/// [DeviceGeolocationPlatform] implementation.
class DeviceGeolocation {
  DeviceGeolocation._();

  static DeviceLocationSettings? _configuredSettings;

  /// Configures default settings used by all subsequent location requests
  /// unless overridden explicitly.
  ///
  /// ```dart
  /// DeviceGeolocation.configure(
  ///   const DeviceLocationSettings(
  ///     accuracy: DeviceLocationAccuracy.high,
  ///     distanceFilter: 10,
  ///   ),
  /// );
  /// ```
  static void configure(DeviceLocationSettings settings) {
    _configuredSettings = settings;
  }

  static DeviceLocationSettings _resolveSettings(
    DeviceLocationSettings? override,
  ) => override ?? _configuredSettings ?? const DeviceLocationSettings();

  /// Returns the current permission status for accessing the device's
  /// location.
  static Future<DeviceLocationPermission> checkPermission() =>
      DeviceGeolocationPlatform.instance.checkPermission();

  /// Asks the user for permission to access the device's location.
  ///
  /// On Android 10+, set [requestBackground] to `true` to also request the
  /// `ACCESS_BACKGROUND_LOCATION` permission after the foreground permission
  /// has been granted. On other platforms the flag is ignored.
  static Future<DeviceLocationPermission> requestPermission({
    bool requestBackground = false,
  }) => DeviceGeolocationPlatform.instance.requestPermission(
    requestBackground: requestBackground,
  );

  /// Returns whether the device's location services are enabled.
  static Future<bool> isLocationServiceEnabled() =>
      DeviceGeolocationPlatform.instance.isLocationServiceEnabled();

  /// Requests a fresh position from the device.
  ///
  /// If [deviceLocationSettings] is omitted, the settings configured with
  /// [configure] are used. If [configure] was never called, the defaults from
  /// [DeviceLocationSettings] are used.
  static Future<DevicePosition> getCurrentPosition({
    DeviceLocationSettings? deviceLocationSettings,
  }) => DeviceGeolocationPlatform.instance.getCurrentPosition(
    deviceLocationSettings: _resolveSettings(deviceLocationSettings),
  );

  /// Stream of positions emitted as the device moves.
  ///
  /// If [deviceLocationSettings] is omitted, the settings configured with
  /// [configure] are used. If [configure] was never called, the defaults from
  /// [DeviceLocationSettings] are used.
  static Stream<DevicePosition> getPositionStream({
    DeviceLocationSettings? deviceLocationSettings,
  }) => DeviceGeolocationPlatform.instance.getPositionStream(
    deviceLocationSettings: _resolveSettings(deviceLocationSettings),
  );

  /// Stream of permission status changes.
  ///
  /// On platforms that support native permission observers (e.g. web), the
  /// stream emits when the browser reports a change. On other platforms it
  /// polls [checkPermission] every [pollingInterval].
  static Stream<DeviceLocationPermission> getPermissionStream({
    Duration pollingInterval = const Duration(seconds: 1),
  }) => DeviceGeolocationPlatform.instance.getPermissionStream(
    pollingInterval: pollingInterval,
  );

  /// Stream emitting whenever the device location service is enabled or
  /// disabled.
  static Stream<DeviceLocationServiceStatus> getServiceStatusStream() =>
      DeviceGeolocationPlatform.instance.getServiceStatusStream();

  /// Returns the granted location accuracy (precise vs. reduced).
  static Future<DeviceLocationAccuracyStatus> getLocationAccuracy() =>
      DeviceGeolocationPlatform.instance.getLocationAccuracy();

  /// Requests temporary precise accuracy access (iOS 14+).
  static Future<DeviceLocationAccuracyStatus> requestTemporaryFullAccuracy({
    required String purposeKey,
  }) => DeviceGeolocationPlatform.instance.requestTemporaryFullAccuracy(
    purposeKey: purposeKey,
  );

  /// Opens the OS-level app settings screen for this application.
  ///
  /// If [callback] is provided, it is invoked when the user returns to the
  /// app with the current service status and permission.
  static Future<bool> openAppSettings({
    DeviceGeolocationSettingsCallback? callback,
  }) async {
    final opened = await DeviceGeolocationPlatform.instance.openAppSettings(
      callback: callback,
    );
    if (opened) {
      SettingsPanelLifecycle.instance.notifySettingsOpened(callback: callback);
    }
    return opened;
  }

  /// Opens the OS-level location settings screen.
  ///
  /// If [callback] is provided, it is invoked when the user returns to the
  /// app with the current service status and permission.
  static Future<bool> openLocationSettings({
    DeviceGeolocationSettingsCallback? callback,
  }) async {
    final opened = await DeviceGeolocationPlatform.instance
        .openLocationSettings(callback: callback);
    if (opened) {
      SettingsPanelLifecycle.instance.notifySettingsOpened(callback: callback);
    }
    return opened;
  }

  /// Stream that emits `true` when a settings panel is opened by this plugin
  /// and `false` when the app returns to the foreground.
  static Stream<bool> get settingsOpenedStream =>
      SettingsPanelLifecycle.instance.stream;

  /// Great-circle distance between two coordinates in meters.
  ///
  /// [algorithm] selects the geodetic formula. [GeospatialAlgorithm.vincenty]
  /// (default) is more accurate; [GeospatialAlgorithm.haversine] is faster.
  static double distanceBetween(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude, {
    GeospatialAlgorithm algorithm = GeospatialAlgorithm.vincenty,
  }) => DeviceGeolocationPlatform.instance.distanceBetween(
    startLatitude,
    startLongitude,
    endLatitude,
    endLongitude,
    algorithm: algorithm,
  );

  /// Asynchronously calculates the great-circle distance between two
  /// coordinates in meters.
  ///
  /// On native platforms the calculation runs in a separate isolate. On the
  /// web, where isolates are unavailable, this falls back to the synchronous
  /// calculation on the main thread.
  static Future<double> distanceBetweenIsolate(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude, {
    GeospatialAlgorithm algorithm = GeospatialAlgorithm.vincenty,
  }) => runInIsolate(
    () => distanceBetweenWorker(
      DistanceIsolateMessage(
        startLatitude,
        startLongitude,
        endLatitude,
        endLongitude,
        algorithm,
      ),
    ),
  );

  /// Initial bearing from one coordinate to another in degrees.
  ///
  /// The result is in the range `(-180, 180]`.
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

  /// Asynchronously calculates the initial bearing from one coordinate to
  /// another in degrees.
  ///
  /// On native platforms the calculation runs in a separate isolate. On the
  /// web, where isolates are unavailable, this falls back to the synchronous
  /// calculation on the main thread.
  static Future<double> bearingBetweenIsolate(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) => runInIsolate(
    () => bearingBetweenWorker(
      BearingIsolateMessage(
        startLatitude,
        startLongitude,
        endLatitude,
        endLongitude,
      ),
    ),
  );
}
