import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../auth_service.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/role_guard.dart';
import '../../widgets/scan_result_card.dart';
import '../../widgets/skeleton_card.dart';
import '../../widgets/workspace_header.dart';

class ConductorScannerScreen extends StatefulWidget {
  const ConductorScannerScreen({super.key});

  @override
  State<ConductorScannerScreen> createState() => _ConductorScannerScreenState();
}

class _ConductorScannerScreenState extends State<ConductorScannerScreen> {
  final _api = ApiService.instance;
  final _qrController = TextEditingController();
  bool _loading = true;
  bool _scanning = false;
  String? _error;
  Map<String, dynamic>? _conductor;
  Map<String, dynamic>? _trip;
  Map<String, dynamic>? _result;
  int _boarded = 0;
  int _total = 0;
  Timer? _resetTimer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    _qrController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await _api.get('/conductor/me');
      final tripData = await _api.get('/conductor/trip');
      if (!mounted) return;
      setState(() {
        _conductor = profile['conductor'] as Map<String, dynamic>?;
        _trip = (tripData['assignedTrip'] ?? tripData['trip']) as Map<String, dynamic>?;
        _boarded = tripData['boarded'] as int? ?? 0;
        _total = tripData['total'] as int? ?? 0;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _scanManualCode() async {
    if (_scanning || _trip == null) return;
    final code = _qrController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter or paste a QR ticket code.')),
      );
      return;
    }

    if (mounted) setState(() => _scanning = true);
    try {
      final result = await _api.post('/conductor/scan', {'qrCode': code});
      if (!mounted) return;
      setState(() => _result = result);
      _qrController.clear();
      await _refreshCounter();
    } on ApiException catch (_) {
      if (!mounted) return;
      setState(() {
        _result = const {
          'status': 'INVALID',
          'message': 'Ticket not found or tampered',
        };
      });
    }

    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() {
        _result = null;
        _scanning = false;
      });
    });
  }

  Future<void> _refreshCounter() async {
    final tripData = await _api.get('/conductor/trip');
    if (!mounted) return;
    setState(() {
      _boarded = tripData['boarded'] as int? ?? _boarded;
      _total = tripData['total'] as int? ?? _total;
    });
  }

  Future<void> _advanceStatus() async {
    final current = '${_trip?['status'] ?? 'BOARDING'}'.toUpperCase();
    final next = current == 'BOARDING'
        ? 'DEPARTED'
        : current == 'DEPARTED'
            ? 'COMPLETED'
            : 'BOARDING';
    final response = await _api.put('/conductor/trip/status', {'status': next});
    if (!mounted) return;
    final updatedTrip = response['trip'];
    setState(() {
      if (updatedTrip is Map<String, dynamic>) {
        _trip = {...?_trip, ...updatedTrip};
      }
    });
  }

  Future<void> _logout() async {
    await AuthService.instance.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return RoleGuard(
      allowedRoles: const {'conductor'},
      child: Scaffold(
        appBar: null,
        body: _loading
            ? const _ConductorSkeleton()
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    WorkspaceHeader(
                      title: 'Conductor',
                      subtitle: 'Boarding control',
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
                              message: _error!,
                              onRetry: _load,
                            ),
                          if (_trip == null && _error == null) _emptyTripState(),
                    _tripHeader(),
                    const SizedBox(height: 14),
                    _counter(),
                    const SizedBox(height: 14),
                    _scannerView(),
                    const SizedBox(height: 14),
                    if (_result != null) ScanResultCard(result: _result!),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: _trip == null ? null : _advanceStatus,
                      icon: const Icon(Icons.flag_rounded),
                      label: Text('Status: ${_trip?['status'] ?? 'NO TRIP'}'),
                    ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _tripHeader() {
    final departure = _trip?['departure_time'] is String
        ? DateFormat('HH:mm').format(DateTime.tryParse(_trip!['departure_time'] as String)?.toLocal() ?? DateTime.now())
        : 'No time';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _box(),
      child: Row(
        children: [
          const Icon(Icons.badge_outlined, size: 38, color: AppColors.brandVivid),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${_conductor?['full_name'] ?? 'Conductor'}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(
                  _trip == null
                      ? 'No assigned trip for today'
                      : '${_trip?['origin'] ?? 'Origin'} -> ${_trip?['destination'] ?? 'Destination'} - ${_trip?['registration_number'] ?? 'Bus'} - $departure',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _counter() => Container(
        padding: const EdgeInsets.all(16),
        decoration: _box(),
        child: Row(
          children: [
            const Icon(Icons.groups_rounded, color: AppColors.successText),
            const SizedBox(width: 10),
            Text('Boarded: $_boarded / $_total passengers', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          ],
        ),
      );

  Widget _scannerView() {
    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: _trip == null
            ? Container(
                color: AppColors.border,
                child: const Center(child: Text('Scanner locked until a trip is assigned.')),
              )
            : Container(
                color: AppColors.textPrimary,
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.qr_code_scanner_rounded,
                      color: Colors.white,
                      size: 62,
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _qrController,
                      minLines: 2,
                      maxLines: 4,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'QR ticket code',
                        labelStyle: const TextStyle(color: AppColors.textOnBrandSoft),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: _scanning ? null : _scanManualCode,
                      icon: _scanning
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.verified_rounded),
                      label: const Text('Scan Ticket'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _emptyTripState() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(20),
      decoration: _box(),
      child: const Column(
        children: [
          Icon(Icons.event_busy_rounded, color: AppColors.textMuted, size: 44),
          SizedBox(height: 12),
          Text(
            'No trip assigned today',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 6),
          Text(
            'When operations assigns your trip, it will appear here automatically.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  BoxDecoration _box() => BoxDecoration(
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
      );
}

class _ConductorSkeleton extends StatelessWidget {
  const _ConductorSkeleton();

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                SkeletonCard(height: 86),
                SizedBox(height: 14),
                SkeletonCard(height: 78),
                SizedBox(height: 14),
                SkeletonCard(height: 320),
              ],
            ),
          ),
        ),
      );
}
