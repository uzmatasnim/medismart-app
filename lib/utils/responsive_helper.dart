// lib/utils/responsive_helper.dart
// Responsive Helper - Detects platform and screen size for adaptive layout

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ResponsiveHelper {
  /// Check if running on web
  static bool get isWeb => kIsWeb;

  /// Check if screen is wide (tablet/desktop)
  static bool isWideScreen(BuildContext context) {
    return MediaQuery.of(context).size.width > 768;
  }

  /// Check if screen is desktop size
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width > 1200;
  }

  /// Get content max width for web
  static double contentMaxWidth(BuildContext context) {
    if (isDesktop(context)) return 900;
    if (isWideScreen(context)) return 700;
    return double.infinity;
  }

  /// Get padding based on screen size
  static EdgeInsets pagePadding(BuildContext context) {
    if (isDesktop(context)) {
      return const EdgeInsets.symmetric(horizontal: 48, vertical: 24);
    }
    if (isWideScreen(context)) {
      return const EdgeInsets.symmetric(horizontal: 32, vertical: 16);
    }
    return const EdgeInsets.all(16);
  }
}

/// Widget that centers content on wide screens (web/desktop)
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double? maxWidth;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    final double width = maxWidth ?? ResponsiveHelper.contentMaxWidth(context);

    if (!ResponsiveHelper.isWideScreen(context)) {
      return child;
    }

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width),
        child: child,
      ),
    );
  }
}

/// Web-optimized scaffold with sidebar navigation on wide screens
class WebAdaptiveScaffold extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onIndexChanged;
  final List<Widget> screens;
  final List<NavigationItem> navItems;

  const WebAdaptiveScaffold({
    super.key,
    required this.currentIndex,
    required this.onIndexChanged,
    required this.screens,
    required this.navItems,
  });

  @override
  Widget build(BuildContext context) {
    // On wide screens (web/tablet): show sidebar navigation
    if (ResponsiveHelper.isWideScreen(context)) {
      return Scaffold(
        body: Row(
          children: [
            // Sidebar
            NavigationRail(
              selectedIndex: currentIndex,
              onDestinationSelected: onIndexChanged,
              labelType: NavigationRailLabelType.all,
              backgroundColor: const Color(0xFF2196F3),
              selectedIconTheme: const IconThemeData(color: Colors.white),
              unselectedIconTheme:
                  const IconThemeData(color: Colors.white70),
              selectedLabelTextStyle: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
              unselectedLabelTextStyle:
                  const TextStyle(color: Colors.white70),
              leading: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    Icon(Icons.medical_services,
                        color: Colors.white, size: 32),
                    SizedBox(height: 4),
                    Text(
                      'MediSmart',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                    ),
                  ],
                ),
              ),
              destinations: navItems
                  .map((item) => NavigationRailDestination(
                        icon: Icon(item.icon),
                        selectedIcon: Icon(item.activeIcon),
                        label: Text(item.label),
                      ))
                  .toList(),
            ),
            const VerticalDivider(thickness: 1, width: 1),
            // Main content
            Expanded(
              child: screens[currentIndex],
            ),
          ],
        ),
      );
    }

    // On mobile: bottom navigation bar
    return Scaffold(
      body: IndexedStack(index: currentIndex, children: screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onIndexChanged,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF2196F3),
        unselectedItemColor: Colors.grey,
        selectedFontSize: 11,
        unselectedFontSize: 10,
        items: navItems
            .map((item) => BottomNavigationBarItem(
                  icon: Icon(item.icon),
                  activeIcon: Icon(item.activeIcon),
                  label: item.label,
                ))
            .toList(),
      ),
    );
  }
}

class NavigationItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const NavigationItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
