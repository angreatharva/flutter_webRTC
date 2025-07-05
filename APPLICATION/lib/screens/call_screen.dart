import 'dart:async';
import 'dart:typed_data';
import 'dart:convert'; // for base64Encode
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:get/get.dart' as getx;
import '../controllers/user_controller.dart';
import '../services/signalling.service.dart';
import '../controllers/calling_controller.dart';
import '../utils/theme_constants.dart';
import '../plugins/audio_forker/audio_forker.dart';
import 'session_summary_screen.dart';

class CallScreen extends StatefulWidget {
  final String callerId;
  final String calleeId;
  final dynamic offer;
  final bool isDoctor;
  final String? requestId;

  const CallScreen({
    super.key,
    this.offer,
    required this.callerId,
    required this.calleeId,
    required this.isDoctor,
    this.requestId,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> with WidgetsBindingObserver {
  // WebRTC related variables
  final socket = SignallingService.instance.socket;
  final _localRTCVideoRenderer = RTCVideoRenderer();
  final _remoteRTCVideoRenderer = RTCVideoRenderer();
  MediaStream? _localStream;
  RTCPeerConnection? _rtcPeerConnection;
  List<RTCIceCandidate> rtcIceCadidates = [];
  bool isAudioOn = true, isVideoOn = true, isFrontCameraSelected = true;
  bool _isConnected = false;
  bool _webrtcInitialized = false;
  
  // Audio forking for transcription
  bool _isTranscribing = false;
  StreamSubscription<Uint8List>? _audioStreamSub;

  // UI variables
  final Color _primaryColor = const Color(0xFF2A7DE1); // Medical blue
  final Color _accentColor = const Color(0xFF1E5BB6); // Darker medical blue
  final Color _backgroundColor = const Color(0xFFF5F9FC); // Light blue-tinted white
  final Color _secondaryColor = const Color(0xFF10B981); // Teal/green for positive actions
  final Color _dangerColor = const Color(0xFFEF4444); // Red for ending call/negative actions
  Timer? _callDurationTimer;
  String _callDuration = "00:00";
  DateTime? _callStartTime;
  
  // Calling controller
  final CallingController _callingController = getx.Get.find<CallingController>();

  final UserController _userController = getx.Get.find<UserController>();


  @override
  void initState() {
    _checkMicPermission();
    WidgetsBinding.instance.addObserver(this);
    _localRTCVideoRenderer.initialize();
    _remoteRTCVideoRenderer.initialize();
    _setupPeerConnection();
    _startCallTimer();
    _initializeAudioForker();
    _setupEndCallListener();
    super.initState();
  }
  
  // Initialize the audio forker for transcription (static API)
  void _initializeAudioForker() async {
    final success = await AudioForker.initialize();
      if (success) {
      debugPrint('🎤 AudioForker (native) initialized successfully');
      // Listen to audio data stream for debugging
      int? _lastChunkTime;
      _audioStreamSub = AudioForker.audioDataStream.listen((chunk) {
        final now = DateTime.now().millisecondsSinceEpoch;
        int delta = _lastChunkTime == null ? 0 : (now - _lastChunkTime!);
        _lastChunkTime = now;
        debugPrint('DART: Sending audio chunk of \\${chunk.length} bytes, first 10: \\${chunk.take(10).toList()}, time since last chunk: \\${delta}ms');
        socket?.emit('audioChunk', {
          'callId': widget.callerId,
          'audioChunk': base64Encode(chunk),
          'transcribe': true,
          'timestamp': now,
        });
      });
      } else {
      debugPrint('❌ Failed to initialize AudioForker (native)');
      }
  }

  void _startCallTimer() {
    _callStartTime = DateTime.now();
    _callDurationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        final duration = DateTime.now().difference(_callStartTime!);
        setState(() {
          _callDuration = _formatDuration(duration);
        });
      }
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  void setState(fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  void _checkMicPermission() async {
    // Request all necessary permissions for WebRTC
    Map<Permission, PermissionStatus> statuses = await [
      Permission.microphone,
      Permission.camera,
      Permission.bluetooth,
      Permission.bluetoothConnect,
      Permission.storage,
    ].request();
    
    if (statuses[Permission.microphone] != PermissionStatus.granted) {
      debugPrint('Microphone permission denied: ${statuses[Permission.microphone]}');
    } else {
      debugPrint('Microphone permission allowed');
    }
    
    // Log all permission statuses
    statuses.forEach((permission, status) {
      debugPrint('Permission $permission: $status');
    });
  }

  // WebRTC setup code
  Future<void> _setupPeerConnection() async {
    debugPrint("🔧 Creating Peer Connection...");
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

    debugPrint("🌐 Peer connection created. TURN/STUN setup done!");

    _rtcPeerConnection!.onIceConnectionState = (state) {
      debugPrint("📶 ICE Connection State: $state");
    };

    _rtcPeerConnection!.onConnectionState = (state) {
      debugPrint("🔄 PeerConnectionState: $state");
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        debugPrint("✅ Connected to peer successfully! 🎉");
        setState(() => _isConnected = true);
      }
    };

    _rtcPeerConnection!.onTrack = (event) {
      debugPrint("🎥 Remote track received!");
      _remoteRTCVideoRenderer.srcObject = event.streams[0];
      setState(() {
        _isConnected = true;
      });
    };

    // Configure optimal audio settings
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
        'sampleRate': 44100,
      },
      'video': isVideoOn
          ? {'facingMode': isFrontCameraSelected ? 'user' : 'environment'}
          : false,
    });

    _localStream!.getTracks().forEach((track) {
      _rtcPeerConnection!.addTrack(track, _localStream!);
    });

    _localRTCVideoRenderer.srcObject = _localStream;
    debugPrint("📷 Local stream setup done");

    if (widget.offer != null) {
      debugPrint("📞 Incoming call detected...");

      // Remove any previous listeners before adding new ones
      socket?.off("IceCandidate");
      socket?.on("IceCandidate", (data) {
        debugPrint("❄️ ICE Candidate received");
        String candidate = data["iceCandidate"]["candidate"];
        String sdpMid = data["iceCandidate"]["id"];
        int sdpMLineIndex = data["iceCandidate"]["label"];
        if (_rtcPeerConnection != null) {
          _rtcPeerConnection!.addCandidate(RTCIceCandidate(
            candidate,
            sdpMid,
            sdpMLineIndex,
          ));
        } else {
          debugPrint("ICE candidate received but _rtcPeerConnection is null. Ignoring.");
        }
      });

      await _rtcPeerConnection!.setRemoteDescription(
        RTCSessionDescription(widget.offer["sdp"], widget.offer["type"]),
      );

      debugPrint("📩 Remote offer set. Creating answer...");

      RTCSessionDescription answer = await _rtcPeerConnection!.createAnswer();
      await _rtcPeerConnection!.setLocalDescription(answer);

      socket!.emit("answerCall", {
        "callerId": widget.callerId,
        "sdpAnswer": answer.toMap(),
      });

      debugPrint("📨 Answer sent to caller");
    } else {
      debugPrint("📤 Outgoing call... Creating offer");

      _rtcPeerConnection!.onIceCandidate =
          (RTCIceCandidate candidate) => rtcIceCadidates.add(candidate);

      // Remove any previous listeners before adding new ones
      socket?.off("callAnswered");
      socket?.on("callAnswered", (data) async {
        debugPrint("📥 Call answered. Setting remote description");
        if (_rtcPeerConnection != null) {
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
          debugPrint("🚀 All ICE candidates sent");
        } else {
          debugPrint("callAnswered received but _rtcPeerConnection is null. Ignoring.");
        }
      });

      RTCSessionDescription offer = await _rtcPeerConnection!.createOffer();
      await _rtcPeerConnection!.setLocalDescription(offer);

      // Get user information for the call
      final userController = getx.Get.find<UserController>();
      String callerName = 'Unknown';
      
      // Set appropriate name based on user type
      if (userController.user.value != null) {
        callerName = userController.userName;
        
        // Add Dr. prefix if this is a doctor
        if (widget.isDoctor) {
          callerName = "Dr. $callerName";
        }
      }
      
      // For doctors, show disclaimer dialog before sending SDP offer
      if (widget.isDoctor) {
        await _showDisclaimerDialog(offer.toMap(), callerName);
      } else {
        // For patients, directly make the call without showing disclaimer
        _callingController.makeCall(
          widget.calleeId,
          offer.toMap(),
          callerName
        );
        debugPrint("📞 Offer sent to callee with name: $callerName");
      }

    }

    // Mark WebRTC as initialized and ready
    _webrtcInitialized = true;
  }

  _leaveCall() {
    _stopTranscription();
    _showEndCallDialog();
  }
  
  // Show disclaimer dialog for doctors before sending SDP offer
  Future<void> _showDisclaimerDialog(Map<String, dynamic> offerMap, String callerName) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap button to proceed
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Medical Disclaimer',
            style: TextStyle(
              color: ThemeConstants.mainColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                  'By proceeding with this call, you acknowledge that:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Text('1. This call may be recorded for quality and training purposes.'),
                SizedBox(height: 5),
                Text('2. Patient information shared during this call is confidential and protected by applicable privacy laws.'),
                SizedBox(height: 5),
                Text('3. This platform is not intended for emergency medical situations.'),
                SizedBox(height: 10),
                Text(
                  'Do you agree to proceed with the call?',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Okay',
                style: TextStyle(
                  color: ThemeConstants.mainColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () {
                // Close the dialog
                Navigator.of(context).pop();
                
                // Send the SDP offer to the patient
                _callingController.makeCall(
                  widget.calleeId,
                  offerMap,
                  callerName
                );
                
                debugPrint("📞 Offer sent to callee with name: $callerName after disclaimer acceptance");
              },
            ),
          ],
        );
      },
    );
  }
  
  // Clean up resources when call ends
  Future<void> _cleanupCall() async {
    // 1. Stop transcription (if running, this also stops native audio forker)
    await _stopTranscription();

    // 2. Cancel audio stream subscription and dispose audio forker
    await _audioStreamSub?.cancel();
    await AudioForker.dispose();

    // 3. Stop timers
    _callDurationTimer?.cancel();

    // 4. Remove all socket listeners related to this call
    socket?.off("IceCandidate");
    socket?.off("callAnswered");
    // Add more .off() as needed for other listeners

    // 5. Close WebRTC connection and dispose video renderers
    _localStream?.getTracks().forEach((track) => track.stop());
    await _rtcPeerConnection?.close();
    await _localRTCVideoRenderer.dispose();
    await _remoteRTCVideoRenderer.dispose();

    // 6. Null out references
    _localStream = null;
    _rtcPeerConnection = null;
    _webrtcInitialized = false;

    // 7. Mark call as completed if needed
    if (widget.isDoctor && widget.requestId != null) {
      await _completeCallRequest();
    }
  }
  
  // Mark call as completed on the server
  Future<void> _completeCallRequest() async {
    if (widget.requestId != null) {
      await _callingController.updateCallRequestStatus(
        widget.requestId!,
        'completed'
      );
      debugPrint("📝 Call marked as completed on server");
    }
  }
  
  // Start audio transcription using static AudioForker API
  _startTranscription() async {
    if (!_isTranscribing) {
      // 1. Tell server to start transcription session
      socket?.emit('startTranscription', {
        'callId': widget.callerId,
        'languageCode': 'en-US',
        'saveToWav': true,
        'sampleRate': 44100,
        'channels': 2,
        'encoding': 'LINEAR16',
      });
      debugPrint('DART: Sent startTranscription with 44100/2');

      // 2. Start native audio forker
      await AudioForker.startAudioForking();
      setState(() {
        _isTranscribing = true;
      });
      debugPrint('📝 Audio transcription started');
    }
  }
  
  // Stop audio transcription using static AudioForker API
  _stopTranscription() async {
    if (_isTranscribing) {
      // 4. Tell server to stop transcription session
      socket?.emit('stopTranscription', {
        'callId': widget.callerId,
      });
      debugPrint('DART: Sent stopTranscription');
      await AudioForker.stopAudioForking();
      setState(() {
        _isTranscribing = false;
      });
      debugPrint('🛑 Audio transcription stopped');
    }
  }

  _showEndCallDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('End Consultation'),
          content: const Text('Are you sure you want to end this consultation?'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
              },
              child: Text('Cancel', style: TextStyle(color: _primaryColor)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _dangerColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () async {
                Navigator.of(context).pop(); // Close dialog
                
                // If doctor, notify the patient that the call is being ended
                if (widget.isDoctor) {
                  // Emit an event to notify the patient that the call is being ended
                  socket?.emit('endCall', {
                    'calleeId': widget.calleeId,
                    'message': 'The doctor has ended the consultation.'
                  });
                  debugPrint('📞 Doctor ended call, notifying patient');
                } else {
                  // If patient, notify the doctor that the call is being ended
                  socket?.emit('endCall', {
                    'calleeId': widget.calleeId,
                    'message': 'The patient has left the consultation.'
                  });
                  debugPrint('📞 Patient left call, notifying doctor');
                }
                
                // Clean up resources
                await _cleanupCall();
                
                // If doctor, refresh pending calls first
                if (widget.isDoctor && widget.requestId != null) {
                  await _callingController.fetchPendingRequests(_callingController.doctorId.value);
                }
                
                // Leave call screen
                getx.Get.off(() => SessionSummaryScreen(
                  callId: widget.requestId ?? widget.callerId,
                  selfId: _userController.userId,
                  otherId: widget.isDoctor ? widget.calleeId : widget.callerId,
                  isDoctor: widget.isDoctor,
                ));
              },
              child: const Text('End Call'),
            ),
          ],
        );
      },
    );
  }

  _toggleMic() {
    // Update WebRTC audio track state
    isAudioOn = !isAudioOn;
    _localStream?.getAudioTracks().forEach((track) {
      track.enabled = isAudioOn;
    });

    debugPrint(isAudioOn ? "🎤 Mic ON" : "🔇 Mic OFF");
    setState(() {});
  }

  _toggleCamera() {
    isVideoOn = !isVideoOn;
    _localStream?.getVideoTracks().forEach((track) {
      track.enabled = isVideoOn;
    });
    debugPrint(isVideoOn ? "📸 Camera ON" : "📷 Camera OFF");
    setState(() {});
  }

  _switchCamera() {
    isFrontCameraSelected = !isFrontCameraSelected;
    _localStream?.getVideoTracks().forEach((track) {
      track.switchCamera();
    });
    debugPrint("🔁 Switched Camera");
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _leaveCall();
        return false;
      },
      child: Scaffold(
        backgroundColor: _backgroundColor,
        body: SafeArea(
          child: Stack(
            children: [
              // Main content - remote video and local video
              Column(
                children: [
                  // Remote Video
                  Expanded(
                    flex: 5,
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.vertical(
                          bottom: Radius.circular(getx.Get.width * 0.04),
                        ),
                      ),
                      child: Stack(
                        children: [
                          // Main remote video
                          Center(
                            child: RTCVideoView(
                              _remoteRTCVideoRenderer,
                              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                              mirror: false,
                            ),
                          ),
                          
                          // Status indicator overlay
                          if (!_isConnected)
                            Container(
                              color: Colors.black54,
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: getx.Get.width * 0.14,
                                      height: getx.Get.width * 0.14,
                                      child: CircularProgressIndicator(
                                        color: _primaryColor,
                                        strokeWidth: getx.Get.width * 0.01,
                                      ),
                                    ),
                                    SizedBox(height: getx.Get.height * 0.02),
                                    Text(
                                      'Connecting to the call...',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: getx.Get.width * 0.045,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            
                          // Call duration and user name header
                          Positioned(
                            top: getx.Get.height * 0.02,
                            left: 0,
                            right: 0,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: getx.Get.width * 0.04,
                                vertical: getx.Get.height * 0.01,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: getx.Get.width * 0.03, 
                                      vertical: getx.Get.height * 0.005
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black45,
                                      borderRadius: BorderRadius.circular(getx.Get.width * 0.04),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.timer,
                                          color: Colors.white,
                                          size: getx.Get.width * 0.04,
                                        ),
                                        SizedBox(width: getx.Get.width * 0.01),
                                        Text(
                                          _callDuration,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: getx.Get.width * 0.035,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: getx.Get.width * 0.03, 
                                      vertical: getx.Get.height * 0.005
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black45,
                                      borderRadius: BorderRadius.circular(getx.Get.width * 0.04),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          widget.isDoctor ? Icons.person : Icons.medical_services,
                                          color: _primaryColor,
                                          size: getx.Get.width * 0.04,
                                        ),
                                        SizedBox(width: getx.Get.width * 0.01),
                                        Text(
                                          widget.isDoctor ? 'Patient' : 'Doctor',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: getx.Get.width * 0.035,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
                          // Local video thumbnail
                          Positioned(
                            right: getx.Get.width * 0.03,
                            bottom: getx.Get.height * 0.15,
                            child: Container(
                              width: getx.Get.width * 0.35,
                              height: getx.Get.height * 0.25,
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(getx.Get.width * 0.03),
                                border: Border.all(color: _primaryColor, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 10,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(getx.Get.width * 0.03),
                                child: isVideoOn
                                    ? RTCVideoView(
                                        _localRTCVideoRenderer,
                                        mirror: isFrontCameraSelected,
                                        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                                      )
                                    : Center(
                                        child: Icon(
                                          Icons.videocam_off,
                                          color: Colors.white,
                                          size: getx.Get.width * 0.08,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              
              // Call controls section
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  padding: EdgeInsets.all(getx.Get.width * 0.04),
                  margin: EdgeInsets.only(
                    bottom: getx.Get.height * 0.03, 
                    left: getx.Get.width * 0.03, 
                    right: getx.Get.width * 0.03
                  ),
                  decoration: BoxDecoration(
                    color: ThemeConstants.mainColor,
                    borderRadius: BorderRadius.circular(getx.Get.width * 0.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Mic toggle
                      _buildControlButton(
                        icon: isAudioOn ? Icons.mic : Icons.mic_off,
                        color: isAudioOn ?  ThemeConstants.mainColor : Color(0XFF9A9D9A),
                        onPressed: _toggleMic,
                        tooltip: isAudioOn ? 'Mute Microphone' : 'Unmute Microphone',
                      ),
                      
                      // Camera toggle
                      _buildControlButton(
                        icon: isVideoOn ? Icons.videocam : Icons.videocam_off,
                        color: isVideoOn ? ThemeConstants.mainColor : Color(0XFF9A9D9A),
                        onPressed: _toggleCamera,
                        tooltip: isVideoOn ? 'Turn Off Camera' : 'Turn On Camera',
                      ),
                      
                      // Transcription toggle
                      _buildControlButton(
                        icon: _isTranscribing ? Icons.record_voice_over : Icons.voice_over_off,
                        color: _isTranscribing ? _secondaryColor : Color(0XFF9A9D9A),
                        onPressed: _isTranscribing ? _stopTranscription : _startTranscription,
                        tooltip: _isTranscribing ? 'Stop Transcription' : 'Start Transcription',
                      ),
                      
                      // Camera flip
                      _buildControlButton(
                        icon: Icons.switch_camera,
                        color: ThemeConstants.mainColor,
                        onPressed: _switchCamera,
                        tooltip: 'Switch Camera',
                      ),
                      
                      // End call
                      _buildControlButton(
                        icon: Icons.call_end,
                        color: _dangerColor,
                        onPressed: _leaveCall,
                        tooltip: 'End Call',
                        isEndCall: true,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required String tooltip,
    bool isEndCall = false,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(getx.Get.width * 0.05),
      child: Container(
        height: getx.Get.width * 0.15,
        width: getx.Get.width * 0.15,
        decoration: BoxDecoration(
          color: isEndCall ? color : (color == ThemeConstants.mainColor ? ThemeConstants.white : ThemeConstants.mainColorInActive),
          borderRadius: BorderRadius.circular(getx.Get.width * 0.12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: EdgeInsets.all(getx.Get.width * 0.025),
        child: Icon(
          icon,
          color: isEndCall ? Colors.white : color,
          size: getx.Get.width * 0.06,
        ),
      ),
    );
  }

  // Set up listener for end call event from the other party
  void _setupEndCallListener() {
    socket?.off('endCall'); // Remove any existing listeners
    socket?.on('endCall', (data) {
      debugPrint('📞 Call ended by other party: ${data['message']}');
      
      // Show a dialog to inform the user that the call has been ended
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Call Ended'),
            content: Text(data['message'] ?? 'The call has been ended by the other party.'),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () async {
                  Navigator.of(context).pop(); // Close dialog
                  
                  // Clean up resources
                  await _cleanupCall();
                  
                  // Leave call screen
                  getx.Get.off(() => SessionSummaryScreen(
                    callId: widget.requestId ?? widget.callerId,
                    selfId: _userController.userId,
                    otherId: widget.isDoctor ? widget.calleeId : widget.callerId,
                    isDoctor: widget.isDoctor,
                  ));
                },
                child: const Text('Okay'),
              ),
            ],
          );
        },
      );
    });
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _callDurationTimer?.cancel();
    _localStream?.getTracks().forEach((track) => track.stop());
    _rtcPeerConnection?.close();
    _localRTCVideoRenderer.dispose();
    _remoteRTCVideoRenderer.dispose();
    // Clean up audio forker (static API)
    _audioStreamSub?.cancel();
    AudioForker.dispose();
    // Remove socket listeners
    socket?.off('endCall');
    // Remove all socket listeners
    socket?.off("IceCandidate");
    socket?.off("callAnswered");
    // Add more .off() as needed for other listeners
    super.dispose();
  }

  // Join Call (handles both outgoing and incoming calls)
  void _joinCall({
    required String callerId,
    required String calleeId,
    dynamic offer,
    String? requestId,
  }) {
    // Navigate to call screen
    getx.Get.to(() => CallScreen(
      callerId: callerId,
      calleeId: calleeId,
      offer: offer,
      isDoctor: _userController.isDoctor,
      requestId: requestId,
    ));
    
    // Clear incoming call offer
    _callingController.clearIncomingCall();
  }
}