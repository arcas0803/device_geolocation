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

- One-shot, last-known and streaming positions.
- Permission lifecycle (`checkPermission`, `requestPermission`) with optional
  Android background-location escalation.
- Service-status stream for OS-level location toggles.
- iOS 14+ temporary full-accuracy requests.
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
| `getLastKnownPosition`                 | ✅ | ✅ | ✅ | —⁴ | ✅ | ✅ |
| `getCurrentPosition`                   | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `getPositionStream`                    | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `getServiceStatusStream`               | ✅ | ✅ | ✅ | —⁵ | ✅ | ✅ |
| `getLocationAccuracy`                  | ✅ | ✅ | ✅ | ✅⁶ | ✅⁶ | ✅⁶ |
| `requestTemporaryFullAccuracy`         | —⁷ | ✅ | ✅ | —⁷ | —⁷ | —⁷ |
| `openAppSettings` / `openLocationSettings` | ✅ | ✅ | ✅ | —⁸ | ✅ | ✅ |
| Distance / bearing helpers             | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

<sup>¹ Uses the browser Permissions API where available; falls back to
`whileInUse` after a successful position fix.<br>
² Linux exposes a single `whileInUse`-like permission once the GeoClue
agent has approved the app.<br>
³ iOS `Always` authorization (use `NSLocationAlwaysAndWhenInUseUsageDescription`).<br>
⁴ The browser Geolocation API does not expose a cached last position; this
returns `null`.<br>
⁵ The browser does not expose a service-status event; the stream emits the
initial status and stays open.<br>
⁶ Always reports `precise` (or `unknown` if permission is denied) because
the platform does not differentiate reduced vs. precise modes.<br>
⁷ Temporary full-accuracy is an iOS/macOS-only concept; the call is a no-op
that returns the current accuracy on other platforms.<br>
⁸ Browsers do not allow programmatic navigation to permission settings;
the call returns `false`.</sup>

## Install

```yaml
dependencies:
  device_geolocation: ^1.0.0
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
  if (!await DeviceGeolocation.isLocationServiceEnabled()) {
    await DeviceGeolocation.openLocationSettings();
    return;
  }

  var permission = await DeviceGeolocation.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await DeviceGeolocation.requestPermission();
  }
  if (permission == LocationPermission.deniedForever) {
    await DeviceGeolocation.openAppSettings();
    return;
  }

  final position = await DeviceGeolocation.getCurrentPosition(
    locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
  );
  print('${position.latitude}, ${position.longitude}');
}
```

### Streaming positions

```dart
final subscription = DeviceGeolocation.getPositionStream(
  locationSettings: const LocationSettings(
    accuracy: LocationAccuracy.high,
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
final meters = DeviceGeolocation.distanceBetween(
    52.2165157, 6.9437819, 52.3546274, 4.8285838);
final bearing = DeviceGeolocation.bearingBetween(
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

## API reference

| Member                                                          | Returns                            |
| --------------------------------------------------------------- | ---------------------------------- |
| `DeviceGeolocation.checkPermission()`                           | `Future<LocationPermission>`       |
| `DeviceGeolocation.requestPermission({requestBackground})`      | `Future<LocationPermission>`       |
| `DeviceGeolocation.isLocationServiceEnabled()`                  | `Future<bool>`                     |
| `DeviceGeolocation.getLastKnownPosition({forceLocationManager})`| `Future<Position?>`                |
| `DeviceGeolocation.getCurrentPosition({locationSettings})`      | `Future<Position>`                 |
| `DeviceGeolocation.getPositionStream({locationSettings})`       | `Stream<Position>`                 |
| `DeviceGeolocation.getServiceStatusStream()`                    | `Stream<ServiceStatus>`            |
| `DeviceGeolocation.getLocationAccuracy()`                       | `Future<LocationAccuracyStatus>`   |
| `DeviceGeolocation.requestTemporaryFullAccuracy({purposeKey})`  | `Future<LocationAccuracyStatus>`   |
| `DeviceGeolocation.openAppSettings()`                           | `Future<bool>`                     |
| `DeviceGeolocation.openLocationSettings()`                      | `Future<bool>`                     |
| `DeviceGeolocation.distanceBetween(lat1, lon1, lat2, lon2)`     | `double` (meters)                  |
| `DeviceGeolocation.bearingBetween(lat1, lon1, lat2, lon2)`      | `double` (degrees)                 |

## Migration from `flutter-geolocator`

| `geolocator`                                | `device_geolocation`                                       |
| ------------------------------------------- | ---------------------------------------------------------- |
| `Geolocator.checkPermission()`              | `DeviceGeolocation.checkPermission()`                      |
| `Geolocator.requestPermission()`            | `DeviceGeolocation.requestPermission()`                    |
| `Geolocator.isLocationServiceEnabled()`     | `DeviceGeolocation.isLocationServiceEnabled()`             |
| `Geolocator.getLastKnownPosition()`         | `DeviceGeolocation.getLastKnownPosition()`                 |
| `Geolocator.getCurrentPosition()`           | `DeviceGeolocation.getCurrentPosition()`                   |
| `Geolocator.getPositionStream()`            | `DeviceGeolocation.getPositionStream()`                    |
| `Geolocator.openAppSettings()`              | `DeviceGeolocation.openAppSettings()`                      |
| `Geolocator.openLocationSettings()`         | `DeviceGeolocation.openLocationSettings()`                 |
| `Geolocator.distanceBetween(...)`           | `DeviceGeolocation.distanceBetween(...)`                   |
| `Geolocator.bearingBetween(...)`            | `DeviceGeolocation.bearingBetween(...)`                    |

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
    mock.permission = LocationPermission.deniedForever;
    expect(
      await DeviceGeolocation.checkPermission(),
      LocationPermission.deniedForever,
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

The mock also exposes `lastRequestedBackground`, `lastForcedLocationManager`,
`lastLocationSettings` and `lastPurposeKey` for assertions, plus an async
`reset()` to clear state and close stream controllers between tests.

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
