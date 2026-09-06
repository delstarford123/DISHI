import 'package:cloud_firestore/cloud_firestore.dart';

class TransactionModel {
  final String id;
  final String studentId;
  final String? vendorId;
  final double amount;
  final String type; // 'payment', 'topup', 'transfer', 'rent'
  final String status; // 'pending', 'completed', 'failed'
  final String description;
  final DateTime? timestamp;

  TransactionModel({
    required this.id,
    required this.studentId,
    this.vendorId,
    required this.amount,
    required this.type,
    required this.status,
    required this.description,
    this.timestamp,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json, String documentId) {
    return TransactionModel(
      id: documentId,
      studentId: json['student_id'] ?? '',
      vendorId: json['vendor_id'],
      amount: (json['amount'] ?? 0.0).toDouble(),
      type: json['type'] ?? 'payment',
      status: json['status'] ?? 'pending',
      description: json['description'] ?? '',
      timestamp: (json['timestamp'] as Timestamp?)?.toDate() ?? (json['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'student_id': studentId,
      'vendor_id': vendorId,
      'amount': amount,
      'type': type,
      'status': status,
      'description': description,
      'timestamp': timestamp != null ? Timestamp.fromDate(timestamp!) : FieldValue.serverTimestamp(),
    };
  }
}
