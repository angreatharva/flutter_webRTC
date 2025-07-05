import 'package:flutter/material.dart';
import '../services/signalling.service.dart';
import '../utils/theme_constants.dart';

class SessionSummaryScreen extends StatefulWidget {
  final String callId;
  final String selfId;
  final String otherId;
  final bool isDoctor;

  const SessionSummaryScreen({
    Key? key,
    required this.callId,
    required this.selfId,
    required this.otherId,
    required this.isDoctor,
  }) : super(key: key);

  @override
  _SessionSummaryScreenState createState() => _SessionSummaryScreenState();
}

class _SessionSummaryScreenState extends State<SessionSummaryScreen> {
  final socket = SignallingService.instance.socket;
  final List<Map<String, dynamic>> messages = [];
  final TextEditingController controller = TextEditingController();
  final ScrollController scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    socket?.on('sessionMessage', _onMessageReceived);
  }

  @override
  void dispose() {
    socket?.off('sessionMessage', _onMessageReceived);
    controller.dispose();
    scrollController.dispose();
    super.dispose();
  }

  void _onMessageReceived(dynamic data) {
    setState(() {
      messages.add(Map<String, dynamic>.from(data));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.jumpTo(scrollController.position.maxScrollExtent);
      }
    });
  }

  void sendMessage() {
    final msg = controller.text.trim();
    if (msg.isEmpty) return;
    final data = {
      'callId': widget.callId,
      'from': widget.selfId,
      'to': widget.otherId,
      'message': msg,
      'timestamp': DateTime.now().toIso8601String(),
    };
    socket?.emit('sessionMessage', data);
    setState(() {
      messages.add(data);
    });
    controller.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.jumpTo(scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeConstants.backgroundColor,
      appBar: AppBar(
        title: const Text('Session Summary'),
        backgroundColor: ThemeConstants.mainColor,
        foregroundColor: ThemeConstants.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                final isMe = msg['from'] == widget.selfId;
                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isMe
                          ? ThemeConstants.mainColor.withOpacity(0.9)
                          : ThemeConstants.greyInActive,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(ThemeConstants.borderRadius),
                        topRight: Radius.circular(ThemeConstants.borderRadius),
                        bottomLeft: Radius.circular(isMe ? ThemeConstants.borderRadius : 0),
                        bottomRight: Radius.circular(isMe ? 0 : ThemeConstants.borderRadius),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg['message'] ?? '',
                          style: TextStyle(
                            fontSize: 16,
                            color: isMe ? ThemeConstants.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          msg['timestamp'] != null ? msg['timestamp'].toString().substring(11, 16) : '',
                          style: TextStyle(
                            fontSize: 10,
                            color: isMe ? ThemeConstants.white.withOpacity(0.7) : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: 'Type your message...',
                      filled: true,
                      fillColor: ThemeConstants.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ThemeConstants.borderRadius),
                        borderSide: BorderSide(color: ThemeConstants.primaryColor.withOpacity(0.5)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ThemeConstants.borderRadius),
                        borderSide: BorderSide(color: ThemeConstants.primaryColor.withOpacity(0.5)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ThemeConstants.borderRadius),
                        borderSide: const BorderSide(color: ThemeConstants.primaryColor, width: 2),
                      ),
                    ),
                    onSubmitted: (_) => sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ThemeConstants.elevatedButtonStyle(backgroundColor: ThemeConstants.mainColor),
                  onPressed: sendMessage,
                  child: const Icon(Icons.send, color: ThemeConstants.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 