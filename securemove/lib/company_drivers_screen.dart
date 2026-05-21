import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'company_service.dart';
import 'driver.dart';

class CompanyDriversScreen extends StatefulWidget {
  const CompanyDriversScreen({
    super.key,
    required this.company,
  });

  final CompanyRecord company;

  @override
  State<CompanyDriversScreen> createState() => _CompanyDriversScreenState();
}

class _CompanyDriversScreenState extends State<CompanyDriversScreen> {
  final CompanyService _companyService = CompanyService.instance;

  List<DriverProfile> _drivers = const [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDrivers();
  }

  Future<void> _loadDrivers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final drivers = await _companyService.getDrivers(widget.company.companyId);
      if (!mounted) {
        return;
      }
      setState(() => _drivers = drivers);
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

  Future<void> _showAddDriverSheet() async {
    final fullNameController = TextEditingController();
    final licenseController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    String? validationMessage;
    bool isSaving = false;

    final created = await showModalBottomSheet<DriverProfile>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> submit() async {
              final fullName = fullNameController.text.trim();
              final license = licenseController.text.trim().toUpperCase();

              if (fullName.isEmpty || license.isEmpty) {
                setModalState(() {
                  validationMessage = 'Full name and license number are required.';
                });
                return;
              }

              setModalState(() {
                isSaving = true;
                validationMessage = null;
              });

              try {
                final driver = await _companyService.createDriver(
                  companyId: widget.company.companyId,
                  fullName: fullName,
                  licenseNumber: license,
                  email: emailController.text,
                  phoneNumber: phoneController.text,
                );

                if (!sheetContext.mounted) {
                  return;
                }

                Navigator.of(sheetContext).pop(driver);
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
                    const Text(
                      'Add driver',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create a company driver record using the new backend driver endpoint.',
                      style: const TextStyle(
                        color: Color(0xFF60708E),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: fullNameController,
                      decoration: const InputDecoration(
                        labelText: 'Full name',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: licenseController,
                      decoration: const InputDecoration(
                        labelText: 'License number',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone number',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.mail_outline_rounded),
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
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isSaving
                                ? null
                                : () => Navigator.of(sheetContext).pop(),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isSaving ? null : submit,
                            child: isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Save driver'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    fullNameController.dispose();
    licenseController.dispose();
    phoneController.dispose();
    emailController.dispose();

    if (created == null || !mounted) {
      return;
    }

    setState(() {
      _drivers = [created, ..._drivers];
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${created.fullName} added to ${widget.company.name}.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.company.name} drivers')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDriverSheet,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add driver'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadDrivers,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 96),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x100F2554),
                    blurRadius: 24,
                    offset: Offset(0, 14),
                  ),
                ],
              ),
              child: const Text(
                'This screen is the first admin/operations rebuild from the cloned repo: live driver records, company-scoped listing, and add-driver flow.',
                style: TextStyle(
                  color: Color(0xFF60708E),
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: Color(0xFF7F2B2B),
                    height: 1.35,
                  ),
                ),
              ),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_drivers.isEmpty)
              const _DriversEmptyState()
            else
              ..._drivers.map(
                (driver) => Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x100F2554),
                        blurRadius: 24,
                        offset: Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF4FF),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(
                          Icons.badge_outlined,
                          color: Color(0xFF284BA8),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              driver.fullName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'License: ${driver.licenseNumber}',
                              style: const TextStyle(
                                color: Color(0xFF60708E),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if ((driver.phoneNumber ?? '').isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                driver.phoneNumber!,
                                style: const TextStyle(
                                  color: Color(0xFF60708E),
                                ),
                              ),
                            ],
                            if ((driver.email ?? '').isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                driver.email!,
                                style: const TextStyle(
                                  color: Color(0xFF60708E),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: driver.isActive
                              ? const Color(0xFFEAFBF4)
                              : const Color(0xFFFFF1F1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          driver.isActive ? 'Active' : 'Inactive',
                          style: TextStyle(
                            color: driver.isActive
                                ? const Color(0xFF0F7A4C)
                                : const Color(0xFF9E3A3A),
                            fontWeight: FontWeight.w700,
                          ),
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
}

class _DriversEmptyState extends StatelessWidget {
  const _DriversEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: const [
          Icon(
            Icons.person_off_outlined,
            size: 42,
            color: Color(0xFF284BA8),
          ),
          SizedBox(height: 12),
          Text(
            'No drivers yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Use the add button to create the first driver record for this company.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF60708E),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
