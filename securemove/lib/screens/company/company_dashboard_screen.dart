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

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will need to sign in again to manage this company.'),
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
    if (shouldLogout == true) await _logout();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Breakpoints.isDesktop(context);
    return RoleGuard(
      allowedRoles: const {'company_admin'},
      child: Scaffold(
        backgroundColor: AppColors.background,
        drawerScrimColor: Colors.black.withOpacity(0.48),
        drawer: _CompanyDrawer(
          sections: _sections,
          selected: _section,
          onSelected: (i) => setState(() => _section = i),
          onLogout: _confirmLogout,
        ),
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          leading: Builder(
            builder: (context) => IconButton(
              tooltip: 'Open menu',
              onPressed: () => Scaffold.of(context).openDrawer(),
              icon: const Icon(Icons.menu_rounded),
            ),
          ),
          title: Text(
            _sections[_section].label,
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
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                top: false,
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
          onEdit: _editRoutePrice,
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
          ['full_name', 'email', 'staff_role'],
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
    Future<void> Function(Map<String, dynamic> item)? onEdit,
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
              if (onEdit != null || onDelete != null)
                const DataColumn(label: Text('')),
            ],
            rows: items.map((item) {
              final id = item['bus_id'] ??
                  item['schedule_id'] ??
                  item['route_id'] ??
                  item['trip_id'] ??
                  item['driver_id'] ??
                  item['staff_id'] ??
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
              if (onEdit != null || onDelete != null) {
                cells.add(DataCell(Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onEdit != null)
                      IconButton(
                        tooltip: 'Edit',
                        onPressed: () => onEdit(item),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        color: AppColors.brandPrimary,
                      ),
                    if (onDelete != null)
                      IconButton(
                        tooltip: 'Delete',
                        onPressed: () => onDelete(id),
                        icon: const Icon(Icons.delete_outline_rounded, size: 18),
                        color: AppColors.dangerText,
                      ),
                  ],
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
    if (index == 0) {
      await _showCreateBusForm();
      return;
    }
    if (index == 2) {
      await _showCreateScheduleForm();
      return;
    }
    if (index == 3) {
      await _showCreateStaffForm();
      return;
    }
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

  Future<void> _showCreateBusForm() async {
    final formKey = GlobalKey<FormState>();
    final plateController = TextEditingController();
    final capacityController = TextEditingController();
    final typeController = TextEditingController(text: 'Coach');
    String? errorMessage;
    bool saving = false;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
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
                const Text(
                  'Add bus',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: plateController,
                  textCapitalization: TextCapitalization.characters,
                  validator: (value) =>
                      (value ?? '').trim().isEmpty ? 'Required' : null,
                  decoration: const InputDecoration(
                    labelText: 'Plate number',
                    hintText: 'ABC 1234',
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: capacityController,
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    final capacity = int.tryParse((value ?? '').trim());
                    return capacity == null || capacity <= 0
                        ? 'Enter a valid capacity'
                        : null;
                  },
                  decoration: const InputDecoration(labelText: 'Capacity'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: typeController,
                  decoration: const InputDecoration(labelText: 'Bus type'),
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    errorMessage!,
                    style: const TextStyle(
                      color: AppColors.dangerText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setModalState(() {
                            saving = true;
                            errorMessage = null;
                          });
                          try {
                            await _api.post('/company/buses', {
                              'plate': plateController.text.trim(),
                              'capacity':
                                  int.parse(capacityController.text.trim()),
                              'type': typeController.text.trim().isEmpty
                                  ? 'Coach'
                                  : typeController.text.trim(),
                            });
                            if (context.mounted) Navigator.pop(context, true);
                          } on ApiException catch (error) {
                            setModalState(() {
                              saving = false;
                              errorMessage = error.message;
                            });
                          }
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandVivid,
                    foregroundColor: AppColors.textOnBrand,
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: Text(saving ? 'Saving...' : 'Save bus'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    plateController.dispose();
    capacityController.dispose();
    typeController.dispose();
    if (saved == true) await _load();
  }

  Future<void> _showCreateStaffForm() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final badgeController = TextEditingController();
    final passwordController = TextEditingController();
    var role = 'driver';
    String? errorMessage;
    bool saving = false;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            18,
            18,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Add staff',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: role,
                    decoration: const InputDecoration(labelText: 'Role'),
                    items: const [
                      DropdownMenuItem(value: 'driver', child: Text('Driver')),
                      DropdownMenuItem(
                        value: 'conductor',
                        child: Text('Conductor'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) setModalState(() => role = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: nameController,
                    validator: (value) =>
                        (value ?? '').trim().isEmpty ? 'Required' : null,
                    decoration: const InputDecoration(labelText: 'Full name'),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'Optional, required for app login',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Phone'),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: badgeController,
                    decoration: InputDecoration(
                      labelText:
                          role == 'driver' ? 'License number' : 'Badge number',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Login password',
                      hintText: 'Optional, creates/updates user login',
                    ),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      errorMessage!,
                      style: const TextStyle(
                        color: AppColors.dangerText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: saving
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;
                            setModalState(() {
                              saving = true;
                              errorMessage = null;
                            });
                            try {
                              await _api.post('/company/staff', {
                                'name': nameController.text.trim(),
                                'email': emailController.text.trim(),
                                'phone_number': phoneController.text.trim(),
                                'role': role,
                                'license_number': badgeController.text.trim(),
                                'password': passwordController.text.trim(),
                              });
                              if (context.mounted) Navigator.pop(context, true);
                            } on ApiException catch (error) {
                              setModalState(() {
                                saving = false;
                                errorMessage = error.message;
                              });
                            }
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brandVivid,
                      foregroundColor: AppColors.textOnBrand,
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: Text(saving ? 'Saving...' : 'Save staff'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    badgeController.dispose();
    passwordController.dispose();
    if (saved == true) await _load();
  }

  Future<void> _showCreateScheduleForm() async {
    final formKey = GlobalKey<FormState>();
    final departureController = TextEditingController();
    final routeItems = _routes.where((item) => item['schedule_id'] != null).toList();
    final busItems = _buses.where((item) => item['bus_id'] != null).toList();
    final driverItems = _staff
        .where((item) => item['staff_role'] == 'driver' && item['staff_id'] != null)
        .toList();
    final conductorItems = _staff
        .where((item) => item['staff_role'] == 'conductor' && item['staff_id'] != null)
        .toList();
    dynamic routeId = routeItems.isNotEmpty ? routeItems.first['schedule_id'] : null;
    dynamic busId = busItems.isNotEmpty ? busItems.first['bus_id'] : null;
    dynamic driverId = driverItems.isNotEmpty ? driverItems.first['staff_id'] : null;
    dynamic conductorId =
        conductorItems.isNotEmpty ? conductorItems.first['staff_id'] : null;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            18,
            18,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Create schedule',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _IdDropdown(
                    label: 'Route',
                    value: routeId,
                    items: routeItems,
                    idKey: 'schedule_id',
                    labelBuilder: (item) =>
                        '${item['origin']} to ${item['destination']} - ${item['price']}',
                    onChanged: (value) => setModalState(() => routeId = value),
                  ),
                  const SizedBox(height: 10),
                  _IdDropdown(
                    label: 'Bus',
                    value: busId,
                    items: busItems,
                    idKey: 'bus_id',
                    labelBuilder: (item) =>
                        '${item['registration_number']} (${item['capacity']} seats)',
                    onChanged: (value) => setModalState(() => busId = value),
                  ),
                  const SizedBox(height: 10),
                  _IdDropdown(
                    label: 'Driver',
                    value: driverId,
                    items: driverItems,
                    idKey: 'staff_id',
                    labelBuilder: (item) => '${item['full_name']}',
                    onChanged: (value) => setModalState(() => driverId = value),
                  ),
                  const SizedBox(height: 10),
                  _IdDropdown(
                    label: 'Conductor',
                    value: conductorId,
                    items: conductorItems,
                    idKey: 'staff_id',
                    labelBuilder: (item) => '${item['full_name']}',
                    onChanged: (value) =>
                        setModalState(() => conductorId = value),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: departureController,
                    validator: (value) =>
                        (value ?? '').trim().isEmpty ? 'Required' : null,
                    decoration: const InputDecoration(
                      labelText: 'Departure date and time',
                      hintText: '2026-05-27 08:30',
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      if (routeId == null ||
                          busId == null ||
                          driverId == null ||
                          conductorId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Add a route, bus, driver, and conductor first.',
                            ),
                          ),
                        );
                        return;
                      }
                      await _api.post('/company/schedules', {
                        'route': routeId,
                        'bus': busId,
                        'driver': driverId,
                        'conductor': conductorId,
                        'departure_time': departureController.text.trim(),
                      });
                      if (context.mounted) Navigator.pop(context, true);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brandVivid,
                      foregroundColor: AppColors.textOnBrand,
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: const Text('Save schedule'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    departureController.dispose();
    if (saved == true) await _load();
  }

  Future<void> _editRoutePrice(Map<String, dynamic> route) async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _EditRoutePriceSheet(
        route: route,
        api: _api,
      ),
    );
    if (updated == true) await _load();
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

class _EditRoutePriceSheet extends StatefulWidget {
  const _EditRoutePriceSheet({
    required this.route,
    required this.api,
  });

  final Map<String, dynamic> route;
  final ApiService api;

  @override
  State<_EditRoutePriceSheet> createState() => _EditRoutePriceSheetState();
}

class _EditRoutePriceSheetState extends State<_EditRoutePriceSheet> {
  late final TextEditingController _controller;
  String? _errorMessage;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.route['price'] ?? ''}');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final price = _controller.text.trim();
    if (price.isEmpty) {
      setState(() => _errorMessage = 'Enter a ticket price.');
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      await widget.api.put('/company/routes/${widget.route['schedule_id']}', {
        'price': price,
      });
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _errorMessage = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(18, 18, 18, bottomInset + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${widget.route['origin']} to ${widget.route['destination']}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _saving ? null : _submit(),
            decoration: const InputDecoration(
              labelText: 'Ticket price',
              prefixIcon: Icon(Icons.payments_outlined),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              _errorMessage!,
              style: const TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _saving ? null : _submit,
            icon: const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Updating...' : 'Update price'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brandVivid,
              foregroundColor: AppColors.textOnBrand,
              minimumSize: const Size.fromHeight(52),
            ),
          ),
        ],
      ),
    );
  }
}

class _IdDropdown extends StatelessWidget {
  const _IdDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.idKey,
    required this.labelBuilder,
    required this.onChanged,
  });

  final String label;
  final dynamic value;
  final List<Map<String, dynamic>> items;
  final String idKey;
  final String Function(Map<String, dynamic> item) labelBuilder;
  final ValueChanged<dynamic> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<dynamic>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      validator: (value) => value == null ? 'Required' : null,
      items: items
          .map(
            (item) => DropdownMenuItem<dynamic>(
              value: item[idKey],
              child: Text(
                labelBuilder(item),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}

// ===========================================================================
// Drawer nav
// ===========================================================================

class _CompanyDrawer extends StatelessWidget {
  const _CompanyDrawer({
    required this.sections,
    required this.selected,
    required this.onSelected,
    required this.onLogout,
  });

  final List<({IconData icon, String label})> sections;
  final int selected;
  final ValueChanged<int> onSelected;
  final VoidCallback onLogout;

  static const _navy = Color(0xFF071225);
  static const _drawerText = Color(0xFFE5E7EB);
  static const _drawerMuted = Color(0xFF94A3B8);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Drawer(
      width: width < 420 ? width * 0.86 : 340,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(30)),
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: _navy,
          borderRadius: BorderRadius.horizontal(right: Radius.circular(30)),
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
                        ),
                        child: const Icon(
                          Icons.business_rounded,
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
                              'Company Console',
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
                    itemCount: sections.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final section = sections[index];
                      return _CompanyDrawerItem(
                        icon: section.icon,
                        label: section.label,
                        selected: selected == index,
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

class _CompanyDrawerItem extends StatelessWidget {
  const _CompanyDrawerItem({
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
                color: selected
                    ? AppColors.textOnBrand
                    : _CompanyDrawer._drawerMuted,
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
                        : _CompanyDrawer._drawerText,
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
