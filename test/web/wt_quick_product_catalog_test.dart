/// Быстрые товары и правила сканера с браузерного терминала — задача 45,
/// **плюс запись правил** (пункт 11 ревизии 2026-09-19).
///
/// Терминал против **настоящей** кассы: те же кассовые реализации
/// (`LocalQuickProductCatalog`, `LocalScannerRulesRepository`) над базой в
/// памяти, настоящий сторож провода и настоящий сеанс. Сравнивается ответ
/// браузерной реализации с ответом кассовой напрямую — две реализации одного
/// договора, а не докстринги.
library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/backend/login_throttle.dart';
import 'package:telepos/backend/pairing_invites.dart';
import 'package:telepos/backend/session_registry.dart';
import 'package:telepos/backend/till_operations.dart';
import 'package:telepos/backend/till_wire_guard.dart';
import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/data/auth/local_auth_repository.dart';
import 'package:telepos/data/database/app_database.dart' hide Terminal;
import 'package:telepos/data/repositories/scanner_rules_repository_impl.dart';
import 'package:telepos/data/sale/local_quick_product_catalog.dart';
import 'package:telepos/data/terminal/terminal_repository_local.dart';
import 'package:telepos/data/transport/till_wire.dart';
import 'package:telepos/domain/repositories/scanner_rules_repository.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/domain/wire/till_ops.dart';
import 'package:telepos/domain/wire/wire_access.dart';
import 'package:telepos/domain/wire/wire_op.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';
import 'package:telepos/web/wt_channel.dart';
import 'package:telepos/web/wt_dispatcher.dart';
import 'package:telepos/web/wt_quick_product_catalog.dart';
import 'package:telepos/web/wt_scanner_rules.dart';

import '../data/transport/till_operations_stubs.dart';
import 'support/fake_dispatcher.dart';
import 'support/loopback.dart';

void main() {
  late AppDatabase db;
  late Loopback loop;
  late TillWire wire;
  late SessionRegistry sessions;
  late PairingInvites invites;
  late LocalQuickProductCatalog localCatalog;
  late LocalScannerRulesRepository localRules;

  Decimal d(String v) => Decimal.parse(v);

  Future<void> seedProduct(int ucode, String name, String price) async {
    await db
        .into(db.productInfos)
        .insert(
          ProductInfosCompanion.insert(
            ucode: Value(ucode),
            barcode: 4870000000000 + ucode,
            name: name,
            type: 0,
            measure: 0,
          ),
        );
    await db
        .into(db.productPrices)
        .insert(
          ProductPricesCompanion.insert(
            ucode: Value(ucode),
            barcode: 4870000000000 + ucode,
            sellingPrice: Value(d(price)),
          ),
        );
  }

  /// Браузер с сеансом [permissions], заведший своё рабочее место настоящим
  /// путём (`terminals.register` с одноразовым кодом).
  Future<WtDispatcher> browser(Set<String> permissions) async {
    final session = sessions.mint(
      userId: 4,
      name: 'Айгуль',
      role: 'cashier',
      permissions: permissions,
      operatingMode: 0,
      pointMode: 'cashier',
      shiftOpen: true,
      terminalId: 1,
    );
    final dispatcher = WtDispatcher(loop, tokens: FakeTokens(session.token));
    await dispatcher.ask<TerminalRegisterRequest, TerminalEnrollment>(
      TillOps.terminalRegister,
      (name: 'Вкладка', code: invites.mint().code),
    );
    return dispatcher;
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    loop = Loopback();
    await db
        .into(db.thisPosEntries)
        .insert(
          const ThisPosEntriesCompanion(
            id: Value(1),
            cashBoxName: Value('Касса-петля'),
          ),
        );
    await db
        .into(db.users)
        .insert(const UsersCompanion(id: Value(4), name: Value('Айгуль')));

    // Каталог, в котором есть что **не** показывать: удалённый товар и
    // категория с товаром, не лежащим в корне (`qa-depth`, правило нуля).
    await seedProduct(10, 'Сүт', '499.995');
    await seedProduct(20, 'Нан', '250');
    await seedProduct(30, 'Снятый', '1');
    await (db.update(db.productInfos)..where((p) => p.ucode.equals(30))).write(
      const ProductInfosCompanion(isDeleted: Value(true)),
    );
    await db.quickProductDao.createCategory(name: 'Сусындар');
    await db.quickProductDao.addQuickProduct(ucode: 10, orderName: 'Сүт');
    await db.quickProductDao.addQuickProduct(ucode: 30, orderName: 'Снятый');

    sessions = SessionRegistry();
    invites = PairingInvites();
    localCatalog = LocalQuickProductCatalog(db: db);
    localRules = LocalScannerRulesRepository(db);
    final operations = TillOperations(
      db: db,
      bootstrap: NoopBootstrap(),
      setup: NoopSetupRepository(),
      terminals: LocalTerminalRepository(db),
      invites: invites,
      deviceBindings: NoopDeviceBindingRepository(),
      auth: LocalAuthRepository(
        db: db,
        sessions: sessions,
        throttle: LoginThrottle(),
      ),
      quickProducts: localCatalog,
      scannerRules: localRules,
    );
    wire = TillWire(
      loop,
      operations.askHandlers,
      watchHandlers: operations.watchHandlers,
      runHandlers: operations.runHandlers,
      guard: wireGuardForTill(
        db: db,
        access: {for (final op in TillOps.all) op.name: op.access},
        sessions: sessions,
      ),
    )..start();
  });

  tearDown(() async {
    await wire.stop();
    await loop.dispose();
    await db.close();
  });

  group('быстрые товары', () {
    test('сетка терминала — та же, что сетка кассы', () async {
      final catalog = WtQuickProductCatalog(
        await browser({PermissionKeys.navSale}),
      );

      final categories = await catalog.categories();
      expect(categories, await localCatalog.categories());
      expect(categories.map((c) => c.name), ['Сусындар']);

      final root = await catalog.items();
      expect(root, await localCatalog.items());
      expect(
        root.map((i) => i.ucode),
        [10],
        reason: 'удалённый товар кнопкой не показывается и на терминале',
      );
      expect(
        root.single.price,
        d('499.995'),
        reason: 'цена доехала строкой без потери знака',
      );

      final drinks = categories.single.id;
      await db.quickProductDao.addQuickProduct(
        ucode: 20,
        parentId: drinks,
        orderName: 'Нан',
      );
      final inCategory = await catalog.items(categoryId: drinks);
      expect(inCategory, await localCatalog.items(categoryId: drinks));
      expect(inCategory.map((i) => i.ucode), [20]);
    });

    test('без права продажи — отказ кассы кодом, а не пустая сетка', () async {
      final catalog = WtQuickProductCatalog(await browser(const {}));

      await expectLater(
        catalog.categories(),
        throwsA(isA<WireRefusal>().having((r) => r.code, 'code', 'forbidden')),
      );
    });
  });

  group('правила сканера', () {
    test('терминал читает правила кассы, а не зашитые', () async {
      await localRules.save(
        ScannerRules(
          barcodeMinLength: 6,
          barcodeMaxLength: 9,
          scannerTimeoutMs: 75,
        ),
      );
      // Сеанс только возврата: правила нужны и экрану возврата.
      final rules = await WtScannerRules(
        await browser({PermissionKeys.navRefund}),
      ).read();

      expect(rules.effectiveBarcodeMinLength, 6);
      expect(rules.effectiveBarcodeMaxLength, 9);
      expect(rules.effectiveScannerTimeoutMs, 75);
      expect(
        rules.effectiveBarcodeMinLength,
        isNot(
          ScannerRules(
            barcodeMinLength: null,
            barcodeMaxLength: null,
            scannerTimeoutMs: null,
          ).effectiveBarcodeMinLength,
        ),
        reason: 'предпосылка: заданное отличимо от умолчания',
      );
    });
  });

  /// Запись правил сканера с планшета — пункт 11 ревизии 2026-09-19.
  ///
  /// # Почему пробы ходят по проводу, а не зовут обработчик
  ///
  /// Тем же доводом, что `sale_permissions_test.dart`: право, объявленное в
  /// каталоге, и право, **проверенное** у кассира, — разные утверждения, и
  /// между ними в этом проекте уже пропадало целое требование. Здесь кадр
  /// проходит настоящий `wireGuardForTill`, собранный тем же выражением
  /// `{for (final op in TillOps.all) op.name: op.access}`, каким его
  /// собирает `ApiServer`, а пишет — настоящая
  /// `LocalScannerRulesRepository` над настоящей базой.
  ///
  /// # Чего эти пробы НЕ доказывают
  ///
  /// Что кассир увидит поля на экране: за это отвечает регистрация
  /// `ScannerRulesRepository` в `main_web.dart`, и её сторожит
  /// `browser_routes_test.dart`. И не доказывают, что новые правила
  /// подхватит уже открытый экран продажи: `BarcodeScannerMixin` читает их
  /// при постройке, а не подпиской (докстринг `WtScannerRules`).
  group('запись правил сканера с планшета', () {
    /// Сырое тело под тем же именем операции — подделанная вкладка.
    ///
    /// Нужна потому, что `WtScannerRules.save` не даёт послать негодную
    /// тройку вовсе: её отвергает конструктор `ScannerRules` ещё во
    /// вкладке. Проверка **кассы** этим не доказывалась бы никак — вот
    /// кадр, который её минует.
    const rawSave = Ask<Map<String, Object?>, Map<String, Object?>>(
      'scanner.saveRules',
      access: SessionAccess(needs: PermissionKeys.settingsHardware),
      encode: _itself,
      decode: _itself,
    );

    test('кассир с settings.hardware задаёт правила кассы с планшета', () async {
      final repo = WtScannerRules(
        await browser({PermissionKeys.navSale, PermissionKeys.settingsHardware}),
      );

      expect(
        (await localRules.read()).barcodeMinLength,
        isNull,
        reason: 'предпосылка: до записи правил нет, и ноль отличим от шести',
      );

      await repo.save(
        ScannerRules(
          barcodeMinLength: 6,
          barcodeMaxLength: 9,
          scannerTimeoutMs: 75,
        ),
      );

      // Читается **касса**, а не ответ провода: ответ `{'ok': true}` можно
      // написать и ничего не записав — ровно та подмена, которую эта проба
      // обязана ловить.
      final onTill = await localRules.read();
      expect(onTill.barcodeMinLength, 6);
      expect(onTill.barcodeMaxLength, 9);
      expect(onTill.scannerTimeoutMs, 75);
    });

    test('снятое правило уезжает значением, а не пропущенным ключом', () async {
      // `null` значит «не задано, берётся умолчание» — состояние, которое
      // кассир обязан уметь вернуть. Пропущенный ключ кодек считает отказом
      // разбора нарочно, и если бы `save` слал только заполненные поля,
      // снять правило с планшета было бы нечем.
      await localRules.save(
        ScannerRules(
          barcodeMinLength: 6,
          barcodeMaxLength: 9,
          scannerTimeoutMs: 75,
        ),
      );
      final repo = WtScannerRules(
        await browser({PermissionKeys.settingsHardware}),
      );

      await repo.save(
        ScannerRules(
          barcodeMinLength: null,
          barcodeMaxLength: null,
          scannerTimeoutMs: null,
        ),
      );

      final onTill = await localRules.read();
      expect(onTill.barcodeMinLength, isNull);
      expect(onTill.barcodeMaxLength, isNull);
      expect(onTill.scannerTimeoutMs, isNull);
    });

    test('без settings.hardware — forbidden, и правила кассы не тронуты', () async {
      // Сеанс продажи: читать правила ему можно (`scanner.rules` открыта
      // любому сеансу), писать — нет. Два права у одной тройки чисел — это
      // решение, а не недосмотр: докстринг `TillOps.scannerRulesSave`.
      final repo = WtScannerRules(await browser({PermissionKeys.navSale}));

      await expectLater(
        repo.save(
          ScannerRules(
            barcodeMinLength: 2,
            barcodeMaxLength: 3,
            scannerTimeoutMs: 5,
          ),
        ),
        throwsA(isA<WireRefusal>().having((r) => r.code, 'code', 'forbidden')),
      );

      // Отказал сторож, а не хранилище: ненаписанное правило отличает
      // «право проверено ДО обработчика» от «обработчик сходил в базу и
      // передумал».
      expect((await localRules.read()).barcodeMinLength, isNull);
    });

    test('подделанная вкладка: min > max — bad_request, а не запись', () async {
      final wt = await browser({PermissionKeys.settingsHardware});

      await expectLater(
        wt.ask(rawSave, const {
          'barcodeMinLength': 30,
          'barcodeMaxLength': 4,
          'scannerTimeoutMs': 80,
        }),
        throwsA(
          isA<WtProtocolError>().having((r) => r.code, 'code', 'bad_request'),
        ),
      );

      expect(
        (await localRules.read()).barcodeMinLength,
        isNull,
        reason: 'разбор идёт до save — записать ничего не успели',
      );
    });

    test('подделанная вкладка: не число — bad_request, а не падение', () async {
      final wt = await browser({PermissionKeys.settingsHardware});

      await expectLater(
        wt.ask(rawSave, const {
          'barcodeMinLength': 'шесть',
          'barcodeMaxLength': 9,
          'scannerTimeoutMs': 75,
        }),
        throwsA(
          isA<WtProtocolError>().having((r) => r.code, 'code', 'bad_request'),
        ),
      );
    });

    test('подделанная вкладка: нет ключа — bad_request', () async {
      final wt = await browser({PermissionKeys.settingsHardware});

      await expectLater(
        wt.ask(rawSave, const {'barcodeMinLength': 6, 'barcodeMaxLength': 9}),
        throwsA(
          isA<WtProtocolError>().having((r) => r.code, 'code', 'bad_request'),
        ),
      );
    });
  });
}

/// Тело как есть — для сырых кадров подделанной вкладки.
Map<String, Object?> _itself(Map<String, Object?> body) => body;
