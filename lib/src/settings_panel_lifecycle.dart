import 'dart:async';

import 'package:flutter/widgets.dart';

import '../device_geolocation_platform_interface.dart';
import 'enums/enums.dart';

/// Helper that observes application lifecycle changes to detect when the user
/// returns from a system settings screen opened by this plugin.
class SettingsPanelLifecycle with WidgetsBindingObserver {
  SettingsPanelLifecycle._();

  static final SettingsPanelLifecycle _instance = SettingsPanelLifecycle._();

  /// Shared lifecycle observer used by platform implementations.
  static SettingsPanelLifecycle get instance => _instance;

  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  DeviceGeolocationSettingsCallback? _callback;
  var _settingsOpened = false;
  var _initialized = false;

  /// Stream that emits `true` when a settings panel is opened and `false` when
  /// the app returns to the foreground.
  Stream<bool> get stream => _controller.stream;

  /// Registers the observer with the widget binding if it has not been done
  /// already.
  void _ensureInitialized() {
    if (_initialized) return;
    _initialized = true;
    WidgetsBinding.instance.addObserver(this);
  }

  /// Called by platform implementations when a settings panel is opened.
  void notifySettingsOpened({DeviceGeolocationSettingsCallback? callback}) {
    _ensureInitialized();
    _callback = callback;
    _settingsOpened = true;
    _controller.add(true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _settingsOpened) {
      _settingsOpened = false;
      _controller.add(false);
      _invokeCallback();
    }
  }

  void _invokeCallback() {
    final callback = _callback;
    _callback = null;
    if (callback == null) return;

    Future.wait([
      DeviceGeolocationPlatform.instance.isLocationServiceEnabled(),
      DeviceGeolocationPlatform.instance.checkPermission(),
    ]).then((values) {
      final serviceStatus = values[0] as bool
          ? DeviceLocationServiceStatus.enabled
          : DeviceLocationServiceStatus.disabled;
      final permission = values[1] as DeviceLocationPermission;
      callback(serviceStatus, permission);
    });
  }

  /// Disposes the lifecycle observer. Intended for tests.
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _initialized = false;
    _settingsOpened = false;
    _callback = null;
  }
}
