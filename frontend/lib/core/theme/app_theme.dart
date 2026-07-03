import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

class AppTheme {
  static ThemeData get light {
    final baseText = ThemeData.light().textTheme;
    final bodyText = GoogleFonts.loraTextTheme(baseText).apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    );
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
      textTheme: bodyText.copyWith(
        displaySmall: GoogleFonts.cormorantGaramond(
          fontSize: 36,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        headlineMedium: GoogleFonts.cormorantGaramond(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        titleLarge: GoogleFonts.cormorantGaramond(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        titleMedium: GoogleFonts.lora(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        bodyLarge: GoogleFonts.lora(
          fontSize: 16,
          height: 1.45,
          color: AppColors.textPrimary,
        ),
        bodyMedium: GoogleFonts.lora(
          fontSize: 14,
          height: 1.45,
          color: AppColors.textSecondary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.royalBlue.withValues(alpha: 0.72),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(
            color: AppColors.shellstone.withValues(alpha: 0.20),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: AppColors.quicksand, width: 1.4),
        ),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: AppColors.cardElevated,
        side: BorderSide(color: AppColors.border),
        labelStyle: TextStyle(color: AppColors.textPrimary),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.quicksand),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          backgroundColor: AppColors.sapphire.withValues(alpha: 0.42),
        ),
      ),
    );
  }
}

class AppTextStyles {
  static TextStyle get monoLabel => GoogleFonts.ibmPlexMono(
    color: AppColors.textSecondary,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
  );
}
