import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telepos/core/locale/locale_provider.dart';
import 'package:telepos/web/wt_boot_gate.dart';
import 'package:telepos/web/wt_channel.dart';
import 'package:telepos/web/wt_unavailable_screen.dart';

/// Створка — единственное место, где `WtUnavailable` превращается в то, что
/// видит человек. Экран, который никто не показывает, покрытием не является,
/// поэтому проверяется именно связь, а не сам экран.
void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<void> pumpGate(WidgetTester tester, WtLink link) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: WtBootGate(
          link: link,
          terminal: const _Terminal(),
        ),
      ),
    );
  }

  testWidgets('без сессии показывается причина, а не терминал', (tester) async {
    // Провод один: запасного пути через REST нет по решению заказчика.
    // Терминал, открывшийся без сессии, показал бы пустые экраны — то есть
    // соврал бы, что данных нет, вместо того чтобы сказать, что нет связи.
    final link = WtLink(
      () async => const WtUnavailable('конструктора WebTransport нет'),
      attempts: 1,
      pause: Duration.zero,
    );

    await pumpGate(tester, link);
    await tester.pumpAndSettle();

    expect(find.byType(WtUnavailableScreen), findsOneWidget);
    expect(find.byType(_Terminal), findsNothing);
    expect(find.textContaining('WebTransport'), findsWidgets);
  });

  testWidgets('с сессией показывается терминал', (tester) async {
    final link = WtLink(() async => _LiveSession(), attempts: 1);

    await pumpGate(tester, link);
    await tester.pumpAndSettle();

    expect(find.byType(_Terminal), findsOneWidget);
    expect(find.byType(WtUnavailableScreen), findsNothing);
  });

  testWidgets('повтор поднимает сессию заново и открывает терминал', (
    tester,
  ) async {
    // Кнопка, которая рисуется и ничего не меняет, — тот же тупик, только с
    // надеждой. Проверяется исход нажатия, а не факт вызова.
    var down = true;
    final link = WtLink(
      () async => down ? const WtUnavailable('касса молчит') : _LiveSession(),
      attempts: 1,
      pause: Duration.zero,
    );

    await pumpGate(tester, link);
    await tester.pumpAndSettle();
    expect(find.byType(WtUnavailableScreen), findsOneWidget);

    down = false;
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(find.byType(_Terminal), findsOneWidget);
  });
}

class _Terminal extends StatelessWidget {
  const _Terminal();

  @override
  Widget build(BuildContext context) =>
      const MaterialApp(home: Scaffold(body: Text('терминал')));
}

class _LiveSession implements WtStreams {
  @override
  Future<void> get closed => Completer<void>().future;

  @override
  Future<WtStream> openStream() async => throw UnimplementedError();

  @override
  Future<void> close() async {}
}
