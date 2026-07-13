// lib/screens/caregiver/caregiver_screen.dart
// UC-12: Manage Multiple Patients (Caregiver)

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:medismart/models/medication_model.dart';
import 'package:medismart/services/medication_service.dart';
import 'package:medismart/services/adherence_service.dart';

class CaregiverScreen extends StatefulWidget {
  const CaregiverScreen({super.key});
  @override
  State<CaregiverScreen> createState() => _CaregiverScreenState();
}

class _CaregiverScreenState extends State<CaregiverScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String? _caregiverId = FirebaseAuth.instance.currentUser?.uid;
  final MedicationService _medicationService = MedicationService();
  final AdherenceService _adherenceService = AdherenceService();

  List<Map<String, dynamic>> _patients = [];
  Map<String, List<Medication>> _patientMedications = {};
  Map<String, Map<String, dynamic>> _patientStats = {};
  bool _isLoading = true;
  String? _selectedPatientId;

  @override
  void initState() { super.initState(); _loadPatients(); }

  Future<void> _loadPatients() async {
    if (_caregiverId == null) return;
    setState(() => _isLoading = true);
    try {
      // Get assigned patients
      final assignmentsSnap = await _firestore.collection('caregiver_assignments')
          .where('caregiver_id', isEqualTo: _caregiverId)
          .where('is_active', isEqualTo: true).get();

      _patients = [];
      _patientMedications = {};
      _patientStats = {};

      for (final doc in assignmentsSnap.docs) {
        final patientId = doc.data()['patient_id'] as String;
        final patientDoc = await _firestore.collection('users').doc(patientId).get();
        if (patientDoc.exists) {
          _patients.add({...patientDoc.data()!, 'assignment_id': doc.id, 'scope': doc.data()['scope']});

          // Load medications for this patient
          final meds = await _medicationService.getPatientMedications(patientId);
          _patientMedications[patientId] = meds;

          // Load adherence stats
          final medIds = meds.map((m) => m.medId).toList();
          if (medIds.isNotEmpty) {
            final events = await _adherenceService.getAdherenceEvents(
              medicationIds: medIds,
              startDate: DateTime.now().subtract(const Duration(days: 30)),
              endDate: DateTime.now(),
            );
            _patientStats[patientId] = _adherenceService.calculateStats(events);
          }
        }
      }
    } catch (e) { /* ignore */ }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _addPatientByEmail() async {
    final emailController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Patient'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Enter the patient\'s email address to link their account:'),
          const SizedBox(height: 12),
          TextField(controller: emailController,
            decoration: const InputDecoration(labelText: 'Patient Email', prefixIcon: Icon(Icons.email), border: OutlineInputBorder()),
            keyboardType: TextInputType.emailAddress),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, emailController.text.trim()), child: const Text('Add')),
        ],
      ),
    );

    if (result == null || result.isEmpty) return;

    try {
      // Find user by email
      final usersSnap = await _firestore.collection('users').where('email', isEqualTo: result.toLowerCase()).get();
      if (usersSnap.docs.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No user found with that email'), backgroundColor: Colors.red));
        return;
      }
      final patientDoc = usersSnap.docs.first;
      if (patientDoc.data()['role'] != 'PATIENT') {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('That user is not a patient'), backgroundColor: Colors.orange));
        return;
      }

      // Create assignment
      final assignId = '${_caregiverId}_${patientDoc.id}';
      await _firestore.collection('caregiver_assignments').doc(assignId).set({
        'assignment_id': assignId,
        'caregiver_id': _caregiverId,
        'patient_id': patientDoc.id,
        'scope': 'VIEW',
        'is_active': true,
        'created_at': FieldValue.serverTimestamp(),
      });

      await _loadPatients();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Patient ${patientDoc.data()['name']} added!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Patients'),
        actions: [
          IconButton(icon: const Icon(Icons.person_add), onPressed: _addPatientByEmail, tooltip: 'Add Patient'),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadPatients),
        ],
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator())
          : _patients.isEmpty ? _buildEmptyState()
          : RefreshIndicator(
        onRefresh: _loadPatients,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _patients.length,
          itemBuilder: (context, i) => _buildPatientCard(_patients[i]),
        ),
      ),
    );
  }

  Widget _buildPatientCard(Map<String, dynamic> patient) {
    final patientId = patient['user_id'] as String;
    final meds = _patientMedications[patientId] ?? [];
    final stats = _patientStats[patientId] ?? {};
    final double adherence = (stats['percentage'] as num?)?.toDouble() ?? 0.0;
    final Color adherenceColor = adherence >= 70 ? Colors.green : adherence >= 40 ? Colors.orange : Colors.red;
    final bool isExpanded = _selectedPatientId == patientId;

    return Card(
      elevation: 2, margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        ListTile(
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFF2196F3).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.person, color: Color(0xFF2196F3), size: 28),
          ),
          title: Text(patient['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          subtitle: Text(patient['email'] ?? '', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('${adherence.toStringAsFixed(0)}%',
                style: TextStyle(color: adherenceColor, fontWeight: FontWeight.bold, fontSize: 16)),
              Text('adherence', style: TextStyle(color: Colors.grey[500], fontSize: 10)),
            ]),
            const SizedBox(width: 8),
            Icon(isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
          ]),
          onTap: () => setState(() => _selectedPatientId = isExpanded ? null : patientId),
        ),
        if (isExpanded) ...[
          const Divider(height: 1),
          Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              _statChip('${meds.length} Medications', Colors.blue),
              const SizedBox(width: 8),
              _statChip('${stats['taken'] ?? 0} Taken', Colors.green),
              const SizedBox(width: 8),
              _statChip('${stats['missed'] ?? 0} Missed', Colors.red),
            ]),
            const SizedBox(height: 12),
            const Text('Medications:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (meds.isEmpty)
              Text('No medications added', style: TextStyle(color: Colors.grey[600], fontSize: 13))
            else
              ...meds.map((med) => Padding(padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  const Icon(Icons.medication, color: Color(0xFF2196F3), size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text('${med.name} - ${med.dosageAmount}${med.dosageUnit} (${med.frequency})',
                    style: const TextStyle(fontSize: 13))),
                ]))),
          ])),
        ],
      ]),
    );
  }

  Widget _statChip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.3))),
    child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
  );

  Widget _buildEmptyState() => Center(child: Padding(padding: const EdgeInsets.all(32),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.people_outline, size: 80, color: Colors.grey[400]),
      const SizedBox(height: 24),
      Text('No Patients Assigned', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[700])),
      const SizedBox(height: 12),
      Text('Tap the + icon above to add a patient by email', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
    ])));
}
