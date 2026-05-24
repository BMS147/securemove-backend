import 'package:flutter/material.dart';

/// Responsive breakpoints for SecureMove.
///
/// We design for three sizes:
///   • mobile  ( < 600 )  — single-column, bottom nav, full-bleed cards
///   • tablet  ( 600 - 1023 ) — slightly relaxed paddings, still single column
///   • desktop ( ≥ 1024 ) — multi-column layouts, side rail, max-width content
class Breakpoints {
  Breakpoints._();

  static const double mobile = 600;
  static const double desktop = 1024;
  static const double wide = 1440;

  /// Content max-width — wide enough to be informative on huge monitors,
  /// narrow enough to keep line length readable.
  static const double contentMaxWidth = 1200;

  /// Narrow column max width — forms, single-column content.
  static const double formMaxWidth = 520;

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < mobile;

  static bool isTablet(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return w >= mobile && w < desktop;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= desktop;

  static bool isWide(BuildContext context) =>
      MediaQuery.of(context).size.width >= wide;
}
