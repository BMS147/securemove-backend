import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// The standard SecureMove surface card.
///
/// Use this anywhere a piece of content needs to sit on its own surface.
/// Behaviour:
///   • Rounded 20 by default
///   • Subtle elevation via [AppColors.cardShadow]
///   • Hairline border in [AppColors.border]
///   • Tap support — pass [onTap] for hover/press ink ripple
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin,
    this.color,
    this.borderRadius = 20,
    this.onTap,
    this.border = true,
    this.elevated = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final double borderRadius;
  final VoidCallback? onTap;
  final bool border;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);

    Widget card = Container(
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: radius,
        border: border ? Border.all(color: AppColors.border) : null,
        boxShadow: elevated ? const [AppColors.cardShadow] : null,
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );

    if (onTap != null) {
      // If tap is needed, wrap in a Material and InkWell
      card = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: card,
        ),
      );
    }

    if (margin != null) {
      card = Padding(padding: margin!, child: card);
    }
    return card;
  }
}
