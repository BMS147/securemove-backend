import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../auth_service.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/breakpoints.dart';
import '../../widgets/design_system/app_card.dart';
import '../../widgets/design_system/kpi_card.dart';
import '../../widgets/design_system/status_pill.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/role_guard.dart';
import '../../widgets/skeleton_card.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _api = ApiService.instance;
  int _index = 0;
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _stats = const {};
  List<Map<String, dynamic>> _companies = const [];
  List<Map<String, dynamic>> _users = const [];
  List<Map<String, dynamic>> _recentUsers = const [];
  List<Map<String, dynamic>> _recentBookings = const [];
  List<Map<String, dynamic>> _transactions = const [];
  List<Map<String, dynamic>> _logs = const [];
  String _roleFilter = 'all';
  bool _generatingReport = false;
  Map<String, dynamic>? _latestReport;
  final TextEditingController _userSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _userSearchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final search = Uri.encodeQueryComponent(_userSearchController.text.trim());
      final usersPath = '/admin/users?role=$_roleFilter&page=1&limit=20'
          '${search.isEmpty ? '' : '&search=$search'}';
      final results = await Future.wait([
        _api.get('/admin/dashboard'),
        _api.get('/admin/companies'),
        _api.get(usersPath),
        _api.get('/admin/transactions'),
        _api.get('/admin/security-logs'),
      ]);
      if (!mounted) return;
      setState(() {
        _stats = results[0]['stats'] as Map<String, dynamic>? ?? const {};
        _recentUsers = _list(results[0]['recentUsers']);
        _recentBookings = _list(results[0]['recentBookings']);
        _companies = _list(results[1]['companies']);
        _users = _list(results[2]['users']);
        _transactions = _list(results[3]['transactions']);
        _logs = _list(results[4]['logs']);
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _approveCompany(dynamic id) async {
    await _api.put('/admin/companies/$id/approve', {});
    await _load();
  }

  Future<void> _updateRole(dynamic id, String role) async {
    await _api.put('/admin/users/$id/role', {'role': role});
    await _load();
  }

  Future<void> _generateReport() async {
    setState(() => _generatingReport = true);
    try {
      final response = await _api.get('/admin/reports');
      final report = response['report'] as Map<String, dynamic>? ?? const {};
      if (!mounted) return;
      setState(() => _latestReport = report);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report generated')),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } finally {
      if (mounted) setState(() => _generatingReport = false);
    }
  }

  Future<void> _logout() async {
    await AuthService.instance.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
  }

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will need to sign in again to manage SecureMove.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: AppColors.textOnBrand,
            ),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await _logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Breakpoints.isDesktop(context);

    return RoleGuard(
      allowedRoles: const {'super_admin'},
      child: Scaffold(
        backgroundColor: AppColors.background,
        drawerScrimColor: Colors.black.withOpacity(0.48),
        drawer: _AdminDrawer(
          selectedIndex: _index,
          onSelected: (v) => setState(() => _index = v),
          onLogout: _confirmLogout,
        ),
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          centerTitle: false,
          leading: Builder(
            builder: (context) => IconButton(
              tooltip: 'Open menu',
              onPressed: () => Scaffold.of(context).openDrawer(),
              icon: const Icon(Icons.menu_rounded),
            ),
          ),
          title: Text(
            _sectionName(),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          actions: const [
            Padding(
              padding: EdgeInsets.only(right: 14),
              child: _NotificationDot(),
            ),
          ],
        ),
        body: _loading
            ? const _AdminSkeleton()
            : SafeArea(
                top: false,
                child: RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      isDesktop ? 32 : 16,
                      22,
                      isDesktop ? 32 : 16,
                      24,
                    ),
                    children: [
                      if (_error != null) ...[
                        ErrorBanner(
                          title: 'Connection failed',
                          message:
                              'SecureMove API is waking up. Retry in a moment.',
                          onRetry: _load,
                        ),
                        const SizedBox(height: 16),
                      ],
                      _currentView(isDesktop),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  String _sectionName() => switch (_index) {
        1 => 'Companies',
        2 => 'Users',
        3 => 'Transactions',
        4 => 'Security logs',
        5 => 'Reports',
        _ => 'Overview',
      };

  Widget _currentView(bool isDesktop) {
    switch (_index) {
      case 1:
        return _companiesView();
      case 2:
        return _usersView();
      case 3:
        return _transactionsView();
      case 4:
        return _logsView();
      case 5:
        return _reportsView();
      default:
        return _dashboard(isDesktop);
    }
  }

  Widget _dashboard(bool isDesktop) {
    final kpis = [
      KpiCard(
        label: 'Total companies',
        value: '${_stats['totalCompanies'] ?? 0}',
        icon: Icons.business_outlined,
      ),
      KpiCard(
        label: 'Total users',
        value: '${_stats['totalUsers'] ?? 0}',
        icon: Icons.people_alt_outlined,
        accentBg: AppColors.successTint,
        accentFg: AppColors.successText,
      ),
      KpiCard(
        label: 'Total bookings',
        value: '${_stats['totalBookings'] ?? 0}',
        icon: Icons.confirmation_number_outlined,
        accentBg: AppColors.warningTint,
        accentFg: AppColors.warningText,
      ),
      KpiCard(
        label: 'System revenue',
        value: 'ZMW ${_money(_stats['systemRevenue'])}',
        icon: Icons.payments_outlined,
        accentBg: AppColors.dangerLight,
        accentFg: AppColors.dangerText,
      ),
      KpiCard(
        label: 'Drivers',
        value: '${_stats['totalDrivers'] ?? 0}',
        icon: Icons.drive_eta_outlined,
      ),
      KpiCard(
        label: 'Conductors',
        value: '${_stats['totalConductors'] ?? 0}',
        icon: Icons.qr_code_scanner_rounded,
      ),
      KpiCard(
        label: 'Pending approvals',
        value: '${_stats['pendingCompanies'] ?? 0}',
        icon: Icons.hourglass_top_rounded,
        accentBg: AppColors.warningTint,
        accentFg: AppColors.warningText,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: kpis.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            mainAxisExtent: 156,
          ),
          itemBuilder: (context, index) => kpis[index],
        ),
        const SizedBox(height: 22),
        _recentActivityView(),
        const SizedBox(height: 6),
        _companiesView(compact: true),
      ],
    );
  }

  Widget _recentActivityView() {
    return _Panel(
      title: 'Recent activity',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_recentUsers.isEmpty && _recentBookings.isEmpty)
            _emptyText('No recent activity yet.'),
          ..._recentUsers.take(5).map((user) => _PanelRow(
                icon: Icons.person_add_alt_rounded,
                iconColor: AppColors.brandPrimary,
                iconBg: AppColors.brandTint,
                title: '${user['name'] ?? user['email'] ?? 'User'}',
                subtitle: '${user['role'] ?? 'user'} joined ${_date(user['created_at'])}',
              )),
          ..._recentBookings.take(5).map((booking) => _PanelRow(
                icon: Icons.confirmation_number_outlined,
                iconColor: AppColors.successText,
                iconBg: AppColors.successTint,
                title: '${booking['booking_reference'] ?? 'Booking'}',
                subtitle:
                    '${booking['passenger_name'] ?? 'Passenger'} - ${booking['origin'] ?? 'Origin'} to ${booking['destination'] ?? 'Destination'}',
              )),
        ],
      ),
    );
  }

  // ── Companies ───────────────────────────────────────────────────────────
  Widget _companiesView({bool compact = false}) {
    final items = compact ? _companies.take(5).toList() : _companies;
    return _Panel(
      title: compact ? 'Recently registered companies' : 'Companies',
      child: items.isEmpty
          ? _emptyText('No companies on file yet.')
          : Column(
              children: items.map((company) {
                final approved = company['approval_status'] == 'approved';
                return _PanelRow(
                  icon: approved
                      ? Icons.verified_rounded
                      : Icons.hourglass_top_rounded,
                  iconColor:
                      approved ? AppColors.successText : AppColors.warningText,
                  iconBg: approved
                      ? AppColors.successTint
                      : AppColors.warningTint,
                  title: '${company['name'] ?? 'Company'}',
                  subtitle:
                      '${company['owner_name'] ?? 'Owner pending'} - ${company['bus_count'] ?? 0} buses, ${company['route_count'] ?? 0} routes, ${company['driver_count'] ?? 0} drivers',
                  trailing: approved
                      ? const StatusPill(
                          label: 'Approved',
                          kind: StatusKind.success,
                        )
                      : FilledButton(
                          onPressed: () =>
                              _approveCompany(company['company_id']),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.brandVivid,
                            foregroundColor: AppColors.textOnBrand,
                          ),
                          child: const Text('Approve'),
                        ),
                );
              }).toList(),
            ),
    );
  }

  // ── Users ───────────────────────────────────────────────────────────────
  Widget _usersView() {
    return _Panel(
      title: 'Users',
      trailing: _RoleFilterMenu(
        value: _roleFilter,
        onChanged: (v) {
          if (v == null) return;
          setState(() => _roleFilter = v);
          _load();
        },
      ),
      child: Column(
        children: [
          TextField(
            controller: _userSearchController,
            decoration: InputDecoration(
              labelText: 'Search users',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                tooltip: 'Search',
                onPressed: _load,
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
            ),
            onSubmitted: (_) => _load(),
          ),
          const SizedBox(height: 14),
          _users.isEmpty
              ? _emptyText('No users match this filter.')
              : Column(
                  children: _users.map((user) {
                    return _PanelRow(
                      icon: Icons.person_outline_rounded,
                      iconColor: AppColors.brandPrimary,
                      iconBg: AppColors.brandTint,
                      title: '${user['name'] ?? user['email']}',
                      subtitle: '${user['email'] ?? ''} - joined ${_date(user['created_at'])}',
                      trailing: DropdownButton<String>(
                        value: (user['role'] as String?) ?? 'passenger',
                        underline: const SizedBox.shrink(),
                        items: const [
                          DropdownMenuItem(value: 'passenger', child: Text('Passenger')),
                          DropdownMenuItem(value: 'company_admin', child: Text('Company')),
                          DropdownMenuItem(value: 'driver', child: Text('Driver')),
                          DropdownMenuItem(value: 'conductor', child: Text('Conductor')),
                          DropdownMenuItem(value: 'super_admin', child: Text('Admin')),
                        ],
                        onChanged: (role) => role == null
                            ? null
                            : _updateRole(user['user_id'], role),
                      ),
                    );
                  }).toList(),
                ),
        ],
      ),
    );
  }

  // ── Transactions ────────────────────────────────────────────────────────
  Widget _transactionsView() {
    return _Panel(
      title: 'Transactions',
      child: _transactions.isEmpty
          ? _emptyText('No transactions yet.')
          : Column(
              children: _transactions.map((item) {
                final status = (item['status'] as String?) ?? 'pending';
                return _PanelRow(
                  icon: Icons.payments_outlined,
                  iconColor: AppColors.brandPrimary,
                  iconBg: AppColors.brandTint,
                  title: 'ZMW ${item['amount'] ?? 0}',
                  subtitle:
                      '${item['company_name'] ?? 'Unknown company'} • ${_date(item['created_at'])}',
                  trailing: StatusPill.fromLabel(status),
                );
              }).toList(),
            ),
    );
  }

  // ── Logs ────────────────────────────────────────────────────────────────
  Widget _logsView() {
    return _Panel(
      title: 'Security logs',
      child: _logs.isEmpty
          ? _emptyText('No events yet.')
          : Column(
              children: _logs.map((item) {
                final type = (item['event_type'] as String?) ?? 'event';
                final isFail = type == 'login_failed';
                final isAlert = type == 'fraud_alert';
                return _PanelRow(
                  icon: isAlert
                      ? Icons.warning_amber_rounded
                      : isFail
                          ? Icons.gpp_bad_rounded
                          : Icons.shield_outlined,
                  iconColor: isAlert
                      ? AppColors.warningText
                      : isFail
                          ? AppColors.dangerText
                          : AppColors.successText,
                  iconBg: isAlert
                      ? AppColors.warningTint
                      : isFail
                          ? AppColors.dangerLight
                          : AppColors.successTint,
                  title: '$type • ${item['status'] ?? ''}',
                  subtitle:
                      '${item['email'] ?? 'Unknown user'} • ${item['ip_address'] ?? 'No IP'} • ${_date(item['created_at'])}',
                );
              }).toList(),
            ),
    );
  }

  // ── Reports ─────────────────────────────────────────────────────────────
  Widget _reportsView() {
    return _Panel(
      title: 'Reports',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Generate a snapshot of revenue, bookings, and security events.',
            style: TextStyle(
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _generatingReport ? null : _generateReport,
            icon: _generatingReport
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_rounded),
            label: Text(_generatingReport ? 'Generating...' : 'Generate report'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brandVivid,
              foregroundColor: AppColors.textOnBrand,
              padding: const EdgeInsets.symmetric(
                horizontal: 22,
                vertical: 14,
              ),
            ),
          ),
          if (_latestReport != null) ...[
            const SizedBox(height: 18),
            _GeneratedReportCard(report: _latestReport!),
          ],
        ],
      ),
    );
  }

  Widget _emptyText(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Text(
          text,
          style: const TextStyle(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
      );

  List<Map<String, dynamic>> _list(dynamic value) => value is List
      ? value.whereType<Map<String, dynamic>>().toList()
      : const [];

  String _date(dynamic raw) => raw is String
      ? DateFormat('d MMM HH:mm')
          .format(DateTime.tryParse(raw)?.toLocal() ?? DateTime.now())
      : 'No date';

  String _money(dynamic raw) {
    if (raw is num) return raw.toStringAsFixed(2);
    if (raw is String) return (num.tryParse(raw) ?? 0).toStringAsFixed(2);
    return '0.00';
  }
}

// ===========================================================================
// Layout pieces
// ===========================================================================

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: AppCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _PanelRow extends StatelessWidget {
  const _PanelRow({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class _GeneratedReportCard extends StatelessWidget {
  const _GeneratedReportCard({required this.report});

  final Map<String, dynamic> report;

  @override
  Widget build(BuildContext context) {
    final generatedAt = _formatDate(report['generatedAt']);
    final reportId = '${report['reportId'] ?? 'SECUREMOVE-REPORT'}';
    final revenue = _formatMoney(report['revenue']);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.brandWash,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.brandBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.accentLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.description_outlined,
                  color: AppColors.accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reportId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Generated $generatedAt',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ReportMetric(
                label: 'Companies',
                value: '${report['totalCompanies'] ?? 0}',
              ),
              _ReportMetric(
                label: 'Users',
                value: '${report['totalUsers'] ?? 0}',
              ),
              _ReportMetric(
                label: 'Bookings',
                value: '${report['totalBookings'] ?? 0}',
              ),
              _ReportMetric(
                label: 'Revenue',
                value: 'ZMW $revenue',
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatDate(dynamic raw) {
    if (raw is! String) return 'just now';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return 'just now';
    return DateFormat('d MMM y, HH:mm').format(parsed.toLocal());
  }

  static String _formatMoney(dynamic raw) {
    if (raw is num) return raw.toStringAsFixed(2);
    if (raw is String) return (num.tryParse(raw) ?? 0).toStringAsFixed(2);
    return '0.00';
  }
}

class _ReportMetric extends StatelessWidget {
  const _ReportMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 132,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleFilterMenu extends StatelessWidget {
  const _RoleFilterMenu({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButton<String>(
        value: value,
        underline: const SizedBox.shrink(),
        items: const [
          DropdownMenuItem(value: 'all', child: Text('All')),
          DropdownMenuItem(value: 'passenger', child: Text('Passenger')),
          DropdownMenuItem(value: 'company_admin', child: Text('Company')),
          DropdownMenuItem(value: 'driver', child: Text('Driver')),
          DropdownMenuItem(value: 'conductor', child: Text('Conductor')),
          DropdownMenuItem(value: 'super_admin', child: Text('Admin')),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

// ===========================================================================
// Drawer nav
// ===========================================================================

class _AdminDrawer extends StatelessWidget {
  const _AdminDrawer({
    required this.selectedIndex,
    required this.onSelected,
    required this.onLogout,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onLogout;

  static const _items = [
    (icon: Icons.grid_view_rounded, label: 'Overview'),
    (icon: Icons.business_outlined, label: 'Companies'),
    (icon: Icons.people_outline, label: 'Users'),
    (icon: Icons.payments_outlined, label: 'Transactions'),
    (icon: Icons.security_outlined, label: 'Logs'),
    (icon: Icons.assessment_outlined, label: 'Reports'),
  ];

  static const _navy = Color(0xFF071225);
  static const _drawerText = Color(0xFFE5E7EB);
  static const _drawerMuted = Color(0xFF94A3B8);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return Drawer(
      width: width < 420 ? width * 0.86 : 340,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(
          right: Radius.circular(30),
        ),
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: _navy,
          borderRadius: BorderRadius.horizontal(
            right: Radius.circular(30),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 24),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          gradient: AppColors.brandGradientShort,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x553564F2),
                              blurRadius: 24,
                              offset: Offset(0, 12),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.shield_outlined,
                          color: AppColors.textOnBrand,
                          size: 23,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SecureMove',
                              style: TextStyle(
                                color: _drawerText,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Admin Console',
                              style: TextStyle(
                                color: _drawerMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final selected = selectedIndex == index;
                      return _AdminDrawerItem(
                        icon: item.icon,
                        label: item.label,
                        selected: selected,
                        onTap: () {
                          Navigator.pop(context);
                          onSelected(index);
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0x1FFFFFFF)),
                const SizedBox(height: 14),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      onLogout();
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x18EF4444),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0x30EF4444)),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.logout_rounded,
                            color: Color(0xFFFCA5A5),
                            size: 21,
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Sign out',
                            style: TextStyle(
                              color: Color(0xFFFCA5A5),
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              letterSpacing: 0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminDrawerItem extends StatelessWidget {
  const _AdminDrawerItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.ease,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: selected ? AppColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? const Color(0x665B6EF5) : Colors.transparent,
            ),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x334F46E5),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected ? AppColors.textOnBrand : _AdminDrawer._drawerMuted,
                size: 21,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected
                        ? AppColors.textOnBrand
                        : _AdminDrawer._drawerText,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                    fontSize: 14,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationDot extends StatelessWidget {
  const _NotificationDot();

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: 'Notifications',
          onPressed: () {},
          icon: const Icon(Icons.notifications_none_rounded),
        ),
        Positioned(
          right: 13,
          top: 13,
          child: Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: AppColors.danger,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.surface, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

// ===========================================================================
// Loading skeleton
// ===========================================================================

class _AdminSkeleton extends StatelessWidget {
  const _AdminSkeleton();

  @override
  Widget build(BuildContext context) => const SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: SkeletonCard(height: 132)),
                  SizedBox(width: 12),
                  Expanded(child: SkeletonCard(height: 132)),
                ],
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: SkeletonCard(height: 132)),
                  SizedBox(width: 12),
                  Expanded(child: SkeletonCard(height: 132)),
                ],
              ),
              SizedBox(height: 14),
              SkeletonCard(height: 260),
            ],
          ),
        ),
      );
}
