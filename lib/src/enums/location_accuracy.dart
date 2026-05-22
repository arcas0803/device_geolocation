/// Desired precision for location updates.
enum LocationAccuracy {
  /// Lowest accuracy. ~3000m on iOS / ~500m on Android.
  lowest,

  /// Low accuracy. ~1000m on iOS / ~500m on Android.
  low,

  /// Medium accuracy. ~100m on iOS / 100-500m on Android.
  medium,

  /// High accuracy. ~10m on iOS / 0-100m on Android.
  high,

  /// Best available accuracy. ~0m on iOS / 0-100m on Android.
  best,

  /// Best accuracy optimized for navigation (iOS). Maps to [best] elsewhere.
  bestForNavigation,

  /// Reduced accuracy (iOS 14+). Maps to [lowest] on other platforms.
  reduced,
}
