import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  AppColors._();

  // Core palette — Sapphire / Royal Blue / Quicksand / Swan Wing / Shellstone
  static const Color sapphire = Color(0xFF3C507D);
  static const Color royalBlue = Color(0xFF112250);
  static const Color quicksand = Color(0xFFE0C68F);
  static const Color swanWing = Color(0xFFF5F0E9);
  static const Color shellstone = Color(0xFFD8CBC2);

  // Semantic mapping
  static const Color background = royalBlue;
  static const Color surface = sapphire;
  static const Color textPrimary = swanWing;
  static const Color textSecondary = shellstone;
  static const Color accentWarm = quicksand;
  static const Color accentCool = sapphire;
  static const Color nudgeWarm = Color(0xFF997953);
}

class AppDurations {
  AppDurations._();
  static const Duration transition = Duration(milliseconds: 400);
  static const Duration transitionSlow = Duration(milliseconds: 600);
}

class AppTextStyles {
  AppTextStyles._();

  static TextStyle display({double fontSize = 48, Color? color}) {
    return GoogleFonts.cormorantGaramond(
      fontSize: fontSize,
      fontWeight: FontWeight.w300,
      color: color ?? AppColors.textPrimary,
      letterSpacing: 0.5,
      height: 1.2,
    );
  }

  static TextStyle body({
    double fontSize = 16,
    Color? color,
    FontStyle? fontStyle,
  }) {
    return GoogleFonts.lora(
      fontSize: fontSize,
      fontWeight: FontWeight.w400,
      fontStyle: fontStyle ?? FontStyle.normal,
      color: color ?? AppColors.textPrimary,
      height: 1.6,
    );
  }

  static TextStyle mono({double fontSize = 12, Color? color}) {
    return GoogleFonts.ibmPlexMono(
      fontSize: fontSize,
      fontWeight: FontWeight.w400,
      color: color ?? AppColors.textSecondary,
      letterSpacing: 1.4,
    );
  }
}

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        surface: AppColors.surface,
        primary: AppColors.accentWarm,
        secondary: AppColors.accentCool,
      ),
    );
  }
}

class FadeThroughPageTransitionsBuilder extends PageTransitionsBuilder {
  const FadeThroughPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
      child: child,
    );
  }
}
