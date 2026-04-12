// lib/core/theme/app_theme.dart

import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_spacing.dart';

/// NeuroLearn "Cognitive Sanctuary" design system.
///
/// Dark-first theme matching the Stitch UI design references.
/// Uses Inter-style (system sans-serif) for headlines/labels and
/// serif for body text / editorial content.
abstract final class AppTheme {
  // ---------- Dark theme (primary) ----------
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.surface,
        fontFamily: 'Segoe UI', // close to Inter on Windows
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primary,
          onPrimary: AppColors.onPrimary,
          primaryContainer: AppColors.primaryContainer,
          onPrimaryContainer: AppColors.onPrimaryContainer,
          secondary: AppColors.secondary,
          onSecondary: AppColors.onSecondary,
          secondaryContainer: AppColors.secondaryContainer,
          onSecondaryContainer: AppColors.onSecondaryContainer,
          tertiary: AppColors.tertiary,
          onTertiary: AppColors.onTertiary,
          tertiaryContainer: AppColors.tertiaryContainer,
          error: AppColors.error,
          onError: AppColors.onError,
          errorContainer: AppColors.errorContainer,
          onErrorContainer: AppColors.onErrorContainer,
          surface: AppColors.surface,
          onSurface: AppColors.onSurface,
          onSurfaceVariant: AppColors.onSurfaceVariant,
          outline: AppColors.outline,
          outlineVariant: AppColors.outlineVariant,
          inverseSurface: AppColors.inverseSurface,
          onInverseSurface: AppColors.inverseOnSurface,
          inversePrimary: AppColors.inversePrimary,
          surfaceContainerHighest: AppColors.surfaceContainerHighest,
          surfaceContainerHigh: AppColors.surfaceContainerHigh,
          surfaceContainer: AppColors.surfaceContainer,
          surfaceContainerLow: AppColors.surfaceContainerLow,
          surfaceContainerLowest: AppColors.surfaceContainerLowest,
          surfaceBright: AppColors.surfaceBright,
          surfaceDim: AppColors.surfaceDim,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: AppColors.onSurface,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontFamily: 'Segoe UI',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
            letterSpacing: 1.2,
          ),
        ),
        cardTheme: CardTheme(
          color: AppColors.surfaceContainerHigh,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            side: const BorderSide(color: AppColors.outlineVariant, width: 0.5),
          ),
          margin: const EdgeInsets.all(AppSpacing.sm),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryContainer,
            foregroundColor: AppColors.onPrimaryContainer,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.lg,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            textStyle: const TextStyle(
              fontFamily: 'Segoe UI',
              fontWeight: FontWeight.w800,
              fontSize: 14,
              letterSpacing: 2.0,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.onSurface,
            side: const BorderSide(color: AppColors.outlineVariant),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.lg,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            textStyle: const TextStyle(
              fontFamily: 'Segoe UI',
              fontWeight: FontWeight.w700,
              fontSize: 14,
              letterSpacing: 1.5,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surfaceContainerLowest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            borderSide: const BorderSide(color: AppColors.primary, width: 1),
          ),
          hintStyle: const TextStyle(
            color: AppColors.surfaceContainerHighest,
            fontSize: 14,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.lg,
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.surfaceContainer,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.outline,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.outlineVariant,
          thickness: 0.5,
          space: AppSpacing.lg,
        ),
        iconTheme: const IconThemeData(
          color: AppColors.onSurfaceVariant,
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontFamily: 'Segoe UI',
            fontWeight: FontWeight.w900,
            fontSize: 32,
            letterSpacing: 3.0,
            color: AppColors.primary,
          ),
          headlineMedium: TextStyle(
            fontFamily: 'Georgia', // serif, close to Newsreader
            fontWeight: FontWeight.w600,
            fontSize: 28,
            fontStyle: FontStyle.italic,
            color: AppColors.onSurface,
          ),
          headlineSmall: TextStyle(
            fontFamily: 'Segoe UI',
            fontWeight: FontWeight.w700,
            fontSize: 22,
            color: AppColors.onSurface,
          ),
          titleLarge: TextStyle(
            fontFamily: 'Segoe UI',
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: AppColors.onSurface,
          ),
          titleMedium: TextStyle(
            fontFamily: 'Segoe UI',
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: AppColors.onSurface,
          ),
          bodyLarge: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 18,
            fontStyle: FontStyle.italic,
            color: AppColors.onSurfaceVariant,
            height: 1.6,
          ),
          bodyMedium: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 14,
            color: AppColors.onSurfaceVariant,
            height: 1.5,
          ),
          labelLarge: TextStyle(
            fontFamily: 'Segoe UI',
            fontWeight: FontWeight.w700,
            fontSize: 12,
            letterSpacing: 2.0,
            color: AppColors.outline,
          ),
          labelSmall: TextStyle(
            fontFamily: 'Segoe UI',
            fontWeight: FontWeight.w700,
            fontSize: 10,
            letterSpacing: 3.0,
            color: AppColors.outline,
          ),
        ),
      );

  // ---------- Light theme (fallback) ----------
  static ThemeData get light => dark; // v1 is dark-only
}
