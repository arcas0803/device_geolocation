/// Possible location permission states.
enum DeviceLocationPermission {
  /// Access is denied. The app may try requesting again.
  denied,

  /// Access is permanently denied. The user must change it from settings.
  deniedForever,

  /// Access is granted only while the app is in use.
  whileInUse,

  /// Access is granted including when the app is in the background.
  always,

  /// Permission state cannot be determined (web fallback).
  unableToDetermine,
}
