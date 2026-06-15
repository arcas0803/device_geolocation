import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'device_geolocation_platform_interface.dart';
import 'src/enums/enums.dart';
import 'src/errors/geolocation_exceptions.dart';
import 'src/models/models.dart';
import 'src/settings_panel_lifecycle.dart';

/// Implementation of [DeviceGeolocationPlatform] that uses method/event
/// channels to talk to the native side.
class MethodChannelDeviceGeolocation extends DeviceGeolocationPlatform {
  @visibleForTesting
  final MethodChannel methodChannel = const MethodChannel('device_geolocation');

  @visibleForTesting
  final EventChannel locationUpdatesChannel = const EventChannel(
    'device_geolocation/locationUpdates',
  );

  @visibleForTesting
  final EventChannel serviceUpdatesChannel = const EventChannel(
    'device_geolocation/serviceUpdates',
  );

  @visibleForTesting
  final EventChannel permissionUpdatesChannel = const EventChannel(
    'device_geolocation/permissionUpdates',
  );

  @override
  Future<DeviceLocationPermission> checkPermission() async {
    try {
      final index = await methodChannel.invokeMethod<int>('checkPermission');
      return DeviceLocationPermission.values[index ?? 0];
    } on PlatformException catch (e) {
      throw _mapException(e);
    }
  }

  @override
  Future<DeviceLocationPermission> requestPermission({
    bool requestBackground = false,
  }) async {
    try {
      final index = await methodChannel.invokeMethod<int>('requestPermission', {
        'requestBackground': requestBackground,
      });
      return DeviceLocationPermission.values[index ?? 0];
    } on PlatformException catch (e) {
      throw _mapException(e);
    }
  }

  @override
  Future<bool> isLocationServiceEnabled() async {
    final enabled = await methodChannel.invokeMethod<bool>(
      'isLocationServiceEnabled',
    );
    return enabled ?? false;
  }

  @override
  Future<DevicePosition> getCurrentPosition({
    DeviceLocationSettings? deviceLocationSettings,
  }) async {
    final settings = deviceLocationSettings ?? const DeviceLocationSettings();
    try {
      final result = await methodChannel.invokeMapMethod<String, dynamic>(
        'getCurrentPosition',
        settings.toJson(),
      );
      if (result == null) {
        throw PositionUpdateException('Platform returned no position');
      }
      return DevicePosition.fromMap(result);
    } on PlatformException catch (e) {
      throw _mapException(e);
    }
  }

  @override
  Stream<DevicePosition> getPositionStream({
    DeviceLocationSettings? deviceLocationSettings,
  }) {
    final args = (deviceLocationSettings ?? const DeviceLocationSettings())
        .toJson();
    return locationUpdatesChannel
        .receiveBroadcastStream(args)
        .map<DevicePosition>((dynamic event) => DevicePosition.fromMap(event))
        .handleError((Object error) {
          if (error is PlatformException) {
            throw _mapException(error);
          }
          throw error;
        });
  }

  @override
  Stream<DeviceLocationPermission> getPermissionStream({
    Duration pollingInterval = const Duration(seconds: 1),
  }) {
    final controller = StreamController<DeviceLocationPermission>.broadcast();
    StreamSubscription<dynamic>? nativeSub;
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
      timer = Timer.periodic(pollingInterval, (_) => emitCurrent());
      try {
        nativeSub = permissionUpdatesChannel.receiveBroadcastStream().listen(
          (dynamic event) {
            final index = event as int;
            if (!controller.isClosed) {
              controller.add(DeviceLocationPermission.values[index]);
            }
          },
          onError: (_) {
            // Polling will keep the stream alive.
          },
        );
      } on Exception {
        // Event channel not implemented on the native side; polling covers it.
      }
      emitCurrent();
    };

    controller.onCancel = () {
      timer?.cancel();
      timer = null;
      nativeSub?.cancel();
      nativeSub = null;
    };

    return controller.stream;
  }

  @override
  Stream<DeviceLocationServiceStatus> getServiceStatusStream() {
    return serviceUpdatesChannel
        .receiveBroadcastStream()
        .map<DeviceLocationServiceStatus>((dynamic event) {
          final index = event as int;
          return DeviceLocationServiceStatus.values[index];
        });
  }

  @override
  Future<DeviceLocationAccuracyStatus> getLocationAccuracy() async {
    final index = await methodChannel.invokeMethod<int>('getLocationAccuracy');
    return DeviceLocationAccuracyStatus.values[index ??
        DeviceLocationAccuracyStatus.unknown.index];
  }

  @override
  Future<DeviceLocationAccuracyStatus> requestTemporaryFullAccuracy({
    required String purposeKey,
  }) async {
    try {
      final index = await methodChannel.invokeMethod<int>(
        'requestTemporaryFullAccuracy',
        {'purposeKey': purposeKey},
      );
      return DeviceLocationAccuracyStatus.values[index ??
          DeviceLocationAccuracyStatus.unknown.index];
    } on PlatformException catch (e) {
      throw _mapException(e);
    }
  }

  @override
  Future<bool> openAppSettings({
    DeviceGeolocationSettingsCallback? callback,
  }) async {
    final opened = await methodChannel.invokeMethod<bool>('openAppSettings');
    return opened ?? false;
  }

  @override
  Future<bool> openLocationSettings({
    DeviceGeolocationSettingsCallback? callback,
  }) async {
    final opened = await methodChannel.invokeMethod<bool>(
      'openLocationSettings',
    );
    return opened ?? false;
  }

  @override
  Stream<bool> get settingsOpenedStream =>
      SettingsPanelLifecycle.instance.stream;

  Exception _mapException(PlatformException e) {
    switch (e.code) {
      case 'PERMISSION_DENIED':
        return PermissionDeniedException(e.message);
      case 'PERMISSION_DEFINITIONS_NOT_FOUND':
        return PermissionDefinitionsNotFoundException(e.message);
      case 'PERMISSION_REQUEST_IN_PROGRESS':
        return PermissionRequestInProgressException(e.message);
      case 'LOCATION_SERVICES_DISABLED':
        return LocationServiceDisabledException();
      case 'POSITION_UNAVAILABLE':
        return PositionUpdateException(e.message);
      default:
        return e;
    }
  }
}
