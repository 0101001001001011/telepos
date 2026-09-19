/// Дисплей покупателя: что касса отправила — и чего она про это НЕ знает.
///
/// # Главная проба здесь — не про экран
///
/// Обёртка `RecordingCustomerDisplay` встаёт между кассой и настоящим
/// дисплеем. Ровно в этом месте и заводится самый дорогой дефект раздела:
/// обёртка, которая записывает строку, но **не доносит её до порта**,
/// выглядит идеально — журнал полон, экран красив, дисплей тёмен. Поэтому
/// первая проба проверяет, что вызов доходит до обёрнутого.
library;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/data/diagnostics/local_hardware_diagnostics.dart';
import 'package:telepos/domain/diagnostics/hardware_diagnostics.dart';
import 'package:telepos/domain/terminal/terminal.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/hardware/display/customer_display_journal.dart';
import 'package:telepos/hardware/display/customer_display_manager.dart';
import 'package:telepos/hardware/display/display_config.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/screens/diagnostics/display_diagnostics_tab.dart';

class _SelfTerminals implements TerminalRepository {
  @override
  Future<Terminal> self() async =>
      const Terminal(id: 1, name: 'Касса', pointMode: PointMode.cashier);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'проба диагностики: ${invocation.memberName} у терминалов не поднят',
  );
}

/// Настоящий получатель: записывает, что до него дошло.
class _SpyDisplay implements CustomerDisplayManager {
  final List<String> calls = [];
  Object? throwOnNext;

  @override
  CustomerDisplayConfig get config => const CustomerDisplayConfig(
    enabled: true,
    port: 'COM9',
    model: DisplayModel.vfd20,
    baudRate: 9600,
  );

  @override
  bool get isConnected => true;

  void _note(String call) {
    final boom = throwOnNext;
    if (boom != null) {
      throwOnNext = null;
      throw boom;
    }
    calls.add(call);
  }

  @override
  Future<bool> connect() async => true;

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> clear() async => _note('clear');

  @override
  Future<void> showPrice(Decimal price) async => _note('price:$price');

  @override
  Future<void> showTotal(Decimal total) async => _note('total:$total');

  @override
  Future<void> showText(String text) async => _note('text:$text');

  @override
  Future<void> showWelcome() async => _note('welcome');

  @override
  Future<void> showChange(Decimal change) async => _note('change:$change');
}

void main() {
  late CustomerDisplayJournal journal;

  setUp(() async {
    journal = CustomerDisplayJournal();
    await GetIt.I.reset();
  });

  /// Настоящая кассовая реализация порта над настоящим журналом — тот же
  /// путь, каким вкладка живёт на кассе.
  ///
  /// С пунктом 4 плана диагностики вкладка перестала брать
  /// `CustomerDisplayJournal` из `GetIt`: журнал живёт в `lib/hardware/`,
  /// которого в браузерной сборке быть не может, и на планшете этой вкладки
  /// не было вовсе. Проба от этого не ослабла — под вкладкой тот же журнал,
  /// добавился только порт между ними.
  void bindPort({CustomerDisplayJournal? display}) {
    GetIt.I.registerSingleton<HardwareDiagnosticsRepository>(
      LocalHardwareDiagnostics(
        terminals: _SelfTerminals(),
        displayJournal: display,
      ),
    );
  }

  tearDown(() async {
    await journal.dispose();
    await GetIt.I.reset();
  });

  group('Обёртка памяти', () {
    test('строка доходит до настоящего дисплея, а не остаётся в журнале', () async {
      final spy = _SpyDisplay();
      final display = RecordingCustomerDisplay(spy, journal);

      await display.showTotal(Decimal.parse('1250.00'));

      // `1250`, а не `1250.00`: соглядатай печатает Decimal как есть. Важно
      // здесь другое — что вызов вообще дошёл; запись суммы проверяется
      // строкой ниже, и она обязана совпасть с той, что уходит в порт.
      expect(
        spy.calls,
        ['total:1250'],
        reason:
            'обёртка, которая пишет в журнал и не пишет в порт, выглядит '
            'идеально: журнал полон, дисплей тёмен',
      );
      expect(journal.recent().single.text, '1250.00');
    });

    test('отказ порта попадает в журнал и не проглатывается', () async {
      final spy = _SpyDisplay()..throwOnNext = StateError('COM9 занят');
      final display = RecordingCustomerDisplay(spy, journal);

      await expectLater(
        display.showText('Добро пожаловать'),
        throwsA(isA<StateError>()),
        reason: 'проглоченный отказ превратил бы обёртку в глушитель',
      );
      final line = journal.recent().single;
      expect(line.accepted, isFalse);
      expect(line.refusal, contains('COM9 занят'));
    });

    test('«сейчас на дисплее» — последняя ПРИНЯТАЯ строка', () async {
      final spy = _SpyDisplay();
      final display = RecordingCustomerDisplay(spy, journal);

      await display.showTotal(Decimal.parse('100.00'));
      spy.throwOnNext = StateError('оборвано');
      await expectLater(
        display.showTotal(Decimal.parse('200.00')),
        throwsA(isA<StateError>()),
      );

      expect(
        journal.current?.text,
        '100.00',
        reason:
            'на стекле осталось прежнее: строка, которая не ушла, ничего не '
            'сменила',
      );
    });
  });

  group('Вкладка дисплея', () {
    Future<void> mount(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: DisplayDiagnosticsTab()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('пустой журнал говорит словами, а не пустотой', (tester) async {
      bindPort(display: journal);
      await mount(tester);
      expect(
        find.byKey(const ValueKey('display-diagnostics-empty')),
        findsOneWidget,
      );
    });

    testWidgets('«памяти нет» и «ничего не отправляли» — разные ответы', (
      tester,
    ) async {
      // Касса без журнала дисплея. Скажи вкладка здесь «на дисплей ничего не
      // отправляли», наладчик пошёл бы проверять исправный дисплей.
      bindPort();
      await mount(tester);

      expect(
        find.byKey(const ValueKey('display-diagnostics-unavailable')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('display-diagnostics-empty')),
        findsNothing,
      );
    });

    testWidgets('порта диагностики нет — вкладка говорит и это', (
      tester,
    ) async {
      await mount(tester);

      expect(find.textContaining('спросить не у кого'), findsOneWidget);
    });

    testWidgets('экран не обещает, что покупатель это увидел', (tester) async {
      journal.record(
        CustomerDisplayLine(
          at: DateTime(2026, 9, 19, 14),
          kind: CustomerDisplayCall.total,
          text: '1250.00',
        ),
      );
      bindPort(display: journal);
      await mount(tester);

      expect(
        find.byKey(const ValueKey('display-diagnostics-current')),
        findsOneWidget,
      );
      expect(find.textContaining('1250.00'), findsWidgets);
      expect(
        find.textContaining('неотличим от исправного'),
        findsOneWidget,
        reason:
            'канал односторонний, и граница знания кассы обязана быть на '
            'экране, а не в исходниках',
      );
    });
  });
}
