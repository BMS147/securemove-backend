import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'company_drivers_screen.dart';
import 'company_schedules_screen.dart';
import 'company_service.dart';
import 'company_tickets_screen.dart';
import 'theme/app_colors.dart';
import 'theme/breakpoints.dart';
import 'widgets/design_system/app_card.dart';
import 'widgets/design_system/kpi_card.dart';
import 'widgets/design_system/state_card.dart';

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
      if (!mounted) return;
      setState(() {
        _companies = companies;
        _selectedCompany = selectedCompany;
        _dashboard = dashboard;
      });
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _changeCompany(CompanyRecord? company) async {
    if (company == null) return;
    setState(() {
      _selectedCompany = company;
      _isRefreshingDashboard = true;
      _errorMessage = null;
    });
    try {
      final dashboard = await _companyService.getDashboard(company.companyId);
      if (!mounted) return;
      setState(() => _dashboard = dashboard);
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _isRefreshingDashboard = false);
    }
  }

  Future<void> _openDrivers() async {
    final company = _selectedCompany;
    if (company == null) return;
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
    if (company == null) return;
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
    if (company == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CompanyTicketsScreen(company: company),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Breakpoints.isDesktop(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        title: const Text(
          'Management hub',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: Breakpoints.contentMaxWidth,
              ),
              child: _isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : _companies.isEmpty
                      ? const StateCard(
                          icon: Icons.domain_disabled_outlined,
                          title: 'No companies found',
                          message:
                              'Run the backend seed again so the management module has data to show.',
                        )
                      : ListView(
                          padding: EdgeInsets.fromLTRB(
                            isDesktop ? 32 : 20,
                            8,
                            isDesktop ? 32 : 20,
                            28,
                          ),
                          children: [
                            if (_errorMessage != null) ...[
                              _InfoBanner(message: _errorMessage!),
                              const SizedBox(height: 16),
                            ],
                            if (isDesktop)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(flex: 5, child: _heroCard()),
                                  const SizedBox(width: 20),
                                  Expanded(flex: 4, child: _actionsCard()),
                                ],
                              )
                            else ...[
                              _heroCard(),
                              const SizedBox(height: 18),
                              _actionsCard(),
                            ],
                            const SizedBox(height: 22),
                            _metricsGrid(),
                          ],
                        ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Hero card ───────────────────────────────────────────────────────────

  Widget _heroCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'COMPANY OVERVIEW',
            style: TextStyle(
              color: AppColors.textOnBrandSoft,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _dashboard?.company.name ?? _selectedCompany?.name ?? '',
            style: const TextStyle(
              color: AppColors.textOnBrand,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _isRefreshingDashboard
                ? 'Refreshing current metrics...'
                : 'Dashboard metrics for operations, fleet, and ticketing.',
            style: const TextStyle(
              color: AppColors.textOnBrandSoft,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: DropdownButtonHideUnderline(
              child: ButtonTheme(
                alignedDropdown: true,
                child: DropdownButton<int>(
                  value: _selectedCompany?.companyId,
                  dropdownColor: AppColors.surface,
                  isExpanded: true,
                  icon: const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textOnBrand,
                    ),
                  ),
                  style: const TextStyle(
                    color: AppColors.textOnBrand,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                  selectedItemBuilder: (_) => _companies
                      .map(
                        (c) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              c.name,
                              style: const TextStyle(
                                color: AppColors.textOnBrand,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  items: _companies
                      .map(
                        (company) => DropdownMenuItem<int>(
                          value: company.companyId,
                          child: Text(
                            company.name,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    final company = _companies
                        .where((c) => c.companyId == value)
                        .cast<CompanyRecord?>()
                        .firstOrNull;
                    _changeCompany(company);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Actions card ────────────────────────────────────────────────────────

  Widget _actionsCard() {
    return AppCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Management actions',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Manage drivers, pricing, schedules, and customer tickets.',
            style: TextStyle(
              color: AppColors.textSecondary,
              height: 1.45,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          _ActionTile(
            icon: Icons.badge_outlined,
            title: 'Drivers',
            subtitle: 'Roster, licenses, contact info',
            onTap: _openDrivers,
          ),
          const SizedBox(height: 10),
          _ActionTile(
            icon: Icons.payments_outlined,
            title: 'Schedules & pricing',
            subtitle: 'Routes, fares, and timetable',
            onTap: _openSchedules,
          ),
          const SizedBox(height: 10),
          _ActionTile(
            icon: Icons.confirmation_number_outlined,
            title: 'Customer tickets',
            subtitle: 'View paid tickets and lookups',
            onTap: _openTickets,
          ),
        ],
      ),
    );
  }

  // ── Metrics grid ────────────────────────────────────────────────────────

  Widget _metricsGrid() {
    final metrics = [
      KpiCard(
        label: 'Active buses',
        value: '${_dashboard?.totalBuses ?? 0}',
        icon: Icons.directions_bus_filled_outlined,
      ),
      KpiCard(
        label: 'Drivers',
        value: '${_dashboard?.totalDrivers ?? 0}',
        icon: Icons.badge_outlined,
        accentBg: AppColors.successTint,
        accentFg: AppColors.successText,
      ),
      KpiCard(
        label: 'Trips',
        value: '${_dashboard?.totalTrips ?? 0}',
        icon: Icons.alt_route_rounded,
        accentBg: AppColors.warningTint,
        accentFg: AppColors.warningText,
      ),
      KpiCard(
        label: 'Scheduled',
        value: '${_dashboard?.scheduledTrips ?? 0}',
        icon: Icons.schedule_rounded,
      ),
      KpiCard(
        label: 'Bookings',
        value: '${_dashboard?.totalBookings ?? 0}',
        icon: Icons.confirmation_number_outlined,
        accentBg: AppColors.successTint,
        accentFg: AppColors.successText,
      ),
      KpiCard(
        label: 'Paid revenue',
        value: 'ZMW ${(_dashboard?.paidRevenue ?? 0).toStringAsFixed(0)}',
        icon: Icons.payments_outlined,
        accentBg: AppColors.dangerLight,
        accentFg: AppColors.dangerText,
      ),
    ];

    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth > 900
          ? 3
          : c.maxWidth > 600
              ? 2
              : 1;
      const spacing = 14.0;
      final width = (c.maxWidth - spacing * (cols - 1)) / cols;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children:
            metrics.map((m) => SizedBox(width: width, child: m)).toList(),
      );
    });
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.brandTint,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.brandPrimary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.dangerLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.danger.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.dangerText),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.dangerText,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
