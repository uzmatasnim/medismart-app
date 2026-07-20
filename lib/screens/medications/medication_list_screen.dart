// lib/screens/medications/medication_list_screen.dart
// Updated Medication List - Phase 2 adds edit button and reminder display

import 'package:flutter/material.dart';
import 'package:medismart/services/medication_service.dart';
import 'package:medismart/services/notification_service.dart';
import 'package:medismart/models/medication_model.dart';
import 'package:medismart/screens/medications/add_medication_screen.dart';
import 'package:medismart/screens/medications/edit_medication_screen.dart';

class MedicationListScreen extends StatefulWidget {
  const MedicationListScreen({super.key});

  @override
  State<MedicationListScreen> createState() => _MedicationListScreenState();
}

class _MedicationListScreenState extends State<MedicationListScreen> {
  final MedicationService _medicationService = MedicationService();
  final NotificationService _notificationService = NotificationService();
  final TextEditingController _searchController = TextEditingController();

  List<Medication> _allMedications = [];
  List<Medication> _filteredMedications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMedications();
    _searchController.addListener(_filterMedications);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMedications() async {
    setState(() => _isLoading = true);
    try {
      final medications = await _medicationService.getUserMedications();
      if (mounted) {
        setState(() {
          _allMedications = medications;
          _filteredMedications = medications;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _filterMedications() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredMedications = _allMedications
          .where((med) => med.name.toLowerCase().contains(query))
          .toList();
    });
  }

  Future<void> _deleteMedication(Medication medication) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Medication'),
        content: Text(
            'Are you sure you want to delete ${medication.name}?\n\nAny associated reminders will also be cancelled.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success =
          await _medicationService.deleteMedication(medication.medId);

      // Cancel notification
      await _notificationService
          .cancelMedicationReminder(medication.medId);

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Medication deleted'),
            backgroundColor: Colors.green,
          ),
        );
        _loadMedications();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete medication'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Medications'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search medications...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadMedications,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildBody(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const AddMedicationScreen()),
          );
          if (result == true) _loadMedications();
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody() {
    if (_filteredMedications.isEmpty) return _buildEmptyState();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.blue.shade50,
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade700),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _searchController.text.isEmpty
                      ? 'Total: ${_filteredMedications.length} medication(s)'
                      : 'Found: ${_filteredMedications.length} medication(s)',
                  style: TextStyle(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _filteredMedications.length,
            itemBuilder: (context, index) =>
                _buildMedicationCard(_filteredMedications[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    final isSearching = _searchController.text.isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isSearching ? Icons.search_off : Icons.medication_outlined,
                size: 80, color: Colors.grey[400]),
            const SizedBox(height: 24),
            Text(
              isSearching ? 'No medications found' : 'No medications yet',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700]),
            ),
            const SizedBox(height: 12),
            Text(
              isSearching
                  ? 'Try a different search term'
                  : 'Tap the + button to add your first medication',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            if (isSearching) ...[
              const SizedBox(height: 16),
              TextButton(
                  onPressed: () => _searchController.clear(),
                  child: const Text('Clear search')),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMedicationCard(Medication medication) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2196F3).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_getMedicationIcon(medication.form),
                  color: const Color(0xFF2196F3), size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(medication.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 17)),
                  const SizedBox(height: 4),
                  Text('${medication.dosageDisplay} • ${medication.form}',
                      style:
                          TextStyle(color: Colors.grey[700], fontSize: 13)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.schedule,
                          size: 13, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(medication.frequency,
                          style: TextStyle(
                              color: Colors.grey[600], fontSize: 12)),
                    ],
                  ),
                  // Show reminder time if set
                  if (medication.reminderTime != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.alarm,
                            size: 13, color: Colors.blue[400]),
                        const SizedBox(width: 4),
                        Text('Reminder: ${medication.reminderTime}',
                            style: TextStyle(
                                color: Colors.blue[400], fontSize: 12)),
                      ],
                    ),
                  ],
                  if (medication.instructions != null) ...[
                    const SizedBox(height: 4),
                    Text(medication.instructions!,
                        style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                            fontStyle: FontStyle.italic),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
            // Action buttons
            Column(
              children: [
                // Edit button - NEW Phase 2
                IconButton(
                  icon: const Icon(Icons.edit, color: Color(0xFF2196F3)),
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            EditMedicationScreen(medication: medication),
                      ),
                    );
                    if (result == true) _loadMedications();
                  },
                  tooltip: 'Edit',
                ),
                // Delete button
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteMedication(medication),
                  tooltip: 'Delete',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getMedicationIcon(String form) {
    switch (form.toUpperCase()) {
      case 'TABLET':
        return Icons.medication;
      case 'CAPSULE':
        return Icons.medical_services;
      case 'SYRUP':
        return Icons.local_drink;
      case 'INJECTION':
        return Icons.vaccines;
      case 'DROP':
        return Icons.water_drop;
      default:
        return Icons.medication_outlined;
    }
  }
}
