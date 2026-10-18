package com.hogarquest.hogarquest

import android.bluetooth.BluetoothManager
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {

    private var pendingPermisoRed: MethodChannel.Result? = null

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
                    "abrirAjustesUbicacion" -> {
                        // Nearby Connections exige la ubicación del sistema
                        // encendida para poder escanear dispositivos.
                        try {
                            startActivity(Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS))
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("ERROR", e.message, null)
                        }
                    }
                    "abrirAjustesBluetooth" -> {
                        // Android 12+ no deja que la app apague el Bluetooth,
                        // así que se abren los ajustes para que el usuario lo haga.
                        try {
                            startActivity(Intent(Settings.ACTION_BLUETOOTH_SETTINGS))
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
                    "estadoRedLocal" -> {
                        // ACCESS_LOCAL_NETWORK solo existe desde Android 17 (API 37).
                        // En versiones anteriores no hay permiso que conceder y la
                        // red local funciona sin él.
                        if (Build.VERSION.SDK_INT < 37) {
                            result.success("no_aplica")
                        } else {
                            val concedido = checkSelfPermission(PERMISO_RED_LOCAL) ==
                                PackageManager.PERMISSION_GRANTED
                            result.success(if (concedido) "concedido" else "denegado")
                        }
                    }
                    "pedirRedLocal" -> {
                        if (Build.VERSION.SDK_INT < 37) {
                            result.success("no_aplica")
                        } else if (pendingPermisoRed != null) {
                            result.success("denegado")
                        } else {
                            pendingPermisoRed = result
                            requestPermissions(arrayOf(PERMISO_RED_LOCAL), REQUEST_PERMISO_RED)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        if (requestCode == REQUEST_PERMISO_RED) {
            val concedido = grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingPermisoRed?.success(if (concedido) "concedido" else "denegado")
            pendingPermisoRed = null
            return
        }
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    companion object {
        private const val PERMISO_RED_LOCAL = "android.permission.ACCESS_LOCAL_NETWORK"
        private const val REQUEST_PERMISO_RED = 1001
    }
}
