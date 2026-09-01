import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool isVerified = false;
  Timer? timer;

  @override
  void initState() {
    super.initState();

    final user = FirebaseAuth.instance.currentUser;
    isVerified = user?.emailVerified ?? false;

    if (!isVerified) {
      timer = Timer.periodic(const Duration(seconds: 3), (_) {
        checkEmailVerified();
      });
    }
  }

  Future<void> checkEmailVerified() async {
    final user = FirebaseAuth.instance.currentUser;

    try {
      await user?.reload();
    } on FirebaseAuthException catch (error) {
      debugPrint('Email verification refresh failed: ${error.code}');
      return;
    }

    if (!mounted) return;

    final refreshedUser = FirebaseAuth.instance.currentUser;
    if (refreshedUser?.emailVerified ?? false) {
      timer?.cancel();

      Navigator.pushNamedAndRemoveUntil(
        context,
        '/home',
            (route) => false,
      );
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            CircularProgressIndicator(color: Colors.pink),
            SizedBox(height: 20),
            Text(
              "Waiting for email verification...",
              style: TextStyle(color: Colors.white),
            ),
            SizedBox(height: 10),
            Text(
              "Check your inbox and verify your email",
              style: TextStyle(color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}
