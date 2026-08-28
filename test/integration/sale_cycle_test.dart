library;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:telepos/presentation/controllers/sale/sale_controller.dart';
import 'package:telepos/presentation/controllers/payment/payment_controller.dart';

import '../helpers/helpers.dart';
import 'test_utils.dart';

Future<void> waitForSearch() async {
  await Future.delayed(const Duration(milliseconds: 500));
}

void main() {
  group('Sale Cycle Integration Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = createTestContainer();
    });

    tearDown(() {
      container.dispose();
      tearDownTestDependencies();
    });

    test('complete sale cycle - cash payment', () async {
      final saleNotifier = container.read(saleControllerProvider.notifier);

      await saleNotifier.search('Молоко');
      await waitForSearch();
      var saleState = container.read(saleControllerProvider);
      expect(saleState.searchResults, isNotEmpty);

      saleNotifier.addProduct(saleState.searchResults.first);
      saleState = container.read(saleControllerProvider);
      expect(saleState.items.length, equals(1));
      expect(saleState.items.first.name, contains('Молоко'));

      await saleNotifier.search('Хлеб');
      await waitForSearch();
      saleState = container.read(saleControllerProvider);
      if (saleState.searchResults.isNotEmpty) {
        saleNotifier.addProduct(saleState.searchResults.first);
        saleState = container.read(saleControllerProvider);
        expect(saleState.items.length, equals(2));
      }

      expect(saleState.total, greaterThan(Decimal.zero));
      expect(saleState.isNotEmpty, isTrue);

      final paymentNotifier = container.read(
        paymentControllerProvider.notifier,
      );
      paymentNotifier.initialize(saleState.total);

      var paymentState = container.read(paymentControllerProvider);
      expect(paymentState.totalAmount, equals(saleState.total));

      paymentNotifier.setPaymentType(PaymentType.cash);
      paymentNotifier.setCashReceived(saleState.total + Decimal.parse('100'));

      paymentState = container.read(paymentControllerProvider);
      expect(paymentState.canComplete, isTrue);
      expect(paymentState.change, equals(Decimal.parse('100')));

      final paymentResult = await paymentNotifier.processPayment();
      expect(paymentResult, isTrue);

      saleNotifier.clearSale();
      saleState = container.read(saleControllerProvider);
      expect(saleState.isEmpty, isTrue);
    });

    test('complete sale cycle - card payment', () async {
      final saleNotifier = container.read(saleControllerProvider.notifier);

      await saleNotifier.search('Сахар');
      await waitForSearch();
      var saleState = container.read(saleControllerProvider);
      if (saleState.searchResults.isNotEmpty) {
        saleNotifier.addProduct(saleState.searchResults.first);
      }
      saleState = container.read(saleControllerProvider);

      final paymentNotifier = container.read(
        paymentControllerProvider.notifier,
      );
      paymentNotifier.initialize(saleState.total);
      paymentNotifier.setPaymentType(PaymentType.card);
      paymentNotifier.selectAccount(1);

      final paymentState = container.read(paymentControllerProvider);
      expect(paymentState.canComplete, isTrue);
      expect(paymentState.change, equals(Decimal.zero));

      final result = await paymentNotifier.processPayment();
      expect(result, isTrue);
    });

    test('complete sale cycle - mixed payment', () async {
      final saleNotifier = container.read(saleControllerProvider.notifier);

      await saleNotifier.search('Молоко');
      await waitForSearch();
      var saleState = container.read(saleControllerProvider);
      if (saleState.searchResults.isNotEmpty) {
        saleNotifier.addProduct(
          saleState.searchResults.first,
          quantity: Decimal.fromInt(2),
        );
      }
      saleState = container.read(saleControllerProvider);

      final paymentNotifier = container.read(
        paymentControllerProvider.notifier,
      );
      paymentNotifier.initialize(saleState.total);
      paymentNotifier.setPaymentType(PaymentType.mixed);

      final halfAmount = saleState.total / Decimal.fromInt(2);
      paymentNotifier.setCashReceived(halfAmount.toDecimal());
      paymentNotifier.setCardAmount(halfAmount.toDecimal());

      final paymentState = container.read(paymentControllerProvider);
      expect(paymentState.canComplete, isTrue);

      final result = await paymentNotifier.processPayment();
      expect(result, isTrue);
    });

    test('sale with quantity adjustment', () async {
      final saleNotifier = container.read(saleControllerProvider.notifier);

      await saleNotifier.search('Молоко');
      await waitForSearch();
      var saleState = container.read(saleControllerProvider);
      if (saleState.searchResults.isNotEmpty) {
        saleNotifier.addProduct(saleState.searchResults.first);
      }
      saleState = container.read(saleControllerProvider);
      final initialTotal = saleState.total;

      saleNotifier.incrementQuantity();
      saleState = container.read(saleControllerProvider);
      expect(saleState.selectedItem?.quantity, equals(Decimal.fromInt(2)));
      expect(saleState.total, greaterThan(initialTotal));

      saleNotifier.decrementQuantity();
      saleState = container.read(saleControllerProvider);
      expect(saleState.selectedItem?.quantity, equals(Decimal.fromInt(1)));
      expect(saleState.total, equals(initialTotal));
    });

    test('sale with discount', () async {
      final saleNotifier = container.read(saleControllerProvider.notifier);

      await saleNotifier.search('Молоко');
      await waitForSearch();
      var saleState = container.read(saleControllerProvider);
      if (saleState.searchResults.isNotEmpty) {
        saleNotifier.addProduct(saleState.searchResults.first);
      }
      saleState = container.read(saleControllerProvider);
      final originalTotal = saleState.total;

      saleNotifier.setDiscountPercent(Decimal.fromInt(10));
      saleState = container.read(saleControllerProvider);

      expect(saleState.totalDiscount, greaterThan(Decimal.zero));
      expect(saleState.total, lessThan(originalTotal));
    });

    test('deferred sale flow', () async {
      final saleNotifier = container.read(saleControllerProvider.notifier);

      await saleNotifier.search('Молоко');
      await waitForSearch();
      var saleState = container.read(saleControllerProvider);
      if (saleState.searchResults.isNotEmpty) {
        saleNotifier.addProduct(saleState.searchResults.first);
      }

      await saleNotifier.search('Хлеб');
      await waitForSearch();
      saleState = container.read(saleControllerProvider);
      if (saleState.searchResults.isNotEmpty) {
        saleNotifier.addProduct(saleState.searchResults.first);
      }
      saleState = container.read(saleControllerProvider);

      await saleNotifier.deferSale();
      saleState = container.read(saleControllerProvider);

      expect(saleState.isEmpty, isTrue);
    });

    test('sale with loyalty bonus', () async {
      final saleNotifier = container.read(saleControllerProvider.notifier);

      await saleNotifier.search('Молоко');
      await waitForSearch();
      var saleState = container.read(saleControllerProvider);
      if (saleState.searchResults.isNotEmpty) {
        saleNotifier.addProduct(saleState.searchResults.first);
      }
      saleState = container.read(saleControllerProvider);

      final paymentNotifier = container.read(
        paymentControllerProvider.notifier,
      );
      paymentNotifier.initialize(saleState.total);

      await paymentNotifier.searchLoyaltyCustomer('+77771234567');
      var paymentState = container.read(paymentControllerProvider);

      if (paymentState.hasLoyaltyCustomer) {
        paymentNotifier.setBonusToUse(Decimal.parse('100'));
        paymentState = container.read(paymentControllerProvider);

        expect(paymentState.amountToPay, lessThan(saleState.total));
      }

      paymentNotifier.setPaymentType(PaymentType.cash);
      paymentNotifier.setCashReceived(paymentState.amountToPay);

      paymentState = container.read(paymentControllerProvider);
      expect(paymentState.canComplete, isTrue);
    });

    testWidgets('sale screen UI flow', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: const TestApp(child: Scaffold(body: _TestSaleFlow())),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Корзина пуста'), findsOneWidget);

      await tester.tap(find.byKey(const Key('add_product_btn')));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.text('Молоко 1л'), findsOneWidget);
      expect(find.text('450'), findsOneWidget);

      await tester.tap(find.byKey(const Key('payment_btn')));
      await tester.pumpAndSettle();

      expect(find.text('К оплате'), findsOneWidget);
    });
  });
}

class _TestSaleFlow extends ConsumerWidget {
  const _TestSaleFlow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(saleControllerProvider);
    final notifier = ref.read(saleControllerProvider.notifier);

    if (state.searchResults.isNotEmpty && state.items.isEmpty) {
      Future.microtask(() {
        final currentState = ref.read(saleControllerProvider);
        if (currentState.searchResults.isNotEmpty &&
            currentState.items.isEmpty) {
          notifier.addProduct(currentState.searchResults.first);
        }
      });
    }

    return Column(
      children: [
        if (state.isEmpty)
          const Text('Корзина пуста')
        else
          Expanded(
            child: ListView.builder(
              itemCount: state.items.length,
              itemBuilder: (context, index) {
                final item = state.items[index];
                return ListTile(
                  title: Text(item.name),
                  trailing: Text(item.price.toString()),
                );
              },
            ),
          ),
        ElevatedButton(
          key: const Key('add_product_btn'),
          onPressed: () {
            notifier.search('Молоко');
          },
          child: const Text('Добавить товар'),
        ),
        if (state.isNotEmpty)
          ElevatedButton(
            key: const Key('payment_btn'),
            onPressed: () {},
            child: const Text('К оплате'),
          ),
      ],
    );
  }
}
