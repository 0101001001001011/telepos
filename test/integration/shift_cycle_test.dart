library;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/presentation/controllers/shift/shift_controller.dart';
import 'package:telepos/presentation/controllers/sale/sale_controller.dart';
import 'package:telepos/presentation/controllers/payment/payment_controller.dart';

import '../helpers/helpers.dart';
import 'test_utils.dart';

void main() {
  group('Shift Cycle Integration Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = createTestContainer();
    });

    tearDown(() async {
      await pumpEventQueue();
      container.dispose();
      tearDownTestDependencies();
    });

    test('complete shift cycle - open, work, close', () async {
      final shiftNotifier = container.read(shiftControllerProvider.notifier);
      final initialCash = Decimal.parse('10000');

      await shiftNotifier.openShift(initialCash);
      var shiftState = container.read(shiftControllerProvider);

      expect(shiftState.isOpen, isTrue, reason: 'Shift should be open');
      expect(shiftState.openTime, isNotNull);

      final saleNotifier = container.read(saleControllerProvider.notifier);
      await saleNotifier.search('Молоко');
      var saleState = container.read(saleControllerProvider);
      if (saleState.searchResults.isNotEmpty) {
        saleNotifier.addProduct(saleState.searchResults.first);
      }
      saleState = container.read(saleControllerProvider);

      final paymentNotifier = container.read(
        paymentControllerProvider.notifier,
      );
      paymentNotifier.initialize(saleState.total);
      paymentNotifier.setPaymentType(PaymentType.cash);
      paymentNotifier.setCashReceived(saleState.total);
      await paymentNotifier.processPayment();

      saleNotifier.clearSale();

      shiftNotifier.setBillCount(10000, 1);
      shiftNotifier.setBillCount(5000, 0);
      shiftNotifier.setBillCount(1000, 0);
      shiftNotifier.setBillCount(500, 0);
      shiftNotifier.setBillCount(200, 2);

      shiftState = container.read(shiftControllerProvider);
      expect(shiftState.billsTotal, equals(Decimal.parse('10400')));

      shiftState = container.read(shiftControllerProvider);

      await shiftNotifier.closeShift();
      shiftState = container.read(shiftControllerProvider);
    });

    test('shift bill counting', () async {
      final shiftNotifier = container.read(shiftControllerProvider.notifier);

      await shiftNotifier.openShift(Decimal.parse('5000'));

      shiftNotifier.setBillCount(20000, 1);
      shiftNotifier.setBillCount(10000, 2);
      shiftNotifier.setBillCount(5000, 3);
      shiftNotifier.setBillCount(2000, 2);
      shiftNotifier.setBillCount(1000, 5);
      shiftNotifier.setBillCount(500, 4);
      shiftNotifier.setBillCount(200, 10);

      var shiftState = container.read(shiftControllerProvider);

      expect(shiftState.billsTotal, equals(Decimal.parse('68000')));
    });

    test('shift manual total entry', () async {
      final shiftNotifier = container.read(shiftControllerProvider.notifier);

      await shiftNotifier.openShift(Decimal.zero);

      shiftNotifier.selectTab(1);
      var shiftState = container.read(shiftControllerProvider);
      expect(shiftState.selectedTab, equals(1));

      shiftNotifier.setManualTotal(Decimal.parse('50000'));
      shiftState = container.read(shiftControllerProvider);
      expect(shiftState.manualTotal, equals(Decimal.parse('50000')));

      shiftNotifier.clearManualTotal();
      shiftState = container.read(shiftControllerProvider);
      expect(shiftState.manualTotal, equals(Decimal.zero));
    });

    test('shift increment/decrement bills', () async {
      final shiftNotifier = container.read(shiftControllerProvider.notifier);

      await shiftNotifier.openShift(Decimal.zero);

      shiftNotifier.incrementBill(1000);
      var shiftState = container.read(shiftControllerProvider);
      expect(shiftState.billCounts[1000], equals(1));
      expect(shiftState.billsTotal, equals(Decimal.parse('1000')));

      shiftNotifier.incrementBill(1000);
      shiftState = container.read(shiftControllerProvider);
      expect(shiftState.billCounts[1000], equals(2));
      expect(shiftState.billsTotal, equals(Decimal.parse('2000')));

      shiftNotifier.decrementBill(1000);
      shiftState = container.read(shiftControllerProvider);
      expect(shiftState.billCounts[1000], equals(1));
      expect(shiftState.billsTotal, equals(Decimal.parse('1000')));

      shiftNotifier.decrementBill(1000);
      shiftState = container.read(shiftControllerProvider);
      expect(shiftState.billCounts[1000], equals(0));
      expect(shiftState.billsTotal, equals(Decimal.zero));

      shiftNotifier.decrementBill(1000);
      shiftState = container.read(shiftControllerProvider);
      expect(shiftState.billCounts[1000] ?? 0, equals(0));
    });

    test('shift clear bills', () async {
      final shiftNotifier = container.read(shiftControllerProvider.notifier);

      await shiftNotifier.openShift(Decimal.zero);

      shiftNotifier.setBillCount(10000, 5);
      shiftNotifier.setBillCount(5000, 10);
      shiftNotifier.setBillCount(1000, 20);

      var shiftState = container.read(shiftControllerProvider);
      expect(shiftState.billsTotal, greaterThan(Decimal.zero));

      shiftNotifier.clearBills();
      shiftState = container.read(shiftControllerProvider);
      expect(shiftState.billsTotal, equals(Decimal.zero));
      expect(shiftState.billCounts, isEmpty);
    });

    test('shift tab switching', () async {
      final shiftNotifier = container.read(shiftControllerProvider.notifier);

      await shiftNotifier.openShift(Decimal.zero);

      var shiftState = container.read(shiftControllerProvider);
      expect(shiftState.selectedTab, equals(0));

      shiftNotifier.selectTab(1);
      shiftState = container.read(shiftControllerProvider);
      expect(shiftState.selectedTab, equals(1));

      shiftNotifier.selectTab(2);
      shiftState = container.read(shiftControllerProvider);
      expect(shiftState.selectedTab, equals(2));

      shiftNotifier.selectTab(5);
      shiftState = container.read(shiftControllerProvider);
      expect(shiftState.selectedTab, equals(2));

      shiftNotifier.selectTab(-1);
      shiftState = container.read(shiftControllerProvider);
      expect(shiftState.selectedTab, equals(2));
    });

    test('shift difference calculation', () async {
      final shiftNotifier = container.read(shiftControllerProvider.notifier);

      await shiftNotifier.openShift(Decimal.parse('10000'));

      var shiftState = container.read(shiftControllerProvider);

      shiftNotifier.setBillCount(10000, 1);
      shiftNotifier.setBillCount(500, 2);

      shiftState = container.read(shiftControllerProvider);

      expect(shiftState.billsTotal, equals(Decimal.parse('11000')));
    });

    test('shift refresh', () async {
      final shiftNotifier = container.read(shiftControllerProvider.notifier);

      await shiftNotifier.openShift(Decimal.zero);

      await shiftNotifier.refresh();

      final shiftState = container.read(shiftControllerProvider);
      expect(shiftState.isLoading, isFalse);
    });

    testWidgets('shift screen UI flow', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: const TestApp(child: Scaffold(body: _TestShiftFlow())),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Смена закрыта'), findsOneWidget);
      expect(find.byKey(const Key('open_shift_btn')), findsOneWidget);

      await tester.tap(find.byKey(const Key('open_shift_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Смена открыта'), findsOneWidget);

      expect(find.byKey(const Key('bill_10000')), findsOneWidget);

      await tester.tap(find.byKey(const Key('increment_10000')));
      await tester.pumpAndSettle();

      expect(find.textContaining('10000'), findsWidgets);
    });
  });
}

class _TestShiftFlow extends ConsumerWidget {
  const _TestShiftFlow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(shiftControllerProvider);
    final notifier = ref.read(shiftControllerProvider.notifier);

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          Text(state.isOpen ? 'Смена открыта' : 'Смена закрыта'),

          if (!state.isOpen) ...[
            ElevatedButton(
              key: const Key('open_shift_btn'),
              onPressed: () => notifier.openShift(Decimal.parse('10000')),
              child: const Text('Открыть смену'),
            ),
          ] else ...[
            ...kBillDenominations.map((denomination) {
              final count = state.billCounts[denomination] ?? 0;
              return Row(
                key: Key('bill_$denomination'),
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('$denomination ₸'),
                  IconButton(
                    key: Key('decrement_$denomination'),
                    icon: const Icon(Icons.remove),
                    onPressed: () => notifier.decrementBill(denomination),
                  ),
                  Text('$count'),
                  IconButton(
                    key: Key('increment_$denomination'),
                    icon: const Icon(TeleposIcons.add),
                    onPressed: () => notifier.incrementBill(denomination),
                  ),
                  Text('= ${Decimal.fromInt(denomination * count)}'),
                ],
              );
            }),

            const Divider(),
            Text('Итого: ${state.billsTotal}'),
            Text('Разница: ${state.difference}'),

            const SizedBox(height: 16),
            ElevatedButton(
              key: const Key('close_shift_btn'),
              onPressed: state.canClose ? () => notifier.closeShift() : null,
              child: const Text('Закрыть смену'),
            ),
          ],
        ],
      ),
    );
  }
}
