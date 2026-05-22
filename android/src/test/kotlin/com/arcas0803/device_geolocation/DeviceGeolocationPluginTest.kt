package com.arcas0803.device_geolocation

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.mockito.Mockito
import kotlin.test.Test

internal class DeviceGeolocationPluginTest {
    @Test
    fun onMethodCall_unknown_method_isNotImplemented() {
        val plugin = DeviceGeolocationPlugin()
        val call = MethodCall("doesNotExist", null)
        val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        plugin.onMethodCall(call, mockResult)
        Mockito.verify(mockResult).notImplemented()
    }
}
