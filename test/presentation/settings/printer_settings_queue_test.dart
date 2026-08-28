import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/data/database/app_database.dart' hide Terminal;
import 'package:telepos/data/device/device_profile_catalog_builtin.dart';
import 'package:telepos/data/print/print_job_store_drift.dart';
import 'package:telepos/data/print/print_queue_local.dart';
import 'package:telepos/data/terminal/device_binding_repository_local.dart';
import 'package:telepos/domain/device/device_profile_catalog.dart';
import 'package:telepos/domain/print/print_job.dart';
import 'package:telepos/domain/print/print_job_store.dart';
import 'package:telepos/domain/print/print_queue.dart';
import 'package:telepos/domain/terminal/device_binding_repository.dart';
import 'package:telepos/domain/terminal/terminal.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/hardware/printer/printer_manager.dart' show PrintResult;
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/screens/settings/printer_settings_screen.dart';

import '../../e2e/support/harness.dart' show PrintQueueLifetime;

/// Only `self()` is exercised by this screen; every other member throws, so an
/// accidental new dependency fails loudly instead of returning a plausible
/// value.
class _FakeTerminalRepository implements TerminalRepository {
  _FakeTerminalRepository(this.terminalId);

  final int terminalId;

  @override
  Future<Terminal> self() async =>
      Terminal(id: terminalId, name: 'Касса-1', pointMode: PointMode.cashier);

  @override
  Future<List<Terminal>> list() => throw UnimplementedError();

  // Подписок этот экран не заводит: свой терминал он спрашивает один раз при
  // открытии. Бросают по той же причине, что и остальные члены — случайная
  // новая зависимость обязана падать громко, а не возвращать правдоподобное.
  @override
  Stream<List<Terminal>> watchAll() => throw UnimplementedError();

  @override
  Stream<Terminal?> watchSelf() => throw UnimplementedError();

  @override
  Future<TerminalEnrollment> register({
    required String name,
    String code = '',
  }) => throw UnimplementedError();

  @override
  Future<Terminal> resume({required int terminalId, required String secret}) =>
      throw UnimplementedError();

  @override
  Future<void> rename(int terminalId, String name) => throw UnimplementedError();

  @override
  Future<void> delete(int terminalId) => throw UnimplementedError();
}

/// Counts what actually reached the printer, and says so.
///
/// A retry that produces a second receipt is invisible in the job list — the
/// job would simply be `printed`, which it was going to be anyway. The only
/// thing that distinguishes "we did not print again" from "we printed again
/// and overwrote the row" is how many times the bytes left the queue, so that
/// is what is counted.
class _CountingTransport {
  final List<Uint8List> sent = <Uint8List>[];

  Future<PrintResult> call(Uint8List payloadBytes) async {
    sent.add(payloadBytes);
    return PrintResult.ok();
  }
}

/// Как эти проверки читаются: очередь наполняется через **настоящее**
/// хранилище над настоящей (в памяти) базой, экран поднимается целиком, и
/// каждая проверка спрашивает у экрана то, ради чего задача 7 существует, —
/// видно ли застрявшее задание, отличима ли нечитаемая очередь от пустой,
/// и не появляется ли второй чек от нажатия «повторить».
void main() {
  late AppDatabase db;
  late PrintJobStore store;
  late PrintQueueLocal queue;
  late _CountingTransport transport;

  /// **Все сроки строятся от этого момента, а не от красивой круглой даты.**
  /// Очередь меряет истечение срока настоящими часами (`PrintQueueLocal`
  /// берёт `DateTime.now` по умолчанию), поэтому задание с датой в 2027 году
  /// было бы для неё живым, а ручной повтор на два часа вперёд «сдвинул бы
  /// срок назад». Урок 3 плана: тест пользуется значениями, которые система
  /// способна произвести.
  late DateTime nowUtc;

  const ownTerminalId = 1;
  const otherTerminalId = 2;

  /// Строится с указанным моментом создания, а не «сейчас»: порядок в списке
  /// задаётся `createdAt`, и без разных моментов проверка сортировки не
  /// отличала бы «отсортировано» от «повезло».
  PrintJob job({
    required String id,
    required DateTime createdAt,
    required DateTime expiresAt,
    int terminalId = ownTerminalId,
    int posId = 7,
  }) => PrintJob(
    id: id,
    terminalId: terminalId,
    posId: posId,
    // Настоящее начало чека ESC/POS — байты, а не заглушка из одного нуля.
    payloadBytes: Uint8List.fromList(const [0x1b, 0x40, 0x0a, 0x1d, 0x56, 0x00]),
    createdAt: createdAt,
    expiresAt: expiresAt,
  );

  setUp(() async {
    nowUtc = DateTime.now().toUtc();
    db = AppDatabase(NativeDatabase.memory());
    await db.terminalDao.ensureSelf(fallbackName: 'Касса-1');
    store = DriftPrintJobStore(db);
    transport = _CountingTransport();
    queue = PrintQueueLocal(store: store, transport: transport.call);

    await GetIt.I.reset();
    GetIt.I.registerSingleton<DeviceProfileCatalog>(
      BuiltinDeviceProfileCatalog(),
    );
    GetIt.I.registerSingleton<DeviceBindingRepository>(
      LocalDeviceBindingRepository(db, BuiltinDeviceProfileCatalog()),
    );
    GetIt.I.registerSingleton<TerminalRepository>(
      _FakeTerminalRepository(ownTerminalId),
    );
    GetIt.I.registerSingleton<PrintQueue>(queue);
  });

  tearDown(() async {
    await queue.dispose();
    await GetIt.I.reset();
    await db.close();
  });

  /// `PrintQueueLifetime` — не украшение. `PrintQueueLocal` заводит таймер
  /// пробуждения, как только у неё появляется активное задание, а
  /// `flutter_test` проверяет незакрытые таймеры **внутри** тела теста, то есть
  /// до `tearDown`. Единственный крючок, который успевает, — `dispose()`
  /// виджета. Подробности — в доке `PrintQueueLifetime`.
  Widget host({String locale = 'ru'}) => PrintQueueLifetime(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: Locale(locale),
      home: const PrinterSettingsScreen(),
    ),
  );

  Finder inJob(String jobId, Finder matching) => find.descendant(
    of: find.byKey(Key('print_job_$jobId')),
    matching: matching,
  );

  /// Разбирает дерево **внутри тела теста** и даёт таймерам догореть.
  ///
  /// Двух источников таймеров здесь два, и оба гасятся только так. Первый —
  /// очередь: `PrintQueueLocal` заводит будильник, и его снимает `dispose()`
  /// виджета `PrintQueueLifetime`. Второй — сам drift: отписка от
  /// `watch()`-потока планирует нулевой `Timer`
  /// (`StreamQueryStore.markAsClosed`), а `flutter_test` проверяет
  /// незакрытые таймеры **до** `tearDown`, поэтому убрать дерево и прокрутить
  /// один кадр надо здесь, а не в `addTearDown` — измерено, из `addTearDown`
  /// уже поздно.
  ///
  /// **Кадр прокручивается с явным `Duration.zero`, и это не украшение.**
  /// `tester.pump()` без длительности фальшивое время не двигает вовсе
  /// (`AutomatedTestWidgetsFlutterBinding._pump` зовёт `elapse` только при
  /// непустой длительности), поэтому нулевой таймер drift оставался
  /// незакрытым: тест падал на «A Timer is still pending», а следом `db.close()`
  /// в `tearDown` ждал этот же таймер до срока самого теста — десять минут на
  /// каждую проверку. Измерено на этом файле.
  Future<void> closeScreen(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  /// Наполненный набор, а не одно задание: шесть заданий этой кассы во всех
  /// шести состояниях, с разными моментами создания (порядок), с причинами на
  /// русском и казахском (сравнение и вывод национальных символов), с датой
  /// на переходе года — **и одно задание чужой кассы**, которое обязано не
  /// попасть в список. Без последнего проверка не отличала бы «показал нужное»
  /// от «показал всё».
  Future<void> seedSixJobsPlusForeign() async {
    final base = nowUtc.subtract(const Duration(minutes: 30));
    final soon = nowUtc.add(const Duration(minutes: 30));

    // Граничные даты: это задание живёт через смену года — переход суток и
    // года проходит через формат срока на экране.
    await store.put(
      job(
        id: 'sale-1001',
        createdAt: DateTime.utc(2025, 12, 31, 23, 55),
        expiresAt: DateTime.utc(2026, 1, 1, 0, 30),
      ),
    );
    await store.put(
      job(
        id: 'sale-1002',
        createdAt: base.add(const Duration(minutes: 1)),
        expiresAt: soon,
      ).beginAttempt(),
    );
    await store.put(
      job(
        id: 'sale-1003',
        createdAt: base.add(const Duration(minutes: 2)),
        expiresAt: soon,
      ).failWith('Нет бумаги'),
    );
    // Истёкшее строится по правилам домена: сначала неудача с причиной, потом
    // истечение по часам — причина обязана пережить переход, иначе оператор
    // увидит «срок вышел» и ни слова о том, почему.
    final expiredAt = nowUtc.subtract(const Duration(minutes: 10));
    await store.put(
      job(
        id: 'sale-1004',
        createdAt: base.add(const Duration(minutes: 3)),
        expiresAt: expiredAt,
      ).failWith('Принтер не отвечает').expireAt(
        expiredAt.add(const Duration(seconds: 1)),
      ),
    );
    await store.put(
      job(
        id: 'sale-1005',
        createdAt: base.add(const Duration(minutes: 4)),
        expiresAt: soon,
      ).failWith('Қағаз жоқ — Дүкен №2').cancelled(),
    );
    await store.put(
      job(
        id: 'sale-1006',
        createdAt: base.add(const Duration(minutes: 5)),
        expiresAt: soon,
      ).confirmPrinted(),
    );

    // Чужая касса — не должна попасть в список этой.
    await store.put(
      job(
        id: 'sale-2001',
        createdAt: base.add(const Duration(minutes: 6)),
        expiresAt: soon,
        terminalId: otherTerminalId,
      ).failWith('Ысык-Көл кассасы'),
    );
  }

  testWidgets(
    'застрявшее задание видно с причиной, и причина у неудачного и у '
    'истёкшего разная — «нет бумаги» и «принтер не отвечает» ведут в разные '
    'места',
    (tester) async {
      await seedSixJobsPlusForeign();

      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('print_queue_list')),
        findsOneWidget,
        reason: 'очередь с шестью заданиями обязана быть списком',
      );

      // Неудачное: своё состояние и своя причина.
      expect(
        inJob('sale-1003', find.text('Не напечаталось, будет повторено')),
        findsOneWidget,
      );
      expect(
        inJob('sale-1003', find.text('Причина: Нет бумаги')),
        findsOneWidget,
        reason: 'без причины оператору некуда идти — это и есть весь смысл '
            'экрана',
      );

      // Истёкшее: другое состояние (оно само повторяться не будет) и другая
      // причина. Слить их в одно «не напечаталось» значило бы отправить
      // человека не туда.
      expect(
        inJob('sale-1004', find.text('Срок вышел, само повторяться не будет')),
        findsOneWidget,
      );
      expect(
        inJob('sale-1004', find.text('Причина: Принтер не отвечает')),
        findsOneWidget,
        reason: 'причина обязана пережить истечение срока',
      );

      // Остальные четыре состояния названы каждое по-своему.
      expect(inJob('sale-1001', find.text('Ждёт печати')), findsOneWidget);
      expect(inJob('sale-1002', find.text('Печатается')), findsOneWidget);
      expect(
        inJob('sale-1005', find.text('Отменено оператором')),
        findsOneWidget,
      );
      expect(inJob('sale-1006', find.text('Напечатано')), findsOneWidget);

      // Национальные символы доходят до экрана через SQLite неизменными.
      expect(
        inJob('sale-1005', find.text('Причина: Қағаз жоқ — Дүкен №2')),
        findsOneWidget,
      );

      // Задание чужой кассы в этот список не попадает — и его текста на экране
      // нет вовсе.
      expect(find.byKey(const Key('print_job_sale-2001')), findsNothing);
      expect(find.textContaining('Ысык-Көл'), findsNothing);

      // Пустая и нечитаемая очередь — это не то, что здесь показано.
      expect(find.byKey(const Key('print_queue_empty')), findsNothing);
      expect(find.byKey(const Key('print_queue_unreadable')), findsNothing);

      // Порядок — порядок создания: чек печатается в том порядке, в каком его
      // выбили, и виден в том же.
      final ys = <double>[
        for (final id in const [
          'sale-1001',
          'sale-1002',
          'sale-1003',
          'sale-1004',
          'sale-1005',
          'sale-1006',
        ])
          tester.getTopLeft(find.byKey(Key('print_job_$id'))).dy,
      ];
      expect(
        ys,
        orderedEquals(List<double>.from(ys)..sort()),
        reason: 'порядок заданий на экране обязан совпадать с порядком их '
            'создания',
      );

      await closeScreen(tester);
    },
  );

  testWidgets(
    'состояния и причина берутся из ресурсов, а не вшиты по-русски: тот же '
    'набор на английском называет состояния по-английски',
    (tester) async {
      await seedSixJobsPlusForeign();

      await tester.pumpWidget(host(locale: 'en'));
      await tester.pumpAndSettle();

      expect(
        inJob('sale-1003', find.text('Not printed, will be retried')),
        findsOneWidget,
      );
      expect(
        inJob('sale-1004', find.text('Deadline passed, will not retry by itself')),
        findsOneWidget,
      );
      expect(
        inJob('sale-1003', find.text('Reason: Нет бумаги')),
        findsOneWidget,
        reason: 'обёртка «Причина» локализуется, сама причина приходит от '
            'драйвера и показывается как есть — см. отчёт задачи 7',
      );
      expect(
        find.text('Не напечаталось, будет повторено'),
        findsNothing,
        reason: 'русский текст в английской локали означает вшитую строку',
      );

      await closeScreen(tester);
    },
  );

  testWidgets(
    'повтор задания, напечатанного, пока оператор выбирал срок, не даёт '
    'второго чека — экран показывает отказ как ответ',
    (tester) async {
      final stuck = job(
        id: 'sale-3001',
        createdAt: nowUtc.subtract(const Duration(minutes: 30)),
        expiresAt: nowUtc.add(const Duration(minutes: 30)),
      ).failWith('Нет бумаги');
      await store.put(stuck);

      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('print_job_retry_sale-3001')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('print_queue_extend_dialog')),
        findsOneWidget,
        reason: 'повтор — это решение о том, на сколько ещё чек имеет смысл, '
            'и его принимает оператор',
      );

      // Пока диалог открыт, принтер вернулся и чек вышел. Ровно эта гонка и
      // делает повтор опасным: оператор смотрит на «не напечаталось», а бумага
      // уже у покупателя.
      await store.put(stuck.beginAttempt().confirmPrinted());

      await tester.tap(find.byKey(const Key('print_queue_extend_30m')));
      await tester.pumpAndSettle();
      // Проход очереди никем не ожидается (И30 — `retry` возвращается сразу),
      // поэтому «байты не ушли» надо спрашивать **после** того, как очередь
      // отработала. Без этого пустой `transport.sent` значил бы всего лишь
      // «очередь ещё не дошла до задания», то есть проверка была бы зелёной и
      // при неверном повторе.
      await queue.whenIdle();
      await tester.pumpAndSettle();

      expect(
        transport.sent,
        isEmpty,
        reason: 'второй чек — это второй уход байтов в принтер, и его быть не '
            'должно',
      );
      final after = await store.jobById('sale-3001');
      expect(
        after!.state,
        PrintJobState.printed,
        reason: 'повтор не имеет права вернуть подтверждённое задание в '
            'очередь',
      );

      expect(
        find.byKey(const Key('print_queue_action_result')),
        findsOneWidget,
        reason: 'отказ обязан быть ответом на экране, а не молчанием после '
            'нажатой кнопки',
      );
      expect(
        find.text('Этот чек уже напечатан — второй раз он не печатается'),
        findsOneWidget,
      );

      await closeScreen(tester);
    },
  );

  testWidgets(
    'повтор живого застрявшего задания возвращает его в очередь с новым '
    'сроком и заново начатым счётчиком попыток — и очередь его печатает',
    (tester) async {
      final expiredAt = nowUtc.subtract(const Duration(minutes: 10));
      final expired = job(
        id: 'sale-3002',
        createdAt: nowUtc.subtract(const Duration(minutes: 40)),
        expiresAt: expiredAt,
      ).beginAttempt().failWith('Принтер не отвечает').expireAt(
        expiredAt.add(const Duration(seconds: 1)),
      );
      await store.put(expired);
      expect(expired.attempts, 1);

      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('print_job_retry_sale-3002')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('print_queue_extend_2h')));
      await tester.pumpAndSettle();
      // Проход очереди не ожидается вызывающим (И30 — `submit`/`retry`
      // возвращаются сразу), поэтому здесь его надо дождаться явно, прежде чем
      // спрашивать, ушли ли байты.
      await queue.whenIdle();
      await tester.pumpAndSettle();

      expect(find.text('Задание снова в очереди'), findsOneWidget);

      final after = (await store.jobById('sale-3002'))!;
      expect(
        after.expiresAt.isAfter(expiredAt),
        isTrue,
        reason: 'продление на два часа обязано сдвинуть срок вперёд',
      );
      expect(
        after.state,
        PrintJobState.printed,
        reason: 'продлённое задание очередь берёт в работу сама — иначе повтор '
            'из интерфейса означал бы только «срок сдвинут», а не «чек будет»',
      );
      // **Счётчик считается после печати, а не до, и число здесь не круглое
      // намеренно.** До повтора попытка уже была одна (`beginAttempt` в
      // построении истёкшего задания). Ручной повтор обнуляет счётчик, очередь
      // делает **одну** новую попытку — значит в базе снова единица. Не
      // обнулись он, здесь была бы двойка, так что именно это сравнение и
      // отличает «счётчик начат заново» от «счётчик продолжен».
      expect(
        after.attempts,
        1,
        reason: 'ручной повтор — новая возможность: счётчик начинается заново, '
            'поэтому после единственной новой попытки он равен единице, а не '
            'двум',
      );
      expect(
        after.failureReason,
        isNull,
        reason: 'прошлая причина больше не объясняет текущее состояние',
      );
      // Задание было отдано в принтер ровно один раз — очередь взялась за него
      // сразу после повтора, и это уже настоящая печать, а не второй чек.
      expect(transport.sent, hasLength(1));

      await closeScreen(tester);
    },
  );

  testWidgets(
    'отмена задания из интерфейса выводит его из очереди и говорит об этом',
    (tester) async {
      await store.put(
        job(
          id: 'sale-4001',
          createdAt: nowUtc.subtract(const Duration(minutes: 30)),
          expiresAt: nowUtc.add(const Duration(minutes: 30)),
        ).failWith('Нет бумаги'),
      );

      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('print_job_cancel_sale-4001')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('print_queue_cancel_confirm')));
      await tester.pumpAndSettle();

      expect(find.text('Задание отменено'), findsOneWidget);
      final after = (await store.jobById('sale-4001'))!;
      expect(after.state, PrintJobState.cancelled);
      expect(
        after.failureReason,
        'Нет бумаги',
        reason: 'в журнале остаётся, на что смотрел отменявший',
      );
      expect(
        transport.sent,
        isEmpty,
        reason: 'отменённый чек в принтер не уходит',
      );

      await closeScreen(tester);
    },
  );

  testWidgets(
    'нечитаемая очередь и пустая очередь — разные экраны: одна испорченная '
    'строка не выглядит как «печатать нечего»',
    (tester) async {
      // Живое задание, которое **должно** было бы быть видно, и одна строка,
      // записанная сборкой с неизвестным этой состоянием. Хранилище такую
      // строку не угадывает, а бросает (`_stateFromStoredName`), и падает всё
      // перечисление целиком — именно это оператор и обязан увидеть.
      await store.put(
        job(
          id: 'sale-5001',
          createdAt: nowUtc.subtract(const Duration(minutes: 30)),
          expiresAt: nowUtc.add(const Duration(minutes: 30)),
        ).failWith('Нет бумаги'),
      );
      final corruptCreatedAt = nowUtc.subtract(const Duration(minutes: 25));
      await db
          .into(db.printJobs)
          .insert(
            PrintJobsCompanion.insert(
              jobId: 'sale-5002',
              terminalId: ownTerminalId,
              posId: 7,
              payloadBytes: Uint8List.fromList(const [0x1b, 0x40]),
              createdAtEpochMs: corruptCreatedAt.millisecondsSinceEpoch,
              expiresAtEpochMs: nowUtc
                  .add(const Duration(minutes: 30))
                  .millisecondsSinceEpoch,
              updatedAtEpochMs: corruptCreatedAt.millisecondsSinceEpoch,
              state: 'teleported',
              attempts: const Value(0),
            ),
          );

      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('print_queue_unreadable')),
        findsOneWidget,
        reason: 'испорченная строка обязана быть названа, а не проглочена',
      );
      expect(
        find.byKey(const Key('print_queue_empty')),
        findsNothing,
        reason: 'нечитаемая очередь и пустая очередь ведут оператора в разные '
            'места и обязаны выглядеть по-разному',
      );
      expect(
        find.byKey(const Key('print_job_sale-5001')),
        findsNothing,
        reason: 'радиус поражения назван честно: одна строка уносит весь '
            'список, и экран не делает вид, что показал его',
      );
      expect(find.textContaining('teleported'), findsOneWidget);

      await closeScreen(tester);
    },
  );

  testWidgets(
    'пустая очередь говорит, что печатать нечего, и не выглядит поломкой',
    (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('print_queue_empty')), findsOneWidget);
      expect(find.byKey(const Key('print_queue_unreadable')), findsNothing);
      expect(find.byKey(const Key('print_queue_list')), findsNothing);
      expect(
        find.text('Очередь пуста — непечатанных чеков нет.'),
        findsOneWidget,
      );

      await closeScreen(tester);
    },
  );

  testWidgets(
    'без зарегистрированной очереди экран открывается и говорит, что очередь '
    'недоступна, — а не падает и не показывает пустой список',
    (tester) async {
      await GetIt.I.unregister<PrintQueue>();

      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('print_queue_unavailable')), findsOneWidget);
      expect(find.byKey(const Key('print_queue_empty')), findsNothing);
      expect(find.byType(PrinterSettingsScreen), findsOneWidget);

      await closeScreen(tester);
    },
  );
}
