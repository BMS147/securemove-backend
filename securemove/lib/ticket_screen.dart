import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'bus.dart';
import 'theme/app_colors.dart';
import 'widgets/workspace_header.dart';

class TicketScreen extends StatelessWidget {
  const TicketScreen({
    super.key,
    required this.bus,
    required this.method,
    this.bookingReference,
    this.travelDate,
    this.ticketCount = 1,
  });

  final Bus bus;
  final String method;
  final String? bookingReference;
  final DateTime? travelDate;
  final int ticketCount;

  String get ticketReference {
    if (bookingReference != null && bookingReference!.trim().isNotEmpty) {
      return bookingReference!;
    }

    final routeCode =
        '${bus.origin.substring(0, 3)}${bus.destination.substring(0, 3)}'
            .toUpperCase();
    return 'SM-${bus.scheduleId}-$routeCode';
  }

  String get ticketData {
    return Uri(
      scheme: 'https',
      host: 'securemove.app',
      path: '/ticket',
      queryParameters: {
        'ref': ticketReference,
        'schedule': '${bus.scheduleId}',
        'from': bus.origin,
        'to': bus.destination,
        'time': bus.time,
        if (travelDate != null) 'date': _dateLabel(travelDate!),
        'tickets': '$ticketCount',
      },
    ).toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          const WorkspaceHeader(
            title: 'Your ticket',
            subtitle: 'Ready to board',
            actionIcon: Icons.verified_rounded,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
            child: Column(
              children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.success, Color(0xFF059669)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.success.withOpacity(0.28),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 52,
                ),
                SizedBox(height: 14),
                Text(
                  'Ticket confirmed',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Keep this QR code ready for inspection before boarding.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xE8FFFFFF),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                _infoRow('Bus Company', bus.company),
                _infoRow('Route', '${bus.origin} to ${bus.destination}'),
                _infoRow('Departure Time', bus.time),
                if (travelDate != null)
                  _infoRow('Travel Date', _dateLabel(travelDate!)),
                _infoRow(
                  ticketCount == 1 ? 'Ticket' : 'Tickets',
                  '$ticketCount',
                ),
                _infoRow('Travel Time', bus.formattedDuration),
                _infoRow('Price', bus.price),
                _infoRow('Payment Method', method),
                if (bus.driverName != null)
                  _infoRow('Driver', bus.driverName!),
                if (bus.driverLicenseNumber != null)
                  _infoRow('Driver License', bus.driverLicenseNumber!),
                if (bus.driverPhone != null)
                  _infoRow('Driver Phone', bus.driverPhone!),
                if (bus.registrationNumber != null)
                  _infoRow('Bus Number', bus.registrationNumber!),
                const Divider(height: 36),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: QrImageView(
                    data: ticketData,
                    version: QrVersions.auto,
                    size: 190,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 14),
                SelectableText(
                  ticketReference,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAFBF4),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Show this QR to the inspector or share the ticket reference',
                    style: TextStyle(
                      color: Color(0xFF237A50),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF6C7894)),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _dateLabel(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }
}
