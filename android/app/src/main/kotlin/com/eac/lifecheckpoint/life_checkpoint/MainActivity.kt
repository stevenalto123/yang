package com.eac.lifecheckpoint.life_checkpoint

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.lifecheckpoint.app/native"
        private const val REQ_LOCATION = 4001
        private const val REQ_NOTIF = 4002
        private const val NOTIF_CHANNEL_ID = "lifecheckpoint_alerts"
    }

    private var pendingLocationResult: MethodChannel.Result? = null
    private var pendingNotifResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getCurrentPosition" -> handleGetLocation(result)
                    "getNotificationPermissionStatus" -> result.success(getNotifPermissionStatus())
                    "requestNotificationPermission" -> handleRequestNotifPermission(result)
                    "showNotification" -> {
                        val title = call.argument<String>("title") ?: "LifeCheckpoint Alert"
                        val body = call.argument<String>("body") ?: ""
                        result.success(showLocalNotification(title, body))
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun hasLocationPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        val fine = checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED
        val coarse = checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED
        return fine || coarse
    }

    private fun handleGetLocation(result: MethodChannel.Result) {
        if (!hasLocationPermission()) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                pendingLocationResult = result
                requestPermissions(
                    arrayOf(
                        Manifest.permission.ACCESS_FINE_LOCATION,
                        Manifest.permission.ACCESS_COARSE_LOCATION
                    ),
                    REQ_LOCATION
                )
                return
            }
        }
        resolveLocationFix(result)
    }

    private fun resolveLocationFix(result: MethodChannel.Result) {
        try {
            val lm = getSystemService(Context.LOCATION_SERVICE) as LocationManager
            val providers = listOf(
                LocationManager.GPS_PROVIDER,
                LocationManager.NETWORK_PROVIDER
            )

            var bestLast: Location? = null
            for (p in providers) {
                if (lm.isProviderEnabled(p)) {
                    val loc = lm.getLastKnownLocation(p)
                    if (loc != null && (bestLast == null || loc.time > bestLast.time)) {
                        bestLast = loc
                    }
                }
            }

            if (bestLast != null && System.currentTimeMillis() - bestLast.time < 120_000) {
                result.success(locationToMap(bestLast))
                return
            }

            val activeProvider = providers.firstOrNull { lm.isProviderEnabled(it) }
            if (activeProvider == null) {
                result.success(bestLast?.let { locationToMap(it) })
                return
            }

            var finished = false
            val handler = Handler(Looper.getMainLooper())
            val listener = object : LocationListener {
                override fun onLocationChanged(location: Location) {
                    if (!finished) {
                        finished = true
                        lm.removeUpdates(this)
                        result.success(locationToMap(location))
                    }
                }
                override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
                override fun onProviderEnabled(provider: String) {}
                override fun onProviderDisabled(provider: String) {}
            }

            lm.requestLocationUpdates(activeProvider, 0L, 0f, listener, Looper.getMainLooper())
            handler.postDelayed({
                if (!finished) {
                    finished = true
                    lm.removeUpdates(listener)
                    result.success(bestLast?.let { locationToMap(it) })
                }
            }, 7000)
        } catch (_: SecurityException) {
            result.success(null)
        } catch (_: Exception) {
            result.success(null)
        }
    }

    private fun locationToMap(loc: Location): Map<String, Any> {
        return mapOf(
            "lat" to loc.latitude,
            "lng" to loc.longitude,
            "accuracy" to loc.accuracy.toDouble()
        )
    }

    private fun getNotifPermissionStatus(): String {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return "granted"
        val granted = checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        return if (granted) "granted" else "default"
    }

    private fun handleRequestNotifPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(true)
            return
        }
        if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }
        pendingNotifResult = result
        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQ_NOTIF)
    }

    private fun showLocalNotification(title: String, body: String): Boolean {
        return try {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
                PackageManager.PERMISSION_GRANTED
            ) {
                return false
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    NOTIF_CHANNEL_ID,
                    "LifeCheckpoint Alerts",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Emergency kit expiration and disaster preparedness reminders"
                }
                nm.createNotificationChannel(channel)
            }

            val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(this, NOTIF_CHANNEL_ID)
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(this)
            }

            val notification = builder
                .setContentTitle(title)
                .setContentText(body)
                .setSmallIcon(applicationInfo.icon)
                .setAutoCancel(true)
                .build()

            nm.notify((System.currentTimeMillis() % 100000).toInt(), notification)
            true
        } catch (_: Exception) {
            false
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        when (requestCode) {
            REQ_LOCATION -> {
                val res = pendingLocationResult
                pendingLocationResult = null
                if (res != null) {
                    if (grantResults.any { it == PackageManager.PERMISSION_GRANTED }) {
                        resolveLocationFix(res)
                    } else {
                        res.success(null)
                    }
                }
            }
            REQ_NOTIF -> {
                val res = pendingNotifResult
                pendingNotifResult = null
                res?.success(grantResults.any { it == PackageManager.PERMISSION_GRANTED })
            }
        }
    }
}
