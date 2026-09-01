import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/phone_formatter.dart';
import '../../profile/fullscreenimage.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {

  final TextEditingController _searchController = TextEditingController();

  List<QueryDocumentSnapshot> results = [];
  bool isLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> searchUser(String input) async {
    if (input.isEmpty) {
      setState(() => results = []);
      return;
    }

    final phone = formatPakistanPhone(input);

    setState(() => isLoading = true);

    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', isEqualTo: phone)
          .get();

      setState(() {
        results = query.docs;
      });

    } catch (e) {
      if (mounted) {
        final message = e is FirebaseException && e.code == 'permission-denied'
            ? 'User search is not permitted. Please update Firestore rules.'
            : 'Could not search users. Please try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    }

    if (mounted) setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Colors.black,

      appBar: AppBar(
        title: const Text("New Chat"),
        backgroundColor: Colors.black,
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            // 🔍 SEARCH BAR
            Container(
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(30),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [

                  const Icon(Icons.search, color: Colors.white54),

                  const SizedBox(width: 10),

                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: "Search phone number",
                        hintStyle: TextStyle(color: Colors.white38),
                        border: InputBorder.none,
                      ),
                      onChanged: searchUser, // 🔥 LIVE SEARCH
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            if (isLoading)
              const CircularProgressIndicator(),

            // 🔥 RESULTS
            Expanded(
              child: results.isEmpty
                  ? const Center(
                child: Text(
                  "Search users by phone",
                  style: TextStyle(color: Colors.white38),
                ),
              )
                  : ListView.builder(
                itemCount: results.length,
                itemBuilder: (context, index) {

                  final userData =
                  results[index].data() as Map<String, dynamic>;

                  final userId = results[index].id;

                  return ListTile(
                    leading: GestureDetector(
                      onTap: () {
                        final imageUrl = userData['profilePic'] ?? "";

                        if (imageUrl.isEmpty) return;

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FullScreenImage(imageUrl: imageUrl),
                          ),
                        );
                      },
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor: AppColors.highlight,
                        backgroundImage:
                        (userData['profilePic'] != null &&
                            userData['profilePic'].toString().isNotEmpty)
                            ? NetworkImage(userData['profilePic'])
                            : null,
                        child: (userData['profilePic'] == null ||
                            userData['profilePic'].toString().isEmpty)
                            ? const Icon(Icons.person, color: Colors.white)
                            : null,
                      ),
                    ),

                    title: Text(
                      userData['name'] ?? "No Name",
                      style: const TextStyle(color: Colors.white),
                    ),

                    subtitle: Text(
                      userData['phone'] ?? "",
                      style: const TextStyle(color: Colors.white54),
                    ),

                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        '/chat',
                        arguments: {
                          'uid': userId,
                          'phone': userData['phone'],
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
