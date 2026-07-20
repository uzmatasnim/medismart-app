// lib/models/medication_model.dart
// Medication Model - Updated for Phase 2 with reminderTime field

import 'package:cloud_firestore/cloud_firestore.dart';

class Medication {
  final String medId;
  final String patientId;
  final String name;
  final String form;
  final double dosageAmount;
  final String dosageUnit;
  final String frequency;
  final String? reminderTime; // Phase 2: HH:MM format
  final DateTime? startDate;
  final DateTime? endDate;
  final String? instructions;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Medication({
    required this.medId,
    required this.patientId,
    required this.name,
    required this.form,
    required this.dosageAmount,
    required this.dosageUnit,
    required this.frequency,
    this.reminderTime,
    this.startDate,
    this.endDate,
    this.instructions,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  factory Medication.fromMap(Map<String, dynamic> map) {
    return Medication(
      medId: map['med_id'] ?? '',
      patientId: map['patient_id'] ?? '',
      name: map['name'] ?? '',
      form: map['form'] ?? 'TABLET',
      dosageAmount: (map['dosage_amount'] ?? 0).toDouble(),
      dosageUnit: map['dosage_unit'] ?? 'mg',
      frequency: map['frequency'] ?? '',
      reminderTime: map['reminder_time'],
      startDate: map['start_date'] != null ? (map['start_date'] as Timestamp).toDate() : null,
      endDate: map['end_date'] != null ? (map['end_date'] as Timestamp).toDate() : null,
      instructions: map['instructions'],
      isActive: map['is_active'] ?? true,
      createdAt: map['created_at'] != null ? (map['created_at'] as Timestamp).toDate() : null,
      updatedAt: map['updated_at'] != null ? (map['updated_at'] as Timestamp).toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'med_id': medId,
      'patient_id': patientId,
      'name': name,
      'form': form,
      'dosage_amount': dosageAmount,
      'dosage_unit': dosageUnit,
      'frequency': frequency,
      'reminder_time': reminderTime,
      'start_date': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'end_date': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'instructions': instructions,
      'is_active': isActive,
    };
  }

  String get dosageDisplay => '$dosageAmount$dosageUnit';

  Medication copyWith({
    String? medId,
    String? patientId,
    String? name,
    String? form,
    double? dosageAmount,
    String? dosageUnit,
    String? frequency,
    String? reminderTime,
    DateTime? startDate,
    DateTime? endDate,
    String? instructions,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Medication(
      medId: medId ?? this.medId,
      patientId: patientId ?? this.patientId,
      name: name ?? this.name,
      form: form ?? this.form,
      dosageAmount: dosageAmount ?? this.dosageAmount,
      dosageUnit: dosageUnit ?? this.dosageUnit,
      frequency: frequency ?? this.frequency,
      reminderTime: reminderTime ?? this.reminderTime,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      instructions: instructions ?? this.instructions,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
