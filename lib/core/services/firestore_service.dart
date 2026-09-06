import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ── Helper to check authentication
  void _requireAuth() {
    if (_auth.currentUser == null) {
      throw Exception('User must be authenticated to perform this action.');
    }
  }

  // ── Generic CRUD Operations ───────────────────────────────────────────────

  /// Fetch a single document by ID
  Future<DocumentSnapshot> getDocument(String collectionPath, String docId) async {
    _requireAuth();
    return await _db.collection(collectionPath).doc(docId).get();
  }

  /// Add a new document (auto-generated ID)
  Future<DocumentReference> addDocument(String collectionPath, Map<String, dynamic> data) async {
    _requireAuth();
    data['createdAt'] = FieldValue.serverTimestamp();
    return await _db.collection(collectionPath).add(data);
  }

  /// Set a document with a specific ID (creates or overwrites)
  Future<void> setDocument(String collectionPath, String docId, Map<String, dynamic> data, {bool merge = true}) async {
    _requireAuth();
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _db.collection(collectionPath).doc(docId).set(data, SetOptions(merge: merge));
  }

  /// Update an existing document
  Future<void> updateDocument(String collectionPath, String docId, Map<String, dynamic> data) async {
    _requireAuth();
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _db.collection(collectionPath).doc(docId).update(data);
  }

  /// Delete a document
  Future<void> deleteDocument(String collectionPath, String docId) async {
    _requireAuth();
    await _db.collection(collectionPath).doc(docId).delete();
  }

  // ── Streams for Real-Time UI Updates (Replacing Mock Data) ───────────────

  /// Stream a single document
  Stream<DocumentSnapshot> streamDocument(String collectionPath, String docId) {
    _requireAuth();
    return _db.collection(collectionPath).doc(docId).snapshots();
  }

  /// Stream a collection (with optional filtering)
  Stream<QuerySnapshot> streamCollection(String collectionPath, {
    String? whereField,
    dynamic isEqualTo,
    String? orderByField,
    bool descending = false,
    int? limit,
  }) {
    _requireAuth();
    Query query = _db.collection(collectionPath);

    if (whereField != null && isEqualTo != null) {
      query = query.where(whereField, isEqualTo: isEqualTo);
    }
    if (orderByField != null) {
      query = query.orderBy(orderByField, descending: descending);
    }
    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots();
  }

  // ── Pre-configured Queries based on firestore.rules ──────────────────────

  /// Get current user's profile
  Stream<DocumentSnapshot> streamCurrentUserProfile() {
    _requireAuth();
    return streamDocument('users', _auth.currentUser!.uid);
  }

  /// Stream housing properties owned by the current merchant
  Stream<QuerySnapshot> streamMyProperties() {
    _requireAuth();
    return streamCollection('housing_properties', whereField: 'merchant_id', isEqualTo: _auth.currentUser!.uid);
  }

  /// Stream match profiles
  Stream<QuerySnapshot> streamMatchProfiles() {
    _requireAuth();
    return streamCollection('match_profiles', limit: 20);
  }

  // ── Global Aggregations (Admin Level) ────────────────────────────────────

  /// Get total count of documents in a collection
  Future<int> getCollectionCount(String collectionPath, {String? whereField, dynamic isEqualTo}) async {
    _requireAuth();
    Query query = _db.collection(collectionPath);
    if (whereField != null && isEqualTo != null) {
      query = query.where(whereField, isEqualTo: isEqualTo);
    }
    final AggregateQuerySnapshot snapshot = await query.count().get();
    return snapshot.count ?? 0;
  }

  /// Get the sum of a specific numerical field across a collection
  Future<double> getCollectionSum(String collectionPath, String field) async {
    _requireAuth();
    final AggregateQuerySnapshot snapshot = await _db.collection(collectionPath).aggregate(sum(field)).get();
    return (snapshot.getSum(field) ?? 0.0).toDouble();
  }
}
