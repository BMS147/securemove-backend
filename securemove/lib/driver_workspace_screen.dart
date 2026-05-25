import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'auth_service.dart';
import 'backend_config.dart';
import 'driver.dart';
import 'driver_service.dart';
import 'theme/app_colors.dart';
import 'widgets/error_banner.dart';
import 'widgets/skeleton_card.dart';

class DriverWorkspaceScreen extends StatefulWidget {
  const DriverWorkspaceScreen({super.key});

  @override
  State<DriverWorkspaceScreen> createState() => _DriverWorkspaceScreenState();
}

class _DriverWorkspaceScreenState extends State<DriverWorkspaceScreen> {
  final _service = DriverService.instance;
  int _tab = 0;
  bool _loading = true;
  String? _error;
  String? _tripsError;
  String? _notificationsError;
  DriverProfile? _driver;
  List<DriverTrip> _upcoming = const [];
  List<DriverTrip> _completed = const [];
  List<DriverTrip> _allTrips = const [];
  List<DriverNotification> _notifications = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _tripsError = null;
      _notificationsError = null;
    });

    try {
      final driver = await _service.getCurrentDriver();
      if (!mounted) return;
      setState(() => _driver = driver);
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }

    try {
      final results = await Future.wait([
        _service.getTrips(status: 'upcoming'),
        _service.getTrips(status: 'completed'),
        _service.getTrips(status: 'all'),
      ]);
      if (!mounted) return;
      setState(() {
        _upcoming = results[0];
        _completed = results[1];
        _allTrips = results[2];
      });
    } on AuthException catch (error) {
      if (mounted) setState(() => _tripsError = error.message);
    }

    try {
      final notifications = await _service.getNotifications();
      if (!mounted) return;
      setState(() => _notifications = notifications);
    } on AuthException catch (error) {
      if (mounted) setState(() => _notificationsError = error.message);
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Driver workspace'),
        actions: [
          IconButton(
            tooltip: 'Log out',
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (value) => setState(() => _tab = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.person_rounded), label: 'Profile'),
          NavigationDestination(icon: Icon(Icons.route_rounded), label: 'My Trips'),
          NavigationDestination(icon: Icon(Icons.notifications_rounded), label: 'Notifications'),
        ],
      ),
      body: _loading
          ? const _DriverSkeleton()
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: [
                  if (_error != null)
                    ErrorBanner(
                      title: 'Driver workspace unavailable',
                      message: _error!,
                      onRetry: _load,
                    ),
                  if (_tab == 0)
                    _DriverProfileView(
                      driver: _driver,
                      onChanged: (driver) => setState(() => _driver = driver),
                    )
                  else if (_tab == 1)
                    _TripsView(
                      upcoming: _upcoming,
                      completed: _completed,
                      allTrips: _allTrips,
                      error: _tripsError,
                      onRetry: _load,
                      onOpen: _openTrip,
                    )
                  else
                    _NotificationsView(
                      notifications: _notifications,
                      error: _notificationsError,
                      onRetry: _load,
                    ),
                ],
              ),
            ),
    );
  }

  Future<void> _openTrip(DriverTrip trip) async {
    final detail = await _service.getTripDetail(trip.tripId);
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _TripDetailSheet(trip: detail),
    );
  }
}

class _DriverProfileView extends StatefulWidget {
  const _DriverProfileView({required this.driver, required this.onChanged});

  final DriverProfile? driver;
  final ValueChanged<DriverProfile> onChanged;

  @override
  State<_DriverProfileView> createState() => _DriverProfileViewState();
}

class _DriverProfileViewState extends State<_DriverProfileView> {
  final _service = DriverService.instance;
  final _picker = ImagePicker();
  bool _editing = false;
  bool _saving = false;
  bool _uploading = false;
  late final TextEditingController _name;
  late final TextEditingController _phone;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.driver?.fullName ?? '');
    _phone = TextEditingController(text: widget.driver?.phoneNumber ?? '');
  }

  @override
  void didUpdateWidget(covariant _DriverProfileView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editing && oldWidget.driver != widget.driver) {
      _name.text = widget.driver?.fullName ?? '';
      _phone.text = widget.driver?.phoneNumber ?? '';
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final updated = await _service.updateProfile(
        fullName: _name.text.trim(),
        phone: _phone.text.trim(),
      );
      widget.onChanged(updated);
      if (mounted) setState(() => _editing = false);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickPhoto() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 90,
    );
    if (picked == null) return;

    setState(() => _uploading = true);
    try {
      final updated = await _service.uploadProfilePhoto(picked.path);
      widget.onChanged(updated);
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final driver = widget.driver;
    final expiry = driver?.licenseExpiry;
    final expiringSoon = expiry != null &&
        expiry.difference(DateTime.now()).inDays <= 30 &&
        expiry.isAfter(DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Panel(
          child: Column(
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: _uploading ? null : _pickPhoto,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        CircleAvatar(
                          radius: 46,
                          backgroundColor: AppColors.brandTint,
                          backgroundImage: _photoProvider(driver?.profilePhoto),
                          child: driver?.profilePhoto == null
                              ? const Icon(Icons.person_rounded, size: 42)
                              : null,
                        ),
                        if (_uploading) const CircularProgressIndicator(),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.brandPrimary,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          driver?.fullName ?? 'Driver profile',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          driver?.email ?? 'No email',
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 10),
                        _StatusChip(label: driver?.status ?? 'ACTIVE'),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _uploading ? null : _pickPhoto,
                          icon: const Icon(Icons.photo_camera_rounded, size: 18),
                          label: const Text('Upload profile photo'),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: () => setState(() => _editing = !_editing),
                    icon: Icon(_editing ? Icons.close_rounded : Icons.edit_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _ProfileField(label: 'Full name', controller: _name, enabled: _editing),
              _ProfileField(label: 'Phone number', controller: _phone, enabled: _editing),
              _ReadOnlyRow(label: 'NRC number', value: driver?.nrcNumber ?? 'Pending admin approval'),
              _ReadOnlyRow(label: 'License number', value: driver?.licenseNumber ?? 'Pending'),
              _ReadOnlyRow(label: 'License class', value: driver?.licenseClass ?? 'Class C PSV'),
              _ReadOnlyRow(
                label: 'License expiry',
                value: expiry == null ? 'Not set' : DateFormat('d MMM yyyy').format(expiry),
                trailing: expiringSoon
                    ? const _WarningBadge(label: 'Expiring soon')
                    : null,
              ),
              if (_editing) ...[
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_rounded),
                  label: const Text('Save changes'),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        _StatsPanel(driver: driver),
      ],
    );
  }

  ImageProvider? _photoProvider(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final url = raw.startsWith('http') ? raw : '${BackendConfig.authBaseUrl}$raw';
    return NetworkImage(url);
  }
}

class _TripsView extends StatefulWidget {
  const _TripsView({
    required this.upcoming,
    required this.completed,
    required this.allTrips,
    required this.error,
    required this.onRetry,
    required this.onOpen,
  });

  final List<DriverTrip> upcoming;
  final List<DriverTrip> completed;
  final List<DriverTrip> allTrips;
  final String? error;
  final VoidCallback onRetry;
  final ValueChanged<DriverTrip> onOpen;

  @override
  State<_TripsView> createState() => _TripsViewState();
}

class _TripsViewState extends State<_TripsView> {
  int _segment = 0;

  @override
  Widget build(BuildContext context) {
    final trips = switch (_segment) {
      1 => widget.completed,
      2 => widget.allTrips,
      _ => widget.upcoming,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, label: Text('Upcoming')),
            ButtonSegment(value: 1, label: Text('Completed')),
            ButtonSegment(value: 2, label: Text('All')),
          ],
          selected: {_segment},
          onSelectionChanged: (value) => setState(() => _segment = value.first),
        ),
        const SizedBox(height: 14),
        if (widget.error != null) ...[
          ErrorBanner(
            title: 'Trips unavailable',
            message: widget.error!,
            onRetry: widget.onRetry,
          ),
          const SizedBox(height: 14),
        ],
        if (trips.isEmpty)
          const _EmptyPanel(
            icon: Icons.route_outlined,
            title: 'No trips here',
            subtitle: 'Assigned trips will appear in this list.',
          )
        else
          ...trips.map((trip) => _TripCard(trip: trip, onTap: () => widget.onOpen(trip))),
      ],
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip, required this.onTap});

  final DriverTrip trip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final departure = trip.departureTime == null
        ? 'Time pending'
        : DateFormat('EEE, d MMM - HH:mm').format(trip.departureTime!);

    return _Panel(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onTap,
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.directions_bus_filled_rounded),
        title: Text(trip.routeLabel, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(
          '$departure\n${trip.registrationNumber ?? 'Bus pending'} - ${trip.boardedCount}/${trip.passengerCount} boarded',
        ),
        isThreeLine: true,
        trailing: _StatusChip(label: trip.statusLabel),
      ),
    );
  }
}

class _TripDetailSheet extends StatelessWidget {
  const _TripDetailSheet({required this.trip});

  final DriverTrip trip;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(trip.routeLabel, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            _ReadOnlyRow(label: 'Bus', value: '${trip.registrationNumber ?? 'Pending'} - ${trip.busType ?? 'Coach'}'),
            _ReadOnlyRow(label: 'Conductor', value: trip.conductorName ?? 'Not assigned'),
            _ReadOnlyRow(
              label: 'Departure',
              value: trip.departureTime == null
                  ? 'Pending'
                  : DateFormat('EEE, d MMM yyyy HH:mm').format(trip.departureTime!),
            ),
            _ReadOnlyRow(
              label: 'Arrival',
              value: trip.arrivalTime == null
                  ? 'Pending'
                  : DateFormat('EEE, d MMM yyyy HH:mm').format(trip.arrivalTime!),
            ),
            _ReadOnlyRow(label: 'Passengers boarded', value: '${trip.boardedCount}/${trip.passengerCount}'),
            _ReadOnlyRow(label: 'Stops/features', value: trip.stops.isEmpty ? 'None listed' : trip.stops.join(', ')),
          ],
        ),
      ),
    );
  }
}

class _NotificationsView extends StatelessWidget {
  const _NotificationsView({
    required this.notifications,
    required this.error,
    required this.onRetry,
  });

  final List<DriverNotification> notifications;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return ErrorBanner(
        title: 'Notifications unavailable',
        message: error!,
        onRetry: onRetry,
      );
    }
    if (notifications.isEmpty) {
      return const _EmptyPanel(
        icon: Icons.notifications_none_rounded,
        title: 'No notifications',
        subtitle: 'Trip assignments, schedule changes, and admin messages will appear here.',
      );
    }
    return Column(
      children: notifications.map((item) {
        return _Panel(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              item.kind == 'warning' ? Icons.warning_amber_rounded : Icons.notifications_rounded,
              color: item.kind == 'warning' ? AppColors.warningText : AppColors.brandPrimary,
            ),
            title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w900)),
            subtitle: Text('${item.message}\n${_date(item.createdAt)}'),
            isThreeLine: true,
          ),
        );
      }).toList(),
    );
  }
}

class _StatsPanel extends StatelessWidget {
  const _StatsPanel({required this.driver});

  final DriverProfile? driver;

  @override
  Widget build(BuildContext context) {
    final stats = driver?.stats ?? const {};
    return _Panel(
      child: Row(
        children: [
          _Stat(label: 'Trips', value: '${stats['totalTrips'] ?? 0}'),
          _Stat(label: 'Distance', value: '${stats['totalDistanceKm'] ?? 0} km'),
          _Stat(label: 'Member since', value: _date(_asDate(stats['memberSince']) ?? driver?.createdAt)),
        ],
      ),
    );
  }
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({
    required this.label,
    required this.controller,
    required this.enabled,
  });

  final String label;
  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        enabled: enabled,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}

class _ReadOnlyRow extends StatelessWidget {
  const _ReadOnlyRow({required this.label, required this.value, this.trailing});

  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 126,
            child: Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w800))),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: label.toUpperCase().contains('SUSPENDED') ? AppColors.dangerLight : AppColors.successTint,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: label.toUpperCase().contains('SUSPENDED') ? AppColors.dangerText : AppColors.successText,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _WarningBadge extends StatelessWidget {
  const _WarningBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.warningTint,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: const TextStyle(color: AppColors.warningText, fontSize: 11, fontWeight: FontWeight.w800)),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        children: [
          Icon(icon, size: 42, color: AppColors.brandPrimary),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.margin});

  final Widget child;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(color: Color(0x100F2554), blurRadius: 24, offset: Offset(0, 14)),
        ],
      ),
      child: child,
    );
  }
}

class _DriverSkeleton extends StatelessWidget {
  const _DriverSkeleton();

  @override
  Widget build(BuildContext context) => const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              SkeletonCard(height: 160),
              SizedBox(height: 14),
              SkeletonCard(height: 240),
            ],
          ),
        ),
      );
}

DateTime? _asDate(dynamic value) {
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value)?.toLocal();
  return null;
}

String _date(DateTime? value) {
  if (value == null) return 'Not available';
  return DateFormat('d MMM yyyy').format(value);
}
