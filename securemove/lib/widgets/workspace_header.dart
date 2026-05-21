import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

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
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 20),
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
                const SizedBox(height: 2),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.8,
                  ),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            onPressed: onAction,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.accentLight,
              foregroundColor: AppColors.accent,
              fixedSize: const Size(48, 48),
            ),
            icon: Icon(actionIcon),
          ),
        ],
      ),
    );
  }
}
