import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/presentation/screens/customer_display/customer_display_data.dart';
import 'package:telepos/presentation/screens/customer_display/customer_display_screen.dart';

Future<void> runCustomerDisplayWindow(WindowController controller) async {
  Map<String, dynamic> args = const {};
  try {
    args = jsonDecode(controller.arguments) as Map<String, dynamic>;
  } catch (_) {}

  final storeName = args['storeName'] as String? ?? 'TelePOS';

  try {
    await windowManager.ensureInitialized();
    final x = (args['x'] as num?)?.toDouble();
    final y = (args['y'] as num?)?.toDouble();
    final w = (args['w'] as num?)?.toDouble();
    final h = (args['h'] as num?)?.toDouble();
    await windowManager.setTitle('Экран покупателя');
    if (x != null && y != null && w != null && h != null) {
      await windowManager.setBounds(Rect.fromLTWH(x, y, w, h));
    }
    await windowManager.show();
    await windowManager.focus();
  } catch (_) {}

  final container = ProviderContainer();

  controller.setWindowMethodHandler((call) async {
    if (call.method == 'cart') {
      try {
        final json =
            jsonDecode(call.arguments as String) as Map<String, dynamic>;
        container
            .read(customerDisplayDataProvider.notifier)
            .set(CustomerDisplayData.fromJson(json));
      } catch (_) {}
    }
    return null;
  });

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: _CustomerDisplayApp(storeName: storeName),
    ),
  );
}

class _CustomerDisplayApp extends StatelessWidget {
  const _CustomerDisplayApp({required this.storeName});
  final String storeName;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: Consumer(
        builder: (context, ref, _) {
          final data = ref.watch(customerDisplayDataProvider);
          return CustomerDisplayView(data: data, storeName: storeName);
        },
      ),
    );
  }
}
