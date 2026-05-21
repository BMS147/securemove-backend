import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../auth_service.dart';
import '../../services/api_service.dart';
import '../../widgets/role_guard.dart';
import '../../widgets/stats_card.dart';

class CompanyOperatorWorkspaceScreen extends StatefulWidget {
  const CompanyOperatorWorkspaceScreen({super.key});

  @override
  State<CompanyOperatorWorkspaceScreen> createState() => _CompanyOperatorWorkspaceScreenState();
}

class _CompanyOperatorWorkspaceScreenState extends State<CompanyOperatorWorkspaceScreen> with SingleTickerProviderStateMixin {
  final _api = ApiService.instance;
  late final TabController _tabController;
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _company = const {};
  Map<String, dynamic> _stats = const {};
  List<Map<String, dynamic>> _buses = const [];
  List<Map<String, dynamic>> _routes = const [];
  List<Map<String, dynamic>> _schedules = const [];
  List<Map<String, dynamic>> _staff = const [];
  List<Map<String, dynamic>> _bookings = const [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
    return RoleGuard(
      allowedRoles: const {'company_admin'},
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Company Workspace'),
          actions: [IconButton(onPressed: _logout, icon: const Icon(Icons.logout_rounded))],
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabs: const [
              Tab(text: 'Buses'),
              Tab(text: 'Routes'),
              Tab(text: 'Schedules'),
              Tab(text: 'Staff'),
              Tab(text: 'Bookings'),
            ],
          ),
        ),
        floatingActionButton: AnimatedBuilder(
          animation: _tabController,
          builder: (context, _) {
            if (_tabController.index == 4) return const SizedBox.shrink();
            return FloatingActionButton(
              onPressed: _showCreateForm,
              child: const Icon(Icons.add_rounded),
            );
          },
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_error != null) _ErrorBanner(message: _error!),
                    _header(),
                    const SizedBox(height: 12),
                    _statsGrid(),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.58,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _entityList(_buses, 'registration_number', 'capacity', Icons.directions_bus_filled_rounded, _deleteBus),
                          _entityList(_routes, 'origin', 'destination', Icons.route_rounded, _deleteRoute),
                          _entityList(_schedules, 'origin', 'departure_time', Icons.schedule_rounded, _deleteSchedule),
                          _entityList(_staff, 'full_name', 'email', Icons.badge_outlined, _deleteStaff),
                          _entityList(_bookings, 'booking_reference', 'passenger_name', Icons.confirmation_number_outlined, null),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _header() {
    final approved = _company['approval_status'] == 'approved';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _box(),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(color: const Color(0xFFEFF4FF), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.business_rounded, color: Color(0xFF3667F5)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${_company['name'] ?? 'Company'}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(approved ? 'Approved operator' : 'Approval pending', style: TextStyle(color: approved ? const Color(0xFF0F7A4C) : const Color(0xFFB7791F))),
              ],
            ),
          ),
          Icon(approved ? Icons.verified_rounded : Icons.pending_actions_rounded, color: approved ? const Color(0xFF0F7A4C) : const Color(0xFFB7791F)),
        ],
      ),
    );
  }

  Widget _statsGrid() {
    final cards = [
      StatsCard(label: 'Active Buses', value: '${_stats['activeBuses'] ?? 0}', icon: Icons.directions_bus),
      StatsCard(label: 'Active Routes', value: '${_stats['activeRoutes'] ?? 0}', icon: Icons.route),
      StatsCard(label: "Today's Trips", value: '${_stats['todaysTrips'] ?? 0}', icon: Icons.today),
      StatsCard(label: 'Revenue', value: 'ZMW ${_stats['revenue'] ?? 0}', icon: Icons.payments),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth > 700 ? (constraints.maxWidth - 36) / 4 : (constraints.maxWidth - 12) / 2;
      return Wrap(spacing: 12, runSpacing: 12, children: cards.map((card) => SizedBox(width: width, child: card)).toList());
    });
  }

  Widget _entityList(
    List<Map<String, dynamic>> items,
    String titleKey,
    String subtitleKey,
    IconData icon,
    Future<void> Function(dynamic id)? onDelete,
  ) {
    if (items.isEmpty) {
      return const Center(child: Text('No records yet.'));
    }
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final id = item['bus_id'] ?? item['schedule_id'] ?? item['trip_id'] ?? item['driver_id'] ?? item['booking_id'];
        final title = titleKey == 'origin' && item['destination'] != null ? '${item['origin']} -> ${item['destination']}' : '${item[titleKey] ?? 'Record'}';
        final subtitle = subtitleKey == 'departure_time' ? _date(item[subtitleKey]) : '${item[subtitleKey] ?? ''}';
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: _box(),
          child: ListTile(
            leading: Icon(icon),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(subtitle),
            trailing: onDelete == null ? null : IconButton(onPressed: () => onDelete(id), icon: const Icon(Icons.delete_outline_rounded)),
          ),
        );
      },
    );
  }

  Future<void> _showCreateForm() async {
    final index = _tabController.index;
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
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(18, 18, 18, MediaQuery.of(context).viewInsets.bottom + 18),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              for (var i = 0; i < labels.length; i++) ...[
                TextFormField(
                  controller: controllers[i],
                  validator: (value) => (value ?? '').trim().isEmpty && i < 3 ? 'Required' : null,
                  decoration: InputDecoration(labelText: labels[i]),
                ),
                const SizedBox(height: 10),
              ],
              FilledButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  await _submitCreate(index, controllers.map((c) => c.text.trim()).toList());
                  if (context.mounted) Navigator.pop(context, true);
                },
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
        return _api.post('/company/buses', {'plate': values[0], 'capacity': int.tryParse(values[1]) ?? 0, 'type': values[2]});
      case 1:
        return _api.post('/company/routes', {'origin': values[0], 'destination': values[1], 'price': values[2]});
      case 2:
        return _api.post('/company/schedules', {'route': values[0], 'bus': values[1], 'driver': values[2], 'departure_time': values[3], 'conductor': values[4]});
      default:
        return _api.post('/company/staff', {'name': values[0], 'email': values[1], 'phone_number': values[2], 'role': values[3].isEmpty ? 'conductor' : values[3], 'password': values[4]});
    }
  }

  Future<void> _deleteBus(dynamic id) async => _api.delete('/company/buses/$id').then((_) => _load());
  Future<void> _deleteRoute(dynamic id) async => _api.delete('/company/routes/$id').then((_) => _load());
  Future<void> _deleteSchedule(dynamic id) async => _api.delete('/company/schedules/$id').then((_) => _load());
  Future<void> _deleteStaff(dynamic id) async => _api.delete('/company/staff/$id').then((_) => _load());

  List<Map<String, dynamic>> _list(dynamic value) => value is List ? value.whereType<Map<String, dynamic>>().toList() : const [];
  String _date(dynamic raw) => raw is String ? DateFormat('d MMM HH:mm').format(DateTime.tryParse(raw)?.toLocal() ?? DateTime.now()) : '';
  BoxDecoration _box() => BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE4EAF5)));
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFFFFECEC), borderRadius: BorderRadius.circular(8)),
        child: Text(message),
      );
}
