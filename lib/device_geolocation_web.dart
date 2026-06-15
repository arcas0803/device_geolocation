// ignore: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:js_interop';

import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as web;

import 'device_geolocation_platform_interface.dart';
import 'src/enums/enums.dart';
import 'src/errors/geolocation_exceptions.dart';
import 'src/models/models.dart';
import 'src/settings_panel_lifecycle.dart';

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
  Future<DeviceLocationPermission> checkPermission() async {
    try {
      final permissions = web.window.navigator.permissions;
      final status = await permissions
          .query(_PermissionDescriptor(name: 'geolocation'))
          .toDart;
      return _permissionFromState(status.state);
    } catch (_) {
      return DeviceLocationPermission.unableToDetermine;
    }
  }

  @override
  Future<DeviceLocationPermission> requestPermission({
    bool requestBackground = false,
  }) async {
    try {
      await _getCurrentPositionRaw(enableHighAccuracy: false);
      return DeviceLocationPermission.whileInUse;
    } on PermissionDeniedException {
      return DeviceLocationPermission.deniedForever;
    } catch (_) {
      return DeviceLocationPermission.denied;
    }
  }

  @override
  Future<DevicePosition> getCurrentPosition({
    DeviceLocationSettings? deviceLocationSettings,
  }) async {
    final settings = deviceLocationSettings ?? const DeviceLocationSettings();
    final raw = await _getCurrentPositionRaw(
      enableHighAccuracy: _highAccuracy(settings.accuracy),
      timeout: settings.timeLimit,
      maximumAge: settings is WebSettings ? settings.maximumAge : null,
    );
    return _positionFromGeoposition(raw);
  }

  @override
  Stream<DevicePosition> getPositionStream({
    DeviceLocationSettings? deviceLocationSettings,
  }) {
    final controller = StreamController<DevicePosition>.broadcast();
    int? watchId;
    DevicePosition? previous;
    final settings = deviceLocationSettings ?? const DeviceLocationSettings();
    final distanceFilter = settings.distanceFilter;

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
      enableHighAccuracy: _highAccuracy(settings.accuracy),
      timeout: settings.timeLimit,
      maximumAge: settings is WebSettings ? settings.maximumAge : null,
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
  Stream<DeviceLocationPermission> getPermissionStream({
    Duration pollingInterval = const Duration(seconds: 1),
  }) {
    final controller = StreamController<DeviceLocationPermission>.broadcast();
    StreamSubscription<web.Event>? changeSub;
    Timer? timer;

    Future<void> emitCurrent() async {
      if (controller.isClosed) return;
      try {
        final permission = await checkPermission();
        if (!controller.isClosed) controller.add(permission);
      } on Exception catch (e) {
        if (!controller.isClosed) controller.addError(e);
      }
    }

    controller.onListen = () {
      emitCurrent();
      try {
        web.window.navigator.permissions
            .query(_PermissionDescriptor(name: 'geolocation'))
            .toDart
            .then((status) {
              if (controller.isClosed) return;
              void listener(web.Event event) => emitCurrent();
              status.addEventListener('change', listener.toJS);
              changeSub = _EventStreamSubscription(
                () => status.removeEventListener('change', listener.toJS),
              );
            });
      } catch (_) {
        // Permissions API not supported; polling covers it.
      }
      timer = Timer.periodic(pollingInterval, (_) => emitCurrent());
    };

    controller.onCancel = () async {
      await changeSub?.cancel();
      timer?.cancel();
    };

    return controller.stream;
  }

  @override
  Stream<DeviceLocationServiceStatus> getServiceStatusStream() async* {
    // Web does not expose a location-service toggle.
    yield DeviceLocationServiceStatus.enabled;
  }

  @override
  Future<DeviceLocationAccuracyStatus> getLocationAccuracy() async =>
      DeviceLocationAccuracyStatus.unknown;

  @override
  Future<DeviceLocationAccuracyStatus> requestTemporaryFullAccuracy({
    required String purposeKey,
  }) async => DeviceLocationAccuracyStatus.unknown;

  @override
  Future<bool> openAppSettings({DeviceGeolocationSettingsCallback? callback}) =>
      throw _unsupported('openAppSettings');

  @override
  Future<bool> openLocationSettings({
    DeviceGeolocationSettingsCallback? callback,
  }) => throw _unsupported('openLocationSettings');

  @override
  Stream<bool> get settingsOpenedStream =>
      SettingsPanelLifecycle.instance.stream;

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

  DevicePosition _positionFromGeoposition(web.GeolocationPosition pos) {
    final coords = pos.coords;
    return DevicePosition(
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

  DeviceLocationPermission _permissionFromState(String state) {
    switch (state) {
      case 'granted':
        return DeviceLocationPermission.whileInUse;
      case 'prompt':
        return DeviceLocationPermission.denied;
      case 'denied':
        return DeviceLocationPermission.deniedForever;
      default:
        return DeviceLocationPermission.unableToDetermine;
    }
  }

  bool _highAccuracy(DeviceLocationAccuracy? accuracy) {
    switch (accuracy) {
      case DeviceLocationAccuracy.high:
      case DeviceLocationAccuracy.best:
      case DeviceLocationAccuracy.bestForNavigation:
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

class _EventStreamSubscription implements StreamSubscription<web.Event> {
  _EventStreamSubscription(this._cancel);

  final void Function() _cancel;

  @override
  Future<void> cancel() async => _cancel();

  @override
  bool get isPaused => false;

  @override
  void onData(void Function(web.Event data)? handleData) {}

  @override
  void onError(Function? handleError) {}

  @override
  void onDone(void Function()? handleDone) {}

  @override
  void pause([Future<void>? resumeSignal]) {}

  @override
  void resume() {}

  @override
  Future<E> asFuture<E>([E? futureValue]) async => futureValue as E;
}
