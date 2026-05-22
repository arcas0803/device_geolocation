import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'device_geolocation_platform_interface.dart';
import 'src/enums/enums.dart';
import 'src/errors/geolocation_exceptions.dart';
import 'src/models/models.dart';

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

  @override
  Future<LocationPermission> checkPermission() async {
    try {
      final index = await methodChannel.invokeMethod<int>('checkPermission');
      return LocationPermission.values[index ?? 0];
    } on PlatformException catch (e) {
      throw _mapException(e);
    }
  }

  @override
  Future<LocationPermission> requestPermission({
    bool requestBackground = false,
  }) async {
    try {
      final index = await methodChannel.invokeMethod<int>('requestPermission', {
        'requestBackground': requestBackground,
      });
      return LocationPermission.values[index ?? 0];
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
  Future<Position?> getLastKnownPosition({
    bool forceLocationManager = false,
  }) async {
    try {
      final result = await methodChannel.invokeMapMethod<String, dynamic>(
        'getLastKnownPosition',
        {'forceLocationManager': forceLocationManager},
      );
      return result == null ? null : Position.fromMap(result);
    } on PlatformException catch (e) {
      throw _mapException(e);
    }
  }

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    try {
      final result = await methodChannel.invokeMapMethod<String, dynamic>(
        'getCurrentPosition',
        locationSettings?.toJson() ?? const <String, dynamic>{},
      );
      if (result == null) {
        throw PositionUpdateException('Platform returned no position');
      }
      return Position.fromMap(result);
    } on PlatformException catch (e) {
      throw _mapException(e);
    }
  }

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    final args = locationSettings?.toJson() ?? const <String, dynamic>{};
    return locationUpdatesChannel
        .receiveBroadcastStream(args)
        .map<Position>((dynamic event) => Position.fromMap(event))
        .handleError((Object error) {
          if (error is PlatformException) {
            throw _mapException(error);
          }
          throw error;
        });
  }

  @override
  Stream<ServiceStatus> getServiceStatusStream() {
    return serviceUpdatesChannel.receiveBroadcastStream().map<ServiceStatus>((
      dynamic event,
    ) {
      final index = event as int;
      return ServiceStatus.values[index];
    });
  }

  @override
  Future<LocationAccuracyStatus> getLocationAccuracy() async {
    final index = await methodChannel.invokeMethod<int>('getLocationAccuracy');
    return LocationAccuracyStatus.values[index ??
        LocationAccuracyStatus.unknown.index];
  }

  @override
  Future<LocationAccuracyStatus> requestTemporaryFullAccuracy({
    required String purposeKey,
  }) async {
    try {
      final index = await methodChannel.invokeMethod<int>(
        'requestTemporaryFullAccuracy',
        {'purposeKey': purposeKey},
      );
      return LocationAccuracyStatus.values[index ??
          LocationAccuracyStatus.unknown.index];
    } on PlatformException catch (e) {
      throw _mapException(e);
    }
  }

  @override
  Future<bool> openAppSettings() async {
    final opened = await methodChannel.invokeMethod<bool>('openAppSettings');
    return opened ?? false;
  }

  @override
  Future<bool> openLocationSettings() async {
    final opened = await methodChannel.invokeMethod<bool>(
      'openLocationSettings',
    );
    return opened ?? false;
  }

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
