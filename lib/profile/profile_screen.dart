import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import 'fullscreenimage.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  File? _imageFile;
  String? profilePicUrl;
  String phoneNumber = "";

  final TextEditingController nameController = TextEditingController();
  final TextEditingController aboutController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();

  bool isLoading = false;
  bool isDataLoading = true;

  @override
  void dispose() {
    nameController.dispose();
    aboutController.dispose();
    usernameController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    loadUserData();
  }

  // 🔥 LOAD EXISTING DATA
  Future<void> loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = doc.data();

      if (data != null) {
        nameController.text = data['name'] ?? "";
        aboutController.text = data['about'] ?? "Using Bakht ✨";
        usernameController.text = data['username'] ?? "";
        profilePicUrl = data['profilePic'] ?? "";
        phoneNumber = data['phone'] ?? "";
      }

    } catch (e) {
      print("Load error: $e");
    }

    if (mounted) setState(() => isDataLoading = false);
  }

  Future<void> saveProfile() async {

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final name = nameController.text.trim();
    final about = aboutController.text.trim();
    final username = usernameController.text.trim();

    if (name.isEmpty || username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Name & Username required")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      // 🔥 Upload image
      final imageUrl = await uploadProfileImage(user.uid);

      // 🔥 Save data
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'name': name,
        'about': about,
        'username': username,
        'profilePic': imageUrl ?? profilePicUrl ?? "",
        'profileCompleted': true,
        'phone': phoneNumber,
      }, SetOptions(merge: true));

      setState(() => isLoading = false);

      Navigator.pushReplacementNamed(context, '/home');

    } catch (e) {
      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error saving profile")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {

    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Profile"),
      ),

      body: isDataLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [

          const SizedBox(height: 20),

          // 🔥 PROFILE IMAGE
          Center(
            child: Stack(
              children: [

                GestureDetector(
                  onTap: () {
                    // 🔥 decide which image to show
                    final imageUrl = _imageFile != null
                        ? _imageFile!.path
                        : (profilePicUrl ?? "");

                    if (imageUrl.isEmpty) return;

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FullScreenImage(
                          imageUrl: imageUrl,
                          isFile: _imageFile != null, // 🔥 important
                        ),
                      ),
                    );
                  },
                  child: CircleAvatar(
                    radius: 60,
                    backgroundColor: AppColors.highlight,

                    backgroundImage: _imageFile != null
                        ? FileImage(_imageFile!)
                        : (profilePicUrl != null && profilePicUrl!.isNotEmpty
                        ? NetworkImage(profilePicUrl!)
                        : null),

                    child: (_imageFile == null &&
                        (profilePicUrl == null || profilePicUrl!.isEmpty))
                        ? const Icon(Icons.person, size: 50, color: Colors.white)
                        : null,
                  ),
                ),

                // 🔥 CAMERA BUTTON
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: CircleAvatar(
                    backgroundColor: AppColors.accent,
                    radius: 18,
                    child: IconButton(
                      icon: const Icon(
                        Icons.camera_alt,
                        size: 18,
                        color: Colors.white,
                      ),
                      onPressed: pickImage, // ✅ CONNECTED
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 25),

          // 🔹 USERNAME
          _inputField(
            controller: usernameController,
            label: "Username (@handle)",
            icon: Icons.alternate_email,
          ),

          const SizedBox(height: 12),

          // 🔹 NAME
          _inputField(
            controller: nameController,
            label: "Name",
            icon: Icons.person_outline,
          ),

          const SizedBox(height: 12),

          // 🔹 ABOUT
          _inputField(
            controller: aboutController,
            label: "About",
            icon: Icons.info_outline,
            maxLines: 2,
          ),

          const SizedBox(height: 15),

          // 🔹 PHONE
          _profileField(
            "Phone",
            phoneNumber,
            Icons.phone_outlined,
          ),

          // 🔹 EMAIL
          _profileField(
            "Email",
            user?.email ?? "",
            Icons.email_outlined,
          ),

          const Spacer(),

          // 🔥 SAVE BUTTON
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: isLoading ? null : saveProfile,
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                  "Save",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🔥 INPUT FIELD
  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white38),
          prefixIcon: Icon(icon),
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
  Future<String?> uploadProfileImage(String uid) async {
    if (_imageFile == null) return profilePicUrl;

    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_pics/$uid.jpg');

      await ref.putFile(_imageFile!);

      final url = await ref.getDownloadURL();

      return url;
    } catch (e) {
      print("Upload error: $e");
      return null;
    }
  }
  Future<void> pickImage() async {
    final picker = ImagePicker();

    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70, // 🔥 compress (faster upload)
    );

    if (picked != null) {
      setState(() {
        _imageFile = File(picked.path);
      });
    }
  }

  // 🔥 DISPLAY FIELD
  Widget _profileField(String label, String value, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: AppColors.accent),
      title: Text(label,
          style: const TextStyle(color: Colors.white38, fontSize: 13)),
      subtitle: Text(value,
          style: const TextStyle(color: Colors.white, fontSize: 16)),
    );
  }
}
