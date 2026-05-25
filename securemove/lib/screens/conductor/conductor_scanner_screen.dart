import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../auth_service.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/role_guard.dart';
import '../../widgets/scan_result_card.dart';
import '../../widgets/skeleton_card.dart';

enum _ScannerState { ready, processing, locked }

class ConductorScannerScreen extends StatefulWidget {
  const ConductorScannerScreen({super.key});

  @override
  State<ConductorScannerScreen> createState() => _ConductorScannerScreenState();
}

class _ConductorScannerScreenState extends State<ConductorScannerScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService.instance;
  final _cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    formats: const [BarcodeFormat.qrCode],
    torchEnabled: false,
  );

  late final AnimationController _laserController;

  bool _loading = true;
  bool _processing = false;
  String? _error;
  Map<String, dynamic>? _conductor;
  Map<String, dynamic>? _trip;
  Map<String, dynamic>? _result;
  Map<String, dynamic> _stats = const {
    'scans': 0,
    'valid': 0,
    'replayed': 0,
    'blocked': 0,
  };
  int _boarded = 0;
  int _total = 0;
  Timer? _resetTimer;
  String? _lastPayloadHash;
  DateTime? _lastPayloadAt;

  @override
  void initState() {
    super.initState();
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _load();
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    _laserController.dispose();
    _cameraController.dispose();
    super.dispose();
  }

  _ScannerState get _scannerState {
    if (_trip == null || _error != null) return _ScannerState.locked;
    if (_processing) return _ScannerState.processing;
    return _ScannerState.ready;
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
        _trip = (tripData['assignedTrip'] ?? tripData['trip'])
            as Map<String, dynamic>?;
        _boarded = tripData['boarded'] as int? ?? 0;
        _total = tripData['total'] as int? ?? 0;
        _stats = _readStats(tripData['stats']);
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleDetect(BarcodeCapture capture) async {
    if (_processing || _trip == null || _result != null) return;
    String? raw;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();
      if (value != null && value.isNotEmpty) {
        raw = value;
        break;
      }
    }
    if (raw == null) return;

    final rawHash = sha256.convert(utf8.encode(raw)).toString();
    final now = DateTime.now();
    if (_lastPayloadHash == rawHash &&
        _lastPayloadAt != null &&
        now.difference(_lastPayloadAt!) < const Duration(seconds: 5)) {
      return;
    }
    _lastPayloadHash = rawHash;
    _lastPayloadAt = now;

    await _cameraController.stop();
    await _submitScan(raw);
  }

  Future<void> _submitScan(String qrCode) async {
    if (!mounted) return;
    setState(() => _processing = true);

    try {
      final result = await _api.post('/conductor/scan', {'qrPayload': qrCode});
      if (!mounted) return;
      _applyHaptics(result['status'] as String?);
      setState(() => _result = result);
      await _refreshStats();
    } on ApiException catch (error) {
      if (!mounted) return;
      HapticFeedback.vibrate();
      setState(() {
        _result = {
          'status': 'NETWORK_ERROR',
          'message': error.message,
        };
      });
    } finally {
      _resetTimer?.cancel();
      _resetTimer = Timer(const Duration(seconds: 4), () async {
        if (!mounted) return;
        setState(() {
          _result = null;
          _processing = false;
        });
        if (_trip != null) {
          await _cameraController.start();
        }
      });
    }
  }

  void _applyHaptics(String? status) {
    switch (status) {
      case 'VALID':
        HapticFeedback.mediumImpact();
        break;
      case 'ALREADY_USED':
      case 'WRONG_TRIP':
      case 'EXPIRED':
        HapticFeedback.heavyImpact();
        break;
      default:
        HapticFeedback.vibrate();
    }
  }

  Future<void> _refreshStats() async {
    final tripData = await _api.get('/conductor/trip');
    if (!mounted) return;
    setState(() {
      _boarded = tripData['boarded'] as int? ?? _boarded;
      _total = tripData['total'] as int? ?? _total;
      _stats = _readStats(tripData['stats'] ?? tripData['scanBreakdown']);
    });
  }

  Map<String, dynamic> _readStats(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return {
        ...raw,
        if (raw.containsKey('alreadyUsed')) 'already_used': raw['alreadyUsed'],
        if (raw.containsKey('wrongTrip')) 'wrong_trip': raw['wrongTrip'],
      };
    }
    return const {
      'scans': 0,
      'valid': 0,
      'replayed': 0,
      'blocked': 0,
    };
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
        backgroundColor: const Color(0xFFF5F7FB),
        body: _loading
            ? const _ConductorSkeleton()
            : SafeArea(
                child: Column(
                  children: [
                    _OfficerHeader(
                      conductor: _conductor,
                      trip: _trip,
                      error: _error,
                      scannerState: _scannerState,
                      onLogout: _logout,
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: ErrorBanner(
                          title: 'Scanner unavailable',
                          message: _error!,
                          onRetry: _load,
                        ),
                      ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 260),
                          child: _result == null
                              ? _CameraZone(
                                  key: const ValueKey('camera'),
                                  controller: _cameraController,
                                  scannerState: _scannerState,
                                  laser: _laserController,
                                  onDetect: _handleDetect,
                                  onToggleTorch: _trip == null
                                      ? null
                                      : () => _cameraController.toggleTorch(),
                                )
                              : TweenAnimationBuilder<double>(
                                  key: const ValueKey('result'),
                                  tween: Tween(begin: 22, end: 0),
                                  duration: const Duration(milliseconds: 260),
                                  curve: Curves.easeOutCubic,
                                  builder: (context, offset, child) {
                                    return Transform.translate(
                                      offset: Offset(0, offset),
                                      child: child,
                                    );
                                  },
                                  child: Center(
                                    child: ScanResultCard(
                                      result: _result!,
                                      onRetry: () {
                                        _resetTimer?.cancel();
                                        setState(() {
                                          _result = null;
                                          _processing = false;
                                        });
                                        _cameraController.start();
                                      },
                                      onReportDuplicate: () =>
                                          _api.post('/conductor/report-duplicate', {
                                        'ticketRef': _result?['ticketRef'],
                                        'scannedAt': _result?['scannedAt'],
                                      }),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                    _SessionStatsBar(
                      boarded: _boarded,
                      total: _total,
                      stats: _stats,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _OfficerHeader extends StatelessWidget {
  const _OfficerHeader({
    required this.conductor,
    required this.trip,
    required this.error,
    required this.scannerState,
    required this.onLogout,
  });

  final Map<String, dynamic>? conductor;
  final Map<String, dynamic>? trip;
  final String? error;
  final _ScannerState scannerState;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final departure = trip?['departure_time'] is String
        ? DateFormat('HH:mm').format(
            DateTime.tryParse(trip!['departure_time'] as String)?.toLocal() ??
                DateTime.now(),
          )
        : 'No time';
    final badge = conductor?['license_number'] ?? conductor?['id'] ?? 'Pending';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _stateColor(scannerState).withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.security_rounded,
              color: _stateColor(scannerState),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  conductor?['full_name'] ?? conductor?['name'] ?? 'Conductor',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Badge $badge',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  trip == null
                      ? 'No trip assigned for today - contact your supervisor'
                      : '${trip?['origin']} -> ${trip?['destination']} | ${trip?['registration_number'] ?? 'Bus pending'} | $departure',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color:
                        trip == null ? AppColors.dangerText : AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Log out',
            onPressed: onLogout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
    );
  }
}

class _CameraZone extends StatelessWidget {
  const _CameraZone({
    super.key,
    required this.controller,
    required this.scannerState,
    required this.laser,
    required this.onDetect,
    required this.onToggleTorch,
  });

  final MobileScannerController controller;
  final _ScannerState scannerState;
  final Animation<double> laser;
  final void Function(BarcodeCapture capture) onDetect;
  final VoidCallback? onToggleTorch;

  @override
  Widget build(BuildContext context) {
    final locked = scannerState == _ScannerState.locked;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (locked)
            Container(
              color: const Color(0xFF111827),
              child: const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Scanner locked until a trip is assigned.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            )
          else
            MobileScanner(
              controller: controller,
              onDetect: onDetect,
            ),
          Container(color: Colors.black.withOpacity(0.12)),
          Center(
            child: AspectRatio(
              aspectRatio: 1,
              child: FractionallySizedBox(
                widthFactor: 0.78,
                heightFactor: 0.78,
                child: CustomPaint(
                  painter: _FramePainter(
                    color: _stateColor(scannerState),
                  ),
                  child: locked
                      ? null
                      : AnimatedBuilder(
                          animation: laser,
                          builder: (context, child) {
                            return Align(
                              alignment: Alignment(0, -0.82 + laser.value * 1.64),
                              child: Container(
                                height: 3,
                                margin: const EdgeInsets.symmetric(horizontal: 20),
                                decoration: BoxDecoration(
                                  color: _stateColor(scannerState),
                                  borderRadius: BorderRadius.circular(999),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _stateColor(scannerState)
                                          .withOpacity(0.55),
                                      blurRadius: 16,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 14,
            left: 14,
            child: _StatusBadge(scannerState: scannerState),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: IconButton.filled(
              tooltip: 'Toggle flashlight',
              onPressed: onToggleTorch,
              icon: const Icon(Icons.flashlight_on_rounded),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.18),
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.scannerState});

  final _ScannerState scannerState;

  @override
  Widget build(BuildContext context) {
    final label = switch (scannerState) {
      _ScannerState.ready => 'Ready',
      _ScannerState.processing => 'Processing',
      _ScannerState.locked => 'Locked',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.45),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: _stateColor(scannerState),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionStatsBar extends StatelessWidget {
  const _SessionStatsBar({
    required this.boarded,
    required this.total,
    required this.stats,
  });

  final int boarded;
  final int total;
  final Map<String, dynamic> stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            _StatTile(label: 'Boarded', value: '$boarded/$total'),
            _StatTile(label: 'Valid', value: '${stats['valid'] ?? 0}'),
            _StatTile(
              label: 'Used',
              value: '${stats['already_used'] ?? stats['alreadyUsed'] ?? 0}',
            ),
            _StatTile(
              label: 'Invalid',
              value:
                  '${(stats['invalid'] ?? 0) + (stats['fake'] ?? 0) + (stats['wrong_trip'] ?? stats['wrongTrip'] ?? 0) + (stats['expired'] ?? 0)}',
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _FramePainter extends CustomPainter {
  const _FramePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const radius = Radius.circular(22);
    const corner = 54.0;

    final path = Path()
      ..moveTo(0, corner)
      ..lineTo(0, radius.y)
      ..quadraticBezierTo(0, 0, radius.x, 0)
      ..lineTo(corner, 0)
      ..moveTo(size.width - corner, 0)
      ..lineTo(size.width - radius.x, 0)
      ..quadraticBezierTo(size.width, 0, size.width, radius.y)
      ..lineTo(size.width, corner)
      ..moveTo(size.width, size.height - corner)
      ..lineTo(size.width, size.height - radius.y)
      ..quadraticBezierTo(
        size.width,
        size.height,
        size.width - radius.x,
        size.height,
      )
      ..lineTo(size.width - corner, size.height)
      ..moveTo(corner, size.height)
      ..lineTo(radius.x, size.height)
      ..quadraticBezierTo(0, size.height, 0, size.height - radius.y)
      ..lineTo(0, size.height - corner);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _FramePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

Color _stateColor(_ScannerState state) {
  switch (state) {
    case _ScannerState.ready:
      return const Color(0xFF16A34A);
    case _ScannerState.processing:
      return const Color(0xFFEAB308);
    case _ScannerState.locked:
      return AppColors.danger;
  }
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
                SkeletonCard(height: 96),
                SizedBox(height: 14),
                Expanded(child: SkeletonCard(height: 420)),
                SizedBox(height: 14),
                SkeletonCard(height: 74),
              ],
            ),
          ),
        ),
      );
}
