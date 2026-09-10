import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String displayName;
  final String email;
  final List<String> roles;
  final String? profileImageUrl;
  final double walletBalance;
  final double vaultBalance;
  final double okoaBalance;
  final bool isVerified;
  final bool isDriverVerified;
  final String? driverVehicleType;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  
  // New fields for DISHI ID & Offline Students
  final String? dishiId;
  final String? pin;
  final String? authToken;
  final bool isOffline;
  final String? parentUid;
  final String? gender;
  
  // New Profile Hub Features
  final DateTime? dob;
  final String? bio;
  final String? campus;
  final String? course;
  final List<String> dietaryPreferences;
  final String? foodVibe;
  final String? instagram;
  final List<String> interests;
  final bool pushNotifications;
  final bool ghostMode;
  
  // Dashboard & Payment Controls
  final bool isFrozen;
  final double? dailyLimit;
  final bool useSharedWallet;
  final bool allowBuddyTransfers;
  final double savingsBalance;
  final double? autoTopUpThreshold;
  final double? autoTopUpAmount;

  // Health & Nutrition offline features
  final List<String> allergies;
  final Map<String, int> categoryLimits;
  final Map<String, int> categorySpentToday;

  // Advanced Security & Biometrics
  final List<String> whitelistedVendors;
  final List<Map<String, String>> allowedTimeWindows;
  final Map<String, dynamic>? tempPin;
  final String? studentImageUrl;

  // Virtual Card
  final Map<String, dynamic>? virtualCard;

  UserModel({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.roles,
    this.profileImageUrl,
    this.walletBalance = 0.0,
    this.vaultBalance = 0.0,
    this.okoaBalance = 0.0,
    this.isVerified = false,
    this.isDriverVerified = false,
    this.driverVehicleType,
    this.createdAt,
    this.updatedAt,
    this.dishiId,
    this.pin,
    this.authToken,
    this.isOffline = false,
    this.parentUid,
    this.gender,
    this.dob,
    this.bio,
    this.campus,
    this.course,
    this.dietaryPreferences = const [],
    this.foodVibe,
    this.instagram,
    this.interests = const [],
    this.pushNotifications = true,
    this.ghostMode = false,
    this.isFrozen = false,
    this.dailyLimit,
    this.useSharedWallet = false,
    this.allowBuddyTransfers = false,
    this.savingsBalance = 0.0,
    this.autoTopUpThreshold,
    this.autoTopUpAmount,
    this.allergies = const [],
    this.categoryLimits = const {},
    this.categorySpentToday = const {},
    this.whitelistedVendors = const [],
    this.allowedTimeWindows = const [],
    this.tempPin,
    this.studentImageUrl,
    this.virtualCard,
  });

  factory UserModel.fromJson(Map<String, dynamic> json, String documentId) {
    return UserModel(
      uid: documentId,
      displayName: json['displayName'] ?? json['name'] ?? '',
      email: json['email'] ?? '',
      roles: json['roles'] != null ? List<String>.from(json['roles']) : (json['role'] != null ? [json['role']] : ['student']),
      profileImageUrl: json['profileImageUrl'],
      walletBalance: (json['walletBalance'] ?? 0.0).toDouble(),
      vaultBalance: (json['vaultBalance'] ?? 0.0).toDouble(),
      okoaBalance: (json['okoaBalance'] ?? 0.0).toDouble(),
      isVerified: json['isVerified'] ?? false,
      isDriverVerified: json['isDriverVerified'] ?? false,
      driverVehicleType: json['driverVehicleType'],
      createdAt: (json['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate(),
      dishiId: json['dishiId'],
      pin: json['pin'],
      authToken: json['authToken'],
      isOffline: json['isOffline'] ?? false,
      parentUid: json['parentUid'],
      gender: json['gender'],
      dob: (json['dob'] as Timestamp?)?.toDate(),
      bio: json['bio'],
      campus: json['campus'],
      course: json['course'],
      dietaryPreferences: json['dietaryPreferences'] != null ? List<String>.from(json['dietaryPreferences']) : [],
      foodVibe: json['foodVibe'],
      instagram: json['instagram'],
      interests: json['interests'] != null ? List<String>.from(json['interests']) : [],
      pushNotifications: json['pushNotifications'] ?? true,
      ghostMode: json['ghostMode'] ?? false,
      isFrozen: json['isFrozen'] ?? false,
      dailyLimit: json['dailyLimit'] != null ? (json['dailyLimit'] as num).toDouble() : null,
      useSharedWallet: json['useSharedWallet'] ?? false,
      allowBuddyTransfers: json['allowBuddyTransfers'] ?? false,
      savingsBalance: (json['savingsBalance'] ?? 0.0).toDouble(),
      autoTopUpThreshold: json['autoTopUpThreshold'] != null ? (json['autoTopUpThreshold'] as num).toDouble() : null,
      autoTopUpAmount: json['autoTopUpAmount'] != null ? (json['autoTopUpAmount'] as num).toDouble() : null,
      allergies: json['allergies'] != null ? List<String>.from(json['allergies']) : [],
      categoryLimits: json['categoryLimits'] != null ? Map<String, int>.from(json['categoryLimits']) : {},
      categorySpentToday: json['categorySpentToday'] != null ? Map<String, int>.from(json['categorySpentToday']) : {},
      whitelistedVendors: json['whitelistedVendors'] != null ? List<String>.from(json['whitelistedVendors']) : [],
      allowedTimeWindows: json['allowedTimeWindows'] != null ? List<Map<String, String>>.from(
          (json['allowedTimeWindows'] as List).map((e) => Map<String, String>.from(e))) : [],
      tempPin: json['tempPin'],
      studentImageUrl: json['studentImageUrl'],
      virtualCard: json['virtualCard'] != null ? Map<String, dynamic>.from(json['virtualCard']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'displayName': displayName,
      'email': email,
      'roles': roles,
      'profileImageUrl': profileImageUrl,
      'walletBalance': walletBalance,
      'vaultBalance': vaultBalance,
      'okoaBalance': okoaBalance,
      'isVerified': isVerified,
      'isDriverVerified': isDriverVerified,
      'driverVehicleType': driverVehicleType,
      'updatedAt': FieldValue.serverTimestamp(),
      'dishiId': dishiId,
      'pin': pin,
      'authToken': authToken,
      'isOffline': isOffline,
      'parentUid': parentUid,
      'gender': gender,
      'dob': dob,
      'bio': bio,
      'campus': campus,
      'course': course,
      'dietaryPreferences': dietaryPreferences,
      'foodVibe': foodVibe,
      'instagram': instagram,
      'interests': interests,
      'pushNotifications': pushNotifications,
      'ghostMode': ghostMode,
      'isFrozen': isFrozen,
      'dailyLimit': dailyLimit,
      'useSharedWallet': useSharedWallet,
      'allowBuddyTransfers': allowBuddyTransfers,
      'savingsBalance': savingsBalance,
      'autoTopUpThreshold': autoTopUpThreshold,
      'autoTopUpAmount': autoTopUpAmount,
      'allergies': allergies,
      'categoryLimits': categoryLimits,
      'categorySpentToday': categorySpentToday,
      'whitelistedVendors': whitelistedVendors,
      'allowedTimeWindows': allowedTimeWindows,
      'tempPin': tempPin,
      'studentImageUrl': studentImageUrl,
      'virtualCard': virtualCard,
      // Note: createdAt is usually handled by the FirestoreService when adding a document
    };
  }
}
