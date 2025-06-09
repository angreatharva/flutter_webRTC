package com.example.neuralife.audio_forker

import android.Manifest
import android.content.Context
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.util.Log
import androidx.annotation.RequiresApi
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import java.nio.ByteBuffer
import java.util.concurrent.atomic.AtomicBoolean

class AudioForker(
    private val context: Context,
    private val methodChannel: MethodChannel
) {
    companion object {
        private const val TAG = "AudioForker"
        private const val SAMPLE_RATE = 44100
        private const val CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_STEREO
        private const val AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT
        private const val CHUNK_DURATION_MS = 100 // 100ms
        private const val BYTES_PER_SAMPLE = 2 // PCM 16-bit
        private const val CHANNELS = 2
        private const val CHUNK_SIZE = (SAMPLE_RATE / 10) * BYTES_PER_SAMPLE * CHANNELS // 100ms chunk, stereo
    }

    private var audioRecord: AudioRecord? = null
    private var recordingJob: Job? = null
    private val isRecording = AtomicBoolean(false)
    private val mainHandler = Handler(Looper.getMainLooper())

    private fun getBestAudioSource(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            MediaRecorder.AudioSource.MIC
        } else {
            MediaRecorder.AudioSource.CAMCORDER
        }
    }

    fun initialize(): Boolean {
        try {
            // Check permission (should be handled in Dart, but double-check here)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val permission = context.checkSelfPermission(Manifest.permission.RECORD_AUDIO)
                if (permission != android.content.pm.PackageManager.PERMISSION_GRANTED) {
                    Log.e(TAG, "RECORD_AUDIO permission not granted!")
                    return false
                }
            }

            val minBufferSize = AudioRecord.getMinBufferSize(
                SAMPLE_RATE, CHANNEL_CONFIG, AUDIO_FORMAT
            )
            if (minBufferSize == AudioRecord.ERROR || minBufferSize == AudioRecord.ERROR_BAD_VALUE) {
                Log.e(TAG, "Invalid min buffer size: $minBufferSize")
                return false
            }

            val bufferSize = maxOf(minBufferSize, CHUNK_SIZE * 2)

            audioRecord = AudioRecord(
                getBestAudioSource(),
                SAMPLE_RATE,
                CHANNEL_CONFIG,
                AUDIO_FORMAT,
                bufferSize
            )

            if (audioRecord?.state != AudioRecord.STATE_INITIALIZED) {
                Log.e(TAG, "AudioRecord failed to initialize!")
                audioRecord?.release()
                audioRecord = null
                return false
            }

            Log.i(TAG, "AudioRecord initialized: sampleRate=${audioRecord?.sampleRate}, channels=${audioRecord?.channelCount}, state=${audioRecord?.state}, bufferSize=$bufferSize, chunkSize=$CHUNK_SIZE")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Error initializing AudioForker", e)
            return false
        }
    }

    fun startAudioForking() {
        if (isRecording.get()) {
            Log.w(TAG, "Audio forking already running.")
            return
        }
        if (audioRecord == null) {
            Log.e(TAG, "AudioRecord is null. Call initialize() first.")
            return
        }
        isRecording.set(true)
        audioRecord?.startRecording()
        recordingJob = CoroutineScope(Dispatchers.IO).launch {
            Process.setThreadPriority(Process.THREAD_PRIORITY_URGENT_AUDIO)
            val buffer = ByteArray(CHUNK_SIZE)
            var lastChunkTime = System.currentTimeMillis()
            while (isRecording.get()) {
                val bytesRead = audioRecord?.read(buffer, 0, buffer.size) ?: 0
                val now = System.currentTimeMillis()
                val delta = now - lastChunkTime
                lastChunkTime = now
                Log.i(TAG, "AudioRecord read $bytesRead bytes (expected $CHUNK_SIZE), time since last chunk: ${delta}ms")
                if (bytesRead > 0) {
                    Log.i(TAG, "First 10 bytes: ${buffer.take(10)}")
                    // Always send every chunk, even if it is silent
                    mainHandler.post {
                        methodChannel.invokeMethod("audioData", buffer.copyOf(bytesRead))
                    }
                } else {
                    Log.w(TAG, "AudioRecord read returned $bytesRead bytes.")
                }
            }
            Log.i(TAG, "Audio forking stopped.")
        }
        Log.i(TAG, "Audio forking started.")
    }

    fun stopAudioForking() {
        if (!isRecording.get()) {
            Log.w(TAG, "Audio forking is not running.")
            return
        }
        isRecording.set(false)
        try {
            audioRecord?.stop()
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping AudioRecord", e)
        }
        recordingJob?.cancel()
        recordingJob = null
        Log.i(TAG, "Audio forking stopped.")
    }

    fun dispose() {
        stopAudioForking()
        audioRecord?.release()
        audioRecord = null
        Log.i(TAG, "AudioForker disposed.")
    }
} 