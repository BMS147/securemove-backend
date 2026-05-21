import 'package:flutter/material.dart';

import 'auth_service.dart';

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

    return _SecurityActivityData(
      profile: profile,
      logs: logs,
    );
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Security Activity'),
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

            return _SecurityState(
              title: 'Could not load activity',
              message: message,
              actionLabel: 'Try again',
              onAction: _refresh,
            );
          }

          final data = snapshot.data;
          if (data == null || data.logs.isEmpty) {
            return _SecurityState(
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
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF12306D), Color(0xFF2E63E8), Color(0xFF7BC8FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          isAdminView ? 'System-wide monitor' : 'Account activity',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isAdminView
                            ? 'Live security activity'
                            : 'Recent security activity',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isAdminView
                            ? 'System Admin accounts can request the latest logs across the system. Fraud alerts appear after three consecutive failed logins for the same email.'
                            : 'Review your latest sign-ins, failed attempts, and alerts in one place.',
                        style: const TextStyle(
                          color: Color(0xE8FFFFFF),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: _MetricTile(
                              value: '${metrics.total}',
                              label: 'Events',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _MetricTile(
                              value: '${metrics.failed}',
                              label: 'Failed',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _MetricTile(
                              value: '${metrics.alerts}',
                              label: 'Alerts',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Recent timeline',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                ...data.logs.map((log) => _AuditLogCard(log: log)),
              ],
            ),
          );
        },
      ),
    );
  }
}

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
      if (log.eventType == 'login_failed') {
        failed++;
      }
      if (log.eventType == 'fraud_alert') {
        alerts++;
      }
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
  const _SecurityActivityData({
    required this.profile,
    required this.logs,
  });

  final UserProfile? profile;
  final List<SecurityAuditEvent> logs;
}

class _SecurityState extends StatelessWidget {
  const _SecurityState({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String message;
  final String actionLabel;
  final Future<void> Function() onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.admin_panel_settings_outlined,
              size: 42,
              color: Color(0xFF325FE3),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              message,
              style: const TextStyle(
                color: Color(0xFF5E6C87),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () {
                onAction();
              },
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuditLogCard extends StatelessWidget {
  const _AuditLogCard({
    required this.log,
  });

  final SecurityAuditEvent log;

  @override
  Widget build(BuildContext context) {
    final severityColor = switch (log.severity) {
      'high' => const Color(0xFFD64545),
      'medium' => const Color(0xFFE38A22),
      _ => const Color(0xFF2F7D32),
    };
    final icon = switch (log.eventType) {
      'login_success' => Icons.verified_user_rounded,
      'login_failed' => Icons.gpp_bad_rounded,
      'fraud_alert' => Icons.warning_amber_rounded,
      'register_success' => Icons.person_add_alt_1_rounded,
      _ => Icons.history_rounded,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x100F2554),
            blurRadius: 24,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: severityColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: severityColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      log.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      log.summary,
                      style: const TextStyle(
                        color: Color(0xFF5E6C87),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: severityColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  log.severityLabel,
                  style: TextStyle(
                    color: severityColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _LogChip(
                icon: Icons.schedule_rounded,
                label: _formatDateTime(log.createdAt),
              ),
              if (log.email != null && log.email!.isNotEmpty)
                _LogChip(
                  icon: Icons.mail_outline_rounded,
                  label: log.email!,
                ),
              if (log.eventType == 'fraud_alert')
                _LogChip(
                  icon: Icons.shield_moon_outlined,
                  label: 'Escalated',
                ),
              if (log.ipAddress != null && log.ipAddress!.isNotEmpty)
                _LogChip(
                  icon: Icons.language_rounded,
                  label: log.ipAddress!,
                ),
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

  static String _formatDateTime(DateTime value) {
    final date =
        '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
    final hour = value.hour == 0 ? 12 : (value.hour > 12 ? value.hour - 12 : value.hour);
    final minute = value.minute.toString().padLeft(2, '0');
    final suffix = value.hour >= 12 ? 'PM' : 'AM';
    return '$date $hour:$minute $suffix';
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xE8FFFFFF),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _LogChip extends StatelessWidget {
  const _LogChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FC),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF325FE3)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF44526C),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
