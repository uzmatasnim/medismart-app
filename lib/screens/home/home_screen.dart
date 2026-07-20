// lib/screens/home/home_screen.dart
// Home Screen - Dashboard with real-time stats

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:medismart/services/medication_service.dart';
import 'package:medismart/services/adherence_service.dart';
import 'package:medismart/models/medication_model.dart';
import 'package:medismart/models/adherence_event_model.dart';
import 'package:medismart/screens/medications/add_medication_screen.dart';
import 'package:medismart/screens/adherence/adherence_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MedicationService _medicationService = MedicationService();
  final AdherenceService _adherenceService = AdherenceService();
  final User? currentUser = FirebaseAuth.instance.currentUser;
  List<Medication> _medications = [];
  Map<String, dynamic> _todayStats = {'taken': 0, 'missed': 0, 'total': 0, 'percentage': 0.0};
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _loadData(); }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _medications = await _medicationService.getTodayMedications();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final events = await _adherenceService.getAllUserAdherenceEvents(startDate: today, endDate: now);
      _todayStats = _adherenceService.calculateStats(events);
    } catch (e) { /* ignore */ }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MediSmart'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _isLoading ? const Center(child: CircularProgressIndicator()) : _buildBody(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const AddMedicationScreen()));
          if (result == true) _loadData();
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody() {
    final hour = DateTime.now().hour;
    String greeting = hour < 12 ? 'Good Morning' : hour < 17 ? 'Good Afternoon' : 'Good Evening';
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Welcome Card
        Card(elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(colors: [Color(0xFF2196F3), Color(0xFF1976D2)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(greeting, style: const TextStyle(fontSize: 16, color: Colors.white70)),
              const SizedBox(height: 4),
              Text(currentUser?.displayName ?? 'User', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 16),
              Row(children: [
                const Icon(Icons.info_outline, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(_medications.isEmpty ? 'No medications scheduled for today' : 'You have ${_medications.length} medication(s) today',
                  style: const TextStyle(fontSize: 14, color: Colors.white))),
              ]),
            ]))),
        const SizedBox(height: 24),
        // Live Stats
        Row(children: [
          Expanded(child: _statCard(Icons.medication, 'Active', '${_medications.length}', Colors.blue)),
          const SizedBox(width: 12),
          Expanded(child: _statCard(Icons.check_circle, 'Taken', '${_todayStats['taken'] ?? 0}', Colors.green)),
          const SizedBox(width: 12),
          Expanded(child: _statCard(Icons.cancel, 'Missed', '${_todayStats['missed'] ?? 0}', Colors.red)),
        ]),
        const SizedBox(height: 24),
        // Today's adherence
        if ((_todayStats['total'] as int?) != null && (_todayStats['total'] as int) > 0) ...[
          const Text("Today's Adherence", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Card(elevation: 1, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('${((_todayStats['percentage'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.blue)),
                Text('${_todayStats['taken']}/${_todayStats['total']} doses taken',
                  style: TextStyle(color: Colors.grey[600])),
              ]),
              const SizedBox(height: 8),
              ClipRRect(borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: ((_todayStats['percentage'] as num?)?.toDouble() ?? 0) / 100,
                  backgroundColor: Colors.grey[200], valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue), minHeight: 10)),
            ]))),
          const SizedBox(height: 24),
        ],
        // Today's schedule
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text("Today's Schedule", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          TextButton(onPressed: () {}, child: const Text('View All')),
        ]),
        const SizedBox(height: 12),
        _medications.isEmpty ? _buildEmptyState()
            : Column(children: _medications.map((med) => _buildMedCard(med)).toList()),
      ]),
    );
  }

  Widget _statCard(IconData icon, String label, String value, Color color) => Card(elevation: 1,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
      Icon(icon, color: color, size: 32), const SizedBox(height: 8),
      Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
    ])));

  Widget _buildEmptyState() => Card(elevation: 1, child: Padding(padding: const EdgeInsets.all(32),
    child: Column(children: [
      Icon(Icons.medication_outlined, size: 64, color: Colors.grey[400]),
      const SizedBox(height: 16),
      Text('No medications yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[700])),
      const SizedBox(height: 8),
      Text('Tap the + button to add your first medication', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
    ])));

  Widget _buildMedCard(Medication med) => Card(elevation: 1, margin: const EdgeInsets.only(bottom: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: ListTile(contentPadding: const EdgeInsets.all(16),
      leading: Container(padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFF2196F3).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: Icon(_medIcon(med.form), color: const Color(0xFF2196F3), size: 28)),
      title: Text(med.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 4),
        Text('${med.dosageDisplay} • ${med.form}', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        const SizedBox(height: 2),
        Text(med.frequency, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        if (med.reminderTime != null) Row(children: [
          Icon(Icons.alarm, size: 12, color: Colors.blue[400]),
          const SizedBox(width: 4),
          Text(med.reminderTime!, style: TextStyle(fontSize: 11, color: Colors.blue[400])),
        ]),
      ]),
      trailing: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdherenceScreen())),
        child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
          child: const Text('Mark', style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)))));

  IconData _medIcon(String form) {
    switch (form.toUpperCase()) {
      case 'TABLET': return Icons.medication;
      case 'CAPSULE': return Icons.medical_services;
      case 'SYRUP': return Icons.local_drink;
      case 'INJECTION': return Icons.vaccines;
      case 'DROP': return Icons.water_drop;
      default: return Icons.medication_outlined;
    }
  }
}
