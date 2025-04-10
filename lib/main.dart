import 'dart:math';
import 'package:flutter/material.dart';
import 'package:rtc/screens/RoleSelectionScreen.dart';
import 'services/signalling.service.dart';

void main() {
  runApp(VideoCallApp());
}

class VideoCallApp extends StatelessWidget {
  VideoCallApp({super.key});

  // WebSocket signaling server URL
  final String websocketUrl = "https://a7c5-103-110-234-188.ngrok-free.app";

  // Randomly generate caller ID
  final String selfCallerID =
  Random().nextInt(999999).toString().padLeft(6, '0');

  @override
  Widget build(BuildContext context) {
    // Initialize signaling service
    SignallingService.instance.init(
      websocketUrl: websocketUrl,
      selfCallerID: selfCallerID,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      darkTheme: ThemeData.dark().copyWith(
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(),
      ),
      themeMode: ThemeMode.dark,
      home: RoleSelectionScreen(selfCallerId: selfCallerID),
    );
  }
}
