// lib/core/theme/app_colors.dart

import 'package:flutter/material.dart';

/// GreyMatters "Cryo-Lattice" palette.
///
/// Dark-first aesthetic — obsidian blue-black base, ice-pale content, a
/// single electric-cyan accent that pulses where attention lives. Designed
/// to feel like a medical-grade neural instrument: clean, clinical, with
/// a single sharp color carrying all the energy.
abstract final class AppColors {
  // -- Primary (ice-electric blue) --
  static const primary = Color(0xFF7FD4FF);          // pale electric ice
  static const primaryContainer = Color(0xFF0077FF); // pure electric blue
  static const onPrimary = Color(0xFF001633);
  static const onPrimaryContainer = Color(0xFFD7E8FF);
  static const primaryFixed = Color(0xFFCCE9FF);
  static const primaryFixedDim = Color(0xFF7FD4FF);

  // -- Secondary (cool silver-blue) --
  static const secondary = Color(0xFFB8C7DB);
  static const secondaryContainer = Color(0xFF2A3B52);
  static const onSecondary = Color(0xFF1A2435);
  static const onSecondaryContainer = Color(0xFFC2D3EA);

  // -- Tertiary (neon cyan accent — replaces former gold) --
  static const tertiary = Color(0xFF00E5FF);
  static const tertiaryContainer = Color(0xFF0099A8);
  static const onTertiary = Color(0xFF002A30);
  static const onTertiaryContainer = Color(0xFFCBF7FF);

  // -- Surface layers (obsidian blue-black, cool containers) --
  static const surface = Color(0xFF0A0E1A);                   // page base
  static const surfaceDim = Color(0xFF060912);
  static const surfaceBright = Color(0xFF2A3249);
  static const surfaceContainerLowest = Color(0xFF05080F);
  static const surfaceContainerLow = Color(0xFF111829);
  static const surfaceContainer = Color(0xFF151D30);
  static const surfaceContainerHigh = Color(0xFF1B2540);
  static const surfaceContainerHighest = Color(0xFF222D4C);
  static const surfaceVariant = Color(0xFF222D4C);

  // -- On-surface text --
  static const onSurface = Color(0xFFE5ECF7);        // slightly cooler white
  static const onSurfaceVariant = Color(0xFFB8C7DB); // pale silver-blue
  static const onBackground = Color(0xFFE5ECF7);

  // -- Outlines (cool steel-silver) --
  static const outline = Color(0xFF6D7B98);
  static const outlineVariant = Color(0xFF2A3449);

  // -- Inverse --
  static const inverseSurface = Color(0xFFE5ECF7);
  static const inverseOnSurface = Color(0xFF131A2A);
  static const inversePrimary = Color(0xFF005BCE);

  // -- Error (sci-fi hot-pink, more distinctive than fire-engine red) --
  static const error = Color(0xFFFF7AAD);
  static const errorContainer = Color(0xFF8F0044);
  static const onError = Color(0xFF32001A);
  static const onErrorContainer = Color(0xFFFFD7E6);

  // -- Attention level indicators --
  // "Focused" shares the tertiary cyan so the primary-accent reads as
  // "you are doing the thing we want you to do." Drifting amber is a
  // softer gold; lost becomes hot pink for a tech feel.
  static const focused = Color(0xFF00E5FF);
  static const drifting = Color(0xFFFFB74D);
  static const lost = Color(0xFFFF4A8D);

  // -- Band powers (semantic, unchanged) --
  static const delta = Color(0xFFAB47BC);
  static const theta = Color(0xFF7E57C2);
  static const alpha = Color(0xFF42A5F5);
  static const beta = Color(0xFF66BB6A);
  static const gamma = Color(0xFFFFCA28);

  // -- Semantic --
  static const success = Color(0xFF00E5FF);          // success = focused cyan

  // -- Glass panel --
  static const glassBackground = Color(0x66151D30);  // 40% container
  static const glassBorder = Color(0x332A3449);      // 20% outlineVariant

  // -- Cryo-Lattice signature: cyan glow for BoxShadow/halo effects --
  static const accentGlow = Color(0x4000E5FF);        // 25% cyan
  static const accentGlowStrong = Color(0x8000E5FF);  // 50% cyan
  static const primaryGlow = Color(0x337FD4FF);       // 20% ice blue

  // -- Gradient endpoints commonly composed across screens --
  static const gradientTop = Color(0xFF0A0E1A);
  static const gradientMid = Color(0xFF0C1324);
  static const gradientBottom = Color(0xFF07091A);
}
