/// Granted accuracy level (iOS 14+ / Android 12+).
enum LocationAccuracyStatus {
  /// Approximate location only.
  reduced,

  /// Precise location.
  precise,

  /// Accuracy status not available on this platform.
  unknown,
}
