import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'auth_service.dart';
import 'theme/app_colors.dart';
import 'theme/breakpoints.dart';
import 'widgets/design_system/app_card.dart';
import 'widgets/design_system/kpi_card.dart';
import 'widgets/design_system/state_card.dart';
import 'widgets/design_system/status_pill.dart';

class SecurityActivityScreen extends StatefulWidget {
  const SecurityActivityScreen({super.key});

  @override
  State<SecurityActivityScreen> createState() => _SecurityActivityScreenState();
}

class _SecurityActivityScreenState extends State<SecurityActivityScreen> {
  late Future<_SecurityActivityData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_SecurityActivityData> _load() async {
    final profile = await AuthService.instance.getCurrentUserProfile();
    final logs = await AuthService.instance.getSecurityAuditEvents(
      limit: 30,
      includeAllAvailable: true,
    );
    return _SecurityActivityData(profile: profile, logs: logs);
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Breakpoints.isDesktop(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Security activity',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: FutureBuilder<_SecurityActivityData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            final message = snapshot.error is AuthException
                ? (snapshot.error as AuthException).message
                : 'Unable to load security activity.';
            return StateCard(
              icon: Icons.cloud_off_rounded,
              title: 'Could not load activity',
              message: message,
              actionLabel: 'Try again',
              onAction: _refresh,
              kind: StateKind.danger,
            );
          }

          final data = snapshot.data;
          if (data == null || data.logs.isEmpty) {
            return StateCard(
              icon: Icons.shield_outlined,
              title: 'No activity yet',
              message:
                  'Sign in, attempt a failed login, or create an account to populate the audit trail.',
              actionLabel: 'Refresh',
              onAction: _refresh,
            );
          }

          final isAdminView = data.profile?.roleId == 3;
          final metrics = _SecurityMetrics.fromLogs(data.logs);

          return RefreshIndicator(
            onRefresh: _refresh,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: Breakpoints.contentMaxWidth,
                ),
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    isDesktop ? 32 : 20,
                    8,
                    isDesktop ? 32 : 20,
                    28,
                  ),
                  children: [
                    _HeroBanner(
                      isAdminView: isAdminView,
                      metrics: metrics,
                    ),
                    const SizedBox(height: 22),
                    if (isDesktop)
                      Row(
                        children: [
                          Expanded(
                            child: KpiCard(
                              icon: Icons.history_rounded,
                              label: 'Total events',
                              value: '${metrics.total}',
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: KpiCard(
                              icon: Icons.gpp_bad_rounded,
                              label: 'Failed logins',
                              value: '${metrics.failed}',
                              accentBg: AppColors.dangerLight,
                              accentFg: AppColors.dangerText,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: KpiCard(
                              icon: Icons.warning_amber_rounded,
                              label: 'Fraud alerts',
                              value: '${metrics.alerts}',
                              accentBg: AppColors.warningTint,
                              accentFg: AppColors.warningText,
                            ),
                          ),
                        ],
                      ),
                    if (isDesktop) const SizedBox(height: 22),
                    const Text(
                      'Recent timeline',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (isDesktop)
                      _AuditTable(logs: data.logs)
                    else
                      ...data.logs.map(
                        (log) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _AuditLogCard(log: log),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ===========================================================================
// Hero banner
// ===========================================================================

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.isAdminView, required this.metrics});

  final bool isAdminView;
  final _SecurityMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              isAdminView ? 'System-wide monitor' : 'Account activity',
              style: const TextStyle(
                color: AppColors.textOnBrand,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            isAdminView
                ? 'Live security activity'
                : 'Recent security activity',
            style: const TextStyle(
              color: AppColors.textOnBrand,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isAdminView
                ? 'Admin accounts see security events across the platform. Fraud alerts trigger after three consecutive failed logins for the same email.'
                : 'Review your latest sign-ins, failed attempts, and security alerts.',
            style: const TextStyle(
              color: AppColors.textOnBrandSoft,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Desktop audit table
// ===========================================================================

class _AuditTable extends StatelessWidget {
  const _AuditTable({required this.logs});

  final List<SecurityAuditEvent> logs;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerTheme: const DividerThemeData(
            color: AppColors.border,
            space: 1,
          ),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: MediaQuery.of(context).size.width - 64 - 240,
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
              columns: const [
                DataColumn(label: Text('EVENT')),
                DataColumn(label: Text('USER')),
                DataColumn(label: Text('SEVERITY')),
                DataColumn(label: Text('STATUS')),
                DataColumn(label: Text('IP')),
                DataColumn(label: Text('TIME')),
              ],
              rows: logs.map((log) {
                final severityKind = switch (log.severity) {
                  'high' => StatusKind.danger,
                  'medium' => StatusKind.warning,
                  _ => StatusKind.success,
                };
                return DataRow(
                  cells: [
                    DataCell(
                      Row(
                        children: [
                          Icon(
                            _iconFor(log.eventType),
                            size: 16,
                            color: AppColors.brandPrimary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            log.title,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    DataCell(Text(log.email ?? '—')),
                    DataCell(StatusPill(
                      label: log.severityLabel,
                      kind: severityKind,
                    )),
                    DataCell(Text(log.status.replaceAll('_', ' '))),
                    DataCell(Text(log.ipAddress ?? '—')),
                    DataCell(Text(
                      DateFormat('d MMM HH:mm').format(log.createdAt),
                    )),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  static IconData _iconFor(String eventType) => switch (eventType) {
        'login_success' => Icons.verified_user_rounded,
        'login_failed' => Icons.gpp_bad_rounded,
        'fraud_alert' => Icons.warning_amber_rounded,
        'register_success' => Icons.person_add_alt_1_rounded,
        _ => Icons.history_rounded,
      };
}

// ===========================================================================
// Mobile audit-log card
// ===========================================================================

class _AuditLogCard extends StatelessWidget {
  const _AuditLogCard({required this.log});

  final SecurityAuditEvent log;

  @override
  Widget build(BuildContext context) {
    final severityKind = switch (log.severity) {
      'high' => StatusKind.danger,
      'medium' => StatusKind.warning,
      _ => StatusKind.success,
    };
    final (severityBg, severityFg) = switch (severityKind) {
      StatusKind.danger => (AppColors.dangerLight, AppColors.dangerText),
      StatusKind.warning => (AppColors.warningTint, AppColors.warningText),
      _ => (AppColors.successTint, AppColors.successText),
    };
    final icon = switch (log.eventType) {
      'login_success' => Icons.verified_user_rounded,
      'login_failed' => Icons.gpp_bad_rounded,
      'fraud_alert' => Icons.warning_amber_rounded,
      'register_success' => Icons.person_add_alt_1_rounded,
      _ => Icons.history_rounded,
    };

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: severityBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: severityFg, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      log.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      log.summary,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        height: 1.4,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusPill(label: log.severityLabel, kind: severityKind),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _LogChip(
                icon: Icons.schedule_rounded,
                label: DateFormat('d MMM HH:mm').format(log.createdAt),
              ),
              if (log.email != null && log.email!.isNotEmpty)
                _LogChip(icon: Icons.mail_outline_rounded, label: log.email!),
              if (log.ipAddress != null && log.ipAddress!.isNotEmpty)
                _LogChip(icon: Icons.language_rounded, label: log.ipAddress!),
              _LogChip(
                icon: Icons.flag_outlined,
                label: log.status.replaceAll('_', ' '),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LogChip extends StatelessWidget {
  const _LogChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.neutralTint,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.brandPrimary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.neutralText,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Data classes
// ===========================================================================

class _SecurityMetrics {
  const _SecurityMetrics({
    required this.total,
    required this.failed,
    required this.alerts,
  });

  factory _SecurityMetrics.fromLogs(List<SecurityAuditEvent> logs) {
    var failed = 0;
    var alerts = 0;
    for (final log in logs) {
      if (log.eventType == 'login_failed') failed++;
      if (log.eventType == 'fraud_alert') alerts++;
    }
    return _SecurityMetrics(
      total: logs.length,
      failed: failed,
      alerts: alerts,
    );
  }

  final int total;
  final int failed;
  final int alerts;
}

class _SecurityActivityData {
  const _SecurityActivityData({required this.profile, required this.logs});

  final UserProfile? profile;
  final List<SecurityAuditEvent> logs;
}
