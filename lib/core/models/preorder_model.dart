import 'package:cloud_firestore/cloud_firestore.dart';

class PreorderModel {
  final String id;
  final String studentId;
  final String studentName;
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
    this.studentName = 'Student',
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
    DateTime parsedPickup;
    if (json['pickupTime'] is Timestamp) {
      parsedPickup = (json['pickupTime'] as Timestamp).toDate();
    } else if (json['pickupTime'] is String) {
      parsedPickup = DateTime.tryParse(json['pickupTime']) ?? DateTime.now().add(const Duration(hours: 1));
    } else {
      parsedPickup = DateTime.now().add(const Duration(hours: 1));
    }

    DateTime? parsedCreated;
    if (json['createdAt'] is Timestamp) {
      parsedCreated = (json['createdAt'] as Timestamp).toDate();
    } else if (json['createdAt'] is String) {
      parsedCreated = DateTime.tryParse(json['createdAt']);
    }

    return PreorderModel(
      id: documentId,
      studentId: json['studentId'] ?? json['student_id'] ?? '',
      studentName: json['studentName'] ?? json['student_name'] ?? 'Student',
      vendorId: json['vendorId'] ?? json['vendor_id'] ?? json['vendorUid'] ?? '',
      vendorName: json['vendorName'] ?? json['vendor_name'] ?? 'Unknown Vendor',
      mealName: json['mealName'] ?? json['meal_name'] ?? '',
      price: (json['price'] ?? 0.0).toDouble(),
      quantity: json['quantity'] ?? 1,
      status: json['status'] ?? 'pending',
      pickupTime: parsedPickup,
      createdAt: parsedCreated,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'studentId': studentId,
      'student_id': studentId,
      'studentName': studentName,
      'student_name': studentName,
      'vendorId': vendorId,
      'vendor_id': vendorId,
      'vendorName': vendorName,
      'vendor_name': vendorName,
      'mealName': mealName,
      'meal_name': mealName,
      'price': price,
      'quantity': quantity,
      'status': status,
      'pickupTime': Timestamp.fromDate(pickupTime),
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }
}
