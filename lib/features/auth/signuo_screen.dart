import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_theme.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();
    String phone = _phoneController.text.trim();

    // 🔴 BASIC EMPTY CHECK
    if (email.isEmpty || password.isEmpty || name.isEmpty || phone.isEmpty) {
      _showError("Please fill all fields");
      return;
    }

    // 🔴 EMAIL VALIDATION
    if (!RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$").hasMatch(email)) {
      _showError("Enter a valid email");
      return;
    }

    // 🔴 PHONE VALIDATION (Pakistan)
    if (!RegExp(r"^03\d{9}$").hasMatch(phone)) {
      _showError("Enter valid phone (03XXXXXXXXX)");
      return;
    }

    // 🔴 PASSWORD VALIDATION
    if (password.length < 6) {
      _showError("Password must be at least 6 characters");
      return;
    }

    // ✅ FORMAT PHONE → +92
    phone = "+92${phone.substring(1)}";

    setState(() => _isLoading = true);

    try {
      // 🔥 CREATE ACCOUNT
      final cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = cred.user;
      if (user == null) {
        throw Exception("User creation failed");
      }

      // Firestore user searches require authentication. Check the phone only
      // after account creation, then remove the unused Auth account on a clash.
      final existing = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        await user.delete();
        if (mounted) _showError("Phone already in use");
        return;
      }


      await user.sendEmailVerification();



      // 💾 SAVE PROFILE
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'uid': user.uid,
        'email': email,
        'name': name,
        'phone': phone,
        'about': "Using Bakht ✨",
        'profilePic': "",
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.pushNamed(context, '/verify');

    } on FirebaseAuthException catch (e) {
      String message = "Signup failed";

      switch (e.code) {
        case 'email-already-in-use':
          message = "Email already in use";
          break;
        case 'weak-password':
          message = "Password too weak";
          break;
        case 'invalid-email':
          message = "Invalid email format";
          break;
      }

      if (mounted) _showError(message);

    } catch (e) {
      if (mounted) _showError("Something went wrong");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _input(String hint, TextEditingController controller,
      {bool isPassword = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white24),
          border: InputBorder.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [

              const Text(
                "Create Account",
                style: TextStyle(
                  fontSize: 24,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 30),

              _input("Name", _nameController),
              _input("Phone Number", _phoneController),
              _input("Email", _emailController),
              _input("Password", _passwordController, isPassword: true),

              const SizedBox(height: 20),

              GestureDetector(
                onTap: _isLoading ? null : _handleSignup,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                      "Sign Up",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Text(
                  "Already have an account? Login",
                  style: TextStyle(color: Colors.white38),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
