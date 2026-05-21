import 'package:flutter/material.dart';

import 'home_screen.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  void _openRouteSearch(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF4F7FB), Color(0xFFE8F0FF), Color(0xFFD8E6FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildIntro(theme),
                    const SizedBox(height: 24),
                    _HeroBusCard(
                      onBookTrip: () => _openRouteSearch(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIntro(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Text(
            'Secure intercity travel',
            style: TextStyle(
              color: Color(0xFF244AA8),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Welcome to SecureMove',
          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w800,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Start from the home page, tap the bus card, and head straight into route search when you are ready to book.',
          style: TextStyle(
            fontSize: 16,
            color: Color(0xFF60708E),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 22),
        const Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _InfoPill(
              icon: Icons.directions_bus_filled_rounded,
              label: 'Bus booking',
            ),
            _InfoPill(
              icon: Icons.route_rounded,
              label: 'Route search',
            ),
            _InfoPill(
              icon: Icons.verified_user_rounded,
              label: 'Secure checkout',
            ),
          ],
        ),
      ],
    );
  }
}

class _HeroBusCard extends StatelessWidget {
  const _HeroBusCard({
    required this.onBookTrip,
  });

  final VoidCallback onBookTrip;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 420),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(36),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2615306B),
            blurRadius: 34,
            offset: Offset(0, 20),
          ),
        ],
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(36),
            child: AspectRatio(
              aspectRatio: 1.75,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/images/securemove_bus_custom.png',
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withOpacity(0.14),
                          Colors.black.withOpacity(0.04),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 44,
                    bottom: 104,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xE617357E),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text(
                        'SecureMove',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 18,
            bottom: 18,
            child: ElevatedButton.icon(
              onPressed: onBookTrip,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Book a trip'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 58),
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 16,
                ),
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF17357E),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F2554),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF244AA8)),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF244AA8),
            ),
          ),
        ],
      ),
    );
  }
}
