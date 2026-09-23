/// Запрет по часам ОСТАНАВЛИВАЕТ продажу, а не только хранится.
///
/// # Что измерено 2026-09-22
///
/// Механизм запрета в продукте был с самого начала: таблица
/// `category_restrictions`, DAO, договор `IsCategoryBlockedUseCase`. Его не
/// звал никто — ни экран продажи, ни корзина, ни провод. То есть настройка
/// существовала на бумаге, а ночная продажа алкоголя проходила везде.
///
/// Эта проба и есть ответ на вопрос «а теперь останавливает?»: она бьёт
/// товар настоящей корзиной, а не проверяет хранилище.
///
/// # Почему оба пути
///
/// Товар кладут в чек двумя способами: сканером (по штрихкоду) и выбором из
/// каталога (по коду). Закрыть один значило бы оставить второй открытым, а
/// сканер — самый частый.
library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker/talker.dart';

import 'package:telepos/data/catalog/local_selling_hours.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/usecases/sale/deferred_sale_service_impl.dart';
import 'package:telepos/data/sale/local_cart_service.dart';
import 'package:telepos/data/usecases/product/find_by_barcode_use_case_impl.dart';
import 'package:telepos/data/usecases/product/search_product_info_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/sale_initiation_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/sale_round_option_use_case_impl.dart';
import 'package:telepos/domain/catalog/selling_hours_repository.dart';
import 'package:telepos/domain/sale/cart_service.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';

const _terminalId = 1;
const _barcode = '4607001000031';

void main() {
  late AppDatabase db;
  late LocalCartService cart;
  late LocalSellingHours hours;

  // Ключ у каждой команды СВОЙ. Одинаковый ключ — это повтор, и корзина
  // честно возвращает прежний снимок, не выполнив команду: первая редакция
  // пробы брала ключ из версии, версия после старта была нулевой, и старт с
  // добавлением получили один ключ. Чек оставался пустым, а выглядело это
  // как «запрет не сработал» — то есть проба обвиняла бы продукт.
  var keys = 0;
  CartCommandMeta meta(int version, {int? receiptNo}) => CartCommandMeta(
    baseVersion: version,
    key: 'k${keys++}',
    // Номер чека обязателен после старта: без него корзина отказывает
    // `cart_wrong_receipt` — команда адресована не тому чеку.
    receiptNo: receiptNo,
  );

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final logger = Talker();
    hours = LocalSellingHours(db);
    cart = LocalCartService(
      db: db,
      logger: logger,
      initiation: SaleInitiationUseCaseImpl(db: db, logger: logger),
      deferred: DeferredSaleServiceImpl(db: db, logger: logger),
      rounding: SaleRoundOptionUseCaseImpl(),
      findByBarcode: FindByBarcodeUseCaseImpl(db: db, logger: logger),
      searchProducts: SearchProductInfoUseCaseImpl(db: db, logger: logger),
    );

    await db
        .into(db.thisPosEntries)
        .insert(
          const ThisPosEntriesCompanion(
            id: Value(1),
            accountId: Value(11),
            cashBoxName: Value('Till-1'),
          ),
        );
    await db
        .into(db.users)
        .insert(const UsersCompanion(id: Value(4), name: Value('Anna')));
    await db
        .into(db.shifts)
        .insert(
          ShiftsCompanion(
            userId: const Value(4),
            openTime: Value(DateTime.now().millisecondsSinceEpoch ~/ 1000),
            isOpened: const Value(true),
            isSynced: const Value(false),
          ),
        );
    await db
        .into(db.categories)
        .insert(
          CategoriesCompanion.insert(
            id: const Value(1),
            name: const Value('Alcohol'),
            createTime: DateTime.now(),
          ),
        );
    await db
        .into(db.productInfos)
        .insert(
          ProductInfosCompanion.insert(
            ucode: const Value(100),
            barcode: int.parse(_barcode),
            name: 'Craft beer',
            type: 0,
            measure: 0,
            quantity: Value(Decimal.fromInt(50)),
            categoryId: const Value(1),
            isDeleted: const Value(false),
          ),
        );
    await db
        .into(db.productPrices)
        .insert(
          ProductPricesCompanion(
            ucode: const Value(100),
            barcode: Value(int.parse(_barcode)),
            sellingPrice: Value(Decimal.parse('3.50')),
          ),
        );
  });

  tearDown(() async => db.close());

  /// Начатый чек — иначе корзина откажет «чек не начат» и проба покраснеет
  /// не о том.
  Future<CartView> started() =>
      cart.start(terminalId: _terminalId, wholesale: false, meta: meta(0));

  Future<void> banAllDay() => hours.save(
    // Окно на целые сутки без минуты: запрет действует в любой час, когда
    // бы проба ни шла. Привязать её к настоящему часу значило бы завести
    // пробу, зелёную только по ночам.
    const SellingHoursRule(
      categoryId: 1,
      categoryName: 'Alcohol',
      beginTime: '00:00',
      endTime: '23:59',
    ),
  );

  test('без запрета товар пробивается', () async {
    final begun = await started();
    final view = await cart.addByBarcode(
      _terminalId,
      _barcode,
      meta(begun.version, receiptNo: begun.receiptNo),
    );
    expect(view.lines, hasLength(1));
  });

  test('сканер: запрет останавливает продажу', () async {
    await banAllDay();
    final begun = await started();
    await expectLater(
      cart.addByBarcode(
        _terminalId,
        _barcode,
        meta(begun.version, receiptNo: begun.receiptNo),
      ),
      throwsA(
        isA<WireRefusal>().having(
          (r) => r.code,
          'код',
          cartSellingHoursBannedCode,
        ),
      ),
    );
  });

  test('выбор из каталога: тот же запрет', () async {
    // Закрыть один путь значило бы оставить второй открытым.
    await banAllDay();
    final begun = await started();
    await expectLater(
      cart.addProduct(
        _terminalId,
        100,
        Decimal.one,
        meta(begun.version, receiptNo: begun.receiptNo),
      ),
      throwsA(
        isA<WireRefusal>().having(
          (r) => r.code,
          'код',
          cartSellingHoursBannedCode,
        ),
      ),
    );
  });

  test('отказ называет товар И окно', () async {
    await banAllDay();
    final begun = await started();
    try {
      await cart.addByBarcode(
        _terminalId,
        _barcode,
        meta(begun.version, receiptNo: begun.receiptNo),
      );
      fail('запрет не сработал');
    } on WireRefusal catch (refusal) {
      expect(refusal.message, contains('Craft beer'));
      expect(refusal.message, contains('00:00'));
      expect(refusal.message, contains('23:59'));
    }
  });

  test('запрет не трогает товар другой категории', () async {
    await banAllDay();
    await db
        .into(db.categories)
        .insert(
          CategoriesCompanion.insert(
            id: const Value(2),
            name: const Value('Bread'),
            createTime: DateTime.now(),
          ),
        );
    await db
        .into(db.productInfos)
        .insert(
          ProductInfosCompanion.insert(
            ucode: const Value(200),
            barcode: 4607002000032,
            name: 'Rye loaf',
            type: 0,
            measure: 0,
            quantity: Value(Decimal.fromInt(10)),
            categoryId: const Value(2),
            isDeleted: const Value(false),
          ),
        );
    await db
        .into(db.productPrices)
        .insert(
          ProductPricesCompanion(
            ucode: const Value(200),
            barcode: const Value(4607002000032),
            sellingPrice: Value(Decimal.parse('1.20')),
          ),
        );

    final begun = await started();
    final view = await cart.addByBarcode(
      _terminalId,
      '4607002000032',
      meta(begun.version, receiptNo: begun.receiptNo),
    );
    expect(
      view.lines,
      hasLength(1),
      reason: 'запрет растёкся на всю кассу — это хуже, чем его отсутствие',
    );
  });

  test('выключенный запрет продажу не держит', () async {
    await hours.save(
      const SellingHoursRule(
        categoryId: 1,
        categoryName: 'Alcohol',
        beginTime: '00:00',
        endTime: '23:59',
        isActive: false,
      ),
    );
    final begun = await started();
    final view = await cart.addByBarcode(
      _terminalId,
      _barcode,
      meta(begun.version, receiptNo: begun.receiptNo),
    );
    expect(view.lines, hasLength(1));
  });

  test('товар без категории запретом не задевается', () async {
    // У товара, заведённого наспех, категории нет. Отказать ему значило бы
    // остановить продажу там, где никакого правила не ставили.
    await banAllDay();
    await db
        .into(db.productInfos)
        .insert(
          ProductInfosCompanion.insert(
            ucode: const Value(300),
            barcode: 4607003000033,
            name: 'Loose item',
            type: 0,
            measure: 0,
            quantity: Value(Decimal.fromInt(10)),
            isDeleted: const Value(false),
          ),
        );
    await db
        .into(db.productPrices)
        .insert(
          ProductPricesCompanion(
            ucode: const Value(300),
            barcode: const Value(4607003000033),
            sellingPrice: Value(Decimal.parse('9.99')),
          ),
        );

    final begun = await started();
    final view = await cart.addByBarcode(
      _terminalId,
      '4607003000033',
      meta(begun.version, receiptNo: begun.receiptNo),
    );
    expect(view.lines, hasLength(1));
  });
}
