library;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:telepos/presentation/controllers/refund/refund_controller.dart';

import '../helpers/helpers.dart';
import 'test_utils.dart';

/// Возврат целиком: экран → контракт → касса → база.
///
/// # Что изменилось задачей 20 и почему это другой тест
///
/// До неё контроллер держал возврат в памяти экрана и читал **мок** базы:
/// «чек 12345» существовал в виде заранее подготовленных ответов `when(...)`,
/// а выделение строк было полем виджета. Проверять там было почти нечего —
/// состояние меняло само себя.
///
/// Теперь под экраном настоящий `LocalRefundService` над настоящей базой
/// корзины (`test_utils.dart`, `_seedCompletedReceipt`), и каждая проверка
/// ниже проходит через кассу: выделение — команда `setLineQuantity`,
/// количество больше проданного — **отказ**, а не молчаливое срезание, и
/// завершение действительно двигает деньги и остаток.
///
/// Чек, на котором всё это меряется: №12345 на кассе 1 — `1001` два раза по
/// 450 и `1002` один раз по 150, итого 1050.
void main() {
  group('Refund Cycle Integration Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = createTestContainer();
    });

    tearDown(() {
      container.dispose();
      tearDownTestDependencies();
    });

    /// Черновик приезжает подпиской, а очередь команд асинхронна — читать
    /// состояние надо после того, как микрозадачи разошлись.
    Future<RefundState> settle() async {
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      return container.read(refundControllerProvider);
    }

    test('возврат по чеку: чек приходит от кассы со строками', () async {
      final refunds = container.read(refundControllerProvider.notifier);

      await refunds.setMode(RefundMode.byReceipt);
      var state = await settle();
      expect(state.mode, RefundMode.byReceipt);

      await refunds.loadReceipt(12345, 1);
      state = await settle();

      expect(state.error, isNull, reason: 'касса приняла чек');
      expect(state.receiptInfo?.receiptNo, 12345);
      expect(state.items, hasLength(2));
      expect(
        state.allSelected,
        isTrue,
        reason: 'загруженный чек возвращается целиком, пока не сняли строку',
      );
      expect(state.selectedTotal, Decimal.parse('1050'));

      final done = await refunds.processRefund();
      expect(done, isTrue, reason: state.error ?? 'возврат должен пройти');

      refunds.clear();
      state = await settle();
      expect(state.items, isEmpty);
    });

    test('снятая строка остаётся видимой и возвращается обратно', () async {
      // Правило контракта: снять выделение — послать кассе ноль, строка
      // уходит из черновика. Экран обязан её показать снятой, а не потерять,
      // иначе вернуть её нечем.
      final refunds = container.read(refundControllerProvider.notifier);

      await refunds.loadReceipt(12345, 1);
      var state = await settle();
      final first = state.items.first;

      await refunds.toggleItemSelection(first.id);
      state = await settle();

      expect(state.items, hasLength(2), reason: 'строка не исчезла с экрана');
      expect(
        state.items.firstWhere((i) => i.id == first.id).isSelected,
        isFalse,
      );
      expect(state.selectedCount, 1);
      expect(state.selectedTotal, lessThan(Decimal.parse('1050')));

      await refunds.toggleItemSelection(first.id);
      state = await settle();

      expect(state.allSelected, isTrue);
      expect(state.selectedTotal, Decimal.parse('1050'));
    });

    test('количество меньше проданного уменьшает сумму', () async {
      final refunds = container.read(refundControllerProvider.notifier);

      await refunds.loadReceipt(12345, 1);
      var state = await settle();

      final twoPack = state.items.firstWhere((i) => i.quantity > Decimal.one);
      await refunds.updateQuantity(twoPack.id, Decimal.one);
      state = await settle();

      expect(state.error, isNull);
      expect(
        state.items.firstWhere((i) => i.id == twoPack.id).quantity,
        Decimal.one,
      );
      expect(state.selectedTotal, Decimal.parse('600'));
    });

    test('больше проданного касса не отдаёт и говорит об этом', () async {
      // До задачи 20 контроллер тихо срезал введённое до `maxQuantity`:
      // кассир видел одно, а вернулось бы другое. Теперь отказ **назван**.
      final refunds = container.read(refundControllerProvider.notifier);

      await refunds.loadReceipt(12345, 1);
      var state = await settle();
      final line = state.items.first;
      final sold = line.maxQuantity!;

      await refunds.updateQuantity(line.id, sold + Decimal.fromInt(10));
      state = await settle();

      expect(
        state.error,
        isNotNull,
        reason: 'молчаливое срезание неотличимо от успеха',
      );
      // С 2026-09-15 — свой ключ возврата, а не `error.refund_refused:<текст
      // кассы>`: код `invalid_amount` общий с корзиной, а её фраза — про
      // скидку (`RefundController._refundOwnKeys`).
      expect(state.error, 'error.refund_invalid_amount');
      expect(
        state.items.firstWhere((i) => i.id == line.id).quantity,
        sold,
        reason: 'отказ ничего не меняет',
      );
    });

    test('ноль убирает строку с экрана насовсем', () async {
      final refunds = container.read(refundControllerProvider.notifier);

      await refunds.loadReceipt(12345, 1);
      var state = await settle();
      final id = state.items.first.id;

      await refunds.updateQuantity(id, Decimal.zero);
      state = await settle();

      expect(
        state.items.any((i) => i.id == id),
        isFalse,
        reason: 'убрать — не то же, что снять выделение',
      );
      expect(state.items, hasLength(1));
    });

    test('снять всё и выделить всё', () async {
      final refunds = container.read(refundControllerProvider.notifier);

      await refunds.loadReceipt(12345, 1);
      var state = await settle();
      expect(state.allSelected, isTrue);

      await refunds.deselectAll();
      state = await settle();
      expect(state.noneSelected, isTrue);
      expect(state.selectedTotal, Decimal.zero);
      expect(state.canRefund, isFalse);

      await refunds.selectAll();
      state = await settle();
      expect(state.allSelected, isTrue);
      expect(state.selectedTotal, Decimal.parse('1050'));
    });

    test('причина возврата остаётся экраном', () async {
      // По проводу причина не едет вовсе (шаг 9 спеки): касса её не
      // спрашивает, и в контракте её нет.
      final refunds = container.read(refundControllerProvider.notifier);

      await refunds.loadReceipt(12345, 1);
      var state = await settle();
      final id = state.items.first.id;

      refunds.setReason(id, RefundReason.defective);
      state = await settle();

      expect(
        state.items.firstWhere((i) => i.id == id).reason,
        RefundReason.defective,
      );
    });

    test('возврат без чека: поиск, товар, завершение', () async {
      final refunds = container.read(refundControllerProvider.notifier);

      await refunds.setMode(RefundMode.withoutReceipt);
      var state = await settle();
      expect(state.mode, RefundMode.withoutReceipt);
      expect(
        state.error,
        isNull,
        reason: 'право op.refundWithoutReceipt проверяет касса; здесь оно есть',
      );

      await refunds.search('Молоко');
      await Future<void>.delayed(const Duration(milliseconds: 500));
      state = await settle();
      expect(state.searchResults, isNotEmpty);

      await refunds.addProduct(state.searchResults.first);
      state = await settle();
      expect(state.items, hasLength(1));
      expect(state.items.first.isSelected, isTrue);
      expect(
        state.items.first.maxQuantity,
        isNull,
        reason: 'без чека потолка нет — сверяться не с чем',
      );

      expect(state.canRefund, isTrue);
      expect(await refunds.processRefund(), isTrue, reason: state.error ?? '');
    });

    testWidgets('refund screen UI flow', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: const TestApp(child: Scaffold(body: _TestRefundFlow())),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Введите номер чека'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('receipt_input')), '12345');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('search_receipt_btn')));
      // `runAsync`, а не `pumpAndSettle`: чек теперь приходит **от кассы** —
      // через очередь команд и настоящую базу в памяти. Часы `testWidgets`
      // поддельные, и работа настоящего SQLite при них не движется вовсе:
      // без этой обёртки ожидание кончается раньше, чем запрос, и экран
      // остаётся пустым при полностью исправном возврате.
      await tester.runAsync(() async {
        for (var i = 0; i < 20; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tester.pumpAndSettle();

      expect(find.byType(ListTile), findsWidgets);

      expect(find.byKey(const Key('refund_btn')), findsOneWidget);
    });
  });
}

class _TestRefundFlow extends ConsumerStatefulWidget {
  const _TestRefundFlow();

  @override
  ConsumerState<_TestRefundFlow> createState() => _TestRefundFlowState();
}

class _TestRefundFlowState extends ConsumerState<_TestRefundFlow> {
  final _receiptController = TextEditingController();

  @override
  void dispose() {
    _receiptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(refundControllerProvider);
    final notifier = ref.read(refundControllerProvider.notifier);

    return Column(
      children: [
        if (state.items.isEmpty) ...[
          const Text('Введите номер чека'),
          TextField(
            key: const Key('receipt_input'),
            controller: _receiptController,
            keyboardType: TextInputType.number,
          ),
          ElevatedButton(
            key: const Key('search_receipt_btn'),
            onPressed: () async {
              final receiptNo = int.tryParse(_receiptController.text);
              if (receiptNo != null) {
                await notifier.loadReceipt(receiptNo, 1);
              }
            },
            child: const Text('Найти чек'),
          ),
        ] else ...[
          Expanded(
            child: ListView.builder(
              itemCount: state.items.length,
              itemBuilder: (context, index) {
                final item = state.items[index];
                return ListTile(
                  leading: Checkbox(
                    value: item.isSelected,
                    onChanged: (_) => notifier.toggleItemSelection(item.id),
                  ),
                  title: Text(item.name),
                  subtitle: Text('${item.quantity} x ${item.price}'),
                  trailing: Text(item.total.toString()),
                );
              },
            ),
          ),
          Text('Итого: ${state.selectedTotal}'),
          ElevatedButton(
            key: const Key('refund_btn'),
            onPressed: state.canRefund ? () => notifier.processRefund() : null,
            child: const Text('Оформить возврат'),
          ),
        ],
      ],
    );
  }
}
