library;

import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/presentation/controllers/payment/payment_controller.dart';
import 'package:telepos/presentation/controllers/sale/sale_controller.dart';

import '../support/harness.dart';

void main() {
  final h = E2eHarness();
  late ProviderContainer container;

  setUpAll(() async {
    await h.setUp();
    GetIt.I.registerSingleton<AppDatabase>(h.db);

    final db = h.db;
    Future<void> seedProduct(int ucode, int barcode, String price) async {
      await db
          .into(db.productInfos)
          .insert(
            ProductInfosCompanion(
              ucode: drift.Value(ucode),
              barcode: drift.Value(barcode),
              name: drift.Value('Дорогой товар $ucode'),
              type: const drift.Value(0),
              measure: const drift.Value(0),
              quantity: drift.Value(d('1000')),
              categoryId: const drift.Value(1),
              isDeleted: const drift.Value(false),
            ),
          );
      await db
          .into(db.productPrices)
          .insert(
            ProductPricesCompanion(
              ucode: drift.Value(ucode),
              barcode: drift.Value(barcode),
              sellingPrice: drift.Value(d(price)),
              wholesalePrice: drift.Value(d(price)),
            ),
          );
    }

    await seedProduct(9001, 4699001, '1500000');
    await seedProduct(9002, 4699002, '1000000');
  });
  tearDownAll(() => h.tearDown());

  setUp(() async {
    await h.db.delete(h.db.payments).go();
    await h.db.delete(h.db.saleProducts).go();
    await h.db.delete(h.db.sales).go();
    await h.db.delete(h.db.shifts).go();

    // Задача 5 плана «Продажа с браузерного терминала»:
    // `SaleInitiationUseCaseImpl.initiate()` больше не открывает смену сама,
    // когда её нет, — она отвечает отказом `shift_not_open`. Этот сценарий
    // чистит смены перед каждой пробой и молча полагался на прежнее
    // самооткрытие; теперь смена открывается **явно**, тем же действием, каким
    // её открывает касса перед продажей, и **на названного человека** — того
    // самого кассира, которого завёл харнесс, а не на выдуманный `userId: 1`.
    //
    // Посев вынесен в `E2eHarness.openShift()` при слиянии: те же девять
    // сценариев чинились дважды и по-разному — ветвь `wire-sale` сеяла
    // смену дословно в каждом файле, ветвь `browser-sale` завела помощник.
    // Взято тело помощника; там же назван и довод про **текущее** время
    // открытия (смена задним числом упёрлась бы в сторож «открыта более 24
    // часов», `kShiftMaxAge`, и продажа отказала бы снова, другой причиной).
    await h.openShift();
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  Future<void> waitForSaleInit() async {
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      if (container.read(saleControllerProvider).receiptNo != null) return;
    }
  }

  Future<({bool ok, String? saleError, int completed})> attemptSale({
    required int ucode,
    required String price,
  }) async {
    final db = GetIt.I<AppDatabase>();

    final saleNotifier = container.read(saleControllerProvider.notifier);
    await waitForSaleInit();
    expect(
      container.read(saleControllerProvider).receiptNo,
      isNotNull,
      reason: 'sale must initialize before payment',
    );

    // Команда корзины асинхронна с задачи 7: она идёт в базу через
    // контракт `CartService`, а не правит состояние на месте. Без
    // `await` следующая строка читает снимок ДО команды — сумма 0, а
    // продолжение работает поверх уже выброшенного нотифайера.
    await saleNotifier.addProduct(
      ProductSearchResult(
        id: ucode,
        name: 'Дорогой товар $ucode',
        price: d(price),
      ),
    );
    final total = container.read(saleControllerProvider).total;
    expect(total, d(price), reason: 'sale total must equal the unit price');

    final payNotifier = container.read(paymentControllerProvider.notifier);
    payNotifier.initialize(total);
    payNotifier.setPaymentType(PaymentType.cash);
    payNotifier.setCashReceived(total);

    final ok = await payNotifier.processPayment();
    // Причина отказа читается с **экрана оплаты**, а не с экрана продажи,
    // и адрес сменила задача 14, а не эта проба. До неё оплату проводил
    // `SaleNotifier.completeSale`, и потолок суммы всплывал в
    // `saleController.error`; теперь завершение живёт за контрактом
    // `PaymentService`, `completeSale` из этого пути не зовётся вовсе, и
    // отказ кассы кладёт в состояние `PaymentNotifier._errorKeyOf`. Кассир
    // читает его фразой: экран оплаты переводит ключ `ErrorLocalizer`,
    // а `error.big_amount_blocked` в словаре есть.
    //
    // Найдено слиянием: на ветви оплаты эта проба зелёной не была ни разу
    // (её держала регрессия задачи 5), а ветвь продажи нового адреса не
    // знала. Утверждать по старому адресу значило бы утверждать про
    // мёртвый путь.
    final payError = container.read(paymentControllerProvider).error;
    final completed = (await db.saleDao.findByState(1)).length;
    return (ok: ok, saleError: payError, completed: completed);
  }

  test('A) total 1.5M with allowBigAmount=false is BLOCKED', () async {
    await h.db.thisPosDao.updateBusinessFlags(allowBigAmount: false);

    final r = await attemptSale(ucode: 9001, price: '1500000');

    expect(
      r.ok,
      isFalse,
      reason: 'payment must fail when big amount is blocked',
    );
    expect(
      r.saleError,
      'error.big_amount_blocked',
      reason: 'the payment screen must surface the big-amount guard error',
    );
    expect(r.completed, 0, reason: 'no sale may complete when blocked');
  });

  test('B) total 1.5M with allowBigAmount=true COMPLETES', () async {
    await h.db.thisPosDao.updateBusinessFlags(allowBigAmount: true);

    final r = await attemptSale(ucode: 9001, price: '1500000');

    expect(
      r.ok,
      isTrue,
      reason: 'large sale must proceed when permission is on',
    );
    expect(r.completed, 1, reason: 'exactly one completed sale');
  });

  test(
    'C) total == 1M (limit, not over) with allowBigAmount=false COMPLETES',
    () async {
      await h.db.thisPosDao.updateBusinessFlags(allowBigAmount: false);

      final r = await attemptSale(ucode: 9002, price: '1000000');

      expect(
        r.ok,
        isTrue,
        reason: 'a sale of exactly 1M is NOT over the limit → always allowed',
      );
      expect(r.completed, 1, reason: 'exactly one completed sale');
    },
  );
}
