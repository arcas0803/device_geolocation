import 'dart:io';

/// Thrown when the user denied location permission.
class PermissionDeniedException implements Exception {
  PermissionDeniedException([this.message]);

  final String? message;

  @override
  String toString() =>
      'PermissionDeniedException(${message ?? 'permission denied'})';
}

/// Thrown when the required platform permission entries are missing
/// (e.g. AndroidManifest.xml or Info.plist).
class PermissionDefinitionsNotFoundException implements Exception {
  PermissionDefinitionsNotFoundException([this.message]);

  final String? message;

  @override
  String toString() {
    if (message != null && message!.isNotEmpty) return message!;

    if (Platform.isAndroid) {
      return 'PermissionDefinitionsNotFoundException: '
          'The AndroidManifest.xml of the host app is missing the required '
          'location permission declarations. '
          'Add the following inside the <manifest> tag:\n'
          '  <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />\n'
          'or, if you only need approximate location:\n'
          '  <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />\n'
          'For background access on Android 10+ also add:\n'
          '  <uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />';
    }

    if (Platform.isIOS || Platform.isMacOS) {
      return 'PermissionDefinitionsNotFoundException: '
          'The Info.plist of the host app is missing the required location '
          'usage description keys. '
          'Add the following to Info.plist:\n'
          '  <key>NSLocationWhenInUseUsageDescription</key>\n'
          '  <string>This app needs your location while in use.</string>\n'
          'For background access also add:\n'
          '  <key>NSLocationAlwaysAndWhenInUseUsageDescription</key>\n'
          '  <string>This app needs your location in the background.</string>';
    }

    return 'PermissionDefinitionsNotFoundException('
        '${message ?? 'missing platform permission declarations'})';
  }
}

/// Thrown when a permission request is made while another is already in
/// progress.
class PermissionRequestInProgressException implements Exception {
  PermissionRequestInProgressException([this.message]);

  final String? message;

  @override
  String toString() =>
      'PermissionRequestInProgressException('
      '${message ?? 'a permission request is already in progress'})';
}

/// Thrown when the device's location services are disabled.
class LocationServiceDisabledException implements Exception {
  @override
  String toString() => 'LocationServiceDisabledException';
}

/// Thrown when something prevented the platform from obtaining a position.
class PositionUpdateException implements Exception {
  PositionUpdateException([this.message]);

  final String? message;

  @override
  String toString() =>
      'PositionUpdateException(${message ?? 'unable to obtain position'})';
}
