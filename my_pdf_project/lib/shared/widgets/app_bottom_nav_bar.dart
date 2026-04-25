import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

enum NavTab { library, create, profile }

class AppBottomNavBar extends StatelessWidget {
  final NavTab active;
  final ValueChanged<NavTab> onTap;

  const AppBottomNavBar({super.key, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xCCF8FAFB),
          border: const Border(top: BorderSide(color: AppColors.borderNav)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF191C1D).withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 13),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _NavItem(tab: NavTab.library, active: active, onTap: onTap, icon: Icons.menu_book_outlined, label: 'Library'),
                _NavItem(tab: NavTab.create, active: active, onTap: onTap, icon: Icons.add, label: 'Create'),
                _NavItem(tab: NavTab.profile, active: active, onTap: onTap, icon: Icons.person_outline, label: 'Profile'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final NavTab tab;
  final NavTab active;
  final ValueChanged<NavTab> onTap;
  final IconData icon;
  final String label;

  const _NavItem({
    required this.tab,
    required this.active,
    required this.onTap,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = tab == active;
    return GestureDetector(
      onTap: () => onTap(tab),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 15,
                    offset: const Offset(0, 10),
                  ),
                ]
              : [],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isActive ? Colors.white : AppColors.textNav, size: 20),
            const SizedBox(height: 2),
            Text(
              label.toUpperCase(),
              style: AppTypography.navLabel.copyWith(
                color: isActive ? Colors.white : AppColors.textNav,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
