import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'auth_screens.dart';
import 'driver_workspace_screen.dart';
import 'management_hub_screen.dart';
import 'my_bookings_screen.dart';
import 'security_activity_screen.dart';
import 'theme/app_colors.dart';
import 'theme/breakpoints.dart';
import 'widgets/design_system/app_card.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, this.embedded = false});

  /// When true, this screen is a tab inside [TravelerShell] — we omit the
  /// back arrow because there's nothing to pop.
  final bool embedded;

  Future<void> _logout(BuildContext context) async {
    await AuthService.instance.logout();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _openSecurityActivity(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SecurityActivityScreen()),
    );
  }

  Future<void> _openMyBookings(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MyBookingsScreen()),
    );
  }

  Future<void> _openManagementHub(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ManagementHubScreen()),
    );
  }

  Future<void> _openDriverWorkspace(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DriverWorkspaceScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Breakpoints.isDesktop(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FutureBuilder<UserProfile?>(
          future: AuthService.instance.getCurrentUserProfile(),
          builder: (context, snapshot) {
            final profile = snapshot.data;

            final heroCard = _ProfileHero(profile: profile);
            final accountOptions = _AccountOptions(
              profile: profile,
              embedded: embedded,
              onOpenBookings: () => _openMyBookings(context),
              onOpenManagement: () => _openManagementHub(context),
              onOpenDriver: () => _openDriverWorkspace(context),
              onOpenSecurity: () => _openSecurityActivity(context),
              onLogout: () => _logout(context),
            );

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: Breakpoints.contentMaxWidth,
                ),
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    isDesktop ? 32 : 20,
                    16,
                    isDesktop ? 32 : 20,
                    28,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          if (!embedded)
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                              ),
                            ),
                          if (!embedded) const SizedBox(width: 8),
                          const Text(
                            'Profile',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      if (isDesktop)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 4, child: heroCard),
                            const SizedBox(width: 24),
                            Expanded(flex: 6, child: accountOptions),
                          ],
                        )
                      else ...[
                        heroCard,
                        const SizedBox(height: 22),
                        accountOptions,
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ===========================================================================
// Hero card
// ===========================================================================

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.profile});

  final UserProfile? profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: AppColors.brandGradientShort,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                profile?.initials ?? 'SM',
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textOnBrand,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            profile?.displayName ?? 'SecureMove User',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textOnBrand,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            profile?.email ?? 'No email available',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textOnBrandSoft,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              _ProfileBadge(
                icon: Icons.verified_user_outlined,
                label: profile?.roleLabel ?? 'Traveler',
              ),
              _ProfileBadge(
                icon: Icons.confirmation_number_outlined,
                label: profile?.userId == null
                    ? 'Account ready'
                    : 'User #${profile!.userId}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileBadge extends StatelessWidget {
  const _ProfileBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.textOnBrand, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textOnBrand,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Account options
// ===========================================================================

class _AccountOptions extends StatelessWidget {
  const _AccountOptions({
    required this.profile,
    required this.embedded,
    required this.onOpenBookings,
    required this.onOpenManagement,
    required this.onOpenDriver,
    required this.onOpenSecurity,
    required this.onLogout,
  });

  final UserProfile? profile;
  final bool embedded;
  final VoidCallback onOpenBookings;
  final VoidCallback onOpenManagement;
  final VoidCallback onOpenDriver;
  final VoidCallback onOpenSecurity;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionLabel(label: 'ACCOUNT'),
        _ProfileOption(
          icon: Icons.mail_outline_rounded,
          title: 'Email address',
          subtitle: profile?.email ?? 'Stored from your latest login',
        ),
        _ProfileOption(
          icon: Icons.badge_outlined,
          title: 'Role',
          subtitle: profile?.roleLabel ?? 'Traveler',
        ),
        if (!embedded)
          _ProfileOption(
            icon: Icons.confirmation_number_outlined,
            title: 'My bookings',
            subtitle: 'View reserved and paid trips',
            onTap: onOpenBookings,
          ),
        if (profile?.roleId == 2 || profile?.roleId == 3 || profile?.roleId == 4)
          const SizedBox(height: 16),
        if (profile?.roleId == 2 || profile?.roleId == 3 || profile?.roleId == 4)
          const _SectionLabel(label: 'WORKSPACE'),
        if (profile?.roleId == 2 || profile?.roleId == 3)
          _ProfileOption(
            icon: Icons.domain_outlined,
            title: 'Management hub',
            subtitle: 'Company dashboard, drivers, and operations data',
            onTap: onOpenManagement,
          ),
        if (profile?.roleId == 4)
          _ProfileOption(
            icon: Icons.directions_bus_filled_outlined,
            title: 'Driver workspace',
            subtitle: 'Assigned trips, passenger tickets, and verification',
            onTap: onOpenDriver,
          ),
        const SizedBox(height: 16),
        const _SectionLabel(label: 'SECURITY'),
        _ProfileOption(
          icon: Icons.lock_person_outlined,
          title: 'Security activity',
          subtitle: 'Recent sign-ins and audit log',
          onTap: onOpenSecurity,
        ),
        const SizedBox(height: 22),
        ElevatedButton.icon(
          onPressed: onLogout,
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Log out'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.danger,
            foregroundColor: AppColors.textOnBrand,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _ProfileOption extends StatelessWidget {
  const _ProfileOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.brandTint,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: AppColors.brandPrimary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.35,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
              ),
          ],
        ),
      ),
    );
  }
}
