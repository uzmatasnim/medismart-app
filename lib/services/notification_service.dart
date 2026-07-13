// lib/services/notification_service.dart
// Notification Service - Mobile only (gracefully disabled on web)

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../models/medication_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Initialize - skipped on web
  Future<void> initialize() async {
    if (kIsWeb) return; // Web doesn't support local notifications
    if (_initialized) return;

    tz.initializeTimeZones();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings =
        InitializationSettings(android: androidSettings);

    await _notifications.initialize(initSettings);

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'medication_reminders',
      'Medication Reminders',
      description: 'Daily medication reminder notifications',
      importance: Importance.high,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    _initialized = true;
  }

  /// Schedule daily medication reminder - mobile only
  Future<void> scheduleMedicationReminder(Medication medication) async {
    if (kIsWeb) return; // Not supported on web
    if (medication.reminderTime == null || medication.reminderTime!.isEmpty) return;

    await initialize();

    try {
      List<String> timeParts = medication.reminderTime!.split(':');
      int hour = int.parse(timeParts[0]);
      int minute = int.parse(timeParts[1]);

      int notifId = medication.medId.hashCode.abs() % 2147483647;

      final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
      tz.TZDateTime scheduledDate = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, hour, minute,
      );

      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'medication_reminders',
        'Medication Reminders',
        channelDescription: 'Daily medication reminder notifications',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
      );

      await _notifications.zonedSchedule(
        notifId,
        '💊 Time to take your medication',
        '${medication.name} - ${medication.dosageAmount}${medication.dosageUnit}',
        scheduledDate,
        const NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: medication.medId,
      );
    } catch (e) {
      // Silently handle
    }
  }

  /// Cancel reminder - mobile only
  Future<void> cancelMedicationReminder(String medId) async {
    if (kIsWeb) return;
    int notifId = medId.hashCode.abs() % 2147483647;
    await _notifications.cancel(notifId);
  }

  /// Cancel all - mobile only
  Future<void> cancelAllReminders() async {
    if (kIsWeb) return;
    await _notifications.cancelAll();
  }

  /// Show immediate test notification - mobile only
  Future<void> showTestNotification(String medicationName) async {
    if (kIsWeb) return;
    await initialize();

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'medication_reminders',
      'Medication Reminders',
      importance: Importance.high,
      priority: Priority.high,
    );

    await _notifications.show(
      999,
      '✅ Reminder Set!',
      'You will be reminded to take $medicationName daily',
      const NotificationDetails(android: androidDetails),
    );
  }
}
