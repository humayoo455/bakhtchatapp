import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}
class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    updateUserStatus(true); // ✅ online when app opens
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    updateUserStatus(false); // ✅ offline when app closes
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      updateUserStatus(true); // ✅ app active
    } else {
      updateUserStatus(false); // ✅ background / closed
    }
  }

  Future<void> updateUserStatus(bool isOnline) async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .set({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(), // 🔥 always update
      }, SetOptions(merge: true));
    } catch (e) {
      print("Status update error: $e");
    }
  }


  @override
  Widget build(BuildContext context) {

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,

        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          title: const Text(
            "Bakht",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.camera_alt_outlined, color: Colors.white70),
              onPressed: () {},
            ),

            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white70),
              onSelected: (value) async {

                if (value == 'profile') {
                  Navigator.pushNamed(context, '/profile');
                }

                if (value == 'logout') {
                  try {
                    // ✅ FIRST update status
                    await updateUserStatus(false);

                    // ✅ THEN logout
                    await FirebaseAuth.instance.signOut();

                    if (!mounted) return;

                    Navigator.of(context).pushNamedAndRemoveUntil(
                      '/login',
                          (route) => false,
                    );

                  } catch (e) {
                    print("Logout error: $e");

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Logout failed")),
                      );
                    }
                  }
                }

              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'profile',
                  child: Text("Profile"),
                ),
                const PopupMenuItem(
                  value: 'logout',
                  child: Text(
                    "Logout",
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),
              ],
            ),
          ],

          bottom: const TabBar(
            indicatorColor: AppColors.accent,
            labelColor: AppColors.accent,
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(text: "CHATS"),
              Tab(text: "STATUS"),
              Tab(text: "CALLS"),
            ],
          ),
        ),

        body: TabBarView(
          children: [
            Column(
              children: [
                _buildStorySection(),
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                    ),
                    child: _buildChatList(context),
                  ),
                ),
              ],
            ),

            const Center(
              child: Text(
                "Status updates will appear here",
                style: TextStyle(color: Colors.white38),
              ),
            ),

            const Center(
              child: Text(
                "No recent calls",
                style: TextStyle(color: Colors.white38),
              ),
            ),
          ],
        ),

        floatingActionButton: FloatingActionButton(
          backgroundColor: AppColors.accent,
          child: const Icon(Icons.message, color: Colors.white),
          onPressed: () {
            Navigator.pushNamed(context, '/contacts');
          },
        ),
      ),
    );
  }

  // ✅ STORIES
  Widget _buildStorySection() {
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 5,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: CircleAvatar(
              radius: 32,
              backgroundColor: AppColors.accent,
              child: CircleAvatar(
                radius: 30,
                backgroundColor: AppColors.background,
                child: const Icon(Icons.person, color: Colors.white54),
              ),
            ),
          );
        },
      ),
    );
  }
  Future<void> deleteChat(String chatId) async {
    final chatRef =
    FirebaseFirestore.instance.collection('chats').doc(chatId);

    final messages =
    await chatRef.collection('messages').get();

    WriteBatch batch = FirebaseFirestore.instance.batch();

    for (var doc in messages.docs) {
      batch.delete(doc.reference);
    }

    batch.delete(chatRef);

    await batch.commit();
  }
  Widget _buildChatList(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

  if (user == null) {
    return const Center(
      child: Text(
        "Please login again",
        style: TextStyle(color: Colors.white38),
      ),
    );
  }

  final uid = user.uid;



    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: uid)
          .orderBy('lastMessageTime', descending: true)
          .snapshots(),
      builder: (context, snapshot) {

        if (snapshot.hasError) {
          final error = snapshot.error;
          final message = error is FirebaseException &&
                  error.code == 'failed-precondition'
              ? 'The chat index is not configured yet.'
              : error is FirebaseException && error.code == 'permission-denied'
                  ? 'Chat access is not configured for this account.'
                  : 'Chats could not be loaded.\nCheck your connection and try again.';

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
          return const Center(child: CircularProgressIndicator());
        }

        final chats = snapshot.data!.docs;

        if (chats.isEmpty) {
          return const Center(
            child: Text(
              "No chats yet\nStart a conversation",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 20),
          itemCount: chats.length,
          itemBuilder: (context, index) {

            final chatData =
            chats[index].data() as Map<String, dynamic>;

            final participants =
            List<String>.from(chatData['participants'] ?? []);

            participants.remove(uid);

            if (participants.isEmpty) return const SizedBox();

            final otherUserId = participants.first;

            return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(otherUserId)
                  .snapshots(),
              builder: (context, userSnap) {

                if (!userSnap.hasData || userSnap.data?.data() == null) {
                  return const SizedBox();
                }

                final userData =
                userSnap.data!.data() as Map<String, dynamic>;

                // ✅ FETCH LOCAL CONTACT (NEW - SAFE ADDITION)
                return StreamBuilder<DocumentSnapshot>(

                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid) // current user
                      .collection('contacts')
                      .doc(otherUserId)
                      .snapshots(),
                  builder: (context, contactSnap) {

                    final contactData =
                    contactSnap.data?.data() as Map<String, dynamic>?;
                    // 🔥 FINAL DISPLAY NAME (PRIORITY SYSTEM)
                    final displayName =
                        contactData?['name'] ??
                            userData['name'] ??
                            userData['phone'] ??
                            "User";

                    // ✅ YOUR ORIGINAL LOGIC (UNCHANGED)
                    final lastMessage =
                        chatData['lastMessage'] ?? userData['about'] ?? "";

                    final timestamp = chatData['lastMessageTime'];
                    final unreadCount = chatData['unread_$uid'] ?? 0;

                    String time = "";
                    if (timestamp != null) {
                      time = TimeOfDay.fromDateTime(timestamp.toDate())
                          .format(context);
                    }

                    final lastSeen = userData['lastSeen'];
                    bool isOnline = false;

                    if (lastSeen != null) {
                      final diff = DateTime.now()
                          .difference((lastSeen as Timestamp).toDate())
                          .inSeconds;
                      isOnline = diff <= 10;
                    }

                    return RepaintBoundary(
                      child: ListTile(
                        tileColor: unreadCount > 0
                            ? Colors.white.withOpacity(0.05)
                            : (lastMessage.isNotEmpty
                            ? Colors.white.withOpacity(0.02)
                            : Colors.transparent),

                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            '/chat',
                            arguments: {
                              'uid': otherUserId,
                              'phone': userData['phone'],
                            },
                          );
                        },

                        leading: Stack(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: AppColors.highlight,
                              backgroundImage:
                              (userData['profilePic'] != null &&
                                  userData['profilePic']
                                      .toString()
                                      .isNotEmpty)
                                  ? NetworkImage(userData['profilePic'])
                                  : null,
                              child: (userData['profilePic'] == null ||
                                  userData['profilePic']
                                      .toString()
                                      .isEmpty)
                                  ? const Icon(Icons.person,
                                  color: Colors.white)
                                  : null,
                            ),
                            if (isOnline)
                              const Positioned(
                                bottom: 2,
                                right: 2,
                                child: CircleAvatar(
                                  radius: 6,
                                  backgroundColor: Colors.green,
                                ),
                              ),
                          ],
                        ),

                        // 🔥 ONLY CHANGE HERE (SAFE)
                        title: Text(
                          displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        subtitle: Text(
                          lastMessage,
                          maxLines: 1,
                          style: TextStyle(
                            color: unreadCount > 0
                                ? Colors.white
                                : Colors.white54,
                            fontSize: 13,
                          ),
                        ),

                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              time,
                              style: TextStyle(
                                color: unreadCount > 0
                                    ? Colors.greenAccent
                                    : Colors.white30,
                                fontSize: 11,
                              ),
                            ),
                            if (unreadCount > 0)
                              Container(
                                margin: const EdgeInsets.only(top: 5),
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  unreadCount.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
