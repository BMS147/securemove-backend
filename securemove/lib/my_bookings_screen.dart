import 'package:flutter/material.dart';

import 'booking_service.dart';
import 'theme/app_colors.dart';
import 'widgets/error_banner.dart';
import 'widgets/skeleton_card.dart';
import 'widgets/workspace_header.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const Column(
        children: [
          WorkspaceHeader(title: 'My bookings', subtitle: 'Tickets and trips'),
          Expanded(child: MyBookingsView()),
        ],
      ),
    );
  }
}

class MyBookingsView extends StatefulWidget {
  const MyBookingsView({super.key});

  @override
  State<MyBookingsView> createState() => _MyBookingsViewState();
}

class _MyBookingsViewState extends State<MyBookingsView> {
  late Future<List<BookingRecord>> _futureBookings;

  @override
  void initState() {
    super.initState();
    _futureBookings = BookingService.instance.getMyBookings();
  }

  Future<void> _refresh() async {
    final future = BookingService.instance.getMyBookings();
    if (mounted) setState(() => _futureBookings = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<BookingRecord>>(
      future: _futureBookings,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                SkeletonCard(height: 126),
                SizedBox(height: 12),
                SkeletonCard(height: 126),
                SizedBox(height: 12),
                SkeletonCard(height: 126),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: ErrorBanner(
              title: 'Could not load bookings',
              message: 'SecureMove API is waking up. Retry in a moment.',
              onRetry: _refresh,
            ),
          );
        }

        final bookings = snapshot.data ?? const <BookingRecord>[];
        if (bookings.isEmpty) {
          return _StateCard(
            icon: Icons.confirmation_number_outlined,
            title: 'No bookings yet',
            message:
                'Your confirmed and reserved trips will appear here once the backend starts returning live booking records.',
            actionLabel: 'Refresh',
            onPressed: _refresh,
          );
        }

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              final booking = bookings[index];
              final routeLabel =
                  booking.origin == null || booking.destination == null
                      ? 'Trip #${booking.tripId}'
                      : '${booking.origin} to ${booking.destination}';

              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            routeLabel,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        _StatusPill(label: booking.status),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if ((booking.companyName ?? '').isNotEmpty)
                      Text(
                        booking.companyName!,
                        style: const TextStyle(
                          color: Color(0xFF5E6C87),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if ((booking.departureTime ?? '').isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Departure: ${booking.departureTime}',
                        style: const TextStyle(color: Color(0xFF5E6C87)),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _DetailColumn(
                          label: 'Reference',
                          value: booking.bookingReference,
                        ),
                        _DetailColumn(
                          label: 'Amount',
                          value: booking.totalAmountLabel,
                        ),
                        _DetailColumn(
                          label: 'Booked',
                          value:
                              '${booking.createdAt.day}/${booking.createdAt.month}/${booking.createdAt.year}',
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final normalized = label.toLowerCase();
    final background = switch (normalized) {
      'paid' => const Color(0xFFEAFBF4),
      'reserved' => const Color(0xFFEFF4FF),
      'cancelled' => const Color(0xFFFFECE8),
      _ => const Color(0xFFF4F7FD),
    };
    final foreground = switch (normalized) {
      'paid' => const Color(0xFF237A50),
      'reserved' => const Color(0xFF2A54C6),
      'cancelled' => const Color(0xFFC44B2C),
      _ => const Color(0xFF5E6C87),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DetailColumn extends StatelessWidget {
  const _DetailColumn({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF7D8AA3),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
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
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF4FF),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(icon, color: const Color(0xFF2A54C6), size: 34),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF5E6C87),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: () {
                  onPressed();
                },
                child: Text(actionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
