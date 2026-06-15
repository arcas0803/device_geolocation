import 'dart:math' as math;

import 'geospatial_algorithm.dart';
import 'haversine.dart';
import 'latlong_math.dart';
import 'vincenty.dart';

/// Calculates the great-circle distance between two coordinates in meters.
///
/// [algorithm] selects the formula. [GeospatialAlgorithm.vincenty] is more
/// accurate; [GeospatialAlgorithm.haversine] is faster.
double calculateDistance(
  double startLatitude,
  double startLongitude,
  double endLatitude,
  double endLongitude, {
  GeospatialAlgorithm algorithm = GeospatialAlgorithm.vincenty,
}) {
  final p1 = GeoPoint(startLatitude, startLongitude);
  final p2 = GeoPoint(endLatitude, endLongitude);

  switch (algorithm) {
    case GeospatialAlgorithm.haversine:
      return const Haversine().distance(p1, p2);
    case GeospatialAlgorithm.vincenty:
      return const Vincenty().distance(p1, p2);
  }
}

/// Calculates the initial bearing from one coordinate to another in degrees.
///
/// The result is in the range `(-180, 180]`.
double calculateBearing(
  double startLatitude,
  double startLongitude,
  double endLatitude,
  double endLongitude,
) {
  final p1 = GeoPoint(startLatitude, startLongitude);
  final p2 = GeoPoint(endLatitude, endLongitude);

  final diffLongitude = p2.longitudeInRad - p1.longitudeInRad;

  final y = math.sin(diffLongitude);
  final x =
      math.cos(p1.latitudeInRad) * math.tan(p2.latitudeInRad) -
      math.sin(p1.latitudeInRad) * math.cos(diffLongitude);

  return radianToDeg(math.atan2(y, x));
}

/// Message sent to an isolate for distance calculations.
class DistanceIsolateMessage {
  /// Creates a message with the coordinates and algorithm to use.
  const DistanceIsolateMessage(
    this.startLatitude,
    this.startLongitude,
    this.endLatitude,
    this.endLongitude,
    this.algorithm,
  );

  final double startLatitude;
  final double startLongitude;
  final double endLatitude;
  final double endLongitude;
  final GeospatialAlgorithm algorithm;
}

/// Top-level worker invoked inside an isolate for distance calculations.
double distanceBetweenWorker(DistanceIsolateMessage message) {
  return calculateDistance(
    message.startLatitude,
    message.startLongitude,
    message.endLatitude,
    message.endLongitude,
    algorithm: message.algorithm,
  );
}

/// Message sent to an isolate for bearing calculations.
class BearingIsolateMessage {
  /// Creates a message with the coordinates.
  const BearingIsolateMessage(
    this.startLatitude,
    this.startLongitude,
    this.endLatitude,
    this.endLongitude,
  );

  final double startLatitude;
  final double startLongitude;
  final double endLatitude;
  final double endLongitude;
}

/// Top-level worker invoked inside an isolate for bearing calculations.
double bearingBetweenWorker(BearingIsolateMessage message) {
  return calculateBearing(
    message.startLatitude,
    message.startLongitude,
    message.endLatitude,
    message.endLongitude,
  );
}
