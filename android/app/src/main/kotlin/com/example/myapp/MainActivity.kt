package com.example.myapp

import io.flutter.embedding.android.FlutterActivity
import androidx.annotation.NonNull
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Context
import android.media.AudioManager

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.myapp/volumecontrol"
    private lateinit var audioManager: AudioManager

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
            when (call.method) {
                "getVolume" -> {
                    val currentVolume = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
                    result.success(currentVolume)
                }
                "getMaxVolume" -> {
                    val maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                    result.success(maxVolume)
                }
                "setVolume" -> {
                    val volume = call.argument<Int>("volume")
                    if (volume != null) {
                        audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, volume, 0)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGUMENT", "Volume cannot be null", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
