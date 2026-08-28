import 'dart:ui';

class TestBreakpoints {
  TestBreakpoints._();

  static const mobile = Size(360, 640);

  static const mobileLandscape = Size(640, 360);

  static const tablet = Size(800, 1024);

  static const tabletLandscape = Size(1024, 768);

  static const desktop = Size(1280, 800);

  static const desktopLarge = Size(1920, 1080);

  static const webDefault = Size(1366, 768);

  static const all = [mobile, tablet, desktop];

  static const allWithLandscape = [
    mobile,
    mobileLandscape,
    tablet,
    tabletLandscape,
    desktop,
    desktopLarge,
  ];
}
