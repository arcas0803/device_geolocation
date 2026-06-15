/*
 * Portions of this file are adapted from latlong2
 * (https://github.com/ThexXTURBOXx/dart-latlong),
 * licensed under the Apache License, Version 2.0.
 *
 * Copyright (c) 2016, Michael Mitterer (office@mikemitterer.at),
 * IT-Consulting and Development Limited.
 */

import 'dart:math' as math;

/// 2*pi as a standalone constant.
const double twoPi = 2 * math.pi;

/// The same as [twoPi] (i.e., 2*pi).
const double tau = twoPi;

/// Equator radius in meters (WGS-84 ellipsoid).
const double equatorRadius = 6378137.0;

/// Polar radius in meters (WGS-84 ellipsoid).
const double polarRadius = 6356752.314245;

/// WGS-84 flattening.
const double flattening = 1 / 298.257223563;

/// Earth radius in meters (alias for [equatorRadius]).
const double earthRadius = equatorRadius;

/// Converts degrees to radians.
double degToRadian(final double deg) => deg * (math.pi / 180.0);

/// Converts radians to degrees.
double radianToDeg(final double rad) => rad * (180.0 / math.pi);

/// Normalizes a longitude delta to the shortest arc, i.e. the interval
/// `(-pi, pi]`.
double normalizeLongitudeDelta(final double delta) {
  final w = delta % tau;
  return w > math.pi ? w - tau : w;
}

/// Simple internal latitude/longitude representation used by the geospatial
/// algorithms.
class GeoPoint {
  /// Creates a point from decimal degrees.
  const GeoPoint(this.latitude, this.longitude);

  /// Latitude in degrees.
  final double latitude;

  /// Longitude in degrees.
  final double longitude;

  /// Latitude in radians.
  double get latitudeInRad => degToRadian(latitude);

  /// Longitude in radians.
  double get longitudeInRad => degToRadian(longitude);
}
