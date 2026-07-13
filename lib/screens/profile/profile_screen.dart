// lib/screens/profile/profile_screen.dart
import 'package:medismart/screens/notifications/notification_preferences_screen.dart';
// UC-04: Manage Profile - View AND Edit profile

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:medismart/services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    if (currentUser == null) return;
    setState(() => _isLoading = true);
    final authService = Provider.of<AuthService>(context, listen: false);
    final profile = await authService.getUserProfile(currentUser!.uid);
    if (mounted) setState(() { _userProfile = profile; _isLoading = false; });
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [IconButton(icon: const Icon(Icons.notifications_active_outlined), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationPreferencesScreen())), tooltip: 'Notification Preferences'),
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Logout')),
        ],
      ),
    );
    if (confirmed == true) {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.logoutUser();
    }
  }

  void _showEditProfileDialog() {
    final nameController = TextEditingController(text: _userProfile?['name'] ?? '');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person), border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [IconButton(icon: const Icon(Icons.notifications_active_outlined), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationPreferencesScreen())), tooltip: 'Notification Preferences'),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              final authService = Provider.of<AuthService>(context, listen: false);
              await authService.updateUserProfile(currentUser!.uid, {'name': nameController.text.trim()});
              await currentUser!.updateDisplayName(nameController.text.trim());
              Navigator.pop(context);
              await _loadUserProfile();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ Profile updated!'), backgroundColor: Colors.green));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [IconButton(icon: const Icon(Icons.notifications_active_outlined), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationPreferencesScreen())), tooltip: 'Notification Preferences'),
          IconButton(icon: const Icon(Icons.edit), onPressed: _showEditProfileDialog, tooltip: 'Edit Profile'),
        ],
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : _buildBody(),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildProfileHeader(),
          const SizedBox(height: 24),
          _buildSection(title: 'Account Information', children: [
            _buildInfoTile(icon: Icons.person, label: 'Name', value: _userProfile?['name'] ?? currentUser?.displayName ?? 'User'),
            _buildInfoTile(icon: Icons.email, label: 'Email', value: currentUser?.email ?? 'No email'),
            _buildInfoTile(icon: Icons.badge, label: 'Role', value: _userProfile?['role'] ?? 'PATIENT'),
            _buildInfoTile(icon: Icons.access_time, label: 'Timezone', value: _userProfile?['timezone'] ?? 'Asia/Dhaka'),
          ]),
          const SizedBox(height: 24),
          _buildSection(title: 'App Information', children: [
            _buildInfoTile(icon: Icons.info, label: 'Version', value: '2.0.0'),
            _buildInfoTile(icon: Icons.school, label: 'Project', value: 'IT Capstone 2'),
          ]),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _handleLogout,
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('MediSmart © 2026', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          Text('Your Health Companion', style: TextStyle(color: Colors.grey[500], fontSize: 12, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    String role = _userProfile?['role'] ?? 'PATIENT';
    Color roleColor = role == 'ADMIN' ? Colors.red : role == 'CAREGIVER' ? Colors.purple : Colors.blue;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(colors: [Color(0xFF2196F3), Color(0xFF1976D2)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))]),
            child: const Icon(Icons.person, size: 60, color: Color(0xFF2196F3)),
          ),
          const SizedBox(height: 16),
          Text(_userProfile?['name'] ?? currentUser?.displayName ?? 'User',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          Text(currentUser?.email ?? 'No email', style: const TextStyle(fontSize: 14, color: Colors.white70)),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: roleColor.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(20)),
              child: Text(role, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(20)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.circle, color: Colors.greenAccent, size: 8),
                SizedBox(width: 4),
                Text('Active', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ]),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _buildSection({required String title, required List<Widget> children}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.only(left: 8, bottom: 12),
        child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87))),
      Card(elevation: 1, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: Column(children: children)),
    ]);
  }

  Widget _buildInfoTile({required IconData icon, required String label, required String value}) {
    return ListTile(
      leading: Container(padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: const Color(0xFF2196F3).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: const Color(0xFF2196F3), size: 24)),
      title: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      subtitle: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black87)),
    );
  }
}
