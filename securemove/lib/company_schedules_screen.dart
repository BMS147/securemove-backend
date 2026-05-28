import 'package:flutter/material.dart';
import 'theme/app_colors.dart';

import 'auth_service.dart';
import 'company_service.dart';

class CompanySchedulesScreen extends StatefulWidget {
  const CompanySchedulesScreen({
    super.key,
    required this.company,
  });

  final CompanyRecord company;

  @override
  State<CompanySchedulesScreen> createState() => _CompanySchedulesScreenState();
}

class _CompanySchedulesScreenState extends State<CompanySchedulesScreen> {
  final CompanyService _companyService = CompanyService.instance;

  List<CompanySchedule> _schedules = const [];
  bool _isLoading = true;
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
      final schedules = await _companyService.getSchedules(widget.company.companyId);
      if (!mounted) {
        return;
      }
      setState(() => _schedules = schedules);
    } on AuthException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _editPrice(CompanySchedule schedule) async {
    final updated = await showModalBottomSheet<CompanySchedule>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditSchedulePriceSheet(
        companyId: widget.company.companyId,
        schedule: schedule,
        companyService: _companyService,
      ),
    );

    if (updated == null || !mounted) {
      return;
    }

    setState(() {
      _schedules = _schedules
          .map((item) => item.scheduleId == updated.scheduleId ? updated : item)
          .toList();
    });
  }

  Future<void> _toggleActive(CompanySchedule schedule) async {
    try {
      final updated = await _companyService.updateSchedule(
        companyId: widget.company.companyId,
        scheduleId: schedule.scheduleId,
        active: !schedule.active,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _schedules = _schedules
            .map((item) => item.scheduleId == updated.scheduleId ? updated : item)
            .toList();
      });
    } on AuthException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.company.name} prices')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
          children: [
            if (_errorMessage != null)
              _MessagePanel(message: _errorMessage!, isError: true),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_schedules.isEmpty)
              const _MessagePanel(
                message: 'No route schedules found for this company.',
                isError: false,
              )
            else
              ..._schedules.map(
                (schedule) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: _panelDecoration(),
                  child: ListTile(
                    leading: Icon(
                      schedule.active ? Icons.route_rounded : Icons.route_outlined,
                      color: AppColors.brandPrimary,
                    ),
                    title: Text(
                      schedule.routeLabel,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text('${schedule.departureTime} • ${schedule.price}'),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        IconButton(
                          tooltip: 'Edit price',
                          onPressed: () => _editPrice(schedule),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        Switch(
                          value: schedule.active,
                          onChanged: (_) => _toggleActive(schedule),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EditSchedulePriceSheet extends StatefulWidget {
  const _EditSchedulePriceSheet({
    required this.companyId,
    required this.schedule,
    required this.companyService,
  });

  final int companyId;
  final CompanySchedule schedule;
  final CompanyService companyService;

  @override
  State<_EditSchedulePriceSheet> createState() =>
      _EditSchedulePriceSheetState();
}

class _EditSchedulePriceSheetState extends State<_EditSchedulePriceSheet> {
  late final TextEditingController _controller;
  String? _validationMessage;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.schedule.price);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final price = _controller.text.trim();
    if (price.isEmpty) {
      setState(() => _validationMessage = 'Enter a ticket price.');
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _isSaving = true;
      _validationMessage = null;
    });

    try {
      final result = await widget.companyService.updateSchedule(
        companyId: widget.companyId,
        scheduleId: widget.schedule.scheduleId,
        price: price,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(result);
    } on AuthException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _validationMessage = error.message;
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(18, 18, 18, bottomInset + 18),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.schedule.routeLabel,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Departure ${widget.schedule.departureTime}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _isSaving ? null : _submit(),
              decoration: const InputDecoration(
                labelText: 'Ticket price',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
            ),
            if (_validationMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _validationMessage!,
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _submit,
              icon: const Icon(Icons.save_outlined),
              label: Text(_isSaving ? 'Updating...' : 'Update price'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessagePanel extends StatelessWidget {
  const _MessagePanel({
    required this.message,
    required this.isError,
  });

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isError ? AppColors.dangerLight : Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(message, style: const TextStyle(height: 1.35)),
    );
  }
}

BoxDecoration _panelDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(24),
    boxShadow: const [
      BoxShadow(
        color: Color(0x100F2554),
        blurRadius: 24,
        offset: Offset(0, 14),
      ),
    ],
  );
}
