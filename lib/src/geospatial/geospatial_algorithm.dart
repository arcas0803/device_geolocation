/// Available algorithms for geodetic calculations.
///
/// [vincenty] is more accurate (default). [haversine] is faster but can
/// deviate by up to ~0.3%.
enum GeospatialAlgorithm {
  /// Haversine formula, assuming a spherical Earth.
  haversine,

  /// Vincenty formula, using the WGS-84 ellipsoid.
  vincenty,
}
