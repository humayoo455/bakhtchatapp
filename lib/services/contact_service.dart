import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ContactService {
  Future<void> addContact(String phone) async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) return;

    final userQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('phone', isEqualTo: phone)
        .get();

    if (userQuery.docs.isEmpty) {
      print("User not found");
      return;
    }

    final contactData = userQuery.docs.first.data();

    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('contacts')
        .doc(userQuery.docs.first.id)
        .set({
      'phone': contactData['phone'],
      'name': contactData['name'],
    });

    print("Contact added");
  }
}