import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/breakpoints.dart';

/// Responsive page container.
///
/// Provides:
///   • a [title] / [subtitle] header (omit by passing nulls)
///   • horizontal padding that scales with the breakpoint
///   • a [maxWidth] constraint that centers content on wide screens
///   • optional [leading] (e.g. back button) and [actions] in the header
///   • optional [bottom] widget for sticky CTAs
class PageScaffold extends StatelessWidget {
  const PageScaffold({
    super.key,
    this.title,
    this.subtitle,
    this.leading,
    this.actions = const [],
    this.bottom,
    this.maxWidth = Breakpoints.contentMaxWidth,
    this.backgroundColor,
    this.padding,
    required this.child,
  });

  final String? title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;
  final Widget? bottom;
  final double maxWidth;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isMobile = Breakpoints.isMobile(context);
    final isDesktop = Breakpoints.isDesktop(context);
    final pad = padding ??
        EdgeInsets.symmetric(
          horizontal: isMobile
              ? AppSpacing.pagePadMobile
              : isDesktop
                  ? AppSpacing.pagePadDesktop
                  : AppSpacing.pagePadTablet,
        );

    return Scaffold(
      backgroundColor: backgroundColor ?? AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: Padding(
                      padding: pad,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (title != null || leading != null)
                            _Header(
                              title: title,
                              subtitle: subtitle,
                              leading: leading,
                              actions: actions,
                            ),
                          if (title != null) const SizedBox(height: 18),
                          child,
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (bottom != null)
              Material(
                color: AppColors.surface,
                elevation: 8,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile
                          ? AppSpacing.pagePadMobile
                          : isDesktop
                              ? AppSpacing.pagePadDesktop
                              : AppSpacing.pagePadTablet,
                      vertical: AppSpacing.md,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxWidth),
                        child: bottom!,
                      ),
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

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.leading,
    required this.actions,
  });

  final String? title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                if (subtitle != null) const SizedBox(height: 2),
                if (title != null)
                  Text(
                    title!,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.8,
                    ),
                  ),
              ],
            ),
          ),
          for (final a in actions) ...[
            const SizedBox(width: AppSpacing.sm),
            a,
          ],
        ],
      ),
    );
  }
}
