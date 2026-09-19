import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/usecases/sale/sale_initiation_use_case_impl.dart';

/// Задача 5 плана «продажа с браузерного терминала».
///
/// `SaleInitiationUseCaseImpl.initiate()` при отсутствии открытой смены
/// открывал её сам, выбирая пользователя как `userId ?? lastShift?.userId ??
/// 1` — на кассе это уже было спорно, а с браузерного терминала недопустимо:
/// смена открылась бы на человека, которого никто не спрашивал, и деньги
/// легли бы на него. Этот тест доказывает, что чек не начинается **и** смена
/// не заводится сама — второе важнее первого, оно и ловит починяемое
/// поведение.
void main() {
  late AppDatabase db;
  late SaleInitiationUseCaseImpl initiation;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    initiation = SaleInitiationUseCaseImpl(db: db, logger: Talker());

    await db.thisPosDao.insertInitialConfig(
      posId: 1,
      companyName: 'ТОО Тест',
      iinbin: null,
      cashBoxName: 'Касса-1',
      countryCode: null,
      currencyCode: null,
      currencySymbol: null,
      currencyNameShort: null,
      paperWidth: null,
      printerHeader: null,
      printerFooter: null,
      accountId: null,
      acquiringAccountId: null,
      rsaPublicKey: null,
    );
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> closeAllShifts() async {
    await (db.update(db.shifts)..where((s) => s.isOpened.equals(true))).write(
      const ShiftsCompanion(isOpened: Value(false)),
    );
  }

  test(
    'без открытой смены чек не начинается и смена не заводится сама',
    () async {
      await closeAllShifts();

      final result = await initiation.initiate(terminalId: 7);

      expect(result.refusal?.code, 'shift_not_open');
      expect(result.sale, isNull, reason: 'отказ — не половинчатый успех');
      expect(
        await db.shiftDao.findOpenedShift(),
        isNull,
        reason: 'смена открылась сама — то самое, что чинится',
      );
    },
  );

  test('с открытой сменой чек начинается как раньше', () async {
    await db
        .into(db.shifts)
        .insert(
          ShiftsCompanion.insert(
            userId: 1,
            openTime: 0,
            isOpened: true,
            isSynced: false,
          ),
        );

    final result = await initiation.initiate(terminalId: 7);

    expect(result.refusal, isNull);
    expect(result.sale, isNotNull);
    expect(result.sale!.state, 0);
  });

  /// Круг правки 4 задачи 7: возобновление ничего не пишет в чек.
  ///
  /// Путь возобновления писал в существующую строку `isWholesale` и оба
  /// типа округления — всё это решает, какая цена берётся строкой, и всё
  /// это менялось **без версии корзины**. Круг правки 3 снял с этого пути
  /// одного вызывающего (`LocalCartService.start`) — то есть лечил
  /// вызывающего, а не пишущего; второй и сегодня главный,
  /// `sale_controller._initSale`, зовётся из пяти мест, и **повторный
  /// вход на экран продажи молча снимал опт с начатого чека**, потому что
  /// состояние экрана по умолчанию розничное.
  test(
    'возобновление не переписывает опт и округления начатого чека',
    () async {
      await db
          .into(db.shifts)
          .insert(
            ShiftsCompanion.insert(
              userId: 1,
              openTime: 0,
              isOpened: true,
              isSynced: false,
            ),
          );

      final started = await initiation.initiate(
        terminalId: 7,
        isWholesale: true,
      );
      final receiptNo = started.sale!.receiptNo;

      // Кассир поставил округление скидок уже после начала чека.
      await db
          .update(db.thisPosEntries)
          .write(const ThisPosEntriesCompanion(discountsRoundType: Value(1)));

      // Повторный вход на экран продажи: розница по умолчанию.
      final resumed = await initiation.initiate(terminalId: 7);

      expect(resumed.sale!.receiptNo, receiptNo);

      final row = await db.saleDao.findByKey(receiptNo, 1);
      expect(
        row!.isWholesale,
        isTrue,
        reason: 'опт снят возобновлением, и версия корзины этого не показала',
      );
      expect(
        row.discountsRoundType,
        0,
        reason: 'правила округления сменились под начатым чеком',
      );
    },
  );
}
