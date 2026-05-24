import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Rounded status pill — paid / pending / failed / etc.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    this.kind,
    this.icon,
  });

  final String label;
  final StatusKind? kind;
  final IconData? icon;

  /// Auto-detect the kind from common string labels.
  factory StatusPill.fromLabel(String label) {
    final k = switch (label.toLowerCase().trim()) {
      'paid'      || 'successful' || 'completed' || 'approved' || 'active'
        => StatusKind.success,
      'reserved'  || 'pending'    || 'processing'
        => StatusKind.info,
      'cancelled' || 'failed'     || 'declined'  || 'expired'
        => StatusKind.danger,
      'warning'   || 'pay-offline'
        => StatusKind.warning,
      _ => StatusKind.neutral,
    };
    return StatusPill(label: label, kind: k);
  }

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (kind ?? StatusKind.neutral) {
      StatusKind.success => (AppColors.successTint, AppColors.successText),
      StatusKind.info    => (AppColors.brandTint, AppColors.brandPrimary),
      StatusKind.warning => (AppColors.warningTint, AppColors.warningText),
      StatusKind.danger  => (AppColors.dangerLight, AppColors.dangerText),
      StatusKind.neutral => (AppColors.neutralTint, AppColors.neutralText),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

enum StatusKind { neutral, info, success, warning, danger }
