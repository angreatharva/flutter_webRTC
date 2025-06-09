import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math' show min, sin, pi;
import 'package:flutter/services.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

/// A Flutter plugin for forking and processing WebRTC audio
class AudioForker {
  static const MethodChannel _channel = MethodChannel('com.rtc.audio_forker');
  
  /// Stream controller for receiving audio data from the native implementation
  static final StreamController<Uint8List> _audioDataStreamController = StreamController<Uint8List>.broadcast();
  
  /// Stream of audio data chunks
  static Stream<Uint8List> get audioDataStream => _audioDataStreamController.stream;
  
  /// The socket used for sending audio data to the server
  final io.Socket? _socket;
  
  /// The call ID for this audio session
  final String _callId;
  
  /// Whether the forker is currently running
  static bool _isRunning = false;
  
  /// Buffer size for audio chunks (in bytes)
  static const int kBufferSize = 4096; // 4KB chunks
  
  /// Sample rate for audio (in Hz)
  static const int kSampleRate = 44100;
  
  /// Minimum recording duration in milliseconds (20 seconds)
  static const int kMinRecordingDuration = 20000;
  
  /// Timer to enforce minimum recording duration
  Timer? _recordingTimer;
  
  /// Constructor
  AudioForker({required io.Socket? socket, required String callId}) 
      : _socket = socket,
        _callId = callId {
    // Set up method channel handler for receiving audio data from native code
    _channel.setMethodCallHandler(_handleMethodCall);
  }
  
  /// Initialize the audio forker
  static Future<bool> initialize() async {
    try {
      final bool result = await _channel.invokeMethod('initialize');
      if (result) {
        _channel.setMethodCallHandler(_handleMethodCall);
      }
      return result;
    } catch (e) {
      print('AudioForker: Failed to initialize: $e');
      return false;
    }
  }
  
  /// Start forking audio from WebRTC
  static Future<void> startAudioForking() async {
    if (_isRunning) {
      print('AudioForker: Already running.');
      return;
    }
    try {
      await _channel.invokeMethod('startAudioForking');
      _isRunning = true;
      print('AudioForker: Started audio forking.');
    } catch (e) {
      print('AudioForker: Failed to start audio forking: $e');
    }
  }
  
  /// Stop forking audio
  static Future<void> stopAudioForking() async {
    if (!_isRunning) {
      print('AudioForker: Not running.');
      return;
    }
    try {
      await _channel.invokeMethod('stopAudioForking');
      _isRunning = false;
      print('AudioForker: Stopped audio forking.');
    } catch (e) {
      print('AudioForker: Failed to stop audio forking: $e');
    }
  }
  
  /// Dispose the forker and clean up resources
  static Future<void> dispose() async {
    try {
      await _channel.invokeMethod('dispose');
      _audioDataStreamController.close();
      print('AudioForker: Disposed.');
    } catch (e) {
      print('AudioForker: Failed to dispose: $e');
    }
  }
  
  // Record start time when we begin processing audio
  DateTime? _startTime;
  
  /// Handle method calls from the native code
  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method == 'audioData') {
      final dynamic args = call.arguments;
      if (args is Uint8List) {
        print('DART: Received audio chunk of ${args.length} bytes, first 10: ${args.take(10).toList()}');
        _audioDataStreamController.add(args);
      } else {
        print('AudioForker: Received audioData with unexpected type: ${args.runtimeType}');
      }
    } else {
      print('AudioForker: Unknown method call from native: ${call.method}');
    }
    return null;
  }
  
  /// Process audio data received from native code
  void _processAudioData(Uint8List audioData) {
    // Skip processing if data is empty
    if (audioData == null || audioData.isEmpty) {
      print('Received empty audio data, skipping');
      return;
    }
    
    // Check if audio data contains any non-zero values (actual audio)
    bool hasAudioData = false;
    for (int i = 0; i < min(audioData.length, 100); i++) {
      if (audioData[i] != 0) {
        hasAudioData = true;
        break;
      }
    }
    
    if (!hasAudioData) {
      print('WARNING: Audio data contains only zeros (silence) - possible audio capture issue');
      // Create artificial test tone to ensure data flows
      if (DateTime.now().millisecondsSinceEpoch % 3000 < 300) {
        print('Generating test tone to confirm data flow');
        audioData = _generateTestTone(audioData.length);
      }
    } else {
      print('Audio data contains actual audio content - length: ${audioData.length} bytes');
    }
    
    // Add to the stream for any local listeners
    _audioDataStreamController.add(audioData);
    
    // Send to server if socket is available
    if (_socket != null && _isRunning) {
      try {
        // Convert to base64 for sending over socket
        final String base64Data = base64Encode(audioData);
        print('Sending ${audioData.length} bytes of audio data to server');
        
        _socket!.emit('audioChunk', {
          'callId': _callId,
          'audioChunk': base64Data,
          'transcribe': true,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'hasAudioContent': hasAudioData
        });
        
        // Check socket connection status
        _socket!.onConnect((_) {
          print('Socket CONNECTED');
        });
        
        _socket!.onDisconnect((_) {
          print('Socket DISCONNECTED');
        });
        
        _socket!.onError((error) {
          print('Socket ERROR: $error');
        });
      } catch (e) {
        print('ERROR sending audio data: $e');
      }
    } else {
      print('Socket not available for sending audio data: socket=${_socket != null}, running=$_isRunning');
    }
  }
  
  /// Generate a test tone to ensure audio data is being sent
  Uint8List _generateTestTone(int length) {
    // Create a simple sine wave tone
    final Uint8List tone = Uint8List(length);
    final int samples = length ~/ 2; // 16-bit samples = 2 bytes per sample
    final double frequency = 440.0; // A4 note
    final int sampleRate = 44100;
    
    for (int i = 0; i < samples; i++) {
      final double time = i / sampleRate;
      final double amplitude = 0.5 * 32767; // Half of max 16-bit amplitude
      final double value = sin(2 * pi * frequency * time) * amplitude;
      final int sample = value.toInt();
      
      // Convert to bytes (little endian)
      tone[i * 2] = sample & 0xFF;
      tone[i * 2 + 1] = (sample >> 8) & 0xFF;
    }
    
    print('Generated test tone of $length bytes');
    return tone;
  }
}
