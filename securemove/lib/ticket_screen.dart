import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'bus.dart';
import 'theme/app_colors.dart';
import 'theme/breakpoints.dart';
import 'widgets/traveler_shell.dart';

/// Boarding-pass style ticket screen.
///
/// Reached via `pushReplacement` from `PaymentScreen` after a successful
/// payment. The screen presents a status banner, a sectioned summary of
/// the trip, and the QR code/reference used at the gate.
///
/// The primary CTA returns the user to the Bookings tab inside
/// [TravelerShell] so the new ticket appears in their list.
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

  // ---------------------------------------------------------------------------
  // Derived data
  // ---------------------------------------------------------------------------

  String get ticketReference {
    if (bookingReference != null && bookingReference!.trim().isNotEmpty) {
      return bookingReference!;
    }
    final routeCode =
        '${bus.origin.substring(0, 3)}${bus.destination.substring(0, 3)}'
            .toUpperCase();
    return 'SM-${bus.scheduleId}-$routeCode';
  }

  String get _routeCode =>
      '${bus.origin.substring(0, 3)}-${bus.destination.substring(0, 3)}'
          .toUpperCase();

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
        if (travelDate != null) 'date': _isoDate(travelDate!),
        'tickets': '$ticketCount',
      },
    ).toString();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isDesktop = Breakpoints.isDesktop(context);
    // On desktop the boarding pass is centered with a generous left/right
    // margin; on mobile it goes full-bleed.
    final maxWidth = isDesktop ? 560.0 : double.infinity;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: _Header(onBack: () => _goBackToBookings(context)),
              ),
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      isDesktop ? 32 : 18,
                      4,
                      isDesktop ? 32 : 18,
                      28,
                    ),
                    children: [
                      _StatusBanner(travelDate: travelDate),
                      const SizedBox(height: 20),
                      _BoardingPass(
                        bus: bus,
                        ticketCount: ticketCount,
                        travelDate: travelDate,
                        method: method,
                        ticketReference: ticketReference,
                        ticketData: ticketData,
                        routeCode: _routeCode,
                      ),
                      const SizedBox(height: 22),
                      _ActionRow(
                        ticketReference: ticketReference,
                        onDone: () => _goBackToBookings(context),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _goBackToBookings(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const TravelerShell(initialIndex: 1)),
      (route) => false,
    );
  }

  static String _isoDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }
}

// ===========================================================================
// Header (replaces WorkspaceHeader so we can include a back affordance)
// ===========================================================================

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 18, 12),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            color: AppColors.textPrimary,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Boarding pass',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Your ticket',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.successTint,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.verified_rounded,
              color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Status banner
// ===========================================================================

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.travelDate});

  final DateTime? travelDate;

  @override
  Widget build(BuildContext context) {
    final dateLabel = travelDate == null
        ? null
        : DateFormat('EEE, d MMM yyyy').format(travelDate!);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.success, AppColors.successDeep],
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
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: AppColors.textOnBrand,
              size: 32,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ticket confirmed',
                  style: TextStyle(
                    color: AppColors.textOnBrand,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dateLabel == null
                      ? 'Show the QR before boarding.'
                      : 'Travel date • $dateLabel',
                  style: const TextStyle(
                    color: AppColors.textOnBrandSoft,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Boarding-pass card (info + perforation + QR)
// ===========================================================================

class _BoardingPass extends StatelessWidget {
  const _BoardingPass({
    required this.bus,
    required this.ticketCount,
    required this.travelDate,
    required this.method,
    required this.ticketReference,
    required this.ticketData,
    required this.routeCode,
  });

  final Bus bus;
  final int ticketCount;
  final DateTime? travelDate;
  final String method;
  final String ticketReference;
  final String ticketData;
  final String routeCode;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: const [AppColors.cardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Route header ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
            child: _RouteHeader(
              from: bus.origin,
              to: bus.destination,
              code: routeCode,
              time: bus.time,
              duration: bus.formattedDuration,
            ),
          ),

          // ── Trip details ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 8),
            child: _Section(
              title: 'Trip details',
              rows: [
                _Row('Operator', bus.company),
                if (travelDate != null)
                  _Row('Travel date',
                      DateFormat('EEE, d MMM yyyy').format(travelDate!)),
                _Row(
                  ticketCount == 1 ? 'Ticket' : 'Tickets',
                  '$ticketCount',
                ),
                _Row('Price', bus.price),
                _Row('Payment', method),
              ],
            ),
          ),

          // ── Bus & driver (only if data available) ───────────────────────
          if (bus.registrationNumber != null ||
              bus.driverName != null ||
              bus.driverLicenseNumber != null ||
              bus.driverPhone != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 18),
              child: _Section(
                title: 'Bus & driver',
                rows: [
                  if (bus.registrationNumber != null)
                    _Row('Bus number', bus.registrationNumber!),
                  if (bus.driverName != null) _Row('Driver', bus.driverName!),
                  if (bus.driverLicenseNumber != null)
                    _Row('License', bus.driverLicenseNumber!),
                  if (bus.driverPhone != null)
                    _Row('Phone', bus.driverPhone!),
                ],
              ),
            ),

          // ── Perforation divider ─────────────────────────────────────────
          const _Perforation(),

          // ── QR + reference ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 26),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: QrImageView(
                    data: ticketData,
                    version: QrVersions.auto,
                    size: 200,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Booking reference',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  ticketReference,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.successTint,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.qr_code_scanner_rounded,
                        size: 16,
                        color: AppColors.successText,
                      ),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Show this QR at boarding',
                          style: TextStyle(
                            color: AppColors.successText,
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
}

// ===========================================================================
// Route header (origin → destination, departure time, duration)
// ===========================================================================

class _RouteHeader extends StatelessWidget {
  const _RouteHeader({
    required this.from,
    required this.to,
    required this.code,
    required this.time,
    required this.duration,
  });

  final String from;
  final String to;
  final String code;
  final String time;
  final String duration;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _Endpoint(label: 'From', city: from)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  const Icon(
                    Icons.directions_bus_filled_rounded,
                    color: AppColors.brandPrimary,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    code,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _Endpoint(
                label: 'To',
                city: to,
                alignEnd: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _MetaPill(icon: Icons.schedule_rounded, label: time),
            const SizedBox(width: 8),
            _MetaPill(icon: Icons.timelapse_rounded, label: duration),
          ],
        ),
      ],
    );
  }
}

class _Endpoint extends StatelessWidget {
  const _Endpoint({
    required this.label,
    required this.city,
    this.alignEnd = false,
  });

  final String label;
  final String city;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          city,
          textAlign: alignEnd ? TextAlign.end : TextAlign.start,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.brandTint,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.brandPrimary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.brandPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Section block (title + rows)
// ===========================================================================

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.rows});

  final String title;
  final List<_Row> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        ...rows,
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Perforation — two notch circles + dashed line, the classic boarding-pass cue
// ===========================================================================

class _Perforation extends StatelessWidget {
  const _Perforation();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: Row(
        children: [
          // Left notch
          Container(
            width: 18,
            height: 28,
            decoration: const BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
          ),
          // Dashed line
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const dashWidth = 6.0;
                const dashGap = 5.0;
                final count =
                    (constraints.maxWidth / (dashWidth + dashGap)).floor();
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(
                    count,
                    (_) => Container(
                      width: dashWidth,
                      height: 2,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // Right notch
          Container(
            width: 18,
            height: 28,
            decoration: const BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(28),
                bottomLeft: Radius.circular(28),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Action row — copy reference + done
// ===========================================================================

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.ticketReference,
    required this.onDone,
  });

  final String ticketReference;
  final VoidCallback onDone;

  Future<void> _copyReference(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: ticketReference));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Booking reference copied'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _copyReference(context),
            icon: const Icon(Icons.copy_rounded),
            label: const Text('Copy ref'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.brandPrimary,
              minimumSize: const Size.fromHeight(54),
              side: const BorderSide(color: AppColors.brandBorder),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: onDone,
            icon: const Icon(Icons.check_rounded),
            label: const Text('Done'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandVivid,
              foregroundColor: AppColors.textOnBrand,
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
