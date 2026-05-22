/// Reference to an Android drawable/mipmap resource declared in the host app.
///
/// Used by [ForegroundNotificationConfig.notificationIcon] to pick the icon
/// shown on the persistent foreground-service notification.
class AndroidResource {
  const AndroidResource({this.name = 'ic_launcher', this.defType = 'mipmap'});

  /// Resource name (e.g. `ic_launcher`, `ic_stat_notify`).
  final String name;

  /// Resource type. Defaults to `'mipmap'` to match the launcher icon
  /// convention; use `'drawable'` for a custom notification icon.
  final String defType;

  Map<String, dynamic> toJson() => {'name': name, 'defType': defType};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AndroidResource &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          defType == other.defType;

  @override
  int get hashCode => Object.hash(name, defType);

  @override
  String toString() => 'AndroidResource(name: $name, defType: $defType)';
}

/// Configuration for the Android foreground-service notification shown while
/// the plugin streams location updates in the background.
///
/// Pass an instance via `AndroidSettings.foregroundNotificationConfig` to
/// `DeviceGeolocation.getPositionStream` to make the plugin run as an Android
/// foreground service (required for continuous background location on
/// modern Android versions). The notification is mandatory: Android forces
/// any foreground service to display one.
class ForegroundNotificationConfig {
  const ForegroundNotificationConfig({
    required this.notificationTitle,
    required this.notificationText,
    this.notificationChannelName = 'Background Location',
    this.notificationIcon = const AndroidResource(),
    this.enableWakeLock = false,
    this.enableWifiLock = false,
    this.setOngoing = false,
    this.color,
  });

  /// Title displayed in the notification.
  final String notificationTitle;

  /// Body text displayed in the notification.
  final String notificationText;

  /// User-visible name of the notification channel (Android 8+).
  final String notificationChannelName;

  /// Drawable/mipmap resource used as the small icon of the notification.
  final AndroidResource notificationIcon;

  /// If `true`, the plugin acquires a `PARTIAL_WAKE_LOCK` so the CPU stays
  /// awake while the service runs. Required for reliable tracking with the
  /// screen off.
  final bool enableWakeLock;

  /// If `true`, the plugin acquires a high-performance `WifiLock` so the
  /// Wi-Fi radio stays awake. Useful for tracking that also needs network.
  final bool enableWifiLock;

  /// If `true`, the notification cannot be dismissed by the user while the
  /// service is running.
  final bool setOngoing;

  /// Optional accent color applied to the notification icon, expressed as an
  /// ARGB integer (e.g. `0xFF2196F3`). `int` is used instead of `Color` to
  /// keep this model free of `dart:ui` dependencies.
  final int? color;

  Map<String, dynamic> toJson() => {
    'notificationTitle': notificationTitle,
    'notificationText': notificationText,
    'notificationChannelName': notificationChannelName,
    'notificationIcon': notificationIcon.toJson(),
    'enableWakeLock': enableWakeLock,
    'enableWifiLock': enableWifiLock,
    'setOngoing': setOngoing,
    'color': color,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ForegroundNotificationConfig &&
          runtimeType == other.runtimeType &&
          notificationTitle == other.notificationTitle &&
          notificationText == other.notificationText &&
          notificationChannelName == other.notificationChannelName &&
          notificationIcon == other.notificationIcon &&
          enableWakeLock == other.enableWakeLock &&
          enableWifiLock == other.enableWifiLock &&
          setOngoing == other.setOngoing &&
          color == other.color;

  @override
  int get hashCode => Object.hash(
    notificationTitle,
    notificationText,
    notificationChannelName,
    notificationIcon,
    enableWakeLock,
    enableWifiLock,
    setOngoing,
    color,
  );

  @override
  String toString() =>
      'ForegroundNotificationConfig(title: $notificationTitle, '
      'text: $notificationText, channel: $notificationChannelName, '
      'icon: $notificationIcon, wakeLock: $enableWakeLock, '
      'wifiLock: $enableWifiLock, ongoing: $setOngoing, color: $color)';
}
