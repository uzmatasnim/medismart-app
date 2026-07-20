// lib/screens/medications/edit_medication_screen.dart
// Edit Medication Screen - Update existing medication details

import 'package:flutter/material.dart';
import 'package:medismart/models/medication_model.dart';
import 'package:medismart/services/medication_service.dart';
import 'package:medismart/services/notification_service.dart';

class EditMedicationScreen extends StatefulWidget {
  final Medication medication;
  const EditMedicationScreen({super.key, required this.medication});

  @override
  State<EditMedicationScreen> createState() => _EditMedicationScreenState();
}

class _EditMedicationScreenState extends State<EditMedicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _medicationService = MedicationService();
  final _notificationService = NotificationService();

  late TextEditingController _nameController;
  late TextEditingController _dosageAmountController;
  late TextEditingController _frequencyController;
  late TextEditingController _instructionsController;

  late String _selectedForm;
  late String _selectedUnit;
  TimeOfDay? _reminderTime;
  bool _isLoading = false;

  final List<String> _medicationForms = [
    'TABLET', 'CAPSULE', 'SYRUP', 'INJECTION', 'DROP', 'OTHER',
  ];
  final List<String> _dosageUnits = ['mg', 'ml', 'g', 'mcg', 'units'];

  @override
  void initState() {
    super.initState();
    // Pre-fill with existing medication data
    _nameController = TextEditingController(text: widget.medication.name);
    _dosageAmountController = TextEditingController(
        text: widget.medication.dosageAmount.toString());
    _frequencyController =
        TextEditingController(text: widget.medication.frequency);
    _instructionsController =
        TextEditingController(text: widget.medication.instructions ?? '');
    _selectedForm = widget.medication.form;
    _selectedUnit = widget.medication.dosageUnit;

    // Set existing reminder time if present
    if (widget.medication.reminderTime != null &&
        widget.medication.reminderTime!.isNotEmpty) {
      List<String> parts = widget.medication.reminderTime!.split(':');
      if (parts.length == 2) {
        _reminderTime = TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }
    }
  }

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
    if (picked != null) {
      setState(() => _reminderTime = picked);
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      String? reminderTimeStr;
      if (_reminderTime != null) {
        reminderTimeStr =
            '${_reminderTime!.hour.toString().padLeft(2, '0')}:${_reminderTime!.minute.toString().padLeft(2, '0')}';
      }

      Map<String, dynamic> updates = {
        'name': _nameController.text.trim(),
        'form': _selectedForm,
        'dosage_amount': double.parse(_dosageAmountController.text),
        'dosage_unit': _selectedUnit,
        'frequency': _frequencyController.text.trim(),
        'reminder_time': reminderTimeStr,
        'instructions': _instructionsController.text.trim().isEmpty
            ? null
            : _instructionsController.text.trim(),
      };

      bool success = await _medicationService.updateMedication(
          widget.medication.medId, updates);

      if (!mounted) return;

      if (success) {
        // Update notification
        Medication updatedMed = widget.medication.copyWith(
          name: _nameController.text.trim(),
          reminderTime: reminderTimeStr,
        );

        if (reminderTimeStr != null) {
          await _notificationService.scheduleMedicationReminder(updatedMed);
        } else {
          await _notificationService
              .cancelMedicationReminder(widget.medication.medId);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Medication updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        throw Exception('Update failed');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to update: $e'),
            backgroundColor: Colors.red,
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
        title: const Text('Edit Medication'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Medication Name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Medication Name *',
                prefixIcon: Icon(Icons.medication),
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Name is required' : null,
              enabled: !_isLoading,
            ),
            const SizedBox(height: 16),

            // Form Dropdown
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
              onChanged:
                  _isLoading ? null : (v) => setState(() => _selectedForm = v!),
            ),
            const SizedBox(height: 16),

            // Dosage Row
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _dosageAmountController,
                    decoration: const InputDecoration(
                      labelText: 'Dosage Amount *',
                      prefixIcon: Icon(Icons.science),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (double.tryParse(v) == null) return 'Invalid number';
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
                    onChanged: _isLoading
                        ? null
                        : (v) => setState(() => _selectedUnit = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Frequency
            TextFormField(
              controller: _frequencyController,
              decoration: const InputDecoration(
                labelText: 'Frequency *',
                prefixIcon: Icon(Icons.schedule),
                border: OutlineInputBorder(),
                hintText: 'e.g., 2 times/day',
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Frequency required' : null,
              enabled: !_isLoading,
            ),
            const SizedBox(height: 16),

            // Reminder Time Picker
            InkWell(
              onTap: _isLoading ? null : _selectReminderTime,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Reminder Time (Optional)',
                  prefixIcon: Icon(Icons.alarm),
                  border: OutlineInputBorder(),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _reminderTime != null
                          ? _reminderTime!.format(context)
                          : 'Tap to set reminder time',
                      style: TextStyle(
                        color: _reminderTime != null
                            ? Colors.black87
                            : Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                    if (_reminderTime != null)
                      GestureDetector(
                        onTap: () => setState(() => _reminderTime = null),
                        child: const Icon(Icons.clear,
                            size: 20, color: Colors.grey),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Instructions
            TextFormField(
              controller: _instructionsController,
              decoration: const InputDecoration(
                labelText: 'Instructions (Optional)',
                prefixIcon: Icon(Icons.notes),
                border: OutlineInputBorder(),
                hintText: 'e.g., Take after meals',
              ),
              maxLines: 3,
              enabled: !_isLoading,
            ),
            const SizedBox(height: 24),

            // Save Button
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _saveChanges,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save),
              label: Text(_isLoading ? 'Saving...' : 'Save Changes',
                  style: const TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
