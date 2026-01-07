import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/app_sidebar.dart';
import '../providers/navigation_provider.dart';
import 'dashboard_screen.dart';
import 'inventory_screen.dart';
import 'assets_screen.dart';
import 'reports_screen.dart';
import 'maintenance_screen.dart';
import 'users_screen.dart';
import 'settings_screen.dart';
import '../utils/extensions.dart';

class MainLayout extends StatelessWidget {
  const MainLayout({super.key});

  @override
  Widget build(BuildContext context) {
    // Listen to the provider
    final navigation = context.watch<NavigationProvider>();
    final selectedIndex = navigation.currentIndex;

    // We build the screen based on the index dynamically
    Widget buildScreen() {
      switch (selectedIndex) {
        case 0:
          return const DashboardScreen();
        case 1:
          return InventoryScreen(initialFilter: navigation.inventoryFilter);
        case 2:
          return const AssetsScreen();
        case 3:
          return const ReportsScreen();
        case 4:
          return const MaintenanceScreen();
        case 5:
          return const UsersScreen();
        case 6:
          return const SettingsScreen();
        default:
          return const DashboardScreen();
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Desktop / Tablet Layout (Sidebar)
        if (constraints.maxWidth > 900) {
          return Scaffold(
            body: Row(
              children: [
                // Sidebar
                AppSidebar(
                  selectedIndex: selectedIndex,
                  onItemSelected: (index) {
                    context.read<NavigationProvider>().setIndex(index);
                  },
                ),

                // Main Content
                Expanded(child: buildScreen()),
              ],
            ),
          );
        } else {
          // Mobile Layout (Bottom Navigation)
          return Scaffold(
            body: buildScreen(),
            bottomNavigationBar: NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) {
                context.read<NavigationProvider>().setIndex(index);
              },
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.dashboard_outlined),
                  selectedIcon: const Icon(Icons.dashboard),
                  label: context.t('dashboard'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.inventory_2_outlined),
                  selectedIcon: const Icon(Icons.inventory),
                  label: context.t('inventory'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.devices_other_outlined),
                  selectedIcon: const Icon(Icons.devices),
                  label: context.t('assets'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.assessment_outlined),
                  selectedIcon: const Icon(Icons.assessment),
                  label: context.t('reports'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.build_outlined),
                  selectedIcon: const Icon(Icons.build),
                  label: context.t('maintenance_reminder'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.people_outlined),
                  selectedIcon: const Icon(Icons.people),
                  label: context.t('users'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.settings_outlined),
                  selectedIcon: const Icon(Icons.settings),
                  label: context.t('settings'),
                ),
              ],
            ),
          );
        }
      },
    );
  }
}
