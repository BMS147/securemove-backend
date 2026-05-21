import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../auth_service.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/role_guard.dart';
import '../../widgets/skeleton_card.dart';
import '../../widgets/stats_card.dart';
import '../../widgets/workspace_header.dart';

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
  List<Map<String, dynamic>> _transactions = const [];
  List<Map<String, dynamic>> _logs = const [];
  String _roleFilter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final usersPath = _roleFilter == 'all' ? '/admin/users' : '/admin/users?role=$_roleFilter';
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
    return RoleGuard(
      allowedRoles: const {'super_admin'},
      child: Scaffold(
        body: _loading
            ? const _AdminSkeleton()
            : Row(
                children: [
                  _AdminSideNav(
                    selectedIndex: _index,
                    onSelected: (value) => setState(() => _index = value),
                    onLogout: _logout,
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: EdgeInsets.zero,
                        children: [
                          WorkspaceHeader(
                            title: 'Super Admin',
                            subtitle: 'System control',
                            actionIcon: Icons.logout_rounded,
                            onAction: _logout,
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            child: Column(
                              children: [
                                if (_error != null)
                                  ErrorBanner(
                                    title: 'Connection failed',
                                    message:
                                        'SecureMove API is waking up. Retry in a moment.',
                                    onRetry: _load,
                                  ),
                                _currentView(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _currentView() {
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
        return _dashboard();
    }
  }

  Widget _dashboard() {
    return Column(
      children: [
        _statsGrid([
          StatsCard(label: 'Total Companies', value: '${_stats['totalCompanies'] ?? 0}', icon: Icons.business),
          StatsCard(label: 'Total Users', value: '${_stats['totalUsers'] ?? 0}', icon: Icons.people),
          StatsCard(label: 'Total Bookings', value: '${_stats['totalBookings'] ?? 0}', icon: Icons.confirmation_number),
          StatsCard(label: 'System Revenue', value: 'ZMW ${_stats['revenue'] ?? 0}', icon: Icons.payments),
        ]),
        const SizedBox(height: 16),
        _companiesView(compact: true),
      ],
    );
  }

  Widget _companiesView({bool compact = false}) {
    final items = compact ? _companies.take(5).toList() : _companies;
    return _Panel(
      title: 'Companies',
      child: Column(
        children: items.map((company) {
          final approved = company['approval_status'] == 'approved';
          return ListTile(
            leading: Icon(approved ? Icons.verified_rounded : Icons.hourglass_top_rounded),
            title: Text('${company['name'] ?? 'Company'}'),
            subtitle: Text('Status: ${company['approval_status'] ?? 'pending'}'),
            trailing: approved
                ? const Text('Approved', style: TextStyle(fontWeight: FontWeight.w800))
                : FilledButton(
                    onPressed: () => _approveCompany(company['company_id']),
                    child: const Text('Approve'),
                  ),
          );
        }).toList(),
      ),
    );
  }

  Widget _usersView() {
    return _Panel(
      title: 'Users',
      trailing: DropdownButton<String>(
        value: _roleFilter,
        items: const [
          DropdownMenuItem(value: 'all', child: Text('All')),
          DropdownMenuItem(value: 'passenger', child: Text('Passenger')),
          DropdownMenuItem(value: 'company_admin', child: Text('Company')),
          DropdownMenuItem(value: 'conductor', child: Text('Conductor')),
          DropdownMenuItem(value: 'super_admin', child: Text('Admin')),
        ],
        onChanged: (value) {
          if (value == null) return;
          setState(() => _roleFilter = value);
          _load();
        },
      ),
      child: Column(
        children: _users.map((user) {
          return ListTile(
            title: Text('${user['name'] ?? user['email']}'),
            subtitle: Text('${user['email'] ?? ''}'),
            trailing: DropdownButton<String>(
              value: (user['role'] as String?) ?? 'passenger',
              items: const [
                DropdownMenuItem(value: 'passenger', child: Text('Passenger')),
                DropdownMenuItem(value: 'company_admin', child: Text('Company')),
                DropdownMenuItem(value: 'conductor', child: Text('Conductor')),
                DropdownMenuItem(value: 'super_admin', child: Text('Admin')),
              ],
              onChanged: (role) => role == null ? null : _updateRole(user['user_id'], role),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _transactionsView() => _Panel(
        title: 'Transactions',
        child: Column(
          children: _transactions
              .map((item) => ListTile(
                    title: Text('ZMW ${item['amount'] ?? 0} - ${item['status'] ?? 'pending'}'),
                    subtitle: Text('${item['company_name'] ?? 'Unknown company'} - ${_date(item['created_at'])}'),
                  ))
              .toList(),
        ),
      );

  Widget _logsView() => _Panel(
        title: 'Security Logs',
        child: Column(
          children: _logs
              .map((item) => ListTile(
                    leading: const Icon(Icons.shield_outlined),
                    title: Text('${item['event_type'] ?? 'event'} - ${item['status'] ?? ''}'),
                    subtitle: Text('${item['email'] ?? 'Unknown user'} - ${item['ip_address'] ?? 'No IP'} - ${_date(item['created_at'])}'),
                  ))
              .toList(),
        ),
      );

  Widget _reportsView() => _Panel(
        title: 'Reports',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Downloadable report data is available from /admin/reports.'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _generateReport,
              icon: const Icon(Icons.download_rounded),
              label: const Text('Generate report'),
            ),
          ],
        ),
      );

  Widget _statsGrid(List<Widget> cards) => LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth > 700 ? (constraints.maxWidth - 36) / 4 : (constraints.maxWidth - 12) / 2;
          return Wrap(spacing: 12, runSpacing: 12, children: cards.map((card) => SizedBox(width: width, child: card)).toList());
        },
      );

  List<Map<String, dynamic>> _list(dynamic value) => value is List ? value.whereType<Map<String, dynamic>>().toList() : const [];
  String _date(dynamic raw) => raw is String ? DateFormat('d MMM HH:mm').format(DateTime.tryParse(raw)?.toLocal() ?? DateTime.now()) : 'No date';
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child, this.trailing});
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))), if (trailing != null) trailing!]),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }
}

class _AdminSideNav extends StatelessWidget {
  const _AdminSideNav({
    required this.selectedIndex,
    required this.onSelected,
    required this.onLogout,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onLogout;

  static const _items = [
    (icon: Icons.grid_view_rounded, label: 'Dashboard'),
    (icon: Icons.business_outlined, label: 'Companies'),
    (icon: Icons.people_outline, label: 'Users'),
    (icon: Icons.payments_outlined, label: 'Transactions'),
    (icon: Icons.security_outlined, label: 'Logs'),
    (icon: Icons.assessment_outlined, label: 'Reports'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      padding: const EdgeInsets.fromLTRB(12, 22, 12, 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.shield_outlined, color: Colors.white),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: ListView.separated(
                itemCount: _items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = _items[index];
                  final selected = selectedIndex == index;
                  return Tooltip(
                    message: item.label,
                    child: InkWell(
                      onTap: () => onSelected(index),
                      borderRadius: BorderRadius.circular(16),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.accentLight
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              item.icon,
                              color: selected
                                  ? AppColors.accent
                                  : AppColors.textMuted,
                              size: 22,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item.label,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight:
                                    selected ? FontWeight.w800 : FontWeight.w600,
                                color: selected
                                    ? AppColors.accent
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
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
                backgroundColor: AppColors.accentLight,
                foregroundColor: AppColors.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
