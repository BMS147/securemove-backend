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
    await _api.get('/admin/reports');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report generated')),
    );
  }

  Future<void> _logout() async {
    await AuthService.instance.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Breakpoints.isDesktop(context);

    return RoleGuard(
      allowedRoles: const {'super_admin'},
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: _loading
            ? const _AdminSkeleton()
            : SafeArea(
                child: Row(
                  children: [
                    _AdminSideNav(
                      selectedIndex: _index,
                      onSelected: (v) => setState(() => _index = v),
                      onLogout: _logout,
                      expanded: isDesktop,
                    ),
                    const VerticalDivider(
                      width: 1,
                      color: AppColors.border,
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _load,
                        child: ListView(
                          padding: EdgeInsets.fromLTRB(
                            isDesktop ? 32 : 16,
                            24,
                            isDesktop ? 32 : 16,
                            24,
                          ),
                          children: [
                            _TopBar(
                              section: _sectionName(),
                              onLogout: _logout,
                            ),
                            const SizedBox(height: 22),
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
                  ],
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
        LayoutBuilder(
          builder: (context, c) {
            final cols = c.maxWidth > 1000
                ? 4
                : c.maxWidth > 700
                    ? 2
                    : 1;
            final spacing = 16.0;
            final width = (c.maxWidth - spacing * (cols - 1)) / cols;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: kpis
                  .map((k) => SizedBox(width: width, child: k))
                  .toList(),
            );
          },
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
            onPressed: _generateReport,
            icon: const Icon(Icons.download_rounded),
            label: const Text('Generate report'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brandVivid,
              foregroundColor: AppColors.textOnBrand,
              padding: const EdgeInsets.symmetric(
                horizontal: 22,
                vertical: 14,
              ),
            ),
          ),
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

class _TopBar extends StatelessWidget {
  const _TopBar({required this.section, required this.onLogout});

  final String section;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Super Admin',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                section,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                ),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          onPressed: onLogout,
          icon: const Icon(Icons.logout_rounded),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.dangerLight,
            foregroundColor: AppColors.dangerText,
          ),
        ),
      ],
    );
  }
}

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
// Side nav
// ===========================================================================

class _AdminSideNav extends StatelessWidget {
  const _AdminSideNav({
    required this.selectedIndex,
    required this.onSelected,
    required this.onLogout,
    required this.expanded,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onLogout;
  final bool expanded;

  static const _items = [
    (icon: Icons.grid_view_rounded, label: 'Overview'),
    (icon: Icons.business_outlined, label: 'Companies'),
    (icon: Icons.people_outline, label: 'Users'),
    (icon: Icons.payments_outlined, label: 'Transactions'),
    (icon: Icons.security_outlined, label: 'Logs'),
    (icon: Icons.assessment_outlined, label: 'Reports'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: expanded ? 240 : 88,
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 18),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: AppColors.brandGradientShort,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    color: AppColors.textOnBrand,
                    size: 20,
                  ),
                ),
                if (expanded) ...[
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'SecureMove\nadmin',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                final selected = selectedIndex == index;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => onSelected(index),
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: EdgeInsets.symmetric(
                          horizontal: expanded ? 12 : 0,
                          vertical: expanded ? 11 : 12,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.brandTint
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: expanded
                            ? Row(
                                children: [
                                  Icon(
                                    item.icon,
                                    size: 20,
                                    color: selected
                                        ? AppColors.brandPrimary
                                        : AppColors.textMuted,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    item.label,
                                    style: TextStyle(
                                      color: selected
                                          ? AppColors.brandPrimary
                                          : AppColors.textSecondary,
                                      fontWeight: selected
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              )
                            : Tooltip(
                                message: item.label,
                                child: Column(
                                  children: [
                                    Icon(
                                      item.icon,
                                      color: selected
                                          ? AppColors.brandPrimary
                                          : AppColors.textMuted,
                                      size: 22,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      item.label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: selected
                                            ? AppColors.brandPrimary
                                            : AppColors.textSecondary,
                                        fontWeight: selected
                                            ? FontWeight.w800
                                            : FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          IconButton.filledTonal(
            onPressed: onLogout,
            icon: const Icon(Icons.logout_rounded),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.dangerLight,
              foregroundColor: AppColors.dangerText,
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Loading skeleton
// ===========================================================================

class _AdminSkeleton extends StatelessWidget {
  const _AdminSkeleton();

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                SkeletonCard(height: 88),
                SizedBox(height: 14),
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
        ),
      );
}
