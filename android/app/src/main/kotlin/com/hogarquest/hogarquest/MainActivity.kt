package com.hogarquest.hogarquest

import android.bluetooth.BluetoothManager
import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "hogarquest/ajustes")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "abrirAjustesNotificaciones" -> {
                        val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                            .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                        try {
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("ERROR", e.message, null)
                        }
                    }
                    "desactivarBluetooth" -> {
                        // Mejor-esfuerzo: en Android 12+ el sistema no permite
                        // que una app apague el Bluetooth del celular, por lo que
                        // esto suele devolver false (atrapado abajo).
                        try {
                            val adapter = (getSystemService(BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter
                            val ok = adapter?.disable() ?: false
                            result.success(ok)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}