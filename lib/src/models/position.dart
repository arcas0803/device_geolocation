import 'package:meta/meta.dart';

/// Contains detailed location data returned by the platform.
@immutable
class Position {
  const Position({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.accuracy,
    required this.altitude,
    required this.altitudeAccuracy,
    required this.heading,
    required this.headingAccuracy,
    required this.speed,
    required this.speedAccuracy,
    this.floor,
    this.isMocked = false,
  });

  /// Latitude in degrees normalized to the interval [-90, 90].
  final double latitude;

  /// Longitude in degrees normalized to the interval (-180, 180].
  final double longitude;

  /// Moment at which the position was determined.
  final DateTime timestamp;

  /// Horizontal accuracy in meters.
  final double accuracy;

  /// Altitude in meters above the WGS 84 reference ellipsoid.
  final double altitude;

  /// Vertical accuracy of [altitude] in meters.
  final double altitudeAccuracy;

  /// Direction of travel in degrees (0-360).
  final double heading;

  /// Accuracy of [heading] in degrees.
  final double headingAccuracy;

  /// Speed in meters per second.
  final double speed;

  /// Accuracy of [speed] in meters per second.
  final double speedAccuracy;

  /// Floor of the building (iOS only).
  final int? floor;

  /// True if the platform reports the location came from a mock provider.
  final bool isMocked;

  static double _toDouble(dynamic value) =>
      value == null ? 0.0 : (value as num).toDouble();

  /// Builds a [Position] from a map produced by a platform implementation.
  static Position fromMap(dynamic message) {
    final map = Map<dynamic, dynamic>.from(message as Map);

    if (!map.containsKey('latitude')) {
      throw ArgumentError.value(
        map,
        'positionMap',
        'Missing mandatory key `latitude`.',
      );
    }
    if (!map.containsKey('longitude')) {
      throw ArgumentError.value(
        map,
        'positionMap',
        'Missing mandatory key `longitude`.',
      );
    }

    final ts = map['timestamp'];
    final timestamp = ts == null
        ? DateTime.now()
        : DateTime.fromMillisecondsSinceEpoch((ts as num).toInt(), isUtc: true);

    return Position(
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      timestamp: timestamp,
      accuracy: _toDouble(map['accuracy']),
      altitude: _toDouble(map['altitude']),
      altitudeAccuracy: _toDouble(map['altitude_accuracy']),
      heading: _toDouble(map['heading']),
      headingAccuracy: _toDouble(map['heading_accuracy']),
      speed: _toDouble(map['speed']),
      speedAccuracy: _toDouble(map['speed_accuracy']),
      floor: map['floor'] as int?,
      isMocked: (map['is_mocked'] as bool?) ?? false,
    );
  }

  /// JSON-serializable representation of this position.
  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'timestamp': timestamp.millisecondsSinceEpoch,
    'accuracy': accuracy,
    'altitude': altitude,
    'altitude_accuracy': altitudeAccuracy,
    'heading': heading,
    'heading_accuracy': headingAccuracy,
    'speed': speed,
    'speed_accuracy': speedAccuracy,
    'floor': floor,
    'is_mocked': isMocked,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Position &&
          other.latitude == latitude &&
          other.longitude == longitude &&
          other.timestamp == timestamp &&
          other.accuracy == accuracy &&
          other.altitude == altitude &&
          other.altitudeAccuracy == altitudeAccuracy &&
          other.heading == heading &&
          other.headingAccuracy == headingAccuracy &&
          other.speed == speed &&
          other.speedAccuracy == speedAccuracy &&
          other.floor == floor &&
          other.isMocked == isMocked);

  @override
  int get hashCode => Object.hash(
    latitude,
    longitude,
    timestamp,
    accuracy,
    altitude,
    altitudeAccuracy,
    heading,
    headingAccuracy,
    speed,
    speedAccuracy,
    floor,
    isMocked,
  );

  @override
  String toString() => 'Position(latitude: $latitude, longitude: $longitude)';
}
