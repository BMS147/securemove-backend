import 'package:flutter/material.dart';
import 'theme/app_colors.dart';

import 'company_service.dart';
import 'company_drivers_screen.dart';

class CompanyDashboardScreen extends StatefulWidget {
  const CompanyDashboardScreen({
    super.key,
    required this.company,
  });

  final CompanyRecord company;

  @override
  State<CompanyDashboardScreen> createState() => _CompanyDashboardScreenState();
}

class _CompanyDashboardScreenState extends State<CompanyDashboardScreen> {
  late Future<CompanyDashboard> _futureDashboard;

  @override
  void initState() {
    super.initState();
    _futureDashboard = CompanyService.instance.getDashboard(
      widget.company.companyId,
    );
  }

  Future<void> _refresh() async {
    final future = CompanyService.instance.getDashboard(
      widget.company.companyId,
    );
    setState(() => _futureDashboard = future);
    await future;
  }

  void _openDrivers() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CompanyDriversScreen(company: widget.company),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.company.name)),
      body: FutureBuilder<CompanyDashboard>(
        future: _futureDashboard,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _DashboardStateCard(
              title: 'Could not load dashboard',
              message: snapshot.error.toString(),
              actionLabel: 'Try again',
              onPressed: _refresh,
            );
          }

          final dashboard = snapshot.data;
          if (dashboard == null) {
            return _DashboardStateCard(
              title: 'No dashboard data',
              message: 'The backend did not return company statistics.',
              actionLabel: 'Refresh',
              onPressed: _refresh,
            );
          }

          final cards = [
            _Metric(label: 'Buses', value: '${dashboard.totalBuses}'),
            _Metric(label: 'Drivers', value: '${dashboard.totalDrivers}'),
            _Metric(label: 'Trips', value: '${dashboard.totalTrips}'),
            _Metric(label: 'Scheduled', value: '${dashboard.scheduledTrips}'),
            _Metric(label: 'Bookings', value: '${dashboard.totalBookings}'),
            _Metric(label: 'Revenue', value: dashboard.paidRevenueLabel),
          ];

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.brandDeep, AppColors.brandVivid],
                    ),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Operations dashboard',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'A company-management view modelled on the cloned repo structure. Use it to inspect fleet, driver, and booking activity.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.88),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: cards
                      .map(
                        (card) => SizedBox(
                          width: 165,
                          child: _MetricCard(metric: card),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 22),
                Container(
                  padding: const EdgeInsets.all(20),
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
                        'Quick actions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _openDrivers,
                          icon: const Icon(Icons.people_outline_rounded),
                          label: const Text('Manage drivers'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Metric {
  const _Metric({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});

  final _Metric metric;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
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
          Text(
            metric.label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            metric.value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardStateCard extends StatelessWidget {
  const _DashboardStateCard({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onPressed,
  });

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
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                  color: AppColors.textSecondary,
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
