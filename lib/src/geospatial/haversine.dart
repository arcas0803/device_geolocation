/*
 * This file is adapted from latlong2
 * (https://github.com/ThexXTURBOXx/dart-latlong),
 * licensed under the Apache License, Version 2.0.
 *
 * Copyright (c) 2016, Michael Mitterer (office@mikemitterer.at),
 * IT-Consulting and Development Limited.
 */

import 'dart:math' as math;

import 'latlong_math.dart';

/// Haversine distance calculator assuming a spherical Earth.
///
/// Faster than [Vincenty] but can be off by up to ~0.3%.
class Haversine {
  /// Creates a const Haversine calculator.
  const Haversine();

  /// Returns the distance between [p1] and [p2] in meters.
  double distance(final GeoPoint p1, final GeoPoint p2) {
    final dLat = p2.latitudeInRad - p1.latitudeInRad;
    final dLng = normalizeLongitudeDelta(
      p2.longitudeInRad - p1.longitudeInRad,
    );

    final sinDLat = math.sin(dLat / 2);
    final sinDLng = math.sin(dLng / 2);

    final a = sinDLat * sinDLat +
        sinDLng * sinDLng *
            math.cos(p1.latitudeInRad) *
            math.cos(p2.latitudeInRad);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return equatorRadius * c;
  }
}
