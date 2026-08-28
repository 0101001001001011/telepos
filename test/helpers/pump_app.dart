import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';
import 'breakpoints.dart';

extension PumpApp on WidgetTester {
  Future<void> pumpApp(Widget widget, {Locale locale = const Locale('ru')}) {
    return pumpWidget(TestApp(locale: locale, child: widget));
  }

  Future<void> pumpScaffold(Widget body, {Locale locale = const Locale('ru')}) {
    return pumpWidget(TestScaffold(locale: locale, body: body));
  }

  Future<void> pumpMobile(Widget widget) async {
    await binding.setSurfaceSize(TestBreakpoints.mobile);
    return pumpApp(widget);
  }

  Future<void> pumpTablet(Widget widget) async {
    await binding.setSurfaceSize(TestBreakpoints.tablet);
    return pumpApp(widget);
  }

  Future<void> pumpDesktop(Widget widget) async {
    await binding.setSurfaceSize(TestBreakpoints.desktop);
    return pumpApp(widget);
  }

  Future<void> pumpAtSize(Widget widget, Size size) async {
    await binding.setSurfaceSize(size);
    return pumpApp(widget);
  }
}

extension ResetSurface on WidgetTester {
  Future<void> resetSurfaceSize() {
    return binding.setSurfaceSize(null);
  }
}
