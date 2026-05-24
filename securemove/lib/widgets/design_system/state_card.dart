import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'app_card.dart';

/// Centered empty / error / success state.
///
/// Used in screens that load remote data — replaces the various inline
/// "_StateCard / _BusStateCard" copies scattered through the app.
class StateCard extends StatelessWidget {
  const StateCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.kind = StateKind.neutral,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final Future<void> Function()? onAction;
  final StateKind kind;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (kind) {
      StateKind.success => (AppColors.successTint, AppColors.successText),
      StateKind.warning => (AppColors.warningTint, AppColors.warningText),
      StateKind.danger  => (AppColors.dangerLight, AppColors.dangerText),
      StateKind.neutral => (AppColors.brandTint, AppColors.brandPrimary),
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: AppCard(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Icon(icon, color: fg, size: 34),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 22),
                  ElevatedButton(
                    onPressed: () => onAction!(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandVivid,
                      foregroundColor: AppColors.textOnBrand,
                    ),
                    child: Text(actionLabel!),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum StateKind { neutral, success, warning, danger }
