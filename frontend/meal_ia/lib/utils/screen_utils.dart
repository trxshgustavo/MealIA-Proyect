import 'package:flutter/material.dart';

/// Utilidades para obtener dimensiones de pantalla de forma global
class ScreenUtils {
  /// Obtiene el ancho de la pantalla
  static double getWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  /// Obtiene el alto de la pantalla
  static double getHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }

  /// Calcula el margen horizontal proporcional (2% del ancho)
  static double getHorizontalMargin(BuildContext context) {
    return getWidth(context) * 0.02;
  }

  /// Calcula el margen vertical proporcional (3% del alto)
  static double getVerticalMargin(BuildContext context) {
    return getHeight(context) * 0.03;
  }

  /// Ancho máximo para botones y formularios
  static double getMaxFormWidth(BuildContext context) {
    final width = getWidth(context);
    return width < 400 ? width * 0.9 : 300;
  }

  /// Altura estándar para botones
  static double getStandardButtonHeight(BuildContext context) {
    return getHeight(context) * 0.07;
  }

  /// Radio estándar para bordes redondeados
  static double getStandardBorderRadius(BuildContext context) {
    return getWidth(context) * 0.02;
  }

  /// Tamaño de fuente proporcional al ancho de pantalla
  static double getProportionalFontSize(BuildContext context, double scale) {
    return getWidth(context) * scale;
  }

  /// Detecta si es una pantalla pequeña (menor a 600px de ancho)
  static bool isSmallScreen(BuildContext context) {
    return getWidth(context) < 600;
  }

  /// Detecta si es una pantalla muy pequeña en altura (menor a 600px)
  static bool isVerySmallHeight(BuildContext context) {
    return getHeight(context) < 600;
  }

  /// Detecta si es una pantalla mediana (600-1200px de ancho)
  static bool isMediumScreen(BuildContext context) {
    final width = getWidth(context);
    return width >= 600 && width < 1200;
  }

  /// Detecta si es una pantalla grande (mayor a 1200px de ancho)
  static bool isLargeScreen(BuildContext context) {
    return getWidth(context) >= 1200;
  }

  /// Obtiene padding horizontal responsive
  static double getResponsiveHorizontalPadding(BuildContext context) {
    if (isSmallScreen(context)) return 16.0;
    if (isMediumScreen(context)) return 24.0;
    return 32.0;
  }

  /// Obtiene padding vertical responsive
  static double getResponsiveVerticalPadding(BuildContext context) {
    if (isVerySmallHeight(context)) return 16.0;
    if (isSmallScreen(context)) return 24.0;
    return 32.0;
  }

  /// Obtiene tamaño de fuente para títulos principales
  static double getTitleFontSize(
    BuildContext context, {
    double defaultSize = 50.0,
  }) {
    if (isSmallScreen(context)) {
      return (getWidth(context) * 0.08).clamp(24.0, defaultSize);
    }
    return defaultSize;
  }

  /// Obtiene tamaño de fuente para subtítulos
  static double getSubtitleFontSize(
    BuildContext context, {
    double defaultSize = 20.0,
  }) {
    if (isSmallScreen(context)) {
      return (getWidth(context) * 0.035).clamp(14.0, defaultSize);
    }
    return defaultSize;
  }

  /// Obtiene tamaño de fuente para botones
  static double getButtonFontSize(
    BuildContext context, {
    double defaultSize = 18.0,
  }) {
    if (isSmallScreen(context)) {
      return 16.0;
    }
    return defaultSize;
  }

  /// Obtiene espaciado vertical responsive
  static double getVerticalSpacing(
    BuildContext context, {
    double defaultSpacing = 60.0,
  }) {
    if (isVerySmallHeight(context)) return defaultSpacing * 0.33;
    if (isSmallScreen(context)) return defaultSpacing * 0.67;
    return defaultSpacing;
  }

  /// Obtiene altura máxima para imágenes
  static double getImageHeight(
    BuildContext context, {
    double defaultHeight = 350.0,
  }) {
    if (isVerySmallHeight(context)) {
      return (getHeight(context) * 0.25).clamp(150.0, defaultHeight);
    }
    if (isSmallScreen(context)) {
      return (getHeight(context) * 0.3).clamp(200.0, defaultHeight);
    }
    return (getHeight(context) * 0.35).clamp(250.0, defaultHeight);
  }

  /// Obtiene padding para botones
  static EdgeInsets getButtonPadding(BuildContext context) {
    final vertical = isSmallScreen(context) ? 12.0 : 16.0;
    return EdgeInsets.symmetric(vertical: vertical);
  }

  /// Obtiene el ancho máximo para contenedores centrados en pantallas grandes
  static double getMaxContainerWidth(BuildContext context) {
    final width = getWidth(context);
    if (width > 1200) return 1000.0;
    if (width > 800) return width * 0.75;
    return width;
  }

  /// Calcula tamaño de imagen responsive
  static double getResponsiveImageSize(
    BuildContext context, {
    double baseSize = 280.0,
  }) {
    if (isVerySmallHeight(context)) return baseSize * 0.5;
    if (isSmallScreen(context)) return baseSize * 0.7;
    return baseSize;
  }

  /// Obtiene padding responsive para formularios
  static EdgeInsets getFormPadding(BuildContext context) {
    if (isSmallScreen(context)) return const EdgeInsets.all(20.0);
    if (isMediumScreen(context)) return const EdgeInsets.all(28.0);
    return const EdgeInsets.all(32.0);
  }

  /// Obtiene ancho para cajas de diálogo responsive
  static double getDialogWidth(BuildContext context) {
    final width = getWidth(context);
    if (width > 600) return 500.0;
    return width * 0.9;
  }

  /// Espaciado entre elementos responsive
  static double getElementSpacing(
    BuildContext context, {
    double defaultSpacing = 20.0,
  }) {
    if (isVerySmallHeight(context)) return defaultSpacing * 0.5;
    if (isSmallScreen(context)) return defaultSpacing * 0.75;
    return defaultSpacing;
  }

  /// Tamaño de iconos responsive
  static double getIconSize(BuildContext context, {double defaultSize = 24.0}) {
    if (isSmallScreen(context)) return defaultSize * 0.9;
    return defaultSize;
  }

  /// Altura de AppBar responsive
  static double getAppBarHeight(BuildContext context) {
    if (isSmallScreen(context)) return 56.0;
    return 64.0;
  }

  /// Card elevation responsive
  static double getCardElevation(
    BuildContext context, {
    double defaultElevation = 4.0,
  }) {
    if (isSmallScreen(context)) return defaultElevation * 0.75;
    return defaultElevation;
  }
}
