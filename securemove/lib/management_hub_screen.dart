import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'company_drivers_screen.dart';
import 'company_schedules_screen.dart';
import 'company_service.dart';
import 'company_tickets_screen.dart';

class ManagementHubScreen extends StatefulWidget {
  const ManagementHubScreen({super.key});

  @override
  State<ManagementHubScreen> createState() => _ManagementHubScreenState();
}

class _ManagementHubScreenState extends State<ManagementHubScreen> {
  final CompanyService _companyService = CompanyService.instance;

  List<CompanyRecord> _companies = const [];
  CompanyRecord? _selectedCompany;
  CompanyDashboard? _dashboard;
  bool _isLoading = true;
  bool _isRefreshingDashboard = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final companies = await _companyService.getCompanies();
      CompanyRecord? selectedCompany = _selectedCompany;
      if (companies.isNotEmpty) {
        selectedCompany = companies.firstWhere(
          (company) => company.companyId == _selectedCompany?.companyId,
          orElse: () => companies.first,
        );
      }

      CompanyDashboard? dashboard;
      if (selectedCompany != null) {
        dashboard =
            await _companyService.getDashboard(selectedCompany.companyId);
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _companies = companies;
        _selectedCompany = selectedCompany;
        _dashboard = dashboard;
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

  Future<void> _changeCompany(CompanyRecord? company) async {
    if (company == null) {
      return;
    }

    setState(() {
      _selectedCompany = company;
      _isRefreshingDashboard = true;
      _errorMessage = null;
    });

    try {
      final dashboard = await _companyService.getDashboard(company.companyId);
      if (!mounted) {
        return;
      }
      setState(() => _dashboard = dashboard);
    } on AuthException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) {
        setState(() => _isRefreshingDashboard = false);
      }
    }
  }

  Future<void> _openDrivers() async {
    final company = _selectedCompany;
    if (company == null) {
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CompanyDriversScreen(company: company),
      ),
    );

    await _changeCompany(company);
  }

  Future<void> _openSchedules() async {
    final company = _selectedCompany;
    if (company == null) {
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CompanySchedulesScreen(company: company),
      ),
    );

    await _changeCompany(company);
  }

  Future<void> _openTickets() async {
    final company = _selectedCompany;
    if (company == null) {
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CompanyTicketsScreen(company: company),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF3F7FD), Color(0xFFE8F0FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Management hub',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FutureBuilder<UserProfile?>(
                  future: AuthService.instance.getCurrentUserProfile(),
                  builder: (context, snapshot) {
                    final profile = snapshot.data;
                    return Text(
                      profile == null
                          ? 'Company operations view based on the cloned repo structure.'
                          : 'Signed in as ${profile.roleLabel}. This view uses the new backend company and driver endpoints.',
                      style: const TextStyle(
                        color: Color(0xFF60708E),
                        height: 1.4,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 18),
                if (_errorMessage != null)
                  _InfoBanner(
                    title: 'Backend response',
                    message: _errorMessage!,
                    tint: const Color(0xFFFFF1F1),
                    icon: Icons.error_outline_rounded,
                  ),
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_companies.isEmpty)
                  const _EmptyState(
                    title: 'No companies found',
                    subtitle:
                        'Run the backend seed again so the management module has data to show.',
                  )
                else ...[
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF17357E), Color(0xFF3868F3)],
                      ),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Company overview',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<int>(
                          value: _selectedCompany?.companyId,
                          dropdownColor: Colors.white,
                          decoration: InputDecoration(
                            labelText: 'Active company',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          items: _companies
                              .map(
                                (company) => DropdownMenuItem<int>(
                                  value: company.companyId,
                                  child: Text(company.name),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            final company = _companies
                                .where((item) => item.companyId == value)
                                .cast<CompanyRecord?>()
                                .firstOrNull;
                            _changeCompany(company);
                          },
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _dashboard?.company.name ??
                              _selectedCompany?.name ??
                              '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isRefreshingDashboard
                              ? 'Refreshing current metrics.'
                              : 'Dashboard metrics for operations, fleet, and ticketing.',
                          style: const TextStyle(
                            color: Color(0xE8FFFFFF),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _MetricCard(
                        label: 'Active buses',
                        value: '${_dashboard?.totalBuses ?? 0}',
                      ),
                      _MetricCard(
                        label: 'Drivers',
                        value: '${_dashboard?.totalDrivers ?? 0}',
                      ),
                      _MetricCard(
                        label: 'Trips',
                        value: '${_dashboard?.totalTrips ?? 0}',
                      ),
                      _MetricCard(
                        label: 'Scheduled',
                        value: '${_dashboard?.scheduledTrips ?? 0}',
                      ),
                      _MetricCard(
                        label: 'Bookings',
                        value: '${_dashboard?.totalBookings ?? 0}',
                      ),
                      _MetricCard(
                        label: 'Paid revenue',
                        value:
                            'ZMW ${(_dashboard?.paidRevenue ?? 0).toStringAsFixed(0)}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
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
                          'Management actions',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Manage company drivers, route pricing, active schedules, and paid customer tickets from the role-scoped backend.',
                          style: TextStyle(
                            color: Color(0xFF60708E),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 18),
                        ElevatedButton.icon(
                          onPressed: _openDrivers,
                          icon: const Icon(Icons.badge_outlined),
                          label: const Text('Open drivers'),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _openSchedules,
                          icon: const Icon(Icons.payments_outlined),
                          label: const Text('Manage prices'),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _openTickets,
                          icon: const Icon(Icons.confirmation_number_outlined),
                          label: const Text('View customer tickets'),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
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
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF60708E),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.title,
    required this.message,
    required this.tint,
    required this.icon,
  });

  final String title;
  final String message;
  final Color tint;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF284BA8)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFF5F6E88),
                    height: 1.35,
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.domain_disabled_outlined,
            size: 44,
            color: Color(0xFF284BA8),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF60708E),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
