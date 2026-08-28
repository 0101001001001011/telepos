library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/hardware/printer/printer_manager.dart';

import 'support/harness.dart';

/// Продажа при недоступном принтере: деньги взяты, **и чек не потерян**.
///
/// Это та самая дыра, ради которой писался весь план 2в. До него
/// `payment_screen.dart` ловил исключение печати, показывал предупреждение — и
/// задание исчезало вместе с локальными переменными асинхронной функции:
/// повторить было нечего. Здесь тот же путь проходится целиком, через
/// настоящее дерево приложения и настоящий граф зависимостей, и проверяется
/// **строка в базе**, а не ответ, живущий ровно столько, сколько живёт вызов.
///
/// Одновременно это повторная проверка И30 (docs/system-architecture.md,
/// раздел 8): очередь появилась на пути чека, но не на пути денег. Соседний
/// файл `no_printer_binding_sale_test.dart` проверяет случай «принтера нет
/// вовсе»; здесь принтер **есть и не отвечает** — это разные отказы, и второй
/// раньше стоил чека.
void main() {
  final h = E2eHarness();

  setUpAll(() => h.setUp());
  tearDownAll(() => h.tearDown());

  Future<void> render(WidgetTester t) async {
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    await t.pump(const Duration(milliseconds: 400));
  }

  Future<void> tapText(WidgetTester t, String text, {bool last = false}) async {
    final f = find.text(text);
    if (f.evaluate().isEmpty) {
      throw TestFailure('tap target not found: "$text"');
    }
    await t.tap(last ? f.last : f.first);
    await render(t);
  }

  /// Продажи в состоянии **завершённой** (`state = 1`), а не просто начатой:
  /// черновик появляется в `sales` сразу при открытии корзины, до всякой
  /// оплаты, поэтому подсчёт всех строк прошёл бы и без принятых денег.
  Future<int> completedSaleCount() async {
    final rows = await h.db
        .customSelect('SELECT COUNT(*) AS c FROM sales WHERE state = 1')
        .get();
    return rows.first.read<int>('c');
  }

  Future<List<({String id, int bytes, String state})>> printJobs() async {
    final rows = await h.db
        .customSelect(
          'SELECT job_id, LENGTH(payload_bytes) AS n, state FROM print_jobs',
        )
        .get();
    return rows
        .map(
          (r) => (
            id: r.read<String>('job_id'),
            bytes: r.read<int>('n'),
            state: r.read<String>('state'),
          ),
        )
        .toList();
  }

  testWidgets('чек не уходит в недоступный принтер и остаётся в очереди', (
    t,
  ) async {
    // Принтер есть — и он не отвечает. Именно этот случай раньше стоил чека:
    // «принтера нет» приложение хотя бы замечало заранее, а сломавшийся посреди
    // смены выглядел рабочим до самой записи.
    final printer = _UnreachablePrinter();
    GetIt.I.registerSingleton<PrinterManager>(printer);

    await h.pumpApp(t);
    await t.pump(const Duration(seconds: 1));
    await h.loginAsCashier(t);
    await render(t);

    h.router!.go('/shift');
    await render(t);
    await tapText(t, 'Открыть смену');
    await t.enterText(find.byType(TextField).last, '50000');
    await render(t);
    await tapText(t, 'Открытие смены', last: true);
    await render(t);

    final salesBefore = await completedSaleCount();
    expect(
      await printJobs(),
      isEmpty,
      reason:
          'до продажи очередь печати пуста — иначе проверка ниже ничего '
          'не доказывает',
    );

    h.router!.go('/sale');
    await render(t);
    await t.enterText(find.byType(TextField).first, '4607001');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await render(t);

    await tapText(t, 'ОПЛАТИТЬ');
    final denom = find.text('1K');
    if (denom.evaluate().isNotEmpty) {
      await t.tap(denom.first);
      await render(t);
    }
    await tapText(t, 'ОПЛАТИТЬ', last: true);
    await render(t);
    await t.pump(const Duration(seconds: 1));
    await t.pump(const Duration(seconds: 1));

    // ── И30: деньги приняты, что бы ни делал принтер ────────────────────────
    expect(
      await completedSaleCount(),
      greaterThan(salesBefore),
      reason:
          'продажа обязана завершиться при неотвечающем принтере: приём денег '
          'не ждёт ни соединения, ни бумаги (И30)',
    );

    // ── Ради чего всё: чек не потерян ───────────────────────────────────────
    final jobs = await printJobs();
    expect(
      jobs,
      hasLength(1),
      reason:
          'чек, не ушедший в принтер, обязан лежать в очереди заданием. Пусто '
          'здесь — это прежнее поведение: деньги взяты, бумаги нет, повторить '
          'нечего',
    );
    expect(
      jobs.single.bytes,
      greaterThan(0),
      reason: 'в задании лежит сам чек, а не пустая строка-заглушка',
    );
    expect(
      jobs.single.id,
      contains('sale'),
      reason:
          'идентификатор говорит, что это за документ, и построен из чека, а '
          'не из момента отправки: ${jobs.single.id}',
    );
    expect(
      printer.writes,
      greaterThan(0),
      reason:
          'очередь действительно пробовала печатать; ноль означал бы, что '
          'задание лежит нетронутым и проверка выше прошла бы даже у очереди, '
          'которая не печатает вовсе',
    );
  });
}

/// Принтер, который есть в системе и не отвечает.
///
/// Отказ на записи, а не на подключении: полуоткрытый сокет выглядит здоровым
/// до первой записи, и именно так сетевой принтер отказывает в жизни.
class _UnreachablePrinter extends BufferedPrinterManager {
  int writes = 0;

  @override
  bool get isConnected => true;

  @override
  Future<PrinterConnectionResult> connect() async => PrinterConnectionResult.ok(
    const PrinterInfo(name: 'Сетевой принтер', address: '10.0.0.9:9100'),
  );

  @override
  Future<void> disconnect() async {}

  @override
  Future<PrinterStatus> getStatus() async => PrinterStatus.offline;

  @override
  Future<PrintResult> writeRaw(Uint8List data) async {
    writes++;
    return PrintResult.error('Принтер 10.0.0.9:9100 не отвечает');
  }
}
