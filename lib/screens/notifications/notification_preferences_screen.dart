// lib/screens/notifications/notification_preferences_screen.dart
// UC-13: Configure Notification Preferences

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});
  @override
  State<NotificationPreferencesScreen> createState() => _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState extends State<NotificationPreferencesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String? _userId = FirebaseAuth.instance.currentUser?.uid;

  bool _pushEnabled = true;
  bool _dailySummary = false;
  int _snoozeMinutes = 10;
  String _sound = 'default';
  TimeOfDay? _quietStart;
  TimeOfDay? _quietEnd;
  bool _isLoading = true;
  bool _isSaving = false;

  final List<int> _snoozeOptions = [5, 10, 15, 20, 30];
  final List<String> _soundOptions = ['default', 'gentle', 'alarm', 'silent'];

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    if (_userId == null) return;
    setState(() => _isLoading = true);
    try {
      final doc = await _firestore.collection('notification_preferences').doc(_userId).get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _pushEnabled = data['push_enabled'] ?? true;
          _dailySummary = data['daily_summary'] ?? false;
          _snoozeMinutes = data['snooze_minutes'] ?? 10;
          _sound = data['sound'] ?? 'default';
          if (data['quiet_start'] != null) {
            final parts = (data['quiet_start'] as String).split(':');
            _quietStart = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
          }
          if (data['quiet_end'] != null) {
            final parts = (data['quiet_end'] as String).split(':');
            _quietEnd = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
          }
        });
      }
    } catch (e) { /* ignore */ }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _savePreferences() async {
    if (_userId == null) return;
    setState(() => _isSaving = true);
    try {
      await _firestore.collection('notification_preferences').doc(_userId).set({
        'pref_id': _userId,
        'user_id': _userId,
        'push_enabled': _pushEnabled,
        'daily_summary': _dailySummary,
        'snooze_minutes': _snoozeMinutes,
        'sound': _sound,
        'quiet_start': _quietStart != null ? '${_quietStart!.hour.toString().padLeft(2,'0')}:${_quietStart!.minute.toString().padLeft(2,'0')}' : null,
        'quiet_end': _quietEnd != null ? '${_quietEnd!.hour.toString().padLeft(2,'0')}:${_quietEnd!.minute.toString().padLeft(2,'0')}' : null,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Preferences saved!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
    if (mounted) setState(() => _isSaving = false);
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(context: context,
      initialTime: (isStart ? _quietStart : _quietEnd) ?? TimeOfDay.now());
    if (picked != null) setState(() => isStart ? _quietStart = picked : _quietEnd = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notification Preferences'),
        actions: [
          IconButton(icon: _isSaving ? const SizedBox(width:20,height:20,child:CircularProgressIndicator(color:Colors.white,strokeWidth:2)) : const Icon(Icons.save),
            onPressed: _isSaving ? null : _savePreferences),
        ]),
      body: _isLoading ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildSectionHeader('General'),
          Card(elevation: 1, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              SwitchListTile(
                leading: const Icon(Icons.notifications, color: Color(0xFF2196F3)),
                title: const Text('Push Notifications'),
                subtitle: const Text('Receive medication reminder alerts'),
                value: _pushEnabled,
                onChanged: (v) => setState(() => _pushEnabled = v),
              ),
              const Divider(height: 1),
              SwitchListTile(
                leading: const Icon(Icons.summarize, color: Color(0xFF2196F3)),
                title: const Text('Daily Summary'),
                subtitle: const Text('Get a daily adherence summary'),
                value: _dailySummary,
                onChanged: (v) => setState(() => _dailySummary = v),
              ),
            ]),
          ),
          const SizedBox(height: 20),
          _buildSectionHeader('Reminder Settings'),
          Card(elevation: 1, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.snooze, color: Color(0xFF2196F3)),
                title: const Text('Snooze Duration'),
                subtitle: Text('$_snoozeMinutes minutes'),
                trailing: DropdownButton<int>(
                  value: _snoozeMinutes,
                  underline: const SizedBox(),
                  items: _snoozeOptions.map((v) => DropdownMenuItem(value: v, child: Text('$v min'))).toList(),
                  onChanged: (v) => setState(() => _snoozeMinutes = v!),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.volume_up, color: Color(0xFF2196F3)),
                title: const Text('Notification Sound'),
                subtitle: Text(_sound.toUpperCase()),
                trailing: DropdownButton<String>(
                  value: _sound,
                  underline: const SizedBox(),
                  items: _soundOptions.map((v) => DropdownMenuItem(value: v, child: Text(v.toUpperCase()))).toList(),
                  onChanged: (v) => setState(() => _sound = v!),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 20),
          _buildSectionHeader('Quiet Hours'),
          Card(elevation: 1, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.bedtime, color: Color(0xFF2196F3)),
                title: const Text('Quiet Start'),
                subtitle: Text(_quietStart != null ? _quietStart!.format(context) : 'Not set'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  TextButton(onPressed: () => _pickTime(true), child: const Text('Set')),
                  if (_quietStart != null) IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => setState(() => _quietStart = null)),
                ]),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.wb_sunny, color: Color(0xFF2196F3)),
                title: const Text('Quiet End'),
                subtitle: Text(_quietEnd != null ? _quietEnd!.format(context) : 'Not set'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  TextButton(onPressed: () => _pickTime(false), child: const Text('Set')),
                  if (_quietEnd != null) IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => setState(() => _quietEnd = null)),
                ]),
              ),
              if (_quietStart != null && _quietEnd != null)
                Padding(padding: const EdgeInsets.all(12),
                  child: Container(padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text('No reminders between ${_quietStart!.format(context)} - ${_quietEnd!.format(context)}',
                        style: TextStyle(fontSize: 12, color: Colors.blue.shade700))),
                    ]),
                  )),
            ]),
          ),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _savePreferences,
              icon: const Icon(Icons.save),
              label: Text(_isSaving ? 'Saving...' : 'Save Preferences'),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            )),
        ]),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)));
  }
}
