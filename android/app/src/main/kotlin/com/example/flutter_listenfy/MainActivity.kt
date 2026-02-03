package com.example.flutter_listenfy

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.content.Context
import android.os.Build
import android.util.Rational
import android.app.PictureInPictureParams
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.media.audiofx.BassBoost
import android.media.audiofx.EnvironmentalReverb
import android.media.audiofx.LoudnessEnhancer
import android.media.audiofx.PresetReverb
import android.media.audiofx.Virtualizer
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.example.flutter_listenfy.widget.PlayerWidgetProvider
import android.content.Intent
import kotlin.math.roundToInt
import java.util.concurrent.atomic.AtomicBoolean

class MainActivity : AudioServiceActivity() {
    private val channel = "listenfy/bluetooth_audio"
    private val spatialChannel = "listenfy/spatial_audio"
    private val openalChannel = "listenfy/openal"
    private val pipChannel = "listenfy/pip"
    private val widgetChannel = "listenfy/player_widget"
    private var pipEnabled: Boolean = false
    private var pipAspect: Double = 1.777777
    private var pipWidth: Int? = null
    private var pipHeight: Int? = null
    private var spatialSessionId: Int? = null
    private var virtualizer: Virtualizer? = null
    private var bassBoost: BassBoost? = null
    private var reverb: PresetReverb? = null
    private var envReverb: EnvironmentalReverb? = null
    private var loudness: LoudnessEnhancer? = null


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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, spatialChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "enable" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        val sessionId = call.argument<Int>("sessionId") ?: 0
                        if (sessionId <= 0) {
                            result.error("NO_SESSION", "Invalid audio session", null)
                            return@setMethodCallHandler
                        }
                        try {
                            if (enabled) {
                                if (virtualizer == null || spatialSessionId != sessionId) {
                                    releaseSpatial()
                                    spatialSessionId = sessionId
                                    virtualizer = Virtualizer(0, sessionId).apply {
                                        setStrength(1000.toShort())
                                        this.enabled = true
                                    }
                                    bassBoost = BassBoost(0, sessionId).apply {
                                        setStrength(200.toShort())
                                        setEnabled(true)
                                    }
                                    reverb = PresetReverb(0, sessionId).apply {
                                        preset = PresetReverb.PRESET_LARGEHALL
                                        setEnabled(true)
                                    }
                                    envReverb = EnvironmentalReverb(0, sessionId).apply {
                                        roomLevel = 0.toShort()
                                        roomHFLevel = 0.toShort()
                                        decayTime = 7000
                                        decayHFRatio = 2000
                                        reflectionsLevel = 0.toShort()
                                        reflectionsDelay = 120
                                        reverbLevel = 0.toShort()
                                        reverbDelay = 180
                                        diffusion = 1000
                                        density = 1000
                                        setEnabled(true)
                                    }
                                    loudness = LoudnessEnhancer(sessionId).apply {
                                        setTargetGain(900)
                                        setEnabled(true)
                                    }
                                } else {
                                    virtualizer?.enabled = true
                                    bassBoost?.enabled = true
                                    reverb?.enabled = true
                                    envReverb?.enabled = true
                                    loudness?.enabled = true
                                }
                            } else {
                                releaseSpatial()
                            }
                            result.success(true)
                        } catch (e: Throwable) {
                            releaseSpatial()
                            result.error("SPATIAL_ERROR", e.message, null)
                        }
                    }
                    "release" -> {
                        releaseSpatial()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, pipChannel)
            .setMethodCallHandler { call, result ->
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
                    result.success(false)
                    return@setMethodCallHandler
                }
                when (call.method) {
                    "setEnabled" -> {
                        pipEnabled = call.argument<Boolean>("enabled") ?: false
                        pipAspect = call.argument<Double>("aspect") ?: 1.777777
                        pipWidth = call.argument<Int>("width")
                        pipHeight = call.argument<Int>("height")
                        result.success(true)
                    }
                    "enter" -> {
                        val width = call.argument<Int>("width")
                        val height = call.argument<Int>("height")
                        val aspect = call.argument<Double>("aspect") ?: 1.777777
                        val ratio = buildPipRational(width, height, aspect)
                        val builder = PictureInPictureParams.Builder()
                            .setAspectRatio(ratio)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            builder.setExpandedAspectRatio(ratio)
                            builder.setSeamlessResizeEnabled(true)
                        }
                        val params = builder.build()
                        val ok = enterPictureInPictureMode(params)
                        result.success(ok)
                    }
                    "exit" -> {
                        // No-op: system exits PiP when activity resumes.
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, widgetChannel)
            .setMethodCallHandler { call, result ->
                if (call.method != "updateWidget") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                val title = call.argument<String>("title") ?: ""
                val artist = call.argument<String>("artist") ?: ""
                val artPath = call.argument<String>("artPath") ?: ""
                val playing = call.argument<Boolean>("playing") ?: false
                val barColorAny = call.argument<Any>("barColor")
                val barColor = when (barColorAny) {
                    is Int -> barColorAny
                    is Long -> barColorAny.toInt()
                    is Double -> barColorAny.toInt()
                    else -> 0xFF1E2633.toInt()
                }

                val prefs = getSharedPreferences(PlayerWidgetProvider.PREFS, Context.MODE_PRIVATE)
                prefs.edit()
                    .putString(PlayerWidgetProvider.KEY_TITLE, title)
                    .putString(PlayerWidgetProvider.KEY_ARTIST, artist)
                    .putString(PlayerWidgetProvider.KEY_ART_PATH, artPath)
                    .putBoolean(PlayerWidgetProvider.KEY_PLAYING, playing)
                    .putInt(PlayerWidgetProvider.KEY_BAR_COLOR, barColor)
                    .apply()

                val intent = Intent(this, PlayerWidgetProvider::class.java).apply {
                    action = PlayerWidgetProvider.ACTION_WIDGET_UPDATE
                }
                sendBroadcast(intent)

                result.success(true)
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, openalChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "playFile" -> {
                        val path = call.argument<String>("path") ?: ""
                        val enableHrtf = call.argument<Boolean>("enableHrtf") ?: true
                        if (path.isBlank()) {
                            result.error("NO_PATH", "Path required", null)
                            return@setMethodCallHandler
                        }
                        Thread {
                            val pcm = OpenALBridge.decodeToPcm(path)
                            if (pcm == null) {
                                runOnUiThread {
                                    result.error("DECODE_FAIL", "Decode failed", null)
                                }
                                return@Thread
                            }
                            val ok = OpenALBridge.nativePlay(
                                pcm.bytes,
                                pcm.sampleRate,
                                pcm.channels,
                                enableHrtf
                            )
                            val durationMs =
                                (pcm.bytes.size / (2 * pcm.channels) * 1000L) / pcm.sampleRate
                            runOnUiThread {
                                if (ok) {
                                    result.success(
                                        mapOf(
                                            "durationMs" to durationMs,
                                            "sampleRate" to pcm.sampleRate,
                                            "channels" to pcm.channels
                                        )
                                    )
                                } else {
                                    result.error("OPENAL_FAIL", "OpenAL failed", null)
                                }
                            }
                        }.start()
                    }
                    "pause" -> {
                        OpenALBridge.nativePause()
                        result.success(true)
                    }
                    "resume" -> {
                        OpenALBridge.nativeResume()
                        result.success(true)
                    }
                    "seek" -> {
                        val seconds = call.argument<Double>("seconds") ?: 0.0
                        OpenALBridge.nativeSeek(seconds.toFloat())
                        result.success(true)
                    }
                    "stop" -> {
                        OpenALBridge.nativeStop()
                        result.success(true)
                    }
                    "release" -> {
                        OpenALBridge.nativeRelease()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        if (!pipEnabled) return
        val ratio = buildPipRational(pipWidth, pipHeight, pipAspect)
        val builder = PictureInPictureParams.Builder()
            .setAspectRatio(ratio)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            builder.setExpandedAspectRatio(ratio)
            builder.setSeamlessResizeEnabled(true)
        }
        val params = builder.build()
        enterPictureInPictureMode(params)
    }

    private fun buildPipRational(width: Int?, height: Int?, aspect: Double): Rational {
        val ratio = when {
            width != null && height != null && width > 0 && height > 0 ->
                width.toDouble() / height.toDouble()
            else -> aspect
        }

        val minRatio = 1.0 / 2.39
        val maxRatio = 2.39
        val clamped = ratio.coerceIn(minRatio, maxRatio)
        val w = 1000
        val h = (w / clamped).roundToInt().coerceAtLeast(1)
        return Rational(w, h)
    }

    private fun releaseSpatial() {
        try {
            virtualizer?.enabled = false
        } catch (_: Throwable) {
        }
        try {
            bassBoost?.enabled = false
        } catch (_: Throwable) {
        }
        try {
            reverb?.enabled = false
        } catch (_: Throwable) {
        }
        try {
            envReverb?.enabled = false
        } catch (_: Throwable) {
        }
        try {
            loudness?.enabled = false
        } catch (_: Throwable) {
        }
        try {
            virtualizer?.release()
        } catch (_: Throwable) {
        }
        try {
            bassBoost?.release()
        } catch (_: Throwable) {
        }
        try {
            reverb?.release()
        } catch (_: Throwable) {
        }
        try {
            envReverb?.release()
        } catch (_: Throwable) {
        }
        try {
            loudness?.release()
        } catch (_: Throwable) {
        }
        virtualizer = null
        bassBoost = null
        reverb = null
        envReverb = null
        loudness = null
        spatialSessionId = null
    }
}
