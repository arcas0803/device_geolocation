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
  String toString() =>
      'PermissionDefinitionsNotFoundException('
      '${message ?? 'missing platform permission declarations'})';
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
