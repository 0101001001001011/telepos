library;

import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:telepos/presentation/controllers/sale/sale_controller.dart';
import 'package:telepos/presentation/controllers/payment/payment_controller.dart';

import '../helpers/helpers.dart';
import 'test_utils.dart';

/// Дождаться результатов поиска — **по состоянию, а не по часам**.
///
/// Здесь стояло `Future.delayed(500ms)` против задержки ввода в 300 мс, и
/// под нагрузкой (прогон нескольких каталогов разом) пятисот миллисекунд
/// не хватало: `expect(searchResults, isNotEmpty)` падал с
/// `Expected: non-empty / Actual: []`. Измерено кругом правки 4 задачи 14:
/// та же краснота воспроизводится **на дереве без единой правки этого
/// круга** (`git stash`, тот же прогон), то есть хрупкость стенда старше
/// задачи 14 — но чинить её выпало здесь, потому что иначе ложную
/// красноту припишут ей.
///
/// Ожидание по состоянию не выдумывает предела терпения: если поиск не
/// дал результата вовсе, проба всё равно упадёт — но на своём
/// утверждении, а не на часах.
Future<void> waitForSearch(ProviderContainer container) async {
  for (var i = 0; i < 200; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final state = container.read(saleControllerProvider);
    if (!state.isSearching && state.searchResults.isNotEmpty) return;
  }
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
      await waitForSearch(container);
      var saleState = container.read(saleControllerProvider);
      expect(saleState.searchResults, isNotEmpty);

      await saleNotifier.addProduct(saleState.searchResults.first);
      saleState = container.read(saleControllerProvider);
      expect(saleState.items.length, equals(1));
      expect(saleState.items.first.name, contains('Молоко'));

      await saleNotifier.search('Хлеб');
      await waitForSearch(container);
      saleState = container.read(saleControllerProvider);
      if (saleState.searchResults.isNotEmpty) {
        await saleNotifier.addProduct(saleState.searchResults.first);
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

      // **Обычный путь, а не аварийный** (круг правки 2 задачи 14). До
      // него счетов в стенде не было ни одного, и оплата уходила в путь
      // «мастер настройки прошёл криво — заводим счёт»: сценарий зеленел,
      // ничего не проверяя про то, куда легли деньги. Здесь сказано
      // прямо: касса не завела ни одного счёта, потому что ей было куда
      // положить.
      expect(
        (await cartDb.accountDao.findAll()).map((a) => a.id).toList()..sort(),
        [1, 2],
        reason: 'оплата ушла аварийным путём и завела себе счёт',
      );

      await saleNotifier.clearSale();
      saleState = container.read(saleControllerProvider);
      expect(saleState.isEmpty, isTrue);
    });

    test(
      'смешанная оплата на кассе без видимых банковских счетов проходит',
      () async {
        // **Путь экрана, а не вызов контракта напрямую** — иначе проба
        // снова не заметила бы расхождения (круг правки 3).
        //
        // Касса без видимых банковских счетов: кассир жмёт «Наличные»
        // (выбирается счёт кассы), потом «Смешанная» — автоподбор ничего
        // не находит. До правки он **молча оставлял** прежний выбор, счёт
        // кассы уезжал в теле, и две строки платежей сталкивались в базе
        // по уникальному ключу «чек, касса, счёт получателя»: кассиру
        // прилетал сырой `SqliteException(2067)` с именами столбцов
        // схемы, а чек оставался занят ключом несостоявшейся оплаты.
        await cartDb.customStatement(
          'UPDATE accounts SET visible_to_pos = 0 WHERE type = 1',
        );

        final saleNotifier = container.read(saleControllerProvider.notifier);
        await saleNotifier.search('Молоко');
        await waitForSearch(container);
        var saleState = container.read(saleControllerProvider);
        await saleNotifier.addProduct(saleState.searchResults.first);
        saleState = container.read(saleControllerProvider);

        final paymentNotifier = container.read(
          paymentControllerProvider.notifier,
        );
        paymentNotifier.initialize(saleState.total);

        // Ровно та последовательность нажатий, что у кассира.
        paymentNotifier.setPaymentType(PaymentType.cash);
        await Future<void>.delayed(Duration.zero);
        expect(
          container.read(paymentControllerProvider).selectedAccountId,
          isNotNull,
          reason: 'наличные выбирают счёт кассы — иначе проба вырождена',
        );

        paymentNotifier.setPaymentType(PaymentType.mixed);
        await Future<void>.delayed(Duration.zero);
        expect(
          container.read(paymentControllerProvider).selectedAccountId,
          isNull,
          reason: 'счёт кассы остался выбранным под безналичную часть',
        );

        final half = (saleState.total / Decimal.fromInt(2)).toDecimal(
          scaleOnInfinitePrecision: 3,
        );
        paymentNotifier.setCardAmount(half);
        paymentNotifier.setCashReceived(saleState.total - half);

        expect(await paymentNotifier.processPayment(), isTrue);

        // Наличная часть — на счёт кассы, безналичная — на счёт
        // эквайринга, который касса подобрала сама (видимых банковских
        // нет). Два **разных** счёта: на одном они столкнулись бы в базе.
        final payees = lastPayeeAccountIds();
        expect(payees, hasLength(2));
        expect(payees.first, 2, reason: 'наличные — на счёт кассы');
        expect(
          payees.toSet(),
          hasLength(2),
          reason: 'счета обязаны различаться',
        );
      },
    );

    test('complete sale cycle - card payment', () async {
      final saleNotifier = container.read(saleControllerProvider.notifier);

      await saleNotifier.search('Сахар');
      await waitForSearch(container);
      var saleState = container.read(saleControllerProvider);
      if (saleState.searchResults.isNotEmpty) {
        await saleNotifier.addProduct(saleState.searchResults.first);
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

      // **Куда легли деньги, а не «получилось»** (круг правки 3). Это
      // один из двух путей, читающих номер счёта из тела запроса, и до
      // этой пробы состав платежей сквозным набором не проверялся вовсе.
      expect(lastPayeeAccountIds(), [
        1,
      ], reason: 'карта обязана лечь на названный банковский счёт');
    });

    test('complete sale cycle - mixed payment', () async {
      final saleNotifier = container.read(saleControllerProvider.notifier);

      await saleNotifier.search('Молоко');
      await waitForSearch(container);
      var saleState = container.read(saleControllerProvider);
      if (saleState.searchResults.isNotEmpty) {
        await saleNotifier.addProduct(
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
      await waitForSearch(container);
      var saleState = container.read(saleControllerProvider);
      if (saleState.searchResults.isNotEmpty) {
        await saleNotifier.addProduct(saleState.searchResults.first);
      }
      saleState = container.read(saleControllerProvider);
      final initialTotal = saleState.total;

      await saleNotifier.incrementQuantity();
      saleState = container.read(saleControllerProvider);
      expect(saleState.selectedItem?.quantity, equals(Decimal.fromInt(2)));
      expect(saleState.total, greaterThan(initialTotal));

      await saleNotifier.decrementQuantity();
      saleState = container.read(saleControllerProvider);
      expect(saleState.selectedItem?.quantity, equals(Decimal.fromInt(1)));
      expect(saleState.total, equals(initialTotal));
    });

    test('sale with discount', () async {
      final saleNotifier = container.read(saleControllerProvider.notifier);

      await saleNotifier.search('Молоко');
      await waitForSearch(container);
      var saleState = container.read(saleControllerProvider);
      if (saleState.searchResults.isNotEmpty) {
        await saleNotifier.addProduct(saleState.searchResults.first);
      }
      saleState = container.read(saleControllerProvider);
      final originalTotal = saleState.total;

      await saleNotifier.setDiscountPercent(Decimal.fromInt(10));
      saleState = container.read(saleControllerProvider);

      expect(saleState.totalDiscount, greaterThan(Decimal.zero));
      expect(saleState.total, lessThan(originalTotal));
    });

    test('deferred sale flow', () async {
      final saleNotifier = container.read(saleControllerProvider.notifier);

      await saleNotifier.search('Молоко');
      await waitForSearch(container);
      var saleState = container.read(saleControllerProvider);
      if (saleState.searchResults.isNotEmpty) {
        await saleNotifier.addProduct(saleState.searchResults.first);
      }

      await saleNotifier.search('Хлеб');
      await waitForSearch(container);
      saleState = container.read(saleControllerProvider);
      if (saleState.searchResults.isNotEmpty) {
        await saleNotifier.addProduct(saleState.searchResults.first);
      }
      saleState = container.read(saleControllerProvider);

      await saleNotifier.deferSale();
      saleState = container.read(saleControllerProvider);

      expect(saleState.isEmpty, isTrue);
    });

    test('sale with loyalty bonus', () async {
      final saleNotifier = container.read(saleControllerProvider.notifier);

      await saleNotifier.search('Молоко');
      await waitForSearch(container);
      var saleState = container.read(saleControllerProvider);
      if (saleState.searchResults.isNotEmpty) {
        await saleNotifier.addProduct(saleState.searchResults.first);
      }
      saleState = container.read(saleControllerProvider);

      final paymentNotifier = container.read(
        paymentControllerProvider.notifier,
      );
      paymentNotifier.initialize(saleState.total);

      await paymentNotifier.searchLoyaltyCustomer('+77771234567');
      var paymentState = container.read(paymentControllerProvider);

      if (paymentState.hasLoyaltyCustomer) {
        await paymentNotifier.setBonusToUse(Decimal.parse('100'));
        paymentState = container.read(paymentControllerProvider);

        expect(paymentState.amountToPay, lessThan(saleState.total));
      }

      paymentNotifier.setPaymentType(PaymentType.cash);
      paymentNotifier.setCashReceived(paymentState.amountToPay);

      paymentState = container.read(paymentControllerProvider);
      expect(paymentState.canComplete, isTrue);
    });

    test('подсветка идёт за изменившейся строкой, а не за последней', () async {
      // Задача 8. Куда лягут новые единицы, решает касса: слияние идёт в
      // строку с той же видимой ценой (`LocalCartService._mergeTarget`), и
      // «выбрать последнюю строку» ошибается ровно в этом случае — кассир
      // пробил товар, лежащий первым, а подсветка уехала бы вниз чека.
      final saleNotifier = container.read(saleControllerProvider.notifier);
      for (var i = 0; i < 30; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        if (container.read(saleControllerProvider).receiptNo != null) break;
      }
      expect(container.read(saleControllerProvider).receiptNo, isNotNull);

      await saleNotifier.addProduct(
        ProductSearchResult(
          id: 1001,
          name: 'Молоко 1л',
          price: Decimal.parse('450'),
        ),
      );
      final firstLine = container.read(saleControllerProvider).selectedItemId;
      expect(firstLine, isNotNull);

      await saleNotifier.addProduct(
        ProductSearchResult(
          id: 1002,
          name: 'Хлеб белый',
          price: Decimal.parse('150'),
        ),
      );
      expect(
        container.read(saleControllerProvider).selectedItemId,
        isNot(firstLine),
        reason: 'новая строка обязана стать выбранной',
      );

      // Тот же товар второй раз — сливается в первую строку.
      await saleNotifier.addProduct(
        ProductSearchResult(
          id: 1001,
          name: 'Молоко 1л',
          price: Decimal.parse('450'),
        ),
      );
      final after = container.read(saleControllerProvider);
      expect(after.items, hasLength(2), reason: 'слияние не сработало');
      expect(
        after.selectedItemId,
        firstLine,
        reason:
            'подсветка уехала на последнюю строку чека, а не на ту, '
            'которую кассир только что изменил',
      );
    });

    testWidgets('sale screen UI flow', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: const TestApp(child: Scaffold(body: _TestSaleFlow())),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Корзина пуста'), findsOneWidget);

      // Задача 8: корзина живёт в настоящей базе за контрактом
      // `CartService`, и её чтения — настоящий асинхронный ввод-вывод.
      // `pump()` крутит только поддельные таймеры, а не цикл событий:
      // без `runAsync` начало чека и поиск не завершаются вовсе, и экран
      // остаётся пустым не потому, что дефект, а потому, что тест не дал
      // им дойти. Та же причина, по которой `watchTables` не пользуется
      // `Selectable.watch()` — см. его докстринг.
      await tester.tap(find.byKey(const Key('add_product_btn')));
      // Задержка ввода — поддельный таймер (его крутит `pump`), а чтения
      // базы — настоящий ввод-вывод (его крутит только `runAsync`).
      // Поэтому шаги чередуются: без `runAsync` начало чека и поиск не
      // завершаются вовсе, и экран остаётся пустым не потому, что дефект,
      // а потому, что тест не дал им дойти. Та же причина, по которой
      // `watchTables` не пользуется `Selectable.watch()` — см. его
      // докстринг.
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 200));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
      }
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
          unawaited(notifier.addProduct(currentState.searchResults.first));
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
