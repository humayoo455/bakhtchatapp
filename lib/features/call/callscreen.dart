import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class CallScreen extends StatefulWidget {
  final String channelName;

  const CallScreen({super.key, required this.channelName});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  RtcEngine? _engine;
  bool isJoined = false;
  int? remoteUid;
  String? errorMessage;

  static const String appId = String.fromEnvironment(
    'AGORA_APP_ID',
    defaultValue: '72a4b0a891de4711ac217a2003acd4fc',
  );
  static const String token = String.fromEnvironment('AGORA_TOKEN');

  @override
  void initState() {
    super.initState();
    initAgora();
  }

  Future<void> initAgora() async {
    final permission = await Permission.microphone.request();
    if (!permission.isGranted) {
      if (mounted) {
        setState(() => errorMessage = 'Microphone permission is required.');
      }
      return;
    }

    try {
      final engine = createAgoraRtcEngine();
      _engine = engine;
      await engine.initialize(const RtcEngineContext(appId: appId));

      // Register call lifecycle events before joining the channel.
      engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (connection, elapsed) {
            if (mounted) setState(() => isJoined = true);
          },
          onUserJoined: (connection, uid, elapsed) {
            if (mounted) setState(() => remoteUid = uid);
          },
          onUserOffline: (connection, uid, reason) {
            if (mounted) setState(() => remoteUid = null);
          },
        ),
      );

      await engine.enableAudio();

      await engine.joinChannel(
        token: token,
        channelId: widget.channelName,
        uid: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        options: const ChannelMediaOptions(),
      );
    } catch (error) {
      if (mounted) {
        setState(() => errorMessage = 'Unable to start the call. Try again.');
      }
      debugPrint('Agora initialization failed: $error');
    }
  }

  @override
  void dispose() {
    _engine?.leaveChannel();
    _engine?.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("Calling..."),
      ),
      body: Center(
        child: Text(
          errorMessage ??
              (remoteUid != null
                  ? "Connected 🔥"
                  : isJoined
                  ? "Waiting for user..."
                  : "Joining..."),
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.red,
        onPressed: () => Navigator.pop(context),
        child: const Icon(Icons.call_end),
      ),
    );
  }
}
