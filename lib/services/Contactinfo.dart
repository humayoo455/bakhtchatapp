import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

import '../profile/fullscreenimage.dart';

class ContactInfoScreen extends StatelessWidget {
  final dynamic user;

  const ContactInfoScreen({super.key, required this.user});


  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Contact Info"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),

      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user['uid'])
            .snapshots(),
        builder: (context, snapshot) {

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data =
          snapshot.data!.data() as Map<String, dynamic>?;

          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(FirebaseAuth.instance.currentUser!.uid)
                .collection('contacts')
                .doc(user['uid'])
                .snapshots(),
            builder: (context, contactSnap) {

              String displayName =
                  data?['name'] ?? data?['phone'] ?? "User";

              if (contactSnap.hasData && contactSnap.data?.data() != null) {
                final contactData =
                contactSnap.data!.data() as Map<String, dynamic>;

                displayName = contactData['name'] ?? displayName;
              }

              return Text(
                displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          );

          final phone = data?['phone'] ?? "";
          final about = data?['about'] ?? "";
          final imageUrl = data?['profilePic'] ?? "";
          final lastSeen = data?['lastSeen'];

          bool isOnline = false;

          if (lastSeen != null) {
            final diff = DateTime.now()
                .difference((lastSeen as Timestamp).toDate())
                .inSeconds;

            isOnline = diff <= 10;
          }

          return SingleChildScrollView(
            child: Column(
              children: [

                // 🔥 TOP GRADIENT HEADER
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(top: 30, bottom: 30),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFFff4b7d),
                        Color(0xFF1f1f2e),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Column(
                    children: [

                      // 🔥 PROFILE IMAGE WITH GLOW
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 130,
                            height: 130,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Colors.pink, Colors.red],
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              if (imageUrl.isEmpty) return;

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FullScreenImage(imageUrl: imageUrl),
                                ),
                              );
                            },
                            child: CircleAvatar(
                              radius: 60,
                              backgroundColor: AppColors.highlight,
                              backgroundImage:
                              imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
                              child: imageUrl.isEmpty
                                  ? const Icon(Icons.person, size: 50, color: Colors.white)
                                  : null,
                            ),
                          ),


                        ],
                      ),

                      const SizedBox(height: 15),
                      StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(FirebaseAuth.instance.currentUser!.uid)
                            .collection('contacts')
                            .doc(user['uid'])
                            .snapshots(),
                        builder: (context, contactSnap) {

                          final currentDisplayName =
                          contactSnap.hasData && contactSnap.data?.data() != null
                              ? (contactSnap.data!.data() as Map<String, dynamic>)['name']
                              : (data?['name'] ?? data?['phone'] ?? "User");

                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [

                              // 🔥 NAME
                              Text(
                                currentDisplayName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              const SizedBox(width: 6),

                              // ✏️ EDIT BUTTON
                              GestureDetector(
                                onTap: () async {

                                  final controller =
                                  TextEditingController(text: currentDisplayName);

                                  final editedName = await showDialog<String>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: const Text("Edit Name"),
                                      content: TextField(controller: controller),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: const Text("Cancel"),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, controller.text.trim()),
                                          child: const Text("Save"),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (editedName == null || editedName.isEmpty) return;

                                  final currentUser = FirebaseAuth.instance.currentUser;

                                  await FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(currentUser!.uid)
                                      .collection('contacts')
                                      .doc(user['uid'])
                                      .set({
                                    'name': editedName,
                                  }, SetOptions(merge: true));
                                },

                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: Colors.pinkAccent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.edit,
                                      size: 14, color: Colors.white),
                                ),
                              ),
                            ],
                          );
                        },
                      ),


                      const SizedBox(height: 5),

                      Text(
                        phone,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),

                      const SizedBox(height: 5),

                      Text(
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
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 🔥 GLASS CARD
                _glassTile(Icons.info_outline, "About", about),
                const SizedBox(height: 10),
                _glassTile(Icons.phone_outlined, "Phone", phone),

                const SizedBox(height: 30),

                // 🔥 PREMIUM BUTTON
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GestureDetector(
                    onTap: () async {
                      final updated = Map<String, dynamic>.from(data!);


                      updated['uid'] = user['uid'];

                      await saveToContacts(context, updated);
                    },
                    child: Container(
                      height: 55,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        gradient: const LinearGradient(
                          colors: [Colors.pink, Colors.red],
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          "Save to Contacts",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 30),
              ],
            ),
          );
        },
      ),
    );
  }
  Widget _glassTile(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.pinkAccent),
            const SizedBox(width: 15),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 12)),
                Text(value,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 15)),
              ],
            ),
          ],
        ),
      ),
    );
  }


  Future<void> saveToContacts(
      BuildContext context,
      Map<String, dynamic> data,
      ) async {
    try {
      final permission = await FlutterContacts.requestPermission();

      if (!permission) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Permission denied")),
        );
        return;
      }

      final name = data['name'] ?? "User";
      final phone = data['phone'] ?? "";
      final uid = user['uid']; // 🔥 IMPORTANT

      if (phone.isEmpty || uid == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid contact")),
        );
        return;
      }

      // ✅ 1. SAVE TO PHONE (your existing)
      final newContact = Contact()
        ..name.first = name
        ..phones = [Phone(phone)];

      await newContact.insert();

      // ✅ 2. SAVE TO FIREBASE (🔥 THIS IS THE FIX)
      final currentUser = FirebaseAuth.instance.currentUser;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .collection('contacts')
          .doc(uid)
          .set({
        'name': name,
        'phone': phone,
        'uid': uid,
        'savedAt': FieldValue.serverTimestamp(),
      });

      // ✅ SUCCESS
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Contact saved successfully")),
      );

    } catch (e) {
      print("Save contact error: $e");

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to save contact")),
      );
    }
  }

}
