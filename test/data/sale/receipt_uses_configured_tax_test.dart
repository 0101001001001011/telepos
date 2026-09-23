/// Чек считает налог настроенным движком, а не фискальными настройками.
///
/// # Зачем
///
/// До этой правки движок, схема и экран существовали, а печатаемый чек их
/// не спрашивал: ставка приходила из фискальных настроек одним числом.
/// Владелец мог настроить Денвер и получить на бумаге казахстанские 12 % —
/// и узнать об этом от покупателя.
///
/// # Несущее утверждение
///
/// Настроенный Денвер доезжает до бумаги **целиком**: суммарная ставка,
/// разбивка по четырём юрисдикциям и освобождение еды штатом при
/// обложении её городом.
///
/// # И обратное, не менее важное
///
/// Касса, где налоги не заведены, печатает ровно то же, что печатала. Иначе
/// эта правка сменила бы налог на каждой работающей кассе молча.
library;

import 'dart:convert';
import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/core/constants/enums/tax_treatment.dart';
import 'package:telepos/data/sale/sale_receipt_composer.dart';
import 'package:telepos/domain/tax/tax_preset.dart';

void main() {
  late AppDatabase db;
  late SaleReceiptComposer composer;

  const posId = 1;
  const receiptNo = 501;

  Decimal d(String v) => Decimal.parse(v);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    composer = SaleReceiptComposer(db: db, logger: Talker());

    await db
        .into(db.thisPosEntries)
        .insert(
          ThisPosEntriesCompanion.insert(
            companyName: const Value('Northwind Trading'),
          ),
        );
  });

  tearDown(() => db.close());

  /// Настоящий поставляемый пресет: выдуманный в пробе доказывал бы, что
  /// сборка умеет читать правильную настройку, — но не то, что доезжает
  /// именно Денвер.
  Future<Map<String, int>> applyDenver() => db.taxSettingsDao.applyPreset(
    TaxPreset.fromJson(
      json.decode(
            File('assets/tax_presets/us-co-denver.json').readAsStringSync(),
          )
          as Map<String, Object?>,
    ),
  );

  /// `barcode`, `type` и `measure` обязательны — на этом уже спотыкались.
  Future<void> addProduct(int ucode, String name, {int? categoryId}) => db
      .into(db.productInfos)
      .insert(
        ProductInfosCompanion.insert(
          ucode: Value(ucode),
          barcode: 460700 + ucode,
          name: name,
          type: 0,
          measure: 0,
          taxCategoryId: Value(categoryId),
        ),
      );

  Future<void> sell(List<(int ucode, String price)> items) async {
    var total = Decimal.zero;
    for (final item in items) {
      total += d(item.$2);
    }
    await db
        .into(db.sales)
        .insert(
          SalesCompanion.insert(
            receiptNo: receiptNo,
            posId: posId,
            userId: 1,
            amount: total,
            time: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        );
    var id = 1;
    for (final item in items) {
      await db
          .into(db.saleProducts)
          .insert(
            SaleProductsCompanion.insert(
              id: Value(id++),
              receiptNo: Value(receiptNo),
              posId: const Value(posId),
              ucode: item.$1,
              quantity: Decimal.one,
              price: d(item.$2),
              priceBefore: d(item.$2),
            ),
          );
    }
  }

  test('настроенный Денвер доезжает до бумаги целиком', () async {
    final ids = await applyDenver();
    await addProduct(1, 'Hot coffee');
    await addProduct(2, 'Milk, 1 gal', categoryId: ids['food-home']);
    await sell([(1, '3.50'), (2, '4.29')]);

    final receipt = await composer.compose(receiptNo: receiptNo, posId: posId);

    expect(receipt, isNotNull);
    expect(
      receipt!.vatRatePercent,
      d('9.15'),
      reason: 'ставка чека берётся из настройки, а не из фискальных настроек',
    );
    expect(
      receipt.taxJurisdictions.map((j) => j.name).toList(),
      ['CO State', 'Denver', 'RTD', 'SCFD'],
      reason:
          'разбивка обязана быть на бумаге: покупатель читает её как '
          'объяснение ставки, а бухгалтер отчитывается по каждой доле',
    );
  });

  test(
    'еда для дома: город облагает, штат — нет, и это видно в строке',
    () async {
      final ids = await applyDenver();
      await addProduct(1, 'Hot coffee');
      await addProduct(2, 'Milk, 1 gal', categoryId: ids['food-home']);
      await sell([(1, '3.50'), (2, '4.29')]);

      final receipt = await composer.compose(
        receiptNo: receiptNo,
        posId: posId,
      );

      final coffee = receipt!.products.firstWhere(
        (p) => p.name == 'Hot coffee',
      );
      final milk = receipt.products.firstWhere((p) => p.name == 'Milk, 1 gal');

      expect(coffee.taxRatePercent, d('9.15'));
      expect(
        milk.taxRatePercent,
        d('6.25'),
        reason:
            'штат освободил еду для дома, город и спецрайоны — нет; одно '
            'число на чек этого не выражает',
      );
      expect(
        milk.isTaxExempt,
        isFalse,
        reason:
            'освобождение штата не делает позицию освобождённой вовсе — '
            'город её облагает, и в базу она входит',
      );
    },
  );

  test('ненастроенная касса печатает ровно то, что печатала', () async {
    await addProduct(1, 'Молоко');
    await sell([(1, '500')]);

    final receipt = await composer.compose(receiptNo: receiptNo, posId: posId);

    expect(
      receipt!.taxJurisdictions,
      isEmpty,
      reason: 'разбивки нет — её неоткуда взять',
    );
    expect(
      receipt.products.single.taxRatePercent,
      isNull,
      reason:
          'позиция без выведенной ставки берёт ставку чека; поставить сюда '
          'ноль значило бы объявить товар необлагаемым',
    );
  });

  test('применение набора США меняет уклад и валюту кассы', () async {
    // Набор, применённый наполовину, хуже неприменённого: он выглядит
    // применённым. Пользователь выбирает Денвер, видит на экране 9,15 % —
    // и получает на чеке налог внутри цены и казахстанский знак.
    await applyDenver();

    final pos = await db.thisPosDao.get();
    expect(
      pos!.taxTreatment,
      TaxTreatment.exclusive.index,
      reason:
          'в США налог добавляется сверх цены; оставить «включён в цену» '
          'значит изменить суммы, а не оформление',
    );
    expect(pos.currencySymbol, r'$');
  });

  test(
    'чек США: налог сверх цены, знак перед суммой, без фискализации',
    () async {
      // Три свойства, которые чек брал умолчанием конструктора и потому
      // всегда печатал по-казахстански.
      await applyDenver();
      await db
          .update(db.thisPosEntries)
          .write(const ThisPosEntriesCompanion(countryCode: Value(4)));

      await addProduct(1, 'Hot coffee');
      await sell([(1, '3.50')]);

      final receipt = await composer.compose(
        receiptNo: receiptNo,
        posId: posId,
      );

      expect(
        receipt!.taxTreatment,
        TaxTreatment.exclusive,
        reason: 'уклад берётся из настройки кассы, а не из умолчания',
      );
      expect(
        receipt.currencyBeforeAmount,
        isTrue,
        reason: r'$11.93, а не 11.93$ — свойство страны, а не вкуса',
      );
      expect(
        receipt.hasFiscalisation,
        isFalse,
        reason:
            'в США фискализации нет, и пустой фискальный блок обещал бы '
            'покупателю документ, которого не существует',
      );
    },
  );

  test('ставка чека и его разбивка всегда сходятся', () async {
    // Чек отказывается собираться, когда разбивка не равна ставке. Проба
    // держит то, что эти два числа берутся из ОДНОГО вывода: возьми их из
    // разных мест — и отказ однажды случится у кассира, а не здесь.
    await applyDenver();
    await addProduct(1, 'Hot coffee');
    await sell([(1, '3.50')]);

    final receipt = await composer.compose(receiptNo: receiptNo, posId: posId);

    final sum = receipt!.taxJurisdictions.fold<Decimal>(
      Decimal.zero,
      (a, j) => a + j.ratePercent,
    );
    expect(sum, receipt.vatRatePercent);
  });
}
