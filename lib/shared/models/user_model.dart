class UserModel {
  final String uid;
  final String email;
  final List<String> roles;
  final String? name;
  final String? phoneNumber;
  final bool isVerified;

  UserModel({
    required this.uid,
    required this.email,
    required this.roles,
    this.name,
    this.phoneNumber,
    this.isVerified = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] ?? '',
      email: json['email'] ?? '',
      roles: json['roles'] != null ? List<String>.from(json['roles']) : (json['role'] != null ? [json['role']] : ['student']),
      name: json['name'],
      phoneNumber: json['phone_number'],
      isVerified: json['is_verified'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'roles': roles,
      'name': name,
      'phone_number': phoneNumber,
      'is_verified': isVerified,
    };
  }
}
