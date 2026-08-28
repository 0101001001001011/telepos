import 'package:flutter/widgets.dart';

class Breakpoints {
  Breakpoints._();

  static const double tablet = 600;

  static const double desktop = 1200;

  static const double mobileMax = tablet - 1;

  static const double tabletMax = desktop - 1;

  static LayoutType fromWidth(double width) {
    if (width < tablet) return LayoutType.mobile;
    if (width < desktop) return LayoutType.tablet;
    return LayoutType.desktop;
  }

  static LayoutType of(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return fromWidth(width);
  }
}

enum LayoutType { mobile, tablet, desktop }

extension LayoutTypeExtension on LayoutType {
  bool get isMobile => this == LayoutType.mobile;

  bool get isTablet => this == LayoutType.tablet;

  bool get isDesktop => this == LayoutType.desktop;

  bool get isMobileOrTablet => isMobile || isTablet;

  bool get isTabletOrDesktop => isTablet || isDesktop;
}

class ScreenSizeHelper {
  ScreenSizeHelper._();

  static bool isMobile(BuildContext context) =>
      Breakpoints.of(context).isMobile;

  static bool isTablet(BuildContext context) =>
      Breakpoints.of(context).isTablet;

  static bool isDesktop(BuildContext context) =>
      Breakpoints.of(context).isDesktop;

  static double widthOf(BuildContext context) {
    return MediaQuery.sizeOf(context).width;
  }

  static double heightOf(BuildContext context) {
    return MediaQuery.sizeOf(context).height;
  }

  static Orientation orientationOf(BuildContext context) {
    return MediaQuery.orientationOf(context);
  }

  static bool isPortrait(BuildContext context) {
    return orientationOf(context) == Orientation.portrait;
  }

  static bool isLandscape(BuildContext context) {
    return orientationOf(context) == Orientation.landscape;
  }
}

class ScreenInfo {
  const ScreenInfo({
    required this.width,
    required this.height,
    required this.layoutType,
    required this.orientation,
  });

  factory ScreenInfo.of(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final width = mediaQuery.size.width;
    final height = mediaQuery.size.height;

    return ScreenInfo(
      width: width,
      height: height,
      layoutType: Breakpoints.fromWidth(width),
      orientation: mediaQuery.orientation,
    );
  }

  final double width;

  final double height;

  final LayoutType layoutType;

  final Orientation orientation;

  bool get isMobile => layoutType.isMobile;

  bool get isTablet => layoutType.isTablet;

  bool get isDesktop => layoutType.isDesktop;

  bool get isPortrait => orientation == Orientation.portrait;

  bool get isLandscape => orientation == Orientation.landscape;

  double get aspectRatio => width / height;
}
