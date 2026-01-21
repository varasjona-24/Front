package com.example.flutter_listenfy

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicBoolean

class MainActivity : FlutterActivity() {
    private val channel = "listenfy/bluetooth_audio"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                if (call.method != "getAudioDevices") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                val manager = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
                val adapter: BluetoothAdapter? = manager?.adapter

                if (adapter == null || !adapter.isEnabled) {
                    result.success(mapOf("bluetoothOn" to false, "devices" to emptyList<Map<String, String>>()))
                    return@setMethodCallHandler
                }

                val responded = AtomicBoolean(false)

                adapter.getProfileProxy(
                    this,
                    object : BluetoothProfile.ServiceListener {
                        override fun onServiceConnected(profile: Int, proxy: BluetoothProfile) {
                            if (profile != BluetoothProfile.A2DP) return

                            val devices = proxy.connectedDevices.map {
                                mapOf(
                                    "name" to (it.name ?: ""),
                                    "address" to it.address
                                )
                            }

                            if (responded.compareAndSet(false, true)) {
                                result.success(mapOf("bluetoothOn" to true, "devices" to devices))
                            }

                            adapter.closeProfileProxy(profile, proxy)
                        }

                        override fun onServiceDisconnected(profile: Int) {
                            if (responded.compareAndSet(false, true)) {
                                result.success(mapOf("bluetoothOn" to true, "devices" to emptyList<Map<String, String>>()))
                            }
                        }
                    },
                    BluetoothProfile.A2DP
                )
            }
    }
}
