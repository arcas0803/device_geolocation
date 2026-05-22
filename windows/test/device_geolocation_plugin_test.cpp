#include <flutter/method_call.h>
#include <flutter/method_result_functions.h>
#include <flutter/standard_method_codec.h>
#include <gtest/gtest.h>
#include <windows.h>

#include <memory>
#include <string>
#include <variant>

#include "device_geolocation_plugin.h"

namespace device_geolocation {
namespace test {

using flutter::EncodableMap;
using flutter::EncodableValue;
using flutter::MethodCall;
using flutter::MethodResultFunctions;

TEST(DeviceGeolocationPlugin, UnknownMethodIsNotImplemented) {
  DeviceGeolocationPlugin plugin;
  bool not_implemented = false;
  plugin.HandleMethodCall(
      MethodCall("doesNotExist", std::make_unique<EncodableValue>()),
      std::make_unique<MethodResultFunctions<>>(
          nullptr, nullptr,
          [&not_implemented]() { not_implemented = true; }));
  EXPECT_TRUE(not_implemented);
}

}  // namespace test
}  // namespace device_geolocation
