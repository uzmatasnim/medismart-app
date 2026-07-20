// lib/screens/admin/admin_screen.dart
// WF-01/UC-14/UC-15/UC-16: Admin Web Portal - User Management, Logs, Settings

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() { _tabController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Portal'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.people), text: 'Users'),
            Tab(icon: Icon(Icons.medication), text: 'Medications'),
            Tab(icon: Icon(Icons.history), text: 'Audit Logs'),
            Tab(icon: Icon(Icons.settings), text: 'Settings'),
          ],
        ),
      ),
      body: TabBarView(controller: _tabController, children: [
        _UserManagementTab(firestore: _firestore),
        _MedicationOversightTab(firestore: _firestore),
        _AuditLogsTab(firestore: _firestore),
        _SystemSettingsTab(firestore: _firestore),
      ]),
    );
  }
}

// WF-01/UC-14: User Management
class _UserManagementTab extends StatelessWidget {
  final FirebaseFirestore firestore;
  const _UserManagementTab({required this.firestore});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(padding: const EdgeInsets.all(16), color: Colors.blue.shade50,
        child: Row(children: [
          Icon(Icons.info_outline, color: Colors.blue.shade700),
          const SizedBox(width: 8),
          Text('Manage all users in the system', style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold)),
        ])),
      Expanded(child: StreamBuilder<QuerySnapshot>(
        stream: firestore.collection('users').orderBy('created_at', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
            return const Center(child: Text('No users found'));
          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, i) {
              final user = snapshot.data!.docs[i].data() as Map<String, dynamic>;
              final bool isActive = user['is_active'] ?? true;
              final String role = user['role'] ?? 'PATIENT';
              return Card(margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _roleColor(role).withOpacity(0.2),
                    child: Icon(_roleIcon(role), color: _roleColor(role)),
                  ),
                  title: Text(user['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(user['email'] ?? '', style: const TextStyle(fontSize: 12)),
                    Row(children: [
                      _roleBadge(role),
                      const SizedBox(width: 6),
                      _statusBadge(isActive),
                    ]),
                  ]),
                  trailing: PopupMenuButton<String>(
                    onSelected: (action) => _handleUserAction(context, action, snapshot.data!.docs[i].id, user),
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'view', child: Row(children: [Icon(Icons.visibility, size: 18), SizedBox(width: 8), Text('View Details')])),
                      PopupMenuItem(value: 'toggle', child: Row(children: [Icon(isActive ? Icons.block : Icons.check_circle, size: 18), const SizedBox(width: 8), Text(isActive ? 'Deactivate' : 'Activate')])),
                      const PopupMenuItem(value: 'role', child: Row(children: [Icon(Icons.manage_accounts, size: 18), SizedBox(width: 8), Text('Change Role')])),
                    ],
                  ),
                ),
              );
            },
          );
        },
      )),
    ]);
  }

  void _handleUserAction(BuildContext context, String action, String userId, Map<String, dynamic> user) async {
    if (action == 'toggle') {
      await firestore.collection('users').doc(userId).update({'is_active': !(user['is_active'] ?? true), 'updated_at': FieldValue.serverTimestamp()});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User status updated'), backgroundColor: Colors.green));
    } else if (action == 'role') {
      final roles = ['PATIENT', 'CAREGIVER', 'ADMIN'];
      final newRole = await showDialog<String>(context: context,
        builder: (ctx) => SimpleDialog(title: const Text('Change Role'),
          children: roles.map((r) => SimpleDialogOption(child: Text(r), onPressed: () => Navigator.pop(ctx, r))).toList()));
      if (newRole != null) {
        await firestore.collection('users').doc(userId).update({'role': newRole, 'updated_at': FieldValue.serverTimestamp()});
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Role changed to $newRole'), backgroundColor: Colors.green));
      }
    } else if (action == 'view') {
      showDialog(context: context, builder: (ctx) => AlertDialog(
        title: Text(user['name'] ?? 'User'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          _detailRow('Email', user['email'] ?? '-'),
          _detailRow('Role', user['role'] ?? '-'),
          _detailRow('Status', (user['is_active'] ?? true) ? 'Active' : 'Inactive'),
          _detailRow('Timezone', user['timezone'] ?? '-'),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ));
    }
  }

  Widget _detailRow(String label, String value) => Padding(padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      Text(value, style: const TextStyle(fontSize: 13)),
    ]));

  Color _roleColor(String role) => role == 'ADMIN' ? Colors.red : role == 'CAREGIVER' ? Colors.purple : Colors.blue;
  IconData _roleIcon(String role) => role == 'ADMIN' ? Icons.admin_panel_settings : role == 'CAREGIVER' ? Icons.supervisor_account : Icons.person;

  Widget _roleBadge(String role) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: _roleColor(role).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
    child: Text(role, style: TextStyle(color: _roleColor(role), fontSize: 10, fontWeight: FontWeight.bold)));

  Widget _statusBadge(bool isActive) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: (isActive ? Colors.green : Colors.red).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
    child: Text(isActive ? 'Active' : 'Inactive', style: TextStyle(color: isActive ? Colors.green : Colors.red, fontSize: 10, fontWeight: FontWeight.bold)));
}

// WF-02: Medication Oversight
class _MedicationOversightTab extends StatelessWidget {
  final FirebaseFirestore firestore;
  const _MedicationOversightTab({required this.firestore});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: firestore.collection('medications').where('is_active', isEqualTo: true).orderBy('created_at', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('No medications found'));
        final meds = snapshot.data!.docs;
        return Column(children: [
          Container(padding: const EdgeInsets.all(12), color: Colors.blue.shade50,
            child: Row(children: [
              Icon(Icons.medication, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Text('${meds.length} active medications across all patients', style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold)),
            ])),
          Expanded(child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: meds.length,
            itemBuilder: (ctx, i) {
              final med = meds[i].data() as Map<String, dynamic>;
              return Card(margin: const EdgeInsets.only(bottom: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.medication, color: Colors.blue, size: 24)),
                  title: Text(med['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${med['dosage_amount']}${med['dosage_unit']} • ${med['form']} • ${med['frequency']}', style: const TextStyle(fontSize: 12)),
                  trailing: med['reminder_time'] != null ? Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.alarm, size: 14, color: Colors.blue),
                    const SizedBox(width: 4),
                    Text(med['reminder_time'], style: const TextStyle(fontSize: 12, color: Colors.blue)),
                  ]) : null,
                ));
            },
          )),
        ]);
      },
    );
  }
}

// WF-05/UC-15: Audit Logs
class _AuditLogsTab extends StatelessWidget {
  final FirebaseFirestore firestore;
  const _AuditLogsTab({required this.firestore});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: firestore.collection('adherence_events').orderBy('created_at', descending: true).limit(100).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('No activity logs yet'));
        return Column(children: [
          Container(padding: const EdgeInsets.all(12), color: Colors.blue.shade50,
            child: Row(children: [
              Icon(Icons.history, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Text('Last 100 adherence events', style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold)),
            ])),
          Expanded(child: ListView.builder(
            itemCount: snapshot.data!.docs.length,
            padding: const EdgeInsets.all(8),
            itemBuilder: (ctx, i) {
              final event = snapshot.data!.docs[i].data() as Map<String, dynamic>;
              final status = event['status'] ?? '';
              final Color statusColor = status == 'TAKEN' ? Colors.green : status == 'MISSED' ? Colors.red : Colors.orange;
              DateTime? date;
              if (event['created_at'] is Timestamp) date = (event['created_at'] as Timestamp).toDate();
              return ListTile(
                leading: CircleAvatar(backgroundColor: statusColor.withOpacity(0.15),
                  child: Icon(status == 'TAKEN' ? Icons.check_circle : status == 'MISSED' ? Icons.cancel : Icons.snooze, color: statusColor, size: 20)),
                title: Text(event['medication_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text(date != null ? DateFormat('dd/MM/yyyy HH:mm').format(date) : '', style: const TextStyle(fontSize: 11)),
                trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Text(status, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold))),
              );
            },
          )),
        ]);
      },
    );
  }
}

// WF-04/UC-16: System Settings
class _SystemSettingsTab extends StatefulWidget {
  final FirebaseFirestore firestore;
  const _SystemSettingsTab({required this.firestore});
  @override
  State<_SystemSettingsTab> createState() => _SystemSettingsTabState();
}

class _SystemSettingsTabState extends State<_SystemSettingsTab> {
  int _defaultSnooze = 10;
  String _defaultQuietStart = '22:00';
  String _defaultQuietEnd = '07:00';
  bool _maintenanceMode = false;
  bool _isSaving = false;

  @override
  void initState() { super.initState(); _loadSettings(); }

  Future<void> _loadSettings() async {
    try {
      final doc = await widget.firestore.collection('system_settings').doc('global').get();
      if (doc.exists) {
        final d = doc.data()!;
        setState(() {
          _defaultSnooze = d['default_snooze_minutes'] ?? 10;
          _defaultQuietStart = d['default_quiet_start'] ?? '22:00';
          _defaultQuietEnd = d['default_quiet_end'] ?? '07:00';
          _maintenanceMode = d['maintenance_mode'] ?? false;
        });
      }
    } catch (e) { /* ignore */ }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    try {
      await widget.firestore.collection('system_settings').doc('global').set({
        'default_snooze_minutes': _defaultSnooze,
        'default_quiet_start': _defaultQuietStart,
        'default_quiet_end': _defaultQuietEnd,
        'maintenance_mode': _maintenanceMode,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Settings saved!'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
      Card(elevation: 1, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: Column(children: [
        ListTile(leading: const Icon(Icons.snooze, color: Color(0xFF2196F3)),
          title: const Text('Default Snooze Duration'),
          subtitle: Text('$_defaultSnooze minutes'),
          trailing: DropdownButton<int>(value: _defaultSnooze, underline: const SizedBox(),
            items: [5,10,15,20,30].map((v) => DropdownMenuItem(value: v, child: Text('$v min'))).toList(),
            onChanged: (v) => setState(() => _defaultSnooze = v!))),
        const Divider(height: 1),
        ListTile(leading: const Icon(Icons.bedtime, color: Color(0xFF2196F3)),
          title: const Text('Default Quiet Hours'),
          subtitle: Text('$_defaultQuietStart – $_defaultQuietEnd')),
        const Divider(height: 1),
        SwitchListTile(secondary: const Icon(Icons.build, color: Colors.orange),
          title: const Text('Maintenance Mode'),
          subtitle: const Text('Disable app for users during maintenance'),
          value: _maintenanceMode,
          onChanged: (v) => setState(() => _maintenanceMode = v)),
      ])),
      const SizedBox(height: 20),
      Card(elevation: 1, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: Column(children: [
        const Padding(padding: EdgeInsets.all(16), child: Text('System Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        const Divider(height: 1),
        _infoTile('App Version', '2.0.0'),
        _infoTile('Platform', 'Flutter + Firebase'),
        _infoTile('Database', 'Cloud Firestore'),
        _infoTile('Auth', 'Firebase Authentication'),
        _infoTile('Notifications', 'FCM + Local Notifications'),
      ])),
      const SizedBox(height: 20),
      SizedBox(width: double.infinity, child: ElevatedButton.icon(
        onPressed: _isSaving ? null : _saveSettings,
        icon: _isSaving ? const SizedBox(width:18,height:18,child:CircularProgressIndicator(color:Colors.white,strokeWidth:2)) : const Icon(Icons.save),
        label: Text(_isSaving ? 'Saving...' : 'Save Settings'),
        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
      )),
    ]));
  }

  Widget _infoTile(String label, String value) => ListTile(
    title: Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
    trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)));
}
