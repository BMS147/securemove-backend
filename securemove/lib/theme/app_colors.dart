import 'package:flutter/material.dart';

/// SecureMove design tokens.
///
/// Two brand families coexist:
///   • `brand*`     — the royal-blue gradient used on customer-facing screens
///                    (auth, home, landing, profile, payment).
///   • `accent*`    — indigo, used on role workspaces (admin/company/conductor).
///
/// Both are exposed here so screens have a single source of truth and the
/// app no longer needs to hardcode hex literals.
class AppColors {
  AppColors._();

  // ---------------------------------------------------------------------------
  // Core surfaces
  // ---------------------------------------------------------------------------
  static const surface = Color(0xFFFFFFFF);
  static const background = Color(0xFFF8FAFC);
  static const border = Color(0xFFE2E8F0);

  // ---------------------------------------------------------------------------
  // Text
  // ---------------------------------------------------------------------------
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF64748B);
  static const textMuted = Color(0xFF94A3B8);
  static const textOnBrand = Color(0xFFFFFFFF);
  static const textOnBrandSoft = Color(0xE8FFFFFF);

  // ---------------------------------------------------------------------------
  // Brand — royal blue family (customer flow)
  // ---------------------------------------------------------------------------
  /// Deepest brand blue — backgrounds, top of gradients, button text on white.
  static const brandDeep = Color(0xFF17357E);

  /// Mid brand blue — primary call-to-action text, icon tint.
  static const brandPrimary = Color(0xFF244AA8);

  /// Bright brand blue — primary buttons, vivid accents.
  static const brandVivid = Color(0xFF3564F2);

  /// Sky blue — bottom of gradients, subtle accents.
  static const brandSky = Color(0xFF72C8FF);

  /// Soft tinted background — icon chips, pill backgrounds, hover states.
  static const brandTint = Color(0xFFEFF4FF);

  /// Very faint blue wash — inset cards, search-field backgrounds.
  static const brandWash = Color(0xFFF8FBFF);

  /// Border color on tinted cards.
  static const brandBorder = Color(0xFFDCE6FA);

  // ---------------------------------------------------------------------------
  // Accent — indigo family (role workspaces, kept for back-compat)
  // ---------------------------------------------------------------------------
  static const primary = Color(0xFF1A1A2E);
  static const accent = Color(0xFF4F46E5);
  static const accentLight = Color(0xFFEEF2FF);

  // ---------------------------------------------------------------------------
  // Status
  // ---------------------------------------------------------------------------
  static const success = Color(0xFF10B981);
  static const successDeep = Color(0xFF059669);
  static const successTint = Color(0xFFEAFBF4);
  static const successText = Color(0xFF237A50);
  static const warning = Color(0xFFF59E0B);
  static const warningTint = Color(0xFFFFF7E8);
  static const warningText = Color(0xFFAA6708);
  static const danger = Color(0xFFEF4444);
  static const dangerLight = Color(0xFFFEF2F2);
  static const dangerText = Color(0xFFC44B2C);
  static const neutralTint = Color(0xFFF4F7FD);
  static const neutralText = Color(0xFF5E6C87);

  // ---------------------------------------------------------------------------
  // Reusable gradients
  // ---------------------------------------------------------------------------
  static const brandGradient = LinearGradient(
    colors: [brandDeep, brandVivid, brandSky],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const brandGradientShort = LinearGradient(
    colors: [brandDeep, brandVivid],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const surfaceGradient = LinearGradient(
    colors: [Color(0xFFF4F7FB), Color(0xFFE8F0FF), Color(0xFFD8E6FF)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ---------------------------------------------------------------------------
  // Shadows
  // ---------------------------------------------------------------------------
  static const cardShadow = BoxShadow(
    color: Color(0x100F2554),
    blurRadius: 24,
    offset: Offset(0, 14),
  );

  static const elevatedShadow = BoxShadow(
    color: Color(0x100F2554),
    blurRadius: 32,
    offset: Offset(0, 18),
  );
}
