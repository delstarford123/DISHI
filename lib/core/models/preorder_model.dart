import 'package:cloud_firestore/cloud_firestore.dart';

class PreorderModel {
  final String id;
  final String studentId;
  final String vendorId;
  final String vendorName;
  final String mealName;
  final double price;
  final int quantity;
  final String status; // 'pending', 'preparing', 'ready', 'completed', 'cancelled'
  final DateTime pickupTime;
  final DateTime? createdAt;

  PreorderModel({
    required this.id,
    required this.studentId,
    required this.vendorId,
    required this.vendorName,
    required this.mealName,
    required this.price,
    this.quantity = 1,
    required this.status,
    required this.pickupTime,
    this.createdAt,
  });

  factory PreorderModel.fromJson(Map<String, dynamic> json, String documentId) {
    return PreorderModel(
      id: documentId,
      studentId: json['student_id'] ?? '',
      vendorId: json['vendor_id'] ?? '',
      vendorName: json['vendor_name'] ?? 'Unknown Vendor',
      mealName: json['meal_name'] ?? '',
      price: (json['price'] ?? 0.0).toDouble(),
      quantity: json['quantity'] ?? 1,
      status: json['status'] ?? 'pending',
      pickupTime: (json['pickupTime'] as Timestamp?)?.toDate() ?? DateTime.now().add(const Duration(hours: 1)),
      createdAt: (json['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'student_id': studentId,
      'vendor_id': vendorId,
      'vendor_name': vendorName,
      'meal_name': mealName,
      'price': price,
      'quantity': quantity,
      'status': status,
      'pickupTime': Timestamp.fromDate(pickupTime),
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }
}
