import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTheme {
  static const _fontFamily = 'Roboto';
  static const _fontFallback = ['Arial', 'Segoe UI', 'sans-serif'];

  static ThemeData get light {
    final baseText = ThemeData.light().textTheme;
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.midnight,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.aqua,
        brightness: Brightness.dark,
        surface: AppColors.card,
        primary: AppColors.aqua,
        secondary: AppColors.coral,
        error: AppColors.danger,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      textTheme: baseText.copyWith(
        displaySmall: const TextStyle(
          fontFamily: _fontFamily,
          fontFamilyFallback: _fontFallback,
          fontSize: 36,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        headlineMedium: const TextStyle(
          fontFamily: _fontFamily,
          fontFamilyFallback: _fontFallback,
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        titleLarge: const TextStyle(
          fontFamily: _fontFamily,
          fontFamilyFallback: _fontFallback,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        titleMedium: const TextStyle(
          fontFamily: _fontFamily,
          fontFamilyFallback: _fontFallback,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        bodyLarge: const TextStyle(
          fontFamily: _fontFamily,
          fontFamilyFallback: _fontFallback,
          fontSize: 16,
          height: 1.45,
          color: AppColors.textPrimary,
        ),
        bodyMedium: const TextStyle(
          fontFamily: _fontFamily,
          fontFamilyFallback: _fontFallback,
          fontSize: 14,
          height: 1.45,
          color: AppColors.textSecondary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.cardElevated,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: AppColors.aqua, width: 1.5),
        ),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: AppColors.cardElevated,
        side: BorderSide(color: AppColors.border),
        labelStyle: TextStyle(color: AppColors.textPrimary),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.aqua),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          backgroundColor: AppColors.cardElevated,
        ),
      ),
    );
  }
}
