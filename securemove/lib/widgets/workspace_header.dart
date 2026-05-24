import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/breakpoints.dart';

/// Standard top-of-screen header for non-shell pages.
///
/// Renders a small subtitle above a large title, with optional trailing
/// icon-action. Padding and font size scale with the breakpoint.
class WorkspaceHeader extends StatelessWidget {
  const WorkspaceHeader({
    super.key,
    required this.title,
    this.subtitle = 'Good morning',
    this.onAction,
    this.actionIcon = Icons.person_rounded,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onAction;
  final IconData actionIcon;

  @override
  Widget build(BuildContext context) {
    final isDesktop = Breakpoints.isDesktop(context);
    final isMobile = Breakpoints.isMobile(context);

    return Container(
      padding: EdgeInsets.fromLTRB(
        isDesktop ? 32 : 24,
        isDesktop ? 28 : 50,
        isDesktop ? 32 : 24,
        18,
      ),
      color: AppColors.background,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isMobile ? 24 : 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.8,
                  ),
                ),
              ],
            ),
          ),
          if (onAction != null)
            IconButton.filledTonal(
              onPressed: onAction,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.brandTint,
                foregroundColor: AppColors.brandPrimary,
                fixedSize: const Size(48, 48),
              ),
              icon: Icon(actionIcon),
            ),
        ],
      ),
    );
  }
}
