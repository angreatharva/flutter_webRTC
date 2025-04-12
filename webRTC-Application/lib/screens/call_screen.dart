import 'package:dio/dio.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/signalling.service.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

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

class _CallScreenState extends State<CallScreen> {
  final socket = SignallingService.instance.socket;
  final _localRTCVideoRenderer = RTCVideoRenderer();
  final _remoteRTCVideoRenderer = RTCVideoRenderer();
  MediaStream? _localStream;
  RTCPeerConnection? _rtcPeerConnection;
  List<RTCIceCandidate> rtcIceCadidates = [];

  bool isAudioOn = true, isVideoOn = true, isFrontCameraSelected = true;
  bool _isConnected = false; // 🔄 Connection state

  final Dio dio = Dio();

  stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _transcription = "";
  List<String> _transcriptionLog = [];

  @override
  void initState() {
    _checkMicPermission();
    _localRTCVideoRenderer.initialize();
    _remoteRTCVideoRenderer.initialize();
    _setupPeerConnection();
    _initSpeechRecognizer();
    super.initState();
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
    }
    else{
      print('Microphone permission allowed');
    }
  }


  void _initSpeechRecognizer() async {
    bool available = await _speech.initialize(
      onStatus: (val) => print('Speech status: $val'),
      onError: (val) => print('Speech error: $val'),
    );
    if (available) {
      print("Speech recognition available");
    }
    else{
      print("Speech recognition unavailable");
    }
  }

  void _listen() async {
    print("_isListening: $_isListening");
    if (!_isListening) {
      // Start listening
      bool available = await _speech.initialize(
        onStatus: (status) {
          print('_listen Speech status: $status');
          if (status == 'done' || status == 'notListening') {
            setState(() => _isListening = false);
          }
        },
        onError: (errorNotification) {
          print('Speech error: ${errorNotification.errorMsg}');
          setState(() => _isListening = false);

          // Auto-restart on timeout
          if (errorNotification.errorMsg == 'error_speech_timeout') {
            Future.delayed(Duration(milliseconds: 300), () {
              _listen();
            });
          }
        },
      );

      if (available) {
        setState(() {
          _isListening = true;
          _transcription = "";
        });

        try {
          await _speech.listen(
            onResult: (result) {
              setState(() {
                _transcription = result.recognizedWords;

                // When we get final results, add to log and send
                if (result.finalResult && _transcription.isNotEmpty) {
                  _transcriptionLog.add(_transcription);
                  sendTranscription(_transcription);
                  print("Final transcription: $_transcription");
                }
              });
            },
            listenFor: Duration(seconds: 30),
            pauseFor: Duration(seconds: 3),
            partialResults: true,
            localeId: 'en_US',
            cancelOnError: false,
          );
        } catch (e) {
          print('Listen error: $e');
          setState(() => _isListening = false);
        }
      } else {
        print("Speech recognition not available");
      }
    }
    else {
      // Stop listening
      _speech.stop();
      setState(() => _isListening = false);

      // Send any final transcription
      if (_transcription.isNotEmpty) {
        if (!_transcriptionLog.contains(_transcription)) {
          _transcriptionLog.add(_transcription);
          sendTranscription(_transcription);
        }
      }
    }
  }

  // New function to send the transcription via Dio
  Future<void> sendTranscription(String text) async {
    if (text.trim().isEmpty) return;

    final String role = widget.isDoctor ? "doctor" : "patient";
    final String speakerId = widget.isDoctor ? widget.callerId : widget.calleeId;
    final String callId = "call1";

    final Map<String, dynamic> payload = {
      "callId": callId,
      "speakerId": speakerId,
      "role": role,
      "text": text,
    };

    try {
      // Show a temporary indication that transcription is being sent
      print("📝 Sending transcription: $text");

      Response response = await dio.post(
        "https://87ed-103-110-234-188.ngrok-free.app/api/transcriptions",
        data: jsonEncode(payload),
        options: Options(
          headers: {"Content-Type": "application/json"},
          sendTimeout: Duration(seconds: 5),
          receiveTimeout: Duration(seconds: 5),
        ),
      );

      if (response.statusCode == 201) {
        print("✅ Transcription saved successfully");
      } else {
        print("❌ Failed to save transcription: ${response.data}");
      }
    } catch (error) {
      print("❌ Error posting transcription: $error");
      // Store failed transcripts to try again later if needed
    }
  }
  // A function to simulate sending a transcription.
  // In your actual implementation, this might be triggered by a transcription event.
  void _simulateTranscription() {
    print('_simulateTranscription');
    _listen();
  }

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
                if (_isListening || _transcription.isNotEmpty)
                  Positioned(
                    top: 60,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _isListening ? Icons.mic : Icons.mic_none,
                                color: _isListening ? Colors.red : Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _isListening ? "Listening..." : "Transcription",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _transcription.isEmpty ? "..." : _transcription,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
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
                )
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  IconButton(
                    icon: Icon(isAudioOn ? Icons.mic : Icons.mic_off),
                    onPressed: _toggleMic,
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
                  IconButton(
                    icon: const Icon(Icons.textsms),
                    onPressed: _simulateTranscription,
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
    _localRTCVideoRenderer.dispose();
    _remoteRTCVideoRenderer.dispose();
    _localStream?.dispose();
    _rtcPeerConnection?.dispose();
    _speech.stop();
    super.dispose();
  }
}
