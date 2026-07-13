// lib/screens/home/main_navigation.dart
// Smart Navigation - shows different tabs based on user role
// Patient: Home, Medications, Adherence, Reports, Profile
// Caregiver: Home, Medications, Patients, Reports, Profile
// Admin: Home, Medications, Admin Portal, Reports, Profile
// Web/Tablet (>768px): Sidebar NavigationRail

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:medismart/screens/home/home_screen.dart';
import 'package:medismart/screens/medications/medication_list_screen.dart';
import 'package:medismart/screens/adherence/adherence_screen.dart';
import 'package:medismart/screens/reports/reports_screen.dart';
import 'package:medismart/screens/profile/profile_screen.dart';
import 'package:medismart/screens/caregiver/caregiver_screen.dart';
import 'package:medismart/screens/admin/admin_screen.dart';
import 'package:medismart/utils/responsive_helper.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});
  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  String _userRole = 'PATIENT';
  bool _roleLoaded = false;

  @override
  void initState() { super.initState(); _loadUserRole(); }

  Future<void> _loadUserRole() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists && mounted) setState(() { _userRole = doc.data()?['role'] ?? 'PATIENT'; _roleLoaded = true; });
    } catch (e) { if (mounted) setState(() => _roleLoaded = true); }
  }

  List<Widget> get _screens {
    final middleScreen = _userRole == 'ADMIN' ? const AdminScreen()
        : _userRole == 'CAREGIVER' ? const CaregiverScreen()
        : const AdherenceScreen();
    return [const HomeScreen(), const MedicationListScreen(), middleScreen, const ReportsScreen(), const ProfileScreen()];
  }

  List<NavigationItem> get _navItems {
    final middleItem = _userRole == 'ADMIN'
        ? const NavigationItem(icon: Icons.admin_panel_settings_outlined, activeIcon: Icons.admin_panel_settings, label: 'Admin')
        : _userRole == 'CAREGIVER'
        ? const NavigationItem(icon: Icons.people_outline, activeIcon: Icons.people, label: 'Patients')
        : const NavigationItem(icon: Icons.track_changes_outlined, activeIcon: Icons.track_changes, label: 'Adherence');
    return [
      const NavigationItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home'),
      const NavigationItem(icon: Icons.medication_outlined, activeIcon: Icons.medication, label: 'Medications'),
      middleItem,
      const NavigationItem(icon: Icons.bar_chart_outlined, activeIcon: Icons.bar_chart, label: 'Reports'),
      const NavigationItem(icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profile'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (!_roleLoaded) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return WebAdaptiveScaffold(
      currentIndex: _currentIndex,
      onIndexChanged: (i) => setState(() => _currentIndex = i),
      screens: _screens,
      navItems: _navItems,
    );
  }
}
