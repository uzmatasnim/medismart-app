// lib/services/medication_service.dart
// FIXED: Proper error propagation + Firestore query fixed (no composite index needed)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../models/medication_model.dart';

class MedicationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Uuid _uuid = const Uuid();

  String? get _currentUserId => _auth.currentUser?.uid;

  /// Add a new medication
  /// FIX 1: Returns medId on success, throws exception on failure (no silent null)
  Future<String?> addMedication(Medication medication) async {
    try {
      if (_currentUserId == null) {
        throw Exception('User not authenticated. Please log in again.');
      }

      final medId = _uuid.v4();

      // FIX 2: Build clean map without null Timestamp fields that cause Firestore errors
      final Map<String, dynamic> medData = {
        'med_id': medId,
        'patient_id': _currentUserId,
        'name': medication.name.trim(),
        'form': medication.form,
        'dosage_amount': medication.dosageAmount,
        'dosage_unit': medication.dosageUnit,
        'frequency': medication.frequency.trim(),
        'reminder_time': medication.reminderTime,
        'instructions': medication.instructions,
        'is_active': true,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
        // FIX 3: Only add startDate if not null — avoid Timestamp(null) crash
        if (medication.startDate != null)
          'start_date': Timestamp.fromDate(medication.startDate!),
        if (medication.endDate != null)
          'end_date': Timestamp.fromDate(medication.endDate!),
      };

      await _firestore.collection('medications').doc(medId).set(medData);
      return medId;
    } catch (e) {
      // Re-throw so the UI can show the real error message
      throw Exception('Failed to save medication: $e');
    }
  }

  /// Get all active medications for current user
  /// FIX 4: Removed .orderBy('created_at') which requires a composite index
  /// Simple query works without any index
  Future<List<Medication>> getUserMedications() async {
    try {
      if (_currentUserId == null) return [];

      QuerySnapshot snapshot = await _firestore
          .collection('medications')
          .where('patient_id', isEqualTo: _currentUserId)
          .where('is_active', isEqualTo: true)
          .get();

      List<Medication> meds = snapshot.docs
          .map((doc) => Medication.fromMap(doc.data() as Map<String, dynamic>))
          .toList();

      // Sort in Dart instead of Firestore to avoid index requirement
      meds.sort((a, b) {
        final aTime = a.createdAt ?? DateTime(2000);
        final bTime = b.createdAt ?? DateTime(2000);
        return bTime.compareTo(aTime); // newest first
      });

      return meds;
    } catch (e) {
      print('Get medications error: $e');
      return [];
    }
  }

  /// Real-time stream of user medications
  Stream<List<Medication>> getUserMedicationsStream() {
    if (_currentUserId == null) return Stream.value([]);

    return _firestore
        .collection('medications')
        .where('patient_id', isEqualTo: _currentUserId)
        .where('is_active', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      List<Medication> meds = snapshot.docs
          .map((doc) => Medication.fromMap(doc.data()))
          .toList();
      meds.sort((a, b) {
        final aTime = a.createdAt ?? DateTime(2000);
        final bTime = b.createdAt ?? DateTime(2000);
        return bTime.compareTo(aTime);
      });
      return meds;
    });
  }

  /// Get a medication by ID
  Future<Medication?> getMedicationById(String medId) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection('medications').doc(medId).get();
      if (doc.exists) {
        return Medication.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('Get medication error: $e');
      return null;
    }
  }

  /// Update a medication
  Future<bool> updateMedication(
      String medId, Map<String, dynamic> updates) async {
    try {
      updates['updated_at'] = FieldValue.serverTimestamp();
      await _firestore.collection('medications').doc(medId).update(updates);
      return true;
    } catch (e) {
      print('Update medication error: $e');
      return false;
    }
  }

  /// Soft delete a medication
  Future<bool> deleteMedication(String medId) async {
    try {
      await _firestore.collection('medications').doc(medId).update({
        'is_active': false,
        'updated_at': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Delete medication error: $e');
      return false;
    }
  }

  /// Search medications by name (client-side)
  Future<List<Medication>> searchMedications(String query) async {
    try {
      if (query.isEmpty) return await getUserMedications();
      List<Medication> all = await getUserMedications();
      return all
          .where((m) => m.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get today's medications
  Future<List<Medication>> getTodayMedications() async {
    return await getUserMedications();
  }

  /// Get medications for a patient (caregiver use)
  Future<List<Medication>> getPatientMedications(String patientId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('medications')
          .where('patient_id', isEqualTo: patientId)
          .where('is_active', isEqualTo: true)
          .get();
      return snapshot.docs
          .map((doc) =>
              Medication.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }
}
