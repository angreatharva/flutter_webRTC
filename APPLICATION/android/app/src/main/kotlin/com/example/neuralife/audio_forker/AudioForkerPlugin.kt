package com.example.neuralife.audio_forker

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class AudioForkerPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private var audioForker: AudioForker? = null
    private var context: Context? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "com.rtc.audio_forker")
        channel.setMethodCallHandler(this)
        audioForker = AudioForker(context!!, channel)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        audioForker?.dispose()
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "initialize" -> {
                val success = audioForker?.initialize() ?: false
                result.success(success)
            }
            "startAudioForking" -> {
                audioForker?.startAudioForking()
                result.success(true)
            }
            "stopAudioForking" -> {
                audioForker?.stopAudioForking()
                result.success(true)
            }
            "dispose" -> {
                audioForker?.dispose()
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }
} 