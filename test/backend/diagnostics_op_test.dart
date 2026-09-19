/// Диагностика оборудования с планшета — пункт «Достижимость с браузерного
/// терминала» плана `2026-09-19-hardware-diagnostics.md`.
///
/// # Что здесь соединено торцами
///
/// Обе половины провода на настоящем графе: база drift, настоящая
/// `LocalHardwareDiagnostics` над настоящей очередью печати и настоящим
/// разборщиком ESC/POS, настоящие `TillOperations`, `TillWire` со **сторожем
/// прав** — и настоящий `WtHardwareDiagnostics` поверх настоящего
/// `WtDispatcher`. Подставлены очередь печати (заданиями, а не поведением),
/// очередь фискализации и ширина ленты; QUIC подставлен один — нативной
/// библиотеки под `flutter test` нет.
///
/// # Четыре утверждения, каждое — про измеренную беду
///
/// 1. **чек, приехавший на планшет, — разбор ТЕХ ЖЕ байтов.** Свойство, ради
///    которого работа устроена так, а не иначе: разбор делает касса своим
///    единственным на дерево разборщиком, и в браузерной половине раскладки
///    чека нет ни строки. Прошлый раз две раскладки разошлись, и предпросмотр
///    показывал не то, что выходило из принтера (докстринг
///    `escpos_text_preview.dart`). Проба сверяет строку с
///    [renderEscPosAsText] тех же байтов **и** требует, чтобы в ней было
///    содержимое чека: без второй половины сверка была бы сверкой двух пустых
///    строк;
/// 2. **планшет не может спросить про чужое рабочее место.** У операции
///    пустое тело, и чьи задания показывать, решает касса по себе
///    (`TerminalRepository.self`). Проба ловит **номер, с которым касса
///    пришла в очередь**: он обязан быть номером кассы, а не планшета,
///    который только что зарегистрировался по проводу. Иначе право
///    `settings.hardware` открывало бы чужие чеки (И29);
/// 3. **право обязательно, и проверяет его сторож, а не обработчик.** Кадр
///    идёт через настоящий `wireGuardForTill` с тем же словарём доступа,
///    каким его собирает `ApiServer`. Сеанс без `settings.hardware` получает
///    `forbidden` **обеими** операциями; с правом — обе отвечают. Без второй
///    половины проба была бы зелена на кассе, которая отказывает всем;
/// 4. **касса без диагностики отказывает названной причиной, а не пустым
///    списком.** Пустой список читается как «касса ничего не отправляла», и
///    наладчик пошёл бы искать беду в принтере, которого никто не спрашивал.
@Tags(['architecture'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

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
import 'package:telepos/data/database/app_database.dart' hide FiscalQueueEntry;
import 'package:telepos/data/device/device_profile_catalog_builtin.dart';
import 'package:telepos/data/diagnostics/local_hardware_diagnostics.dart';
import 'package:telepos/data/auth/local_auth_repository.dart';
import 'package:telepos/data/fiscal/offline_queueing_provider.dart';
import 'package:telepos/data/terminal/device_binding_repository_local.dart';
import 'package:telepos/data/terminal/terminal_repository_local.dart';
import 'package:telepos/data/transport/till_wire.dart';
import 'package:telepos/domain/diagnostics/hardware_diagnostics.dart';
import 'package:telepos/domain/entities/receipt/receipt_options.dart';
import 'package:telepos/domain/print/print_job.dart';
import 'package:telepos/domain/print/print_queue.dart';
import 'package:telepos/domain/services/receipt_print_service.dart';
import 'package:telepos/domain/wire/till_ops.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';
import 'package:telepos/hardware/cash_drawer/cash_drawer_journal.dart';
import 'package:telepos/hardware/display/customer_display_journal.dart';
import 'package:telepos/hardware/printer/escpos_text_preview.dart';
import 'package:telepos/hardware/scales/scales_service.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/web/wt_channel.dart';
import 'package:telepos/web/wt_dispatcher.dart';
import 'package:telepos/web/wt_hardware_diagnostics.dart';

import '../web/support/fake_dispatcher.dart';
import '../web/support/loopback.dart';
import 'support/bare_till_deps.dart';

/// Кусок настоящего потока ESC/POS: сброс, кодовая страница, выравнивание,
/// строки, рез. Байтами, а не строкой: по проводу обязан ехать разбор именно
/// потока, а не заранее приготовленный текст.
Uint8List _receiptBytes() {
  final bytes = <int>[
    0x1B, 0x40, // ESC @ — сброс
    0x1B, 0x74, 17, // ESC t 17 — CP866
    0x1B, 0x61, 1, // ESC a 1 — по центру
  ];
  bytes.addAll('MAGAZIN\n'.codeUnits);
  bytes.addAll([0x1B, 0x61, 0]); // по левому краю
  bytes.addAll('MOLOKO        500.00\n'.codeUnits);
  bytes.addAll([0x1D, 0x56, 1]); // GS V 1 — рез
  return Uint8List.fromList(bytes);
}

PrintJob _job(Uint8List payload, {int terminalId = 1}) => PrintJob(
  id: 't$terminalId/p1/s1/sale/7001/c1',
  terminalId: terminalId,
  posId: 1,
  payloadBytes: payload,
  createdAt: DateTime(2026, 9, 19, 10),
  expiresAt: DateTime(2026, 9, 19, 10, 30),
  state: PrintJobState.printed,
);

void main() {
  late AppDatabase db;
  late Loopback loop;
  late TillWire wire;
  late _RecordingQueue queue;
  late int tillTerminalId;

  /// Реестр сеансов поднятой кассы — нужен пробе прав, чтобы завести
  /// **второй** сеанс на том же проводе, а не поднимать кассу заново.
  late SessionRegistry sessions;

  /// Поднять обе половины провода с сеансом, несущим [permissions].
  ///
  /// [withDiagnostics] `false` — касса без порта диагностики: голый процесс
  /// `bin/telepos_backend.dart` стоит именно так.
  Future<WtHardwareDiagnostics> boot(
    Set<String> permissions, {
    bool withDiagnostics = true,
    FiscalQueueStore? fiscalQueue,
    CashDrawerJournal? drawerJournal,
    CustomerDisplayJournal? displayJournal,
    ScalesService? scalesService,
    // Окно прореживания кадров весов. Короткое нарочно: длина окна — не
    // предмет пробы, предмет — то, что прореживание вообще есть и что
    // последний кадр не теряется.
    Duration scalesFrameInterval = const Duration(milliseconds: 200),
  }) async {
    sessions = SessionRegistry();
    final invites = PairingInvites();
    final terminals = LocalTerminalRepository(db);
    final operations = TillOperations(
      db: db,
      bootstrap: BareBootstrap(),
      setup: BareSetup(),
      terminals: terminals,
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
      diagnostics: withDiagnostics
          ? LocalHardwareDiagnostics(
              terminals: terminals,
              queue: queue,
              printer: _FixedWidthPrinter(ReceiptPaperWidth.mm80),
              db: db,
              fiscalQueue: fiscalQueue,
              drawerJournal: drawerJournal,
              displayJournal: displayJournal,
              scales: scalesService,
              scalesFrameInterval: scalesFrameInterval,
            )
          : null,
    );
    final session = sessions.mint(
      userId: 4,
      name: 'Наладчик',
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
      // Тот же сторож и тот же словарь доступа, что у настоящей кассы:
      // `ApiServer.access` — это буквально то же выражение.
      guard: wireGuardForTill(
        db: db,
        access: {for (final op in TillOps.all) op.name: op.access},
        sessions: sessions,
      ),
    )..start();
    final browser = WtDispatcher(loop, tokens: FakeTokens(session.token));
    await browser.ask<TerminalRegisterRequest, TerminalEnrollment>(
      TillOps.terminalRegister,
      (name: 'Планшет', code: invites.mint().code),
    );
    return WtHardwareDiagnostics(browser);
  }

  /// Ещё один планшет на **той же** поднятой кассе, с другими правами.
  ///
  /// Вторая касса здесь была бы подменой предмета: проба про право обязана
  /// мерить один и тот же провод с одним и тем же сторожем, иначе «отказал» и
  /// «ответил» приходили бы из двух разных сборок.
  WtHardwareDiagnostics as(Set<String> permissions) {
    final session = sessions.mint(
      userId: 4,
      name: 'Наладчик',
      role: 'admin',
      permissions: permissions,
      operatingMode: 0,
      pointMode: 'cashier',
      shiftOpen: true,
      terminalId: 1,
    );
    return WtHardwareDiagnostics(
      WtDispatcher(loop, tokens: FakeTokens(session.token)),
    );
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    loop = Loopback();
    queue = _RecordingQueue();
    await db
        .into(db.thisPosEntries)
        .insert(
          const ThisPosEntriesCompanion(
            id: Value(1),
            cashBoxName: Value('Касса-1'),
          ),
        );
    await db
        .into(db.users)
        .insert(const UsersCompanion(id: Value(4), name: Value('Наладчик')));
    // Рабочее место самой кассы — то, про которое она и обязана отвечать.
    tillTerminalId = (await db.terminalDao.ensureSelf(
      fallbackName: 'Касса-1',
    )).id;
  });

  tearDown(() async {
    await wire.stop();
    await loop.dispose();
    await db.close();
  });

  const engineer = {PermissionKeys.settingsHardware};

  test('чек на планшете — разбор ТЕХ ЖЕ байтов, что ушли в порт', () async {
    final payload = _receiptBytes();
    queue.jobs = [_job(payload, terminalId: tillTerminalId)];

    final diagnostics = await boot(engineer);
    final view = await diagnostics.watchPrinter().first;

    expect(view.available, isTrue);
    expect(view.jobs, hasLength(1));

    // То, что **касса разобрала бы у себя** для тех же байтов: тот самый
    // единственный на дерево разборщик.
    final onTill = renderEscPosAsText(payload, width: 48);

    // ── текст НЕПУСТ И НЕСЁТ ЧЕК ───────────────────────────────────────
    //
    // Без этой половины сверка ниже была бы сверкой двух пустых строк — то
    // есть кассы, которая не разобрала ничего.
    expect(
      onTill,
      contains('MOLOKO'),
      reason: 'предпосылка: разборщик что-то разобрал',
    );
    expect(
      view.jobs.single.text,
      onTill,
      reason:
          'на планшете обязан быть разбор ровно тех байтов задания, а не '
          'вторая раскладка: иначе диагностика отвечает на вопрос «что мы '
          'отправили» тем, чего мы не отправляли',
    );
    expect(view.jobs.single.state, PrintJobState.printed);
    expect(view.jobs.single.id, 't$tillTerminalId/p1/s1/sale/7001/c1');
  });

  test(
    'планшет спрашивает про КАССУ, а не про себя: номер рабочего места '
    'выбирает касса',
    () async {
      queue.jobs = [_job(_receiptBytes(), terminalId: tillTerminalId)];

      final diagnostics = await boot(engineer);
      await diagnostics.watchPrinter().first;

      // Планшет зарегистрировался по проводу и получил СВОЙ номер рабочего
      // места — не номер кассы. Если бы операция возила его телом, очередь
      // спросили бы про него, и наладчик увидел бы пустоту вместо чеков
      // кассы; а в другую сторону — чужие чеки соседнего рабочего места (И29).
      expect(
        queue.askedFor,
        [tillTerminalId],
        reason:
            'касса обязана отвечать про СВОЁ рабочее место, а не про то, '
            'которое назвал планшет: у операции пустое тело именно поэтому',
      );
    },
  );

  test('тело запроса к оператору едет как есть, с отступами', () async {
    final diagnostics = await boot(
      engineer,
      fiscalQueue: _StubFiscalQueue(
        pending: [
          FiscalQueueEntry(
            idempotencyKey: 'sale-1789757442-7002-1',
            opType: FiscalQueueOp.sale,
            payload: const {
              'sale': {'receiptNo': 7002},
            },
            occurredAt: DateTime(2026, 9, 19, 11),
          ),
        ],
      ),
    );

    final view = await diagnostics.fiscal();

    expect(view.configured, isTrue);
    expect(view.queued, hasLength(1));
    final queued = view.queued.single;
    expect(queued.idempotencyKey, 'sale-1789757442-7002-1');
    expect(queued.opType, 'sale');
    expect(queued.failed, isFalse);
    // Как есть — и это сверяют с тем, что ждёт оператор. Приглаженный вид
    // врёт ровно там, где его читают.
    expect(
      queued.payloadJson,
      const JsonEncoder.withIndent('  ').convert(const {
        'sale': {'receiptNo': 7002},
      }),
      reason:
          'тело обязано приехать тем же текстом, каким его показывает касса: '
          'второй форматировщик во вкладке разошёлся бы с первым',
    );
  });

  test('принятый оператором документ доезжает с признаком', () async {
    await db
        .into(db.webkassaReceipts)
        .insert(
          WebkassaReceiptsCompanion.insert(
            operationId: 1,
            fiscalNo: const Value('ФП-4210'),
            wkReceiptNo: const Value('WK-1'),
            receiptNo: const Value(7001),
          ),
        );

    final diagnostics = await boot(
      engineer,
      fiscalQueue: _StubFiscalQueue(),
    );
    final view = await diagnostics.fiscal();

    expect(view.accepted, hasLength(1));
    expect(view.accepted.single.fiscalNo, 'ФП-4210');
    expect(view.accepted.single.operatorReceiptNo, 'WK-1');
    // Строкой, а не числом: номер документа, а не величина.
    expect(view.accepted.single.receiptNo, '7001');
    expect(view.accepted.single.offline, isFalse);
  });

  test(
    'без settings.hardware обе операции отказывает СТОРОЖ, а не обработчик',
    () async {
      queue.jobs = [_job(_receiptBytes(), terminalId: tillTerminalId)];

      // Сеанс есть, право — любое другое. Именно этим отличается «нет
      // сеанса» от «сеанс без права»: коды разные, и кассир обязан видеть
      // второй, а не первый.
      final barred = await boot(
        {PermissionKeys.navSale},
        fiscalQueue: _StubFiscalQueue(),
      );

      expect(
        () => barred.fiscal(),
        throwsA(
          isA<WireRefusal>().having((e) => e.code, 'code', 'forbidden'),
        ),
        reason:
            'скрытая кнопка правом не является (И162): отказ обязан прийти '
            'значением с провода',
      );
      expect(
        barred.watchPrinter().first,
        throwsA(
          isA<WtProtocolError>().having((e) => e.code, 'code', 'forbidden'),
        ),
        reason: 'подписка охраняется тем же сторожем, что и вопрос',
      );

      // ── ОБРАТНЫЙ ПОЛЮС ──────────────────────────────────────────────
      //
      // Тот же провод, тот же сторож, тот же обработчик — другой сеанс. Без
      // этой половины проба была бы зелена на кассе, которая отказывает
      // ВСЕМ: то есть доказывала бы не право, а сломанный провод.
      final allowed = as(engineer);
      expect((await allowed.fiscal()).configured, isTrue);
      expect((await allowed.watchPrinter().first).jobs, hasLength(1));
    },
  );

  test(
    'три подписки пункта 4 охраняет ТОТ ЖЕ сторож: ящик, дисплей, весы',
    () async {
      // Отдельной пробой, а не строками в соседней: право у новых операций
      // легко объявить и легко **забыть**, и забытое выглядит работающим —
      // вкладка на планшете открывается и показывает данные. Здесь три
      // подписки проверяются обоими полюсами: сеанс без права и сеанс с
      // правом на одном и том же проводе.
      final barred = await boot(
        {PermissionKeys.navSale},
        drawerJournal: CashDrawerJournal(),
        displayJournal: CustomerDisplayJournal(),
        scalesService: _FakeScales(),
      );

      for (final stream in [
        barred.watchDrawer(),
        barred.watchDisplay(),
        barred.watchScales(),
      ]) {
        expect(
          stream.first,
          throwsA(
            isA<WtProtocolError>().having((e) => e.code, 'code', 'forbidden'),
          ),
          reason:
              'скрытая вкладка правом не является (И162): отказ обязан '
              'прийти значением с провода',
        );
      }

      // ── ОБРАТНЫЙ ПОЛЮС ────────────────────────────────────────────────
      final allowed = as(engineer);
      expect((await allowed.watchDrawer().first).available, isTrue);
      expect((await allowed.watchDisplay().first).available, isTrue);
      expect((await allowed.watchScales().first).bound, isTrue);
    },
  );

  test('импульс ящика доезжает с путём, причиной и честным словом', () async {
    final journal = CashDrawerJournal();
    journal.record(
      CashDrawerKick(
        at: DateTime(2026, 9, 19, 12, 31),
        path: CashDrawerPath.serialPort,
        accepted: false,
        note: 'Не удалось открыть порт COM9: Access denied',
      ),
    );

    final diagnostics = await boot(engineer, drawerJournal: journal);
    final view = await diagnostics.watchDrawer().first;

    expect(view.available, isTrue);
    expect(view.kicks, hasLength(1));
    final kick = view.kicks.single;
    // Путь едет **именем значения**, а не словом по-русски: слово, зашитое
    // кассой, казахский наладчик прочитал бы по-русски, и сторож равенства
    // словарей такого не ловит.
    expect(kick.path, DrawerKickPath.serialPort);
    expect(
      kick.accepted,
      isFalse,
      reason:
          'граница знания кассы обязана пережить провод: «принята» — это не '
          '«ящик открылся», и поле называется так на обеих сторонах',
    );
    expect(
      kick.note,
      'Не удалось открыть порт COM9: Access denied',
      reason:
          'дословная причина — то, ради чего журнал и заведён; общее слово '
          '«ошибка» не разбирает ни одну жалобу',
    );
    expect(kick.at, DateTime(2026, 9, 19, 12, 31));
  });

  test(
    'ящик — ПОДПИСКА: импульс, случившийся после открытия вкладки, доезжает',
    () async {
      // Это и есть довод рода операции, проверенный, а не объявленный.
      // Наладчик держит вкладку открытой и жмёт «Открыть ящик» на кассе;
      // вопрос вернул бы снимок, верный в миг постройки экрана, и импульс не
      // появился бы на планшете вовсе.
      //
      // Проба ловит именно **второй** кадр: первый приходит из уже
      // записанного и был бы зелен и у вопроса.
      final journal = CashDrawerJournal();
      final diagnostics = await boot(engineer, drawerJournal: journal);

      final frames = <DrawerDiagnosticsView>[];
      final subscription = diagnostics.watchDrawer().listen(frames.add);
      await pumpEventQueue();
      expect(frames.single.kicks, isEmpty, reason: 'предпосылка: пусто');

      journal.record(
        CashDrawerKick(
          at: DateTime(2026, 9, 19, 12, 40),
          path: CashDrawerPath.viaPrinter,
          accepted: true,
        ),
      );
      await pumpEventQueue();

      expect(
        frames, hasLength(2),
        reason:
            'вкладка обязана узнать об импульсе в момент импульса, а не при '
            'следующем вопросе — иначе подписка здесь не нужна вовсе',
      );
      expect(frames.last.kicks.single.path, DrawerKickPath.viaPrinter);
      expect(frames.last.kicks.single.accepted, isTrue);

      await subscription.cancel();
      await journal.dispose();
    },
  );

  test('что на стекле СЕЙЧАС считает касса, а не планшет', () async {
    // Правило «текущая — последняя принятая» живёт одно, в
    // `CustomerDisplayJournal.current`. Проба ставит поверх принятой строки
    // **отказанную**: вкладка, считающая текущей просто последнюю, показала
    // бы строку, которой на стекле нет.
    final journal = CustomerDisplayJournal();
    journal.record(
      CustomerDisplayLine(
        at: DateTime(2026, 9, 19, 13),
        kind: CustomerDisplayCall.total,
        text: '1250.00',
      ),
    );
    journal.record(
      CustomerDisplayLine(
        at: DateTime(2026, 9, 19, 13, 1),
        kind: CustomerDisplayCall.text,
        text: 'СПАСИБО',
        refusal: 'Порт COM5 закрыт',
      ),
    );

    final diagnostics = await boot(engineer, displayJournal: journal);
    final view = await diagnostics.watchDisplay().first;

    expect(view.available, isTrue);
    expect(view.lines, hasLength(2));
    expect(
      view.current?.text,
      '1250.00',
      reason:
          'текущая — последняя ПРИНЯТАЯ: отказанная строка на стекло не '
          'попала, и показывать её как текущую значит показывать то, чего '
          'там нет',
    );
    expect(
      view.current?.kind,
      DisplayCallKind.total,
      reason: 'подпись вызова едет именем значения, а не словом',
    );
    // Сумма — **той записью, что ушла в порт**: журнал пишет
    // `toStringAsFixed(2)`, как `BaseDisplayManager.formatAmount`. Второй
    // формат на планшете дал бы «1250» там, где на стекле «1250.00».
    expect(view.lines.last.text, '1250.00');
    expect(view.lines.first.refusal, 'Порт COM5 закрыт');

    await journal.dispose();
  });

  test('весы: вес едет ГОТОВОЙ строкой с тремя знаками', () async {
    // Три знака — разрешение прибора. `Decimal` печатает 1.250 как «1.25»,
    // и вкладка, форматирующая сама, теряла бы граммы молча. Проба берёт
    // ровно такой вес: у него последний знак нулевой.
    final scales = _FakeScales(connected: true);
    // Окно нулевое: предмет этой пробы — содержимое кадра, а не его срок.
    // С настоящим окном показание легло бы в досылку, и проба мерила бы
    // таймер.
    final diagnostics = await boot(
      engineer,
      scalesService: scales,
      scalesFrameInterval: Duration.zero,
    );

    final frames = <ScalesDiagnosticsView>[];
    final subscription = diagnostics.watchScales().listen(frames.add);
    await pumpEventQueue();

    scales.push(
      ScalesReading(
        weight: Decimal.parse('1.250'),
        status: ScalesStatus.stable,
      ),
    );
    await pumpEventQueue();

    final reading = frames.last.reading;
    expect(
      reading?.weight,
      '1.250',
      reason:
          'вес обязан приехать готовым: «1.25» на планшете — это потерянный '
          'грамм, и потерян он был бы молча',
    );
    expect(reading?.unit, 'kg');
    expect(reading?.status, ScalesReadingStatus.stable);
    expect(frames.last.port, 'COM7');
    expect(frames.last.baudRate, 4800);
    expect(frames.last.protocol, 'cas');
    expect(frames.last.connected, isTrue);

    await subscription.cancel();
  });

  test('весы: зашкал сильнее «устойчиво», и разбирает это касса', () async {
    // Перегруженные весы умеют присылать `stable` — и слово «стабильно» на
    // зашкале прямая неправда. Порядок ветвей разбирает касса; проба берёт
    // ровно то сочетание, на котором ошибётся наивный разбор.
    final scales = _FakeScales();
    final diagnostics = await boot(
      engineer,
      scalesService: scales,
      scalesFrameInterval: Duration.zero,
    );

    final frames = <ScalesDiagnosticsView>[];
    final subscription = diagnostics.watchScales().listen(frames.add);
    await pumpEventQueue();

    scales.push(
      ScalesReading(
        weight: Decimal.zero,
        status: ScalesStatus.overload,
      ),
    );
    await pumpEventQueue();

    expect(frames.last.reading?.status, ScalesReadingStatus.overload);

    await subscription.cancel();
  });

  test(
    'весы: кадры ПРОРЕЖЕНЫ, и последний не теряется',
    () async {
      // Главное утверждение пункта 4 про весы. `ScalesService` опрашивает
      // порт каждые 200 мс, и кадр на каждое показание был бы потоком ради
      // вкладки, которую смотрят минуту.
      //
      // Проба вбрасывает шесть РАЗНЫХ показаний одним всплеском — то есть
      // быстрее любого окна — и требует двух вещей сразу:
      //
      // 1. кадров стало меньше, чем показаний. Иначе прореживания нет;
      // 2. **последний вес доехал**. Это не придирка: взвешивание кончается
      //    тем, что вес устанавливается и прибор замолкает, и отброшенный
      //    хвост означал бы вкладку, показывающую предпоследний вес и
      //    называющую его устоявшимся.
      final scales = _FakeScales();
      final diagnostics = await boot(
        engineer,
        scalesService: scales,
        scalesFrameInterval: const Duration(milliseconds: 200),
      );

      final frames = <ScalesDiagnosticsView>[];
      final subscription = diagnostics.watchScales().listen(frames.add);
      await pumpEventQueue();

      for (final grams in [100, 200, 300, 400, 500, 617]) {
        scales.push(
          ScalesReading(
            weight: Decimal.parse('0.$grams'),
            status: grams == 617 ? ScalesStatus.stable : ScalesStatus.unstable,
          ),
        );
      }
      await pumpEventQueue();

      final duringWindow = frames.length;
      expect(
        duringWindow,
        lessThan(6),
        reason:
            'шесть показаний одним всплеском обязаны стать меньше чем шестью '
            'кадрами: иначе прореживания нет и вкладка стоит потока',
      );

      // Ждём закрытия окна — именно здесь уходит досылка.
      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(
        frames.last.reading?.weight,
        '0.617',
        reason:
            'последнее показание — это УСТАНОВИВШИЙСЯ вес, число, по '
            'которому продают товар; прореживание, теряющее его, врёт именно '
            'в той цифре, за которой пришли',
      );
      expect(frames.last.reading?.status, ScalesReadingStatus.stable);
      expect(
        frames.length,
        lessThan(7),
        reason: 'досылка одна, а не по кадру на каждое пропущенное показание',
      );

      await subscription.cancel();
    },
  );

  test('весы: неподвижный груз не стоит ни одного лишнего кадра', () async {
    // Второе правило прореживания, и выигрыш у него больше первого: весы с
    // неподвижным грузом шлют одно и то же значение по нескольку раз в
    // секунду **бесконечно**. Без снятия повторов простаивающая вкладка
    // стоила бы столько же, сколько работающая.
    final scales = _FakeScales();
    final diagnostics = await boot(engineer, scalesService: scales);

    final frames = <ScalesDiagnosticsView>[];
    final subscription = diagnostics.watchScales().listen(frames.add);
    await pumpEventQueue();
    final before = frames.length;

    for (var i = 0; i < 10; i++) {
      scales.push(
        ScalesReading(
          weight: Decimal.parse('0.500'),
          status: ScalesStatus.stable,
        ),
      );
      await pumpEventQueue();
    }
    // Хватило бы и без ожидания, но окно закрывается таймером: ждём, чтобы
    // досылка, если бы она была, успела уйти и была засчитана.
    await Future<void>.delayed(const Duration(milliseconds: 400));

    expect(
      frames.length - before,
      1,
      reason:
          'десять одинаковых показаний — это ОДИН кадр: первый. Повтор, '
          'доехавший до планшета, ничего не меняет на экране и стоит '
          'ровно столько же, сколько новый',
    );

    await subscription.cancel();
  });

  test('весов нет — сказано значением, а не пустым показанием', () async {
    // Пустое показание при привязанных весах неотличимо от весов с
    // оборванным проводом: пустота отвечает «ничего нет» на два
    // противоположных вопроса.
    final diagnostics = await boot(engineer);
    final view = await diagnostics.watchScales().first;

    expect(view.bound, isFalse);
    expect(view.reading, isNull);

    // Та же развилка у ящика и дисплея: памяти нет — названо, а не пусто.
    expect((await diagnostics.watchDrawer().first).available, isFalse);
    expect((await diagnostics.watchDisplay().first).available, isFalse);
  });

  test(
    'касса без диагностики отказывает названной причиной и трём подпискам',
    () async {
      final diagnostics = await boot(engineer, withDiagnostics: false);

      for (final stream in [
        diagnostics.watchDrawer(),
        diagnostics.watchDisplay(),
        diagnostics.watchScales(),
      ]) {
        expect(
          stream.first,
          throwsA(
            isA<WtProtocolError>().having(
              (e) => e.code,
              'code',
              diagnosticsUnavailableCode,
            ),
          ),
          reason:
              'пустой кадр читался бы как «ящик не звали» и «весы молчат», и '
              'наладчик пошёл бы искать обрыв в исправной проводке',
        );
      }
    },
  );

  test(
    'касса без диагностики отказывает названной причиной, а не пустым списком',
    () async {
      final diagnostics = await boot(engineer, withDiagnostics: false);

      expect(
        () => diagnostics.fiscal(),
        throwsA(
          isA<WireRefusal>().having(
            (e) => e.code,
            'code',
            diagnosticsUnavailableCode,
          ),
        ),
        reason:
            'пустой список читался бы как «касса ничего не отправляла», и '
            'наладчик пошёл бы искать беду в принтере, которого никто не '
            'спрашивал',
      );
      expect(
        diagnostics.watchPrinter().first,
        throwsA(
          isA<WtProtocolError>().having(
            (e) => e.code,
            'code',
            diagnosticsUnavailableCode,
          ),
        ),
      );
    },
  );
}

/// Очередь печати, запоминающая, **про какое рабочее место её спросили**.
///
/// Это и есть узел пробы 2: поведения у очереди здесь нет, есть память о
/// доводе. Подставить её честнее, чем настоящую: настоящая сама фильтрует по
/// номеру, и проба, читающая только результат, не отличила бы «спросили про
/// кассу» от «спросили про планшет, а заданий планшета нет».
class _RecordingQueue implements PrintQueue {
  List<PrintJob> jobs = const [];
  final List<int?> askedFor = [];

  @override
  Stream<List<PrintJob>> watch({int? terminalId}) {
    askedFor.add(terminalId);
    return Stream.value(jobs);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'проба диагностики: ${invocation.memberName} у очереди не поднят',
  );
}

class _FixedWidthPrinter implements ReceiptPrintService {
  _FixedWidthPrinter(this._width);

  final ReceiptPaperWidth _width;

  @override
  Future<ReceiptPaperWidth> currentPaperWidth() async => _width;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'проба диагностики: ${invocation.memberName} у печати не поднят',
  );
}

/// Весы, у которых показания задаёт проба.
///
/// **Наследник настоящей службы**, а не подделка её договора: у
/// `ScalesService` нет интерфейса, и подставлять здесь свой класс значило бы
/// проверять провод над выдуманным прибором. Переопределены ровно три вещи —
/// поток, последнее показание и признак открытого порта; порт, скорость и
/// говор берутся у настоящего конструктора, потому что именно их вкладка и
/// показывает.
///
/// `setManualWeight` для этого не годится: он помечает показание `isManual`
/// и всегда объявляет его устойчивым, то есть зашкал и «вес едет» им не
/// задать вовсе.
class _FakeScales extends ScalesService {
  _FakeScales({bool connected = false})
    : _connected = connected,
      super(port: 'COM7', baudRate: 4800, protocol: ScalesProtocol.cas);

  final bool _connected;
  final _controller = StreamController<ScalesReading>.broadcast();
  ScalesReading? _last;

  void push(ScalesReading reading) {
    _last = reading;
    _controller.add(reading);
  }

  @override
  Stream<ScalesReading> get weightStream => _controller.stream;

  @override
  ScalesReading? get lastReading => _last;

  @override
  bool get isConnected => _connected;
}

class _StubFiscalQueue implements FiscalQueueStore {
  _StubFiscalQueue({
    List<FiscalQueueEntry> pending = const [],
    List<FiscalQueueEntry> failed = const [],
  }) : pendingEntries = pending,
       failedEntries = failed;

  final List<FiscalQueueEntry> pendingEntries;
  final List<FiscalQueueEntry> failedEntries;

  @override
  Future<List<FiscalQueueEntry>> pending() async => pendingEntries;

  @override
  Future<List<FiscalQueueEntry>> failed() async => failedEntries;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'проба диагностики: ${invocation.memberName} у очереди не поднят',
  );
}
