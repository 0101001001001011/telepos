import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/data/database/app_database.dart';

/// Задача 3 плана «продажа с браузерного терминала»: `findInProgress`
/// перестаёт означать «единственный чек кассы» и начинает означать «чек
/// **этого** рабочего места» (`terminalId`, схема v37, задача 2).
///
/// До v37 рабочее место на кассе было одно, и `state = 0` определяло чек
/// однозначно. С браузерным терминалом рабочих мест на одной кассе может
/// быть больше одного — и довод обязателен намеренно: молчаливое умолчание
/// (взять первый попавшийся `state = 0`) вернуло бы ровно ту ошибку, ради
/// которой довод и заведён, — чужой чек, продолженный как свой.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seedSale({
    required int receiptNo,
    required int posId,
    required int state,
    int? terminalId,
  }) async {
    await db
        .into(db.sales)
        .insert(
          SalesCompanion.insert(
            receiptNo: receiptNo,
            posId: posId,
            userId: 1,
            amount: Decimal.zero,
            time: 0,
            state: Value(state),
            terminalId: Value(terminalId),
          ),
        );
  }

  test('чек в работе виден своему рабочему месту и не виден чужому', () async {
    await seedSale(receiptNo: 1, posId: 1, state: 0, terminalId: 7);

    expect(
      (await db.saleDao.findInProgress(posId: 1, terminalId: 7))?.receiptNo,
      1,
    );
    expect(await db.saleDao.findInProgress(posId: 1, terminalId: 9), isNull);
  });

  test('отложенный чек не принадлежит никому', () async {
    await seedSale(receiptNo: 2, posId: 1, state: 3, terminalId: null);

    expect(await db.saleDao.findInProgress(posId: 1, terminalId: 7), isNull);
    expect((await db.saleDao.findByState(3)).single.receiptNo, 2);
  });

  test(
    'два рабочих места набирают разные чеки и не видят корзин друг друга',
    () async {
      await seedSale(receiptNo: 10, posId: 1, state: 0, terminalId: 7);
      await seedSale(receiptNo: 11, posId: 1, state: 0, terminalId: 9);

      final ownOfSeven = await db.saleDao.findInProgress(
        posId: 1,
        terminalId: 7,
      );
      final ownOfNine = await db.saleDao.findInProgress(
        posId: 1,
        terminalId: 9,
      );

      expect(ownOfSeven?.receiptNo, 10);
      expect(ownOfNine?.receiptNo, 11);

      // Существо, а не форма: терминалу 7 недоступна ни строка, ни
      // количество товаров чужого чека — только собственный номер.
      expect(ownOfSeven?.receiptNo, isNot(ownOfNine?.receiptNo));
      expect(await db.saleDao.findInProgress(posId: 1, terminalId: 42), isNull);
    },
  );

  // Круг правки 4 задачи 7: до него **этот файл — про владение чеком —
  // проходил целиком с вырезанным предикатом кассы**. Проба жила в тесте
  // корзины, то есть у потребителя, а не у самого правила; здесь её не
  // было ни в каком виде.
  test(
    'чек соседней кассы не принадлежит рабочему месту с тем же номером',
    () async {
      // Строки чужих касс попадают в базу штатно: обмен и слияние тянут
      // чеки других касс сети (`findLastForeign` прямо на них рассчитан).
      // Совпадает всё, кроме кассы.
      await seedSale(receiptNo: 1, posId: 2, state: 0, terminalId: 7);

      expect(
        await db.saleDao.findInProgress(posId: 1, terminalId: 7),
        isNull,
        reason: 'чек соседней кассы отдан как свой',
      );
      expect(
        (await db.saleDao.findInProgress(posId: 2, terminalId: 7))?.receiptNo,
        1,
        reason: 'на своей кассе чек обязан находиться',
      );
    },
  );

  test('свой и чужой чек с одним номером не путаются', () async {
    // Номер чека уникален **внутри кассы**: у `Sales` составной ключ
    // `{receiptNo, posId}`, и `receiptNo = 1` на двух кассах — норма.
    await seedSale(receiptNo: 1, posId: 1, state: 0, terminalId: 7);
    await seedSale(receiptNo: 1, posId: 2, state: 0, terminalId: 7);

    final own = await db.saleDao.findInProgress(posId: 1, terminalId: 7);
    expect(own?.posId, 1, reason: 'из двух чеков выбран чек чужой кассы');
  });
}
