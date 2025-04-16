import 'dart:math';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:rtc/screens/RoleSelectionScreen.dart';
import 'package:rtc/services/api_service.dart';
import 'services/signalling.service.dart';

void main() {
  runApp(VideoCallApp());
}

class VideoCallApp extends StatelessWidget {
  VideoCallApp({super.key});

  // WebSocket signaling server URL
  final String websocketUrl = "${ApiService.baseUrl}";


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

    return GetMaterialApp(
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
