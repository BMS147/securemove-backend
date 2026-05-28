import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class ScanResultCard extends StatelessWidget {
  const ScanResultCard({
    super.key,
    required this.result,
    this.onDismiss,
    this.onReportDuplicate,
    this.onRetry,
  });

  final Map<String, dynamic> result;
  final VoidCallback? onDismiss;
  final Future<void> Function()? onReportDuplicate;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final status = (result['status'] as String?) ?? 'INVALID';
    final config = _configFor(status);
    final fake = status == 'FAKE';

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.96, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: AnimatedContainer(
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
          border: fake ? Border.all(color: Colors.white, width: 2) : null,
          boxShadow: [
            BoxShadow(
              color: config.background.withOpacity(fake ? 0.55 : 0.30),
              blurRadius: fake ? 30 : 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(config.icon, color: Colors.white, size: 54),
            const SizedBox(height: 12),
            Text(
              config.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            ..._detailsFor(status),
            const SizedBox(height: 10),
            Text(
              (result['message'] as String?) ?? config.message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (status == 'ALREADY_USED' && onReportDuplicate != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onReportDuplicate,
                icon: const Icon(Icons.report_gmailerrorred_rounded),
                label: const Text('Report duplicate'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white70),
                ),
              ),
            ],
            if (status == 'NETWORK_ERROR' && onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
            if (status != 'NETWORK_ERROR' && onDismiss != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onDismiss,
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Back to scanner'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: config.background,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _detailsFor(String status) {
    final whiteText = const TextStyle(color: Colors.white, fontSize: 14);
    Widget line(String value, {bool strong = false}) => Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Text(
            value,
            textAlign: TextAlign.center,
            style: whiteText.copyWith(
              fontWeight: strong ? FontWeight.w900 : FontWeight.w600,
            ),
          ),
        );

    switch (status) {
      case 'VALID':
        return [
          line(
            '${result['passengerName'] ?? 'Passenger'} - Seat ${result['seatNumber'] ?? ''}',
            strong: true,
          ),
          line('${result['route'] ?? ''}'),
          line('Bus: ${result['busNumber'] ?? 'Bus pending'}'),
          line('Departure: ${result['departureTime'] ?? 'Time pending'}'),
          line('Ticket ${result['ticketRef'] ?? result['ticketNumber'] ?? ''}'),
        ];
      case 'ALREADY_USED':
        return [
          line('First scanned at: ${result['scannedAt'] ?? 'Unknown time'}'),
          line(
            'DO NOT ALLOW BOARDING',
            strong: true,
          ),
        ];
      case 'EXPIRED':
        return [
          line('This ticket was valid for ${_readTime(result['departureTime'])}'),
          line('DO NOT ALLOW BOARDING', strong: true),
        ];
      case 'SCHEDULED_LATER':
        return [
          line('Route: ${result['route'] ?? 'assigned trip'}'),
          line('Departure: ${_readTime(result['departureTime'])}'),
          line('Boarding starts: ${_readTime(result['boardingStartsAt'])}'),
          line('DO NOT ALLOW BOARDING YET', strong: true),
        ];
      case 'FAKE':
        return [
          line('QR signature verification FAILED'),
          line('Security alert sent to supervisor', strong: true),
        ];
      case 'WRONG_TRIP':
        return [
          line('This ticket is for: ${result['correctRoute'] ?? 'another trip'}'),
          line('Your trip: ${result['assignedRoute'] ?? 'assigned trip'}'),
          line('DO NOT ALLOW BOARDING', strong: true),
        ];
      case 'NETWORK_ERROR':
        return [
          line('No connection to server'),
          line('Do NOT allow boarding - ticket unverifiable', strong: true),
        ];
      default:
        return [
          line('DO NOT ALLOW BOARDING', strong: true),
        ];
    }
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
          title: 'TICKET ALREADY SCANNED',
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
      case 'SCHEDULED_LATER':
        return const _ScanResultConfig(
          title: 'TRIP SCHEDULED LATER',
          message: 'Trip is scheduled for a later time',
          icon: Icons.schedule_rounded,
          background: AppColors.warning,
          shadow: Color(0xFFD97706),
        );
      case 'WRONG_TRIP':
        return const _ScanResultConfig(
          title: 'WRONG TRIP',
          message: 'This ticket is not for your assigned trip',
          icon: Icons.block_rounded,
          background: Color(0xFFEA580C),
          shadow: Color(0xFF991B1B),
        );
      case 'FAKE':
        return const _ScanResultConfig(
          title: 'FRAUDULENT TICKET DETECTED',
          message: 'QR signature verification failed',
          icon: Icons.gpp_bad_rounded,
          background: Color(0xFF7F1D1D),
          shadow: Color(0xFF450A0A),
        );
      case 'NETWORK_ERROR':
        return const _ScanResultConfig(
          title: 'CANNOT VERIFY TICKET',
          message: 'No connection to server',
          icon: Icons.wifi_off_rounded,
          background: Color(0xFF4B5563),
          shadow: Color(0xFF1F2937),
        );
      default:
        return const _ScanResultConfig(
          title: 'INVALID TICKET',
          message: 'Ticket not found or tampered',
          icon: Icons.cancel_rounded,
          background: Color(0xFF7A1020),
          shadow: Color(0xFF450A0A),
        );
    }
  }

  String _readTime(dynamic value) {
    if (value == null) return 'the scheduled departure';
    final parsed = DateTime.tryParse(value.toString())?.toLocal();
    if (parsed == null) return value.toString();
    final hour = parsed.hour.toString().padLeft(2, '0');
    final minute = parsed.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
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
