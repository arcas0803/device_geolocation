import '../enums/location_accuracy.dart';

/// Cross-platform options used to request a location.
class LocationSettings {
  const LocationSettings({
    this.accuracy = LocationAccuracy.best,
    this.distanceFilter = 0,
    this.timeLimit,
  });

  /// Desired accuracy of the position. Defaults to [LocationAccuracy.best].
  final LocationAccuracy accuracy;

  /// Minimum distance in meters between updates. `0` (default) emits all.
  final int distanceFilter;

  /// Maximum time to wait for a position before throwing [TimeoutException].
  final Duration? timeLimit;

  /// Serializes this object to a map sent over the method channel.
  Map<String, dynamic> toJson() => {
    'accuracy': accuracy.index,
    'distanceFilter': distanceFilter,
    if (timeLimit != null) 'timeLimit': timeLimit!.inMilliseconds,
  };
}

/// Android-specific location settings.
class AndroidSettings extends LocationSettings {
  const AndroidSettings({
    super.accuracy = LocationAccuracy.best,
    super.distanceFilter = 0,
    super.timeLimit,
    this.forceLocationManager = false,
    this.intervalDuration,
  });

  /// Force the use of the legacy `LocationManager` instead of
  /// `FusedLocationProviderClient`.
  final bool forceLocationManager;

  /// Minimum desired interval between updates.
  final Duration? intervalDuration;

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'forceLocationManager': forceLocationManager,
    if (intervalDuration != null)
      'intervalDuration': intervalDuration!.inMilliseconds,
  };
}

/// Apple-specific location settings (iOS / macOS).
class AppleSettings extends LocationSettings {
  const AppleSettings({
    super.accuracy = LocationAccuracy.best,
    super.distanceFilter = 0,
    super.timeLimit,
    this.activityType = ActivityType.other,
    this.pauseLocationUpdatesAutomatically = false,
    this.showBackgroundLocationIndicator = false,
    this.allowBackgroundLocationUpdates = false,
  });

  /// Hint for the kind of activity producing the location updates.
  final ActivityType activityType;

  /// Whether the OS may pause updates when appropriate.
  final bool pauseLocationUpdatesAutomatically;

  /// Whether to show the blue background-usage indicator (iOS).
  final bool showBackgroundLocationIndicator;

  /// Whether the app may receive location updates while in the background.
  final bool allowBackgroundLocationUpdates;

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'activityType': activityType.index,
    'pauseLocationUpdatesAutomatically': pauseLocationUpdatesAutomatically,
    'showBackgroundLocationIndicator': showBackgroundLocationIndicator,
    'allowBackgroundLocationUpdates': allowBackgroundLocationUpdates,
  };
}

/// Web-specific location settings.
class WebSettings extends LocationSettings {
  const WebSettings({
    super.accuracy = LocationAccuracy.best,
    super.distanceFilter = 0,
    super.timeLimit,
    this.maximumAge = Duration.zero,
  });

  /// Maximum acceptable age of a cached browser position.
  final Duration maximumAge;

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'maximumAge': maximumAge.inMilliseconds,
  };
}

/// Hint used by Apple devices for the type of motion producing locations.
enum ActivityType {
  other,
  automotiveNavigation,
  fitness,
  otherNavigation,
  airborne,
}
