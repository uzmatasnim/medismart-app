// lib/models/adherence_event_model.dart
// AdherenceEvent Model - Represents a medication adherence record

import 'package:cloud_firestore/cloud_firestore.dart';

class AdherenceEvent {
  final String eventId;
  final String medId;
  final String medicationName;
  final DateTime scheduledAt;
  final DateTime? eventTimestamp;
  final String status; // TAKEN, MISSED, SNOOZED
  final String? note;
  final String source; // MANUAL, NOTIF
  final DateTime createdAt;

  AdherenceEvent({
    required this.eventId,
    required this.medId,
    required this.medicationName,
    required this.scheduledAt,
    this.eventTimestamp,
    required this.status,
    this.note,
    this.source = 'MANUAL',
    required this.createdAt,
  });

  factory AdherenceEvent.fromMap(Map<String, dynamic> map) {
    return AdherenceEvent(
      eventId: map['event_id'] ?? '',
      medId: map['med_id'] ?? '',
      medicationName: map['medication_name'] ?? '',
      scheduledAt: map['scheduled_at'] != null
          ? (map['scheduled_at'] as Timestamp).toDate()
          : DateTime.now(),
      eventTimestamp: map['event_timestamp'] != null
          ? (map['event_timestamp'] as Timestamp).toDate()
          : null,
      status: map['status'] ?? 'MISSED',
      note: map['note'],
      source: map['source'] ?? 'MANUAL',
      createdAt: map['created_at'] != null
          ? (map['created_at'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'event_id': eventId,
      'med_id': medId,
      'medication_name': medicationName,
      'scheduled_at': Timestamp.fromDate(scheduledAt),
      'event_timestamp':
          eventTimestamp != null ? Timestamp.fromDate(eventTimestamp!) : null,
      'status': status,
      'note': note,
      'source': source,
      'created_at': Timestamp.fromDate(createdAt),
    };
  }
}
