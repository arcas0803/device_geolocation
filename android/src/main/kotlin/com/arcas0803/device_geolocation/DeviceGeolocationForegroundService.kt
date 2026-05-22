package com.arcas0803.device_geolocation

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.net.wifi.WifiManager
import android.os.Binder
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.EventChannel

internal const val FOREGROUND_NOTIFICATION_ID = 0x9C01
internal const val FOREGROUND_CHANNEL_ID = "device_geolocation_channel"
internal const val WAKE_LOCK_TAG = "device_geolocation:wakelock"
internal const val WIFI_LOCK_TAG = "device_geolocation:wifilock"

class DeviceGeolocationForegroundService : Service() {

    inner class LocalBinder : Binder() {
        fun getService(): DeviceGeolocationForegroundService =
            this@DeviceGeolocationForegroundService
    }

    private val binder = LocalBinder()

    private data class ActiveSubscription(
        val sink: EventChannel.EventSink,
        val closeable: AutoCloseable,
    )

    private val subscriptions = mutableListOf<ActiveSubscription>()
    private var connectedEngines = 0
    private var foregroundStarted = false
    private var wakeLock: PowerManager.WakeLock? = null
    private var wifiLock: WifiManager.WifiLock? = null

    override fun onBind(intent: Intent?): IBinder {
        connectedEngines++
        return binder
    }

    override fun onUnbind(intent: Intent?): Boolean {
        connectedEngines = (connectedEngines - 1).coerceAtLeast(0)
        stopIfIdle()
        return true // allow onRebind on subsequent bind
    }

    override fun onRebind(intent: Intent?) {
        connectedEngines++
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int = START_STICKY

    override fun onDestroy() {
        for (s in subscriptions) {
            try { s.closeable.close() } catch (_: Throwable) {}
        }
        subscriptions.clear()
        releaseLocks()
        super.onDestroy()
    }

    /**
     * Starts a foreground-service-backed location subscription. The first
     * successful call also promotes the service to the foreground and shows
     * the notification described by [config]. Returns `true` on success.
     */
    fun startLocationUpdates(
        accuracyIndex: Int,
        intervalMs: Long,
        distanceMeters: Float,
        forceLocationManager: Boolean,
        config: Map<String, Any?>,
        sink: EventChannel.EventSink,
    ): Boolean {
        if (Build.VERSION.SDK_INT >= 34 && !hasManifestPermission(
                "android.permission.FOREGROUND_SERVICE_LOCATION",
            )
        ) {
            sink.error(
                "MISSING_FOREGROUND_SERVICE_LOCATION_PERMISSION",
                "The host AndroidManifest.xml must declare " +
                    "android.permission.FOREGROUND_SERVICE_LOCATION when " +
                    "targeting Android 14+ and using foreground location.",
                null,
            )
            return false
        }
        if (!hasLocationPermission()) {
            sink.error("PERMISSION_DENIED", "Location permission denied.", null)
            return false
        }

        val notification = buildNotification(config)
        if (!foregroundStarted) {
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    startForeground(
                        FOREGROUND_NOTIFICATION_ID,
                        notification,
                        ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION,
                    )
                } else {
                    startForeground(FOREGROUND_NOTIFICATION_ID, notification)
                }
                foregroundStarted = true
                acquireLocks(config)
            } catch (e: Throwable) {
                sink.error(
                    "FOREGROUND_SERVICE_START_FAILED",
                    e.localizedMessage ?: e.toString(),
                    null,
                )
                return false
            }
        } else {
            // Refresh the existing notification with the latest config.
            val mgr = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            mgr.notify(FOREGROUND_NOTIFICATION_ID, notification)
        }

        val strategy: LocationStrategy = if (forceLocationManager) {
            LocationManagerStrategy(applicationContext)
        } else {
            createStrategy(applicationContext)
        }

        val closeable = try {
            strategy.startUpdates(
                accuracyIndex = accuracyIndex,
                intervalMs = intervalMs,
                minDistanceMeters = distanceMeters,
                onLocation = { loc ->
                    if (!hasLocationPermission()) {
                        sink.error(
                            "PERMISSION_DENIED",
                            "Location permission revoked while service was running.",
                            null,
                        )
                        stopLocationUpdates(sink)
                    } else {
                        sink.success(locationToMap(loc))
                    }
                },
                onError = { msg -> sink.error("POSITION_UNAVAILABLE", msg, null) },
            )
        } catch (e: SecurityException) {
            sink.error("PERMISSION_DENIED", e.localizedMessage, null)
            return false
        }

        subscriptions.add(ActiveSubscription(sink, closeable))
        return true
    }

    /** Stops the subscription bound to [sink] and tears down the service if idle. */
    fun stopLocationUpdates(sink: EventChannel.EventSink) {
        val it = subscriptions.iterator()
        while (it.hasNext()) {
            val s = it.next()
            if (s.sink === sink) {
                try { s.closeable.close() } catch (_: Throwable) {}
                it.remove()
            }
        }
        stopIfIdle()
    }

    private fun stopIfIdle() {
        if (subscriptions.isEmpty() && connectedEngines == 0) {
            releaseLocks()
            if (foregroundStarted) {
                stopForeground(STOP_FOREGROUND_REMOVE)
                foregroundStarted = false
            }
            stopSelf()
        }
    }

    private fun hasLocationPermission(): Boolean =
        ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.ACCESS_FINE_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED ||
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.ACCESS_COARSE_LOCATION,
            ) == PackageManager.PERMISSION_GRANTED

    private fun hasManifestPermission(name: String): Boolean = try {
        val info = packageManager.getPackageInfo(
            packageName,
            PackageManager.GET_PERMISSIONS,
        )
        info.requestedPermissions?.any { it == name } == true
    } catch (_: Throwable) {
        false
    }

    private fun buildNotification(config: Map<String, Any?>): Notification {
        val title = (config["notificationTitle"] as? String) ?: "Location"
        val text = (config["notificationText"] as? String)
            ?: "Tracking your location"
        val channelName = (config["notificationChannelName"] as? String)
            ?: "Background Location"
        val setOngoing = (config["setOngoing"] as? Boolean) ?: false
        val color = (config["color"] as? Number)?.toInt()
        val iconCfg = config["notificationIcon"] as? Map<*, *>
        val iconName = (iconCfg?.get("name") as? String) ?: "ic_launcher"
        val iconDefType = (iconCfg?.get("defType") as? String) ?: "mipmap"

        ensureNotificationChannel(channelName)

        val smallIconRes = resources.getIdentifier(iconName, iconDefType, packageName)
            .takeIf { it != 0 }
            ?: resources.getIdentifier("ic_launcher", "mipmap", packageName)

        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val contentIntent = if (launchIntent != null) {
            PendingIntent.getActivity(this, 0, launchIntent, flags)
        } else null

        val builder = NotificationCompat.Builder(this, FOREGROUND_CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(text)
            .setSmallIcon(smallIconRes)
            .setOngoing(setOngoing)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
        if (color != null) builder.setColor(color)
        if (contentIntent != null) builder.setContentIntent(contentIntent)
        return builder.build()
    }

    private fun ensureNotificationChannel(channelName: String) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val mgr = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val existing = mgr.getNotificationChannel(FOREGROUND_CHANNEL_ID)
        if (existing == null) {
            val channel = NotificationChannel(
                FOREGROUND_CHANNEL_ID,
                channelName,
                NotificationManager.IMPORTANCE_LOW,
            )
            channel.setShowBadge(false)
            mgr.createNotificationChannel(channel)
        } else if (existing.name != channelName) {
            existing.name = channelName
            mgr.createNotificationChannel(existing)
        }
    }

    @SuppressWarnings("WakelockTimeout")
    private fun acquireLocks(config: Map<String, Any?>) {
        val wantWake = (config["enableWakeLock"] as? Boolean) ?: false
        val wantWifi = (config["enableWifiLock"] as? Boolean) ?: false
        if (wantWake && wakeLock == null) {
            val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager
            wakeLock = pm?.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, WAKE_LOCK_TAG)
                ?.apply { setReferenceCounted(false); acquire() }
        }
        if (wantWifi && wifiLock == null) {
            val wm = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
            wifiLock = wm?.createWifiLock(
                WifiManager.WIFI_MODE_FULL_HIGH_PERF,
                WIFI_LOCK_TAG,
            )?.apply { setReferenceCounted(false); acquire() }
        }
    }

    private fun releaseLocks() {
        try { wakeLock?.takeIf { it.isHeld }?.release() } catch (_: Throwable) {}
        wakeLock = null
        try { wifiLock?.takeIf { it.isHeld }?.release() } catch (_: Throwable) {}
        wifiLock = null
    }
}
