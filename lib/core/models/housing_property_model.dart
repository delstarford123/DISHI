import 'package:cloud_firestore/cloud_firestore.dart';

class HousingPropertyModel {
  final String id;
  final String merchantId;
  final String title;
  final String location;
  final double pricePerMonth;
  final int totalRooms;
  final int availableRooms;
  final List<String> amenities;
  final List<String> imageUrls;
  final bool isVerified;
  final DateTime? createdAt;

  HousingPropertyModel({
    required this.id,
    required this.merchantId,
    required this.title,
    required this.location,
    required this.pricePerMonth,
    required this.totalRooms,
    required this.availableRooms,
    this.amenities = const [],
    this.imageUrls = const [],
    this.isVerified = false,
    this.createdAt,
  });

  factory HousingPropertyModel.fromJson(Map<String, dynamic> json, String documentId) {
    return HousingPropertyModel(
      id: documentId,
      merchantId: json['merchant_id'] ?? '',
      title: json['title'] ?? '',
      location: json['location'] ?? '',
      pricePerMonth: (json['pricePerMonth'] ?? 0.0).toDouble(),
      totalRooms: json['totalRooms'] ?? 0,
      availableRooms: json['availableRooms'] ?? 0,
      amenities: List<String>.from(json['amenities'] ?? []),
      imageUrls: List<String>.from(json['imageUrls'] ?? []),
      isVerified: json['isVerified'] ?? false,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'merchant_id': merchantId,
      'title': title,
      'location': location,
      'pricePerMonth': pricePerMonth,
      'totalRooms': totalRooms,
      'availableRooms': availableRooms,
      'amenities': amenities,
      'imageUrls': imageUrls,
      'isVerified': isVerified,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
