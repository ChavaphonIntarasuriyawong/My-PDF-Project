import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

enum NavTab { library, create, profile }

class AppBottomNavBar extends StatelessWidget {
  final ValueChanged<NavTab> onTap;

  const AppBottomNavBar({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Per Figma 17:535 — Create tab is always the highlighted pill, regardless of route.
    const resolvedActive = NavTab.create;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
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
              padding: const EdgeInsets.fromLTRB(31.61, 13, 31.61, 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: NavTab.values
                    .map((tab) => _NavItem(tab: tab, active: resolvedActive, onTap: onTap))
                    .toList(),
              ),
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

  static const _meta = {
    NavTab.library: (icon: FontAwesomeIcons.bookOpenReader, label: 'Library'),
    NavTab.create:  (icon: Icons.add,                   label: 'Create'),
    NavTab.profile: (icon: Icons.person_outline,        label: 'Profile'),
  };

  const _NavItem({required this.tab, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isActive = tab == active;
    final meta = _meta[tab]!;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onTap(tab),
        borderRadius: BorderRadius.circular(8),
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
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                meta.icon,
                color: isActive ? Colors.white : AppColors.textNav,
                size: 20,
              ),
              const SizedBox(height: 2),
              Text(
                meta.label.toUpperCase(),
                style: AppTypography.navLabel.copyWith(
                  color: isActive ? Colors.white : AppColors.textNav,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
