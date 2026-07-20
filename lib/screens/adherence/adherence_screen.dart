// lib/screens/adherence/adherence_screen.dart
// FIXED: Stats update immediately after marking Taken/Missed

import 'package:flutter/material.dart';
import 'package:medismart/models/medication_model.dart';
import 'package:medismart/models/adherence_event_model.dart';
import 'package:medismart/services/medication_service.dart';
import 'package:medismart/services/adherence_service.dart';

class AdherenceScreen extends StatefulWidget {
  const AdherenceScreen({super.key});
  @override
  State<AdherenceScreen> createState() => _AdherenceScreenState();
}

class _AdherenceScreenState extends State<AdherenceScreen> {
  final MedicationService   _medicationService  = MedicationService();
  final AdherenceService    _adherenceService   = AdherenceService();

  List<Medication>          _medications  = [];
  List<AdherenceEvent>      _events       = [];
  Map<String, dynamic>      _stats        = {};
  bool                      _isLoading    = true;
  // FIX 4: Track which medication card is currently saving
  // so we can show a loading indicator on just that button
  String?                   _markingMedId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      _medications = await _medicationService.getUserMedications();

      final now           = DateTime.now();
      // FIX 5: Use start of day (not start of month) so today's
      // events are always included
      final startOfDay    = DateTime(now.year, now.month, now.day);

      _events = await _adherenceService.getAllUserAdherenceEvents(
        startDate: startOfDay,
        endDate: now,
      );

      _stats = _adherenceService.calculateStats(_events);
    } catch (e) {
      print('loadData error: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _markAdherence(Medication med, String status) async {
    // FIX 6: Set _markingMedId so button shows loading while saving
    if (mounted) setState(() => _markingMedId = med.medId);

    try {
      final result = await _adherenceService.recordAdherence(
        medId:            med.medId,
        medicationName:   med.name,
        status:           status,
      );

      if (!mounted) return;

      if (result != null) {
        // FIX 7: Reload data BEFORE clearing _markingMedId
        // so the UI shows fresh stats as soon as save completes
        await _loadData();

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(status == 'TAKEN'
              ? '✅ ${med.name} marked as taken'
              : '❌ ${med.name} marked as missed'),
          backgroundColor: status == 'TAKEN' ? Colors.green : Colors.red,
          duration: const Duration(seconds: 2),
        ));
      } else {
        // recordAdherence returned null — write failed silently
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to save. Check your internet connection.'),
          backgroundColor: Colors.red,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _markingMedId = null);
    }
  }

  Color     _statusColor(String s) =>
      s == 'TAKEN' ? Colors.green : s == 'MISSED' ? Colors.red : Colors.orange;
  IconData  _statusIcon(String s)  =>
      s == 'TAKEN' ? Icons.check_circle : s == 'MISSED' ? Icons.cancel : Icons.snooze;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Adherence Tracking'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatsRow(),
                    const SizedBox(height: 24),
                    const Text("Mark Today's Medications",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Tap Taken or Missed for each medication',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                    const SizedBox(height: 12),
                    _medications.isEmpty
                        ? _buildEmpty(Icons.medication_outlined,
                            'No medications added yet',
                            'Go to Medications tab to add your medications')
                        : Column(children: _medications.map(_buildMedCard).toList()),
                    const SizedBox(height: 24),
                    const Text('Recent History',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _events.isEmpty
                        ? _buildEmpty(Icons.history, 'No records yet',
                            'Start marking your medications above')
                        : Column(children: _events.take(15).map(_buildEventTile).toList()),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatsRow() {
    final pct    = (_stats['percentage'] as num?)?.toDouble() ?? 0.0;
    final taken  = (_stats['taken']  as int?) ?? 0;
    final missed = (_stats['missed'] as int?) ?? 0;
    final total  = (_stats['total']  as int?) ?? 0;
    return Row(children: [
      Expanded(child: _statCard('Adherence', '${pct.toStringAsFixed(0)}%', Colors.blue,    Icons.pie_chart)),
      const SizedBox(width: 8),
      Expanded(child: _statCard('Taken',     '$taken',                     Colors.green,   Icons.check_circle)),
      const SizedBox(width: 8),
      Expanded(child: _statCard('Missed',    '$missed',                    Colors.red,     Icons.cancel)),
      const SizedBox(width: 8),
      Expanded(child: _statCard('Total',     '$total',                     Colors.orange,  Icons.list)),
    ]);
  }

  Widget _statCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
      ]),
    );
  }

  Widget _buildMedCard(Medication med) {
    final adherence = _adherenceService.getMedicationAdherencePercentage(_events, med.medId);
    final isMarking = _markingMedId == med.medId;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF2196F3).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.medication, color: Color(0xFF2196F3), size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(med.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text('${med.dosageAmount}${med.dosageUnit} • ${med.frequency}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600])),
              if (med.reminderTime != null)
                Row(children: [
                  Icon(Icons.alarm, size: 12, color: Colors.blue[400]),
                  const SizedBox(width: 4),
                  Text(med.reminderTime!,
                      style: TextStyle(fontSize: 12, color: Colors.blue[400])),
                ]),
            ])),
            Column(children: [
              Text('${adherence.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold,
                    color: adherence >= 70 ? Colors.green
                         : adherence >= 40 ? Colors.orange
                         : Colors.red,
                  )),
              Text('adherence', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
            ]),
          ]),
          const SizedBox(height: 12),
          // FIX 8: Show loading spinner on buttons while saving
          isMarking
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 12),
                      Text('Saving...', style: TextStyle(color: Colors.grey)),
                    ]),
                  ),
                )
              : Row(children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _markAdherence(med, 'TAKEN'),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Taken'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _markAdherence(med, 'MISSED'),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Missed'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ]),
        ]),
      ),
    );
  }

  Widget _buildEventTile(AdherenceEvent event) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _statusColor(event.status).withOpacity(0.15),
          child: Icon(_statusIcon(event.status),
              color: _statusColor(event.status), size: 20),
        ),
        title: Text(event.medicationName,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${event.scheduledAt.day}/${event.scheduledAt.month}/${event.scheduledAt.year}  '
          '${event.scheduledAt.hour.toString().padLeft(2, '0')}:'
          '${event.scheduledAt.minute.toString().padLeft(2, '0')}',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _statusColor(event.status).withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _statusColor(event.status).withOpacity(0.3)),
          ),
          child: Text(event.status,
              style: TextStyle(
                  color: _statusColor(event.status),
                  fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildEmpty(IconData icon, String title, String subtitle) {
    return Card(elevation: 1,
      child: Padding(padding: const EdgeInsets.all(24),
        child: Column(children: [
          Icon(icon, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(title, style: TextStyle(fontSize: 16, color: Colors.grey[600])),
          const SizedBox(height: 4),
          Text(subtitle,
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              textAlign: TextAlign.center),
        ])));
  }
}
