/// Товар без цены не продаётся даром.
///
/// # Что измерено 2026-09-22
///
/// Корзина сводила два разных случая в один: `price?.sellingPrice ??
/// Decimal.zero`. «Цена ноль» и «цены не завели» становились одинаковым
/// нулём, товар ложился в чек, продажа проходила — магазин отдавал вещь
/// даром и не узнавал об этом.
///
/// Путей было два, и оба текли. Хуже второй: поиск по штрихкоду
/// (`FindByBarcodeUseCase`) тоже отдаёт `?? Decimal.zero`, а это путь
/// СКАНЕРА — самый частый способ пробить товар.
///
/// Проверка на это в проекте БЫЛА: `SaleValidationService.validateSale` с
/// доводом `hasZeroPriceProduct`. Её не звал никто — 304 строки мёртвого
/// кода, выглядевшего живым, вместе с регистрацией в контейнере
/// зависимостей. Снята.
///
/// # Что НЕ чинится
///
/// Ноль, заведённый человеком, законен: подарок и акция — обычное дело.
/// Отказ различает «цены нет» и «цена ноль», и второе пропускает.
library;

import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/sale/cart_service.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async => db.close());

  Future<void> addProduct({
    required int ucode,
    required int barcode,
    required String name,
    Decimal? sellingPrice,
    bool withPriceRow = true,
  }) async {
    await db
        .into(db.productInfos)
        .insert(
          ProductInfosCompanion(
            ucode: Value(ucode),
            barcode: Value(barcode),
            name: Value(name),
            type: const Value(0),
            measure: const Value(0),
            quantity: Value(Decimal.fromInt(10)),
            isDeleted: const Value(false),
          ),
        );
    if (!withPriceRow) return;
    await db
        .into(db.productPrices)
        .insert(
          ProductPricesCompanion(
            ucode: Value(ucode),
            barcode: Value(barcode),
            sellingPrice: Value(sellingPrice),
          ),
        );
  }

  test('код отказа объявлен и отличается от «товар не найден»', () {
    // Свести их в один код значило бы сказать кассиру «такого товара нет»
    // про товар, который он держит в руках.
    expect(cartProductHasNoPriceCode, 'product_has_no_price');
    expect(cartProductHasNoPriceCode, isNot(cartProductNotFoundCode));
  });

  test('строки цены нет вовсе — это не ноль', () async {
    await addProduct(
      ucode: 1,
      barcode: 4607001,
      name: 'Unpriced item',
      withPriceRow: false,
    );
    final price = await db.productPriceDao.findByUcode(1);
    expect(
      price,
      isNull,
      reason: 'заготовка неверна — проба проверяла бы не тот случай',
    );
  });

  test('строка цены есть, но значение пусто — тоже не ноль', () async {
    await addProduct(
      ucode: 2,
      barcode: 4607002,
      name: 'Half-filled item',
      sellingPrice: null,
    );
    final price = await db.productPriceDao.findByUcode(2);
    expect(price, isNotNull);
    expect(
      price!.sellingPrice,
      isNull,
      reason:
          'колонка объявлена nullable, и это второй способ остаться без '
          'цены — строка заведена, число не проставлено',
    );
  });

  test('ноль, заведённый человеком, остаётся нулём', () async {
    await addProduct(
      ucode: 3,
      barcode: 4607003,
      name: 'Promo gift',
      sellingPrice: Decimal.zero,
    );
    final price = await db.productPriceDao.findByUcode(3);
    expect(price?.sellingPrice, Decimal.zero);
    expect(
      price?.sellingPrice,
      isNotNull,
      reason:
          'подарок — законная продажа, и отказывать в ней значило бы чинить '
          'не то',
    );
  });

  test('мёртвой проверки продажи в дереве больше нет', () {
    // Она и была причиной: 304 строки, зарегистрированные в контейнере и не
    // вызванные ни разу, создавали впечатление, что цена проверяется.
    expect(
      Directory(
        'lib/data/usecases/sale',
      ).listSync().any((e) => e.path.contains('sale_validation_service')),
      isFalse,
    );
    expect(
      Directory(
        'lib/domain/usecases/sale',
      ).listSync().any((e) => e.path.contains('sale_validation_service')),
      isFalse,
    );
  });
}
