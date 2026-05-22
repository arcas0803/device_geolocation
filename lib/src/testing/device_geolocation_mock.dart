import 'dart:async';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../../device_geolocation_platform_interface.dart';
import '../enums/enums.dart';
import '../models/models.dart';

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
  /// [requestPermission].
  LocationPermission permission = LocationPermission.whileInUse;

  /// Value returned by [isLocationServiceEnabled].
  bool serviceEnabled = true;

  /// Value returned by [getCurrentPosition].
  Position? position;

  /// Value returned by [getLastKnownPosition].
  Position? lastKnownPosition;

  /// Value returned by [getLocationAccuracy].
  LocationAccuracyStatus accuracy = LocationAccuracyStatus.precise;

  /// Value returned by [requestTemporaryFullAccuracy].
  LocationAccuracyStatus temporaryAccuracyResult =
      LocationAccuracyStatus.precise;

  /// Value returned by [openAppSettings] and [openLocationSettings].
  bool settingsOpened = true;

  /// Whether [requestPermission] received `requestBackground: true` the last
  /// time it was called. Useful for assertions.
  bool lastRequestedBackground = false;

  /// Whether [getLastKnownPosition] received `forceLocationManager: true`
  /// the last time it was called.
  bool lastForcedLocationManager = false;

  /// `LocationSettings` last passed to [getCurrentPosition] or
  /// [getPositionStream]. `null` if no call has been made yet.
  LocationSettings? lastLocationSettings;

  /// `purposeKey` last passed to [requestTemporaryFullAccuracy].
  String? lastPurposeKey;

  /// Exception thrown by the next platform call, then cleared.
  Object? _pendingError;

  StreamController<Position>? _positionController;
  StreamController<ServiceStatus>? _serviceController;

  /// Convenience constructor for a [Position] with sensible defaults.
  Position makePosition({
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
  }) => Position(
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

  /// Sets [position] (and [lastKnownPosition] when [alsoLastKnown] is `true`).
  void setPosition(Position value, {bool alsoLastKnown = true}) {
    position = value;
    if (alsoLastKnown) lastKnownPosition = value;
  }

  /// Pushes [value] to active [getPositionStream] listeners.
  void emitPosition(Position value) {
    _positionController?.add(value);
  }

  /// Pushes [value] to active [getServiceStatusStream] listeners.
  void emitServiceStatus(ServiceStatus value) {
    _serviceController?.add(value);
  }

  /// Causes the next platform call to throw [error].
  void throwOnNext(Object error) {
    _pendingError = error;
  }

  /// Resets all configured state and closes active stream controllers.
  Future<void> reset() async {
    permission = LocationPermission.whileInUse;
    serviceEnabled = true;
    position = null;
    lastKnownPosition = null;
    accuracy = LocationAccuracyStatus.precise;
    temporaryAccuracyResult = LocationAccuracyStatus.precise;
    settingsOpened = true;
    lastRequestedBackground = false;
    lastForcedLocationManager = false;
    lastLocationSettings = null;
    lastPurposeKey = null;
    _pendingError = null;
    await _positionController?.close();
    _positionController = null;
    await _serviceController?.close();
    _serviceController = null;
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
  Future<LocationPermission> checkPermission() async => _maybeThrow(permission);

  @override
  Future<LocationPermission> requestPermission({
    bool requestBackground = false,
  }) async {
    lastRequestedBackground = requestBackground;
    return _maybeThrow(permission);
  }

  @override
  Future<bool> isLocationServiceEnabled() async => _maybeThrow(serviceEnabled);

  @override
  Future<Position?> getLastKnownPosition({
    bool forceLocationManager = false,
  }) async {
    lastForcedLocationManager = forceLocationManager;
    return _maybeThrow(lastKnownPosition);
  }

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    lastLocationSettings = locationSettings;
    final p = position;
    if (p == null && _pendingError == null) {
      throw StateError(
        'DeviceGeolocationMock.position has not been set. '
        'Configure it before calling getCurrentPosition().',
      );
    }
    return _maybeThrow(p as Position);
  }

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    lastLocationSettings = locationSettings;
    final controller = _positionController ??=
        StreamController<Position>.broadcast();
    return controller.stream;
  }

  @override
  Stream<ServiceStatus> getServiceStatusStream() {
    final controller = _serviceController ??=
        StreamController<ServiceStatus>.broadcast();
    return controller.stream;
  }

  @override
  Future<LocationAccuracyStatus> getLocationAccuracy() async =>
      _maybeThrow(accuracy);

  @override
  Future<LocationAccuracyStatus> requestTemporaryFullAccuracy({
    required String purposeKey,
  }) async {
    lastPurposeKey = purposeKey;
    return _maybeThrow(temporaryAccuracyResult);
  }

  @override
  Future<bool> openAppSettings() async => _maybeThrow(settingsOpened);

  @override
  Future<bool> openLocationSettings() async => _maybeThrow(settingsOpened);
}
