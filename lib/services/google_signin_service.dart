import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/request.dart';

class GoogleSignInService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email'],
  );

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// כניסה עם Google
  static Future<UserCredential?> signInWithGoogle() async {
    try {
      // התנתקות מחשבון קיים כדי לאפשר בחירה
      await _googleSignIn.signOut();
      
      // המתנה קצרה כדי לוודא שההתנתקות הושלמה
      await Future.delayed(const Duration(milliseconds: 500));
      
      // התחלת תהליך הכניסה עם Google
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        // המשתמש ביטל את הכניסה
        return null;
      }

      // קבלת פרטי האימות
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // יצירת credential עבור Firebase
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // כניסה ל-Firebase
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      
      // שמירת פרטי המשתמש ב-Firestore
      if (userCredential.user != null) {
        await _saveUserToFirestore(userCredential.user!);
      } else {
        debugPrint('❌ Google Sign-In failed: User is null after Firebase authentication');
        throw Exception('User is null after Firebase authentication');
      }
      
      return userCredential;
    } catch (e) {
      debugPrint('Error signing in with Google: $e');
      rethrow;
    }
  }

  /// יציאה מהחשבון
  static Future<void> signOut() async {
    try {
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);
      debugPrint('✅ Signed out from both Firebase and Google');
    } catch (e) {
      debugPrint('Error signing out: $e');
      rethrow;
    }
  }

  /// התנתקות מלאה - מוחקת את כל המידע השמור
  static Future<void> fullSignOut() async {
    try {
      // התנתקות מכל החשבונות
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
        _googleSignIn.disconnect(), // מוחקת את המידע השמור ב-Google
      ]);
      debugPrint('✅ Full sign out completed - all data cleared');
    } catch (e) {
      debugPrint('Error in full sign out: $e');
      rethrow;
    }
  }

  /// בדיקה אם המשתמש מחובר
  static bool isSignedIn() {
    return _auth.currentUser != null;
  }

  /// קבלת המשתמש הנוכחי
  static User? getCurrentUser() {
    return _auth.currentUser;
  }

  /// שמירת פרטי המשתמש ב-Firestore
  static Future<void> _saveUserToFirestore(User user) async {
    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      
      // בדיקה אם המשתמש הוא מנהל
      final isAdminUser = user.email != null ? await isAdmin(user.email!) : false;
      
      if (!userDoc.exists) {
        // יצירת משתמש חדש
        final now = DateTime.now();
        final guestTrialEndDate = now.add(const Duration(days: 60)); // 60 יום תקופת ניסיון
        
        final userData = {
          'uid': user.uid,
          'email': user.email,
          'displayName': user.displayName ?? '',
          'photoURL': user.photoURL ?? '',
          'phoneNumber': user.phoneNumber ?? '',
          'isActive': true,
          'role': isAdminUser ? 'business' : 'personal',
          'createdAt': FieldValue.serverTimestamp(),
          'lastLoginAt': FieldValue.serverTimestamp(),
          'signInMethod': 'google',
        };
        
        // אם זה מנהל, הוסף פרטים נוספים
        if (isAdminUser) {
          userData.addAll({
            'userType': 'business',
            'isSubscriptionActive': true,
            'subscriptionStatus': 'active',
            'subscriptionExpiry': Timestamp.fromDate(
              DateTime.now().add(const Duration(days: 365 * 10)) // 10 שנים
            ),
            'businessCategories': RequestCategory.values.map((e) => e.name).toList(), // גישה לכל הקטגוריות
            'isAdmin': true,
            'latitude': 32.0853,
            'longitude': 34.7818,
            'village': 'תל אביב, ישראל',
          });
        } else {
          // משתמש רגיל - הגדר כאורח
          userData.addAll({
            'userType': 'guest', // כל המשתמשים החדשים נרשמים כאורחים
            'isSubscriptionActive': true, // תקופת אורח פעילה
            'subscriptionStatus': 'active',
            'emailVerified': user.emailVerified,
            'accountStatus': 'active',
            'guestTrialStartDate': Timestamp.fromDate(now),
            'guestTrialEndDate': Timestamp.fromDate(guestTrialEndDate),
            'maxRequestsPerMonth': 10, // גבוה יותר לאורחים
            'maxRadius': 3.0, // 3 ק"מ לאורחים
            'canCreatePaidRequests': true, // אורחים יכולים ליצור בקשות בתשלום
            'businessCategories': [], // יבחרו במסך הבא
            'hasAcceptedTerms': true,
          });
        }
        
        await _firestore.collection('users').doc(user.uid).set(userData);
        
        debugPrint('New Google user created: ${user.email}, isAdmin: $isAdminUser');
      } else {
        // עדכון זמן הכניסה האחרון
        final updateData = {
          'lastLoginAt': FieldValue.serverTimestamp(),
          'signInMethod': 'google',
        };
        
        // אם זה מנהל, וודא שהפרטים נכונים
        if (isAdminUser) {
          updateData.addAll({
            'isAdmin': true,
            'userType': 'business',
            'isSubscriptionActive': true,
            'subscriptionStatus': 'active',
            'businessCategories': RequestCategory.values.map((e) => e.name).toList(), // גישה לכל הקטגוריות
          });
        }
        
        await _firestore.collection('users').doc(user.uid).update(updateData);
        
        debugPrint('Existing Google user logged in: ${user.email}, isAdmin: $isAdminUser');
      }
    } catch (e) {
      debugPrint('Error saving user to Firestore: $e');
      rethrow;
    }
  }

  /// בדיקה אם המשתמש הוא מנהל
  static Future<bool> isAdmin(String email) async {
    try {
      // רשימת מנהלים קבועה
      const adminEmails = ['admin@gmail.com', 'haitham.ay82@gmail.com'];
      
      if (adminEmails.contains(email)) {
        return true;
      }
      
      // בדיקה נוספת ב-Firestore (למקרה של מנהלים נוספים)
      final adminDoc = await _firestore
          .collection('admins')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      
      return adminDoc.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking admin status: $e');
      return false;
    }
  }
}
