
import 'dart:async';
import 'dart:io';
import 'package:bakht/features/chat/widgets/audio_message_bubble.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';
import 'dart:ui';
import '../../core/theme/app_theme.dart';
import '../../core/utils/chat_id.dart';
import '../../profile/fullscreenimage.dart';
import '../../services/Contactinfo.dart';

import '../call/callscreen.dart';
import 'widgets/chat_bubble.dart';

import 'package:path_provider/path_provider.dart';



class ChatScreenUI extends StatefulWidget {
  const ChatScreenUI({super.key});

  @override
  State<ChatScreenUI> createState() => _ChatScreenUIState();
}

class _ChatScreenUIState extends State<ChatScreenUI> {
  Timer? _typingTimer;
  bool _isTyping = false;
  Timer? _recordingTimer;
  int _recordingSeconds = 0;
  List<double> waveform = []; // 🔥 ADD THIS
  double _dragPosition = 0.0;


  // Add this at the top of your _ChatScreenUIState class
  final AudioPlayer globalPlayer = AudioPlayer();
  final ImagePicker _picker = ImagePicker();

  Future<void> _updateChatSummary({
    required String chatId,
    required dynamic user,
    required String lastMessage,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
      'participants': [currentUser.uid, user['uid']],
      'participantData': {
        currentUser.uid: {
          'name': currentUser.displayName ?? '',
          'phone': currentUser.phoneNumber ?? '',
          'profilePic': '',
        },
        user['uid']: {
          'name': user['name'] ?? '',
          'phone': user['phone'] ?? '',
          'profilePic': user['profilePic'] ?? '',
        },
      },
      'lastMessage': lastMessage,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastSenderId': currentUser.uid,
      'unread_${user['uid']}': FieldValue.increment(1),
      'unread_${currentUser.uid}': 0,
    }, SetOptions(merge: true));
  }

  Future<void> pickAndSendImage(
    String chatId,
    dynamic user, {
    bool fromCamera = false,
  }) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      );

      if (pickedFile == null) return;

      final file = File(pickedFile.path);

      await _updateChatSummary(
        chatId: chatId,
        user: user,
        lastMessage: '📷 Photo',
      );

      final fileName = DateTime.now().millisecondsSinceEpoch.toString();

      final ref = FirebaseStorage.instance
          .ref()
          .child('chat_images/$chatId/$fileName');

      final uploadTask = await ref.putFile(file);

      final imageUrl = await uploadTask.ref.getDownloadURL();

      final currentUser = FirebaseAuth.instance.currentUser;

      await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add({
        'senderId': currentUser!.uid,
        'receiverId': user['uid'],
        'type': 'image',
        'mediaUrl': imageUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'sent',
      });

    } catch (e) {
      print("Image error: $e");
    }

  }
// Update your dispose method
  @override
  void dispose() {
    _typingTimer?.cancel();
    _recordingTimer?.cancel();
    _amplitudeSubscription?.cancel();
    recorder.dispose();
    _controller.dispose();
    globalPlayer.dispose(); // Kill the player when leaving the screen
    super.dispose();
  }

  Future<void> uploadAndSendImage(File file, String chatId) async {
    final fileName = DateTime.now().millisecondsSinceEpoch.toString();

    final ref = FirebaseStorage.instance
        .ref()
        .child('chat_images')
        .child(chatId)
        .child(fileName);

    final uploadTask = await ref.putFile(file);

    final imageUrl = await uploadTask.ref.getDownloadURL();

    final currentUser = FirebaseAuth.instance.currentUser;

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add({
      'senderId': currentUser!.uid,
      'type': 'image', // 🔥 important
      'mediaUrl': imageUrl,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'sent',
    });
  }

  final recorder = AudioRecorder();
  bool isRecording = false;
  String? audioPath;
  bool hasMarkedSeen = false;
  final TextEditingController _controller = TextEditingController();
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  double currentAmplitude = 0.0; // We will use this for the "visualizer" effect

  // 1. START RECORDING (With Timer and Faster Bitrate)
  Future<void> startRecording() async {
    try {

      waveform= [];

      final hasPermission = await recorder.hasPermission();
      if (!hasPermission) {

        return;
      }

      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.m4a';

      // ✅ OPTIMIZED: Lower bitrate (32kbps) makes the upload 4x faster!
      await recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 32000,
          sampleRate: 22050,
        ),
        path: path,
      );

      // ✅ TIMER START: Reset and start counting seconds
      _recordingSeconds = 0;
      _recordingTimer?.cancel(); // Safety clear
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _recordingSeconds++;
        });
      });

      _amplitudeSubscription = recorder
          .onAmplitudeChanged(const Duration(milliseconds: 100))
          .listen((amp) {setState(() {
        currentAmplitude = amp.current;

        double normalized = ((amp.current + 40) / 40).clamp(0.0, 1.0);

// 🔥 SMOOTHING (average last values)
        if (waveform.isNotEmpty) {
          normalized = (waveform.last + normalized) / 2;
        }

// 🔥 LIMIT SIZE (max 50 points like WhatsApp)
        if (waveform.length > 50) {
          waveform.removeAt(0);
        }

        waveform.add(normalized);
      });
      });

      setState(() {
        isRecording = true;
        audioPath = path;
      });

    } catch (e) {
      print("CRASH ERROR: $e");
      _recordingTimer?.cancel();
      setState(() => isRecording = false);
    }
  }
  void handleTyping(String chatId, String text) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final isTypingNow = text.trim().isNotEmpty;

    if (isTypingNow && !_isTyping) {
      _isTyping = true;

      FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .set({
        'typing_${currentUser.uid}': true,
      }, SetOptions(merge: true));
    }

    _typingTimer?.cancel();

    _typingTimer = Timer(const Duration(seconds: 2), () {
      _isTyping = false;

      FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .set({
        'typing_${currentUser.uid}': false,
      }, SetOptions(merge: true));
    });
  }
// 2. STOP AND SEND (With Timer Cleanup and Slide-to-Cancel)
  Future<void> stopRecordingAndSend(String chatId, dynamic user) async {
    try {
      // ✅ STOP TIMER IMMEDIATELY
      _recordingTimer?.cancel();

      await _amplitudeSubscription?.cancel();
      final path = await recorder.stop();

      // ✅ NEW: Wait for OS to finish writing the file to avoid "Empty" notes
      await Future.delayed(const Duration(milliseconds: 300));

      // 🛑 PROTECT DURATION: Save the seconds into a local variable
      int savedSeconds = _recordingSeconds;

      // 🔥🔥🔥 ADD THIS BLOCK (REAL DURATION FIX) 🔥🔥🔥
      if (path != null) {
        try {
          final tempPlayer = AudioPlayer();
          await tempPlayer.setFilePath(path);
          final realDuration = tempPlayer.duration;

          if (realDuration != null && realDuration.inSeconds > 0) {
            savedSeconds = realDuration.inSeconds; // ✅ override with REAL duration
          }

          await tempPlayer.dispose();
        } catch (e) {

        }
      }
      // 🔥🔥🔥 END OF FIX 🔥🔥🔥


      // Change this line in stopRecordingAndSend:
      bool isCancelled = _dragPosition > 100; // Positive 100 means sliding Right

      setState(() {
        isRecording = false;
        currentAmplitude = 0.0;
        _dragPosition = 0.0;
        _recordingSeconds = 0; // Reset UI timer
      });

      if (path == null || isCancelled) {
        if (path != null) {
          final fileToDelete = File(path);
          if (await fileToDelete.exists()) {
            await fileToDelete.delete();

          }
        }
        return;
      }



      // ✅ NEW: Debug File Size to check for "Empty" notes
      final file = File(path);
      final int sizeInBytes = await file.length();
      print("RECORDING SAVED: $path | SIZE: $sizeInBytes bytes | DURATION: $savedSeconds s");
      final finalWaveform = List<double>.from(waveform);
      final currentUser = FirebaseAuth.instance.currentUser!;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _updateChatSummary(
        chatId: chatId,
        user: user,
        lastMessage: '🎤 Voice Message',
      );

      // 3. Upload to Firebase
      Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('chats/$chatId/voice_notes/$fileName');

      UploadTask uploadTask = storageRef.putFile(file);
      TaskSnapshot snapshot = await uploadTask;

      String downloadUrl = await snapshot.ref.getDownloadURL();

      // ✅ NEW: Print URL to verify playback in browser
      print("REAL URL: $downloadUrl");

      // 5. Create the Firestore Message (Adding duration field)
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add({
        'type': 'audio',
        'mediaUrl': downloadUrl,
        'duration': savedSeconds, // ✅ NOW REAL (fixed)
        'senderId': currentUser.uid,
        'receiverId': user['uid'],
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'sent',
        'waveform':finalWaveform
      });

    } catch (e) {

      _recordingTimer?.cancel();
      setState(() {
        isRecording = false;
        _dragPosition = 0.0;
        _recordingSeconds = 0;
      });
    }


  }


  void updateTypingStatus(String chatId, bool isTyping) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .set({
      'typing_${currentUser.uid}': isTyping,
    }, SetOptions(merge: true));
  }



  Future<void> sendMessage(String text, String chatId, dynamic user) async {
    if (text.trim().isEmpty) return;

    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) return;

    // Create/update the parent chat first so participant-based security rules
    // can authorize the message write for brand-new conversations.
    await _updateChatSummary(
      chatId: chatId,
      user: user,
      lastMessage: text,
    );

    // ✅ SAVE MESSAGE
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add({
      'text': text,
      'senderId': currentUser.uid,
      'receiverId': user['uid'],
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'sent',
    });
  }
  void markAllAsSeen(String chatId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final messages = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('receiverId', isEqualTo: currentUser.uid)
          .get();
// 1. update messages ONLY
      for (var doc in messages.docs) {
        await doc.reference.update({'status': 'seen'});
      }

// 2. reset unread ONLY ONCE
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .set({
        'unread_${currentUser.uid}': 0,
      }, SetOptions(merge: true));
    } on FirebaseException catch (error) {
      debugPrint('Unable to mark chat as seen (${error.code}): ${error.message}');
    }

  }
  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser!;
    final user = ModalRoute.of(context)!.settings.arguments as dynamic;

    final currentUserId = currentUser.uid;
    final otherUserId = user['uid'];

    // ✅ SINGLE chatId source
    final chatId = generateChatId(currentUserId, otherUserId);

    // 🔥 DEBUG PRINT (VERY IMPORTANT)
    print("CHAT ID: $chatId");

    // ✅ RUN ONLY ONCE
    if (!hasMarkedSeen) {
      markAllAsSeen(chatId);
      hasMarkedSeen = true;
    }

    // continue your UI below...ccha


    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          _buildBackgroundPhoto(),

          SafeArea(
            child: Column(
              children: [
                _buildHeader(context, user, chatId),

                // ✅ CHAT LIST
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('chats')
                        .doc(chatId)
                        .collection('messages')
                        .orderBy('timestamp', descending: true)
                        .limit(10)
                        .snapshots(),
                    builder: (context, snapshot) {

                      if (snapshot.hasError) {
                        final error = snapshot.error;
                        final message = error is FirebaseException &&
                                error.code == 'permission-denied'
                            ? 'You do not have permission to open this chat.'
                            : 'Messages could not be loaded.\nCheck your connection and try again.';

                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              message,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ),
                        );
                      }

                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      final messages = snapshot.data!.docs;

                      return ListView.builder(
                        key: PageStorageKey(chatId),
                        reverse: true,
                        padding: const EdgeInsets.all(15),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {

                          final msg = messages[index];
                          final messageId = msg.id;

                          final data = msg.data() as Map<String, dynamic>;

                          final isMe =
                              data['senderId'] == currentUser.uid;

                          final status = data['status'] ?? 'sent';
                          final type = data['type'] ?? 'text';

                          // ✅ STATUS UPDATE (SAFE - NO BUILD CRASH)
                          if (data['receiverId'] == currentUser.uid &&
                              status == 'sent') {
                            Future.microtask(() {
                              msg.reference.update({'status': 'delivered'});
                            });
                          }

                          if (data['receiverId'] == currentUser.uid &&
                              status == 'delivered') {
                            Future.microtask(() {
                              msg.reference.update({'status': 'seen'});
                            });
                          }

                          // 🔥 COMMON DELETE FUNCTION
                          void handleDelete() {
                            showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                backgroundColor: AppColors.surface,
                                title: const Text(
                                  "Delete Message",
                                  style: TextStyle(color: Colors.white),
                                ),
                                content: const Text(
                                  "Are you sure?",
                                  style: TextStyle(color: Colors.white70),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text("Cancel"),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      Navigator.pop(context);

                                      await FirebaseFirestore.instance
                                          .collection('chats')
                                          .doc(chatId)
                                          .collection('messages')
                                          .doc(messageId)
                                          .delete();
                                    },
                                    child: const Text(
                                      "Delete",
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          // 🎤 AUDIO MESSAGE
                          if (type == 'audio' && data['mediaUrl'] != null) {
                            return GestureDetector(
                              onLongPress: handleDelete,
                              child: AudioMessageBubble(
                                url: data['mediaUrl'],
                                isMe: isMe,
                                player: globalPlayer,
                                savedDuration: data['duration'],
                                waveform: (data['waveform'] as List?)
                                    ?.map((e) => (e as num).toDouble())
                                    .toList(),
                              ),
                            );
                          }

                          final isImage = type == 'image';
                          final imageUrl = data['mediaUrl'] ?? data['imageUrl'];

                          return GestureDetector(
                            onLongPress: handleDelete,
                            onTap: isImage && imageUrl != null
                                ? () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => FullScreenImage(
                                          imageUrl: imageUrl,
                                        ),
                                      ),
                                    );
                                  }
                                : null,
                            child: ChatBubble(
                                message: isImage ? "" : (data['text'] ?? ""),
                                isMe: isMe,
                                time: data['timestamp'] != null
                                    ? TimeOfDay.fromDateTime(
                                  data['timestamp'].toDate(),
                                ).format(context)
                                    : "",
                                status: status,
                                mediaUrl: isImage ? imageUrl : null,
                              ),
                          );
                        },
                      );
                    },
                  ),
                ),
                // ✅ INPUT AREA
                _buildInputArea(chatId, user),
              ],
            ),
          )
        ],
      ),
    );
  }
  Future<void> deleteChat(String chatId) async {
    final chatRef =
    FirebaseFirestore.instance.collection('chats').doc(chatId);

    // 🔥 delete all messages first
    final messages =
    await chatRef.collection('messages').get();

    for (var doc in messages.docs) {
      await doc.reference.delete();
    }

    // 🔥 delete chat document
    await chatRef.delete();
  }

  // ✅ BACKGROUND
  Widget _buildBackgroundPhoto() {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topLeft,
          radius: 1.5,
          colors: [
            AppColors.highlight,
            AppColors.background
          ],
        ),
      ),
    );
  }
  Future<void> deleteMessage(
      String chatId, String messageId) async {
    try {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .delete();
    } catch (e) {
      print("Delete message error: $e");
    }
  }
  Widget _buildHeader(BuildContext context, dynamic user, String chatId) {

    return Padding(
      padding:
      const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Row(
        mainAxisAlignment:
        MainAxisAlignment.spaceBetween,
        children: [
          _circleIconButton(Icons.arrow_back_ios_new, () {
            Navigator.pop(context);
          }),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ContactInfoScreen(user: user),
                  ),
                );
              },

              child:
              Row(
                children: [

                  Expanded(
                    child:
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(user['uid'])
                          .snapshots(),
                      builder: (context, snapshot) {

                        if (!snapshot.hasData || snapshot.data?.data() == null) {
                          return const Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                child: Icon(Icons.person),
                              ),
                              SizedBox(width: 15),
                              Text(
                                "User",
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          );
                        }

                        final data =
                        snapshot.data!.data() as Map<String, dynamic>;

                        final imageUrl = data['profilePic'];
                        final lastSeen = data['lastSeen'];

                        bool isOnline = false;

                        if (lastSeen != null) {
                          final diff = DateTime.now()
                              .difference((lastSeen as Timestamp).toDate())
                              .inSeconds;

                          isOnline = diff <= 10;
                        }

                        return Row(
                          children: [

                            // 🔥 PROFILE
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: AppColors.highlight,
                              backgroundImage:
                              (imageUrl != null && imageUrl.toString().isNotEmpty)
                                  ? NetworkImage(imageUrl)
                                  : null,
                              child: (imageUrl == null ||
                                  imageUrl.toString().isEmpty)
                                  ? const Icon(Icons.person, color: Colors.white)
                                  : null,
                            ),

                            const SizedBox(width: 15),


                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [

                                  StreamBuilder<DocumentSnapshot>(
                                    stream: FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(FirebaseAuth.instance.currentUser!.uid)
                                        .collection('contacts')
                                        .doc(user['uid'])
                                        .snapshots(),
                                    builder: (context, contactSnap) {

                                      String displayName =
                                          data['name'] ?? data['phone'] ?? "User";

                                      if (contactSnap.hasData && contactSnap.data?.data() != null) {
                                        final contactData =
                                        contactSnap.data!.data() as Map<String, dynamic>;

                                        displayName = contactData['name'] ?? displayName;
                                      }

                                      return Text(
                                        displayName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 2),

                                  // 🔥 TYPING + ONLINE
                                  StreamBuilder<DocumentSnapshot>(
                                    stream: FirebaseFirestore.instance
                                        .collection('chats')
                                        .doc(chatId)
                                        .snapshots(),
                                    builder: (context, chatSnap) {

                                      if (!chatSnap.hasData) {
                                        return const SizedBox();
                                      }

                                      final chatData =
                                      chatSnap.data!.data() as Map<String, dynamic>?;

                                      final isTyping =
                                          chatData?['typing_${user['uid']}'] ?? false;

                                      if (isTyping) {
                                        return const Text(
                                          "Typing...",
                                          style: TextStyle(
                                            color: Colors.greenAccent,
                                            fontSize: 12,
                                          ),
                                        );
                                      }

                                      return Text(
                                        isOnline
                                            ? "Online"
                                            : lastSeen != null
                                            ? "Last seen ${TimeOfDay.fromDateTime(lastSeen.toDate()).format(context)}"
                                            : "Offline",
                                        style: TextStyle(
                                          color: isOnline
                                              ? Colors.greenAccent
                                              : Colors.white38,
                                          fontSize: 12,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),IconButton(
            icon: const Icon(Icons.call, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CallScreen(
                    channelName: chatId, // 🔥 SAME chatId for both users
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _circleIconButton(
      IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
        ),
        child:
        Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildInputArea(String chatId, dynamic user) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // ✅ 1. THE MIC (ON LEFT)
          GestureDetector(
            onLongPress: startRecording,
            onLongPressMoveUpdate: (details) {
              setState(() {
                // Tracks movement. Positive is Right, Negative is Left.
                _dragPosition = details.localOffsetFromOrigin.dx;
              });
            },
            onLongPressUp: () => stopRecordingAndSend(chatId, user),
            child: CircleAvatar(
              radius: 25,
              backgroundColor: isRecording ? Colors.red : Colors.white10,
              child: Icon(isRecording ? Icons.mic : Icons.mic_none, color: Colors.white),
            ),
          ),

          const SizedBox(width: 10),

          // ✅ 2. PLUS BUTTON (IMAGE X TRIGGER) - Only show when not recording
          if (!isRecording) ...[
            GestureDetector(
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.black,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (_) {
                    return SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [

                          ListTile(
                            leading: const Icon(Icons.camera_alt, color: Colors.white),
                            title: const Text("Camera", style: TextStyle(color: Colors.white)),
                            onTap: () {
                              Navigator.pop(context);
                              pickAndSendImage(chatId, user, fromCamera: true);
                            },
                          ),

                          ListTile(
                            leading: const Icon(Icons.photo, color: Colors.white),
                            title: const Text("Gallery", style: TextStyle(color: Colors.white)),
                            onTap: () {
                              Navigator.pop(context);
                              pickAndSendImage(chatId, user, fromCamera: false);
                            },
                          ),

                        ],
                      ),
                    );
                  },
                );
              },
              child: const CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white10,
                child: Icon(Icons.add, color: Colors.white70, size: 20),
              ),
            ),
            const SizedBox(width: 10),
          ],

          // ✅ 3. THE DYNAMIC CENTER AREA
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  height: 50, // ✅ kept same (NO UI CHANGE)
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  color: Colors.white.withOpacity(0.05),
                  child: isRecording
                      ? Row(
                    children: [
                      const Icon(
                        Icons.fiber_manual_record,
                        color: Colors.red,
                        size: 14,
                      ),
                      const SizedBox(width: 8),

                      // ✅ SAFE TIMER (no crash)
                      Text(
                        "${_recordingSeconds}s",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const Spacer(),

                      // ✅ SAFE OPACITY (bounded)
                      Opacity(
                        opacity: (1.0 - (_dragPosition / 100))
                            .clamp(0.0, 1.0),
                        child: Row(
                          children: const [
                            Text(
                              "Slide to cancel",
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 10,
                              color: Colors.white54,
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                      : TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white),

                    // ✅ SAFE (no UI change, but smoother typing)
                    cursorColor: Colors.white,
                    textAlignVertical: TextAlignVertical.center,

                    onChanged: (text) {
                      handleTyping(chatId, text);
                    },

                    decoration: const InputDecoration(
                      hintText: "Type a message...",
                      hintStyle: TextStyle(color: Colors.white24),
                      border: InputBorder.none,
                      isDense: true, // ✅ prevents overflow issues
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ✅ 4. SEND BUTTON
          if (!isRecording) ...[
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () async {
                final text = _controller.text.trim();
                if (text.isEmpty) return;

                _controller.clear();

                updateTypingStatus(chatId, false);

                await sendMessage(text, chatId, user);
              },
              child: const CircleAvatar(
                backgroundColor: AppColors.accent,
                child: Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ),
          ],
        ],
      ),
    );
  }



}
