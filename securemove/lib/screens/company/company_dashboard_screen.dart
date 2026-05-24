import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../auth_service.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/breakpoints.dart';
import '../../widgets/design_system/app_card.dart';
import '../../widgets/design_system/kpi_card.dart';
import '../../widgets/design_system/state_card.dart';
import '../../widgets/design_system/status_pill.dart';
import '../../widgets/role_guard.dart';

class CompanyOperatorWorkspaceScreen extends StatefulWidget {
  const CompanyOperatorWorkspaceScreen({super.key});

  @override
  State<CompanyOperatorWorkspaceScreen> createState() =>
      _CompanyOperatorWorkspaceScreenState();
}

class _CompanyOperatorWorkspaceScreenState
    extends State<CompanyOperatorWorkspaceScreen> {
  final _api = ApiService.instance;
  int _section = 0; // 0 overview, 1 buses, 2 routes, 3 schedules, 4 staff, 5 bookings
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _company = const {};
  Map<String, dynamic> _stats = const {};
  List<Map<String, dynamic>> _buses = const [];
  List<Map<String, dynamic>> _routes = const [];
  List<Map<String, dynamic>> _schedules = const [];
  List<Map<String, dynamic>> _staff = const [];
  List<Map<String, dynamic>> _bookings = const [];

  static const _sections = [
    (icon: Icons.grid_view_rounded, label: 'Overview'),
    (icon: Icons.directions_bus_filled_outlined, label: 'Buses'),
    (icon: Icons.alt_route_rounded, label: 'Routes'),
    (icon: Icons.schedule_rounded, label: 'Schedules'),
    (icon: Icons.badge_outlined, label: 'Staff'),
    (icon: Icons.confirmation_number_outlined, label: 'Bookings'),
  ];

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
      final results = await Future.wait([
        _api.get('/company/dashboard'),
        _api.get('/company/buses'),
        _api.get('/company/routes'),
        _api.get('/company/schedules'),
        _api.get('/company/staff'),
        _api.get('/company/bookings'),
      ]);
      if (!mounted) return;
      setState(() {
        _company = results[0]['company'] as Map<String, dynamic>? ?? const {};
        _stats = results[0]['stats'] as Map<String, dynamic>? ?? const {};
        _buses = _list(results[1]['buses']);
        _routes = _list(results[2]['routes']);
        _schedules = _list(results[3]['schedules']);
        _staff = _list(results[4]['staff']);
        _bookings = _list(results[5]['bookings']);
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
      allowedRoles: const {'company_admin'},
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: Row(
                  children: [
                    _SideNav(
                      sections: _sections,
                      selected: _section,
                      expanded: isDesktop,
                      onSelected: (i) => setState(() => _section = i),
                      onLogout: _logout,
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
                            22,
                            isDesktop ? 32 : 16,
                            32,
                          ),
                          children: [
                            _header(),
                            const SizedBox(height: 22),
                            if (_error != null) ...[
                              _ErrorBanner(message: _error!),
                              const SizedBox(height: 14),
                            ],
                            _currentSection(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        floatingActionButton: _section >= 1 && _section <= 4
            ? FloatingActionButton.extended(
                onPressed: _showCreateForm,
                backgroundColor: AppColors.brandVivid,
                foregroundColor: AppColors.textOnBrand,
                icon: const Icon(Icons.add_rounded),
                label: Text('New ${_sections[_section].label.toLowerCase()}'),
              )
            : null,
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────

  Widget _header() {
    final approved = _company['approval_status'] == 'approved';
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_company['name'] ?? 'Company'}',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  StatusPill(
                    label: approved ? 'Approved' : 'Pending review',
                    kind: approved ? StatusKind.success : StatusKind.warning,
                    icon: approved
                        ? Icons.verified_rounded
                        : Icons.pending_actions_rounded,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _sections[_section].label,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Sections ────────────────────────────────────────────────────────────

  Widget _currentSection() {
    switch (_section) {
      case 1:
        return _entityTable(
          _buses,
          ['Plate', 'Capacity', 'Type'],
          ['registration_number', 'capacity', 'type'],
          Icons.directions_bus_filled_rounded,
          _deleteBus,
        );
      case 2:
        return _entityTable(
          _routes,
          ['Origin', 'Destination', 'Price'],
          ['origin', 'destination', 'price'],
          Icons.alt_route_rounded,
          _deleteRoute,
        );
      case 3:
        return _entityTable(
          _schedules,
          ['Origin → Destination', 'Departure', 'Bus'],
          ['origin', 'departure_time', 'bus'],
          Icons.schedule_rounded,
          _deleteSchedule,
          dateColumn: 1,
          routeColumn: 0,
        );
      case 4:
        return _entityTable(
          _staff,
          ['Name', 'Email', 'Role'],
          ['full_name', 'email', 'role'],
          Icons.badge_outlined,
          _deleteStaff,
        );
      case 5:
        return _entityTable(
          _bookings,
          ['Reference', 'Passenger', 'Status'],
          ['booking_reference', 'passenger_name', 'status'],
          Icons.confirmation_number_outlined,
          null,
          pillColumn: 2,
        );
      default:
        return _overview();
    }
  }

  Widget _overview() {
    final kpis = [
      KpiCard(
        label: 'Active buses',
        value: '${_stats['activeBuses'] ?? 0}',
        icon: Icons.directions_bus_filled_outlined,
      ),
      KpiCard(
        label: 'Active routes',
        value: '${_stats['activeRoutes'] ?? 0}',
        icon: Icons.alt_route_rounded,
        accentBg: AppColors.warningTint,
        accentFg: AppColors.warningText,
      ),
      KpiCard(
        label: "Today's trips",
        value: '${_stats['todaysTrips'] ?? 0}',
        icon: Icons.today_rounded,
        accentBg: AppColors.successTint,
        accentFg: AppColors.successText,
      ),
      KpiCard(
        label: 'Revenue',
        value: 'ZMW ${_stats['revenue'] ?? 0}',
        icon: Icons.payments_outlined,
        accentBg: AppColors.dangerLight,
        accentFg: AppColors.dangerText,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, c) {
            final cols = c.maxWidth > 1000
                ? 4
                : c.maxWidth > 600
                    ? 2
                    : 1;
            const spacing = 16.0;
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
        AppCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Latest schedules',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 14),
              if (_schedules.isEmpty)
                _emptyText('No schedules created yet.')
              else
                ..._schedules.take(5).map(
                      (s) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.brandTint,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.schedule_rounded,
                                color: AppColors.brandPrimary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${s['origin'] ?? '—'} → ${s['destination'] ?? '—'}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _date(s['departure_time']),
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
                      ),
                    ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _entityTable(
    List<Map<String, dynamic>> items,
    List<String> headers,
    List<String> keys,
    IconData icon,
    Future<void> Function(dynamic id)? onDelete, {
    int? dateColumn,
    int? routeColumn,
    int? pillColumn,
  }) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 30),
        child: StateCard(
          icon: icon,
          title: 'No records yet',
          message:
              'Tap the "New ${_sections[_section].label.toLowerCase()}" button to create your first record.',
        ),
      );
    }

    return AppCard(
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: MediaQuery.of(context).size.width - 320,
          ),
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(AppColors.background),
            headingTextStyle: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
            dataTextStyle: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
            ),
            columnSpacing: 28,
            horizontalMargin: 20,
            columns: [
              for (final h in headers) DataColumn(label: Text(h.toUpperCase())),
              if (onDelete != null) const DataColumn(label: Text('')),
            ],
            rows: items.map((item) {
              final id = item['bus_id'] ??
                  item['schedule_id'] ??
                  item['route_id'] ??
                  item['trip_id'] ??
                  item['driver_id'] ??
                  item['booking_id'];

              final cells = <DataCell>[];
              for (var i = 0; i < keys.length; i++) {
                if (i == 0) {
                  // First column also shows the row icon
                  String text;
                  if (routeColumn == 0 && item['destination'] != null) {
                    text = '${item['origin']} → ${item['destination']}';
                  } else {
                    text = '${item[keys[i]] ?? '—'}';
                  }
                  cells.add(DataCell(Row(
                    children: [
                      Icon(icon, size: 16, color: AppColors.brandPrimary),
                      const SizedBox(width: 8),
                      Text(
                        text,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  )));
                  continue;
                }
                if (i == dateColumn) {
                  cells.add(DataCell(Text(_date(item[keys[i]]))));
                } else if (i == pillColumn) {
                  cells.add(DataCell(
                    StatusPill.fromLabel('${item[keys[i]] ?? '—'}'),
                  ));
                } else {
                  cells.add(DataCell(Text('${item[keys[i]] ?? '—'}')));
                }
              }
              if (onDelete != null) {
                cells.add(DataCell(IconButton(
                  onPressed: () => onDelete(id),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  color: AppColors.dangerText,
                )));
              }
              return DataRow(cells: cells);
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _emptyText(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          text,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      );

  // ── Create form ─────────────────────────────────────────────────────────

  Future<void> _showCreateForm() async {
    final index = _section - 1; // adjust: section 1 = buses (index 0 of labels)
    if (index < 0 || index > 3) return;
    final title = ['Add bus', 'Add route', 'Create schedule', 'Add staff'][index];
    final controllers = List.generate(5, (_) => TextEditingController());
    final formKey = GlobalKey<FormState>();
    final labels = [
      ['Plate', 'Capacity', 'Type'],
      ['Origin', 'Destination', 'Price'],
      ['Route ID', 'Bus ID', 'Driver ID', 'Departure ISO/date', 'Conductor ID'],
      ['Full name', 'Email', 'Phone', 'Role', 'Password'],
    ][index];

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          18,
          18,
          18,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              for (var i = 0; i < labels.length; i++) ...[
                TextFormField(
                  controller: controllers[i],
                  validator: (value) =>
                      (value ?? '').trim().isEmpty && i < 3 ? 'Required' : null,
                  decoration: InputDecoration(labelText: labels[i]),
                ),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 6),
              FilledButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  await _submitCreate(
                    index,
                    controllers.map((c) => c.text.trim()).toList(),
                  );
                  if (context.mounted) Navigator.pop(context, true);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brandVivid,
                  foregroundColor: AppColors.textOnBrand,
                  minimumSize: const Size.fromHeight(52),
                ),
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
    for (final controller in controllers) {
      controller.dispose();
    }
    if (saved == true) await _load();
  }

  Future<void> _submitCreate(int index, List<String> values) {
    switch (index) {
      case 0:
        return _api.post('/company/buses', {
          'plate': values[0],
          'capacity': int.tryParse(values[1]) ?? 0,
          'type': values[2],
        });
      case 1:
        return _api.post('/company/routes', {
          'origin': values[0],
          'destination': values[1],
          'price': values[2],
        });
      case 2:
        return _api.post('/company/schedules', {
          'route': values[0],
          'bus': values[1],
          'driver': values[2],
          'departure_time': values[3],
          'conductor': values[4],
        });
      default:
        return _api.post('/company/staff', {
          'name': values[0],
          'email': values[1],
          'phone_number': values[2],
          'role': values[3].isEmpty ? 'conductor' : values[3],
          'password': values[4],
        });
    }
  }

  Future<void> _deleteBus(dynamic id) async =>
      _api.delete('/company/buses/$id').then((_) => _load());
  Future<void> _deleteRoute(dynamic id) async =>
      _api.delete('/company/routes/$id').then((_) => _load());
  Future<void> _deleteSchedule(dynamic id) async =>
      _api.delete('/company/schedules/$id').then((_) => _load());
  Future<void> _deleteStaff(dynamic id) async =>
      _api.delete('/company/staff/$id').then((_) => _load());

  List<Map<String, dynamic>> _list(dynamic value) => value is List
      ? value.whereType<Map<String, dynamic>>().toList()
      : const [];

  String _date(dynamic raw) => raw is String
      ? DateFormat('d MMM HH:mm')
          .format(DateTime.tryParse(raw)?.toLocal() ?? DateTime.now())
      : '—';
}

// ===========================================================================
// Side nav
// ===========================================================================

class _SideNav extends StatelessWidget {
  const _SideNav({
    required this.sections,
    required this.selected,
    required this.expanded,
    required this.onSelected,
    required this.onLogout,
  });

  final List<({IconData icon, String label})> sections;
  final int selected;
  final bool expanded;
  final ValueChanged<int> onSelected;
  final VoidCallback onLogout;

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
                    Icons.business_rounded,
                    color: AppColors.textOnBrand,
                    size: 20,
                  ),
                ),
                if (expanded) ...[
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Operator\nworkspace',
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
              itemCount: sections.length,
              itemBuilder: (context, index) {
                final s = sections[index];
                final isSelected = selected == index;
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
                          color: isSelected
                              ? AppColors.brandTint
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: expanded
                            ? Row(
                                children: [
                                  Icon(
                                    s.icon,
                                    size: 20,
                                    color: isSelected
                                        ? AppColors.brandPrimary
                                        : AppColors.textMuted,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    s.label,
                                    style: TextStyle(
                                      color: isSelected
                                          ? AppColors.brandPrimary
                                          : AppColors.textSecondary,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              )
                            : Tooltip(
                                message: s.label,
                                child: Column(
                                  children: [
                                    Icon(
                                      s.icon,
                                      color: isSelected
                                          ? AppColors.brandPrimary
                                          : AppColors.textMuted,
                                      size: 22,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      s.label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isSelected
                                            ? AppColors.brandPrimary
                                            : AppColors.textSecondary,
                                        fontWeight: isSelected
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

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.dangerLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.danger.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppColors.dangerText,
            ),
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
