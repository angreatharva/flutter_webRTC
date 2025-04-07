import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/signalling.service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'dart:convert';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:cross_file/cross_file.dart';

class CallScreen extends StatefulWidget {
  final String callerId, calleeId;
  final dynamic offer;
  final bool isDoctor; // Add this to identify if user is doctor (caller) or patient (callee)

  const CallScreen({
    super.key,
    this.offer,
    required this.callerId,
    required this.calleeId,
    this.isDoctor = false, // Default to doctor role
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  // socket instance
  final socket = SignallingService.instance.socket;

  // videoRenderer for localPeer
  final _localRTCVideoRenderer = RTCVideoRenderer();

  // videoRenderer for remotePeer
  final _remoteRTCVideoRenderer = RTCVideoRenderer();

  // mediaStream for localPeer
  MediaStream? _localStream;

  // RTC peer connection
  RTCPeerConnection? _rtcPeerConnection;

  // list of rtcCandidates to be sent over signalling
  List<RTCIceCandidate> rtcIceCadidates = [];

  // for STT
  late stt.SpeechToText _speech;
  bool _speechAvailable = false;
  bool _isListening = false;

  // for transcription storage
  String _completeTranscriptText = '';
  // for captions
  String _localTranscript = '';
  String _remoteTranscript = '';

  // Complete transcript history
  List<TranscriptEntry> _transcriptHistory = [];

  // for WebRTC data channel
  RTCDataChannel? _transcriptionChannel;

  // media status
  bool isAudioOn = true, isVideoOn = true, isFrontCameraSelected = true;

  // Is transcript expanded view
  bool _showFullTranscript = false;

  // For tracking data channel state
  bool _isDataChannelOpen = false;

  @override
  void initState() {
    super.initState();

    _localRTCVideoRenderer.initialize();
    _remoteRTCVideoRenderer.initialize();

    _initSpeech().then((_) {
      debugPrint("STT available? $_speechAvailable");
      if (_speechAvailable) {
        // now kick off WebRTC
        _setupPeerConnection();
      } else {
        debugPrint("Speech-to-Text not available or permission denied");
      }
    });
  }

  @override
  void setState(fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  Future<void> _initSpeech() async {
    if (await Permission.microphone.request().isDenied) {
      debugPrint("🎤 Mic permission denied");
      return;
    }
    _speech = stt.SpeechToText();
    _speechAvailable = await _speech.initialize();
    setState(() {});

    if (_speechAvailable) {
      debugPrint("🎤 STT ready – starting quick test…");
    } else {
      debugPrint("⚠️ Speech recognition not available.");
      debugPrint("⚠️ STT unavailable or permission denied");
    }
  }

  void _startListening() {
    if (!_speechAvailable || _isListening) {
      debugPrint("Cannot start STT—no permission or unavailable or already listening");
      return;
    }

    _isListening = true;
    debugPrint("➡️ Starting STT…");

    _speech.listen(
      onResult: (result) {
        // Only send if we have content
        if (result.recognizedWords.isEmpty) return;

        // 1) Log to console with more details
        debugPrint("📝 STT result: \"${result.recognizedWords}\" (final: ${result.finalResult})");

        // 2) Update UI
        setState(() => _localTranscript = result.recognizedWords);

        // 3) Send over the data channel
        if (_transcriptionChannel?.state == RTCDataChannelState.RTCDataChannelOpen) {
          // Create a transcript message with metadata
          final message = jsonEncode({
            'text': result.recognizedWords,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'isDoctor': widget.isDoctor,
            'isFinal': result.finalResult,
          });

          _transcriptionChannel!.send(RTCDataChannelMessage(message));

          // Add to local transcript history for both final and non-final results (improved)
          if (result.recognizedWords.length > 5) {  // Only add meaningful phrases
            _addToTranscriptHistory(
              result.recognizedWords,
              widget.isDoctor,
              DateTime.now(),
            );
          }
        } else {
          debugPrint("❌ Data channel not open, can't send transcript");
        }

        // If it's final, we can consider restarting for continuous recognition
        if (result.finalResult) {
          _isListening = false;
          if (mounted) {
            Future.delayed(const Duration(milliseconds: 300), () {
              _startListening();
            });
          }
        }
      },
      onSoundLevelChange: (level) {
        // Optional: see if mic picks up anything at very high levels
        if (level > 8.0) {
          debugPrint("🔊 High sound level: $level");
        }
      },
      partialResults: true,
      listenMode: stt.ListenMode.dictation,
      listenFor: const Duration(seconds: 30), // Listen in chunks
      pauseFor: const Duration(seconds: 2),   // Brief pause before restarting
      cancelOnError: false,
    );
  }

  void _stopListening() {
    if (_isListening) {
      _speech.stop();
      _isListening = false;
    }
  }

  void _addToTranscriptHistory(String text, bool isDoctor, DateTime timestamp) {
    if (text.trim().isEmpty) return;

    // Debug print to see when entries are added
    debugPrint("Adding to transcript history: '$text' from ${isDoctor ? 'Doctor' : 'Patient'}");

    setState(() {
      // Add to transcript history list
      _transcriptHistory.add(TranscriptEntry(
        text: text,
        isDoctor: isDoctor,
        timestamp: timestamp,
      ));

      // Also update the text-based transcript
      final speaker = isDoctor ? 'Doctor' : 'Patient';
      final timeStr = _formatTime(timestamp);
      _completeTranscriptText += '[$timeStr] $speaker: $text\n';

      // Debug print count
      debugPrint("Transcript history size: ${_transcriptHistory.length}");
      debugPrint("Complete transcript length: ${_completeTranscriptText.length} chars");
    });
  }

  Future<void> _setupPeerConnection() async {
    // Create peer connection
    _rtcPeerConnection = await createPeerConnection({
      'iceServers': [
        {
          'urls': [
            'stun:stun1.l.google.com:19302',
            'stun:stun2.l.google.com:19302',
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

    // Add ICE candidate handler
    _rtcPeerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      if (widget.offer == null) {
        // Store ICE candidates if we're the caller
        rtcIceCadidates.add(candidate);
      } else {
        // Send ICE candidates directly if we're the callee
        socket!.emit("IceCandidate", {
          "callerId": widget.callerId,
          "iceCandidate": {
            "id": candidate.sdpMid,
            "label": candidate.sdpMLineIndex,
            "candidate": candidate.candidate
          }
        });
      }
    };

    // 2) Set up transcription data channel (caller side)
    if (widget.offer == null) { // this is the caller/doctor
      debugPrint("Creating data channel as caller (doctor)");
      _transcriptionChannel = await _rtcPeerConnection!
          .createDataChannel('transcription', RTCDataChannelInit());

      _setupTranscriptionChannel(_transcriptionChannel!);
    }

    // 3) Listen for incoming data channel (callee side)
    _rtcPeerConnection!.onDataChannel = (RTCDataChannel channel) {
      debugPrint("Received data channel: ${channel.label}");
      if (channel.label == 'transcription') {
        _transcriptionChannel = channel;
        _setupTranscriptionChannel(channel);
      }
    };

    // listen for remotePeer mediaTrack event
    _rtcPeerConnection!.onTrack = (event) {
      debugPrint("Received remote track");
      _remoteRTCVideoRenderer.srcObject = event.streams[0];
      setState(() {});
    };

    // get localStream
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': isAudioOn,
      'video': isVideoOn
          ? {'facingMode': isFrontCameraSelected ? 'user' : 'environment'}
          : false,
    });

    // add mediaTrack to peerConnection
    _localStream!.getTracks().forEach((track) {
      _rtcPeerConnection!.addTrack(track, _localStream!);
    });

    // set source for local video renderer
    _localRTCVideoRenderer.srcObject = _localStream;
    setState(() {});

    // for Incoming call
    if (widget.offer != null) {
      debugPrint("Processing incoming call offer");
      // listen for Remote IceCandidate
      socket!.on("IceCandidate", (data) {
        String candidate = data["iceCandidate"]["candidate"];
        String sdpMid = data["iceCandidate"]["id"];
        int sdpMLineIndex = data["iceCandidate"]["label"];

        debugPrint("Received ICE candidate from remote peer");

        // add iceCandidate
        _rtcPeerConnection!.addCandidate(RTCIceCandidate(
          candidate,
          sdpMid,
          sdpMLineIndex,
        ));
      });

      // set SDP offer as remoteDescription for peerConnection
      await _rtcPeerConnection!.setRemoteDescription(
        RTCSessionDescription(widget.offer["sdp"], widget.offer["type"]),
      );

      // create SDP answer
      RTCSessionDescription answer = await _rtcPeerConnection!.createAnswer();

      // set SDP answer as localDescription for peerConnection
      await _rtcPeerConnection!.setLocalDescription(answer);

      // send SDP answer to remote peer over signalling
      socket!.emit("answerCall", {
        "callerId": widget.callerId,
        "sdpAnswer": answer.toMap(),
      });

      debugPrint("Sent answer to call");
    }
    // for Outgoing Call
    else {
      debugPrint("Setting up outgoing call");

      // when call is accepted by remote peer
      socket!.on("callAnswered", (data) async {
        debugPrint("Call was answered by remote peer");
        // set SDP answer as remoteDescription for peerConnection
        await _rtcPeerConnection!.setRemoteDescription(
          RTCSessionDescription(
            data["sdpAnswer"]["sdp"],
            data["sdpAnswer"]["type"],
          ),
        );

        // send iceCandidate generated to remote peer over signalling
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

        debugPrint("Sent ${rtcIceCadidates.length} ICE candidates to remote peer");
      });

      // create SDP Offer
      RTCSessionDescription offer = await _rtcPeerConnection!.createOffer();

      // set SDP offer as localDescription for peerConnection
      await _rtcPeerConnection!.setLocalDescription(offer);

      // make a call to remote peer over signalling
      socket!.emit('makeCall', {
        "calleeId": widget.calleeId,
        "sdpOffer": offer.toMap(),
      });

      debugPrint("Sent call offer to remote peer");
    }
  }

  void _setupTranscriptionChannel(RTCDataChannel channel) {
    debugPrint("Setting up transcription channel");

    channel.onDataChannelState = (state) {
      debugPrint("🔗 Data channel state changed to: $state");

      if (state == RTCDataChannelState.RTCDataChannelOpen) {
        debugPrint("🔗 Transcription channel open – starting STT");
        setState(() => _isDataChannelOpen = true);
        _startListening();
      } else if (state == RTCDataChannelState.RTCDataChannelClosed ||
          state == RTCDataChannelState.RTCDataChannelClosing) {
        debugPrint("🔗 Data channel closing or closed");
        setState(() => _isDataChannelOpen = false);
      }
    };

    channel.onMessage = (RTCDataChannelMessage msg) {
      debugPrint("📥 Received data channel message: ${msg.text.substring(0, min(20, msg.text.length))}...");

      try {
        // Parse incoming JSON message
        final data = jsonDecode(msg.text);
        final text = data['text'] as String;
        final isDoctor = data['isDoctor'] as bool;
        final isFinal = data['isFinal'] as bool;
        final timestamp = DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int);

        // Update remote transcript
        setState(() => _remoteTranscript = text);

        // Add to transcript history if it's final or substantial non-final
        if (isFinal || text.length > 10) {
          _addToTranscriptHistory(text, isDoctor, timestamp);
        }
      } catch (e) {
        debugPrint("❌ Error parsing transcription message: $e");
      }
    };
  }

  Future<void> _shareTranscript() async {
    // First check if we have any transcript data
    if (_transcriptHistory.isEmpty && _completeTranscriptText.isEmpty) {
      debugPrint("No transcript available");
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No transcript available to share'))
      );
      return;
    }

    // For debugging, show what we have
    debugPrint("Transcript history entries: ${_transcriptHistory.length}");
    debugPrint("Complete transcript length: ${_completeTranscriptText.length} chars");

    try {
      // Format transcript
      final buffer = StringBuffer();
      buffer.writeln('Medical Consultation Transcript');
      buffer.writeln('Date: ${DateTime.now().toString().split('.')[0]}');
      buffer.writeln('-----------------------------------\n');

      // If we have history entries, use those
      if (_transcriptHistory.isNotEmpty) {
        for (var entry in _transcriptHistory) {
          final timeStr = _formatTime(entry.timestamp);
          final speaker = entry.isDoctor ? 'Doctor' : 'Patient';
          buffer.writeln('[$timeStr] $speaker: ${entry.text}');
        }
      } else {
        // Otherwise use our text backup
        buffer.write(_completeTranscriptText);
      }

      // Store the formatted transcript
      final transcriptContent = buffer.toString();
      _completeTranscriptText = transcriptContent;

      debugPrint("Final transcript content: ${transcriptContent.substring(0, min(100, transcriptContent.length))}...");
      debugPrint("Stored transcript length: ${_completeTranscriptText.length}");

      // Get app directory for temporary storage
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/transcript_${DateTime.now().millisecondsSinceEpoch}.txt';
      final file = File(filePath);
      await file.writeAsString(transcriptContent);

      debugPrint("Transcript saved to file: $filePath");

      // Share the file
      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Medical Consultation Transcript',
      );

      // Show success feedback
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transcript shared successfully'))
      );
    } catch (e) {
      debugPrint("❌ Error sharing transcript: $e");
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share transcript: $e'))
      );
    }
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }

  _leaveCall() {
    debugPrint("Leaving call and cleaning up");
    _stopListening();
    Navigator.pop(context);
  }

  _toggleMic() {
    // change status
    isAudioOn = !isAudioOn;
    // enable or disable audio track
    _localStream?.getAudioTracks().forEach((track) {
      track.enabled = isAudioOn;
    });
    debugPrint("Microphone ${isAudioOn ? 'enabled' : 'disabled'}");
    setState(() {});
  }

  _toggleCamera() {
    // change status
    isVideoOn = !isVideoOn;

    // enable or disable video track
    _localStream?.getVideoTracks().forEach((track) {
      track.enabled = isVideoOn;
    });
    debugPrint("Camera ${isVideoOn ? 'enabled' : 'disabled'}");
    setState(() {});
  }

  _switchCamera() {
    // change status
    isFrontCameraSelected = !isFrontCameraSelected;

    // switch camera
    _localStream?.getVideoTracks().forEach((track) {
      // ignore: deprecated_member_use
      track.switchCamera();
    });
    debugPrint("Switched to ${isFrontCameraSelected ? 'front' : 'back'} camera");
    setState(() {});
  }

  _toggleTranscriptView() {
    setState(() {
      _showFullTranscript = !_showFullTranscript;
    });
    debugPrint("Transcript view ${_showFullTranscript ? 'expanded' : 'collapsed'}");
  }

  // Helper function to get min of two values (for string substring safety)
  int min(int a, int b) {
    return a < b ? a : b;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Text(widget.isDoctor ? "Doctor Consultation" : "Patient Call"),
        actions: widget.isDoctor ? [
          IconButton(
            icon: const Icon(Icons.text_snippet),
            onPressed: _shareTranscript,
            tooltip: 'Share Transcript',
          ),
          IconButton(
            icon: Icon(_showFullTranscript ? Icons.fullscreen_exit : Icons.fullscreen),
            onPressed: _toggleTranscriptView,
            tooltip: _showFullTranscript ? 'Minimize Transcript' : 'Full Transcript',
          ),
        ] : null,
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_showFullTranscript && widget.isDoctor)
              _buildFullTranscriptView()
            else
              Expanded(
                child: Stack(
                  children: [
                    // 1) Remote video full-screen
                    RTCVideoView(
                      _remoteRTCVideoRenderer,
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    ),

                    // 2) Local preview (small window)
                    Positioned(
                      right: 20,
                      bottom: 20,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        height: 150,
                        width: 120,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: RTCVideoView(
                            _localRTCVideoRenderer,
                            mirror: isFrontCameraSelected,
                            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                          ),
                        ),
                      ),
                    ),

                    // LOCAL captions (bottom-right)
                    if (_localTranscript.isNotEmpty)
                      Positioned(
                        right: 20,
                        bottom: 180,
                        child: _buildCaptionBubble(_localTranscript, isLocal: true),
                      ),

                    // REMOTE captions (top-center)
                    if (_remoteTranscript.isNotEmpty)
                      Positioned(
                        top: 20,
                        left: 20,
                        right: 20,
                        child: _buildCaptionBubble(_remoteTranscript, isLocal: false),
                      ),

                    // Data channel status indicator
                    Positioned(
                      top: 20,
                      right: 20,
                      left: 20,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _isDataChannelOpen ? Colors.green.withOpacity(0.7) : Colors.orange.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isDataChannelOpen ? Icons.check_circle : Icons.sync,
                                color: Colors.white,
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _isDataChannelOpen ? 'Connected' : 'Connecting...',
                                style: const TextStyle(color: Colors.white, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Transcript indicator for doctor
                    if (widget.isDoctor && _transcriptHistory.isNotEmpty)
                      Positioned(
                        left: 20,
                        bottom: 20,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.record_voice_over, color: Colors.white, size: 16),
                              const SizedBox(width: 5),
                              Text(
                                'Recording (${_transcriptHistory.length} entries)',
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
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
                    icon: Icon(isVideoOn ? Icons.videocam : Icons.videocam_off),
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

  Widget _buildCaptionBubble(String text, {required bool isLocal}) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isLocal
            ? Colors.blue.withOpacity(0.7)
            : Colors.black87.withOpacity(0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      constraints: const BoxConstraints(maxWidth: 300),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isLocal ? 'You' : widget.isDoctor ? 'Patient' : 'Doctor',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            text,
            style: TextStyle(
              color: Colors.white,
              fontSize: isLocal ? 12 : 14,
            ),
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildFullTranscriptView() {
    return Expanded(
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.blue.shade100,
              child: Row(
                children: [
                  const Icon(Icons.history),
                  const SizedBox(width: 8),
                  const Text(
                    'Complete Consultation Transcript',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Text(
                    '${_transcriptHistory.length} entries',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade800,
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton.icon(
                    icon: const Icon(Icons.share),
                    label: const Text('Share'),
                    onPressed: _shareTranscript,
                  ),
                ],
              ),
            ),
            Expanded(
              child: _transcriptHistory.isEmpty
                  ? const Center(child: Text('No transcript data available yet.'))
                  : ListView.builder(
                itemCount: _transcriptHistory.length,
                padding: const EdgeInsets.all(8),
                itemBuilder: (context, index) {
                  final entry = _transcriptHistory[index];
                  return _buildTranscriptEntry(entry);
                },
              ),
            ),
            // Small video preview
            Container(
              height: 100,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  // Remote video (patient)
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: RTCVideoView(
                          _remoteRTCVideoRenderer,
                          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                        ),
                      ),
                    ),
                  ),
                  // Local video (doctor)
                  Container(
                    width: 120,
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.blue),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: RTCVideoView(
                        _localRTCVideoRenderer,
                        mirror: isFrontCameraSelected,
                        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTranscriptEntry(TranscriptEntry entry) {
    final bool isDoctor = entry.isDoctor;
    final timeString = _formatTime(entry.timestamp);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time indicator
          Text(
            timeString,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(width: 8),
          // Speaker icon
          CircleAvatar(
            radius: 12,
            backgroundColor: isDoctor ? Colors.blue.shade100 : Colors.green.shade100,
            child: Icon(
              isDoctor ? Icons.medical_services : Icons.person,
              size: 14,
              color: isDoctor ? Colors.blue : Colors.green,
            ),
          ),
          const SizedBox(width: 8),
          // Message bubble
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isDoctor ? 'Doctor' : 'Patient',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: isDoctor ? Colors.blue.shade700 : Colors.green.shade700,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDoctor ? Colors.blue.shade50 : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(entry.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _stopListening();
    _speech.stop();
    _localRTCVideoRenderer.dispose();
    _remoteRTCVideoRenderer.dispose();
    _localStream?.dispose();
    _rtcPeerConnection?.dispose();
    super.dispose();
  }
}

// Model for transcript entries
class TranscriptEntry {
  final String text;
  final bool isDoctor;
  final DateTime timestamp;

  TranscriptEntry({
    required this.text,
    required this.isDoctor,
    required this.timestamp,
  });
}