package com.example.flutter_listenfy

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.content.Context
import android.media.AudioDeviceInfo
import android.media.AudioManager
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
                    result.success(
                        mapOf(
                            "bluetoothOn" to false,
                            "devices" to emptyList<Map<String, Any>>(),
                            "outputs" to emptyList<String>()
                        )
                    )
                    return@setMethodCallHandler
                }

                val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                val outputKinds = linkedSetOf<String>()
                for (device in audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)) {
                    when (device.type) {
                        AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
                        AudioDeviceInfo.TYPE_BLUETOOTH_SCO -> outputKinds.add("bluetooth")
                        AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
                        AudioDeviceInfo.TYPE_WIRED_HEADSET,
                        AudioDeviceInfo.TYPE_USB_HEADSET,
                        AudioDeviceInfo.TYPE_USB_DEVICE -> outputKinds.add("wired")
                        AudioDeviceInfo.TYPE_BUILTIN_SPEAKER -> outputKinds.add("speaker")
                        AudioDeviceInfo.TYPE_BUILTIN_EARPIECE -> outputKinds.add("earpiece")
                    }
                }

                val responded = AtomicBoolean(false)

                adapter.getProfileProxy(
                    this,
                    object : BluetoothProfile.ServiceListener {
                        override fun onServiceConnected(profile: Int, proxy: BluetoothProfile) {
                            if (profile != BluetoothProfile.A2DP) return

                            val devices = proxy.connectedDevices.map { device ->
                                val battery = try {
                                    val method = device.javaClass.getMethod("getBatteryLevel")
                                    (method.invoke(device) as? Int) ?: -1
                                } catch (_: Throwable) {
                                    -1
                                }
                                mapOf(
                                    "name" to (device.name ?: ""),
                                    "address" to device.address,
                                    "kind" to "bluetooth",
                                    "battery" to battery
                                )
                            }

                            if (responded.compareAndSet(false, true)) {
                                result.success(
                                    mapOf(
                                        "bluetoothOn" to true,
                                        "devices" to devices,
                                        "outputs" to outputKinds.toList()
                                    )
                                )
                            }

                            adapter.closeProfileProxy(profile, proxy)
                        }

                        override fun onServiceDisconnected(profile: Int) {
                            if (responded.compareAndSet(false, true)) {
                                result.success(
                                    mapOf(
                                        "bluetoothOn" to true,
                                        "devices" to emptyList<Map<String, Any>>(),
                                        "outputs" to outputKinds.toList()
                                    )
                                )
                            }
                        }
                    },
                    BluetoothProfile.A2DP
                )
            }
    }
}
