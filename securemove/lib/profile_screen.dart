import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'auth_screens.dart';
import 'driver_workspace_screen.dart';
import 'management_hub_screen.dart';
import 'my_bookings_screen.dart';
import 'security_activity_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    await AuthService.instance.logout();
    if (!context.mounted) {
      return;
    }

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
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF3F7FD), Color(0xFFE8F0FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: FutureBuilder<UserProfile?>(
            future: AuthService.instance.getCurrentUserProfile(),
            builder: (context, snapshot) {
              final profile = snapshot.data;

              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Profile',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF17357E), Color(0xFF3868F3)],
                      ),
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 92,
                          height: 92,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              profile?.initials ?? 'SM',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          profile?.displayName ?? 'SecureMove User',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          profile?.email ?? 'No email available',
                          style: const TextStyle(
                            color: Color(0xE8FFFFFF),
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 18),
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
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Account',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
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
                  _ProfileOption(
                    icon: Icons.confirmation_number_outlined,
                    title: 'My bookings',
                    subtitle: 'View reserved and paid trips',
                    onTap: () => _openMyBookings(context),
                  ),
                  if (profile?.roleId == 2 || profile?.roleId == 3)
                    _ProfileOption(
                      icon: Icons.domain_outlined,
                      title: 'Management hub',
                      subtitle: 'Company dashboard, drivers, and operations data',
                      onTap: () => _openManagementHub(context),
                    ),
                  if (profile?.roleId == 4)
                    _ProfileOption(
                      icon: Icons.directions_bus_filled_outlined,
                      title: 'Driver workspace',
                      subtitle: 'Assigned trips, passenger tickets, and verification',
                      onTap: () => _openDriverWorkspace(context),
                    ),
                  _ProfileOption(
                    icon: Icons.lock_person_outlined,
                    title: 'Security',
                    subtitle: 'Security only',
                    onTap: () => _openSecurityActivity(context),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    onPressed: () => _logout(context),
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Log out'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ProfileBadge extends StatelessWidget {
  const _ProfileBadge({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x100F2554),
            blurRadius: 24,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF4FF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: const Color(0xFF2A54C6)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF6C7894),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF7D8AA3),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
