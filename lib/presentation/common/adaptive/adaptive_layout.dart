import 'package:flutter/widgets.dart';

import 'package:telepos/presentation/common/adaptive/breakpoints.dart';
import 'package:telepos/presentation/common/adaptive/responsive_wrapper.dart';

typedef LayoutWidgetBuilder =
    Widget Function(BuildContext context, ResponsiveInfo info);

class AdaptiveLayout extends StatelessWidget {
  const AdaptiveLayout({
    required this.mobile,
    this.tablet,
    this.desktop,
    super.key,
  });

  final LayoutWidgetBuilder mobile;

  final LayoutWidgetBuilder? tablet;

  final LayoutWidgetBuilder? desktop;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final layoutType = Breakpoints.fromWidth(width);

        final info =
            ResponsiveWrapper.maybeOf(context) ??
            ResponsiveInfo(
              width: width,
              height: constraints.maxHeight,
              layoutType: layoutType,
              orientation: MediaQuery.orientationOf(context),
              devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
              padding: MediaQuery.paddingOf(context),
              viewInsets: MediaQuery.viewInsetsOf(context),
            );

        return _buildLayout(context, info);
      },
    );
  }

  Widget _buildLayout(BuildContext context, ResponsiveInfo info) {
    switch (info.layoutType) {
      case LayoutType.mobile:
        return mobile(context, info);

      case LayoutType.tablet:
        return (tablet ?? mobile)(context, info);

      case LayoutType.desktop:
        return (desktop ?? tablet ?? mobile)(context, info);
    }
  }
}

class AdaptiveWidget extends StatelessWidget {
  const AdaptiveWidget({
    required this.mobile,
    this.tablet,
    this.desktop,
    super.key,
  });

  final Widget mobile;

  final Widget? tablet;

  final Widget? desktop;

  @override
  Widget build(BuildContext context) {
    return AdaptiveLayout(
      mobile: (_, __) => mobile,
      tablet: tablet != null ? (_, __) => tablet! : null,
      desktop: desktop != null ? (_, __) => desktop! : null,
    );
  }
}

class ResponsiveVisibility extends StatelessWidget {
  const ResponsiveVisibility({
    required this.child,
    this.visibleOnMobile = true,
    this.visibleOnTablet = true,
    this.visibleOnDesktop = true,
    this.replacement,
    super.key,
  });

  final Widget child;

  final bool visibleOnMobile;

  final bool visibleOnTablet;

  final bool visibleOnDesktop;

  final Widget? replacement;

  @override
  Widget build(BuildContext context) {
    final layoutType = Breakpoints.of(context);

    final isVisible = switch (layoutType) {
      LayoutType.mobile => visibleOnMobile,
      LayoutType.tablet => visibleOnTablet,
      LayoutType.desktop => visibleOnDesktop,
    };

    if (isVisible) {
      return child;
    }

    return replacement ?? const SizedBox.shrink();
  }
}

class MobileOnly extends StatelessWidget {
  const MobileOnly({required this.child, this.replacement, super.key});

  final Widget child;
  final Widget? replacement;

  @override
  Widget build(BuildContext context) {
    return ResponsiveVisibility(
      visibleOnMobile: true,
      visibleOnTablet: false,
      visibleOnDesktop: false,
      replacement: replacement,
      child: child,
    );
  }
}

class TabletOnly extends StatelessWidget {
  const TabletOnly({required this.child, this.replacement, super.key});

  final Widget child;
  final Widget? replacement;

  @override
  Widget build(BuildContext context) {
    return ResponsiveVisibility(
      visibleOnMobile: false,
      visibleOnTablet: true,
      visibleOnDesktop: false,
      replacement: replacement,
      child: child,
    );
  }
}

class DesktopOnly extends StatelessWidget {
  const DesktopOnly({required this.child, this.replacement, super.key});

  final Widget child;
  final Widget? replacement;

  @override
  Widget build(BuildContext context) {
    return ResponsiveVisibility(
      visibleOnMobile: false,
      visibleOnTablet: false,
      visibleOnDesktop: true,
      replacement: replacement,
      child: child,
    );
  }
}

class HideOnMobile extends StatelessWidget {
  const HideOnMobile({required this.child, this.replacement, super.key});

  final Widget child;
  final Widget? replacement;

  @override
  Widget build(BuildContext context) {
    return ResponsiveVisibility(
      visibleOnMobile: false,
      visibleOnTablet: true,
      visibleOnDesktop: true,
      replacement: replacement,
      child: child,
    );
  }
}

class AdaptiveValue<T> {
  const AdaptiveValue({required this.mobile, this.tablet, this.desktop});

  final T mobile;

  final T? tablet;

  final T? desktop;

  T resolve(BuildContext context) {
    final layoutType = Breakpoints.of(context);

    return switch (layoutType) {
      LayoutType.mobile => mobile,
      LayoutType.tablet => tablet ?? mobile,
      LayoutType.desktop => desktop ?? tablet ?? mobile,
    };
  }
}
