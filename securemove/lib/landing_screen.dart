import 'package:flutter/material.dart';

import 'theme/app_colors.dart';
import 'theme/breakpoints.dart';
import 'widgets/traveler_shell.dart';

/// Marketing landing page (public deep-link target).
///
/// Most travelers skip this — the login flow routes them directly into
/// [TravelerShell]. Useful for sharing a "preview the app" URL.
class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  void _openShell(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TravelerShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = Breakpoints.isDesktop(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.surfaceGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              isDesktop ? 48 : 20,
              isDesktop ? 32 : 16,
              isDesktop ? 48 : 20,
              28,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: Breakpoints.contentMaxWidth,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (isDesktop)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(flex: 5, child: _Intro(theme: theme)),
                          const SizedBox(width: 32),
                          Expanded(
                            flex: 6,
                            child: _HeroBusCard(
                              onBookTrip: () => _openShell(context),
                            ),
                          ),
                        ],
                      )
                    else ...[
                      _Intro(theme: theme),
                      const SizedBox(height: 24),
                      _HeroBusCard(onBookTrip: () => _openShell(context)),
                    ],
                    const SizedBox(height: 48),
                    _FeatureGrid(isDesktop: isDesktop),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Intro column (text + pills)
// ===========================================================================

class _Intro extends StatelessWidget {
  const _Intro({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final isDesktop = Breakpoints.isDesktop(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Text(
            'Secure intercity travel',
            style: TextStyle(
              color: AppColors.brandPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Welcome to\nSecureMove',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: isDesktop ? 56 : 36,
            fontWeight: FontWeight.w800,
            height: 1.05,
            letterSpacing: -1.5,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Search routes, compare operators, and pay securely — your next trip is a few taps away.',
          style: TextStyle(
            fontSize: 16,
            color: AppColors.textSecondary,
            height: 1.55,
          ),
        ),
        const SizedBox(height: 24),
        const Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _InfoPill(
              icon: Icons.directions_bus_filled_rounded,
              label: 'Bus booking',
            ),
            _InfoPill(icon: Icons.route_rounded, label: 'Route search'),
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

// ===========================================================================
// Feature grid (desktop) / column (mobile)
// ===========================================================================

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid({required this.isDesktop});

  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    const features = [
      (
        icon: Icons.qr_code_2_rounded,
        title: 'Digital tickets',
        body: 'A QR code per seat. No printing, no paperwork.',
      ),
      (
        icon: Icons.payments_outlined,
        title: 'Mobile money + cards',
        body: 'MTN MoMo, Airtel Money, and card checkout, all in one flow.',
      ),
      (
        icon: Icons.support_agent_outlined,
        title: '24/7 support',
        body: 'Schedule issues or refund requests answered within minutes.',
      ),
    ];

    if (isDesktop) {
      return Row(
        children: [
          for (var i = 0; i < features.length; i++) ...[
            Expanded(
              child: _FeatureTile(
                icon: features[i].icon,
                title: features[i].title,
                body: features[i].body,
              ),
            ),
            if (i < features.length - 1) const SizedBox(width: 16),
          ],
        ],
      );
    }

    return Column(
      children: [
        for (final f in features)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _FeatureTile(icon: f.icon, title: f.title, body: f.body),
          ),
      ],
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [AppColors.cardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.brandTint,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.brandPrimary),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Hero bus card (kept from previous design, color-tokenized)
// ===========================================================================

class _HeroBusCard extends StatelessWidget {
  const _HeroBusCard({required this.onBookTrip});

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
              aspectRatio: 1.55,
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
                        color: AppColors.brandDeep.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text(
                        'SecureMove',
                        style: TextStyle(
                          color: AppColors.textOnBrand,
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
                minimumSize: const Size(0, 56),
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 16,
                ),
                backgroundColor: AppColors.surface,
                foregroundColor: AppColors.brandDeep,
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
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
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
          Icon(icon, size: 18, color: AppColors.brandPrimary),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.brandPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
