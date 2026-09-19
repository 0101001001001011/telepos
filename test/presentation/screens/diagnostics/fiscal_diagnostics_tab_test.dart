/// Диагностика ОФД отвечает на вопрос «работает ли», а не только «что сломано».
///
/// # Почему это не очевидно и потому проверяется
///
/// Очередь фискализации держит только то, что **не** уехало. На исправной
/// кассе она пуста. Экран, показывающий одну очередь, на исправной кассе
/// выглядит так же, как на кассе, где оператор не настроен вовсе, — то есть
/// отвечает «ничего нет» на оба противоположных вопроса.
///
/// Наладчику при запуске нужен обратный ответ: «документы уходят, вот
/// последний, вот его признак». Поэтому две половины, и проба следит, что
/// обе на месте и что пустота одной не выдаётся за беду.
///
/// # Что изменилось 2026-09-19
///
/// Вкладка перестала спрашивать `AppDatabase` и `FiscalQueueStore` — между
/// ней и кассой встал порт `HardwareDiagnosticsRepository` (пункт
/// «Достижимость с браузерного терминала» плана
/// `2026-09-19-hardware-diagnostics.md`).
///
/// Проба от этого не ослабла, а **окрепла**: под вкладку ставится настоящая
/// кассовая реализация порта над настоящей базой drift, то есть тот же путь,
/// каким вкладка живёт на кассе, — подделки между ними нет ни одной.
/// Различать «порта нет вовсе» и «оператор не настроен» проба требует
/// отдельно: это разные ответы, и сливать их значило бы отправить наладчика
/// настраивать оператора там, где беда в сборке.
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/data/database/app_database.dart'
    hide FiscalQueueEntry, Terminal;
import 'package:telepos/data/diagnostics/local_hardware_diagnostics.dart';
import 'package:telepos/data/fiscal/offline_queueing_provider.dart';
import 'package:telepos/domain/fiscal/fiscal_settings.dart';
import 'package:telepos/domain/usecases/fiscal/fiscal_service.dart';
import 'package:telepos/domain/diagnostics/hardware_diagnostics.dart';
import 'package:telepos/domain/terminal/terminal.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/screens/diagnostics/fiscal_diagnostics_tab.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await GetIt.I.reset();
  });

  tearDown(() async {
    await db.close();
    await GetIt.I.reset();
  });

  /// Настоящая кассовая реализация порта над настоящей базой — тот же путь,
  /// каким вкладка живёт на кассе.
  void bindPort({FiscalQueueStore? queue}) {
    GetIt.I.registerSingleton<HardwareDiagnosticsRepository>(
      LocalHardwareDiagnostics(
        terminals: _SelfTerminals(),
        db: queue == null ? null : db,
        fiscalQueue: queue,
      ),
    );
  }

  Future<void> mount(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        // Словари подключены нарочно: плашка эмулятора — строка интерфейса,
        // и без делегатов `AppLocalizations.of` вернул бы null, а проба
        // покраснела бы на пустом месте.
        locale: Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: FiscalDiagnosticsTab()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> acceptReceipt({
    required int operationId,
    required String fiscalNo,
  }) => db
      .into(db.webkassaReceipts)
      .insert(
        WebkassaReceiptsCompanion.insert(
          operationId: operationId,
          fiscalNo: Value(fiscalNo),
          wkReceiptNo: Value('WK-$operationId'),
          receiptNo: Value(7000 + operationId),
        ),
      );

  testWidgets('принятый оператором документ виден с признаком', (
    tester,
  ) async {
    await acceptReceipt(operationId: 1, fiscalNo: 'ФП-4210');
    bindPort(queue: _EmptyQueue());

    await mount(tester);

    expect(
      find.textContaining('ФП-4210'),
      findsOneWidget,
      reason:
          'это и есть доказательство работы: без него исправная касса '
          'выглядит так же, как касса без оператора',
    );
    expect(find.textContaining('WK-1'), findsOneWidget);
  });

  testWidgets('пустая очередь на исправной кассе — не беда, и так и сказано', (
    tester,
  ) async {
    await acceptReceipt(operationId: 1, fiscalNo: 'ФП-4210');
    bindPort(queue: _EmptyQueue());

    await mount(tester);

    expect(find.textContaining('оператор принял'), findsOneWidget);
    expect(
      find.textContaining('не настроен'),
      findsNothing,
      reason: 'касса настроена: пустая очередь у неё — признак здоровья',
    );
  });

  testWidgets('строка очереди показывает ключ, попытки и дословную ошибку', (
    tester,
  ) async {
    bindPort(
      queue: _StubQueue.named(
        failed: [
          FiscalQueueEntry(
            idempotencyKey: 'sale-1789757442-7001-1',
            opType: FiscalQueueOp.sale,
            payload: const {
              'sale': {'receiptNo': 7001, 'posId': 1},
            },
            occurredAt: DateTime(2026, 9, 19, 10),
            status: FiscalQueueStatus.failed,
            attempts: 3,
            lastError: 'Документ с ExternalCheckNumber уже зарегистрирован',
          ),
        ],
      ),
    );

    await mount(tester);

    expect(find.text('sale-1789757442-7001-1'), findsOneWidget);
    expect(
      find.textContaining('уже зарегистрирован'),
      findsOneWidget,
      reason:
          'ошибка оператора приводится дословно: приглаженная формулировка '
          'врёт ровно там, где её сверяют с кабинетом оператора',
    );
    expect(find.textContaining('попыток 3'), findsOneWidget);
  });

  testWidgets('тело запроса видно как есть', (tester) async {
    bindPort(
      queue: _StubQueue.named(
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

    await mount(tester);
    await tester.tap(find.text('sale-1789757442-7002-1'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('"receiptNo": 7002'),
      findsOneWidget,
      reason: 'это и есть «подробные данные по передаче», которых просили',
    );
  });

  testWidgets('оператора нет — сказано словами, а не пустым списком', (
    tester,
  ) async {
    // Порт есть, очереди нет: касса собрана, оператор не настроен.
    bindPort();

    await mount(tester);
    expect(find.textContaining('не настроен'), findsOneWidget);
  });

  // ───────────────────────── пометка эмулятора ──────────────────────────────
  //
  // Признак — АДРЕС оператора, а не выключатель встроенного эмулятора. Касса,
  // направленная на эмулятор, запущенный руками из командной строки, обязана
  // быть помечена так же: ни одного «включено» в кассе при этом нет.

  const banner = ValueKey('fiscal-diagnostics-emulator-banner');

  /// Настройки оператора плюс поднятый кассовый порт.
  ///
  /// Признак «за адресом эмулятор» считает **касса**
  /// (`LocalHardwareDiagnostics`), а не вкладка: вкладка одна на обе
  /// поверхности, а разбор адреса требует `dart:io`, которого в браузерной
  /// сборке нет. Поэтому проба поднимает настоящий порт — тот самый путь,
  /// которым признак и приходит на экран.
  void useSettings(FiscalSettings settings) {
    GetIt.I.registerSingleton<FiscalSettingsSource>(_StubSettings(settings));
    bindPort(queue: _EmptyQueue());
  }

  testWidgets('адрес оператора на петле — плашка зажжена', (tester) async {
    useSettings(
      FiscalSettings(
        operatorType: FiscalOperatorType.webkassa,
        baseUrl: 'http://127.0.0.1:8085',
      ),
    );
    await mount(tester);
    expect(
      find.byKey(banner),
      findsOneWidget,
      reason:
          'документы уходят на этот же компьютер: чек выглядит настоящим, '
          'документа у покупателя нет, и молчать об этом нельзя',
    );
  });

  testWidgets('петля пишется тремя способами, и все три помечены', (
    tester,
  ) async {
    for (final url in const [
      'http://localhost:8085',
      'http://[::1]:8085',
      'http://127.0.0.2:8085',
    ]) {
      await GetIt.I.reset();
      useSettings(
        FiscalSettings(
          operatorType: FiscalOperatorType.webkassa,
          baseUrl: url,
        ),
      );
      await mount(tester);
      expect(
        find.byKey(banner),
        findsOneWidget,
        reason:
            '$url ведёт в тот же процесс на этой машине; одна строка «127.0.0.1» '
            'пометила бы одну запись из трёх',
      );
    }
  });

  testWidgets('локальный модуль перебивает адрес сервера — и метится он', (
    tester,
  ) async {
    // `WebKassaProvider._baseUrl` смотрит на локальный модуль первым. Плашка,
    // читающая только «Адрес сервера», пометила бы не тот адрес — и на кассе,
    // направленной облачным адресом, но с модулем на петле, промолчала бы.
    useSettings(
      FiscalSettings(
        operatorType: FiscalOperatorType.webkassa,
        baseUrl: 'https://devkkm.webkassa.kz',
        localModuleUrl: 'http://127.0.0.1:1332',
      ),
    );
    await mount(tester);
    expect(find.byKey(banner), findsOneWidget);
  });

  testWidgets('облачный адрес оператора плашки не зажигает', (tester) async {
    useSettings(
      FiscalSettings(
        operatorType: FiscalOperatorType.webkassa,
        baseUrl: 'https://devkkm.webkassa.kz',
      ),
    );
    await mount(tester);
    expect(
      find.byKey(banner),
      findsNothing,
      reason:
          'плашка на каждой кассе — это плашка, которую перестают читать '
          'через неделю',
    );
  });

  testWidgets('настроек нет вовсе — плашки нет, а не «на всякий случай»', (
    tester,
  ) async {
    await mount(tester);
    expect(
      find.byKey(banner),
      findsNothing,
      reason: '«не знаю» и «за адресом эмулятор» — разные ответы',
    );
  });
  testWidgets(
    'порта нет вовсе — это ДРУГАЯ фраза, а не «оператор не настроен»',
    (tester) async {
      // Ни одной привязки: голый процесс `bin/telepos_backend.dart` стоит
      // именно так. Сказать здесь «оператор не настроен» значило бы отправить
      // наладчика настраивать оператора там, где беда в сборке кассы.
      await mount(tester);
      expect(find.textContaining('спросить не у кого'), findsOneWidget);
      expect(find.textContaining('не настроен'), findsNothing);
    },
  );
}


/// Фискальные настройки как есть. `noSuchMethod` бросает: случайная новая
/// зависимость вкладки обязана падать громко, а не возвращать правдоподобное.
class _StubSettings implements FiscalSettingsSource {
  _StubSettings(this.settings);

  final FiscalSettings settings;

  @override
  Future<FiscalSettings> load() async => settings;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'проба диагностики: ${invocation.memberName} у настроек не поднят',
  );
}

/// Рабочее место кассы. Вкладка фискализации его не спрашивает вовсе —
/// реализация порта берёт его только для заданий печати, — но конструктор
/// порта без него не собрать.
class _SelfTerminals implements TerminalRepository {
  @override
  Future<Terminal> self() async =>
      const Terminal(id: 1, name: 'Касса', pointMode: PointMode.cashier);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'проба диагностики: ${invocation.memberName} у терминалов не поднят',
  );
}

class _EmptyQueue implements FiscalQueueStore {
  @override
  Future<List<FiscalQueueEntry>> pending() async => const [];

  @override
  Future<List<FiscalQueueEntry>> failed() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'проба диагностики: ${invocation.memberName} у очереди не поднят',
  );
}

class _StubQueue implements FiscalQueueStore {
  _StubQueue.named({
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
