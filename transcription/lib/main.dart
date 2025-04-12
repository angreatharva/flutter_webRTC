import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:dio/dio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Continuous Speech Transcription',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const SpeechRecognitionPage(),
    );
  }
}

class SpeechRecognitionPage extends StatefulWidget {
  const SpeechRecognitionPage({super.key});

  @override
  State<SpeechRecognitionPage> createState() => _SpeechRecognitionPageState();
}

class _SpeechRecognitionPageState extends State<SpeechRecognitionPage> {
  final Dio _dio = Dio();
  final SpeechToText _speechToText = SpeechToText();
  bool _isListening = false;
  String _text = '';
  String _previousText = '';
  String _fullTranscription = '';
  bool _isInitialized = false;
  DateTime? _recordingStartTime;
  bool _isRecording = false;
  Timer? _restartSpeechTimer;
  List<TranscriptionSegment> _segments = [];

  @override
  void initState() {
    super.initState();
    _initializeSpeech();
  }

  @override
  void dispose() {
    _restartSpeechTimer?.cancel();
    _stopListening();
    super.dispose();
  }

  Future<void> _initializeSpeech() async {
    try {
      bool available = await _speechToText.initialize(
        onError: (error) {
          print("Speech recognition error: $error");
          // If there's an error while listening, restart listening
          if (_isRecording && (error.errorMsg.contains('error_no_match') ||
              error.errorMsg.contains('error_speech_timeout'))) {
            _restartListening();
          }
        },
        onStatus: (status) {
          print("Speech recognition status: $status");
          if (status == "done" && _isRecording) {
            // When speech recognition stops while recording is still active, restart it
            _restartListening();
          }
        },
      );
      if (available) {
        setState(() {
          _isInitialized = true;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Speech recognition not available')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error initializing speech: $e')),
      );
    }
  }

  Future<void> _requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    if (status.isGranted) {
      if (_isRecording) {
        _stopRecording();
      } else {
        _startRecording();
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission is required')),
      );
    }
  }

  void _startRecording() {
    if (!_isRecording) {
      setState(() {
        _isRecording = true;
        _recordingStartTime = DateTime.now();
        _text = '';
        _previousText = '';
        _fullTranscription = '';
        _segments = [];
      });
      _startListening();
    } else {
      _stopRecording();
    }
  }

  void _startListening() {
    if (!_isListening) {
      setState(() {
        _isListening = true;
      });

      _startSpeechRecognition();
    }
  }

  void _startSpeechRecognition() {
    try {
      _speechToText.listen(
        onResult: (result) {
          if (result.finalResult) {
            // Save the final result as previous text to maintain context
            _previousText = _text;

            // Add the segment to our list
            if (result.recognizedWords.isNotEmpty) {
              _segments.add(TranscriptionSegment(
                text: result.recognizedWords,
                timestamp: DateTime.now(),
              ));

              // Update the full transcription
              if (_fullTranscription.isEmpty) {
                _fullTranscription = result.recognizedWords;
              } else {
                _fullTranscription += ' ' + result.recognizedWords;
              }
            }
          }

          setState(() {
            // Use recognized words if available, otherwise keep previous text
            if (result.recognizedWords.isNotEmpty) {
              _text = result.recognizedWords;
            } else if (_previousText.isNotEmpty) {
              _text = _previousText;
            }
          });
        },
        listenMode: ListenMode.dictation,
        partialResults: true,
        cancelOnError: false,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
      );
    } catch (e) {
      print("Error starting speech recognition: $e");
      if (_isRecording) {
        _restartListening();
      }
    }
  }

  void _restartListening() {
    print("Restarting speech recognition");

    // Cancel existing timer if any
    _restartSpeechTimer?.cancel();

    // Stop current listening session
    if (_speechToText.isListening) {
      _speechToText.stop();
    }

    setState(() {
      _isListening = false;
    });

    // Add a small delay before restarting
    _restartSpeechTimer = Timer(const Duration(milliseconds: 500), () {
      if (_isRecording) {
        _startListening();
      }
    });
  }

  void _stopRecording() {
    if (_isRecording) {
      // Stop listening first
      _stopListening();

      // Send the full transcription to server
      _sendTranscriptionToServer();

      // Cancel timers
      _restartSpeechTimer?.cancel();

      setState(() {
        _isRecording = false;
      });
    }
  }

  void _stopListening() {
    if (_speechToText.isListening) {
      _speechToText.stop();
    }
    setState(() {
      _isListening = false;
    });
  }

  Future<void> _sendTranscriptionToServer() async {
    try {
      // Use either the full transcription or build from segments
      final textToSend = _fullTranscription.isNotEmpty
          ? _fullTranscription
          : _segments.isNotEmpty
          ? _segments.map((s) => s.text).join(' ')
          : _text;

      // If there's nothing to send, don't make the API call
      if (textToSend.isEmpty) {
        return;
      }

      print("Sending data to server: $textToSend");

      final response = await _dio.post(
        'https://ca62-210-16-113-62.ngrok-free.app/api/transcriptions',
        data: {
          'callId': 'call123',
          'speakerId': 'user789',
          'role': 'patient',
          'text': textToSend,
          'startTime': _recordingStartTime?.toIso8601String(),
          'endTime': DateTime.now().toIso8601String(),
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          validateStatus: (status) {
            return status! < 500;
          },
        ),
      );

      print("Response status: ${response.statusCode}");
      print("Response data: ${response.data}");

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transcription sent successfully')),
        );
      } else {
        print("Error status code: ${response.statusCode}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending data: ${response.statusCode}')),
        );
      }
    } catch (e) {
      print("Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending data: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Continuous Speech Transcription'),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!_isInitialized)
                const CircularProgressIndicator()
              else
                Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
                      Text(
                        _text.isEmpty ? 'Start speaking...' : _text,
                        style: const TextStyle(fontSize: 18),
                        textAlign: TextAlign.center,
                      ),
            const SizedBox(height: 10),
                      Text(
                        _isRecording
                            ? 'Recording in progress... (Data will be sent when stopped)'
                            : 'Recording stopped',
                        style: TextStyle(
                          fontSize: 14,
                          color: _isRecording ? Colors.red : Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_recordingStartTime != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            'Started: ${_recordingStartTime!.hour}:${_recordingStartTime!.minute}:${_recordingStartTime!.second}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      if (_segments.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 16.0),
                          child: Text(
                            'Segments recorded: ${_segments.length}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.green,
                            ),
                          ),
                        ),
                      if (_segments.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 16.0),
                          child: Container(
                            height: 200,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(8),
                            ),
              child: ListView.builder(
                              itemCount: _segments.length,
                              itemBuilder: (context, index) {
                                final segment = _segments[index];
                                return Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    'Segment ${index + 1}: ${segment.text}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                );
                              },
                ),
              ),
            ),
          ],
                  ),
                ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _requestMicrophonePermission,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isRecording ? Colors.red : Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: Text(_isRecording ? 'Stop Recording' : 'Start Recording'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TranscriptionSegment {
  final String text;
  final DateTime timestamp;

  TranscriptionSegment({
    required this.text,
    required this.timestamp,
  });
}