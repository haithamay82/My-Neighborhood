enum UserRole {
  personal,
  business,
}

extension UserRoleExtension on UserRole {
  String get displayName {
    switch (this) {
      case UserRole.personal:
        return 'פרטי';
      case UserRole.business:
        return 'עסקי';
    }
  }
  
  bool get hasFullAccess {
    return this == UserRole.business;
  }
}

class AppUser {
  final String uid;
  final String name;
  final String email;
  final UserRole role;
  
  AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'role': role.name,
    };
  }
  
  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      role: UserRole.values.firstWhere(
        (e) => e.name == map['role'],
        orElse: () => UserRole.personal,
      ),
    );
  }
}
