import 'dart:async';

import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'booking_service.dart';
import 'bus.dart';
import 'mobile_money_service.dart';
import 'stripe_payment_service.dart';
import 'theme/app_colors.dart';
import 'ticket_screen.dart';
import 'widgets/error_banner.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key, required this.bus});

  final Bus bus;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  // ── Trip configuration ─────────────────────────────────────────────────────
  DateTime _travelDate = DateTime.now();
  int _ticketCount = 1;

  // ── Processing state ───────────────────────────────────────────────────────
  bool _isProcessingCard = false;
  bool _isProcessingMobile = false;
  String? _activeMobileMethod;

  // ── Booking cache ──────────────────────────────────────────────────────────
  int? _activeBookingId;
  String? _activeBookingRef;

  // ── Mobile money config ────────────────────────────────────────────────────
  MobileMoneyConfig? _momoConfig;
  bool _momoLoading = true;
  String? _momoError;

  final _mobileMoney = MobileMoneyService.instance;
  final _stripe = StripePaymentService.instance;

  @override
  void initState() {
    super.initState();
    _loadMomoConfig();
  }

  // ── Derived helpers ────────────────────────────────────────────────────────

  int get _maxTickets => widget.bus.effectiveSeatsLeft.clamp(1, 10);

  double get _unitPrice {
    final cleaned = widget.bus.price.replaceAll(RegExp(r'[^0-9.,]'), '');
    final normalized = cleaned.contains(',') && !cleaned.contains('.')
        ? cleaned.replaceAll(',', '.')
        : cleaned.replaceAll(',', '');
    return double.tryParse(normalized) ?? 0;
  }

  double get _total => _unitPrice * _ticketCount;

  String get _totalLabel => 'K${_total.toStringAsFixed(2)}';

  String get _dateLabel {
    final d = _travelDate;
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year}';
  }

  bool _isMomoMethodEnabled(String method) {
    final cfg = _momoConfig;
    if (cfg == null) return false;
    if (cfg.isMockMode) return true;
    return method == 'MTN MoMo' ? cfg.mtn.enabled : cfg.airtel.enabled;
  }

  // ── Config loading ─────────────────────────────────────────────────────────

  Future<void> _loadMomoConfig() async {
    try {
      final cfg = await _mobileMoney.getConfig();
      if (!mounted) return;
      setState(() {
        _momoConfig = cfg;
        _momoLoading = false;
        _momoError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _momoLoading = false;
        _momoError = 'Mobile money temporarily unavailable.';
      });
    }
  }

  // ── Date / ticket helpers ──────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _travelDate.isBefore(today) ? today : _travelDate,
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: today.add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      _travelDate = picked;
      _clearBookingCache();
    });
  }

  void _adjustTickets(int delta) {
    final next = (_ticketCount + delta).clamp(1, _maxTickets);
    if (next == _ticketCount) return;
    setState(() {
      _ticketCount = next;
      _clearBookingCache();
    });
  }

  void _clearBookingCache() {
    _activeBookingId = null;
    _activeBookingRef = null;
  }

  // ── Payment entry points ───────────────────────────────────────────────────

  Future<void> _onPayWithCard() async {
    if (!_stripe.isReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_stripe.missingConfigurationMessage)),
      );
      return;
    }

    setState(() => _isProcessingCard = true);
    try {
      if (widget.bus.hasLiveTripId && _activeBookingRef == null) {
        await _ensureBooking();
      }
      await _stripe.payForBus(
        widget.bus,
        amount: _total,
        ticketCount: _ticketCount,
        travelDate: _travelDate,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => TicketScreen(
            bus: widget.bus,
            bookingReference: _activeBookingRef,
            method: 'Credit / Debit Card',
            travelDate: _travelDate,
            ticketCount: _ticketCount,
          ),
        ),
      );
    } on PaymentException catch (e) {
      if (!mounted) return;
      _showError(e.message);
    } catch (e) {
      if (!mounted) return;
      _showError('Card payment failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isProcessingCard = false);
    }
  }

  Future<void> _onPayWithMobile(String method) async {
    final phone = await _collectPhone(method);
    if (phone == null || !mounted) return;

    // Cancellation is coordinated via this Completer. The dialog's "Cancel"
    // button completes it, and the polling loop races against it so it exits
    // immediately instead of waiting out the next 2-second delay.
    final cancelSignal = Completer<void>();

    setState(() {
      _isProcessingMobile = true;
      _activeMobileMethod = method;
    });

    _showProcessingDialog(
      method: method,
      phone: phone,
      onCancel: () {
        if (!cancelSignal.isCompleted) cancelSignal.complete();
      },
    );

    try {
      final booking = await _ensureBooking();
      if (cancelSignal.isCompleted) return;

      final initiated = await _mobileMoney.initiatePayment(
        bookingId: booking.bookingId,
        provider: method == 'MTN MoMo' ? 'mtn' : 'airtel',
        phoneNumber: phone,
        amount: booking.totalAmount,
      );
      if (cancelSignal.isCompleted) return;

      final settled = await _pollUntilSettled(
        initiated.payment.paymentId,
        cancelSignal: cancelSignal,
      );
      if (!mounted || cancelSignal.isCompleted) return;

      // Dialog is still open — close it before navigating.
      Navigator.of(context, rootNavigator: true).pop();

      if (settled.payment.isPending) {
        throw const PaymentException(
          'No confirmation received. Please check your phone for the approval prompt and try again.',
        );
      }
      if (settled.payment.isFailed) {
        final reason = settled.message;
        throw PaymentException(
          reason != null && reason.isNotEmpty
              ? 'Payment failed: $reason'
              : 'Payment was declined. Check your wallet balance and try again.',
        );
      }

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
    } on AuthException catch (e) {
      if (!mounted || cancelSignal.isCompleted) return;
      _closeDialogSafely();
      _showError(e.message);
    } on PaymentException catch (e) {
      if (!mounted || cancelSignal.isCompleted) return;
      _closeDialogSafely();
      _showError(e.message);
    } catch (e) {
      if (!mounted || cancelSignal.isCompleted) return;
      _closeDialogSafely();
      _showError('Payment failed. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingMobile = false;
          _activeMobileMethod = null;
        });
      }
    }
  }

  // ── Booking helper ─────────────────────────────────────────────────────────

  Future<BookingRecord> _ensureBooking() async {
    if (_activeBookingId != null && _activeBookingRef != null) {
      return BookingRecord(
        bookingId: _activeBookingId!,
        tripId: widget.bus.tripId ?? 0,
        bookingReference: _activeBookingRef!,
        totalAmount: _total,
        status: 'reserved',
        createdAt: DateTime.now(),
      );
    }

    if (!widget.bus.hasLiveTripId) {
      throw const PaymentException(
        'This route is schedule-only and does not support mobile money yet. '
        'Please pay by card.',
      );
    }

    final booking = await BookingService.instance.reserveBooking(
      tripId: widget.bus.tripId!,
      totalAmount: _total,
    );
    _activeBookingId = booking.bookingId;
    _activeBookingRef = booking.bookingReference;
    return booking;
  }

  // ── Payment status polling ─────────────────────────────────────────────────

  Future<MobileMoneyResult> _pollUntilSettled(
    int paymentId, {
    required Completer<void> cancelSignal,
  }) async {
    var result = await _mobileMoney.getPaymentStatus(paymentId);

    // Poll up to 30 times × 4 s = 2 minutes. Mobile money approvals (especially
    // MTN USSD prompts) can take 30–60 s for the customer to respond.
    for (var i = 0; i < 30; i++) {
      if (!result.payment.isPending || cancelSignal.isCompleted) return result;

      // Race the wait against the cancel signal so cancellation is immediate.
      await Future.any([
        Future<void>.delayed(const Duration(seconds: 4)),
        cancelSignal.future,
      ]);

      if (cancelSignal.isCompleted) return result;

      result = await _mobileMoney.getPaymentStatus(paymentId);
    }

    return result;
  }

  // ── UI helpers ─────────────────────────────────────────────────────────────

  void _closeDialogSafely() {
    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        ),
      ),
    );
  }

  // ── Phone collection sheet ─────────────────────────────────────────────────

  Future<String?> _collectPhone(String method) async {
    final ctrl = TextEditingController();
    String? validationMsg;

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (_, setModal) {
            Future<void> submit() async {
              final digits = ctrl.text.trim().replaceAll(RegExp(r'[^0-9+]'), '');
              if (digits.length < 10) {
                setModal(() => validationMsg = 'Enter a valid mobile money number.');
                return;
              }
              Navigator.of(sheetCtx).pop(digits);
            }

            final inset = MediaQuery.of(sheetCtx).viewInsets.bottom;

            return Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, inset + 16),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: AppColors.brandTint,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.phone_iphone_rounded,
                            color: AppColors.brandPrimary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                method,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Enter the number to receive the approval prompt.',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  height: 1.35,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: ctrl,
                      keyboardType: TextInputType.phone,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'Phone number',
                        hintText: method == 'MTN MoMo' ? '0961 234 567' : '0971 234 567',
                        errorText: validationMsg,
                        prefixIcon: const Icon(Icons.phone_rounded),
                      ),
                      onChanged: (_) {
                        if (validationMsg != null) {
                          setModal(() => validationMsg = null);
                        }
                      },
                      onSubmitted: (_) => submit(),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(sheetCtx).pop(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textSecondary,
                              side: const BorderSide(color: AppColors.border),
                              minimumSize: const Size.fromHeight(52),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.brandVivid,
                              foregroundColor: AppColors.textOnBrand,
                              minimumSize: const Size.fromHeight(52),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              'Continue',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
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

    ctrl.dispose();
    return result;
  }

  // ── Processing dialog ──────────────────────────────────────────────────────

  void _showProcessingDialog({
    required String method,
    required String phone,
    required VoidCallback onCancel,
  }) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [AppColors.elevatedShadow],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.brandTint,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(18),
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: AppColors.brandPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Waiting for approval',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$method sent a prompt to $phone.\nApprove it on your phone to complete the payment.\n\nThis may take up to 2 minutes.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                const Divider(color: AppColors.border),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () {
                    onCancel();
                    Navigator.of(dialogCtx).pop();
                  },
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Cancel payment'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
          color: AppColors.textPrimary,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text(
              'Book ticket',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              'Review and pay',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: [
              _BusSummaryCard(bus: widget.bus),
              const SizedBox(height: 16),
              _TripDetailsCard(
                dateLabel: _dateLabel,
                ticketCount: _ticketCount,
                maxTickets: _maxTickets,
                onPickDate: _pickDate,
                onDecrease: _ticketCount > 1 ? () => _adjustTickets(-1) : null,
                onIncrease: _ticketCount < _maxTickets ? () => _adjustTickets(1) : null,
              ),
              const SizedBox(height: 16),
              _OrderTotalCard(
                ticketCount: _ticketCount,
                unitPrice: widget.bus.price,
                totalLabel: _totalLabel,
              ),
              const SizedBox(height: 20),
              _PaymentMethodsSection(
                momoLoading: _momoLoading,
                momoError: _momoError,
                momoConfig: _momoConfig,
                stripe: _stripe,
                isProcessingCard: _isProcessingCard,
                isProcessingMobile: _isProcessingMobile,
                activeMobileMethod: _activeMobileMethod,
                isMomoEnabled: _isMomoMethodEnabled,
                onPayWithCard: _onPayWithCard,
                onPayWithMobile: _onPayWithMobile,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Bus summary card
// ============================================================

class _BusSummaryCard extends StatelessWidget {
  const _BusSummaryCard({required this.bus});

  final Bus bus;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppColors.brandGradientShort,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.directions_bus_filled_rounded,
                  color: AppColors.textOnBrand,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bus.company,
                      style: const TextStyle(
                        color: AppColors.textOnBrand,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${bus.origin} → ${bus.destination}',
                      style: const TextStyle(
                        color: AppColors.textOnBrandSoft,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              _SummaryPill(
                icon: Icons.schedule_rounded,
                label: bus.time,
              ),
              const SizedBox(width: 10),
              _SummaryPill(
                icon: Icons.timelapse_rounded,
                label: bus.formattedDuration,
              ),
              const SizedBox(width: 10),
              _SummaryPill(
                icon: Icons.event_seat_rounded,
                label: '${bus.effectiveSeatsLeft} seats',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Price per ticket',
                style: TextStyle(
                  color: AppColors.textOnBrandSoft,
                  fontSize: 13,
                ),
              ),
              Text(
                bus.price,
                style: const TextStyle(
                  color: AppColors.textOnBrand,
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.textOnBrand),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textOnBrand,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Trip details card
// ============================================================

class _TripDetailsCard extends StatelessWidget {
  const _TripDetailsCard({
    required this.dateLabel,
    required this.ticketCount,
    required this.maxTickets,
    required this.onPickDate,
    required this.onDecrease,
    required this.onIncrease,
  });

  final String dateLabel;
  final int ticketCount;
  final int maxTickets;
  final VoidCallback onPickDate;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: const [AppColors.cardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Trip details',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          // Date picker
          InkWell(
            onTap: onPickDate,
            borderRadius: BorderRadius.circular(14),
            child: Ink(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.brandWash,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.brandBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month_rounded,
                      color: AppColors.brandPrimary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TRAVEL DATE',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          dateLabel,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.edit_calendar_rounded,
                      size: 18, color: AppColors.textMuted),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Ticket counter
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.brandWash,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.brandBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.groups_2_rounded,
                    color: AppColors.brandPrimary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PASSENGERS',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$ticketCount of $maxTickets available',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                _Stepper(icon: Icons.remove_rounded, onPressed: onDecrease),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    '$ticketCount',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                _Stepper(icon: Icons.add_rounded, onPressed: onIncrease),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      onPressed: onPressed,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        fixedSize: const Size(38, 38),
        backgroundColor: AppColors.brandTint,
        foregroundColor: AppColors.brandPrimary,
        disabledBackgroundColor: AppColors.neutralTint,
      ),
    );
  }
}

// ============================================================
// Order total card
// ============================================================

class _OrderTotalCard extends StatelessWidget {
  const _OrderTotalCard({
    required this.ticketCount,
    required this.unitPrice,
    required this.totalLabel,
  });

  final int ticketCount;
  final String unitPrice;
  final String totalLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.brandTint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.brandBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ORDER TOTAL',
                  style: TextStyle(
                    color: AppColors.brandPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$ticketCount × $unitPrice',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            totalLabel,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: AppColors.brandDeep,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Payment methods section
// ============================================================

class _PaymentMethodsSection extends StatelessWidget {
  const _PaymentMethodsSection({
    required this.momoLoading,
    required this.momoError,
    required this.momoConfig,
    required this.stripe,
    required this.isProcessingCard,
    required this.isProcessingMobile,
    required this.activeMobileMethod,
    required this.isMomoEnabled,
    required this.onPayWithCard,
    required this.onPayWithMobile,
  });

  final bool momoLoading;
  final String? momoError;
  final MobileMoneyConfig? momoConfig;
  final StripePaymentService stripe;
  final bool isProcessingCard;
  final bool isProcessingMobile;
  final String? activeMobileMethod;
  final bool Function(String method) isMomoEnabled;
  final VoidCallback onPayWithCard;
  final Future<void> Function(String method) onPayWithMobile;

  @override
  Widget build(BuildContext context) {
    final hasMomo = momoConfig?.hasAnyProvider == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choose payment method',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Select how you would like to pay for your ticket.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 14),

        // Mobile money unavailable banner
        if (momoError != null || (!momoLoading && !hasMomo))
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: ErrorBanner(
              title: 'Mobile money unavailable',
              message: momoError ??
                  'No mobile money providers are active right now.',
              onRetry: null,
            ),
          ),

        // While config is loading show a placeholder
        if (momoLoading) ...[
          _MethodTile(
            icon: Icons.phone_android_rounded,
            accent: AppColors.accentLight,
            title: 'MTN MoMo',
            subtitle: 'Checking availability…',
            loading: true,
            enabled: false,
            onTap: null,
          ),
          const SizedBox(height: 12),
          _MethodTile(
            icon: Icons.sim_card_rounded,
            accent: AppColors.warningTint,
            title: 'Airtel Money',
            subtitle: 'Checking availability…',
            loading: true,
            enabled: false,
            onTap: null,
          ),
          const SizedBox(height: 12),
        ],

        // Mobile money methods (shown once config is loaded)
        if (!momoLoading && hasMomo) ...[
          _MethodTile(
            icon: Icons.phone_android_rounded,
            accent: AppColors.accentLight,
            title: 'MTN MoMo',
            subtitle: isMomoEnabled('MTN MoMo')
                ? 'Pay from your MTN mobile money wallet'
                : 'MTN MoMo is not enabled on this account',
            enabled: isMomoEnabled('MTN MoMo') && !isProcessingMobile,
            loading: isProcessingMobile && activeMobileMethod == 'MTN MoMo',
            onTap: isMomoEnabled('MTN MoMo') && !isProcessingMobile
                ? () => onPayWithMobile('MTN MoMo')
                : null,
          ),
          const SizedBox(height: 12),
          _MethodTile(
            icon: Icons.sim_card_rounded,
            accent: AppColors.warningTint,
            title: 'Airtel Money',
            subtitle: isMomoEnabled('Airtel Money')
                ? 'Pay from your Airtel Money account'
                : 'Airtel Money is not enabled on this account',
            enabled: isMomoEnabled('Airtel Money') && !isProcessingMobile,
            loading: isProcessingMobile && activeMobileMethod == 'Airtel Money',
            onTap: isMomoEnabled('Airtel Money') && !isProcessingMobile
                ? () => onPayWithMobile('Airtel Money')
                : null,
          ),
          const SizedBox(height: 12),
        ],

        // Card payment
        _MethodTile(
          icon: Icons.credit_card_rounded,
          accent: AppColors.successTint,
          title: 'Credit / Debit Card',
          subtitle: stripe.isReady
              ? 'Pay securely by card via Stripe'
              : 'Add your Stripe key to enable card payments',
          enabled: stripe.isReady && !isProcessingCard && !isProcessingMobile,
          loading: isProcessingCard,
          onTap: stripe.isReady && !isProcessingCard && !isProcessingMobile
              ? onPayWithCard
              : null,
        ),
      ],
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.loading,
    required this.onTap,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final bool enabled;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: const [AppColors.cardShadow],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: AppColors.brandPrimary, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (loading)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: AppColors.brandPrimary,
                      ),
                    )
                  else if (enabled)
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: AppColors.textMuted,
                    )
                  else
                    const Icon(
                      Icons.lock_outline_rounded,
                      size: 16,
                      color: AppColors.textMuted,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
