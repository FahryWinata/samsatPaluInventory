import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../l10n/app_localizations.dart';

class AppSidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;

  const AppSidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context)!;

    return Container(
      width: 250,
      color: AppColors.sidebarBackground,
      child: Column(
        children: [
          // Spacing at top
          const SizedBox(height: 32),
          // Navigation Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                // GENERAL Section
                _SidebarSectionHeader(
                  title: localization.t('general').toUpperCase(),
                ),
                _SidebarItem(
                  icon: Icons.grid_view_rounded, // Dashboard icon
                  title: localization.t('dashboard'),
                  isSelected: selectedIndex == 0,
                  onTap: () => onItemSelected(0),
                ),

                const SizedBox(height: 16),

                // MANAGEMENT Section
                _SidebarSectionHeader(title: 'MANAGEMENT'),
                _SidebarItem(
                  icon: Icons.inventory_2_outlined,
                  title: localization.t('inventory'),
                  isSelected: selectedIndex == 1,
                  onTap: () => onItemSelected(1),
                ),
                _SidebarItem(
                  icon: Icons.devices_other_rounded,
                  title: localization.t('assets'),
                  isSelected: selectedIndex == 2,
                  onTap: () => onItemSelected(2),
                ),
                _SidebarItem(
                  icon: Icons.build_circle_outlined,
                  title: localization.t('maintenance_reminder'),
                  isSelected: selectedIndex == 4,
                  onTap: () => onItemSelected(4),
                ),

                const SizedBox(height: 16),

                // TOOLS Section
                _SidebarSectionHeader(title: 'TOOLS'),
                _SidebarItem(
                  icon: Icons.analytics_outlined,
                  title: localization.t('reports'),
                  isSelected: selectedIndex == 3,
                  onTap: () => onItemSelected(3),
                ),
                _SidebarItem(
                  icon: Icons.people_outline_rounded,
                  title: localization.t('users'),
                  isSelected: selectedIndex == 5,
                  onTap: () => onItemSelected(5),
                ),

                const SizedBox(height: 16),

                // SUPPORT Section
                _SidebarSectionHeader(title: 'SUPPORT'),
                _SidebarItem(
                  icon: Icons.settings_outlined,
                  title: localization.t('settings'),
                  isSelected: selectedIndex == 6,
                  onTap: () => onItemSelected(6),
                ),
              ],
            ),
          ),

          // User Profile Snippet (Optional - matches design bottom left)
          // Adding a placeholder for the logged-in user if desired later
        ],
      ),
    );
  }
}

class _SidebarSectionHeader extends StatelessWidget {
  final String title;
  const _SidebarSectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          hoverColor: AppColors.primary.withValues(alpha: 0.05),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textSecondary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
                if (isSelected) ...[
                  const Spacer(),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
