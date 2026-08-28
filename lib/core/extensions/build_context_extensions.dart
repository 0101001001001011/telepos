import 'package:flutter/material.dart';
import 'package:telepos/l10n/app_localizations.dart';

extension BuildContextExtensions on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;

  AppLocalizations? get l10nOrNull => AppLocalizations.of(this);

  Locale get locale => Localizations.localeOf(this);

  ThemeData get theme => Theme.of(this);

  TextTheme get textTheme => Theme.of(this).textTheme;

  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  MediaQueryData get mediaQuery => MediaQuery.of(this);

  Size get screenSize => MediaQuery.sizeOf(this);

  double get screenWidth => MediaQuery.sizeOf(this).width;

  double get screenHeight => MediaQuery.sizeOf(this).height;

  bool get isLandscape =>
      MediaQuery.orientationOf(this) == Orientation.landscape;

  bool get isPortrait => MediaQuery.orientationOf(this) == Orientation.portrait;

  double get devicePixelRatio => MediaQuery.devicePixelRatioOf(this);

  double get textScaleFactor =>
      MediaQuery.textScaleFactorOf(this); // ignore: deprecated_member_use

  EdgeInsets get viewPadding => MediaQuery.viewPaddingOf(this);

  EdgeInsets get viewInsets => MediaQuery.viewInsetsOf(this);

  bool get isKeyboardVisible => MediaQuery.viewInsetsOf(this).bottom > 0;

  Brightness get platformBrightness => MediaQuery.platformBrightnessOf(this);

  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  void showSnackBar(String message, {Duration? duration}) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration ?? const Duration(seconds: 4),
      ),
    );
  }

  void showErrorSnackBar(String message) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: colorScheme.error,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void pop<T>([T? result]) => Navigator.of(this).pop(result);

  bool get canPop => Navigator.of(this).canPop();
}

extension ResponsiveExtensions on BuildContext {
  static const double mobileBreakpoint = 600;

  static const double tabletBreakpoint = 1200;

  bool get isMobile => screenWidth < mobileBreakpoint;

  bool get isTablet =>
      screenWidth >= mobileBreakpoint && screenWidth < tabletBreakpoint;

  bool get isDesktop => screenWidth >= tabletBreakpoint;

  String get breakpointName {
    if (isMobile) return 'mobile';
    if (isTablet) return 'tablet';
    return 'desktop';
  }

  T responsive<T>({required T mobile, T? tablet, T? desktop}) {
    if (isDesktop) return desktop ?? tablet ?? mobile;
    if (isTablet) return tablet ?? mobile;
    return mobile;
  }
}
