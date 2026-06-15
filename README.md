# device_geolocation

[![pub package](https://img.shields.io/pub/v/device_geolocation.svg)](https://pub.dev/packages/device_geolocation)
[![CI](https://github.com/arcas0803/device_geolocation/actions/workflows/ci.yaml/badge.svg)](https://github.com/arcas0803/device_geolocation/actions/workflows/ci.yaml)
[![codecov](https://codecov.io/gh/arcas0803/device_geolocation/branch/main/graph/badge.svg)](https://codecov.io/gh/arcas0803/device_geolocation)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A cross-platform Flutter plugin that provides easy access to the device's
geolocation across **Android, iOS, macOS, Web, Windows and Linux**.

> **Credits & attribution** — the public API surface, semantics and naming of
> this plugin are inspired by the excellent
> [`flutter-geolocator`](https://github.com/Baseflow/flutter-geolocator) plugin
> by [Baseflow](https://baseflow.com). This package is an independent
> reimplementation distributed under the MIT License.

## Features

- One-shot and streaming positions.
- Global default settings via `DeviceGeolocation.configure()`.
- Permission lifecycle (`checkPermission`, `requestPermission`) with optional
  Android background-location escalation.
- Permission change stream (`getPermissionStream`).
- Service-status stream for OS-level location toggles.
- iOS 14+ temporary full-accuracy requests.
- Settings callbacks and `settingsOpenedStream` so the app knows when the user
  returns from the OS settings screen.
- Distance and bearing helpers via the Haversine formula.

## Platform support

| Platform | Minimum version | Backend                                                    |
| -------- | --------------- | ---------------------------------------------------------- |
| Android  | 7.0 (API 24)    | Fused Location Provider with LocationManager fallback      |
| iOS      | 14.0            | `CLLocationManager` + `CLLocationUpdate.liveUpdates` (17+) |
| macOS    | 11.0            | `CLLocationManager` + `CLLocationUpdate.liveUpdates` (14+) |
| Web      | Secure context  | `navigator.geolocation` + `navigator.permissions`          |
| Windows  | 10 (1809+)      | WinRT `Windows.Devices.Geolocation`                        |
| Linux    | GeoClue2        | `org.freedesktop.GeoClue2` over D-Bus                      |

## Toolchain compatibility

This plugin is built to be **forward-compatible with the latest mobile build
toolchains**:

- **Swift Package Manager** — the iOS and macOS plugins are distributed as
  Swift packages (`ios/device_geolocation/Package.swift`,
  `macos/device_geolocation/Package.swift`), so they integrate natively when
  Flutter resolves your app with SwiftPM (the default on recent Flutter
  versions) without requiring a CocoaPods install. Traditional CocoaPods
  resolution is still supported through the bundled `.podspec` files.
- **Gradle 9** — the Android side targets the AGP 9 / Gradle 9 toolchain
  (Kotlin 2.x, Java 17 toolchain, namespace-based manifests). No legacy
  `package=` attributes, no deprecated `compile`/`testCompile` configurations,
  and no buildscript `apply` blocks: the module builds cleanly with the
  declarative Kotlin DSL (`build.gradle.kts`).

## Functionality matrix

All APIs are part of the same façade — the table below clarifies which
capabilities are actually wired on each platform.

| Feature                                | Android | iOS | macOS | Web | Windows | Linux |
| -------------------------------------- | :-----: | :-: | :---: | :-: | :-----: | :---: |
| `checkPermission` / `requestPermission` | ✅ | ✅ | ✅ | ✅¹ | ✅ | ✅² |
| Background permission escalation       | ✅ | ✅³ | — | — | — | — |
| `isLocationServiceEnabled`             | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `getCurrentPosition`                   | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `getPositionStream`                    | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Background foreground service          | ✅ | —⁹ | — | — | — | — |
| `getServiceStatusStream`               | ✅ | ✅ | ✅ | —⁵ | ✅ | ✅ |
| `getPermissionStream`                  | ✅⁴ | ✅ | ✅ | ✅ | ✅⁴ | ✅⁴ |
| `settingsOpenedStream` / settings callbacks | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `getLocationAccuracy`                  | ✅ | ✅ | ✅ | ✅⁶ | ✅⁶ | ✅⁶ |
| `requestTemporaryFullAccuracy`         | —⁷ | ✅ | ✅ | —⁷ | —⁷ | —⁷ |
| `openAppSettings` / `openLocationSettings` | ✅ | ✅ | ✅ | —⁸ | ✅ | ✅ |
| Distance / bearing helpers             | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

<sup>¹ Uses the browser Permissions API where available; falls back to
`whileInUse` after a successful position fix.<br>
² Linux exposes a single `whileInUse`-like permission once the GeoClue
agent has approved the app.<br>
³ iOS `Always` authorization (use `NSLocationAlwaysAndWhenInUseUsageDescription`).<br>
⁴ Android and Linux do not expose a native permission-change event; the
stream falls back to polling. Windows relies on OS-level change detection.<br>
⁵ The browser does not expose a service-status event; the stream emits the
initial status and stays open.<br>
⁶ Always reports `precise` (or `unknown` if permission is denied) because
the platform does not differentiate reduced vs. precise modes.<br>
⁷ Temporary full-accuracy is an iOS/macOS-only concept; the call is a no-op
that returns the current accuracy on other platforms.<br>
⁸ Browsers do not allow programmatic navigation to permission settings;
the call returns `false`.<br>
⁹ iOS keeps location running in the background via the platform's own
`UIBackgroundModes` + `allowBackgroundLocationUpdates` flag — see the
iOS permissions section above.</sup>

## Install

```yaml
dependencies:
  device_geolocation: ^2.1.3
```

## Permissions setup

### Android (`AndroidManifest.xml`)

Add the permissions your app needs to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<!-- Only if you need background location on Android 10+ -->
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
```

### iOS (`Info.plist`)

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>We need your location to show nearby content.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>We use your location in the background to ...</string>
```

### macOS

In `macos/Runner/Info.plist`:

```xml
<key>NSLocationUsageDescription</key>
<string>We need your location to ...</string>
```

And enable the *Location* capability in `macos/Runner/DebugProfile.entitlements`
and `macos/Runner/Release.entitlements`:

```xml
<key>com.apple.security.personal-information.location</key>
<true/>
```

### Web

The Geolocation API only works on **HTTPS** or `localhost`. No additional
configuration is required.

### Windows

Enable the *Location* capability for your packaged app.

### Linux

Requires the `geoclue-2.0` service (installed by default on most desktop
distributions). No build-time configuration is needed.

## Usage

```dart
import 'package:device_geolocation/device_geolocation.dart';

Future<void> locateMe() async {
  // Optional: configure once so every call uses these defaults.
  DeviceGeolocation.configure(
    const DeviceLocationSettings(accuracy: DeviceLocationAccuracy.high),
  );

  if (!await DeviceGeolocation.isLocationServiceEnabled()) {
    await DeviceGeolocation.openLocationSettings();
    return;
  }

  var permission = await DeviceGeolocation.checkPermission();
  if (permission == DeviceLocationPermission.denied) {
    permission = await DeviceGeolocation.requestPermission();
  }
  if (permission == DeviceLocationPermission.deniedForever) {
    await DeviceGeolocation.openAppSettings();
    return;
  }

  // Uses the configured settings because no override is passed.
  final position = await DeviceGeolocation.getCurrentPosition();
  print('${position.latitude}, ${position.longitude}');
}
```

### Streaming positions

```dart
final subscription = DeviceGeolocation.getPositionStream(
  deviceLocationSettings: const DeviceLocationSettings(
    accuracy: DeviceLocationAccuracy.high,
    distanceFilter: 10,
  ),
).listen((position) {
  print('${position.latitude}, ${position.longitude}');
});

// later
await subscription.cancel();
```

### Distance and bearing

```dart
// Default uses the more accurate Vincenty formula.
final meters = DeviceGeolocation.distanceBetween(
    52.2165157, 6.9437819, 52.3546274, 4.8285838);

// Use Haversine for a faster, spherical-Earth approximation.
final metersHaversine = DeviceGeolocation.distanceBetween(
    52.2165157, 6.9437819, 52.3546274, 4.8285838,
    algorithm: GeospatialAlgorithm.haversine);

final bearing = DeviceGeolocation.bearingBetween(
    52.2165157, 6.9437819, 52.3546274, 4.8285838);
```

Heavy calculations can be offloaded to an isolate. On the web, where
isolates are unavailable, the call falls back to the synchronous version on
the main thread.

```dart
final meters = await DeviceGeolocation.distanceBetweenIsolate(
    52.2165157, 6.9437819, 52.3546274, 4.8285838);
final bearing = await DeviceGeolocation.bearingBetweenIsolate(
    52.2165157, 6.9437819, 52.3546274, 4.8285838);
```

### Requesting background permission on Android

```dart
final permission = await DeviceGeolocation.requestPermission(
  requestBackground: true,
);
```

The plugin first requests the foreground permission and — on Android 10+
(API 29) — chains the background permission request only when foreground access
has been granted, matching Google's [recommended flow](https://developer.android.com/develop/sensors-and-location/location/permissions).

### Background location on Android (foreground service)

From 1.1.0 the plugin can promote an active location stream to an Android
`FOREGROUND_SERVICE_TYPE_LOCATION` service so updates keep flowing while
your app is in the background, the screen is off or the user switches to
another task. Pass a `ForegroundNotificationConfig` inside
`AndroidSettings.foregroundNotificationConfig`:

```dart
final subscription = DeviceGeolocation.getPositionStream(
  deviceLocationSettings: const AndroidSettings(
    accuracy: DeviceLocationAccuracy.high,
    distanceFilter: 10,
    intervalDuration: Duration(seconds: 5),
    foregroundNotificationConfig: ForegroundNotificationConfig(
      notificationTitle: 'Tracking your run',
      notificationText: 'We will keep recording while the screen is off.',
      notificationChannelName: 'Activity tracking',
      notificationIcon: AndroidResource(
        name: 'ic_stat_notify',
        defType: 'drawable',
      ),
      enableWakeLock: true,
      enableWifiLock: false,
      setOngoing: true,
      color: 0xFF2196F3,
    ),
  ),
).listen((position) => print(position));
```

The plugin starts a bound service that holds the location subscription,
shows the (mandatory) notification described by the config and stops as
soon as every Flutter engine has cancelled its stream. Multiple
subscriptions across multiple Flutter engines are supported: the service
fans every fix out to all active sinks and only tears itself down when
the last one cancels.

The service automatically picks the best available location source on
each device — `FusedLocationProviderClient` from Google Play services
when they are installed, and the system `LocationManager` (GPS / network
providers) on devices without Play services or when you pass
`forceLocationManager: true`. Background tracking therefore works on
GMS and non-GMS devices alike.

#### Required setup in the host app

The service itself is declared in the plugin's `AndroidManifest.xml`,
but Google Play and Android still require the *consumer* app to declare
the matching permissions. Add these to your
`android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />
<!-- Optional, only required when you enable enableWakeLock. -->
<uses-permission android:name="android.permission.WAKE_LOCK" />
```

On Android 14 (API 34) and above the runtime enforces
`FOREGROUND_SERVICE_LOCATION`. If the host manifest does not declare it,
the stream emits a `PositionUpdateException` with the code
`MISSING_FOREGROUND_SERVICE_LOCATION_PERMISSION`. Make sure your
Google Play listing also justifies background location usage, as the
store policy requires for any app shipping this permission.

## API reference

| Member                                                                   | Returns                                  |
| ------------------------------------------------------------------------ | ---------------------------------------- |
| `DeviceGeolocation.configure(settings)`                                  | `void`                                   |
| `DeviceGeolocation.checkPermission()`                                    | `Future<DeviceLocationPermission>`       |
| `DeviceGeolocation.requestPermission({requestBackground})`               | `Future<DeviceLocationPermission>`       |
| `DeviceGeolocation.isLocationServiceEnabled()`                           | `Future<bool>`                           |
| `DeviceGeolocation.getCurrentPosition({deviceLocationSettings})`         | `Future<DevicePosition>`                 |
| `DeviceGeolocation.getPositionStream({deviceLocationSettings})`          | `Stream<DevicePosition>`                 |
| `DeviceGeolocation.getPermissionStream({pollingInterval})`               | `Stream<DeviceLocationPermission>`       |
| `DeviceGeolocation.getServiceStatusStream()`                             | `Stream<DeviceLocationServiceStatus>`    |
| `DeviceGeolocation.getLocationAccuracy()`                                | `Future<DeviceLocationAccuracyStatus>`   |
| `DeviceGeolocation.requestTemporaryFullAccuracy({purposeKey})`           | `Future<DeviceLocationAccuracyStatus>`   |
| `DeviceGeolocation.openAppSettings({callback})`                          | `Future<bool>`                           |
| `DeviceGeolocation.openLocationSettings({callback})`                     | `Future<bool>`                           |
| `DeviceGeolocation.settingsOpenedStream`                                 | `Stream<bool>`                           |
| `DeviceGeolocation.distanceBetween(lat1, lon1, lat2, lon2, {algorithm})` | `double` (meters)                        |
| `DeviceGeolocation.distanceBetweenIsolate(lat1, lon1, lat2, lon2, {algorithm})` | `Future<double>` (meters)         |
| `DeviceGeolocation.bearingBetween(lat1, lon1, lat2, lon2)`               | `double` (degrees)                       |
| `DeviceGeolocation.bearingBetweenIsolate(lat1, lon1, lat2, lon2)`        | `Future<double>` (degrees)               |

## Migration from `flutter-geolocator`

| `geolocator`                                | `device_geolocation`                                       |
| ------------------------------------------- | ---------------------------------------------------------- |
| `Geolocator.checkPermission()`              | `DeviceGeolocation.checkPermission()`                      |
| `Geolocator.requestPermission()`            | `DeviceGeolocation.requestPermission()`                    |
| `Geolocator.isLocationServiceEnabled()`     | `DeviceGeolocation.isLocationServiceEnabled()`             |
| `Geolocator.getCurrentPosition()`           | `DeviceGeolocation.getCurrentPosition()`                   |
| `Geolocator.getPositionStream()`            | `DeviceGeolocation.getPositionStream()`                    |
| `Geolocator.getServiceStatusStream()`       | `DeviceGeolocation.getServiceStatusStream()`               |
| `Geolocator.openAppSettings()`              | `DeviceGeolocation.openAppSettings()`                      |
| `Geolocator.openLocationSettings()`         | `DeviceGeolocation.openLocationSettings()`                 |
| `Geolocator.distanceBetween(...)`           | `DeviceGeolocation.distanceBetween(...)`                   |
| `Geolocator.bearingBetween(...)`            | `DeviceGeolocation.bearingBetween(...)`                    |

Type names in this package use the `Device` prefix:

| Old (`geolocator`)         | New (`device_geolocation`)          |
| -------------------------- | ----------------------------------- |
| `Position`                 | `DevicePosition`                    |
| `LocationSettings`         | `DeviceLocationSettings`            |
| `LocationAccuracy`         | `DeviceLocationAccuracy`            |
| `LocationPermission`       | `DeviceLocationPermission`          |
| `LocationAccuracyStatus`   | `DeviceLocationAccuracyStatus`      |
| `ServiceStatus`            | `DeviceLocationServiceStatus`       |

Asking for background-location permission on Android 10+ collapses into a
single call:

```dart
// Was (geolocator): two manual calls
// Now (device_geolocation):
await DeviceGeolocation.requestPermission(requestBackground: true);
```

## Testing your app with the bundled mock

This package ships a ready-to-use mock so you can unit/widget-test screens
that depend on the location API without reaching the platform channel.

```dart
import 'package:device_geolocation/device_geolocation.dart';
import 'package:device_geolocation/testing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DeviceGeolocationMock mock;

  setUp(() {
    mock = DeviceGeolocationMock.install();
  });

  test('shows the user\'s coordinates', () async {
    mock.setPosition(mock.makePosition(latitude: 41.4, longitude: 2.2));

    final p = await DeviceGeolocation.getCurrentPosition();
    expect(p.latitude, 41.4);
    expect(p.longitude, 2.2);
  });

  test('streams live updates', () async {
    final stream = DeviceGeolocation.getPositionStream();
    final future = stream.first;
    mock.emitPosition(mock.makePosition(latitude: 1, longitude: 2));
    expect((await future).latitude, 1);
  });

  test('simulates a denied permission', () async {
    mock.permission = DeviceLocationPermission.deniedForever;
    expect(
      await DeviceGeolocation.checkPermission(),
      DeviceLocationPermission.deniedForever,
    );
  });

  test('simulates a platform error', () async {
    mock.throwOnNext(PermissionDeniedException('denied'));
    expect(
      DeviceGeolocation.requestPermission(),
      throwsA(isA<PermissionDeniedException>()),
    );
  });
}
```

The mock also exposes `lastRequestedBackground`, `lastDeviceLocationSettings`
and `lastPurposeKey` for assertions, plus methods to emit position, permission
and service-status events. Call `await mock.reset()` between tests to clear
state and close stream controllers.

## Test coverage

Run:

```bash
flutter test --coverage
```

The Dart library is covered by **53 tests**. Current line coverage
(measured locally; updated automatically in CI via [Codecov](https://codecov.io/gh/arcas0803/device_geolocation)):

| Scope                                                | Coverage  |
| ---------------------------------------------------- | --------- |
| Whole `lib/` (incl. Linux backend)                   | **63.8%** |
| `lib/` excluding the Linux D-Bus backend (\*)        | **89.8%** |

<sup>(\*) The Linux backend (`lib/device_geolocation_linux.dart`) talks to
the GeoClue2 D-Bus service and can only be exercised end-to-end on a real
Linux host with `geoclue-2.0` installed; it is excluded from the headline
coverage number.</sup>

## License

[MIT](LICENSE). Portions inspired by
[`flutter-geolocator`](https://github.com/Baseflow/flutter-geolocator) by
Baseflow.
