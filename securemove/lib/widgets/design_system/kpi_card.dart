import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'app_card.dart';

/// Single-metric tile for dashboards.
///
///   [label]   — short description ("Total Revenue")
///   [value]   — the big number ("ZMW 12,400")
///   [icon]    — accent glyph shown in a tinted square
///   [delta]   — optional trend chip ("+12% MoM")
///   [accent]  — chip tint color; defaults to brand
class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.delta,
    this.deltaPositive = true,
    this.accentBg,
    this.accentFg,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? delta;
  final bool deltaPositive;
  final Color? accentBg;
  final Color? accentFg;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bg = accentBg ?? AppColors.brandTint;
    final fg = accentFg ?? AppColors.brandPrimary;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: fg, size: 22),
              ),
              const Spacer(),
              if (delta != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: deltaPositive
                        ? AppColors.successTint
                        : AppColors.dangerLight,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    delta!,
                    style: TextStyle(
                      color: deltaPositive
                          ? AppColors.successText
                          : AppColors.dangerText,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.15,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}
