# AudioForker (Kotlin Native Plugin)

## Features
- Real-time audio capture using Android's AudioRecord API
- 16kHz, mono, PCM 16-bit audio (industry standard for speech transcription)
- Noise suppression, echo cancellation, and auto gain control enabled
- Audio chunked in 100ms frames for low-latency streaming
- (Optional) Voice Activity Detection (VAD) logic for bandwidth savings
- Robust error handling and logging
- Exposes `initialize`, `startAudioForking`, `stopAudioForking`, and `dispose` methods via Flutter MethodChannel

## Usage
- Register the plugin in `MainActivity.kt` (already done)
- Use the MethodChannel `com.rtc.audio_forker` from Dart to control audio forking
- Listen for `audioData` events in Dart to receive audio chunks for streaming/transcription

## Best Practices
- Ensure RECORD_AUDIO permission is granted before initializing
- Always call `initialize()` before starting audio forking
- Use 16kHz sample rate throughout your pipeline (client, server, and cloud STT)
- For production, consider enabling VAD to reduce bandwidth
- Monitor logs for silence or errors to debug device-specific issues

## Extending
- VAD can be improved with more advanced algorithms (energy threshold, WebRTC VAD, etc.)
- You can add more audio processing (e.g., gain normalization) as needed

---

**This implementation follows 2024 industry best practices for real-time speech transcription on Android.** 