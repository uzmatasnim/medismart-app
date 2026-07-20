// lib/services/adherence_service.dart
// FIXED: Stats now update after marking Taken/Missed

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../models/adherence_event_model.dart';

class AdherenceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Uuid _uuid = const Uuid();

  String? get _currentUserId => _auth.currentUser?.uid;

  // ─── RECORD ────────────────────────────────────────────────────
  // FIX 1: Build map directly — toMap() wrote local DateTime objects
  // that conflicted with FieldValue.serverTimestamp(), causing silent
  // Firestore write failures which meant events were never stored.
  Future<String?> recordAdherence({
    required String medId,
    required String medicationName,
    required String status,
    String? note,
    String source = 'MANUAL',
  }) async {
    try {
      if (_currentUserId == null) return null;
      final eventId = _uuid.v4();
      final now = DateTime.now();

      await _firestore.collection('adherence_events').doc(eventId).set({
        'event_id':         eventId,
        'user_id':          _currentUserId,   // needed for read queries
        'med_id':           medId,
        'medication_name':  medicationName,
        'status':           status,           // TAKEN / MISSED / SNOOZED
        'note':             note,
        'source':           source,
        'scheduled_at':     Timestamp.fromDate(now),
        'event_timestamp':  FieldValue.serverTimestamp(),
        'created_at':       FieldValue.serverTimestamp(),
      });

      return eventId;
    } catch (e) {
      print('recordAdherence error: $e');
      return null;
    }
  }

  // ─── READ ──────────────────────────────────────────────────────
  // FIX 2: Removed .orderBy('scheduled_at') which required a composite
  // Firestore index (user_id + scheduled_at). When that index doesn't
  // exist, Firestore silently returns [] — so stats stayed at 0.
  // Now: simple .where('user_id') query + sort in Dart.
  //
  // FIX 3: Removed double inequality filter (startDate + endDate both
  // in Firestore). Multiple range filters on different fields also need
  // a composite index. Now: startDate in Firestore, endDate in Dart.
  Future<List<AdherenceEvent>> getAllUserAdherenceEvents({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      if (_currentUserId == null) return [];

      Query query = _firestore
          .collection('adherence_events')
          .where('user_id', isEqualTo: _currentUserId);

      if (startDate != null) {
        query = query.where('scheduled_at',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      final snapshot = await query.get();

      List<AdherenceEvent> events = snapshot.docs
          .map((doc) => AdherenceEvent.fromMap(doc.data() as Map<String, dynamic>))
          .toList();

      // Sort newest first in Dart — no Firestore index needed
      events.sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));

      // Apply endDate in Dart
      if (endDate != null) {
        events = events.where((e) =>
            e.scheduledAt.isBefore(endDate) ||
            e.scheduledAt.isAtSameMomentAs(endDate)).toList();
      }

      return events;
    } catch (e) {
      print('getAllUserAdherenceEvents error: $e');
      return [];
    }
  }

  Future<List<AdherenceEvent>> getAdherenceEvents({
    required List<String> medicationIds,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      if (medicationIds.isEmpty || _currentUserId == null) return [];
      final all = await getAllUserAdherenceEvents(
          startDate: startDate, endDate: endDate);
      return all.where((e) => medicationIds.contains(e.medId)).toList();
    } catch (e) {
      print('getAdherenceEvents error: $e');
      return [];
    }
  }

  // ─── STATS ─────────────────────────────────────────────────────
  Map<String, dynamic> calculateStats(List<AdherenceEvent> events) {
    if (events.isEmpty) {
      return {'total': 0, 'taken': 0, 'missed': 0, 'snoozed': 0, 'percentage': 0.0};
    }
    final taken   = events.where((e) => e.status == 'TAKEN').length;
    final missed  = events.where((e) => e.status == 'MISSED').length;
    final snoozed = events.where((e) => e.status == 'SNOOZED').length;
    return {
      'total':      events.length,
      'taken':      taken,
      'missed':     missed,
      'snoozed':    snoozed,
      'percentage': (taken / events.length) * 100,
    };
  }

  double getMedicationAdherencePercentage(
      List<AdherenceEvent> events, String medId) {
    final medEvents = events.where((e) => e.medId == medId).toList();
    if (medEvents.isEmpty) return 0.0;
    return (medEvents.where((e) => e.status == 'TAKEN').length /
            medEvents.length) *
        100;
  }
}
