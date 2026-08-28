import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screen_retriever/screen_retriever.dart';

import 'package:telepos/presentation/screens/customer_display/customer_display_data.dart';

final customerWindowServiceProvider = Provider<CustomerWindowService>(
  (ref) => CustomerWindowService(),
);

const kCustomerDisplayBusinessId = 'customer_display';

class CustomerWindowService {
  WindowController? _controller;

  bool get isOpen => _controller != null;

  Future<bool> open({
    required int monitorIndex,
    required String storeName,
  }) async {
    try {
      final bounds = await _monitorBounds(monitorIndex);
      final args = jsonEncode({
        'businessId': kCustomerDisplayBusinessId,
        'storeName': storeName,
        if (bounds != null) ...{
          'x': bounds.x,
          'y': bounds.y,
          'w': bounds.w,
          'h': bounds.h,
        },
      });
      final controller = await WindowController.create(
        WindowConfiguration(arguments: args),
      );
      _controller = controller;
      await controller.show();
      return true;
    } catch (_) {
      _controller = null;
      return false;
    }
  }

  Future<void> push(CustomerDisplayData data) async {
    final c = _controller;
    if (c == null) return;
    try {
      await c.invokeMethod('cart', jsonEncode(data.toJson()));
    } catch (_) {
      _controller = null;
    }
  }

  Future<void> close() async {
    final c = _controller;
    _controller = null;
    if (c == null) return;
    try {
      await c.hide();
    } catch (_) {}
  }

  Future<_Bounds?> _monitorBounds(int monitorIndex) async {
    try {
      final displays = await screenRetriever.getAllDisplays();
      if (displays.isEmpty) return null;
      final idx = (monitorIndex - 1).clamp(0, displays.length - 1);
      final d = displays[idx];
      final pos = d.visiblePosition;
      final size = d.visibleSize ?? d.size;
      return _Bounds(
        x: pos?.dx ?? 0,
        y: pos?.dy ?? 0,
        w: size.width,
        h: size.height,
      );
    } catch (_) {
      return null;
    }
  }
}

class _Bounds {
  const _Bounds({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });
  final double x;
  final double y;
  final double w;
  final double h;
}
