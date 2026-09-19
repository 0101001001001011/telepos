library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/account_dao.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/sale/payment_service.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';
import 'package:telepos/presentation/controllers/sale/sale_controller.dart';

import '../support/harness.dart';

void main() {
  final h = E2eHarness();
  late ProviderContainer container;

  setUpAll(() async {
    await h.setUp();
    GetIt.I.registerSingleton<AppDatabase>(h.db);
  });
  tearDownAll(() => h.tearDown());

  setUp(() async {
    await h.db.delete(h.db.saleProductMarks).go();
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

  Future<void> waitForSaleInit(SaleNotifier sale) async {
    for (var i = 0; i < 50; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      if (container.read(saleControllerProvider).receiptNo != null) return;
    }
  }

  Future<int> seedMarkableProduct({
    required int ucode,
    required int barcode,
    required String name,
    required String price,
  }) async {
    final db = GetIt.I<AppDatabase>();
    await db
        .into(db.productInfos)
        .insert(
          ProductInfosCompanion(
            ucode: drift.Value(ucode),
            barcode: drift.Value(barcode),
            name: drift.Value(name),
            type: const drift.Value(0),
            measure: const drift.Value(0),
            quantity: drift.Value(d('100')),
            categoryId: const drift.Value(1),
            isDeleted: const drift.Value(false),
            isMarkable: const drift.Value(true),
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
    return ucode;
  }

  /// Оплатить набранный чек наличными — тем же путём, каким это делает
  /// касса.
  ///
  /// Метка команды собирается из состояния экрана продажи ровно так же,
  /// как её собирает `PaymentController._meta()`: чек и версия приходят
  /// из снимка, который прислала касса, а не выдумываются здесь.
  /// Владелец чека читается из базы — это тот терминал, за которым
  /// набран чек, и другому касса откажет (`pay_not_owner`).
  Future<SaleOutcome> payFor(AppDatabase db) async {
    final state = container.read(saleControllerProvider);
    final row = await db.saleDao.findByKey(state.receiptNo!, state.posId!);
    return GetIt.I<PaymentService>().complete(
      row!.terminalId ?? 0,
      PaymentRequest(type: PaymentType.cash, cashReceived: state.total),
      CartCommandMeta(
        key: 'e2e-${state.receiptNo}',
        baseVersion: state.version,
        receiptNo: state.receiptNo,
      ),
    );
  }

  test(
    'scanned DataMatrix mark is persisted to sale_product and retrievable via '
    'findMarksBySaleProduct (reaches the ОФД receipt)',
    () async {
      final db = GetIt.I<AppDatabase>();

      const ucode = 5001;
      const dataMatrix = '0104607001234567215abcd910093dGVz';
      await seedMarkableProduct(
        ucode: ucode,
        barcode: 4609101,
        name: 'Сигареты Marlboro',
        price: '1200',
      );

      final probe = await db.productInfoDao.findByUcode(ucode);
      expect(
        probe?.isMarkable,
        isTrue,
        reason: 'seed must persist isMarkable=true (gate depends on it)',
      );

      final posAccId = (await db.accountDao.findByType(
        AccountType.pos,
      )).first.id;

      final sale = container.read(saleControllerProvider.notifier);
      await waitForSaleInit(sale);
      expect(
        container.read(saleControllerProvider).receiptNo,
        isNotNull,
        reason: 'sale must initialize before payment',
      );

      // Команда корзины асинхронна с задачи 7: она идёт в базу через
      // контракт `CartService`, а не правит состояние на месте. Без
      // `await` следующая строка читает снимок ДО команды — сумма 0, а
      // продолжение работает поверх уже выброшенного нотифайера.
      await sale.addProduct(
        ProductSearchResult(
          id: ucode,
          name: 'Сигареты Marlboro',
          price: d('1200'),
        ),
      );

      await sale.setMark(dataMatrix);
      final scannedItem = container
          .read(saleControllerProvider)
          .items
          .firstWhere((i) => i.productId == ucode);
      expect(
        scannedItem.mark,
        dataMatrix,
        reason: 'setMark records the code on the selected line (UI state)',
      );

      final total = container.read(saleControllerProvider).total;
      expect(total, d('1200'), reason: 'sale total must be exactly 1200');

      // Ключ чека берётся **до** оплаты: путь `PaymentService.complete`
      // уводит чек из работы, экран продажи это видит подпиской и
      // начинает следующий чек — а прежний `completeSale` состояние
      // экрана не трогал вовсе. Читать номер после оплаты значило бы
      // спрашивать про уже другой чек.
      final paidReceiptNo = container.read(saleControllerProvider).receiptNo!;
      final paidPosId = container.read(saleControllerProvider).posId!;

      // Задача 9 сняла `SaleNotifier.completeSale`: это был второй путь к
      // деньгам, у которого в продукте не было ни одного вызывающего, а
      // чек по нему уходил незафискализованным и ненапечатанным. Журнал
      // идёт тем же путём, что и касса, — `PaymentService.complete`.
      final outcome = await payFor(db);
      expect(
        outcome.paid,
        total,
        reason: 'a markable product WITH a scanned mark must complete',
      );
      expect(container.read(saleControllerProvider).error, isNull);

      final lines = await db.saleProductDao.findBySale(
        paidReceiptNo,
        paidPosId,
      );
      expect(lines.length, 1, reason: 'exactly one sale line persisted');
      final saleProductId = lines.first.id;

      final marks = await db.saleProductDao.findMarksBySaleProduct(
        saleProductId,
      );
      expect(
        marks.length,
        1,
        reason: 'the scanned DataMatrix must be persisted to sale_product',
      );
      expect(
        marks.first.mark,
        dataMatrix,
        reason: 'the persisted mark equals the scanned DataMatrix verbatim',
      );
      expect(
        marks.first.saleProductId,
        saleProductId,
        reason: 'mark is linked to the sale line the fiscal service reads',
      );
    },
  );

  test(
    'a markable product WITHOUT a scanned mark cannot be paid (honest error, '
    'no half-committed sale)',
    () async {
      final db = GetIt.I<AppDatabase>();

      const ucode = 5002;
      await seedMarkableProduct(
        ucode: ucode,
        barcode: 4609102,
        name: 'Парфюм Chanel',
        price: '9000',
      );

      final posAccId = (await db.accountDao.findByType(
        AccountType.pos,
      )).first.id;

      final sale = container.read(saleControllerProvider.notifier);
      await waitForSaleInit(sale);
      final receiptNo = container.read(saleControllerProvider).receiptNo;
      final posId = container.read(saleControllerProvider).posId;
      expect(receiptNo, isNotNull);

      // Команда корзины асинхронна с задачи 7: она идёт в базу через
      // контракт `CartService`, а не правит состояние на месте. Без
      // `await` следующая строка читает снимок ДО команды — сумма 0, а
      // продолжение работает поверх уже выброшенного нотифайера.
      await sale.addProduct(
        ProductSearchResult(id: ucode, name: 'Парфюм Chanel', price: d('9000')),
      );

      final total = container.read(saleControllerProvider).total;
      expect(total, d('9000'));

      // Отказ приходит **значением с именем** (I144), а не булевым `false`
      // с ключом в состоянии экрана: путь оплаты ушёл за
      // `PaymentService.complete` задачей 14, а задача 9 сняла второй,
      // мёртвый (`SaleNotifier.completeSale`).
      Object? refusal;
      try {
        await payFor(db);
      } catch (e) {
        refusal = e;
      }
      expect(
        refusal,
        isA<WireRefusal>(),
        reason: 'a markable product without a mark must NOT be payable',
      );
      expect(
        (refusal! as WireRefusal).code,
        'mark_required',
        reason: 'the error names the missing-mark gate',
      );
      expect(
        (refusal as WireRefusal).message,
        contains('Парфюм Chanel'),
        reason: 'the error names the offending product',
      );

      // До контракта корзины (задача 7) строки чека жили в состоянии экрана,
      // и `completeSale` писала их в базу разом — отсюда прежнее утверждение
      // «сторож срабатывает ДО любой записи в базу, строк нет». С задачи 7
      // корзина **живёт в базе**: `addProduct` кладёт строку сразу, и она там
      // законно есть — это чек в работе, а не половина проведённой продажи.
      // Утверждение переписано по существу, а не ослаблено: половинчатой
      // продажи по-прежнему нет — ни завершённого чека, ни оплаты, ни марки.
      final lines = await db.saleProductDao.findBySale(receiptNo!, posId!);
      expect(
        lines,
        hasLength(1),
        reason: 'the line lives in the working cart — the receipt is in work',
      );
      expect(
        await db.saleDao.findByState(1),
        isEmpty,
        reason: 'no sale may complete when the mark gate blocks it',
      );
      expect(
        await db.paymentDao.findBySale(receiptNo, posId),
        isEmpty,
        reason: 'no payment lines written for a blocked sale',
      );
      final allMarks = await db.select(db.saleProductMarks).get();
      expect(
        allMarks,
        isEmpty,
        reason: 'no mark rows written for a blocked sale',
      );
    },
  );
}
