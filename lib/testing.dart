/// Test helpers for `device_geolocation`.
///
/// Import this barrel from your tests to access [DeviceGeolocationMock],
/// an in-memory fake of [DeviceGeolocationPlatform] that lets you control
/// every value returned by the plugin without setting up mock method
/// channels.
library;

export 'device_geolocation_platform_interface.dart'
    show DeviceGeolocationPlatform;
export 'src/testing/device_geolocation_mock.dart';
