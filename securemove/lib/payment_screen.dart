import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'booking_service.dart';
import 'bus.dart';
import 'mobile_money_service.dart';
import 'my_bookings_screen.dart';
import 'stripe_payment_service.dart';
import 'theme/app_colors.dart';
import 'ticket_screen.dart';
import 'widgets/error_banner.dart';
import 'widgets/workspace_header.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key, required this.bus});

  final Bus bus;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final MobileMoneyService _mobileMoney = MobileMoneyService.instance;
  final StripePaymentService _stripe = StripePaymentService.instance;
  bool _isProcessingCardPayment = false;
  bool _isProcessingMobileMoney = false;
  String? _processingMobileMoneyMethod;
  int? _activeBookingId;
  String? _activeBookingReference;
  MobileMoneyConfig? _mobileMoneyConfig;
  String? _mobileMoneyConfigError;
  DateTime _travelDate = DateTime.now();
  int _ticketCount = 1;

  @override
  void initState() {
    super.initState();
    _loadMobileMoneyConfig();
  }

  @override
  Widget build(BuildContext context) {
    final mobileMoneyAvailable = _mobileMoneyConfig?.hasAnyProvider == true;
    final methods = [
      if (mobileMoneyAvailable) ...[
        (
          title: 'MTN MoMo',
          subtitle: 'Pay from your MTN mobile money wallet',
          icon: Icons.phone_android_rounded,
          accent: AppColors.accentLight,
          enabled: _mobileMoneyConfig?.isMockMode == true ||
              _mobileMoneyConfig?.mtn.enabled == true,
        ),
        (
          title: 'Airtel Money',
          subtitle: 'Pay from your Airtel Money account',
          icon: Icons.sim_card_rounded,
          accent: const Color(0xFFFFF7E8),
          enabled: _mobileMoneyConfig?.isMockMode == true ||
              _mobileMoneyConfig?.airtel.enabled == true,
        ),
      ],
      (
        title: 'Credit / Debit Card',
        subtitle: _stripe.isReady
            ? 'Pay by card through Stripe'
            : 'Add your Stripe key to unlock card checkout',
        icon: Icons.credit_card_rounded,
        accent: const Color(0xFFEAFBF4),
        enabled: _stripe.isReady,
      ),
    ];

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(150),
          child: Column(
            children: [
              WorkspaceHeader(
                title: 'Tickets',
                subtitle: 'Book and ride securely',
                actionIcon: Icons.receipt_long_rounded,
                onAction: () {},
              ),
              const TabBar(
                tabs: [
                  Tab(
                    icon: Icon(Icons.confirmation_number_outlined),
                    text: 'Book',
                  ),
                  Tab(
                    icon: Icon(Icons.receipt_long_outlined),
                    text: 'My tickets',
                  ),
                ],
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
              children: [
                if (_mobileMoneyConfigError != null ||
                    _mobileMoneyConfig?.hasAnyProvider == false) ...[
                  const ErrorBanner(
                    title: 'Mobile money unavailable',
                    message:
                        'Mobile money temporarily unavailable, try again later.',
                  ),
                  const SizedBox(height: 14),
                ],
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.accent],
                    ),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Booking summary',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _SummaryRow(label: 'Operator', value: widget.bus.company),
                      _SummaryRow(
                        label: 'Route',
                        value:
                            '${widget.bus.origin} to ${widget.bus.destination}',
                      ),
                      _SummaryRow(label: 'Departure', value: widget.bus.time),
                      _SummaryRow(label: 'Travel date', value: _dateLabel),
                      _SummaryRow(
                        label: _ticketCount == 1 ? 'Ticket' : 'Tickets',
                        value: '$_ticketCount x ${widget.bus.price}',
                      ),
                      _SummaryRow(label: 'Total', value: _totalPriceLabel),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _TripDetailsCard(
                  travelDateLabel: _dateLabel,
                  ticketCount: _ticketCount,
                  maxTickets: _maxTickets,
                  onPickDate: _pickTravelDate,
                  onDecreaseTickets: _ticketCount > 1
                      ? () => _changeTicketCount(_ticketCount - 1)
                      : null,
                  onIncreaseTickets: _ticketCount < _maxTickets
                      ? () => _changeTicketCount(_ticketCount + 1)
                      : null,
                ),
                const SizedBox(height: 22),
                const Text(
                  'Payment methods',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                for (final method in methods)
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0A000000),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 8,
                      ),
                      enabled: method.enabled,
                      leading: Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: method.accent,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(
                          method.icon,
                          color: AppColors.accent,
                        ),
                      ),
                      title: Text(
                        method.title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          method.subtitle,
                          style: const TextStyle(height: 1.35),
                        ),
                      ),
                      trailing: _isProcessing(method.title)
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                              ),
                            )
                          : method.enabled
                              ? const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 18,
                                )
                              : const Icon(
                                  Icons.lock_outline_rounded,
                                  size: 18,
                                ),
                      onTap: () => _onMethodSelected(method.title),
                    ),
                  ),
              ],
            ),
            const MyBookingsView(),
          ],
        ),
      ),
    );
  }

  int get _maxTickets {
    final seats = widget.bus.effectiveSeatsLeft;
    if (seats < 1) {
      return 1;
    }

    return seats > 10 ? 10 : seats;
  }

  double get _bookingTotalAmount =>
      _priceToAmount(widget.bus.price) * _ticketCount;

  String get _totalPriceLabel => 'K${_bookingTotalAmount.toStringAsFixed(2)}';

  String get _dateLabel {
    final day = _travelDate.day.toString().padLeft(2, '0');
    final month = _travelDate.month.toString().padLeft(2, '0');
    return '$day/$month/${_travelDate.year}';
  }

  void _changeTicketCount(int value) {
    setState(() {
      _ticketCount = value.clamp(1, _maxTickets);
      _clearActiveBooking();
    });
  }

  Future<void> _pickTravelDate() async {
    final today = DateTime.now();
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _travelDate.isBefore(today) ? today : _travelDate,
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: today.add(const Duration(days: 365)),
    );

    if (selectedDate == null) {
      return;
    }

    setState(() {
      _travelDate = selectedDate;
      _clearActiveBooking();
    });
  }

  void _clearActiveBooking() {
    _activeBookingId = null;
    _activeBookingReference = null;
  }

  Future<void> _onMethodSelected(String method) async {
    if (_ticketCount < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose at least one ticket.')),
      );
      return;
    }

    if (method == 'MTN MoMo' || method == 'Airtel Money') {
      await _completeMobileMoneyPayment(method);
      return;
    }

    if (!_stripe.isReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_stripe.missingConfigurationMessage)),
      );
      return;
    }

    setState(() => _isProcessingCardPayment = true);

    try {
      await _reserveBookingIfAvailable();
      await _stripe.payForBus(
        widget.bus,
        amount: _bookingTotalAmount,
        ticketCount: _ticketCount,
        travelDate: _travelDate,
      );
      if (!mounted) {
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => TicketScreen(
            bus: widget.bus,
            bookingReference: _activeBookingReference,
            method: 'Stripe (test mode)',
            travelDate: _travelDate,
            ticketCount: _ticketCount,
          ),
        ),
      );
    } on PaymentException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessingCardPayment = false);
      }
    }
  }

  Future<void> _loadMobileMoneyConfig() async {
    try {
      final config = await _mobileMoney.getConfig();
      if (!mounted) {
        return;
      }
      setState(() {
        _mobileMoneyConfig = config;
        _mobileMoneyConfigError = null;
      });
    } on AuthException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _mobileMoneyConfigError = error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(
        () => _mobileMoneyConfigError =
            'Mobile money temporarily unavailable, try again later.',
      );
    }
  }

  bool _isProcessing(String method) {
    if (method == 'Credit / Debit Card') {
      return _isProcessingCardPayment;
    }

    if (method == 'MTN MoMo' || method == 'Airtel Money') {
      return _isProcessingMobileMoney && _processingMobileMoneyMethod == method;
    }

    return false;
  }

  Future<void> _completeMobileMoneyPayment(String method) async {
    final phoneNumber = await _collectMobileMoneyDetails(method);
    if (phoneNumber == null || !mounted) {
      return;
    }

    setState(() {
      _isProcessingMobileMoney = true;
      _processingMobileMoneyMethod = method;
    });

    _showMobileMoneyProcessingSheet(
      method: method,
      phoneNumber: phoneNumber,
    );

    try {
      final booking = await _ensureBooking();
      final initiated = await _mobileMoney.initiatePayment(
        bookingId: booking.bookingId,
        provider: method == 'MTN MoMo' ? 'mtn' : 'airtel',
        phoneNumber: phoneNumber,
        amount: booking.totalAmount,
      );
      final settled = await _waitForPaymentSettlement(initiated.payment.paymentId);
      if (!mounted) {
        return;
      }

      Navigator.of(context, rootNavigator: true).pop();

      if (settled.payment.isPending) {
        throw const PaymentException(
          'Payment is still pending approval. Please confirm the request on your phone and try again in a moment.',
        );
      }

      if (settled.payment.isFailed) {
        throw PaymentException(
          settled.message ??
              'Mobile money payment failed. Please check your wallet and try again.',
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${method == 'MTN MoMo' ? 'MTN MoMo' : method} payment approved. Your QR ticket is ready.',
          ),
        ),
      );

      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => TicketScreen(
            bus: widget.bus,
            bookingReference: booking.bookingReference,
            method: method,
            travelDate: _travelDate,
            ticketCount: _ticketCount,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingMobileMoney = false;
          _processingMobileMoneyMethod = null;
        });
      }
    }
  }

  Future<String?> _collectMobileMoneyDetails(String method) async {
    final controller = TextEditingController();
    String? validationMessage;

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> submit() async {
              final raw = controller.text.trim();
              final digitsOnly = raw.replaceAll(RegExp(r'[^0-9+]'), '');

              if (digitsOnly.length < 10) {
                setModalState(() {
                  validationMessage = 'Enter a valid mobile money number.';
                });
                return;
              }

              Navigator.of(sheetContext).pop(digitsOnly);
            }

            final bottomInset = MediaQuery.of(context).viewInsets.bottom;

            return Padding(
              padding: EdgeInsets.fromLTRB(18, 18, 18, bottomInset + 18),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      method,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Enter the number that should receive the approval prompt.',
                      style: TextStyle(
                        color: Colors.blueGrey.shade700,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: controller,
                      keyboardType: TextInputType.phone,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'Phone number',
                        hintText: method == 'MTN MoMo'
                            ? '0977 123 456'
                            : '0967 123 456',
                        errorText: validationMessage,
                        prefixIcon: const Icon(Icons.phone_iphone_rounded),
                      ),
                      onChanged: (_) {
                        if (validationMessage != null) {
                          setModalState(() => validationMessage = null);
                        }
                      },
                      onSubmitted: (_) => submit(),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: submit,
                            child: const Text('Continue'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    controller.dispose();
    return result;
  }

  void _showMobileMoneyProcessingSheet({
    required String method,
    required String phoneNumber,
  }) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x100F2554),
                  blurRadius: 28,
                  offset: Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF4FF),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(18),
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  '$method is processing',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Waiting for approval on $phoneNumber. This usually only takes a moment.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF5E6C87),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _reserveBookingIfAvailable() async {
    if (!widget.bus.hasLiveTripId || _activeBookingReference != null) {
      return;
    }

    await _ensureBooking();
  }

  Future<BookingRecord> _ensureBooking() async {
    if (_activeBookingId != null && _activeBookingReference != null) {
      return BookingRecord(
        bookingId: _activeBookingId!,
        tripId: widget.bus.tripId ?? 0,
        bookingReference: _activeBookingReference!,
        totalAmount: _bookingTotalAmount,
        status: 'reserved',
        createdAt: DateTime.now(),
      );
    }

    if (!widget.bus.hasLiveTripId) {
      throw const PaymentException(
        'This route is still schedule-only. Live mobile money requires a trip-backed search result.',
      );
    }

    final booking = await BookingService.instance.reserveBooking(
      tripId: widget.bus.tripId!,
      totalAmount: _bookingTotalAmount,
    );
    _activeBookingId = booking.bookingId;
    _activeBookingReference = booking.bookingReference;
    return booking;
  }

  Future<MobileMoneyResult> _waitForPaymentSettlement(int paymentId) async {
    MobileMoneyResult latest = await _mobileMoney.getPaymentStatus(paymentId);

    for (var attempt = 0; attempt < 7; attempt++) {
      if (!latest.payment.isPending) {
        return latest;
      }

      await Future<void>.delayed(const Duration(seconds: 2));
      latest = await _mobileMoney.getPaymentStatus(paymentId);
    }

    return latest;
  }

  double _priceToAmount(String rawPrice) {
    final cleaned = rawPrice.replaceAll(RegExp(r'[^0-9.,]'), '');
    final normalized = cleaned.contains(',') && !cleaned.contains('.')
        ? cleaned.replaceAll(',', '.')
        : cleaned.replaceAll(',', '');
    final parsed = double.tryParse(normalized);
    if (parsed == null) {
      throw PaymentException(
        'Could not convert the ticket price "$rawPrice" into a booking amount.',
      );
    }

    return parsed;
  }
}

class _TripDetailsCard extends StatelessWidget {
  const _TripDetailsCard({
    required this.travelDateLabel,
    required this.ticketCount,
    required this.maxTickets,
    required this.onPickDate,
    required this.onDecreaseTickets,
    required this.onIncreaseTickets,
  });

  final String travelDateLabel;
  final int ticketCount;
  final int maxTickets;
  final VoidCallback onPickDate;
  final VoidCallback? onDecreaseTickets;
  final VoidCallback? onIncreaseTickets;

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
            'Trip details',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: onPickDate,
            borderRadius: BorderRadius.circular(18),
            child: Ink(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FBFF),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFDCE6FA)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_month_rounded,
                    color: Color(0xFF2A54C6),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Travel date',
                          style: TextStyle(
                            color: Color(0xFF7D8AA3),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          travelDateLabel,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.edit_calendar_rounded,
                    color: Color(0xFF7D8AA3),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FBFF),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFDCE6FA)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.groups_2_rounded,
                  color: Color(0xFF2A54C6),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Passengers / tickets',
                        style: TextStyle(
                          color: Color(0xFF7D8AA3),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$ticketCount of $maxTickets available',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                _StepperButton(
                  icon: Icons.remove_rounded,
                  onPressed: onDecreaseTickets,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '$ticketCount',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                _StepperButton(
                  icon: Icons.add_rounded,
                  onPressed: onIncreaseTickets,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      onPressed: onPressed,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        fixedSize: const Size(40, 40),
        backgroundColor: const Color(0xFFEFF4FF),
        disabledBackgroundColor: const Color(0xFFF1F3F8),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xDFFFFFFF)),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
