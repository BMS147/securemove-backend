import 'package:flutter/material.dart';

import 'bus.dart';
import 'payment_screen.dart';
import 'route_service.dart';

enum SortType { price, time }

class BusListScreen extends StatefulWidget {
  final String from;
  final String to;

  const BusListScreen({super.key, required this.from, required this.to});

  @override
  State<BusListScreen> createState() => _BusListScreenState();
}

class _BusListScreenState extends State<BusListScreen> {
  SortType _currentSort = SortType.price;
  late Future<List<Bus>> _futureRoutes;

  @override
  void initState() {
    super.initState();
    _futureRoutes = _loadRoutes();
  }

  Future<List<Bus>> _loadRoutes() {
    return RouteService.instance.searchRoutes(
      from: widget.from,
      to: widget.to,
    );
  }

  Future<void> _refreshRoutes() async {
    final next = _loadRoutes();
    setState(() => _futureRoutes = next);
    await next;
  }

  // Parse price string like "K250" to int 250
  int _parsePrice(String priceStr) {
    return int.parse(priceStr.replaceAll(RegExp(r'[^0-9]'), ''));
  }

  // Parse time string like "10:00 AM" to minutes since midnight
  int _parseTimeToMinutes(String timeStr) {
    final parts = timeStr.split(' ');
    final timePart = parts[0]; // "10:00"
    final ampm = parts[1]; // "AM" or "PM"
    var timeComponents = timePart.split(':');
    int hour = int.parse(timeComponents[0]);
    int minute = int.parse(timeComponents[1]);
    if (ampm == 'PM' && hour != 12) hour += 12;
    if (ampm == 'AM' && hour == 12) hour = 0;
    return hour * 60 + minute;
  }

  // Get sorted list based on current sort type
  List<Bus> _sortedItems(List<Bus> routes) {
    final sorted = List<Bus>.from(routes);
    if (_currentSort == SortType.price) {
      sorted.sort((a, b) => _parsePrice(a.price).compareTo(_parsePrice(b.price)));
    } else if (_currentSort == SortType.time) {
      sorted.sort(
        (a, b) => _parseTimeToMinutes(a.time).compareTo(_parseTimeToMinutes(b.time)),
      );
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    const accents = [
      Color(0xFFEFF4FF),
      Color(0xFFFFF5E8),
      Color(0xFFEAFBF4),
      Color(0xFFF4E8FF),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Available buses',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(
              '${widget.from} to ${widget.to}',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF6C7894),
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _SortDropdown(
              currentSort: _currentSort,
              onSelected: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _currentSort = value;
                });
              },
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<Bus>>(
        future: _futureRoutes,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _BusStateCard(
              icon: Icons.cloud_off_rounded,
              title: 'Could not load routes',
              message: snapshot.error.toString(),
              actionLabel: 'Try again',
              onPressed: _refreshRoutes,
            );
          }

          final routes = snapshot.data ?? const <Bus>[];
          if (routes.isEmpty) {
            return _BusStateCard(
              icon: Icons.route_outlined,
              title: 'No scheduled buses found',
              message:
                  'SecureMove only allows booking real routes now. We could not find any active schedules from ${widget.from} to ${widget.to}.',
              actionLabel: 'Refresh',
              onPressed: _refreshRoutes,
            );
          }

          final sortedItems = _sortedItems(routes);

          return RefreshIndicator(
            onRefresh: _refreshRoutes,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: sortedItems.length,
              itemBuilder: (context, index) {
                final bus = sortedItems[index];
                final accentColor = accents[index % accents.length];

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(18),
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
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: accentColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(
                              Icons.directions_bus_filled_rounded,
                              size: 34,
                              color: Color(0xFF2048AC),
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
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Departs at ${bus.time}',
                                  style: const TextStyle(
                                    color: Color(0xFF6C7894),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF4FF),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    bus.formattedDuration,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF2B53C5),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (bus.seatAvailabilityLabel != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEAFBF4),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      bus.seatAvailabilityLabel!,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1F8C57),
                                      ),
                                    ),
                                  ),
                                if (bus.driverSummary != null) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF4F7FD),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      'Driver: ${bus.driverSummary!}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF5E6C87),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Text(
                            bus.price,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF17357E),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: bus.features
                              .map(
                                (feature) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF5F7FB),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    feature,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF60708E),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Icon(
                            Icons.timeline_rounded,
                            color: Color(0xFF3667F5),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              bus.registrationNumber == null
                                  ? 'Scheduled trip from ${bus.origin} to ${bus.destination} with digital check-in.'
                                  : 'Scheduled trip from ${bus.origin} to ${bus.destination} on bus ${bus.registrationNumber}.',
                              style: const TextStyle(
                                color: Color(0xFF6C7894),
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PaymentScreen(bus: bus),
                              ),
                            );
                          },
                          icon: const Icon(Icons.arrow_forward_rounded),
                          label: const Text('Continue to Payment'),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _SortDropdown extends StatelessWidget {
  const _SortDropdown({
    required this.currentSort,
    required this.onSelected,
  });

  final SortType currentSort;
  final ValueChanged<SortType?> onSelected;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x100F2554),
              blurRadius: 18,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButton<SortType>(
            value: currentSort,
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            borderRadius: BorderRadius.circular(16),
            style: const TextStyle(
              color: Color(0xFF15306B),
              fontWeight: FontWeight.w700,
            ),
            onChanged: onSelected,
            items: const [
              DropdownMenuItem(
                value: SortType.price,
                child: Text('Cheapest'),
              ),
              DropdownMenuItem(
                value: SortType.time,
                child: Text('Earliest'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BusStateCard extends StatelessWidget {
  const _BusStateCard({
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
