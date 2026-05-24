import 'package:flutter/material.dart';

import '../home_screen.dart';
import '../my_bookings_screen.dart';
import '../profile_screen.dart';
import '../theme/app_colors.dart';
import '../theme/breakpoints.dart';

/// Responsive navigation shell for travelers.
///
///   • Mobile (< 1024) — bottom [NavigationBar]
///   • Desktop (≥ 1024) — left [NavigationRail] with labels + brand header
///
/// Tabs are kept in an [IndexedStack] so each tab preserves its state
/// (scroll position, in-flight futures) when switching.
class TravelerShell extends StatefulWidget {
  const TravelerShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<TravelerShell> createState() => _TravelerShellState();
}

class _TravelerShellState extends State<TravelerShell> {
  late int _index = widget.initialIndex.clamp(0, 2);

  static const _pages = <Widget>[
    HomeScreen(embedded: true),
    MyBookingsScreen(embedded: true),
    ProfileScreen(embedded: true),
  ];

  static const _destinations = [
    _Dest(
      icon: Icons.search_rounded,
      selectedIcon: Icons.search_rounded,
      label: 'Home',
    ),
    _Dest(
      icon: Icons.confirmation_number_outlined,
      selectedIcon: Icons.confirmation_number_rounded,
      label: 'Bookings',
    ),
    _Dest(
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDesktop = Breakpoints.isDesktop(context);
    // Use IndexedStack so each tab preserves its State (scroll position,
    // in-flight futures) across switches.
    final body = IndexedStack(
      index: _index,
      children: _pages,
    );

    if (isDesktop) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Row(
            children: [
              _DesktopRail(
                selectedIndex: _index,
                destinations: _destinations,
                onSelected: (i) => setState(() => _index = i),
              ),
              const VerticalDivider(width: 1, color: AppColors.border),
              Expanded(child: body),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.brandTint,
        destinations: [
          for (final d in _destinations)
            NavigationDestination(
              icon: Icon(d.icon, color: AppColors.textMuted),
              selectedIcon: Icon(d.selectedIcon, color: AppColors.brandPrimary),
              label: d.label,
            ),
        ],
      ),
    );
  }
}

class _Dest {
  const _Dest({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

class _DesktopRail extends StatelessWidget {
  const _DesktopRail({
    required this.selectedIndex,
    required this.destinations,
    required this.onSelected,
  });

  final int selectedIndex;
  final List<_Dest> destinations;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Brand
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: AppColors.brandGradientShort,
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    color: AppColors.textOnBrand,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'SecureMove',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 12),

          // Destinations
          for (var i = 0; i < destinations.length; i++)
            _RailItem(
              dest: destinations[i],
              selected: selectedIndex == i,
              onTap: () => onSelected(i),
            ),

          const Spacer(),
          // Footer
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.brandTint,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.support_agent_rounded,
                    color: AppColors.brandPrimary,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Need help?\nReach support 24/7',
                      style: TextStyle(
                        color: AppColors.brandPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.dest,
    required this.selected,
    required this.onTap,
  });

  final _Dest dest;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: selected ? AppColors.brandTint : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  selected ? dest.selectedIcon : dest.icon,
                  size: 20,
                  color: selected
                      ? AppColors.brandPrimary
                      : AppColors.textMuted,
                ),
                const SizedBox(width: 12),
                Text(
                  dest.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: selected
                        ? AppColors.brandPrimary
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
