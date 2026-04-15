// lib/core/theme/app_colors.dart

import 'package:flutter/material.dart';

/// NeuroLearn "Cognitive Sanctuary" colour palette.
///
/// Derived from the Stitch design system — dark theme with blue primary,
/// gold tertiary accent, and layered surface containers.
abstract final class AppColors {
  // -- Primary (blue cognitive focus) --
  static const primary = Color(0xFFACC7FF);
  static const primaryContainer = Color(0xFF468FFF);
  static const onPrimary = Color(0xFF002F67);
  static const onPrimaryContainer = Color(0xFF00285A);
  static const primaryFixed = Color(0xFFD7E2FF);
  static const primaryFixedDim = Color(0xFFACC7FF);

  // -- Secondary (muted blue-gray) --
  static const secondary = Color(0xFFB7C8E1);
  static const secondaryContainer = Color(0xFF3A4A5F);
  static const onSecondary = Color(0xFF213145);
  static const onSecondaryContainer = Color(0xFFA9BAD3);

  // -- Tertiary (gold accent) --
  static const tertiary = Color(0xFFFBBC00);
  static const tertiaryContainer = Color(0xFFB88900);
  static const onTertiary = Color(0xFF402D00);

  // -- Surface layers (dark, layered) --
  static const surface = Color(0xFF131313);
  static const surfaceDim = Color(0xFF131313);
  static const surfaceBright = Color(0xFF393939);
  static const surfaceContainerLowest = Color(0xFF0E0E0E);
  static const surfaceContainerLow = Color(0xFF1C1B1B);
  static const surfaceContainer = Color(0xFF201F1F);
  static const surfaceContainerHigh = Color(0xFF2A2A2A);
  static const surfaceContainerHighest = Color(0xFF353534);
  static const surfaceVariant = Color(0xFF353534);

  // -- On-surface text --
  static const onSurface = Color(0xFFE5E2E1);
  static const onSurfaceVariant = Color(0xFFC1C6D7);
  static const onBackground = Color(0xFFE5E2E1);

  // -- Outlines --
  static const outline = Color(0xFF8B90A0);
  static const outlineVariant = Color(0xFF414754);

  // -- Inverse --
  static const inverseSurface = Color(0xFFE5E2E1);
  static const inverseOnSurface = Color(0xFF313030);
  static const inversePrimary = Color(0xFF005CBD);

  // -- Error --
  static const error = Color(0xFFFFB4AB);
  static const errorContainer = Color(0xFF93000A);
  static const onError = Color(0xFF690005);
  static const onErrorContainer = Color(0xFFFFDAD6);

  // -- Attention level indicators --
  static const focused = Color(0xFF43A047);
  static const drifting = Color(0xFFFFA000);
  static const lost = Color(0xFFE53935);

  // -- Band power bars --
  static const delta = Color(0xFFAB47BC); // purple — slow waves
  static const theta = Color(0xFF7E57C2);
  static const alpha = Color(0xFF42A5F5);
  static const beta = Color(0xFF66BB6A);
  static const gamma = Color(0xFFFFCA28);

  // -- Semantic --
  static const success = Color(0xFF388E3C);

  // -- Glass panel --
  static const glassBackground = Color(0x66353534); // 40% opacity
  static const glassBorder = Color(0x33414754);     // 20% opacity
}
