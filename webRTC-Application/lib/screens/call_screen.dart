import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/api_service.dart';
import '../services/signalling.service.dart';
import 'package:speech_to_text/speech_to_text.dart';

// New class for transcription segments
class TranscriptionSegment {
  final String text;
  final DateTime timestamp;

  TranscriptionSegment({
    required this.text,
    required this.timestamp,
  });
}

class CallScreen extends StatefulWidget {
  final String callerId;
  final String calleeId;
  final dynamic offer;
  final bool isDoctor;

  const CallScreen({
    super.key,
    this.offer,
    required this.callerId,
    required this.calleeId,
    required this.isDoctor,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> with WidgetsBindingObserver {
  // Existing WebRTC related variables
  final socket = SignallingService.instance.socket;
  final _localRTCVideoRenderer = RTCVideoRenderer();
  final _remoteRTCVideoRenderer = RTCVideoRenderer();
  MediaStream? _localStream;
  RTCPeerConnection? _rtcPeerConnection;
  List<RTCIceCandidate> rtcIceCadidates = [];
  bool isAudioOn = true, isVideoOn = true, isFrontCameraSelected = true;
  bool _isConnected = false;

  // New Speech Recognition variables
  final Dio dio = Dio();
  final SpeechToText _speechToText = SpeechToText();
  bool _isListening = false;
  String _text = '';
  String _previousText = '';
  String _fullTranscription = '';
  bool _isInitialized = false;
  DateTime? _recordingStartTime;
  bool _isRecording = false;
  Timer? _restartSpeechTimer;
  Timer? _keepAliveTimer;
  List<TranscriptionSegment> _segments = [];
  int _restartAttempts = 0;
  final int _maxRestartAttempts = 10;
  bool _showTranscription = false;

  @override
  void initState() {
    _checkMicPermission();
    WidgetsBinding.instance.addObserver(this);
    _initializeSpeech();
    _localRTCVideoRenderer.initialize();
    _remoteRTCVideoRenderer.initialize();
    _setupPeerConnection();
    super.initState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (_isRecording) {
        _stopListening();
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_isRecording && !_isListening) {
        _startListening();
      }
    }
  }

  @override
  void setState(fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  void _checkMicPermission() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      print('Microphone permission denied');
    } else {
      print('Microphone permission allowed');
    }
  }

  // Initialize speech recognition
  Future<void> _initializeSpeech() async {
    try {
      // Attempt to configure audio session to disable sounds
      try {
        await SystemChannels.platform.invokeMethod<void>('flutter.disableSoundEffects', true);
      } catch (e) {
        print('Could not disable sound effects: $e');
      }

      // Initialize the speech recognition
      bool available = await _speechToText.initialize(
        onError: (error) {
          print("Speech recognition error: ${error.errorMsg}");
          if (_isRecording && (error.errorMsg.contains('error_no_match') ||
              error.errorMsg.contains('error_speech_timeout'))) {
            _restartListening();
          }
        },
        onStatus: (status) {
          print("Speech recognition status: $status");
          if (status == "done" && _isRecording) {
            _restartListening();
          }
        },
        debugLogging: true, // Enable for troubleshooting
      );

      print("Speech recognition available: $available");

      if (available) {
        setState(() {
          _isInitialized = true;
        });
      } else {
        // If not available, show an error
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Speech recognition not available')),
          );
        }
      }
    } catch (e) {
      print("Error initializing speech: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing speech: $e')),
        );
      }
    }
  }

  // Toggle speech recognition
  void _toggleSpeechRecognition() async {
    // Check if speech is initialized first
    if (!_isInitialized) {
      print("Speech recognition not initialized yet");
      await _initializeSpeech();

      if (!_isInitialized) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please wait, speech recognition is initializing')),
        );
        return;
      }
    }

    if (_isRecording) {
      _stopRecording();
    } else {
      _startRecording();
    }
  }

  // Start recording session
  void _startRecording() {
    if (!_isRecording) {
      setState(() {
        _isRecording = true;
        _recordingStartTime = DateTime.now();
        _text = '';
        _previousText = '';
        _fullTranscription = '';
        _segments = [];
        _restartAttempts = 0;
        _showTranscription = true;
      });

      // Start listening for speech
      _startListening();

      // Create a keep-alive timer
      _keepAliveTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
        if (_isRecording && !_isListening && _restartAttempts < _maxRestartAttempts) {
          print("Keep-alive check - restarting speech recognition");
          _startListening();
        }
      });
    } else {
      _stopRecording();
    }
  }

  // Start the speech recognition
  void _startListening() {
    if (!_isListening && _isInitialized) {
      try {
        setState(() {
          _isListening = true;
        });

        // Disable system sounds if possible before starting recognition
        try {
          SystemChannels.textInput.invokeMethod('TextInput.hide');
          SystemSound.play(SystemSoundType.click);
        } catch (e) {
          print('Failed to disable system sounds: $e');
        }

        // Start listening
        _speechToText.listen(
          onResult: (result) {
            print("Recognition result: ${result.recognizedWords}");
            if (result.finalResult) {
              _previousText = _text;

              if (result.recognizedWords.isNotEmpty) {
                _segments.add(TranscriptionSegment(
                  text: result.recognizedWords,
                  timestamp: DateTime.now(),
                ));

                if (_fullTranscription.isEmpty) {
                  _fullTranscription = result.recognizedWords;
                } else {
                  _fullTranscription += ' ' + result.recognizedWords;
                }
              }
            }

            setState(() {
              if (result.recognizedWords.isNotEmpty) {
                _text = result.recognizedWords;
              } else if (_previousText.isNotEmpty) {
                _text = _previousText;
              }
            });
          },
          localeId: 'en_US',
          listenMode: ListenMode.dictation,
          partialResults: true,
          cancelOnError: false,
        );
      } catch (e) {
        print("Error starting speech recognition: $e");
        setState(() {
          _isListening = false;
        });

        if (_isRecording) {
          _restartListening();
        }
      }
    } else if (!_isInitialized) {
      print("Cannot start listening - speech recognition not initialized");
      _initializeSpeech().then((_) {
        if (_isInitialized && _isRecording) {
          _startListening();
        }
      });
    }
  }

  // Restart the speech recognition
  void _restartListening() {
    print("Restarting speech recognition");

    _restartSpeechTimer?.cancel();

    if (_speechToText.isListening) {
      _speechToText.stop();
    }

    setState(() {
      _isListening = false;
    });

    _restartAttempts++;

    // Instead of stopping recording, just log the attempt count
    if (_restartAttempts >= _maxRestartAttempts) {
      print("Maximum restart attempts reached, but continuing to try");
      // Reset restart attempts to avoid integer overflow during very long sessions
      _restartAttempts = 0;
    }

    final delay = Duration(milliseconds: 500 + (_restartAttempts * 100));

    _restartSpeechTimer = Timer(delay, () {
      if (_isRecording) {
        _startListening();
      }
    });
  }

  // Stop the recording session
  void _stopRecording() {
    if (_isRecording) {
      _stopListening();
      _sendTranscriptionToServer();

      _restartSpeechTimer?.cancel();
      _keepAliveTimer?.cancel();

      setState(() {
        _isRecording = false;
      });
    }
  }

  // Stop listening for speech
  void _stopListening() {
    if (_speechToText.isListening) {
      _speechToText.stop();
    }
    setState(() {
      _isListening = false;
    });
  }

  // Send the transcription to the server
  Future<void> _sendTranscriptionToServer() async {
    try {
      final textToSend = _fullTranscription.isNotEmpty
          ? _fullTranscription
          : _segments.isNotEmpty
          ? _segments.map((s) => s.text).join(' ')
          : _text;

      if (textToSend.isEmpty) {
        return;
      }

      print("Sending data to server: $textToSend");

      final response = await dio.post(
        '${ApiService.baseUrl}/api/transcriptions',
        data: {
          'callId': widget.callerId + '_' + widget.calleeId, // Use call IDs to identify the call
          'speakerId': widget.isDoctor ? 'doctor_${widget.callerId}' : 'patient_${widget.callerId}',
          'role': widget.isDoctor ? 'doctor' : 'patient',
          'text': textToSend,
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          validateStatus: (status) {
            return status! < 500;
          },
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
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

  // Toggle transcription visibility
  void _toggleTranscriptionVisibility() {
    setState(() {
      _showTranscription = !_showTranscription;
    });
  }

  // WebRTC setup code
  _setupPeerConnection() async {
    print("🔧 Creating Peer Connection...");
    _rtcPeerConnection = await createPeerConnection({
      'iceServers': [
        {
          'urls': [
            'stun:stun1.l.google.com:19302',
            'stun:stun2.l.google.com:19302'
          ]
        },
        {
          'urls': "stun:stun.relay.metered.ca:80",
        },
        {
          'urls': "turn:global.relay.metered.ca:80",
          'username': "c0bff27b06d608b3c25fd6e9",
          'credential': "1nviIBKZFFqW64IH",
        },
        {
          'urls': "turn:global.relay.metered.ca:80?transport=tcp",
          'username': "c0bff27b06d608b3c25fd6e9",
          'credential': "1nviIBKZFFqW64IH",
        },
        {
          'urls': "turn:global.relay.metered.ca:443",
          'username': "c0bff27b06d608b3c25fd6e9",
          'credential': "1nviIBKZFFqW64IH",
        },
        {
          'urls': "turns:global.relay.metered.ca:443?transport=tcp",
          'username': "c0bff27b06d608b3c25fd6e9",
          'credential': "1nviIBKZFFqW64IH",
        },
      ]
    });

    print("🌐 Peer connection created. TURN/STUN setup done!");

    _rtcPeerConnection!.onIceConnectionState = (state) {
      print("📶 ICE Connection State: $state");
    };

    _rtcPeerConnection!.onConnectionState = (state) {
      print("🔄 PeerConnectionState: $state");
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        print("✅ Connected to peer successfully! 🎉");
        setState(() => _isConnected = true);
      }
    };

    _rtcPeerConnection!.onTrack = (event) {
      print("🎥 Remote track received!");
      _remoteRTCVideoRenderer.srcObject = event.streams[0];
      setState(() {
        _isConnected = true;
      });
    };

    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': isAudioOn,
      'video': isVideoOn
          ? {'facingMode': isFrontCameraSelected ? 'user' : 'environment'}
          : false,
    });

    _localStream!.getTracks().forEach((track) {
      _rtcPeerConnection!.addTrack(track, _localStream!);
    });

    _localRTCVideoRenderer.srcObject = _localStream;
    print("📷 Local stream setup done");

    if (widget.offer != null) {
      print("📞 Incoming call detected...");

      socket!.on("IceCandidate", (data) {
        print("❄️ ICE Candidate received");
        String candidate = data["iceCandidate"]["candidate"];
        String sdpMid = data["iceCandidate"]["id"];
        int sdpMLineIndex = data["iceCandidate"]["label"];

        _rtcPeerConnection!.addCandidate(RTCIceCandidate(
          candidate,
          sdpMid,
          sdpMLineIndex,
        ));
      });

      await _rtcPeerConnection!.setRemoteDescription(
        RTCSessionDescription(widget.offer["sdp"], widget.offer["type"]),
      );

      print("📩 Remote offer set. Creating answer...");

      RTCSessionDescription answer = await _rtcPeerConnection!.createAnswer();
      await _rtcPeerConnection!.setLocalDescription(answer);

      socket!.emit("answerCall", {
        "callerId": widget.callerId,
        "sdpAnswer": answer.toMap(),
      });

      print("📨 Answer sent to caller");
    } else {
      print("📤 Outgoing call... Creating offer");

      _rtcPeerConnection!.onIceCandidate =
          (RTCIceCandidate candidate) => rtcIceCadidates.add(candidate);

      socket!.on("callAnswered", (data) async {
        print("📥 Call answered. Setting remote description");

        await _rtcPeerConnection!.setRemoteDescription(
          RTCSessionDescription(
            data["sdpAnswer"]["sdp"],
            data["sdpAnswer"]["type"],
          ),
        );

        for (RTCIceCandidate candidate in rtcIceCadidates) {
          socket!.emit("IceCandidate", {
            "calleeId": widget.calleeId,
            "iceCandidate": {
              "id": candidate.sdpMid,
              "label": candidate.sdpMLineIndex,
              "candidate": candidate.candidate
            }
          });
        }
        print("🚀 All ICE candidates sent");
      });

      RTCSessionDescription offer = await _rtcPeerConnection!.createOffer();
      await _rtcPeerConnection!.setLocalDescription(offer);

      socket!.emit('makeCall', {
        "calleeId": widget.calleeId,
        "sdpOffer": offer.toMap(),
      });

      print("📞 Offer sent to callee");
    }
  }

  _leaveCall() {
    print("📴 Leaving call...");
    if (_isRecording) {
      _stopRecording();
    }
    Navigator.pop(context);
  }

  _toggleMic() {
    isAudioOn = !isAudioOn;
    _localStream?.getAudioTracks().forEach((track) {
      track.enabled = isAudioOn;
    });
    print(isAudioOn ? "🎤 Mic ON" : "🔇 Mic OFF");
    setState(() {});
  }

  _toggleCamera() {
    isVideoOn = !isVideoOn;
    _localStream?.getVideoTracks().forEach((track) {
      track.enabled = isVideoOn;
    });
    print(isVideoOn ? "📸 Camera ON" : "📷 Camera OFF");
    setState(() {});
  }

  _switchCamera() {
    isFrontCameraSelected = !isFrontCameraSelected;
    _localStream?.getVideoTracks().forEach((track) {
      track.switchCamera();
    });
    print("🔁 Switched Camera");
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(title: const Text("P2P Call App")),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(children: [
                RTCVideoView(
                  _remoteRTCVideoRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
                // Connection status indicator
                Positioned(
                  top: 16,
                  left: 0,
                  right: 0,
                  child: !_isConnected
                      ? Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        "🔗 Connecting...",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  )
                      : Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade700,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        "✅ Connected",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
                // Local video feed
                Positioned(
                  right: 20,
                  bottom: 20,
                  child: SizedBox(
                    height: 150,
                    width: 120,
                    child: RTCVideoView(
                      _localRTCVideoRenderer,
                      mirror: isFrontCameraSelected,
                      objectFit:
                      RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    ),
                  ),
                ),
                // Speech recognition status and transcription
                if (_showTranscription)
                  Positioned(
                    left: 20,
                    top: 80,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              if (_isRecording && _isListening)
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              SizedBox(width: 2),
                              Text(
                                _isRecording
                                    ? "Recording..."
                                    : "Recording stopped",
                                style: TextStyle(
                                  color: _isRecording ? Colors.red : Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Spacer(),
                              IconButton(
                                icon: Icon(Icons.close, color: Colors.white, size: 16),
                                padding: EdgeInsets.zero,
                                constraints: BoxConstraints(),
                                onPressed: _toggleTranscriptionVisibility,
                              ),
                            ],
                          ),
                          SizedBox(height: 4),
                          Text(
                            _text.isEmpty ? 'Listening...' : _text,
                            style: TextStyle(color: Colors.white),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  IconButton(
                    icon: Icon(isAudioOn ? Icons.mic_off : Icons.mic),
                    onPressed: _toggleMic,
                  ),
                  IconButton(
                    icon: Icon(_isRecording
                        ? Icons.record_voice_over
                        : Icons.voice_over_off),
                    color: _isRecording ? Colors.red : null,
                    onPressed: _toggleSpeechRecognition,
                    tooltip: _isRecording
                        ? 'Stop Transcription'
                        : 'Start Transcription',
                  ),
                  IconButton(
                    icon: const Icon(Icons.call_end),
                    iconSize: 30,
                    color: Colors.red,
                    onPressed: _leaveCall,
                  ),
                  IconButton(
                    icon: const Icon(Icons.cameraswitch),
                    onPressed: _switchCamera,
                  ),
                  IconButton(
                    icon: Icon(
                        isVideoOn ? Icons.videocam : Icons.videocam_off),
                    onPressed: _toggleCamera,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    print("🧹 Disposing resources");
    WidgetsBinding.instance.removeObserver(this);
    _localRTCVideoRenderer.dispose();
    _remoteRTCVideoRenderer.dispose();
    _localStream?.dispose();
    _rtcPeerConnection?.dispose();
    _restartSpeechTimer?.cancel();
    _keepAliveTimer?.cancel();
    _stopListening();
    super.dispose();
  }
}