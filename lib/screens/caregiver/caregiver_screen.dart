// lib/screens/caregiver/caregiver_screen.dart
// FULLY REWRITTEN - No map key issues, all data stored directly

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CaregiverScreen extends StatefulWidget {
  const CaregiverScreen({super.key});
  @override
  State<CaregiverScreen> createState() => _CaregiverScreenState();
}

// Simple data class - avoids all map key issues
class PatientData {
  final String patientId;
  final String name;
  final String email;
  final List<Map<String, dynamic>> medications;
  final int taken;
  final int missed;
  final int total;
  double get adherence => total > 0 ? (taken / total) * 100 : 0.0;

  PatientData({
    required this.patientId,
    required this.name,
    required this.email,
    required this.medications,
    required this.taken,
    required this.missed,
    required this.total,
  });
}

class _CaregiverScreenState extends State<CaregiverScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String? _myId = FirebaseAuth.instance.currentUser?.uid;

  List<PatientData> _patients = [];
  bool _isLoading = true;
  String? _expandedId; // which patient card is open

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_myId == null) return;
    if (mounted) setState(() => _isLoading = true);

    try {
      // Step 1: Get all patient IDs assigned to this caregiver
      final assignments = await _db
          .collection('caregiver_assignments')
          .where('caregiver_id', isEqualTo: _myId)
          .where('is_active', isEqualTo: true)
          .get();

      final List<PatientData> result = [];

      for (final doc in assignments.docs) {
        final pid = doc.data()['patient_id'] as String? ?? '';
        if (pid.isEmpty) continue;

        // Step 2: Get patient profile
        final userDoc = await _db.collection('users').doc(pid).get();
        if (!userDoc.exists) continue;

        final userData = userDoc.data()!;
        final name  = userData['name']  as String? ?? 'Unknown';
        final email = userData['email'] as String? ?? '';

        // Step 3: Get patient medications
        final medsSnap = await _db
            .collection('medications')
            .where('patient_id', isEqualTo: pid)
            .where('is_active', isEqualTo: true)
            .get();

        final meds = medsSnap.docs
            .map((d) => d.data() as Map<String, dynamic>)
            .toList();

        // Step 4: Get adherence events for this month
        int taken = 0, missed = 0, total = 0;
        if (meds.isNotEmpty) {
          final medIds = meds.map((m) => m['med_id'] as String).toList();
          final startOfMonth = DateTime(
              DateTime.now().year, DateTime.now().month, 1);

          // Query in chunks of 10 (Firestore whereIn limit)
          for (int i = 0; i < medIds.length; i += 10) {
            final chunk = medIds.sublist(
                i, i + 10 > medIds.length ? medIds.length : i + 10);
            final eventsSnap = await _db
                .collection('adherence_events')
                .where('med_id', whereIn: chunk)
                .where('scheduled_at',
                    isGreaterThanOrEqualTo:
                        Timestamp.fromDate(startOfMonth))
                .get();

            for (final e in eventsSnap.docs) {
              final status = e.data()['status'] as String? ?? '';
              total++;
              if (status == 'TAKEN') taken++;
              if (status == 'MISSED') missed++;
            }
          }
        }

        result.add(PatientData(
          patientId: pid,
          name: name,
          email: email,
          medications: meds,
          taken: taken,
          missed: missed,
          total: total,
        ));
      }

      if (mounted) setState(() { _patients = result; _isLoading = false; });
    } catch (e) {
      print('caregiver load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addPatient() async {
    final ctrl = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Patient'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Patient Email',
            prefixIcon: Icon(Icons.email),
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Add')),
        ],
      ),
    );

    if (email == null || email.isEmpty) return;

    try {
      // Find user by email
      final snap = await _db
          .collection('users')
          .where('email', isEqualTo: email.toLowerCase())
          .get();

      if (snap.docs.isEmpty) {
        _snack('No user found with that email', Colors.red);
        return;
      }

      final patientDoc = snap.docs.first;
      final role = patientDoc.data()['role'] as String? ?? '';
      if (role != 'PATIENT') {
        _snack('That user is not a patient', Colors.orange);
        return;
      }

      final patientId = patientDoc.id;
      final assignId  = '${_myId}_$patientId';

      await _db.collection('caregiver_assignments').doc(assignId).set({
        'assignment_id': assignId,
        'caregiver_id': _myId,
        'patient_id':   patientId,
        'scope':        'VIEW',
        'is_active':    true,
        'created_at':   FieldValue.serverTimestamp(),
      });

      _snack('✅ Patient ${patientDoc.data()['name']} added!', Colors.green);
      await _load();
    } catch (e) {
      _snack('Error: $e', Colors.red);
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Patients'),
        actions: [
          IconButton(
              icon: const Icon(Icons.person_add),
              onPressed: _addPatient,
              tooltip: 'Add Patient'),
          IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _load),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _patients.isEmpty
              ? _empty()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _patients.length,
                    itemBuilder: (_, i) => _card(_patients[i]),
                  ),
                ),
    );
  }

  Widget _card(PatientData p) {
    final isOpen = _expandedId == p.patientId;
    final adColor = p.adherence >= 70
        ? Colors.green
        : p.adherence >= 40
            ? Colors.orange
            : Colors.red;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        // Header row — tap to expand/collapse
        InkWell(
          onTap: () => setState(
              () => _expandedId = isOpen ? null : p.patientId),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              // Avatar
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF2196F3).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person,
                    color: Color(0xFF2196F3), size: 28),
              ),
              const SizedBox(width: 12),
              // Name + email
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(p.email,
                          style: TextStyle(
                              color: Colors.grey[600], fontSize: 12)),
                    ]),
              ),
              // Adherence %
              Column(children: [
                Text('${p.adherence.toStringAsFixed(0)}%',
                    style: TextStyle(
                        color: adColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 18)),
                Text('adherence',
                    style:
                        TextStyle(color: Colors.grey[500], fontSize: 10)),
              ]),
              const SizedBox(width: 8),
              Icon(isOpen
                  ? Icons.keyboard_arrow_up
                  : Icons.keyboard_arrow_down),
            ]),
          ),
        ),

        // Expanded details
        if (isOpen) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats chips
                  Wrap(spacing: 8, children: [
                    _chip('${p.medications.length} Medications',
                        Colors.blue),
                    _chip('${p.taken} Taken', Colors.green),
                    _chip('${p.missed} Missed', Colors.red),
                    _chip('${p.total} Total', Colors.orange),
                  ]),
                  const SizedBox(height: 12),

                  // Adherence bar
                  if (p.total > 0) ...[
                    Text(
                        'Adherence this month: ${p.adherence.toStringAsFixed(0)}%',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: p.adherence / 100,
                        minHeight: 10,
                        backgroundColor: Colors.grey[200],
                        valueColor:
                            AlwaysStoppedAnimation<Color>(adColor),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Medication list
                  const Text('Medications:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (p.medications.isEmpty)
                    Text('No medications added',
                        style: TextStyle(
                            color: Colors.grey[600], fontSize: 13))
                  else
                    ...p.medications.map((med) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(children: [
                            const Icon(Icons.medication,
                                color: Color(0xFF2196F3), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${med['name']} — '
                                      '${med['dosage_amount']}${med['dosage_unit']}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13),
                                    ),
                                    Text(med['frequency'] ?? '',
                                        style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12)),
                                  ]),
                            ),
                          ]),
                        )),
                ]),
          ),
        ],
      ]),
    );
  }

  Widget _chip(String label, Color color) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Text(label,
            style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold)),
      );

  Widget _empty() => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.people_outline, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 24),
          Text('No Patients Assigned',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700])),
          const SizedBox(height: 12),
          Text('Tap the + icon above to add a patient by email',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        ]),
      );
}
