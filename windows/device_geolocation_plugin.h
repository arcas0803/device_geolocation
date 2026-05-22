#ifndef FLUTTER_PLUGIN_DEVICE_GEOLOCATION_PLUGIN_H_
#define FLUTTER_PLUGIN_DEVICE_GEOLOCATION_PLUGIN_H_

#include <flutter/event_channel.h>
#include <flutter/event_sink.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <winrt/Windows.Devices.Geolocation.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.System.h>

#include <memory>
#include <mutex>

namespace device_geolocation {

class DeviceGeolocationPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  DeviceGeolocationPlugin();
  virtual ~DeviceGeolocationPlugin();

  DeviceGeolocationPlugin(const DeviceGeolocationPlugin&) = delete;
  DeviceGeolocationPlugin& operator=(const DeviceGeolocationPlugin&) = delete;

  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void OnPositionStreamListen(
      std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> sink);
  void OnPositionStreamCancel();
  void OnServiceStreamListen(
      std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> sink);
  void OnServiceStreamCancel();

  void SetDispatcherQueue(winrt::Windows::System::DispatcherQueue queue) {
    dispatcher_queue_ = queue;
  }

 private:
  winrt::Windows::Devices::Geolocation::Geolocator geolocator_{nullptr};
  std::shared_ptr<flutter::EventSink<flutter::EncodableValue>> position_sink_;
  std::shared_ptr<flutter::EventSink<flutter::EncodableValue>> service_sink_;
  winrt::event_token position_token_{};
  winrt::event_token status_token_{};
  std::mutex mutex_;
  winrt::Windows::System::DispatcherQueue dispatcher_queue_{nullptr};

  void EnsureGeolocator();
};

}  // namespace device_geolocation

#endif  // FLUTTER_PLUGIN_DEVICE_GEOLOCATION_PLUGIN_H_
