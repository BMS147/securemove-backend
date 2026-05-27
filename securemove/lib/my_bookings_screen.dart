import 'package:flutter/material.dart';

import 'booking_service.dart';
import 'theme/app_colors.dart';
import 'theme/breakpoints.dart';
import 'widgets/design_system/app_card.dart';
import 'widgets/design_system/state_card.dart';
import 'widgets/design_system/status_pill.dart';
import 'widgets/error_banner.dart';
import 'widgets/skeleton_card.dart';
import 'widgets/workspace_header.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key, this.embedded = false});

  /// When true, the screen is a tab inside [TravelerShell]. We omit the
  /// back-button affordance on the header.
  final bool embedded;

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          WorkspaceHeader(
            title: 'My bookings',
            subtitle: widget.embedded
                ? 'Tickets and upcoming trips'
                : 'Tickets and trips',
          ),
          const Expanded(child: MyBookingsView()),
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
  String _filter = 'all';

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

  List<BookingRecord> _applyFilter(List<BookingRecord> all) {
    if (_filter == 'all') return all;
    return all
        .where((b) => b.status.toLowerCase() == _filter.toLowerCase())
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Breakpoints.isDesktop(context);

    return FutureBuilder<List<BookingRecord>>(
      future: _futureBookings,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _LoadingState(isDesktop: isDesktop);
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
          return StateCard(
            icon: Icons.confirmation_number_outlined,
            title: 'No bookings yet',
            message:
                'Your confirmed and reserved trips will appear here once you book your first ride.',
            actionLabel: 'Refresh',
            onAction: _refresh,
          );
        }

        // Status counts for the filter strip
        final counts = <String, int>{'all': bookings.length};
        for (final b in bookings) {
          counts[b.status.toLowerCase()] =
              (counts[b.status.toLowerCase()] ?? 0) + 1;
        }
        final filtered = _applyFilter(bookings);

        return RefreshIndicator(
          onRefresh: _refresh,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: Breakpoints.contentMaxWidth,
              ),
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      isDesktop ? 32 : 18,
                      8,
                      isDesktop ? 32 : 18,
                      14,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: _FilterStrip(
                        current: _filter,
                        counts: counts,
                        onChanged: (v) => setState(() => _filter = v),
                      ),
                    ),
                  ),
                  if (isDesktop)
                    SliverPadding(
                      padding:
                          const EdgeInsets.fromLTRB(32, 0, 32, 24),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 460,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          mainAxisExtent: 230,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _BookingCard(
                            booking: filtered[index],
                          ),
                          childCount: filtered.length,
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                      sliver: SliverList.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _BookingCard(booking: filtered[index]),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ===========================================================================
// Filter strip — all / paid / reserved / cancelled
// ===========================================================================

class _FilterStrip extends StatelessWidget {
  const _FilterStrip({
    required this.current,
    required this.counts,
    required this.onChanged,
  });

  final String current;
  final Map<String, int> counts;
  final ValueChanged<String> onChanged;

  static const _options = [
    ('all', 'All'),
    ('paid', 'Paid'),
    ('reserved', 'Reserved'),
    ('cancelled', 'Cancelled'),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (value, label) in _options) ...[
            _FilterChip(
              label: '$label (${counts[value] ?? 0})',
              selected: current == value,
              onTap: () => onChanged(value),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? AppColors.brandPrimary : AppColors.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppColors.brandPrimary : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.textOnBrand : AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Booking card
// ===========================================================================

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking});

  final BookingRecord booking;

  @override
  Widget build(BuildContext context) {
    final routeLabel =
        booking.origin == null || booking.destination == null
            ? 'Trip #${booking.tripId}'
            : '${booking.origin} → ${booking.destination}';

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  routeLabel,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              StatusPill.fromLabel(booking.status),
            ],
          ),
          if ((booking.companyName ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              booking.companyName!,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
          if ((booking.departureTime ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  size: 14,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  booking.departureTime!,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
          // A fixed gap instead of Spacer() — Spacer is a flex widget that
          // requires a bounded height, but inside SliverList the Column's
          // height is unconstrained, producing a "non-zero flex but incoming
          // height constraints are unbounded" layout error.
          const SizedBox(height: 12),
          const Divider(height: 24, color: AppColors.border),
          Row(
            children: [
              Expanded(
                child: _DetailColumn(
                  label: 'Reference',
                  value: booking.bookingReference,
                ),
              ),
              Expanded(
                child: _DetailColumn(
                  label: 'Amount',
                  value: booking.totalAmountLabel,
                ),
              ),
              Expanded(
                child: _DetailColumn(
                  label: 'Booked',
                  value:
                      '${booking.createdAt.day}/${booking.createdAt.month}/${booking.createdAt.year}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailColumn extends StatelessWidget {
  const _DetailColumn({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            fontSize: 13,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ===========================================================================
// Loading skeleton
// ===========================================================================

class _LoadingState extends StatelessWidget {
  const _LoadingState({required this.isDesktop});

  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    if (isDesktop) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 2,
          children: const [
            SkeletonCard(height: 200),
            SkeletonCard(height: 200),
            SkeletonCard(height: 200),
            SkeletonCard(height: 200),
          ],
        ),
      );
    }
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
}
