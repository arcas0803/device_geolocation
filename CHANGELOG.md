# Changelog

All notable changes to this project are documented in this file. The format is
based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) and this
project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
