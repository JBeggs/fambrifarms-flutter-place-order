import 'package:flutter/material.dart';

class AppTheme {
  // Farm-themed color palette with high contrast
  static const Color primaryColor = Color(0xFF2D5016); // Dark farm green
  static const Color primaryVariant = Color(0xFF1A3009); // Darker green
  static const Color secondaryColor = Color(0xFF8B4513); // Earthy brown
  static const Color secondaryVariant = Color(0xFF654321); // Darker brown
  static const Color errorColor = Color(0xFFDC2626);
  static const Color warningColor = Color(0xFFD97706);
  static const Color successColor = Color(0xFF16A34A);
  static const Color infoColor = Color(0xFF0EA5E9);
  
  // VERY DARK theme colors for maximum visibility
  static const Color surfaceLight = Color(0xFF1A1A1A); // Very dark surface
  static const Color surfaceDark = Color(0xFF0F0F0F); // Extremely dark surface  
  static const Color backgroundLight = Color(0xFF121212); // Very dark background
  static const Color backgroundDark = Color(0xFF000000); // Pure black background
  
  // High contrast text colors
  static const Color textPrimaryLight = Color(0xFFFFFFFF); // White text
  static const Color textSecondaryLight = Color(0xFFE0E0E0); // Light gray text
  static const Color textPrimaryDark = Color(0xFFFFFFFF); // White text
  static const Color textSecondaryDark = Color(0xFFB0B0B0); // Gray text
  
  // MAXIMUM CONTRAST input field colors
  static const Color inputBorderLight = Color(0xFF00FF00); // Bright green border for visibility
  static const Color inputBorderDark = Color(0xFF00FF00); // Bright green border
  static const Color inputFillLight = Color(0xFF2A2A2A); // Dark input background
  static const Color inputFillDark = Color(0xFF1A1A1A); // Darker input background
  
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark, // Use dark brightness for better contrast
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        primaryContainer: Color(0xFF3D6B1F), // Lighter green container
        secondary: secondaryColor,
        secondaryContainer: Color(0xFFA0561A), // Lighter brown container
        error: errorColor,
        errorContainer: Color(0xFF8B1538),
        surface: surfaceLight,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onError: Colors.white,
        onSurface: textPrimaryLight,
      ),
      
      // Enhanced typography with better readability
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: textPrimaryLight,
          letterSpacing: -0.5,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: textPrimaryLight,
          letterSpacing: -0.25,
        ),
        displaySmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: textPrimaryLight,
        ),
        headlineLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: textPrimaryLight,
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimaryLight,
        ),
        headlineSmall: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimaryLight,
        ),
        titleLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimaryLight,
        ),
        titleMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textPrimaryLight,
        ),
        titleSmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textSecondaryLight,
        ),
        bodyLarge: TextStyle(
          color: Color(0xFFFFFFFF), // WHITE input text for maximum visibility
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        bodyMedium: TextStyle(
          color: Color(0xFFFFFFFF), // WHITE input text for maximum visibility
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.normal,
          color: textSecondaryLight,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textPrimaryLight,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textSecondaryLight,
        ),
        labelSmall: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: textSecondaryLight,
        ),
      ),
      
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: backgroundLight,
        foregroundColor: textPrimaryLight,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimaryLight,
        ),
      ),
      
      cardTheme: CardThemeData(
        elevation: 2,
        color: backgroundLight,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 2,
        ),
      ),
      
      // ULTRA HIGH CONTRAST input decoration for MAXIMUM visibility
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFillLight, // Dark background for input
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF00FF00), width: 3), // BRIGHT GREEN border
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF00FF00), width: 3), // BRIGHT GREEN border
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF00FFFF), width: 4), // CYAN focus border
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFFF0000), width: 3), // BRIGHT RED error
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFFF0000), width: 4), // BRIGHT RED error focus
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20), // Extra padding
        labelStyle: const TextStyle(
          color: Color(0xFFFFFFFF), // PURE WHITE label text
          fontSize: 18, // Larger font
          fontWeight: FontWeight.w700, // Extra bold text
        ),
        floatingLabelStyle: const TextStyle(
          color: Color(0xFF00FF00), // BRIGHT GREEN floating label
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        hintStyle: const TextStyle(
          color: Color(0xFFCCCCCC), // Lighter gray hint
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
  
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        primaryContainer: Color(0xFF1E3A8A),
        secondary: secondaryColor,
        secondaryContainer: Color(0xFF064E3B),
        error: errorColor,
        errorContainer: Color(0xFF7F1D1D),
        surface: surfaceDark,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onError: Colors.white,
        onSurface: textPrimaryDark,
      ),
      
      // Enhanced typography for dark theme
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: textPrimaryDark,
          letterSpacing: -0.5,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: textPrimaryDark,
          letterSpacing: -0.25,
        ),
        displaySmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: textPrimaryDark,
        ),
        headlineLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: textPrimaryDark,
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimaryDark,
        ),
        headlineSmall: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimaryDark,
        ),
        titleLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimaryDark,
        ),
        titleMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textPrimaryDark,
        ),
        titleSmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textSecondaryDark,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: textPrimaryDark,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: textPrimaryDark,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.normal,
          color: textSecondaryDark,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textPrimaryDark,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textSecondaryDark,
        ),
        labelSmall: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: textSecondaryDark,
        ),
      ),
      
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: backgroundDark,
        foregroundColor: textPrimaryDark,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimaryDark,
        ),
      ),
      
      cardTheme: CardThemeData(
        elevation: 2,
        color: surfaceDark,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 2,
        ),
      ),
      
      // Enhanced input decoration for dark theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFillDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: inputBorderDark, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: inputBorderDark, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: errorColor, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: errorColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        labelStyle: const TextStyle(
          color: textSecondaryDark,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: const TextStyle(
          color: textSecondaryDark,
          fontSize: 14,
        ),
      ),
    );
  }
}
