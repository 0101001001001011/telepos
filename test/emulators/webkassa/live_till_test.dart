library;

import 'dart:convert';
import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/fiscal/fiscal_settings_store.dart';
import 'package:telepos/domain/fiscal/fiscal_failure_reason.dart';
import 'package:telepos/domain/fiscal/fiscal_models.dart';
import 'package:telepos/domain/fiscal/fiscal_settings.dart';
import 'package:telepos/domain/fiscal/fiscal_offset_settings.dart';
import 'package:telepos/domain/usecases/fiscal/fiscal_service.dart';

import '../../e2e/support/harness.dart';
import 'emulator.dart';
import 'state.dart';

/// Живой проход: **настоящая касса** фискализует **настоящую продажу** из
/// **настоящей базы** через эмулятор по настоящему HTTP.
///
/// # Чем это отличается от `probe.dart`, и зачем нужны оба
///
/// Проба ведёт `WebKassaProvider` напрямую и кормит его позициями, собранными
/// руками. Здесь не так: поднимается **весь граф зависимостей кассы**
/// (`configureDependencies` — тот же вызов, что делает `main.dart`),
/// настройки читаются из настоящего `SharedPreferences` тем же
/// `StoreFiscalSettingsSource`, провайдера выдаёт настоящий
/// `FiscalProviderRegistry` в обёртке `OfflineQueueingProvider`, а позиции
/// строит `FiscalServiceImpl._buildSalePositions` — **из строк продажи в
/// базе**. Ровно ту дыру, которую проба честно называет своей, закрывает этот
/// файл.
///
/// Адрес эмулятора попадает в кассу **тем же путём, каким его вписывает
/// человек на экране фискальных настроек**: ключ `fiscal_settings_v1` в
/// prefs, поле `baseUrl`. Ни строки продуктового кода для этого не менялось.
///
/// # Чего этот проход НЕ доказывает
///
/// * Что настоящая WebKassa ответила бы так же. Смотри докстринг
///   `emulator.dart` — там это разобрано целиком.
/// * Что **экран** фискальных настроек кладёт в prefs именно то, что здесь
///   положено руками. Экран сюда не входит: он проверяется только запуском
///   приложения.
/// * Что чек напечатан и что ящик открылся. Ни принтера, ни ящика здесь нет.
///
/// # Ловушка, которая укусит первой
///
/// `StoreFiscalSettingsSource.load()` отдаёт настройки из prefs **только
/// если** `operatorType != none`; иначе падает на `ThisPosFiscalSettingsSource`,
/// а тот жёстко ставит `baseUrl: pos.webkassaHost`. Кто впишет адрес
/// эмулятора, не выбрав оператора, получит чужой адрес и решит, что эмулятор
/// не работает. И вторая: непустой `localModuleUrl` перебивает `baseUrl` —
/// `WebKassaProvider._baseUrl` смотрит на него первым.
void main() {
  final h = E2eHarness();
  WebKassaEmulator? emulator;
  late EmulatorState state;
  late String baseUrl;

  /// Адрес **отдельно поднятого** эмулятора, если он есть.
  ///
  /// ```
  /// dart run test/emulators/webkassa/emulator.dart --port 8085
  /// TELEPOS_EMUL_URL=http://127.0.0.1:8085 flutter test test/emulators/webkassa/live_till_test.dart
  /// ```
  ///
  /// Тогда эмулятор — настоящий чужой процесс на настоящем сокете, и от
  /// боевой WebKassa он отличается **только адресом**, как и обещано. Журнал
  /// в этом случае печатает сам эмулятор в свою консоль; проверки конверта
  /// здесь пропускаются — своего состояния у теста нет, и утверждать про
  /// чужой журнал он не вправе.
  final external = Platform.environment['TELEPOS_EMUL_URL'];
  final inProcess = external == null || external.isEmpty;

  const cashbox = 'SWK00000001';
  const regNumber = '000000000001';

  setUp(() async {
    state = EmulatorState(
      cashboxes: {
        cashbox: EmulatedCashbox(
          uniqueNumber: cashbox,
          registrationNumber: regNumber,
          now: DateTime.now(),
        ),
      },
      login: 'emul',
      password: 'emul',
      tokenTtl: const Duration(hours: 1),
      vat: VatMode.off,
    );
    if (inProcess) {
      final started = WebKassaEmulator(state: state, echo: false);
      await started.start('127.0.0.1', 0);
      emulator = started;
      baseUrl = started.baseUri.toString();
    } else {
      emulator = null;
      baseUrl = external;
      // Чужой процесс держит своё состояние между прогонами: без сброса
      // второй прогон получил бы код 14 на первой же продаже и был бы
      // принят за дефект.
      await _resetExternal(baseUrl);
    }

    final settings = FiscalSettings(
      operatorType: FiscalOperatorType.webkassa,
      testMode: true,
      baseUrl: baseUrl,
      login: 'emul',
      password: 'emul',
      apiKey: 'emulated-integrator-key',
      cashboxUniqueNumber: cashbox,
      registrationNumber: regNumber,
    );

    await h.setUp(
      prefs: {FiscalSettingsStore.prefsKey: jsonEncode(settings.toJson())},
    );
    GetIt.I.registerSingleton<AppDatabase>(h.db);
  });

  tearDown(() async {
    await emulator?.stop();
    await h.tearDown();
  });

  test('касса фискализует продажу из базы через эмулятор', () async {
    final db = GetIt.I<AppDatabase>();

    // Настоящий товар и настоящие строки продажи: именно из них
    // `_buildSalePositions` соберёт позиции. Название латиницей осталось от
    // времён, когда кириллица до сервера не доезжала (починено 2026-09-13);
    // русское название по всей цепочке закрывает
    // `test/data/fiscal/cyrillic_receipt_fiscalized_test.dart`.
    await db
        .into(db.productInfos)
        .insert(
          ProductInfosCompanion(
            ucode: const drift.Value(90001),
            barcode: const drift.Value(4870000000001),
            name: const drift.Value('Emulated bread'),
            type: const drift.Value(0),
            measure: const drift.Value(0),
            quantity: drift.Value(Decimal.fromInt(100)),
            categoryId: const drift.Value(1),
            isDeleted: const drift.Value(false),
          ),
        );

    const receiptNo = 4242;
    const posId = 1;
    // Сама продажа — **строкой в базе**, а не только её товарами.
    //
    // Без неё состояние невозможно в бою: номер чека выдаёт
    // `ReceiptNumbers.withNext`, вставляя строку `Sales` в той же
    // транзакции, и товары без продажи не появляются никогда. Проба жила
    // без неё, пока ключ фискального документа не читал базу; с 2026-09-19
    // ключ несёт время чека (`sale-<time>-<номер>-<касса>`), и продажа без
    // строки честно отказывает «ключ собрать не из чего».
    await db
        .into(db.sales)
        .insert(
          SalesCompanion.insert(
            receiptNo: receiptNo,
            posId: posId,
            userId: 1,
            amount: Decimal.parse('501.00'),
            time: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            state: const drift.Value(1),
          ),
        );
    await db
        .into(db.saleProducts)
        .insert(
          SaleProductsCompanion(
            receiptNo: const drift.Value(receiptNo),
            posId: const drift.Value(posId),
            ucode: const drift.Value(90001),
            barcode: const drift.Value(4870000000001),
            categoryId: const drift.Value(1),
            quantity: drift.Value(Decimal.fromInt(2)),
            price: drift.Value(Decimal.parse('250.50')),
            priceBefore: drift.Value(Decimal.parse('250.50')),
          ),
        );

    final fiscal = GetIt.I<FiscalService>();
    final result = await fiscal.fiscalizeSale(
      saleReceiptNo: receiptNo,
      salePosId: posId,
      amount: Decimal.parse('501.00'),
      cashAmount: Decimal.parse('501.00'),
      cardAmount: Decimal.zero,
      mobileAmount: Decimal.zero,
      bonusAmount: Decimal.zero,
      offsetAmount: Decimal.zero,
      offsetLayout: OffsetFiscalLayout.discount,
      excludeCertificatePositions: false,
    );

    // --- журнал эмулятора печатается целиком: он и есть доказательство ---
    //
    // При внешнем эмуляторе журнал берётся его же пультом `/_emul/journal`:
    // состояние живёт в чужом процессе, и читать память теста было бы
    // самообманом — она пуста и была бы пуста при любом исходе.
    final journal = inProcess ? state.journal : await _externalJournal(baseUrl);
    // ignore: avoid_print
    print(
      '\n--- Журнал эмулятора (${journal.length} записей, '
      '${inProcess ? 'в процессе' : 'внешний: $baseUrl'}) ---',
    );
    for (final entry in journal) {
      // ignore: avoid_print
      print(entry.line);
    }

    expect(
      result.success,
      isTrue,
      reason:
          'касса не фискализовала: ${result.errorCode.name} '
          '${result.errorMessage}',
    );
    expect(
      result.hasFiscalSign,
      isTrue,
      reason: 'успех без фискального признака — это находка №1, а не проход',
    );
    expect(result.registrationNumber, regNumber);

    // Конверт пришёл от `_buildSalePositions`, а не от руки.
    final check = journal.firstWhere((e) => e.path == '/api/v4/check');
    final positions = (check.request['Positions'] as List)
        .cast<Map<String, Object?>>();
    expect(positions, hasLength(1));
    expect(
      positions.single['PositionName'],
      'Emulated bread',
      reason: 'название взято из ProductInfos кассы, а не выдумано пробой',
    );
    expect(positions.single['Count'], 2);
    expect(positions.single['Price'], 250.5);
    expect(
      check.request['CashboxUniqueNumber'],
      cashbox,
      reason:
          'заводской номер приехал из prefs через StoreFiscalSettingsSource',
    );
    // Эпоха ключа — **время самого чека**, прочитанное из той же строки, из
    // которой его берёт продукт. Вписать сюда число нельзя: оно своё у
    // каждого прогона. Вычислять его вторым способом — тоже: сверка
    // построителя с самим собой зеленела бы и на сломанном ключе (эту
    // ошибку в соседней пробе уже ловили диверсией 2026-09-19).
    final seededSale = await (db.select(
      db.sales,
    )..where((s) => s.receiptNo.equals(receiptNo))).getSingle();
    expect(
      check.request['ExternalCheckNumber'],
      'sale-${seededSale.time}-$receiptNo-$posId',
      reason:
          'ключ идемпотентности собран продуктом (buildSaleIdempotencyKey), '
          'и именно по нему эмулятор узнает повтор; эпоха в нём — время '
          'чека, чтобы уборка старых продаж не вернула занятый ключ',
    );
    expect(check.outcome, 'ok');

    // `_persistReceipt` обязан оставить строку — иначе повтор и сверка потом
    // не на чем строятся.
    final receipts = await db.select(db.webkassaReceipts).get();
    expect(
      receipts,
      hasLength(1),
      reason: 'FiscalServiceImpl._persistReceipt не записал чек',
    );
    expect(receipts.single.fiscalNo, result.fiscalSign);
  });

  test('касса фискализует продажу СО СКИДКОЙ — оператор сводит суммы', () async {
    // Задача 6. До неё скидка не доезжала до оператора никогда, а уценённая
    // цена единицы разводила сумму позиций с суммой оплат: три штуки по 100
    // со скидкой 100 давали `3 × 66.67 = 200.01` против оплаты 200.00, и
    // пересчёт эмулятора отказывал кодом 9 — «деньги взяты, документа нет».
    //
    // Строки кладутся ровно так, как их оставляет касса после скидки
    // (`LocalCartService._writeLine`: `price = priceBefore − скидка /
    // количество` с масштабом 10), а не «примерно так».
    final db = GetIt.I<AppDatabase>();
    await db
        .into(db.productInfos)
        .insert(
          ProductInfosCompanion(
            ucode: const drift.Value(90003),
            barcode: const drift.Value(4870000000003),
            name: const drift.Value('Emulated cheese'),
            type: const drift.Value(0),
            measure: const drift.Value(0),
            quantity: drift.Value(Decimal.fromInt(100)),
            categoryId: const drift.Value(1),
            isDeleted: const drift.Value(false),
          ),
        );

    const receiptNo = 4244;
    const posId = 1;
    // Сама продажа — **строкой в базе**, а не только её товарами.
    //
    // Без неё состояние невозможно в бою: номер чека выдаёт
    // `ReceiptNumbers.withNext`, вставляя строку `Sales` в той же
    // транзакции, и товары без продажи не появляются никогда. Проба жила
    // без неё, пока ключ фискального документа не читал базу; с 2026-09-19
    // ключ несёт время чека (`sale-<time>-<номер>-<касса>`), и продажа без
    // строки честно отказывает «ключ собрать не из чего».
    await db
        .into(db.sales)
        .insert(
          SalesCompanion.insert(
            receiptNo: receiptNo,
            posId: posId,
            userId: 1,
            amount: Decimal.parse('501.00'),
            time: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            state: const drift.Value(1),
          ),
        );
    await db
        .into(db.saleProducts)
        .insert(
          SaleProductsCompanion(
            receiptNo: const drift.Value(receiptNo),
            posId: const drift.Value(posId),
            ucode: const drift.Value(90003),
            barcode: const drift.Value(4870000000003),
            categoryId: const drift.Value(1),
            quantity: drift.Value(Decimal.fromInt(3)),
            price: drift.Value(Decimal.parse('66.6666666667')),
            priceBefore: drift.Value(Decimal.fromInt(100)),
          ),
        );

    final fiscal = GetIt.I<FiscalService>();
    final result = await fiscal.fiscalizeSale(
      saleReceiptNo: receiptNo,
      salePosId: posId,
      amount: Decimal.parse('200.00'),
      cashAmount: Decimal.parse('200.00'),
      cardAmount: Decimal.zero,
      mobileAmount: Decimal.zero,
      bonusAmount: Decimal.zero,
      offsetAmount: Decimal.zero,
      offsetLayout: OffsetFiscalLayout.discount,
      excludeCertificatePositions: false,
    );

    final journal = inProcess ? state.journal : await _externalJournal(baseUrl);
    // ignore: avoid_print
    print(
      '\n--- Журнал эмулятора, продажа со скидкой '
      '(${inProcess ? 'в процессе' : 'внешний: $baseUrl'}) ---',
    );
    for (final entry in journal) {
      // ignore: avoid_print
      print(entry.line);
    }

    expect(
      result.success,
      isTrue,
      reason:
          'оператор отказал: ${result.errorCode.name} ${result.errorMessage}',
    );
    expect(result.hasFiscalSign, isTrue);

    final check = journal.firstWhere((e) => e.path == '/api/v4/check');
    final position =
        (check.request['Positions'] as List).cast<Map<String, Object?>>().single;
    expect(
      position['Price'],
      100,
      reason: 'в конверт уезжает цена ДО скидки, а не уценённая 66.67',
    );
    expect(position['Discount'], 100);
    expect(position['Count'], 3);
    expect(
      check.outcome,
      'ok',
      reason: 'пересчёт с нулевым допуском обязан свести 3 × 100 − 100 = 200',
    );
  });

  test('касса фискализует продажу С ПОДАРКОМ АКЦИИ — и без него не может', () async {
    // Задача 9. Подарок акции в базе не хранится вовсе: акция — чистая
    // функция от строк и таблицы `Promotions`, и в цену её впечатывала
    // запись формата завершённого чека. Запись эта была мертва
    // (`SaleCheckoutService.finalize` звал только
    // `SaleNotifier.completeSale`, у которого вызывающих ноль), и в
    // `SaleProducts.price` оставалась цена БЕЗ подарка.
    //
    // Для оператора это не «строка чуть неточна»: позиции считались на
    // 400, оплат приходило 200 — расхождение 200 при нулевом допуске.
    // Проход показывает обе стороны на одном стенде.
    final db = GetIt.I<AppDatabase>();
    await db
        .into(db.productInfos)
        .insert(
          ProductInfosCompanion(
            ucode: const drift.Value(90005),
            barcode: const drift.Value(4870000000005),
            name: const drift.Value('Emulated promo tea'),
            type: const drift.Value(0),
            measure: const drift.Value(0),
            quantity: drift.Value(Decimal.fromInt(100)),
            categoryId: const drift.Value(1),
            isDeleted: const drift.Value(false),
          ),
        );

    const posId = 1;

    // Строка чека **вместе с самим чеком**: товаров без продажи в базе не
    // бывает — номер выдаёт `ReceiptNumbers.withNext`, вставляя `Sales` в
    // той же транзакции. Раньше помощник обходился без продажи, потому что
    // ключ фискального документа базы не читал.
    Future<void> seedLine(int receiptNo, Decimal price) async {
      await db
          .into(db.sales)
          .insert(
            SalesCompanion.insert(
              receiptNo: receiptNo,
              posId: posId,
              userId: 1,
              amount: Decimal.parse('200.00'),
              time: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              state: const drift.Value(1),
            ),
          );
      await db
        .into(db.saleProducts)
        .insert(
          SaleProductsCompanion(
            receiptNo: drift.Value(receiptNo),
            posId: const drift.Value(posId),
            ucode: const drift.Value(90005),
            barcode: const drift.Value(4870000000005),
            categoryId: const drift.Value(1),
            quantity: drift.Value(Decimal.fromInt(4)),
            price: drift.Value(price),
            priceBefore: drift.Value(Decimal.fromInt(100)),
          ),
        );
    }

    final fiscal = GetIt.I<FiscalService>();

    // Как строка выглядела ДО задачи 9: подарок в цену не впечатан.
    const staleReceiptNo = 4246;
    await seedLine(staleReceiptNo, Decimal.fromInt(100));
    final stale = await fiscal.fiscalizeSale(
      saleReceiptNo: staleReceiptNo,
      salePosId: posId,
      amount: Decimal.parse('200.00'),
      cashAmount: Decimal.parse('200.00'),
      cardAmount: Decimal.zero,
      mobileAmount: Decimal.zero,
      bonusAmount: Decimal.zero,
      offsetAmount: Decimal.zero,
      offsetLayout: OffsetFiscalLayout.discount,
      excludeCertificatePositions: false,
    );
    expect(
      stale.success,
      isFalse,
      reason:
          'чек с неучтённым подарком обязан быть остановлен: позиции 400 '
          'против оплат 200',
    );
    expect(
      stale.errorMessage,
      contains('не сводится'),
      reason:
          'останавливает его сторож конверта на кассе (I168) — до отправки '
          'оператору, поэтому в журнале эмулятора этой попытки нет вовсе',
    );

    // Как строку оставляет касса ПОСЛЕ задачи 9: две подарочные единицы
    // из четырёх, цена единицы 200/4 = 50 ровно.
    const receiptNo = 4247;
    await seedLine(receiptNo, Decimal.fromInt(50));
    final result = await fiscal.fiscalizeSale(
      saleReceiptNo: receiptNo,
      salePosId: posId,
      amount: Decimal.parse('200.00'),
      cashAmount: Decimal.parse('200.00'),
      cardAmount: Decimal.zero,
      mobileAmount: Decimal.zero,
      bonusAmount: Decimal.zero,
      offsetAmount: Decimal.zero,
      offsetLayout: OffsetFiscalLayout.discount,
      excludeCertificatePositions: false,
    );

    final journal = inProcess ? state.journal : await _externalJournal(baseUrl);
    // ignore: avoid_print
    print(
      '\n--- Журнал эмулятора, продажа с подарком акции '
      '(${inProcess ? 'в процессе' : 'внешний: $baseUrl'}) ---',
    );
    for (final entry in journal) {
      // ignore: avoid_print
      print(entry.line);
    }

    expect(
      result.success,
      isTrue,
      reason:
          'оператор отказал: ${result.errorCode.name} ${result.errorMessage}',
    );
    expect(result.hasFiscalSign, isTrue);

    final check = journal.lastWhere((e) => e.path == '/api/v4/check');
    final position = (check.request['Positions'] as List)
        .cast<Map<String, Object?>>()
        .single;
    expect(
      position['Price'],
      100,
      reason: 'в конверт уезжает прейскурантная цена, а не 50',
    );
    expect(
      position['Count'],
      4,
      reason: 'покупатель уносит четыре штуки, две из них подарочные',
    );
    expect(
      position['Discount'],
      200,
      reason: 'подарок обязан уехать скидкой позиции',
    );
    expect(
      check.outcome,
      'ok',
      reason: 'пересчёт с нулевым допуском обязан свести 4 × 100 − 200 = 200',
    );
  });

  test('касса фискализует продажу С БОНУСОМ — оператор сводит суммы', () async {
    // Задача 7. До неё списанный бонус не попадал в конверт **ни одним
    // числом**: он уходил с бонусного счёта покупателя, раскладка
    // `LocalPaymentService._fiscalize` относила к наличным только
    // `AccountType.pos` и к карте только `customBank`, а позиции строились
    // на полную сумму. Чек 300 с бонусом 100 уезжал как «позиций на 300,
    // оплат на 200», и пересчёт с нулевым допуском отвечал кодом 9 —
    // «деньги взяты, документа нет» на **каждой** продаже с бонусом.
    //
    // Здесь бонус входит слагаемым в поле `Discount` позиции, и потому
    // цена в конверте остаётся ценой ДО скидки. Оба утверждения проверены
    // порознь: свести суммы можно и уценив цену — тогда оператор увидел бы
    // чек дешевле прейскуранта без объяснения.
    final db = GetIt.I<AppDatabase>();
    await db
        .into(db.productInfos)
        .insert(
          ProductInfosCompanion(
            ucode: const drift.Value(90004),
            barcode: const drift.Value(4870000000004),
            name: const drift.Value('Emulated coffee'),
            type: const drift.Value(0),
            measure: const drift.Value(0),
            quantity: drift.Value(Decimal.fromInt(100)),
            categoryId: const drift.Value(1),
            isDeleted: const drift.Value(false),
          ),
        );

    const receiptNo = 4245;
    const posId = 1;
    // Сама продажа — **строкой в базе**, а не только её товарами.
    //
    // Без неё состояние невозможно в бою: номер чека выдаёт
    // `ReceiptNumbers.withNext`, вставляя строку `Sales` в той же
    // транзакции, и товары без продажи не появляются никогда. Проба жила
    // без неё, пока ключ фискального документа не читал базу; с 2026-09-19
    // ключ несёт время чека (`sale-<time>-<номер>-<касса>`), и продажа без
    // строки честно отказывает «ключ собрать не из чего».
    await db
        .into(db.sales)
        .insert(
          SalesCompanion.insert(
            receiptNo: receiptNo,
            posId: posId,
            userId: 1,
            amount: Decimal.parse('501.00'),
            time: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            state: const drift.Value(1),
          ),
        );
    await db
        .into(db.saleProducts)
        .insert(
          SaleProductsCompanion(
            receiptNo: const drift.Value(receiptNo),
            posId: const drift.Value(posId),
            ucode: const drift.Value(90004),
            barcode: const drift.Value(4870000000004),
            categoryId: const drift.Value(1),
            quantity: drift.Value(Decimal.fromInt(3)),
            // Ручной скидки нет: строка стоит полную цену, и всё
            // расхождение с оплатой создаёт **только** бонус.
            price: drift.Value(Decimal.fromInt(100)),
            priceBefore: drift.Value(Decimal.fromInt(100)),
          ),
        );

    final fiscal = GetIt.I<FiscalService>();
    final result = await fiscal.fiscalizeSale(
      saleReceiptNo: receiptNo,
      salePosId: posId,
      amount: Decimal.parse('300.00'),
      cashAmount: Decimal.parse('200.00'),
      cardAmount: Decimal.zero,
      mobileAmount: Decimal.zero,
      bonusAmount: Decimal.parse('100.00'),
      offsetAmount: Decimal.zero,
      offsetLayout: OffsetFiscalLayout.discount,
      excludeCertificatePositions: false,
    );

    final journal = inProcess ? state.journal : await _externalJournal(baseUrl);
    // ignore: avoid_print
    print(
      '\n--- Журнал эмулятора, продажа с бонусом '
      '(${inProcess ? 'в процессе' : 'внешний: $baseUrl'}) ---',
    );
    for (final entry in journal) {
      // ignore: avoid_print
      print(entry.line);
    }

    expect(
      result.success,
      isTrue,
      reason:
          'оператор отказал: ${result.errorCode.name} ${result.errorMessage}',
    );
    expect(result.hasFiscalSign, isTrue);

    final check = journal.firstWhere((e) => e.path == '/api/v4/check');
    final position =
        (check.request['Positions'] as List).cast<Map<String, Object?>>().single;
    expect(
      position['Price'],
      100,
      reason: 'бонус не имеет права уценить позицию — он скидка, не цена',
    );
    expect(position['Count'], 3);
    expect(
      position['Discount'],
      100,
      reason: 'бонус стал слагаемым скидки позиции',
    );

    final payments = (check.request['Payments'] as List)
        .cast<Map<String, Object?>>();
    expect(
      payments.map((p) => p['Sum']).toList(),
      [200],
      reason:
          'бонус не платёж: в оплатах ровно 300 − 100, и второй строки нет',
    );
    expect(
      check.outcome,
      'ok',
      reason: 'пересчёт с нулевым допуском обязан свести 3 × 100 − 100 = 200',
    );
  });

  test(
    'повтор той же продажи: эмулятор узнаёт ключ, касса называет беду',
    () async {
      final db = GetIt.I<AppDatabase>();
      await db
          .into(db.productInfos)
          .insert(
            ProductInfosCompanion(
              ucode: const drift.Value(90002),
              barcode: const drift.Value(4870000000002),
              name: const drift.Value('Emulated milk'),
              type: const drift.Value(0),
              measure: const drift.Value(0),
              quantity: drift.Value(Decimal.fromInt(100)),
              categoryId: const drift.Value(1),
              isDeleted: const drift.Value(false),
            ),
          );
      const receiptNo = 4243;
      const posId = 1;
      // Сама продажа — **строкой в базе**, а не только её товарами.
      //
      // Без неё состояние невозможно в бою: номер чека выдаёт
      // `ReceiptNumbers.withNext`, вставляя строку `Sales` в той же
      // транзакции, и товары без продажи не появляются никогда. Проба жила
      // без неё, пока ключ фискального документа не читал базу; с 2026-09-19
      // ключ несёт время чека (`sale-<time>-<номер>-<касса>`), и продажа без
      // строки честно отказывает «ключ собрать не из чего».
      await db
          .into(db.sales)
          .insert(
            SalesCompanion.insert(
              receiptNo: receiptNo,
              posId: posId,
              userId: 1,
              amount: Decimal.parse('501.00'),
              time: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              state: const drift.Value(1),
            ),
          );
      await db
          .into(db.saleProducts)
          .insert(
            SaleProductsCompanion(
              receiptNo: const drift.Value(receiptNo),
              posId: const drift.Value(posId),
              ucode: const drift.Value(90002),
              barcode: const drift.Value(4870000000002),
              categoryId: const drift.Value(1),
              quantity: drift.Value(Decimal.fromInt(1)),
              price: drift.Value(Decimal.fromInt(500)),
              priceBefore: drift.Value(Decimal.fromInt(500)),
            ),
          );

      final fiscal = GetIt.I<FiscalService>();
      Future<FiscalResult> send() => fiscal.fiscalizeSale(
        saleReceiptNo: receiptNo,
        salePosId: posId,
        amount: Decimal.fromInt(500),
        cashAmount: Decimal.fromInt(500),
        cardAmount: Decimal.zero,
        mobileAmount: Decimal.zero,
        bonusAmount: Decimal.zero,
        offsetAmount: Decimal.zero,
        offsetLayout: OffsetFiscalLayout.discount,
        excludeCertificatePositions: false,
      );

      final first = await send();
      final second = await send();

      final journal = inProcess
          ? state.journal
          : await _externalJournal(baseUrl);

      // ignore: avoid_print
      print('\n--- Журнал эмулятора, повтор ---');
      for (final entry in journal) {
        // ignore: avoid_print
        print(entry.line);
      }

      expect(first.success, isTrue);
      expect(first.hasFiscalSign, isTrue);

      expect(
        journal.any((e) => e.outcome == 'refused:14'),
        isTrue,
        reason: 'эмулятор обязан узнать повтор по ExternalCheckNumber',
      );

      // НАХОДКА №1 закрыта 2026-09-18, и здесь измерено на настоящей кассе,
      // а не на подделке: повтор ключа — **беда с именем**, а не успех.
      //
      // Было: `second.success == true`, `hasFiscalSign == false`. Кассир
      // читал «фискализовано», чек печатался без фискального признака, а
      // следа не оставалось вовсе — `_persistReceipt` выходит по
      // `!result.hasFiscalSign`. Признак исходного документа дозапросить
      // нечем: ни один из девяти путей `/api/v4/*` не отдаёт документ по
      // `ExternalCheckNumber` (разбор — в докстринге
      // `WebKassaProvider._checkResult`).
      expect(
        second.success,
        isFalse,
        reason: 'повтор ключа — не успех: документ у оператора, признака нет',
      );
      expect(
        second.errorCode,
        FiscalErrorCode.duplicate,
        reason: 'код 14 обязан доехать до кассира названной причиной',
      );
      expect(
        second.rawErrorCode,
        14,
        reason: 'код оператора едет рядом: на экране он и объясняет причину',
      );
      expect(
        second.hasFiscalSign,
        isFalse,
        reason: 'признак не выдуман: оператор его на код 14 не отдаёт',
      );
      expect(
        FiscalFailureReason.fromResult(second).encode(),
        'fiscal(duplicate#14)',
        reason:
            'ровно эта строка ляжет в lastError и станет фразой словаря '
            'fiscalReasonDuplicate на экране нефискализованных чеков',
      );

      // Первая отправка свой признак получила и записала; повтор второй
      // строки не добавил — и не должен: документ у оператора **один**.
      final receipts = await db.select(db.webkassaReceipts).get();
      expect(
        receipts,
        hasLength(1),
        reason: 'на один документ оператора — одна строка WebkassaReceipts',
      );
      expect(
        receipts.single.fiscalNo,
        first.fiscalSign,
        reason: 'записан признак первой отправки, а не пустая строка повтора',
      );
    },
  );
}

/// Сбросить состояние внешнего эмулятора через его пульт.
Future<void> _resetExternal(String baseUrl) async {
  final client = HttpClient();
  try {
    final req = await client.postUrl(Uri.parse('$baseUrl/_emul/reset'));
    req.headers.contentType = ContentType.json;
    req.write('{}');
    final resp = await req.close();
    await resp.drain<void>();
  } finally {
    client.close(force: true);
  }
}

/// Журнал внешнего эмулятора — через пульт, а не через память процесса.
Future<List<JournalEntry>> _externalJournal(String baseUrl) async {
  final client = HttpClient();
  try {
    final req = await client.getUrl(Uri.parse('$baseUrl/_emul/journal'));
    final resp = await req.close();
    final body = await utf8.decoder.bind(resp).join();
    final decoded = jsonDecode(body) as Map<String, dynamic>;
    return [
      for (final raw in decoded['journal'] as List)
        JournalEntry(
          seq: (raw['seq'] as num).toInt(),
          at: DateTime.parse(raw['at'] as String),
          path: raw['path'] as String,
          request: (raw['request'] as Map).cast<String, Object?>(),
          response: (raw['response'] as Map).cast<String, Object?>(),
          reasons: (raw['reasons'] as List).map((e) => e.toString()).toList(),
          outcome: raw['outcome'] as String,
        ),
    ];
  } finally {
    client.close(force: true);
  }
}
