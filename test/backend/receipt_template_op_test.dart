/// Шаблон чека из браузера — решение заказчика 2026-09-18.
///
/// # Что здесь соединено торцами
///
/// Обе половины провода на настоящем графе: база drift, настоящая
/// `LocalReceiptTemplateSetup` над настоящей `ReceiptPrintServiceImpl`,
/// настоящая `LocalPaymentService` (порт снимается с неё), настоящие
/// `TillOperations`, `TillWire` со **сторожем прав** — и настоящий
/// `WtReceiptTemplateSetup` поверх настоящего `WtDispatcher`. Подставлен один
/// QUIC (нативной библиотеки под `flutter test` нет).
///
/// # Главное утверждение — **предпросмотр во вкладке есть бумага**
///
/// Свойство, ради которого эта работа вообще устроена так, а не иначе
/// (докстринг `lib/domain/receipt/receipt_template_setup.dart`): текст чека
/// на экране рождается **в одном месте на всё дерево** —
/// `ReceiptPrintService.renderSalePreviewText`, которая собирает настоящий
/// поток ESC/POS тем же кодом, каким печатает, и разбирает его обратно.
///
/// Прошлый раз это стоило круга правок: предпросмотр рисовал вторую,
/// независимую копию раскладки, копии разошлись, и на экране показывалось не
/// то, что выходило из принтера (докстринг `escpos_text_preview.dart`).
/// Браузерная половина обязана число раскладок **не увеличить**.
///
/// Проба обязана краснеть в обе стороны, поэтому у утверждения две половины:
///
/// 1. **текст, приехавший во вкладку, совпадает посимвольно** с тем, что
///    `renderSalePreviewText` отдаёт на кассе для того же черновика;
/// 2. **этот текст не пустой и несёт именно черновик** — строки шапки,
///    которой в сохранённом шаблоне нет. Без второй половины первая была бы
///    зелена на двух пустых строках, то есть на кассе, которая ничего не
///    собрала вовсе.
///
/// Цепочка смыкается торцами с соседней пробой:
/// `test/unit/hardware/receipt_template_wire_test.dart`, «предпросмотр
/// шаблона — те же строки, что вышли на бумагу», сличает **тот же вызов** с
/// бумагой настоящего эмулятора через настоящий сокет. Вкладка = касса =
/// бумага.
@Tags(['architecture'])
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker/talker.dart';
import 'package:telepos/backend/login_throttle.dart';
import 'package:telepos/backend/pairing_invites.dart';
import 'package:telepos/backend/session_registry.dart';
import 'package:telepos/backend/till_operations.dart';
import 'package:telepos/backend/till_wire_guard.dart';
import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/data/auth/local_auth_repository.dart';
import 'package:telepos/data/database/app_database.dart' hide Terminal;
import 'package:telepos/data/device/device_profile_catalog_builtin.dart';
import 'package:telepos/data/sale/local_cart_service.dart';
import 'package:telepos/data/sale/local_payment_service.dart';
import 'package:telepos/data/sale/local_sale_checkout_service.dart';
import 'package:telepos/data/services/receipt_print_service_impl.dart';
import 'package:telepos/data/terminal/device_binding_repository_local.dart';
import 'package:telepos/data/terminal/terminal_repository_local.dart';
import 'package:telepos/data/transport/till_wire.dart';
import 'package:telepos/data/usecases/product/find_by_barcode_use_case_impl.dart';
import 'package:telepos/data/usecases/product/search_product_info_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/deferred_sale_service_impl.dart';
import 'package:telepos/data/usecases/sale/sale_initiation_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/sale_round_option_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/sale_use_case_impl.dart';
import 'package:telepos/domain/entities/receipt/receipt_options.dart';
import 'package:telepos/domain/fiscal/refusing_fiscal_service.dart';
import 'package:telepos/domain/print/receipt_paper_width_source.dart';
import 'package:telepos/domain/receipt/receipt_template_sample.dart';
import 'package:telepos/domain/services/receipt_print_service.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/domain/wire/till_ops.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';
import 'package:telepos/web/wt_dispatcher.dart';
import 'package:telepos/web/wt_receipt_template_setup.dart';

import '../helpers/cash_drawer.dart';
import '../web/support/fake_dispatcher.dart';
import '../web/support/loopback.dart';
import 'support/bare_till_deps.dart';

void main() {
  late AppDatabase db;
  late Loopback loop;
  late TillWire wire;
  late ReceiptPrintService printer;

  /// Поднять обе половины провода с сеансом, несущим [permissions].
  ///
  /// [withPrinter] `false` — касса без очереди печати, то есть и без шаблона:
  /// голый процесс `bin/telepos_backend.dart` стоит именно так, и отвечать
  /// ему «сохранено» было бы худшим из возможного.
  Future<WtReceiptTemplateSetup> boot(
    Set<String> permissions, {
    bool withPrinter = true,
  }) async {
    final sessions = SessionRegistry();
    final logger = Talker();
    final invites = PairingInvites();
    final cart = LocalCartService(
      db: db,
      logger: logger,
      initiation: SaleInitiationUseCaseImpl(db: db, logger: logger),
      deferred: DeferredSaleServiceImpl(db: db, logger: logger),
      rounding: SaleRoundOptionUseCaseImpl(),
      findByBarcode: FindByBarcodeUseCaseImpl(db: db, logger: logger),
      searchProducts: SearchProductInfoUseCaseImpl(db: db, logger: logger),
    );
    // Ширина ленты — **фиксированная 80 мм**, а не привязка устройства: под
    // `flutter test` привязки принтера нет, а мерить надо не поиск ширины, а
    // совпадение двух текстов на одной и той же ширине. 80, а не 58, потому
    // что на широкой ленте перенос по словам виден сильнее — расхождение
    // раскладок в прошлый раз и было переносом.
    printer = ReceiptPrintServiceImpl(
      paperWidth: const FixedReceiptPaperWidth(ReceiptPaperWidth.mm80),
    );
    final operations = TillOperations(
      db: db,
      bootstrap: BareBootstrap(),
      setup: BareSetup(),
      terminals: LocalTerminalRepository(db),
      deviceBindings: LocalDeviceBindingRepository(
        db,
        BuiltinDeviceProfileCatalog(),
      ),
      auth: LocalAuthRepository(
        db: db,
        sessions: sessions,
        throttle: LoginThrottle(),
      ),
      invites: invites,
      // Настоящая раскладка оплаты — и **та же служба печати**, которой она
      // печатала бы чек. В этом весь смысл того, что порт снимается с
      // оплаты, а не приходит отдельным доводом: собрать кассу, у которой
      // шаблон правит одна служба печати, а печатает другая, здесь нечем —
      // и правка тогда не сбрасывала бы кэш той, что печатает.
      payments: LocalPaymentService(
        db: db,
        checkout: LocalSaleCheckoutService(db: db, cart: cart, logger: logger),
        sale: SaleUseCaseImpl(db: db, logger: logger),
        logger: logger,
        fiscal: const RefusingFiscalService(),
        printer: withPrinter ? printer : null,
        drawer: drawerOpens,
      ),
    );
    final session = sessions.mint(
      userId: 4,
      name: 'Владелец',
      role: 'admin',
      permissions: permissions,
      operatingMode: 0,
      pointMode: 'cashier',
      shiftOpen: true,
      terminalId: 1,
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
    final browser = WtDispatcher(loop, tokens: FakeTokens(session.token));
    await browser.ask<TerminalRegisterRequest, TerminalEnrollment>(
      TillOps.terminalRegister,
      (name: 'Вкладка', code: invites.mint().code),
    );
    return WtReceiptTemplateSetup(browser);
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    loop = Loopback();
    await db
        .into(db.thisPosEntries)
        .insert(
          const ThisPosEntriesCompanion(
            id: Value(1),
            companyName: Value('ТОО Ромашка'),
            cashBoxName: Value('Касса-1'),
            iinbin: Value('987654321098'),
          ),
        );
    await db
        .into(db.users)
        .insert(const UsersCompanion(id: Value(4), name: Value('Владелец')));
  });

  tearDown(() async {
    await wire.stop();
    await loop.dispose();
    await db.close();
  });

  const owner = {PermissionKeys.settingsPrinter};

  /// Черновик с приметной шапкой и подвалом — **не сохранённый**.
  ///
  /// Шапка нарочно длиннее строки на 80 колонках и по центру, подвал — слева:
  /// расхождение раскладок в прошлый раз было именно в переносе и отступе, и
  /// черновик, у которого обе стороны выравнивания одинаковы, его не поймал
  /// бы вовсе.
  ReceiptOptions draft() => const ReceiptOptions().copyWith(
    header: const ReceiptTextBlock(
      text: 'Спасибо, что выбрали нашу лавку на углу Абая и Достык',
      align: ReceiptTextAlign.center,
    ),
    footer: const ReceiptTextBlock(
      text: 'Возврат в течение 14 дней\nТелефон 8-800-000-00-00',
      align: ReceiptTextAlign.left,
    ),
  );

  test(
    'предпросмотр с браузера — тот же текст, что касса собирает из байтов',
    () async {
      final setup = await boot(owner);
      final options = draft();

      final fromBrowser = await setup.preview(options.encode());

      // То, что **касса покажет у себя** для того же черновика: тот самый
      // единственный на дерево вызов, который собирает настоящие байты
      // ESC/POS и разбирает их обратно.
      final onTill = printer.renderSalePreviewText(
        sampleSaleReceiptData(
          storeName: 'ТОО Ромашка',
          posName: 'Касса-1',
          binIin: '987654321098',
        ),
        options,
        paperWidth: ReceiptPaperWidth.mm80,
      );

      // ── текст НЕПУСТ И НЕСЁТ ЧЕРНОВИК ──────────────────────────────────
      //
      // Без этой половины сравнение ниже было бы зелено на двух пустых
      // строках — то есть на кассе, которая не собрала ничего.
      expect(
        fromBrowser,
        contains('Спасибо, что выбрали нашу лавку'),
        reason:
            'в предпросмотре нет шапки черновика — касса собрала не тот '
            'шаблон или не собрала ничего',
      );
      expect(fromBrowser, contains('Телефон 8-800-000-00-00'));
      expect(
        fromBrowser.split('\n').length,
        greaterThan(10),
        reason: 'чек короче десяти строк — собран не чек',
      );

      // Черновик **не сохранён**: предпросмотр обязан показывать то, что
      // набрано, а не то, что лежит в базе. Иначе владелец правил бы подвал
      // и видел прежний.
      final saved = await db.receiptTemplateDao.getSelectedOptions();
      expect(
        saved.header.text,
        isEmpty,
        reason: 'предпросмотр не имеет права сохранять черновик',
      );

      // ── ВКЛАДКА = КАССА ────────────────────────────────────────────────
      //
      // Время в чеке — единственное, что законно расходится между двумя
      // сборками образца (`sampleSaleReceiptData` ставит `DateTime.now()`).
      // Снимается ровно одна строка, а не «похожие» — иначе снятие маскировало
      // бы расхождение.
      List<String> withoutClock(String text) => text
          .split('\n')
          .where((l) => !RegExp(r'^\s*\d{2}\.\d{2}\.\d{4}').hasMatch(l))
          .toList();

      expect(
        withoutClock(fromBrowser),
        withoutClock(onTill),
        reason:
            'предпросмотр во вкладке разошёлся с тем, что касса собирает из '
            'байтов, — то есть в браузере завелась вторая раскладка чека, '
            'ровно та беда, ради которой раскладку свели к одной',
      );
    },
  );

  test('правка с браузера доезжает до базы кассы и до печати', () async {
    final setup = await boot(owner);
    final before = await setup.read();
    expect(before.paperWidthMm, 80, reason: 'ширину называет касса');
    expect(before.templates, hasLength(1), reason: 'встроенный шаблон засеян');
    expect(before.templates.single.builtIn, isTrue);
    expect(before.templates.single.selected, isTrue);

    final id = before.templates.single.id;
    await setup.save(
      id: id,
      name: 'Наш чек',
      optionsJson: draft().encode(),
    );

    // ── в базе кассы ────────────────────────────────────────────────────
    final row = await db.receiptTemplateDao.getById(id);
    expect(row!.name, 'Наш чек');
    expect(
      ReceiptOptions.decode(row.optionsJson).header.text,
      startsWith('Спасибо, что выбрали'),
    );
    // Признак «встроенный» правкой не трогается: единственным способом его
    // поменять была бы эта поездка, и потому поля в кадре нет вовсе.
    expect(row.isDefault, isTrue);

    // ── и до печати ─────────────────────────────────────────────────────
    //
    // Не «строка в базе изменилась», а «касса будет печатать новым»:
    // `ReceiptPrintServiceImpl` кэширует шаблон внутри себя, и правка без
    // сброса кэша печаталась бы старым текстом до перезапуска кассы. Читаем
    // через **тот же экземпляр службы**, который отдан раскладке оплаты.
    final printed = printer.renderSalePreviewText(
      sampleSaleReceiptData(storeName: 'ТОО Ромашка', posName: 'Касса-1'),
      await db.receiptTemplateDao.getSelectedOptions(),
      paperWidth: ReceiptPaperWidth.mm80,
    );
    expect(printed, contains('Спасибо, что выбрали нашу лавку'));

    final after = await setup.read();
    expect(after.templates.single.name, 'Наш чек');
  });

  test('безымянный шаблон касса не берёт — и не пишет ничего', () async {
    final setup = await boot(owner);
    final id = (await setup.read()).templates.single.id;

    await expectLater(
      setup.save(id: id, name: '   ', optionsJson: draft().encode()),
      throwsA(
        isA<WireRefusal>().having(
          (e) => e.code,
          'code',
          'receipt_template_nameless',
        ),
      ),
    );

    // Отказ **до записи**, а не после: строка осталась прежней целиком.
    final row = await db.receiptTemplateDao.getById(id);
    expect(row!.name, isNot('   '));
    expect(ReceiptOptions.decode(row.optionsJson).header.text, isEmpty);
  });

  test('без права settings.printer не открывается ни один из шести', () async {
    // Пустой набор прав, а не чужое право: проверяется, что сторож требует
    // именно этот ключ, а не что он пропускает всех.
    final setup = await boot(const {});
    for (final call in <Future<void> Function()>[
      () => setup.read(),
      () => setup.save(name: 'Х', optionsJson: '{}'),
      () => setup.select(1),
      () => setup.remove(1),
      () => setup.preview('{}'),
      () => setup.testPrint(),
    ]) {
      await expectLater(
        call(),
        throwsA(
          isA<WireRefusal>().having((e) => e.code, 'code', 'forbidden'),
        ),
        reason: 'операция шаблона открылась без права settings.printer',
      );
    }
  });

  test('касса без очереди печати отказывает названной причиной', () async {
    final setup = await boot(owner, withPrinter: false);
    await expectLater(
      setup.read(),
      throwsA(
        isA<WireRefusal>().having(
          (e) => e.code,
          'code',
          'receipt_templates_unavailable',
        ),
      ),
      reason:
          'ответить «сохранено» без записи — худшее из возможного: владелец '
          'ушёл бы с экрана, считая чек настроенным',
    );
  });
}
