// lib/screens/medications/add_medication_screen.dart
// FIXED: Proper error handling - shows real error message from Firestore

import 'package:flutter/material.dart';
import 'package:medismart/services/medication_service.dart';
import 'package:medismart/services/notification_service.dart';
import 'package:medismart/models/medication_model.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddMedicationScreen extends StatefulWidget {
  const AddMedicationScreen({super.key});
  @override
  State<AddMedicationScreen> createState() => _AddMedicationScreenState();
}

class _AddMedicationScreenState extends State<AddMedicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _medicationService = MedicationService();
  final _notificationService = NotificationService();

  final _nameController = TextEditingController();
  final _dosageAmountController = TextEditingController();
  final _frequencyController = TextEditingController();
  final _instructionsController = TextEditingController();

  String _selectedForm = 'TABLET';
  String _selectedUnit = 'mg';
  TimeOfDay? _reminderTime;
  bool _isLoading = false;

  final List<String> _medicationForms = [
    'TABLET', 'CAPSULE', 'SYRUP', 'INJECTION', 'DROP', 'OTHER',
  ];
  final List<String> _dosageUnits = ['mg', 'ml', 'g', 'mcg', 'units'];

  @override
  void dispose() {
    _nameController.dispose();
    _dosageAmountController.dispose();
    _frequencyController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  Future<void> _selectReminderTime() async {
    TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => _reminderTime = picked);
  }

  Future<void> _saveMedication() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('Not logged in. Please log out and log in again.');
      }

      String? reminderTimeStr;
      if (_reminderTime != null) {
        reminderTimeStr =
            '${_reminderTime!.hour.toString().padLeft(2, '0')}:${_reminderTime!.minute.toString().padLeft(2, '0')}';
      }

      final medication = Medication(
        medId: '',
        patientId: currentUser.uid,
        name: _nameController.text.trim(),
        form: _selectedForm,
        dosageAmount: double.parse(_dosageAmountController.text),
        dosageUnit: _selectedUnit,
        frequency: _frequencyController.text.trim(),
        reminderTime: reminderTimeStr,
        instructions: _instructionsController.text.trim().isEmpty
            ? null
            : _instructionsController.text.trim(),
        // FIX: Don't pass startDate — let the service handle timestamps
        isActive: true,
      );

      // FIX: addMedication now throws on error instead of returning null
      final medId = await _medicationService.addMedication(medication);

      if (!mounted) return;

      // Schedule notification
      if (reminderTimeStr != null && medId != null) {
        try {
          final medWithId = medication.copyWith(medId: medId);
          await _notificationService.scheduleMedicationReminder(medWithId);
          await _notificationService.showTestNotification(medication.name);
        } catch (notifError) {
          // Notification error is non-critical — medication was still saved
          debugPrint('Notification error (non-critical): $notifError');
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(reminderTimeStr != null
              ? '✅ Medication added! Daily reminder set for $reminderTimeStr'
              : '✅ Medication added successfully!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        // FIX: Show the actual error so you know what went wrong
        String errorMsg = e.toString();
        // Clean up the error message for display
        if (errorMsg.contains('PERMISSION_DENIED')) {
          errorMsg = 'Permission denied. Check Firestore security rules.';
        } else if (errorMsg.contains('FAILED_PRECONDITION')) {
          errorMsg = 'Database index needed. Check Firebase Console.';
        } else if (errorMsg.contains('network')) {
          errorMsg = 'No internet connection. Please check your network.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Medication'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _isLoading ? null : () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Medication Name *',
                hintText: 'e.g., Paracetamol',
                prefixIcon: Icon(Icons.medication),
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Please enter medication name';
                if (v.trim().length < 2) return 'Name must be at least 2 characters';
                return null;
              },
              enabled: !_isLoading,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: _selectedForm,
              decoration: const InputDecoration(
                labelText: 'Medication Form *',
                prefixIcon: Icon(Icons.category),
                border: OutlineInputBorder(),
              ),
              items: _medicationForms
                  .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                  .toList(),
              onChanged: _isLoading ? null : (v) => setState(() => _selectedForm = v!),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _dosageAmountController,
                    decoration: const InputDecoration(
                      labelText: 'Dosage Amount *',
                      hintText: '500',
                      prefixIcon: Icon(Icons.science),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (double.tryParse(v) == null) return 'Enter a number';
                      if (double.parse(v) <= 0) return 'Must be > 0';
                      return null;
                    },
                    enabled: !_isLoading,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedUnit,
                    decoration: const InputDecoration(
                      labelText: 'Unit *',
                      border: OutlineInputBorder(),
                    ),
                    items: _dosageUnits
                        .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                        .toList(),
                    onChanged: _isLoading ? null : (v) => setState(() => _selectedUnit = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _frequencyController,
              decoration: const InputDecoration(
                labelText: 'Frequency *',
                hintText: 'e.g., 2 times/day',
                prefixIcon: Icon(Icons.schedule),
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Please enter frequency' : null,
              enabled: !_isLoading,
            ),
            const SizedBox(height: 16),

            InkWell(
              onTap: _isLoading ? null : _selectReminderTime,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Reminder Time (Optional)',
                  prefixIcon: Icon(Icons.alarm),
                  border: OutlineInputBorder(),
                  helperText: 'Set a daily reminder to take this medication',
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _reminderTime != null
                          ? _reminderTime!.format(context)
                          : 'Tap to set reminder time',
                      style: TextStyle(
                        color: _reminderTime != null ? Colors.black87 : Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                    if (_reminderTime != null)
                      GestureDetector(
                        onTap: () => setState(() => _reminderTime = null),
                        child: const Icon(Icons.clear, size: 20, color: Colors.grey),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _instructionsController,
              decoration: const InputDecoration(
                labelText: 'Instructions (Optional)',
                hintText: 'e.g., Take after meals',
                prefixIcon: Icon(Icons.notes),
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              enabled: !_isLoading,
            ),
            const SizedBox(height: 24),

            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Fields marked with * are required. Set a reminder time to receive daily notifications.',
                        style: TextStyle(color: Colors.blue.shade700, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _isLoading ? null : _saveMedication,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Save Medication', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
