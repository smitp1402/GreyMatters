// lib/core/theme/app_colors.dart

import 'package:flutter/material.dart';

/// NeuroLearn colour palette.
///
/// One primary (deep indigo — focus / cognition), one accent (teal — calm /
/// recovery), neutral grays for text and backgrounds. Dark mode variants
/// defined alongside each colour.
abstract final class AppColors {
  // -- Primary --
  static const primary = Color(0xFF3F51B5); // Indigo 500
  static const primaryLight = Color(0xFF7986CB); // Indigo 300
  static const primaryDark = Color(0xFF283593); // Indigo 800

  // -- Accent --
  static const accent = Color(0xFF00897B); // Teal 600
  static const accentLight = Color(0xFF4DB6AC); // Teal 300

  // -- Attention level indicators --
  static const focused = Color(0xFF43A047); // Green 600
  static const drifting = Color(0xFFFFA000); // Amber 700
  static const lost = Color(0xFFE53935); // Red 600

  // -- Band power bars --
  static const theta = Color(0xFF7E57C2); // Deep Purple 400
  static const alpha = Color(0xFF42A5F5); // Blue 400
  static const beta = Color(0xFF66BB6A); // Green 400
  static const gamma = Color(0xFFFFCA28); // Amber 400

  // -- Neutrals --
  static const backgroundLight = Color(0xFFFAFAFA);
  static const backgroundDark = Color(0xFF121212);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const surfaceDark = Color(0xFF1E1E1E);
  static const textPrimary = Color(0xFF212121);
  static const textSecondary = Color(0xFF757575);
  static const textOnPrimary = Color(0xFFFFFFFF);
  static const divider = Color(0xFFE0E0E0);

  // -- Semantic --
  static const error = Color(0xFFD32F2F);
  static const success = Color(0xFF388E3C);
}
