package com.arcas0803.device_geolocation

import android.Manifest
import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Looper
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailability
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry

private const val PERMISSION_REQUEST_CODE = 0x2701
private const val BACKGROUND_PERMISSION_REQUEST_CODE = 0x2702

class DeviceGeolocationPlugin :
    FlutterPlugin,
    MethodCallHandler,
    ActivityAware,
    PluginRegistry.RequestPermissionsResultListener {

    private lateinit var context: Context
    private lateinit var methodChannel: MethodChannel
    private lateinit var locationUpdatesChannel: EventChannel
    private lateinit var serviceUpdatesChannel: EventChannel

    private var activity: Activity? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var pendingPermissionResult: Result? = null
    private var pendingRequestBackground: Boolean = false

    private var strategy: LocationStrategy? = null

    private val locationStreamHandler = LocationStreamHandler { strategy }
    private val serviceStreamHandler = ServiceStreamHandler()

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        strategy = createStrategy(context)

        methodChannel = MethodChannel(binding.binaryMessenger, "device_geolocation")
        methodChannel.setMethodCallHandler(this)

        locationUpdatesChannel = EventChannel(
            binding.binaryMessenger,
            "device_geolocation/locationUpdates",
        )
        locationUpdatesChannel.setStreamHandler(locationStreamHandler)

        serviceUpdatesChannel = EventChannel(
            binding.binaryMessenger,
            "device_geolocation/serviceUpdates",
        )
        serviceUpdatesChannel.setStreamHandler(serviceStreamHandler)

        serviceStreamHandler.attach(context)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        locationUpdatesChannel.setStreamHandler(null)
        serviceUpdatesChannel.setStreamHandler(null)
        serviceStreamHandler.detach()
        strategy = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        onAttachedToActivity(binding)

    override fun onDetachedFromActivity() {
        activityBinding?.removeRequestPermissionsResultListener(this)
        activityBinding = null
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "checkPermission" -> result.success(currentPermissionIndex())
            "requestPermission" -> {
                val requestBackground = call.argument<Boolean>("requestBackground") ?: false
                requestPermission(result, requestBackground)
            }
            "isLocationServiceEnabled" -> result.success(isLocationServiceEnabled())
            "getLastKnownPosition" -> {
                val forceLM = call.argument<Boolean>("forceLocationManager") ?: false
                getLastKnownPosition(result, forceLM)
            }
            "getCurrentPosition" -> getCurrentPosition(call, result)
            "openAppSettings" -> result.success(openAppSettings())
            "openLocationSettings" -> result.success(openLocationSettings())
            "getLocationAccuracy" -> result.success(getLocationAccuracyIndex())
            "requestTemporaryFullAccuracy" -> result.success(getLocationAccuracyIndex())
            else -> result.notImplemented()
        }
    }

    private fun hasPermission(name: String): Boolean =
        ContextCompat.checkSelfPermission(context, name) == PackageManager.PERMISSION_GRANTED

    private fun currentPermissionIndex(): Int {
        val fine = hasPermission(Manifest.permission.ACCESS_FINE_LOCATION)
        val coarse = hasPermission(Manifest.permission.ACCESS_COARSE_LOCATION)
        val background = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            hasPermission(Manifest.permission.ACCESS_BACKGROUND_LOCATION)
        } else fine || coarse
        return when {
            (fine || coarse) && background -> LocationPermissionIndex.ALWAYS
            fine || coarse -> LocationPermissionIndex.WHILE_IN_USE
            else -> LocationPermissionIndex.DENIED
        }
    }

    private fun requestPermission(result: Result, requestBackground: Boolean) {
        val current = currentPermissionIndex()
        val alreadySufficient =
            (current == LocationPermissionIndex.ALWAYS) ||
                (current == LocationPermissionIndex.WHILE_IN_USE && !requestBackground)
        if (alreadySufficient) {
            result.success(current)
            return
        }
        val act = activity ?: run {
            result.error("MISSING_ACTIVITY", "No attached Activity.", null)
            return
        }
        if (pendingPermissionResult != null) {
            result.error(
                "PERMISSION_REQUEST_IN_PROGRESS",
                "A permission request is already in progress.",
                null,
            )
            return
        }
        pendingPermissionResult = result
        pendingRequestBackground = requestBackground

        // Stage 1: foreground only (Android 10+ requires asking for ACCESS_BACKGROUND_LOCATION
        // in a separate prompt after the foreground permission was granted).
        if (current == LocationPermissionIndex.WHILE_IN_USE && requestBackground &&
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q
        ) {
            ActivityCompat.requestPermissions(
                act,
                arrayOf(Manifest.permission.ACCESS_BACKGROUND_LOCATION),
                BACKGROUND_PERMISSION_REQUEST_CODE,
            )
            return
        }

        ActivityCompat.requestPermissions(
            act,
            arrayOf(
                Manifest.permission.ACCESS_FINE_LOCATION,
                Manifest.permission.ACCESS_COARSE_LOCATION,
            ),
            PERMISSION_REQUEST_CODE,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != PERMISSION_REQUEST_CODE &&
            requestCode != BACKGROUND_PERMISSION_REQUEST_CODE
        ) return false
        val pending = pendingPermissionResult ?: return false

        val foregroundGranted = grantResults.isNotEmpty() &&
            grantResults.any { it == PackageManager.PERMISSION_GRANTED }

        if (requestCode == PERMISSION_REQUEST_CODE &&
            foregroundGranted &&
            pendingRequestBackground &&
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
            !hasPermission(Manifest.permission.ACCESS_BACKGROUND_LOCATION)
        ) {
            val act = activity
            if (act != null) {
                ActivityCompat.requestPermissions(
                    act,
                    arrayOf(Manifest.permission.ACCESS_BACKGROUND_LOCATION),
                    BACKGROUND_PERMISSION_REQUEST_CODE,
                )
                return true
            }
        }

        pendingPermissionResult = null
        pendingRequestBackground = false
        pending.success(currentPermissionIndex())
        return true
    }

    private fun isLocationServiceEnabled(): Boolean {
        val lm = context.getSystemService(Context.LOCATION_SERVICE) as? LocationManager
            ?: return false
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) lm.isLocationEnabled
        else lm.isProviderEnabled(LocationManager.GPS_PROVIDER) ||
            lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
    }

    private fun ensurePermissionsOrFail(result: Result): Boolean {
        if (!hasPermission(Manifest.permission.ACCESS_FINE_LOCATION) &&
            !hasPermission(Manifest.permission.ACCESS_COARSE_LOCATION)
        ) {
            result.error("PERMISSION_DENIED", "Location permission denied.", null)
            return false
        }
        if (!isLocationServiceEnabled()) {
            result.error(
                "LOCATION_SERVICES_DISABLED",
                "Location services are disabled.",
                null,
            )
            return false
        }
        return true
    }

    private fun getLastKnownPosition(result: Result, forceLocationManager: Boolean) {
        if (!ensurePermissionsOrFail(result)) return
        val str = strategyFor(forceLocationManager) ?: run {
            result.error("POSITION_UNAVAILABLE", "Location services unavailable.", null)
            return
        }
        try {
            str.getLastKnownPosition(
                onResult = { loc -> result.success(loc?.let(::locationToMap)) },
                onError = { msg -> result.error("POSITION_UNAVAILABLE", msg, null) },
            )
        } catch (e: SecurityException) {
            result.error("PERMISSION_DENIED", e.localizedMessage, null)
        }
    }

    private fun getCurrentPosition(call: MethodCall, result: Result) {
        if (!ensurePermissionsOrFail(result)) return
        val forceLM = call.argument<Boolean>("forceLocationManager") ?: false
        val str = strategyFor(forceLM) ?: run {
            result.error("POSITION_UNAVAILABLE", "Location services unavailable.", null)
            return
        }
        val accuracy = (call.argument<Int>("accuracy") ?: 4)
        try {
            str.getCurrentPosition(
                accuracyIndex = accuracy,
                onResult = { loc ->
                    if (loc == null) {
                        result.error("POSITION_UNAVAILABLE", "No location returned.", null)
                    } else {
                        result.success(locationToMap(loc))
                    }
                },
                onError = { msg -> result.error("POSITION_UNAVAILABLE", msg, null) },
            )
        } catch (e: SecurityException) {
            result.error("PERMISSION_DENIED", e.localizedMessage, null)
        }
    }

    private fun strategyFor(forceLocationManager: Boolean): LocationStrategy? =
        if (forceLocationManager) LocationManagerStrategy(context) else strategy

    private fun openAppSettings(): Boolean = try {
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.fromParts("package", context.packageName, null)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(intent)
        true
    } catch (_: Throwable) {
        false
    }

    private fun openLocationSettings(): Boolean = try {
        val intent = Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(intent)
        true
    } catch (_: Throwable) {
        false
    }

    private fun getLocationAccuracyIndex(): Int {
        val fine = hasPermission(Manifest.permission.ACCESS_FINE_LOCATION)
        val coarse = hasPermission(Manifest.permission.ACCESS_COARSE_LOCATION)
        return when {
            fine -> 1
            coarse -> 0
            else -> 2
        }
    }
}

internal object LocationPermissionIndex {
    const val DENIED = 0
    const val DENIED_FOREVER = 1
    const val WHILE_IN_USE = 2
    const val ALWAYS = 3
    const val UNABLE_TO_DETERMINE = 4
}

internal fun priorityFor(accuracyIndex: Int): Int = when (accuracyIndex) {
    0 -> Priority.PRIORITY_PASSIVE
    1 -> Priority.PRIORITY_LOW_POWER
    2 -> Priority.PRIORITY_BALANCED_POWER_ACCURACY
    3, 4, 5 -> Priority.PRIORITY_HIGH_ACCURACY
    6 -> Priority.PRIORITY_PASSIVE
    else -> Priority.PRIORITY_HIGH_ACCURACY
}

internal fun locationToMap(location: Location): Map<String, Any?> {
    val map = HashMap<String, Any?>()
    map["latitude"] = location.latitude
    map["longitude"] = location.longitude
    map["timestamp"] = location.time
    map["accuracy"] = location.accuracy.toDouble()
    map["altitude"] = location.altitude
    map["heading"] = location.bearing.toDouble()
    map["speed"] = location.speed.toDouble()
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        map["altitude_accuracy"] = location.verticalAccuracyMeters.toDouble()
        map["heading_accuracy"] = location.bearingAccuracyDegrees.toDouble()
        map["speed_accuracy"] = location.speedAccuracyMetersPerSecond.toDouble()
    } else {
        map["altitude_accuracy"] = 0.0
        map["heading_accuracy"] = 0.0
        map["speed_accuracy"] = 0.0
    }
    map["is_mocked"] = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
        location.isMock else @Suppress("DEPRECATION") location.isFromMockProvider
    return map
}

internal fun createStrategy(context: Context): LocationStrategy {
    val availability = GoogleApiAvailability.getInstance()
        .isGooglePlayServicesAvailable(context)
    return if (availability == ConnectionResult.SUCCESS) {
        FusedLocationStrategy(context)
    } else {
        LocationManagerStrategy(context)
    }
}

internal interface LocationStrategy {
    fun getLastKnownPosition(
        onResult: (Location?) -> Unit,
        onError: (String?) -> Unit,
    )

    fun getCurrentPosition(
        accuracyIndex: Int,
        onResult: (Location?) -> Unit,
        onError: (String?) -> Unit,
    )

    fun startUpdates(
        accuracyIndex: Int,
        intervalMs: Long,
        minDistanceMeters: Float,
        onLocation: (Location) -> Unit,
        onError: (String?) -> Unit,
    ): AutoCloseable
}

internal class FusedLocationStrategy(context: Context) : LocationStrategy {
    private val client: FusedLocationProviderClient =
        LocationServices.getFusedLocationProviderClient(context)

    override fun getLastKnownPosition(
        onResult: (Location?) -> Unit,
        onError: (String?) -> Unit,
    ) {
        client.lastLocation
            .addOnSuccessListener { onResult(it) }
            .addOnFailureListener { onError(it.localizedMessage) }
    }

    override fun getCurrentPosition(
        accuracyIndex: Int,
        onResult: (Location?) -> Unit,
        onError: (String?) -> Unit,
    ) {
        client.getCurrentLocation(priorityFor(accuracyIndex), null)
            .addOnSuccessListener { onResult(it) }
            .addOnFailureListener { onError(it.localizedMessage) }
    }

    override fun startUpdates(
        accuracyIndex: Int,
        intervalMs: Long,
        minDistanceMeters: Float,
        onLocation: (Location) -> Unit,
        onError: (String?) -> Unit,
    ): AutoCloseable {
        val request = LocationRequest.Builder(priorityFor(accuracyIndex), intervalMs)
            .setMinUpdateDistanceMeters(minDistanceMeters)
            .build()
        val cb = object : LocationCallback() {
            override fun onLocationResult(result: LocationResult) {
                result.lastLocation?.let(onLocation)
            }
        }
        return try {
            client.requestLocationUpdates(request, cb, Looper.getMainLooper())
            AutoCloseable { client.removeLocationUpdates(cb) }
        } catch (e: SecurityException) {
            onError(e.localizedMessage)
            AutoCloseable {}
        }
    }
}

internal class LocationManagerStrategy(context: Context) : LocationStrategy {
    private val lm: LocationManager =
        context.getSystemService(Context.LOCATION_SERVICE) as LocationManager

    private fun bestProvider(accuracyIndex: Int): String {
        val highAccuracy = accuracyIndex >= 3
        return when {
            highAccuracy && lm.isProviderEnabled(LocationManager.GPS_PROVIDER) ->
                LocationManager.GPS_PROVIDER
            lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER) ->
                LocationManager.NETWORK_PROVIDER
            lm.isProviderEnabled(LocationManager.GPS_PROVIDER) ->
                LocationManager.GPS_PROVIDER
            else -> LocationManager.PASSIVE_PROVIDER
        }
    }

    override fun getLastKnownPosition(
        onResult: (Location?) -> Unit,
        onError: (String?) -> Unit,
    ) {
        val providers = lm.getProviders(true)
        var best: Location? = null
        for (p in providers) {
            val l = try { lm.getLastKnownLocation(p) } catch (_: SecurityException) { null }
            if (l != null && (best == null || l.accuracy < best.accuracy)) best = l
        }
        onResult(best)
    }

    override fun getCurrentPosition(
        accuracyIndex: Int,
        onResult: (Location?) -> Unit,
        onError: (String?) -> Unit,
    ) {
        val provider = bestProvider(accuracyIndex)
        val listener = object : LocationListener {
            var delivered = false
            override fun onLocationChanged(location: Location) {
                if (delivered) return
                delivered = true
                lm.removeUpdates(this)
                onResult(location)
            }
            override fun onProviderEnabled(p: String) {}
            override fun onProviderDisabled(p: String) {}
            @Deprecated("Required by older API levels")
            override fun onStatusChanged(p: String?, status: Int, extras: Bundle?) {}
        }
        try {
            @Suppress("DEPRECATION")
            lm.requestSingleUpdate(provider, listener, Looper.getMainLooper())
        } catch (e: SecurityException) {
            onError(e.localizedMessage)
        } catch (e: IllegalArgumentException) {
            onError(e.localizedMessage)
        }
    }

    override fun startUpdates(
        accuracyIndex: Int,
        intervalMs: Long,
        minDistanceMeters: Float,
        onLocation: (Location) -> Unit,
        onError: (String?) -> Unit,
    ): AutoCloseable {
        val provider = bestProvider(accuracyIndex)
        val listener = object : LocationListener {
            override fun onLocationChanged(location: Location) = onLocation(location)
            override fun onProviderEnabled(p: String) {}
            override fun onProviderDisabled(p: String) {}
            @Deprecated("Required by older API levels")
            override fun onStatusChanged(p: String?, status: Int, extras: Bundle?) {}
        }
        return try {
            lm.requestLocationUpdates(
                provider,
                intervalMs,
                minDistanceMeters,
                listener,
                Looper.getMainLooper(),
            )
            AutoCloseable { lm.removeUpdates(listener) }
        } catch (e: SecurityException) {
            onError(e.localizedMessage)
            AutoCloseable {}
        } catch (e: IllegalArgumentException) {
            onError(e.localizedMessage)
            AutoCloseable {}
        }
    }
}

internal class LocationStreamHandler(
    private val strategyProvider: () -> LocationStrategy?,
) : EventChannel.StreamHandler {
    private var subscription: AutoCloseable? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        val args = (arguments as? Map<*, *>) ?: emptyMap<Any, Any>()
        val accuracyIndex = (args["accuracy"] as? Int) ?: 4
        val interval = (args["intervalDuration"] as? Number)?.toLong() ?: 5000L
        val distance = (args["distanceFilter"] as? Number)?.toFloat() ?: 0f

        val str = strategyProvider() ?: run {
            events.error("POSITION_UNAVAILABLE", "Location services unavailable.", null)
            return
        }
        subscription = str.startUpdates(
            accuracyIndex = accuracyIndex,
            intervalMs = interval,
            minDistanceMeters = distance,
            onLocation = { events.success(locationToMap(it)) },
            onError = { events.error("POSITION_UNAVAILABLE", it, null) },
        )
    }

    override fun onCancel(arguments: Any?) {
        subscription?.close()
        subscription = null
    }
}

internal class ServiceStreamHandler : EventChannel.StreamHandler {
    private var context: Context? = null
    private var receiver: BroadcastReceiver? = null
    private var sink: EventChannel.EventSink? = null

    fun attach(context: Context) { this.context = context }
    fun detach() { context = null }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        sink = events
        val ctx = context ?: return
        val r = object : BroadcastReceiver() {
            override fun onReceive(c: Context?, intent: Intent?) {
                if (intent?.action == LocationManager.PROVIDERS_CHANGED_ACTION) {
                    val lm = c?.getSystemService(Context.LOCATION_SERVICE) as? LocationManager
                    val enabled = lm?.let {
                        it.isProviderEnabled(LocationManager.GPS_PROVIDER) ||
                            it.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
                    } ?: false
                    sink?.success(if (enabled) 1 else 0)
                }
            }
        }
        receiver = r
        ctx.registerReceiver(r, IntentFilter(LocationManager.PROVIDERS_CHANGED_ACTION))
    }

    override fun onCancel(arguments: Any?) {
        receiver?.let { context?.unregisterReceiver(it) }
        receiver = null
        sink = null
    }
}
