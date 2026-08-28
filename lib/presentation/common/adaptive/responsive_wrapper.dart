import 'package:flutter/widgets.dart';

import 'package:telepos/presentation/common/adaptive/breakpoints.dart';

class ResponsiveWrapper extends StatelessWidget {
  const ResponsiveWrapper({required this.child, super.key});

  final Widget child;

  static ResponsiveInfo of(BuildContext context) {
    final inherited = context
        .dependOnInheritedWidgetOfExactType<_ResponsiveInherited>();
    assert(inherited != null, 'ResponsiveWrapper not found in widget tree');
    return inherited!.info;
  }

  static ResponsiveInfo? maybeOf(BuildContext context) {
    final inherited = context
        .dependOnInheritedWidgetOfExactType<_ResponsiveInherited>();
    return inherited?.info;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mediaQuery = MediaQuery.of(context);
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        final info = ResponsiveInfo(
          width: width,
          height: height,
          layoutType: Breakpoints.fromWidth(width),
          orientation: mediaQuery.orientation,
          devicePixelRatio: mediaQuery.devicePixelRatio,
          padding: mediaQuery.padding,
          viewInsets: mediaQuery.viewInsets,
        );

        return _ResponsiveInherited(info: info, child: child);
      },
    );
  }
}

class ResponsiveInfo {
  const ResponsiveInfo({
    required this.width,
    required this.height,
    required this.layoutType,
    required this.orientation,
    required this.devicePixelRatio,
    required this.padding,
    required this.viewInsets,
  });

  final double width;

  final double height;

  final LayoutType layoutType;

  final Orientation orientation;

  final double devicePixelRatio;

  final EdgeInsets padding;

  final EdgeInsets viewInsets;

  bool get isMobile => layoutType.isMobile;

  bool get isTablet => layoutType.isTablet;

  bool get isDesktop => layoutType.isDesktop;

  bool get isMobileOrTablet => layoutType.isMobileOrTablet;

  bool get isTabletOrDesktop => layoutType.isTabletOrDesktop;

  bool get isPortrait => orientation == Orientation.portrait;

  bool get isLandscape => orientation == Orientation.landscape;

  double get aspectRatio => width / height;

  bool get isKeyboardVisible => viewInsets.bottom > 0;

  double get keyboardHeight => viewInsets.bottom;

  double get heightWithoutKeyboard => height + viewInsets.bottom;

  double get adaptivePadding {
    switch (layoutType) {
      case LayoutType.mobile:
        return 16.0;
      case LayoutType.tablet:
        return 24.0;
      case LayoutType.desktop:
        return 32.0;
    }
  }

  double get adaptiveFontScale {
    switch (layoutType) {
      case LayoutType.mobile:
        return 1.0;
      case LayoutType.tablet:
        return 1.1;
      case LayoutType.desktop:
        return 1.2;
    }
  }

  int get gridColumns {
    switch (layoutType) {
      case LayoutType.mobile:
        return 2;
      case LayoutType.tablet:
        return 3;
      case LayoutType.desktop:
        return 4;
    }
  }
}

class _ResponsiveInherited extends InheritedWidget {
  const _ResponsiveInherited({required this.info, required super.child});

  final ResponsiveInfo info;

  @override
  bool updateShouldNotify(_ResponsiveInherited oldWidget) {
    return info.width != oldWidget.info.width ||
        info.height != oldWidget.info.height ||
        info.layoutType != oldWidget.info.layoutType ||
        info.orientation != oldWidget.info.orientation;
  }
}

extension ResponsiveContextExtension on BuildContext {
  ResponsiveInfo get responsive => ResponsiveWrapper.of(this);

  ResponsiveInfo? get responsiveOrNull => ResponsiveWrapper.maybeOf(this);

  bool get isMobile => responsive.isMobile;

  bool get isTablet => responsive.isTablet;

  bool get isDesktop => responsive.isDesktop;
}
