// ignore: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:js_interop';

import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as web;

import 'device_geolocation_platform_interface.dart';
import 'src/enums/enums.dart';
import 'src/errors/geolocation_exceptions.dart';
import 'src/models/models.dart';

/// Web implementation of [DeviceGeolocationPlatform] backed by
/// `navigator.geolocation` and the Permissions API when available.
class DeviceGeolocationWeb extends DeviceGeolocationPlatform {
  DeviceGeolocationWeb();

  static void registerWith(Registrar registrar) {
    DeviceGeolocationPlatform.instance = DeviceGeolocationWeb();
  }

  web.Geolocation get _geolocation => web.window.navigator.geolocation;

  bool get _isSecureContext => web.window.isSecureContext;

  void _ensureSecureContext() {
    if (!_isSecureContext) {
      throw PositionUpdateException(
        'Geolocation requires a secure context (HTTPS or localhost).',
      );
    }
  }

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async {
    try {
      final permissions = web.window.navigator.permissions;
      final status = await permissions
          .query(_PermissionDescriptor(name: 'geolocation'))
          .toDart;
      switch (status.state) {
        case 'granted':
          return LocationPermission.whileInUse;
        case 'prompt':
          return LocationPermission.denied;
        case 'denied':
          return LocationPermission.deniedForever;
        default:
          return LocationPermission.unableToDetermine;
      }
    } catch (_) {
      return LocationPermission.unableToDetermine;
    }
  }

  @override
  Future<LocationPermission> requestPermission({
    bool requestBackground = false,
  }) async {
    try {
      await _getCurrentPositionRaw(enableHighAccuracy: false);
      return LocationPermission.whileInUse;
    } on PermissionDeniedException {
      return LocationPermission.deniedForever;
    } catch (_) {
      return LocationPermission.denied;
    }
  }

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    final raw = await _getCurrentPositionRaw(
      enableHighAccuracy: _highAccuracy(locationSettings?.accuracy),
      timeout: locationSettings?.timeLimit,
      maximumAge: locationSettings is WebSettings
          ? locationSettings.maximumAge
          : null,
    );
    return _positionFromGeoposition(raw);
  }

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    final controller = StreamController<Position>.broadcast();
    int? watchId;
    Position? previous;
    final distanceFilter = locationSettings?.distanceFilter ?? 0;

    void onSuccess(web.GeolocationPosition pos) {
      final next = _positionFromGeoposition(pos);
      if (distanceFilter > 0 && previous != null) {
        final d = distanceBetween(
          previous!.latitude,
          previous!.longitude,
          next.latitude,
          next.longitude,
        );
        if (d < distanceFilter) return;
      }
      previous = next;
      controller.add(next);
    }

    void onError(web.GeolocationPositionError err) {
      controller.addError(_mapError(err));
    }

    final options = _buildOptions(
      enableHighAccuracy: _highAccuracy(locationSettings?.accuracy),
      timeout: locationSettings?.timeLimit,
      maximumAge: locationSettings is WebSettings
          ? locationSettings.maximumAge
          : null,
    );

    controller.onListen = () {
      watchId = _geolocation.watchPosition(
        onSuccess.toJS,
        onError.toJS,
        options,
      );
    };
    controller.onCancel = () {
      if (watchId != null) {
        _geolocation.clearWatch(watchId!);
      }
    };
    return controller.stream;
  }

  @override
  Future<Position?> getLastKnownPosition({bool forceLocationManager = false}) =>
      throw _unsupported('getLastKnownPosition');

  @override
  Stream<ServiceStatus> getServiceStatusStream() =>
      throw _unsupported('getServiceStatusStream');

  @override
  Future<LocationAccuracyStatus> getLocationAccuracy() async =>
      LocationAccuracyStatus.unknown;

  @override
  Future<bool> openAppSettings() => throw _unsupported('openAppSettings');

  @override
  Future<bool> openLocationSettings() =>
      throw _unsupported('openLocationSettings');

  Future<web.GeolocationPosition> _getCurrentPositionRaw({
    bool enableHighAccuracy = false,
    Duration? timeout,
    Duration? maximumAge,
  }) {
    _ensureSecureContext();
    final completer = Completer<web.GeolocationPosition>();
    final options = _buildOptions(
      enableHighAccuracy: enableHighAccuracy,
      timeout: timeout,
      maximumAge: maximumAge,
    );
    _geolocation.getCurrentPosition(
      (web.GeolocationPosition p) {
        if (!completer.isCompleted) completer.complete(p);
      }.toJS,
      (web.GeolocationPositionError e) {
        if (!completer.isCompleted) completer.completeError(_mapError(e));
      }.toJS,
      options,
    );
    return completer.future;
  }

  web.PositionOptions _buildOptions({
    required bool enableHighAccuracy,
    Duration? timeout,
    Duration? maximumAge,
  }) {
    return web.PositionOptions(
      enableHighAccuracy: enableHighAccuracy,
      timeout: timeout?.inMilliseconds ?? 0x7FFFFFFF,
      maximumAge: maximumAge?.inMilliseconds ?? 0,
    );
  }

  Position _positionFromGeoposition(web.GeolocationPosition pos) {
    final coords = pos.coords;
    return Position(
      latitude: coords.latitude,
      longitude: coords.longitude,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        pos.timestamp.toInt(),
        isUtc: true,
      ),
      accuracy: coords.accuracy,
      altitude: coords.altitude ?? 0.0,
      altitudeAccuracy: coords.altitudeAccuracy ?? 0.0,
      heading: coords.heading ?? 0.0,
      headingAccuracy: 0.0,
      speed: coords.speed ?? 0.0,
      speedAccuracy: 0.0,
    );
  }

  bool _highAccuracy(LocationAccuracy? accuracy) {
    switch (accuracy) {
      case LocationAccuracy.high:
      case LocationAccuracy.best:
      case LocationAccuracy.bestForNavigation:
        return true;
      default:
        return false;
    }
  }

  Exception _mapError(web.GeolocationPositionError error) {
    switch (error.code) {
      case 1:
        return PermissionDeniedException(error.message);
      case 2:
        return PositionUpdateException(error.message);
      case 3:
        return TimeoutException(error.message);
      default:
        return PositionUpdateException(error.message);
    }
  }

  UnsupportedError _unsupported(String method) =>
      UnsupportedError('$method is not supported on the web platform.');
}

@JS()
@anonymous
extension type _PermissionDescriptor._(JSObject _) implements JSObject {
  external factory _PermissionDescriptor({String name});
}
