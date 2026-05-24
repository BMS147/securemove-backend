import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'auth_service.dart';
import 'driver.dart';
import 'driver_service.dart';
import 'theme/app_colors.dart';
import 'widgets/error_banner.dart';
import 'widgets/skeleton_card.dart';

class DriverWorkspaceScreen extends StatefulWidget {
  const DriverWorkspaceScreen({super.key});

  @override
  State<DriverWorkspaceScreen> createState() => _DriverWorkspaceScreenState();
}

class _DriverWorkspaceScreenState extends State<DriverWorkspaceScreen> {
  final DriverService _driverService = DriverService.instance;
  final TextEditingController _codeController = TextEditingController();

  DriverProfile? _driver;
  List<DriverTrip> _trips = const [];
  DriverTrip? _selectedTrip;
  List<DriverTicket> _tickets = const [];
  bool _isLoading = true;
  bool _isVerifying = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final driver = await _driverService.getCurrentDriver();
      final trips = await _driverService.getMyTrips();
      final selectedTrip = trips.isEmpty ? null : trips.first;
      final tickets = selectedTrip == null
          ? const <DriverTicket>[]
          : await _driverService.getTripTickets(selectedTrip.tripId);

      if (!mounted) {
        return;
      }

      setState(() {
        _driver = driver;
        _trips = trips;
        _selectedTrip = selectedTrip;
        _tickets = tickets;
      });
    } on AuthException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectTrip(DriverTrip trip) async {
    setState(() {
      _selectedTrip = trip;
      _tickets = const [];
      _errorMessage = null;
    });

    try {
      final tickets = await _driverService.getTripTickets(trip.tripId);
      if (!mounted) {
        return;
      }
      setState(() => _tickets = tickets);
    } on AuthException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _errorMessage = error.message);
    }
  }

  Future<void> _verifyTicket() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a booking reference or ticket code.')),
      );
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final ticket = await _driverService.verifyTicket(code);
      _codeController.clear();

      if (_selectedTrip != null) {
        final tickets = await _driverService.getTripTickets(_selectedTrip!.tripId);
        if (mounted) {
          setState(() => _tickets = tickets);
        }
      }

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${ticket.passengerName} verified for boarding.')),
      );
    } on AuthException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: AppColors.background,
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Driver workspace',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (_isLoading)
                  const Column(
                    children: [
                      SkeletonCard(height: 128),
                      SizedBox(height: 16),
                      SkeletonCard(height: 150),
                      SizedBox(height: 16),
                      SkeletonCard(height: 180),
                    ],
                  )
                else ...[
                  _DriverHeader(driver: _driver),
                  const SizedBox(height: 16),
                  if (_errorMessage != null)
                    ErrorBanner(
                      title: 'Driver workspace unavailable',
                      message: _errorMessage!,
                      onRetry: _load,
                    ),
                  _VerifyPanel(
                    controller: _codeController,
                    isVerifying: _isVerifying,
                    onVerify: _verifyTicket,
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Assigned trips',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  if (_trips.isEmpty)
                    const _EmptyPanel(
                      icon: Icons.route_outlined,
                      title: 'No trips assigned',
                      subtitle: 'Trips assigned to the driver email will appear here.',
                    )
                  else
                    ..._trips.map(
                      (trip) => _TripCard(
                        trip: trip,
                        selected: trip.tripId == _selectedTrip?.tripId,
                        onTap: () => _selectTrip(trip),
                      ),
                    ),
                  const SizedBox(height: 18),
                  const Text(
                    'Passenger tickets',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  if (_selectedTrip == null)
                    const _EmptyPanel(
                      icon: Icons.confirmation_number_outlined,
                      title: 'Choose a trip',
                      subtitle: 'Select an assigned trip to see paid passenger tickets.',
                    )
                  else if (_tickets.isEmpty)
                    const _EmptyPanel(
                      icon: Icons.confirmation_number_outlined,
                      title: 'No tickets yet',
                      subtitle: 'Paid bookings for this trip will appear here.',
                    )
                  else
                    ..._tickets.map((ticket) => _TicketTile(ticket: ticket)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DriverHeader extends StatelessWidget {
  const _DriverHeader({required this.driver});

  final DriverProfile? driver;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.brandDeep, AppColors.brandVivid],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.badge_outlined, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  driver?.fullName ?? 'Driver profile',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${driver?.companyName ?? 'SecureMove'} • ${driver?.licenseNumber ?? 'License pending'}',
                  style: const TextStyle(color: Color(0xE8FFFFFF)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VerifyPanel extends StatelessWidget {
  const _VerifyPanel({
    required this.controller,
    required this.isVerifying,
    required this.onVerify,
  });

  final TextEditingController controller;
  final bool isVerifying;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Verify boarding',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Booking reference or ticket code',
              prefixIcon: Icon(Icons.qr_code_scanner_rounded),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: isVerifying ? null : onVerify,
            icon: isVerifying
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.verified_rounded),
            label: const Text('Verify ticket'),
          ),
        ],
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({
    required this.trip,
    required this.selected,
    required this.onTap,
  });

  final DriverTrip trip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final time = trip.departureTime == null
        ? 'Time pending'
        : DateFormat('EEE, d MMM • HH:mm').format(trip.departureTime!);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: _panelDecoration(
        border: selected ? AppColors.brandVivid : Colors.transparent,
      ),
      child: ListTile(
        onTap: onTap,
        leading: const Icon(Icons.directions_bus_filled_rounded),
        title: Text(
          trip.routeLabel,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '$time\n${trip.registrationNumber ?? 'Bus pending'} • ${trip.usedTicketCount}/${trip.ticketCount} boarded',
        ),
        isThreeLine: true,
        trailing: Text(
          trip.status,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _TicketTile extends StatelessWidget {
  const _TicketTile({required this.ticket});

  final DriverTicket ticket;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: _panelDecoration(),
      child: ListTile(
        leading: Icon(
          ticket.isUsed ? Icons.check_circle_rounded : Icons.confirmation_number_outlined,
          color: ticket.isUsed ? AppColors.successText : AppColors.brandPrimary,
        ),
        title: Text(
          ticket.passengerName,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '${ticket.seatNumber} • ${ticket.bookingReference ?? ticket.ticketNumber}',
        ),
        trailing: Text(
          ticket.status.toUpperCase(),
          style: TextStyle(
            color: ticket.isUsed ? AppColors.successText : AppColors.brandPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _panelDecoration(),
      child: Column(
        children: [
          Icon(icon, size: 40, color: AppColors.brandPrimary),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }
}

BoxDecoration _panelDecoration({Color border = Colors.transparent}) {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(24),
    border: Border.all(color: border, width: border == Colors.transparent ? 0 : 1.5),
    boxShadow: const [
      BoxShadow(
        color: Color(0x100F2554),
        blurRadius: 24,
        offset: Offset(0, 14),
      ),
    ],
  );
}
