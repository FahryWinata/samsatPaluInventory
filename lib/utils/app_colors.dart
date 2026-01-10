import 'package:flutter/material.dart';

class AppColors {
  // Nexus Design System - Palette

  // Primary & Accents
  static const Color primary = Color(0xFF5347CE); // Primary Purple
  static const Color secondary = Color(0xFF887CFD); // Secondary Purple
  static const Color blue = Color(0xFF4896FE); // Blue (Charts/Info)
  static const Color teal = Color(0xFF16C8C7); // Teal (Success/Accent)

  // Semantic Aliases
  static const Color primaryDark = Color(0xFF3F35B0);
  static const Color primaryLight = Color(0xFF887CFD);
  static const Color accent = Color(0xFF16C8C7);
  static const Color accentLight = Color(0xFF4DD0E1);

  // Background Colors
  static const Color background = Color(0xFFF5F6FA); // Very Light Blue/Gray
  static const Color cardBackground = Colors.white;
  static const Color sidebarBackground = Colors.white; // Changed from dark

  // Text Colors
  static const Color textPrimary = Color(0xFF1A1C29); // Nearly Black
  static const Color textSecondary = Color(0xFF9096A2); // Gray
  static const Color textLight = Colors.white;

  // Status Colors
  static const Color success = Color(0xFF16C8C7); // Using Teal for success
  static const Color warning = Color(0xFFFFA726);
  static const Color error = Color(0xFFEF5350);
  static const Color info = Color(0xFF4896FE); // Using Blue for info

  // Asset Status Colors
  static const Color available = Color(0xFF16C8C7); // Teal
  static const Color assigned = Color(0xFF4896FE); // Blue
  static const Color maintenance = Color(0xFFFF7043); // Orange

  // Neutral Colors
  static const Color divider = Color(0xFFEEF0F5);
  static const Color shadow = Color(0x0D000000); // Very subtle shadow
}
