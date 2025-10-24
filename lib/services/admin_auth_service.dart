import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/request.dart';

class AdminAuthService {
  // פרטי המנהלים (יש לשמור בסוד!)
  static const String _adminEmail = 'admin@gmail.com';
  static const String _adminPassword = '1q2w3e';
  static const String _adminEmail2 = 'haitham.ay82@gmail.com';
  
  /// רשימת כל המנהלים
  static const List<String> _adminEmails = [_adminEmail, _adminEmail2];
  
  /// בדיקה אם המשתמש הנוכחי הוא מנהל
  static bool isCurrentUserAdmin() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('🔍 Admin check: No current user');
      return false;
    }
    
    final isAdmin = _adminEmails.contains(user.email);
    print('🔍 Admin check: User email: ${user.email}, Is admin: $isAdmin');
    return isAdmin;
  }
  
  /// התחברות כמנהל
  static Future<bool> loginAsAdmin(String email, String password) async {
    try {
      if (email != _adminEmail || password != _adminPassword) {
        return false;
      }
      
      // התחברות עם Firebase Auth
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (credential.user != null) {
        // וידוא שהמנהל מוגדר כעסקי עם מנוי פעיל
        await _ensureAdminProfile(credential.user!);
        return true;
      }
      
      return false;
    } catch (e) {
      print('Admin login error: $e');
      return false;
    }
  }
  
  /// וידוא שהמנהל הנוכחי מוגדר כעסקי
  static Future<void> ensureAdminProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('❌ ensureAdminProfile: No current user');
      return;
    }
    
    if (!isCurrentUserAdmin()) {
      print('❌ ensureAdminProfile: Current user is not admin');
      return;
    }

    print('✅ ensureAdminProfile: Ensuring admin profile for user: ${user.email}');
    await _ensureAdminProfile(user);
    
    // וידוא שהמנהל מעודכן עם businessCategories נכון
    await _updateAdminBusinessCategories(user);
  }

  /// עדכון businessCategories למנהל
  static Future<void> _updateAdminBusinessCategories(User user) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'businessCategories': RequestCategory.values.map((e) => e.name).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('Admin business categories updated successfully');
    } catch (e) {
      print('Error updating admin business categories: $e');
    }
  }

  /// עדכון מיקום המנהל
  static Future<void> updateAdminLocation(double latitude, double longitude, String address) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !isCurrentUserAdmin()) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'latitude': latitude,
        'longitude': longitude,
        'village': address,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('Admin location updated successfully');
    } catch (e) {
      print('Error updating admin location: $e');
    }
  }

  /// וידוא שהמנהל מוגדר כעסקי עם מנוי פעיל
  static Future<void> _ensureAdminProfile(User user) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (!userDoc.exists) {
        // יצירת פרופיל מנהל חדש
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
          'userId': user.uid,
          'displayName': user.displayName ?? 'מנהל מערכת',
          'email': user.email,
          'userType': 'business',
          'isSubscriptionActive': true,
          'subscriptionStatus': 'active',
          'subscriptionExpiry': Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 365 * 10)) // 10 שנים
          ),
          'createdAt': Timestamp.now(),
          'businessCategories': RequestCategory.values.map((e) => e.name).toList(), // גישה לכל הקטגוריות
          'isAdmin': true,
          // מיקום ברירת מחדל למנהל (תל אביב)
          'latitude': 32.0853,
          'longitude': 34.7818,
          'village': 'תל אביב, ישראל',
        });
      } else {
        // עדכון פרופיל קיים למנהל
        final userData = userDoc.data()!;
        final hasLocation = userData['latitude'] != null && userData['longitude'] != null;
        
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'displayName': user.displayName ?? 'מנהל מערכת',
          'userType': 'business',
          'isSubscriptionActive': true,
          'subscriptionStatus': 'active',
          'subscriptionExpiry': Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 365 * 10)) // 10 שנים
          ),
          'businessCategories': RequestCategory.values.map((e) => e.name).toList(), // גישה לכל הקטגוריות
          'isAdmin': true,
          'updatedAt': FieldValue.serverTimestamp(),
          // הוספת מיקום ברירת מחדל רק אם לא קיים
          if (!hasLocation) ...{
            'latitude': 32.0853,
            'longitude': 34.7818,
            'village': 'תל אביב, ישראל',
          },
        });
      }
    } catch (e) {
      print('Error ensuring admin profile: $e');
    }
  }
  
  /// יצירת חשבון מנהל (רק פעם אחת)
  static Future<bool> createAdminAccount() async {
    try {
      print('🔧 Starting admin account creation process...');
      
      // בדיקה אם החשבון כבר קיים
      try {
        print('🔍 Checking if admin account already exists...');
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _adminEmail,
          password: _adminPassword,
        );
        print('✅ Admin account already exists');
        await FirebaseAuth.instance.signOut(); // התנתקות אחרי הבדיקה
        return true; // החשבון כבר קיים
      } catch (e) {
        print('ℹ️ Admin account does not exist, will create new one. Error: $e');
        // החשבון לא קיים, בואו ניצור אותו
      }
      
      // יצירת חשבון מנהל
      print('🔨 Creating new admin account...');
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _adminEmail,
        password: _adminPassword,
      );
      
      if (credential.user != null) {
        print('✅ Admin account created successfully');
        
        // עדכון שם המנהל
        await credential.user!.updateDisplayName('מנהל מערכת');
        print('✅ Admin display name updated');
        
        // יצירת פרופיל מנהל ב-Firestore
        await _ensureAdminProfile(credential.user!);
        print('✅ Admin profile created in Firestore');
        
        // התנתקות אחרי יצירת החשבון
        await FirebaseAuth.instance.signOut();
        print('✅ Signed out after account creation');
        
        return true;
      }
      
      print('❌ Failed to create admin account - no user returned');
      return false;
    } catch (e) {
      print('❌ Error creating admin account: $e');
      return false;
    }
  }
  
  /// התנתקות
  static Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
  }
  
  /// בדיקה אם יש מנהל רשום במערכת
  static Future<bool> hasAdminAccount() async {
    try {
      print('🔍 Checking if admin account exists...');
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _adminEmail,
        password: _adminPassword,
      );
      print('✅ Admin account exists and credentials are valid');
      await FirebaseAuth.instance.signOut();
      return true;
    } catch (e) {
      print('❌ Admin account does not exist or credentials are invalid: $e');
      return false;
    }
  }
  
  /// בדיקה מהירה אם החשבון קיים (ללא התחברות)
  static Future<bool> checkAdminAccountExists() async {
    try {
      // נסה להתחבר עם פרטי המנהל
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _adminEmail,
        password: _adminPassword,
      );
      
      if (credential.user != null) {
        print('✅ Admin account exists');
        await FirebaseAuth.instance.signOut();
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Admin account check failed: $e');
      return false;
    }
  }
}
