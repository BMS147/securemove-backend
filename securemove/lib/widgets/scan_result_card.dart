import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class ScanResultCard extends StatelessWidget {
  const ScanResultCard({super.key, required this.result});

  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    final status = (result['status'] as String?) ?? 'INVALID';
    final config = _configFor(status);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [config.background, config.shadow],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: config.background.withOpacity(0.30),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(config.icon, color: Colors.white, size: 46),
          const SizedBox(height: 10),
          Text(
            config.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          if (status == 'VALID') ...[
            const SizedBox(height: 8),
            Text(
              '${result['passengerName'] ?? 'Passenger'} - Seat ${result['seatNumber'] ?? ''}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              '${result['route'] ?? ''} - ${result['busNumber'] ?? ''}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
          ] else if (status == 'ALREADY_USED') ...[
            const SizedBox(height: 8),
            Text(
              'First scanned: ${result['scannedAt'] ?? 'Unknown time'}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            (result['message'] as String?) ?? config.message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  _ScanResultConfig _configFor(String status) {
    switch (status) {
      case 'VALID':
        return const _ScanResultConfig(
          title: 'BOARD PASSENGER',
          message: 'Passenger may board',
          icon: Icons.check_circle_rounded,
          background: AppColors.success,
          shadow: AppColors.successDeep,
        );
      case 'ALREADY_USED':
        return const _ScanResultConfig(
          title: 'ALREADY SCANNED',
          message: 'This ticket was already scanned',
          icon: Icons.warning_amber_rounded,
          background: AppColors.warning,
          shadow: Color(0xFFD97706),
        );
      case 'EXPIRED':
        return const _ScanResultConfig(
          title: 'TICKET EXPIRED',
          message: 'This ticket is for a past trip',
          icon: Icons.cancel_rounded,
          background: AppColors.danger,
          shadow: Color(0xFFDC2626),
        );
      case 'WRONG_TRIP':
        return const _ScanResultConfig(
          title: 'NOT YOUR TRIP',
          message: 'This ticket is not for your assigned trip',
          icon: Icons.block_rounded,
          background: AppColors.danger,
          shadow: Color(0xFFDC2626),
        );
      default:
        return const _ScanResultConfig(
          title: 'INVALID TICKET - DO NOT BOARD',
          message: 'Ticket not found or tampered',
          icon: Icons.gpp_bad_rounded,
          background: Color(0xFF7A1020),
          shadow: Color(0xFF450A0A),
        );
    }
  }
}

class _ScanResultConfig {
  const _ScanResultConfig({
    required this.title,
    required this.message,
    required this.icon,
    required this.background,
    required this.shadow,
  });

  final String title;
  final String message;
  final IconData icon;
  final Color background;
  final Color shadow;
}
