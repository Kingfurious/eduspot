import 'package:cloud_firestore/cloud_firestore.dart';
import 'ad_model.dart';

class AdService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Fetch ads for a specific placement location
  Future<List<AdModel>> getAdsForPlacement(String placement) async {
    try {
      final now = Timestamp.now();

      final querySnapshot = await _firestore
          .collection('ads')
          .where('placementLocation', isEqualTo: placement)
          .where('isActive', isEqualTo: true)
          .where('expiryDate', isGreaterThan: now)
          .orderBy('expiryDate', descending: false)
          .limit(5) // Limit the number of ads to fetch
          .get();

      return querySnapshot.docs
          .map((doc) => AdModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print('Error fetching ads: $e');
      return [];
    }
  }

  // Record an impression for an ad
  Future<void> recordImpression(String adId) async {
    try {
      await _firestore.collection('ads').doc(adId).update({
        'impressions': FieldValue.increment(1),
      });
    } catch (e) {
      print('Error recording impression: $e');
    }
  }

  // Record a click for an ad
  Future<void> recordClick(String adId) async {
    try {
      await _firestore.collection('ads').doc(adId).update({
        'clicks': FieldValue.increment(1),
      });
    } catch (e) {
      print('Error recording click: $e');
    }
  }
}