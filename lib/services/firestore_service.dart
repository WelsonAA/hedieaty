import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Save business card data to Firestore
  Future<void> saveBusinessCard(String userId, String name, String jobTitle, String companyName, String contactInfo, String? profilePic) async {
    try {
      await _firestore.collection('business_cards').doc(userId).set({
        'name': name,
        'job_title': jobTitle,
        'company_name': companyName,
        'contact_info': contactInfo,
        'profile_pic': profilePic ?? '',
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("Error saving card data: $e");
    }
  }

  // Get business card data from Firestore
  Future<Map<String, dynamic>?> getBusinessCard(String userId) async {
    try {
      DocumentSnapshot snapshot = await _firestore.collection('business_cards').doc(userId).get();
      return snapshot.data() as Map<String, dynamic>?;
    } catch (e) {
      print("Error fetching card data: $e");
      return null;
    }
  }
}
