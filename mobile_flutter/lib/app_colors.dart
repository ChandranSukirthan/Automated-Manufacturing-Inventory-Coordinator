import 'package:flutter/material.dart';

abstract final class AppColors {
  // Deep space obsidian & slate backgrounds (matching React #070b14, #0f172a, #1e293b)
  static const background = Color(0xFF070B14);
  static const surface = Color(0xFF0F172A);
  static const surfaceSubtle = Color(0xFF131D33);
  static const card = Color(0xFF0F172A);
  static const cardDark = Color(0xFF0B1120);
  static const nestedSurface = Color(0xFF1E293B);
  static const border = Color(0xFF1E293B);
  static const borderLight = Color(0xFF334155);

  // Typography
  static const strongText = Color(0xFFFFFFFF);
  static const primaryText = Color(0xFFF1F5F9);
  static const secondaryText = Color(0xFFCBD5E1);
  static const mutedText = Color(0xFF94A3B8);
  static const faintText = Color(0xFF64748B);

  // Primary QA Brand (React from-blue-600 to-blue-700)
  static const primary = Color(0xFF2563EB);
  static const primaryHover = Color(0xFF1D4ED8);
  static const primaryLight = Color(0xFF3B82F6);
  static const primaryTextLight = Color(0xFF93C5FD);
  static const primaryBg = Color(0x263B82F6);

  // Cyan / Tech accents (React cyan-400, cyan-300)
  static const info = Color(0xFF06B6D4);
  static const infoBorder = Color(0xFF22D3EE);
  static const infoText = Color(0xFFA5F3FC);
  static const infoBg = Color(0x2606B6D4);

  // Warning / Amber (React amber-400, amber-500)
  static const warning = Color(0xFFF59E0B);
  static const warningAction = Color(0xFFFBBF24);
  static const warningText = Color(0xFFFCD34D);
  static const warningBg = Color(0x26F59E0B);

  // Error / Danger / Rose (React rose-500, rose-400)
  static const error = Color(0xFFEF4444);
  static const errorText = Color(0xFFFCA5A5);
  static const danger = Color(0xFFF43F5E);
  static const dangerText = Color(0xFFFDA4AF);
  static const errorBg = Color(0x26EF4444);

  // Emerald / Success (React emerald-400, emerald-500)
  static const emerald = Color(0xFF10B981);
  static const emeraldLight = Color(0xFF34D399);
  static const emeraldBg = Color(0x2610B981);

  // Backwards compatibility aliases
  static const violet = Color(0xFF3B82F6);
  static const orange = Color(0xFFF97316);
}