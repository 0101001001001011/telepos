/// Диагностику с планшета можно **дойти и нажать** — пункт «Достижимость с
/// браузерного терминала» плана `2026-09-19-hardware-diagnostics.md`.
///
/// # Почему одной пробы провода мало
///
/// `test/backend/diagnostics_op_test.dart` доказывает, что обе операции
/// работают и что чек на планшете — разбор тех же байтов. Она **не
/// доказывает, что наладчик может ими воспользоваться**, — и ровно этот класс
/// дефекта дерево ловило уже пять раз: операции отзыва сеанса были готовы и
/// недостижимы; `pay.certificateIssue` написана и не имеет ни одного
/// вызывающего; `WtPaymentService` был верен и не привязан ни одной строкой;
/// приём аванса работал и не имел экрана в браузере; сами вкладки
/// диагностики были написаны и **не достижимы ни одним переходом** — экраны
/// без маршрута (план, пункт 1). Каждый раз набор оставался зелёным.
///
/// Здесь по исходникам сверяются звенья цепочки, каждое из которых молчаливо
/// рвётся:
///
/// 1. **точка входа привязывает порт** — без строки обе вкладки в браузере
///    скажут «диагностику спросить не у кого» и не покажут ничего;
/// 2. **браузерная таблица объявляет маршрут** и ведёт на настоящий экран, а
///    не на заглушку `WtNotPortedScreen`;
/// 3. **экрану назван дом** — вкладку открывают прямо по адресу, стека
///    переходов у неё нет, и `pop()` в ней не делает ничего;
/// 4. **маршрут связан с ключом права.** Без записи в карте `redirect`
///    браузерной таблицы пропустил бы **любого вошедшего**: карта — это
///    единственное, что он спрашивает. Две операции провода остались бы
///    единственной границей, и кассир без права увидел бы экран, а на нём
///    два отказа вместо честного «сюда нельзя».
///
/// Пятое звено — плитку, с которой на маршрут нажимают, — держит
/// `browser_routes_test` («на каждый объявленный маршрут кто-то ведёт»), но
/// здесь оно названо **поимённо** (файл и переход): тот сторож обходит граф
/// импортов, и опечатка в обходе сделала бы его зелёным на пустом множестве.
///
/// # И одно звено, которого у соседей нет: **раскладки чека в браузере нет**
///
/// Проба провода сличает два текста и потому ловит расхождение раскладок **в
/// момент прогона**. Этот сторож запрещает саму возможность: браузерная
/// половина и обе вкладки не имеют права ни разбирать байты ESC/POS, ни
/// знать ширину ленты. Разбор — в докстринге
/// `lib/domain/diagnostics/hardware_diagnostics.dart`.
@Tags(['architecture'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _entry = 'lib/web/main_web.dart';
const _table = 'lib/app/router/setup_router.dart';
const _home = 'lib/presentation/screens/terminal/terminal_home_screen.dart';
const _permissions = 'lib/core/constants/permission_keys.dart';
const _screen =
    'lib/presentation/screens/diagnostics/terminal_diagnostics_screen.dart';
const _printerTab =
    'lib/presentation/screens/diagnostics/printer_diagnostics_tab.dart';
const _fiscalTab =
    'lib/presentation/screens/diagnostics/fiscal_diagnostics_tab.dart';

/// Три вкладки пункта 4: ящик, весы, дисплей покупателя.
///
/// До него они брали из `GetIt` **кассовые** службы — `CashDrawerJournal`,
/// `CustomerDisplayJournal`, `ScalesService`, — а все три живут в
/// `lib/hardware/`, которого в браузерной сборке быть не может. Поэтому здесь
/// они стоят в тех же двух запретах, что и соседи: ни `dart:io`, ни раскладки
/// чека.
const _drawerTab =
    'lib/presentation/screens/diagnostics/drawer_diagnostics_tab.dart';
const _scalesTab =
    'lib/presentation/screens/diagnostics/scales_diagnostics_tab.dart';
const _displayTab =
    'lib/presentation/screens/diagnostics/display_diagnostics_tab.dart';
const _wire = 'lib/web/wt_hardware_diagnostics.dart';

/// Комментарии не считаются: ссылка в докстринге ничего не привязывает и
/// никуда не ведёт. Ровно на этом сторожа исходника и слепнут.
String _code(String path) {
  final file = File(path);
  if (!file.existsSync()) fail('сторож смотрит в несуществующий файл $path');
  return file
      .readAsLinesSync()
      .where(
        (l) =>
            !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'),
      )
      .join('\n');
}

void main() {
  test('точка входа браузера привязывает порт диагностики', () {
    final source = _code(_entry);
    expect(
      source,
      contains('registerLazySingleton<HardwareDiagnosticsRepository>'),
      reason:
          'Без этой строки обе вкладки не найдут порта в контейнере и скажут '
          '«диагностику спросить не у кого» — то есть пробел останется ровно '
          'там, где его закрывали. Набор при этом зелен: экранные пробы '
          'регистрируют порт сами.',
    );
    expect(
      source,
      contains('WtHardwareDiagnostics('),
      reason:
          'диагностика обязана быть проводной: `LocalHardwareDiagnostics` в '
          'браузере не компилируется вовсе (drift и `lib/hardware/`), а любая '
          'третья реализация здесь — вторая раскладка чека',
    );
  });

  test('браузерная таблица ведёт на настоящий экран диагностики', () {
    final source = _code(_table);
    expect(
      source,
      contains('path: AppRoutes.terminalDiagnostics'),
      reason:
          'маршрута нет — в браузере это «Page Not Found: GoException» на '
          'плитке, которая стоит на доме терминала',
    );
    // Запись в таблице и **экран** — разные вещи: `/payment` жил в таблице
    // задолго до того, как начал открывать оплату, и вёл на
    // `WtNotPortedScreen`. Сторож, смотрящий на наличие записи, был бы зелен
    // на заглушке.
    expect(source, contains('TerminalDiagnosticsScreen('));
    expect(
      source,
      contains('homeRoute: AppRoutes.terminalHome'),
      reason:
          'экрану не назван дом: вкладка, открытая прямо по адресу, стека '
          'переходов не имеет, и наладчик остаётся на экране навсегда',
    );
  });

  test('маршрут диагностики связан с ключом права, а не открыт всем', () {
    expect(
      _code(_permissions),
      contains("'/terminal-diagnostics': settingsHardware"),
      reason:
          '`redirect` браузерной таблицы спрашивает ровно эту карту. Без '
          'записи экран открылся бы любому вошедшему, и границей остались бы '
          'только две операции провода — то есть кассир без права увидел бы '
          'экран и два отказа на нём вместо честного «сюда нельзя»',
    );
  });

  test('дом терминала ведёт на диагностику', () {
    final source = _code(_home);
    expect(source, contains('context.go(AppRoutes.terminalDiagnostics)'));
    expect(
      source,
      contains('PermissionKeys.settingsHardware'),
      reason:
          'плитка обязана стоять под тем же ключом, что маршрут и обе '
          'операции провода: показ под другим правом означал бы кнопку, '
          'которая видна одному, а работает у другого',
    );
  });

  test('раскладки чека в браузерной половине нет ни строки', () {
    // Запрет, а не сравнение: проба провода ловит расхождение раскладок в
    // момент прогона, а этот сторож запрещает саму возможность его завести.
    // Текст чека на экране обязан рождаться в одном месте на всё дерево.
    for (final file in [
      _wire,
      _screen,
      _printerTab,
      _fiscalTab,
      _drawerTab,
      _scalesTab,
      _displayTab,
    ]) {
      final source = _code(file);
      for (final forbidden in [
        'renderEscPosAsText',
        'escpos_text_preview',
        'ReceiptBuilder',
        'charWidth',
        'payloadBytes',
      ]) {
        expect(
          source,
          isNot(contains(forbidden)),
          reason:
              '$file знает о раскладке чека ($forbidden) — это вторая '
              'раскладка в дереве, ровно та беда, ради которой раскладку '
              'свели к одной (докстринг escpos_text_preview.dart)',
        );
      }
    }
  });

  test('браузерный экран диагностики не тянет `dart:io`', () {
    // Ровно та причина, по которой экран здесь свой, а не кассовый
    // `DiagnosticsScreen`: тот считает плашку эмулятора через
    // `InternetAddress.isLoopback`. `dart:io` в браузерной сборке нет, и
    // `flutter build web` не собрался бы вовсе — но узнать об этом на сборке
    // дороже, чем здесь.
    //
    // Транзитивное замыкание сторожит `browser_routes_test`; здесь — прямой
    // якорь на файл, чтобы причина была названа рядом с ней.
    for (final file in [
      _screen,
      _printerTab,
      _fiscalTab,
      _drawerTab,
      _scalesTab,
      _displayTab,
    ]) {
      expect(
        _code(file),
        isNot(contains("dart:io")),
        reason: '$file не соберётся под веб',
      );
    }
  });

  test('три вкладки пункта 4 не знают кассовых служб напрямую', () {
    // Запрет, а не проверка поведения. До пункта 4 каждая из трёх брала свою
    // кассовую службу из `GetIt` — и это ровно та строка, которую правка
    // «да просто верни как было» вернёт первой, потому что на кассе она
    // работает.
    //
    // В браузере она не работает никак: все три службы живут в
    // `lib/hardware/`, и сторож `browser_routes_test` красит такой импорт в
    // замыкании таблицы маршрутов. Здесь — прямой якорь на файл, чтобы
    // причина стояла рядом с ней: обход графа импортов можно сломать
    // опечаткой и не заметить, а этот сторож смотрит в три названных файла.
    const forbidden = {
      _drawerTab: ['CashDrawerJournal', 'cash_drawer_journal'],
      _displayTab: ['CustomerDisplayJournal', 'customer_display_journal'],
      _scalesTab: ['ScalesService', 'scales_service', 'ScalesReading('],
    };
    forbidden.forEach((file, names) {
      final source = _code(file);
      for (final name in names) {
        expect(
          source,
          isNot(contains(name)),
          reason:
              '$file знает кассовую службу ($name) напрямую — в браузере её '
              'нет вовсе, и вкладка там не покажет ничего. Спрашивать '
              'положено порт HardwareDiagnosticsRepository',
        );
      }
      expect(
        source,
        contains('HardwareDiagnosticsRepository'),
        reason:
            '$file обязана спрашивать порт: без него вкладка на планшете '
            'пуста, а на кассе работает — то есть дефект виден только там, '
            'куда смотрят реже',
      );
    });
  });

  test('экран планшета несёт все пять вкладок, а не две', () {
    // Вкладка, которой нет на экране, читается человеком как «у этой кассы
    // такого прибора нет». Ровно это и стояло на планшете до пункта 4: три
    // прибора из пяти отсутствовали, и отсутствие было названо только
    // докстрингом, которого наладчик не читает.
    final source = _code(_screen);
    for (final tab in [
      'PrinterDiagnosticsTab()',
      'DrawerDiagnosticsTab()',
      'ScalesDiagnosticsTab()',
      'DisplayDiagnosticsTab()',
      'FiscalDiagnosticsTab()',
    ]) {
      expect(
        source,
        contains(tab),
        reason: 'на экране планшета нет вкладки $tab',
      );
    }
    expect(
      source,
      contains('length: 5'),
      reason:
          'число вкладок у `DefaultTabController` и число детей `TabBarView` '
          'обязаны совпадать: разойдясь, они дают либо пустую вкладку, либо '
          'падение при переходе на неё',
    );
  });
}
