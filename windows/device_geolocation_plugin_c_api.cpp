#include "include/device_geolocation/device_geolocation_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "device_geolocation_plugin.h"

void DeviceGeolocationPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  device_geolocation::DeviceGeolocationPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
