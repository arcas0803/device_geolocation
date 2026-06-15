import 'dart:async';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../../device_geolocation_platform_interface.dart';
import '../enums/enums.dart';
import '../models/models.dart';
import '../settings_panel_lifecycle.dart';

/// In-memory fake of [DeviceGeolocationPlatform] for use in tests.
///
/// Apps depending on `device_geolocation` can import this class from
/// `package:device_geolocation/testing.dart` and install it as the active
/// platform implementation, removing the need to set up mock method
/// channels manually.
///
/// ```dart
/// import 'package:device_geolocation/device_geolocation.dart';
/// import 'package:device_geolocation/testing.dart';
///
/// void main() {
///   late DeviceGeolocationMock mock;
///
///   setUp(() {
///     mock = DeviceGeolocationMock.install();
///   });
///
///   tearDown(() => mock.reset());
///
///   test('returns the position configured by the test', () async {
///     mock.position = mock.makePosition(latitude: 41.0, longitude: 2.0);
///     final p = await DeviceGeolocation.getCurrentPosition();
///     expect(p.latitude, 41.0);
///   });
/// }
/// ```
class DeviceGeolocationMock extends DeviceGeolocationPlatform
    with MockPlatformInterfaceMixin {
  DeviceGeolocationMock();

  /// Installs a fresh [DeviceGeolocationMock] as the active platform
  /// implementation and returns it.
  static DeviceGeolocationMock install() {
    final mock = DeviceGeolocationMock();
    DeviceGeolocationPlatform.instance = mock;
    return mock;
  }

  /// Current permission state returned by [checkPermission] /
  /// [requestPermission] and emitted by [getPermissionStream].
  DeviceLocationPermission permission = DeviceLocationPermission.whileInUse;

  /// Value returned by [isLocationServiceEnabled].
  bool serviceEnabled = true;

  /// Value returned by [getCurrentPosition].
  DevicePosition? position;

  /// Value returned by [getLocationAccuracy].
  DeviceLocationAccuracyStatus accuracy = DeviceLocationAccuracyStatus.precise;

  /// Value returned by [requestTemporaryFullAccuracy].
  DeviceLocationAccuracyStatus temporaryAccuracyResult =
      DeviceLocationAccuracyStatus.precise;

  /// Value returned by [openAppSettings] and [openLocationSettings].
  bool settingsOpened = true;

  /// Whether [requestPermission] received `requestBackground: true` the last
  /// time it was called. Useful for assertions.
  bool lastRequestedBackground = false;

  /// `DeviceLocationSettings` last passed to [getCurrentPosition] or
  /// [getPositionStream]. `null` if no call has been made yet.
  DeviceLocationSettings? lastDeviceLocationSettings;

  /// Convenience accessor for the [ForegroundNotificationConfig] carried by
  /// the most recent [AndroidSettings] passed to [getPositionStream]. Returns
  /// `null` when the last call did not use an `AndroidSettings` instance or
  /// the settings did not configure the foreground service.
  ForegroundNotificationConfig? get lastForegroundNotificationConfig {
    final settings = lastDeviceLocationSettings;
    return settings is AndroidSettings
        ? settings.foregroundNotificationConfig
        : null;
  }

  /// `purposeKey` last passed to [requestTemporaryFullAccuracy].
  String? lastPurposeKey;

  /// Exception thrown by the next platform call, then cleared.
  Object? _pendingError;

  StreamController<DevicePosition>? _positionController;
  StreamController<DeviceLocationServiceStatus>? _serviceController;
  StreamController<DeviceLocationPermission>? _permissionController;

  /// Convenience constructor for a [DevicePosition] with sensible defaults.
  DevicePosition makePosition({
    double latitude = 0,
    double longitude = 0,
    DateTime? timestamp,
    double accuracy = 0,
    double altitude = 0,
    double altitudeAccuracy = 0,
    double heading = 0,
    double headingAccuracy = 0,
    double speed = 0,
    double speedAccuracy = 0,
    int? floor,
    bool isMocked = true,
  }) => DevicePosition(
    latitude: latitude,
    longitude: longitude,
    timestamp: timestamp ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    accuracy: accuracy,
    altitude: altitude,
    altitudeAccuracy: altitudeAccuracy,
    heading: heading,
    headingAccuracy: headingAccuracy,
    speed: speed,
    speedAccuracy: speedAccuracy,
    floor: floor,
    isMocked: isMocked,
  );

  /// Sets [position] to [value].
  void setPosition(DevicePosition value) {
    position = value;
  }

  /// Pushes [value] to active [getPositionStream] listeners.
  void emitPosition(DevicePosition value) {
    _positionController?.add(value);
  }

  /// Pushes [value] to active [getServiceStatusStream] listeners.
  void emitServiceStatus(DeviceLocationServiceStatus value) {
    _serviceController?.add(value);
  }

  /// Pushes [value] to active [getPermissionStream] listeners.
  void emitPermission(DeviceLocationPermission value) {
    _permissionController?.add(value);
  }

  /// Causes the next platform call to throw [error].
  void throwOnNext(Object error) {
    _pendingError = error;
  }

  /// Resets all configured state and closes active stream controllers.
  Future<void> reset() async {
    permission = DeviceLocationPermission.whileInUse;
    serviceEnabled = true;
    position = null;
    accuracy = DeviceLocationAccuracyStatus.precise;
    temporaryAccuracyResult = DeviceLocationAccuracyStatus.precise;
    settingsOpened = true;
    lastRequestedBackground = false;
    lastDeviceLocationSettings = null;
    lastPurposeKey = null;
    _pendingError = null;
    await _positionController?.close();
    _positionController = null;
    await _serviceController?.close();
    _serviceController = null;
    await _permissionController?.close();
    _permissionController = null;
  }

  T _maybeThrow<T>(T value) {
    final err = _pendingError;
    if (err != null) {
      _pendingError = null;
      throw err;
    }
    return value;
  }

  @override
  Future<DeviceLocationPermission> checkPermission() async =>
      _maybeThrow(permission);

  @override
  Future<DeviceLocationPermission> requestPermission({
    bool requestBackground = false,
  }) async {
    lastRequestedBackground = requestBackground;
    return _maybeThrow(permission);
  }

  @override
  Future<bool> isLocationServiceEnabled() async => _maybeThrow(serviceEnabled);

  @override
  Future<DevicePosition> getCurrentPosition({
    DeviceLocationSettings? deviceLocationSettings,
  }) async {
    lastDeviceLocationSettings = deviceLocationSettings;
    final p = position;
    if (p == null && _pendingError == null) {
      throw StateError(
        'DeviceGeolocationMock.position has not been set. '
        'Configure it before calling getCurrentPosition().',
      );
    }
    return _maybeThrow(p as DevicePosition);
  }

  @override
  Stream<DevicePosition> getPositionStream({
    DeviceLocationSettings? deviceLocationSettings,
  }) {
    lastDeviceLocationSettings = deviceLocationSettings;
    final controller = _positionController ??=
        StreamController<DevicePosition>.broadcast();
    return controller.stream;
  }

  @override
  Stream<DeviceLocationPermission> getPermissionStream({
    Duration pollingInterval = const Duration(seconds: 1),
  }) {
    final controller = _permissionController ??=
        StreamController<DeviceLocationPermission>.broadcast();
    return controller.stream;
  }

  @override
  Stream<DeviceLocationServiceStatus> getServiceStatusStream() {
    final controller = _serviceController ??=
        StreamController<DeviceLocationServiceStatus>.broadcast();
    return controller.stream;
  }

  @override
  Future<DeviceLocationAccuracyStatus> getLocationAccuracy() async =>
      _maybeThrow(accuracy);

  @override
  Future<DeviceLocationAccuracyStatus> requestTemporaryFullAccuracy({
    required String purposeKey,
  }) async {
    lastPurposeKey = purposeKey;
    return _maybeThrow(temporaryAccuracyResult);
  }

  @override
  Future<bool> openAppSettings({
    DeviceGeolocationSettingsCallback? callback,
  }) async => _maybeThrow(settingsOpened);

  @override
  Future<bool> openLocationSettings({
    DeviceGeolocationSettingsCallback? callback,
  }) async => _maybeThrow(settingsOpened);

  @override
  Stream<bool> get settingsOpenedStream =>
      SettingsPanelLifecycle.instance.stream;
}
