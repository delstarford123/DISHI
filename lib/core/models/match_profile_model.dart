import 'package:cloud_firestore/cloud_firestore.dart';

class MatchProfileModel {
  final String uid;
  final String bio;
  final List<String> interests;
  final String primaryLoveLanguage;
  final bool isPremium;
  final bool isVerified;
  final List<String> vibeTags;
  final String? voiceIntroUrl;
  final int swipeCount;
  final DateTime? updatedAt;

  MatchProfileModel({
    required this.uid,
    required this.bio,
    this.interests = const [],
    this.primaryLoveLanguage = '',
    this.isPremium = false,
    this.isVerified = false,
    this.vibeTags = const [],
    this.voiceIntroUrl,
    this.swipeCount = 0,
    this.updatedAt,
  });

  factory MatchProfileModel.fromJson(Map<String, dynamic> json, String documentId) {
    return MatchProfileModel(
      uid: documentId,
      bio: json['bio'] ?? '',
      interests: List<String>.from(json['interests'] ?? []),
      primaryLoveLanguage: json['primaryLoveLanguage'] ?? '',
      isPremium: json['is_premium'] ?? false,
      isVerified: json['isVerified'] ?? false,
      vibeTags: List<String>.from(json['vibeTags'] ?? []),
      voiceIntroUrl: json['voiceIntroUrl'],
      swipeCount: json['swipeCount'] ?? 0,
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bio': bio,
      'interests': interests,
      'primaryLoveLanguage': primaryLoveLanguage,
      // Note: is_premium cannot be explicitly updated by client per firestore.rules
      'isVerified': isVerified,
      'vibeTags': vibeTags,
      'voiceIntroUrl': voiceIntroUrl,
      'swipeCount': swipeCount,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
