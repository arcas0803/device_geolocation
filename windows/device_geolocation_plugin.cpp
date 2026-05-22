#include "device_geolocation_plugin.h"

#include <windows.h>
#include <shellapi.h>

#include <flutter/event_channel.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <winrt/Windows.Devices.Geolocation.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.System.h>

#include <chrono>
#include <memory>
#include <utility>

namespace device_geolocation {

using flutter::EncodableMap;
using flutter::EncodableValue;
using winrt::Windows::Devices::Geolocation::BasicGeoposition;
using winrt::Windows::Devices::Geolocation::GeolocationAccessStatus;
using winrt::Windows::Devices::Geolocation::Geolocator;
using winrt::Windows::Devices::Geolocation::Geoposition;
using winrt::Windows::Devices::Geolocation::PositionAccuracy;
using winrt::Windows::Devices::Geolocation::PositionStatus;
using winrt::Windows::System::DispatcherQueue;

namespace {

EncodableValue PositionToMap(const Geoposition& position) {
  auto coord = position.Coordinate();
  auto point = coord.Point();
  auto basic = point.Position();
  EncodableMap map;
  map[EncodableValue("latitude")] = EncodableValue(basic.Latitude);
  map[EncodableValue("longitude")] = EncodableValue(basic.Longitude);
  map[EncodableValue("altitude")] = EncodableValue(basic.Altitude);
  map[EncodableValue("accuracy")] = EncodableValue(coord.Accuracy());
  auto altAcc = coord.AltitudeAccuracy();
  map[EncodableValue("altitude_accuracy")] =
      EncodableValue(altAcc ? altAcc.Value() : 0.0);
  auto heading = coord.Heading();
  map[EncodableValue("heading")] =
      EncodableValue(heading ? heading.Value() : 0.0);
  map[EncodableValue("heading_accuracy")] = EncodableValue(0.0);
  auto speed = coord.Speed();
  map[EncodableValue("speed")] = EncodableValue(speed ? speed.Value() : 0.0);
  map[EncodableValue("speed_accuracy")] = EncodableValue(0.0);
  auto ts = coord.Timestamp();
  auto millis = std::chrono::duration_cast<std::chrono::milliseconds>(
                    ts.time_since_epoch())
                    .count();
  map[EncodableValue("timestamp")] =
      EncodableValue(static_cast<int64_t>(millis));
  return EncodableValue(map);
}

int AccessStatusIndex(GeolocationAccessStatus status) {
  switch (status) {
    case GeolocationAccessStatus::Allowed:
      return 2;  // whileInUse
    case GeolocationAccessStatus::Denied:
      return 1;  // deniedForever
    case GeolocationAccessStatus::Unspecified:
    default:
      return 0;  // denied
  }
}

}  // namespace

// static
void DeviceGeolocationPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto plugin = std::make_unique<DeviceGeolocationPlugin>();
  auto dispatcher = DispatcherQueue::GetForCurrentThread();
  plugin->SetDispatcherQueue(dispatcher);

  auto method_channel =
      std::make_unique<flutter::MethodChannel<EncodableValue>>(
          registrar->messenger(), "device_geolocation",
          &flutter::StandardMethodCodec::GetInstance());
  method_channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  auto location_channel =
      std::make_unique<flutter::EventChannel<EncodableValue>>(
          registrar->messenger(), "device_geolocation/locationUpdates",
          &flutter::StandardMethodCodec::GetInstance());
  location_channel->SetStreamHandler(
      std::make_unique<flutter::StreamHandlerFunctions<EncodableValue>>(
          [plugin_pointer = plugin.get()](
              const EncodableValue* /*arguments*/,
              std::unique_ptr<flutter::EventSink<EncodableValue>>&& events)
              -> std::unique_ptr<flutter::StreamHandlerError<EncodableValue>> {
            plugin_pointer->OnPositionStreamListen(std::move(events));
            return nullptr;
          },
          [plugin_pointer = plugin.get()](const EncodableValue* /*arguments*/)
              -> std::unique_ptr<flutter::StreamHandlerError<EncodableValue>> {
            plugin_pointer->OnPositionStreamCancel();
            return nullptr;
          }));

  auto service_channel =
      std::make_unique<flutter::EventChannel<EncodableValue>>(
          registrar->messenger(), "device_geolocation/serviceUpdates",
          &flutter::StandardMethodCodec::GetInstance());
  service_channel->SetStreamHandler(
      std::make_unique<flutter::StreamHandlerFunctions<EncodableValue>>(
          [plugin_pointer = plugin.get()](
              const EncodableValue* /*arguments*/,
              std::unique_ptr<flutter::EventSink<EncodableValue>>&& events)
              -> std::unique_ptr<flutter::StreamHandlerError<EncodableValue>> {
            plugin_pointer->OnServiceStreamListen(std::move(events));
            return nullptr;
          },
          [plugin_pointer = plugin.get()](const EncodableValue* /*arguments*/)
              -> std::unique_ptr<flutter::StreamHandlerError<EncodableValue>> {
            plugin_pointer->OnServiceStreamCancel();
            return nullptr;
          }));

  registrar->AddPlugin(std::move(plugin));
}

DeviceGeolocationPlugin::DeviceGeolocationPlugin() {}

DeviceGeolocationPlugin::~DeviceGeolocationPlugin() {
  OnPositionStreamCancel();
  OnServiceStreamCancel();
}

void DeviceGeolocationPlugin::EnsureGeolocator() {
  if (!geolocator_) {
    geolocator_ = Geolocator();
  }
}

namespace {

// Schedule a callback on the captured UI dispatcher (no-op fallback runs inline).
template <typename F>
void DispatchToUi(DispatcherQueue const& dispatcher, F&& fn) {
  if (dispatcher) {
    dispatcher.TryEnqueue([fn = std::forward<F>(fn)]() mutable { fn(); });
  } else {
    fn();
  }
}

winrt::fire_and_forget RequestAccessAsync(
    DispatcherQueue dispatcher,
    std::shared_ptr<flutter::MethodResult<EncodableValue>> result) {
  try {
    auto status = co_await Geolocator::RequestAccessAsync();
    DispatchToUi(dispatcher, [result, status]() {
      result->Success(EncodableValue(AccessStatusIndex(status)));
    });
  } catch (winrt::hresult_error const& e) {
    auto msg = winrt::to_string(e.message());
    DispatchToUi(dispatcher, [result, msg]() {
      result->Error("PERMISSION_DENIED", msg);
    });
  }
}

winrt::fire_and_forget GetPositionAsync(
    Geolocator geolocator, DispatcherQueue dispatcher,
    std::shared_ptr<flutter::MethodResult<EncodableValue>> result) {
  try {
    auto pos = co_await geolocator.GetGeopositionAsync();
    DispatchToUi(dispatcher, [result, pos]() {
      result->Success(PositionToMap(pos));
    });
  } catch (winrt::hresult_error const& e) {
    auto msg = winrt::to_string(e.message());
    DispatchToUi(dispatcher, [result, msg]() {
      result->Error("POSITION_UNAVAILABLE", msg);
    });
  }
}

}  // namespace

void DeviceGeolocationPlugin::HandleMethodCall(
    const flutter::MethodCall<EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
  const auto& method = method_call.method_name();

  if (method == "checkPermission" || method == "requestPermission") {
    auto shared_result =
        std::shared_ptr<flutter::MethodResult<EncodableValue>>(result.release());
    RequestAccessAsync(dispatcher_queue_, shared_result);
    return;
  }

  if (method == "isLocationServiceEnabled") {
    try {
      EnsureGeolocator();
      auto status = geolocator_.LocationStatus();
      bool enabled = status != PositionStatus::Disabled &&
                     status != PositionStatus::NotAvailable;
      result->Success(EncodableValue(enabled));
    } catch (winrt::hresult_error const&) {
      result->Success(EncodableValue(false));
    }
    return;
  }

  if (method == "getLastKnownPosition" || method == "getCurrentPosition") {
    try {
      EnsureGeolocator();
      auto shared_result = std::shared_ptr<flutter::MethodResult<EncodableValue>>(
          result.release());
      GetPositionAsync(geolocator_, dispatcher_queue_, shared_result);
    } catch (winrt::hresult_error const& e) {
      result->Error("POSITION_UNAVAILABLE", winrt::to_string(e.message()));
    }
    return;
  }

  if (method == "openAppSettings" || method == "openLocationSettings") {
    HINSTANCE rc =
        ShellExecuteW(nullptr, L"open", L"ms-settings:privacy-location",
                      nullptr, nullptr, SW_SHOWNORMAL);
    bool ok = reinterpret_cast<INT_PTR>(rc) > 32;
    result->Success(EncodableValue(ok));
    return;
  }

  if (method == "getLocationAccuracy") {
    result->Success(EncodableValue(1));  // precise
    return;
  }

  if (method == "requestTemporaryFullAccuracy") {
    result->Success(EncodableValue(1));
    return;
  }

  result->NotImplemented();
}

void DeviceGeolocationPlugin::OnPositionStreamListen(
    std::unique_ptr<flutter::EventSink<EncodableValue>> sink) {
  std::lock_guard<std::mutex> lock(mutex_);
  try {
    EnsureGeolocator();
  } catch (winrt::hresult_error const&) {
    return;
  }
  position_sink_ = std::shared_ptr<flutter::EventSink<EncodableValue>>(
      sink.release());
  auto sink_weak = std::weak_ptr<flutter::EventSink<EncodableValue>>(position_sink_);
  auto dispatcher = dispatcher_queue_;
  position_token_ = geolocator_.PositionChanged(
      [sink_weak, dispatcher](
          Geolocator const&,
          winrt::Windows::Devices::Geolocation::PositionChangedEventArgs const&
              args) {
        auto position = args.Position();
        auto payload = PositionToMap(position);
        DispatchToUi(dispatcher, [sink_weak, payload]() {
          if (auto s = sink_weak.lock()) {
            s->Success(payload);
          }
        });
      });
}

void DeviceGeolocationPlugin::OnPositionStreamCancel() {
  std::lock_guard<std::mutex> lock(mutex_);
  if (geolocator_ && position_token_.value != 0) {
    geolocator_.PositionChanged(position_token_);
    position_token_ = {};
  }
  position_sink_.reset();
}

void DeviceGeolocationPlugin::OnServiceStreamListen(
    std::unique_ptr<flutter::EventSink<EncodableValue>> sink) {
  std::lock_guard<std::mutex> lock(mutex_);
  try {
    EnsureGeolocator();
  } catch (winrt::hresult_error const&) {
    return;
  }
  service_sink_ = std::shared_ptr<flutter::EventSink<EncodableValue>>(
      sink.release());
  auto sink_weak = std::weak_ptr<flutter::EventSink<EncodableValue>>(service_sink_);
  auto dispatcher = dispatcher_queue_;
  status_token_ = geolocator_.StatusChanged(
      [sink_weak, dispatcher](
          Geolocator const&,
          winrt::Windows::Devices::Geolocation::StatusChangedEventArgs const& args) {
        bool enabled = args.Status() != PositionStatus::Disabled &&
                       args.Status() != PositionStatus::NotAvailable;
        DispatchToUi(dispatcher, [sink_weak, enabled]() {
          if (auto s = sink_weak.lock()) {
            s->Success(EncodableValue(enabled ? 1 : 0));
          }
        });
      });
}

void DeviceGeolocationPlugin::OnServiceStreamCancel() {
  std::lock_guard<std::mutex> lock(mutex_);
  if (geolocator_ && status_token_.value != 0) {
    geolocator_.StatusChanged(status_token_);
    status_token_ = {};
  }
  service_sink_.reset();
}

}  // namespace device_geolocation
