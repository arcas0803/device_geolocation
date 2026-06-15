# Changelog

All notable changes to this project are documented in this file. The format is
based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) and this
project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.1.1] - 2026

### Fixed
- iOS build: `Date.timeIntervalSinceEpoch` replaced with `timeIntervalSince1970`
  in the Swift plugin implementation.
- Windows build: updated bundled GoogleTest from `release-1.11.0` to
  `release-1.14.0` to restore compatibility with CMake 4.x.
- Applied `dart format` across the repository so the formatting CI check passes.

## [2.1.0] - 2026

### Added
- `GeospatialAlgorithm` enum to choose between `haversine` and `vincenty`
  distance formulas.
- `DeviceGeolocation.distanceBetweenIsolate()` and
  `DeviceGeolocation.bearingBetweenIsolate()` to run calculations in a separate
  isolate on native platforms. On the web they fall back to the synchronous
  calculation.

### Changed
- `DeviceGeolocation.distanceBetween()` now uses the more accurate Vincenty
  formula by default and accepts an optional `algorithm` parameter.
- Distance calculations now normalize longitude deltas to the shortest arc,
  improving accuracy across the antimeridian.

## [2.0.0] - 2026

### Added
- `DeviceGeolocation.configure(DeviceLocationSettings)` to set default location
  settings for all subsequent `getCurrentPosition()` and `getPositionStream()`
  calls. Explicit `deviceLocationSettings` still override the configured values.
- `DeviceGeolocation.getPermissionStream()` emits permission status changes.
  The web implementation uses the Permissions API natively; iOS and macOS use
  a native `permissionUpdates` event channel; Android and Linux fall back to
  polling.
- `DeviceGeolocation.openAppSettings()` and `openLocationSettings()` now accept
  an optional `DeviceGeolocationSettingsCallback` that is invoked when the user
  returns to the app with the current service status and permission.
- `DeviceGeolocation.settingsOpenedStream` emits `true` when a settings panel
  is opened and `false` when the app returns to the foreground.
- Native checks on Android, iOS and macOS that detect missing location
  permission declarations (`AndroidManifest.xml` / `Info.plist`) and throw
  `PermissionDefinitionsNotFoundException` with detailed English instructions.

### Changed
- **Breaking:** renamed public types to use the `Device` prefix:
  - `LocationPermission` → `DeviceLocationPermission`
  - `LocationAccuracy` → `DeviceLocationAccuracy`
  - `LocationAccuracyStatus` → `DeviceLocationAccuracyStatus`
  - `ServiceStatus` → `DeviceLocationServiceStatus`
  - `LocationSettings` → `DeviceLocationSettings`
  - `Position` → `DevicePosition`
- `getCurrentPosition()` and `getPositionStream()` now take
  `DeviceLocationSettings? deviceLocationSettings` instead of `locationSettings`.

### Removed
- **Breaking:** removed `DeviceGeolocation.getLastKnownPosition()` and the
  `forceAndroidLocationManager` parameter from the public API.

## [1.1.0] - 2026

### Added
- Android: `ForegroundNotificationConfig` (with `AndroidResource`) and the
  new `AndroidSettings.foregroundNotificationConfig` field. When supplied to
  `DeviceGeolocation.getPositionStream`, the plugin runs a
  `FOREGROUND_SERVICE_TYPE_LOCATION` service so location updates keep
  flowing while the app is backgrounded.
- Android: bundled `DeviceGeolocationForegroundService` (declared in the
  plugin's `AndroidManifest.xml`) with optional `WAKE_LOCK` /
  high-performance `WifiLock` retention, customizable notification (title,
  text, channel name, icon, color, ongoing flag), multi-engine support
  (service is shared across Flutter engines and stops only when the last
  subscription ends), and runtime detection of the host app's
  `FOREGROUND_SERVICE_LOCATION` permission on Android 14+.
- The foreground service reuses the existing GMS/non-GMS detection
  (`FusedLocationProviderClient` when Google Play services are available,
  fallback to `LocationManager` otherwise) and honours
  `AndroidSettings.forceLocationManager`.
- Testing: `DeviceGeolocationMock.lastForegroundNotificationConfig` getter
  to assert the configuration carried by the last stream subscription.

## [1.0.2] - 2026

### Fixed
- Windows: apply `cxx_std_20`, `/await` and the `WindowsApp` link to the
  `${TEST_RUNNER}` target in `windows/CMakeLists.txt`. The unit-test
  executable recompiles the plugin sources (which use `co_await` /
  WinRT C++/coroutines) and was inheriting C++17 from Flutter's default
  settings, breaking the example's Windows build on CI.

## [1.0.1] - 2026

### Changed
- CI/CD: aligned the `publish.yaml` workflow with the shared team template
  (OIDC trusted publishing via `id-token: write`, version-vs-tag verification
  step, `flutter pub get` + `flutter test` gate before publishing).

## [1.0.0] - 2025

### Added
- Linux support via the GeoClue2 D-Bus service (Dart-only implementation,
  registered through `dartPluginClass`).
- iOS 17+ and macOS 14+ streaming via `CLLocationUpdate.liveUpdates` with a
  delegate-based fallback for older OS versions.
- Two-stage Android runtime permission flow: `requestPermission()` accepts a
  `requestBackground` flag and, when granted while-in-use first, chains the
  background permission request on Android 10+ (`Q`).
- Privacy manifests (`PrivacyInfo.xcprivacy`) are now bundled on iOS and macOS.
- `topics`, `homepage`, `repository` and `issue_tracker` in `pubspec.yaml`.

### Changed
- Bumped plugin to **1.0.0** and re-namespaced the Android implementation to
  `com.arcas0803.device_geolocation`.
- iOS minimum deployment target raised to **14.0**; macOS to **11.0**; Swift
  language version raised to **5.9**.
- Android minimum SDK is **24** (Android 7.0); `compileSdk` 36, AGP 9.0.1,
  Kotlin 2.3.20, Play Services Location 21.3.0.
- Windows plugin compiles with **C++20** and uses WinRT C++/coroutines
  (`co_await`, `winrt::fire_and_forget`); event-sink callbacks are now
  marshalled onto the platform thread via `DispatcherQueue`.
- Web implementation migrated to `package:web` + `dart:js_interop` and now
  validates the page is served from a secure context before requesting a
  position.
- Replaced deprecated `CLLocationManager.authorizationStatus()` with the
  instance property and adopted `locationManagerDidChangeAuthorization(_:)`.
- macOS settings deep-link now targets the macOS 13+
  `com.apple.settings.PrivacySecurity.extension` panel with a fallback for
  older versions.

### Removed
- Default `flutter create` scaffolding (boilerplate counter app, `TODO` README,
  empty CHANGELOG, placeholder LICENSE, placeholder podspec/Package.swift
  metadata).
- `getPlatformVersion` method and its tests on every platform.
