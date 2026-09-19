@Tags(['architecture'])
library;

/// Сторож на правило диагностики: **вкладка показывает готовое значение, а
/// не разбирает сырьё, и один и тот же вопрос задаётся в одном месте**
/// (инвариант I170).
///
/// # Откуда правило и что оно стоило
///
/// Вкладки диагностики — одни и те же файлы на двух поверхностях: на кассе
/// (`DiagnosticsScreen`) и на планшете (`TerminalDiagnosticsScreen`).
/// Признак «за адресом оператора эмулятор» сначала считала вкладка — и это
/// уронило сборку веба: разбор адреса требует `dart:io`, которого в браузере
/// нет вовсе. Три сторожа браузерной таблицы покраснели разом (сведение
/// 2026-09-19, `1e46b1d4`).
///
/// Сборка — меньшая половина довода. Большая — **второй разбор даёт второй
/// ответ, и расходятся они молча**. Это измерено при написании сторожа, а не
/// предположено: в дереве жили **две** частные копии правила «это петля» —
/// `DiagnosticsScreen._isLoopback` и
/// `EmulatorSettingsScreen._looksLocal`, — при том что
/// `lib/core/net/loopback.dart` заведён ровно ради единственности этого
/// ответа и говорит об этом первой же строкой докстринга. Обе копии уже
/// отставали: `[::1]` в квадратных скобках (так адрес IPv6 приходит из URL)
/// и адрес с пробелами по краям общая функция считает петлёй, копии — нет.
/// Увидеть расхождение нечем: «плашка не зажглась» выглядит как исправная
/// касса, а не как дефект.
///
/// # Что именно проверяется — и чего здесь нет намеренно
///
/// 1. **Вопрос «это петля?» задаётся в одном месте.** Ответ на него —
///    `isLoopbackHost`/`isLoopbackUrl`; больше никто в `lib/` не разбирает
///    адрес сам. Сеть — по решению (`.isLoopback`, сравнение с литералом
///    `'localhost'`), а не по слову «loopback»: литерал `'localhost'` живёт
///    в дереве и как **значение** (имя в сертификате, узел по умолчанию у
///    сервера), и запрет на слово пришлось бы глушить списком в тот же день.
/// 2. **Вкладка, общая для двух поверхностей, не берёт `dart:io` прямо.**
///    Список общих вкладок **вычисляется** из импортов
///    `terminal_diagnostics_screen.dart`, а не пишется руками: вкладка,
///    вынесенная на планшет завтра, попадает под правило сама.
///    Транзитивной безопасности здесь нет намеренно — её уже мерит
///    `browser_routes_test.dart` обходом всего замыкания от таблицы
///    маршрутов, и второй такой обход был бы не второй проверкой, а второй
///    копией первой.
/// 3. **Готовое значение доезжает, а молчание читается как «не знаю».**
///    Признак `FiscalDiagnosticsView.onLoopback` переживает оба конца
///    кодека провода, а кадр без ключа даёт `false`: назвать честный адрес
///    эмулятором хуже, чем промолчать.
///
/// # Чем сторож показанно краснеет
///
/// Диверсии проверены, а не объявлены (см. отчёт замера 2026-09-19):
/// возвращённая копия `_isLoopback` в `diagnostics_screen.dart` красит
/// случай 1 с именем файла и строки; `import 'dart:io';` в
/// `fiscal_diagnostics_tab.dart` красит случай 2; подмена
/// `'onLoopback': view.onLoopback` на `false` и разбор отсутствующего ключа
/// как `true` красят случай 3.
///
/// # Чего сторож НЕ проверяет
///
/// Что показанное значение **верно**: верность разбора адреса — дело
/// `isLoopbackHost` и его собственных проб. Здесь только о том, кто задаёт
/// вопрос и кто на него отвечает.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/domain/diagnostics/hardware_diagnostics.dart';
import 'package:telepos/domain/wire/till_ops.dart';

/// Единственное место, где разбирается «этот адрес ведёт в тот же самый
/// компьютер».
const _loopbackHome = 'lib/core/net/loopback.dart';

/// Перечисление собственных сетевых интерфейсов — **другой вопрос**, и
/// потому не нарушение.
///
/// `host_addresses.dart` спрашивает у `NetworkInterface`, какие из **своих**
/// адресов не петля, чтобы назвать кассу соседям. Это не «понять чужой
/// адрес», а «перебрать свои»: строки для разбора там нет вовсе, и свести
/// его к `isLoopbackHost` значило бы разобрать обратно в строку то, что уже
/// пришло объектом.
const _interfaceEnumeration = 'lib/data/transport/host_addresses.dart';

/// Экран планшета — по его импортам вычисляются общие вкладки.
const _terminalScreen =
    'lib/presentation/screens/diagnostics/terminal_diagnostics_screen.dart';

void main() {
  group('вопрос «это петля?» задаётся в одном месте (I170)', () {
    /// Все файлы `lib/`, кроме двух названных выше.
    List<File> sources() => Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) {
          final path = f.path.replaceAll(r'\', '/');
          return path != _loopbackHome && path != _interfaceEnumeration;
        })
        .toList();

    /// Строки кода — без докстрингов и комментариев. Правило про решения, а
    /// не про доводы: этот файл и сам называет `.isLoopback` в разборе.
    List<(String, int, String)> codeLines(File file) {
      final out = <(String, int, String)>[];
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final trimmed = lines[i].trimLeft();
        if (trimmed.startsWith('///') || trimmed.startsWith('//')) continue;
        out.add((file.path.replaceAll(r'\', '/'), i + 1, lines[i]));
      }
      return out;
    }

    test('обход не пуст — иначе сторож ничего не проверяет', () {
      expect(
        sources().length,
        greaterThan(300),
        reason:
            'дерево `lib/` прочитано почти пустым: сторож, не нашедший '
            'файлов, зеленеет на чём угодно',
      );
      expect(
        File(_loopbackHome).existsSync(),
        isTrue,
        reason: '$_loopbackHome переехал — сторож сторожит пустоту',
      );
    });

    test('никто, кроме loopback.dart, не спрашивает .isLoopback', () {
      final offenders = <String>[];
      for (final file in sources()) {
        for (final (path, line, text) in codeLines(file)) {
          if (text.contains('.isLoopback')) offenders.add('$path:$line');
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'вторая копия правила «это петля». Ответ один и живёт в '
            '$_loopbackHome (I170): второй разбор даёт второй ответ, и '
            'расходятся они молча — «плашка не зажглась» неотличимо от '
            'исправной кассы',
      );
    });

    test('никто, кроме loopback.dart, не сравнивает узел с «localhost»', () {
      // Именно **сравнение**, а не литерал: `'localhost'` законно живёт в
      // дереве значением — именем в сертификате и узлом по умолчанию у
      // сервера, — и запрет на литерал пришлось бы глушить списком.
      final decision = RegExp(r"""[=!]=\s*'localhost'|'localhost'\s*[=!]=""");
      final offenders = <String>[];
      for (final file in sources()) {
        for (final (path, line, text) in codeLines(file)) {
          if (decision.hasMatch(text)) offenders.add('$path:$line');
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'решение «это петля» принято сравнением со строкой мимо '
            '$_loopbackHome (I170)',
      );
    });
  });

  group('общая вкладка не берёт сырьё сама', () {
    /// Вкладки, которые стоят на обеих поверхностях, — по импортам экрана
    /// планшета, а не списком руками.
    List<String> sharedTabs() {
      final imports = RegExp(
        r"""^import\s+'package:telepos/(presentation/screens/diagnostics/[a-z_]+\.dart)'""",
      );
      final out = <String>[];
      for (final line in File(_terminalScreen).readAsLinesSync()) {
        final match = imports.firstMatch(line.trimLeft());
        if (match != null) out.add('lib/${match.group(1)!}');
      }
      return out;
    }

    test('общих вкладок найдено не меньше двух', () {
      expect(
        sharedTabs().length,
        greaterThanOrEqualTo(2),
        reason:
            'импорты $_terminalScreen прочитаны пустыми — сторож общих '
            'вкладок не нашёл и потому ничего не проверяет',
      );
    });

    test('ни одна общая вкладка не импортирует dart:io', () {
      final offenders = <String>[];
      for (final path in sharedTabs()) {
        final lines = File(path).readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i].trimLeft();
          if (line.startsWith('///') || line.startsWith('//')) continue;
          if (RegExp("""^import\\s+['"]dart:io['"]""").hasMatch(line)) {
            offenders.add('$path:${i + 1}');
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'общая вкладка разбирает сырьё сама. Всё, что требует `dart:io`, '
            'обязано считаться на кассе и ехать готовым значением (I170): в '
            'браузерной сборке этого пакета нет вовсе',
      );
    });
  });

  group('готовое значение переживает провод', () {
    test('признак «за адресом эмулятор» доезжает до вкладки', () {
      final json = fiscalDiagnosticsToWireJson(
        const FiscalDiagnosticsView(
          configured: true,
          accepted: [],
          queued: [],
          onLoopback: true,
        ),
      );
      expect(
        json['onLoopback'],
        isTrue,
        reason: 'касса посчитала признак и не положила его в кадр',
      );
      expect(fiscalDiagnosticsFromWireJson(json).onLoopback, isTrue);
    });

    test('признак «не эмулятор» доезжает тоже — а не теряется в умолчании', () {
      final json = fiscalDiagnosticsToWireJson(
        const FiscalDiagnosticsView(
          configured: true,
          accepted: [],
          queued: [],
        ),
      );
      expect(json['onLoopback'], isFalse);
      expect(fiscalDiagnosticsFromWireJson(json).onLoopback, isFalse);
    });

    test('касса промолчала — читается «не знаю», то есть false', () {
      // Кадр от кассы более старой сборки: ключа в нём нет вовсе.
      expect(
        fiscalDiagnosticsFromWireJson(const <String, Object?>{
          'configured': true,
          'accepted': <Object?>[],
          'queued': <Object?>[],
        }).onLoopback,
        isFalse,
        reason:
            'молчание кассы прочитано как «за адресом эмулятор». Назвать '
            'честный адрес подделкой хуже, чем промолчать',
      );
    });
  });
}
