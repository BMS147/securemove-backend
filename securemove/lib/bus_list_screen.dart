import 'package:flutter/material.dart';

import 'bus.dart';
import 'payment_screen.dart';
import 'route_service.dart';
import 'theme/app_colors.dart';

enum SortType { price, time }

class BusListScreen extends StatefulWidget {
  final String from;
  final String to;

  const BusListScreen({super.key, required this.from, required this.to});

  @override
  State<BusListScreen> createState() => _BusListScreenState();
}

class _BusListScreenState extends State<BusListScreen> {
  SortType _sort = SortType.price;
  late Future<List<Bus>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  Future<List<Bus>> _fetch() =>
      RouteService.instance.searchRoutes(from: widget.from, to: widget.to);

  void _reload() => setState(() => _future = _fetch());

  List<Bus> _sorted(List<Bus> raw) {
    final list = List<Bus>.from(raw);
    if (_sort == SortType.price) {
      list.sort((a, b) => _cents(a.price).compareTo(_cents(b.price)));
    } else {
      list.sort((a, b) => a.time.compareTo(b.time));
    }
    return list;
  }

  int _cents(String price) =>
      int.tryParse(price.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

  List<Bus> _deduplicate(List<Bus> raw) {
    final seen = <String>{};
    final unique = <Bus>[];

    for (final bus in raw) {
      final key = [
        bus.company,
        bus.origin,
        bus.destination,
        bus.time,
        bus.price,
        bus.durationMinutes.toString(),
        bus.effectiveSeatsLeft.toString(),
        bus.registrationNumber ?? '',
        bus.driverName ?? '',
        bus.driverPhone ?? '',
        bus.driverLicenseNumber ?? '',
        ...bus.features,
      ].map((value) => value.trim().toLowerCase()).join('|');

      if (seen.add(key)) {
        unique.add(bus);
      }
    }

    return unique;
  }

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
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Available buses',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              '${widget.from} → ${widget.to}',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
      body: FutureBuilder<List<Bus>>(
        future: _future,
        builder: (context, snapshot) {
          // ── Loading ──────────────────────────────────────────────────────
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // ── Error ────────────────────────────────────────────────────────
          if (snapshot.hasError) {
            return _ErrorState(
              message: snapshot.error.toString(),
              onRetry: _reload,
            );
          }

          final buses = _sorted(_deduplicate(snapshot.data ?? const []));

          // ── Empty ────────────────────────────────────────────────────────
          if (buses.isEmpty) {
            return _EmptyState(
              from: widget.from,
              to: widget.to,
              onRefresh: _reload,
            );
          }

          // ── List ─────────────────────────────────────────────────────────
          // ListView.builder is placed directly in Scaffold.body so it always
          // receives tight constraints from the viewport — no Expanded/Row
          // nesting that could leave slivers' parent data dirty.
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              itemCount: buses.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _SortBar(
                    current: _sort,
                    onChanged: (s) => setState(() => _sort = s),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _BusCard(bus: buses[index - 1]),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// ============================================================
// Sort bar
// ============================================================

class _SortBar extends StatelessWidget {
  const _SortBar({required this.current, required this.onChanged});

  final SortType current;
  final ValueChanged<SortType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          const Text(
            'Sort by:',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 10),
          _Chip(
            label: 'Cheapest',
            icon: Icons.attach_money_rounded,
            selected: current == SortType.price,
            onTap: () => onChanged(SortType.price),
          ),
          const SizedBox(width: 8),
          _Chip(
            label: 'Earliest',
            icon: Icons.schedule_rounded,
            selected: current == SortType.time,
            onTap: () => onChanged(SortType.time),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.brandPrimary : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.brandPrimary : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: selected ? AppColors.textOnBrand : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.textOnBrand : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Bus card
// ============================================================

class _BusCard extends StatelessWidget {
  const _BusCard({required this.bus});

  final Bus bus;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: const [AppColors.cardShadow],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row: icon + company + price ──────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.brandTint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.directions_bus_filled_rounded,
                  size: 26,
                  color: AppColors.brandPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bus.company,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${bus.origin} → ${bus.destination}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                bus.price,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.brandDeep,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 14),

          // ── Info row: departure · duration · seats ───────────────────────
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _InfoItem(
                icon: Icons.schedule_rounded,
                label: 'Departs',
                value: bus.time,
              ),
              _InfoItem(
                icon: Icons.timelapse_rounded,
                label: 'Duration',
                value: bus.formattedDuration,
              ),
              _InfoItem(
                icon: Icons.event_seat_rounded,
                label: 'Seats left',
                value: '${bus.effectiveSeatsLeft}',
              ),
              if (bus.registrationNumber != null)
                _InfoItem(
                  icon: Icons.confirmation_number_outlined,
                  label: 'Reg',
                  value: bus.registrationNumber!,
                ),
            ],
          ),

          if (bus.features.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: bus.features
                  .map(
                    (f) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.neutralTint,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        f,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],

          const SizedBox(height: 16),

          // ── Book button ──────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PaymentScreen(bus: bus)),
              ),
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text('Continue to payment'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandVivid,
                foregroundColor: AppColors.textOnBrand,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppColors.brandPrimary),
        const SizedBox(width: 5),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ============================================================
// Empty + error states
// ============================================================

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.from,
    required this.to,
    required this.onRefresh,
  });

  final String from;
  final String to;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.neutralTint,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.route_outlined,
                size: 40,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No buses found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No active schedules from $from to $to. Try a different route or check back later.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Refresh'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.brandPrimary,
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.dangerLight,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                size: 40,
                color: AppColors.dangerText,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Could not load routes',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandVivid,
                foregroundColor: AppColors.textOnBrand,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
