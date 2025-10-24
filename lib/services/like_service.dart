import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/like.dart';

class LikeService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// הוספת LIKE לבקשה
  static Future<bool> likeRequest(String requestId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final likeId = '${user.uid}_$requestId';
      
      // בדיקה אם כבר יש LIKE
      final existingLike = await _firestore
          .collection('likes')
          .doc(likeId)
          .get();

      if (existingLike.exists) {
        // אם כבר יש LIKE, הסר אותו
        await _firestore.collection('likes').doc(likeId).delete();
        return false; // הסרת LIKE
      } else {
        // הוסף LIKE חדש
        final like = Like(
          id: likeId,
          requestId: requestId,
          userId: user.uid,
          createdAt: DateTime.now(),
        );

        await _firestore
            .collection('likes')
            .doc(likeId)
            .set(like.toMap());

        return true; // הוספת LIKE
      }
    } catch (e) {
      debugPrint('Error liking request: $e');
      return false;
    }
  }

  /// בדיקה אם המשתמש הנוכחי אהב את הבקשה
  static Future<bool> isLikedByCurrentUser(String requestId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final likeId = '${user.uid}_$requestId';
      final likeDoc = await _firestore
          .collection('likes')
          .doc(likeId)
          .get();

      return likeDoc.exists;
    } catch (e) {
      debugPrint('Error checking if liked: $e');
      return false;
    }
  }

  /// קבלת מספר ה-LIKEs לבקשה
  static Future<int> getLikesCount(String requestId) async {
    try {
      final querySnapshot = await _firestore
          .collection('likes')
          .where('requestId', isEqualTo: requestId)
          .get();

      return querySnapshot.docs.length;
    } catch (e) {
      debugPrint('Error getting likes count: $e');
      return 0;
    }
  }

  /// Stream של מספר ה-LIKEs לבקשה
  static Stream<int> getLikesCountStream(String requestId) {
    return _firestore
        .collection('likes')
        .where('requestId', isEqualTo: requestId)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Stream לבדיקה אם המשתמש הנוכחי אהב את הבקשה
  static Stream<bool> isLikedByCurrentUserStream(String requestId) {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(false);

    final likeId = '${user.uid}_$requestId';
    return _firestore
        .collection('likes')
        .doc(likeId)
        .snapshots()
        .map((doc) => doc.exists);
  }
}
