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
    final controller = TextEditingController(text: schedule.price);
    String? validationMessage;
    bool isSaving = false;

    final updated = await showModalBottomSheet<CompanySchedule>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> submit() async {
              final price = controller.text.trim();
              if (price.isEmpty) {
                setModalState(() => validationMessage = 'Enter a ticket price.');
                return;
              }

              setModalState(() {
                isSaving = true;
                validationMessage = null;
              });

              try {
                final result = await _companyService.updateSchedule(
                  companyId: widget.company.companyId,
                  scheduleId: schedule.scheduleId,
                  price: price,
                );
                if (sheetContext.mounted) {
                  Navigator.pop(sheetContext, result);
                }
              } on AuthException catch (error) {
                setModalState(() {
                  validationMessage = error.message;
                  isSaving = false;
                });
              }
            }

            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
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
                      schedule.routeLabel,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Departure ${schedule.departureTime}',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        labelText: 'Ticket price',
                        prefixIcon: Icon(Icons.payments_outlined),
                      ),
                    ),
                    if (validationMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        validationMessage!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    ElevatedButton.icon(
                      onPressed: isSaving ? null : submit,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Update price'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    controller.dispose();

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
