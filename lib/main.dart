import 'package:bakht/profile/profile_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Internal Imports
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/signuo_screen.dart';
import 'features/auth/verify_email_screen.dart';
import 'features/chat/chat_screen.dart';
import 'features/chat/contact_select_screen.dart';
import 'features/home/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const BakhtChatApp());
}

class BakhtChatApp extends StatelessWidget {
  const BakhtChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bakht Chat',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
        primaryColor: AppColors.accent,
      ),

      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final user = snapshot.data;

          if (user != null) {
            if (user.emailVerified) {
              return const HomeScreen(); // ✅ verified
            } else {
              return const VerifyEmailScreen(); // 🔥 block access
            }
          }

          return const LoginScreen(); // not logged in
        },
      ),

      routes: {
        '/signup': (context) => const SignupScreen(),
        '/verify': (context) => const VerifyEmailScreen(),
        '/home': (context) => const HomeScreen(),
        '/chat': (context) => const ChatScreenUI(),
        '/contacts': (context) => const ContactsScreen(),
        '/profile': (context) => const ProfileScreen(),
      },
    );
  }
}
