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

/// Vincenty distance calculator using the WGS-84 ellipsoid.
///
/// More accurate than [Haversine] but slower. May fail to converge for
/// nearly antipodal points.
class Vincenty {
  final int maxIterations;
  final double accuracy;

  /// Creates a const Vincenty calculator.
  ///
  /// [maxIterations] defaults to 200 and [accuracy] to 1e-12.
  const Vincenty({this.maxIterations = 200, this.accuracy = 1e-12});

  /// Returns the distance between [p1] and [p2] in meters.
  double distance(final GeoPoint p1, final GeoPoint p2) {
    const a = equatorRadius;
    const b = polarRadius;
    const f = flattening;

    final l = normalizeLongitudeDelta(p2.longitudeInRad - p1.longitudeInRad);

    final u1 = math.atan((1 - f) * math.tan(p1.latitudeInRad));
    final u2 = math.atan((1 - f) * math.tan(p2.latitudeInRad));
    final sinU1 = math.sin(u1), cosU1 = math.cos(u1);
    final sinU2 = math.sin(u2), cosU2 = math.cos(u2);

    double sinLambda,
        cosLambda,
        sinSigma,
        cosSigma,
        sigma,
        sinAlpha,
        cosSqAlpha,
        cos2SigmaM;
    double lambda = l, lambdaP;
    var iterations = maxIterations;

    do {
      sinLambda = math.sin(lambda);
      cosLambda = math.cos(lambda);
      sinSigma = math.sqrt(
        (cosU2 * sinLambda) * (cosU2 * sinLambda) +
            (cosU1 * sinU2 - sinU1 * cosU2 * cosLambda) *
                (cosU1 * sinU2 - sinU1 * cosU2 * cosLambda),
      );

      if (sinSigma == 0) {
        return 0.0;
      }

      cosSigma = sinU1 * sinU2 + cosU1 * cosU2 * cosLambda;
      sigma = math.atan2(sinSigma, cosSigma);
      sinAlpha = cosU1 * cosU2 * sinLambda / sinSigma;
      cosSqAlpha = 1 - sinAlpha * sinAlpha;
      cos2SigmaM = cosSigma - 2 * sinU1 * sinU2 / cosSqAlpha;

      if (cos2SigmaM.isNaN) {
        cos2SigmaM = 0.0;
      }

      final c = f / 16 * cosSqAlpha * (4 + f * (4 - 3 * cosSqAlpha));
      lambdaP = lambda;
      lambda =
          l +
          (1 - c) *
              f *
              sinAlpha *
              (sigma +
                  c *
                      sinSigma *
                      (cos2SigmaM +
                          c * cosSigma * (-1 + 2 * cos2SigmaM * cos2SigmaM)));
    } while ((lambda - lambdaP).abs() > accuracy && --iterations > 0);

    if (iterations == 0) {
      throw StateError('Vincenty distance calculation failed to converge.');
    }

    final uSq = cosSqAlpha * (a * a - b * b) / (b * b);
    final bigA =
        1 + uSq / 16384 * (4096 + uSq * (-768 + uSq * (320 - 175 * uSq)));
    final bigB = uSq / 1024 * (256 + uSq * (-128 + uSq * (74 - 47 * uSq)));
    final deltaSigma =
        bigB *
        sinSigma *
        (cos2SigmaM +
            bigB /
                4 *
                (cosSigma * (-1 + 2 * cos2SigmaM * cos2SigmaM) -
                    bigB /
                        6 *
                        cos2SigmaM *
                        (-3 + 4 * sinSigma * sinSigma) *
                        (-3 + 4 * cos2SigmaM * cos2SigmaM)));

    return b * bigA * (sigma - deltaSigma);
  }
}
