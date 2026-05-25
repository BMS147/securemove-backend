import 'package:flutter/material.dart';
import 'theme/app_colors.dart';
import 'package:intl/intl.dart';

import 'auth_service.dart';
import 'company_service.dart';

class CompanyTicketsScreen extends StatefulWidget {
  const CompanyTicketsScreen({
    super.key,
    required this.company,
  });

  final CompanyRecord company;

  @override
  State<CompanyTicketsScreen> createState() => _CompanyTicketsScreenState();
}

class _CompanyTicketsScreenState extends State<CompanyTicketsScreen> {
  final CompanyService _companyService = CompanyService.instance;
  final TextEditingController _verifyController = TextEditingController();

  List<CompanyTicket> _tickets = const [];
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
    _verifyController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final tickets = await _companyService.getTickets(widget.company.companyId);
      if (!mounted) {
        return;
      }
      setState(() => _tickets = tickets);
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

  Future<void> _verifyTicket() async {
    final code = _verifyController.text.trim();
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
      final ticket = await _companyService.verifyTicket(code);
      _verifyController.clear();
      await _load();

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${ticket.passengerName} verified successfully.')),
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
      appBar: AppBar(title: Text('${widget.company.name} tickets')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
          children: [
            _VerifyPanel(
              controller: _verifyController,
              isVerifying: _isVerifying,
              onVerify: _verifyTicket,
            ),
            const SizedBox(height: 14),
            if (_errorMessage != null)
              _MessagePanel(message: _errorMessage!, isError: true),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_tickets.isEmpty)
              const _MessagePanel(
                message: 'No paid passenger tickets found for this company yet.',
                isError: false,
              )
            else
              ..._tickets.map((ticket) => _TicketCard(ticket: ticket)),
          ],
        ),
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x100F2554),
            blurRadius: 24,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Validate ticket',
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
            label: const Text('Validate'),
          ),
        ],
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket});

  final CompanyTicket ticket;

  @override
  Widget build(BuildContext context) {
    final departure = ticket.departureTime == null
        ? 'Departure pending'
        : DateFormat('EEE, d MMM • HH:mm').format(ticket.departureTime!);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x100F2554),
            blurRadius: 24,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            ticket.status == 'used'
                ? Icons.check_circle_rounded
                : Icons.confirmation_number_outlined,
            color: ticket.status == 'used'
                ? AppColors.successText
                : AppColors.brandPrimary,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ticket.passengerName,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  ticket.routeLabel,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$departure • ${ticket.driverName ?? 'Driver pending'}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  '${ticket.bookingReference ?? ticket.ticketNumber} • ${ticket.seatNumber}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Text(
            ticket.status.toUpperCase(),
            style: const TextStyle(
              color: AppColors.brandPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MessagePanel extends StatelessWidget {
  const _MessagePanel({
    required this.message,
    required this.isError,
  });

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isError ? AppColors.dangerLight : Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(message, style: const TextStyle(height: 1.35)),
    );
  }
}
