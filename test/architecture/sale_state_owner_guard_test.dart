@Tags(['architecture'])
library;

/// Сторож на правило смысла `Sales.terminalId` (задача 3 плана «продажа с
/// браузерного терминала», круг правки 2).
///
/// **Как нашлась дыра, которую этот сторож закрывает.** Круг правки 1 искал
/// по **форме вызова** — кто зовёт `SaleDao.updateState` — нашёл двоих
/// (`data_exchange_service.dart`, `merge_tables_use_case_impl.dart`) и
/// закрыл обоих, плюс заодно `markSyncedByKey`/`setState` в том же файле.
/// Переразбор нашёл третьего: `SaleUseCaseImpl.perform` (`completeSale()`,
/// самый частый переход состояния во всей системе — каждая оплата) писал
/// `Sales.state` **напрямую**, минуя `updateState` вовсе — форма поиска не
/// могла его найти в принципе, потому что он не проходит через
/// проверенный метод. Тот же класс ошибки, которым в этом проекте уже
/// обжигались на проводе: сторож сырой интерполяции исключения стерёг
/// конструкторы кадров по имени, пропустил состояние экрана, пришлось
/// переписывать на признак назначения (`no_raw_exception_on_wire_test.dart`,
/// круг 4) — там смена признака нашла 27 мест в 13 файлах.
///
/// **Признак — назначение, не форма.** Не «кто зовёт `updateState`», а
/// «где угодно в `lib/` в `Sales` пишется `state`, в любой форме» —
/// `SalesCompanion(...)`, `SalesCompanion.insert(...)`, сырой SQL. Правило
/// смысла (докстринг `Sales.terminalId`, `sale_tables.dart`; докстринг
/// `SaleDao.updateState`): владельца имеет только чек в работе
/// (`state = 0`). Каждая запись `state` обязана явно решить, что делать с
/// `terminalId` в той же записи — не молчаливо совпасть с умолчанием
/// колонки (ровно так молчаливое умолчание уже один раз спрятало дыру:
/// `SaleUseCaseImpl.perform` работал «случайно правильно» ровно до
/// круга правки 2, когда стало явно, что он вообще не принимал решения).
///
/// **Круг правки 2 задачи 4 (2026-09-06): атомарность закрыла гонку, но не
/// неполноту строки.** `ReceiptNumbers.withNext(writeSale)` защищает от
/// двух вызывающих, получивших один номер, — но ничего не мешает
/// замыканию `writeSale` вставить строку **без довода `state:` вовсе**.
/// `state` объявлена допускающей пустоту, а правила 1–2 выше проверяют
/// только «раз пишешь state — реши судьбу владельца»; вставку без state
/// они не видят в принципе, потому что она никогда не попадает в их
/// выборку `stateWritesFound`. Ровно это воспроизвело бы исходную находку
/// круга 1 (строка без состояния, которую «Печать последнего чека» находит
/// как настоящий последний чек) — только не через двухшаговую бронь, а
/// через один вызывающий, который просто не подумал о `state`. Первый
/// названный будущий вызывающий — `CartService.start` (задача 7,
/// докстринг `ReceiptNumbers`). Правила 3–4 закрывают это отдельно:
/// **любая вставка в `Sales` обязана нести `state:` явно**, а не только
/// «если несёт state — то полностью».
///
/// **Круг правки 3 задачи 4 (2026-09-06): сторож пропускал форму и врал о
/// себе.** Правило 3 ловит только текст `SalesCompanion.insert(` —
/// именованный конструктор литералом на месте. Но в дереве живёт путь мимо
/// него: `SaleMapper.toDrift(entity)` строит `SalesCompanion(...)` **обычным**
/// конструктором (`sale_mapper.dart:33`) и возвращает его; `SaleRepositoryImpl
/// .insert()` (`sale_repository_impl.dart:57-58`) кладёт результат в
/// переменную и вставляет её — `_db.into(_db.sales).insert(companion)`.
/// Прежняя версия раздела «Честно о пределе» ниже утверждала, что такой
/// формы в дереве нет, и это «проверено при написании» — утверждение было
/// неверным сразу на двух живых строках; сторож, ошибающийся о собственных
/// границах, опаснее сторожа, у которого границы просто есть (тот же класс
/// урока, что дал круги 1–2 этой же задачи: пятое повторение находки
/// «сторож ловит по форме вызова, а не по признаку» за одну задачу).
///
/// Правка не гонится за именем вызывающего или числом файлов между
/// конструктором и вставкой (это и есть след формы, а не признака) — она
/// смотрит на **сам конструктор**: `SalesCompanion(...)` обычной формы,
/// несущий явно все пять обязательных без `NULL` колонок таблицы
/// (`receiptNo`, `posId`, `userId`, `amount`, `time` — `sale_tables.dart`),
/// не может быть частичным обновлением существующей строки (ни одно
/// легитимное обновление в этом дереве не переобъявляет все пять сразу —
/// `SaleDao.setAmount`/`setSaleId`/`updateState` и подобные трогают одну-две
/// колонки, `SaleUseCaseImpl.perform` — семь, но не эту пятёрку целиком).
/// Значит такой конструктор **строит новую строку**, кем бы он ни был
/// вызван и через сколько бы переменных ни прошёл до `.insert(...)` — и
/// обязан решить `state`, тем же правилом, что и правило 3.
///
/// **Что проверяется:**
/// 1. Любой вызов `SalesCompanion(...)`/`SalesCompanion.insert(...)` во всём
///    `lib/`, несущий довод `state:`, обязан нести и довод `terminalId:` —
///    неважно, каким значением (`Value(...)`, `Value(null)`,
///    `Value.absent()` через тернарник, лишь бы решение было видно в
///    тексте самой записи).
/// 2. Любая строка сырого SQL, пишущая в `sales` (`INSERT ... INTO sales`,
///    `UPDATE sales SET ...`) со словом `state` в списке колонок/`SET`,
///    обязана нести и `terminal_id` в том же списке.
/// 3. Любой вызов `SalesCompanion.insert(...)` — то есть каждая вставка
///    новой строки литералом на месте — обязан нести довод `state:` явно.
/// 4. Любая строка сырого SQL `INSERT ... INTO sales` обязана нести
///    `state` в списке колонок — тот же смысл, что правило 3, для другой
///    формы записи.
/// 5. Любой вызов `SalesCompanion(...)` обычным конструктором, несущий
///    явно все пять обязательных колонок (`receiptNo`, `posId`, `userId`,
///    `amount`, `time`) — то есть строящий новую строку, а не частично
///    обновляющий существующую, — обязан нести и `state:`, тем же смыслом,
///    что правило 3, но по признаку конструкции, а не по имени метода.
///    Легитимные частичные обновления (`SaleDao.setAmount`, `setSaleId`,
///    `updateState`, `SaleUseCaseImpl.perform` и подобные) этим правилом не
///    задеты — ни одно не несёт всю пятёрку разом.
///
/// **Честно о пределе.** Проверка текстовая, не типовая: не различает,
/// правильное ли значение `terminalId`/`state` выбрано, — только что
/// решение вообще принято и видно в тексте. Правило 5 не следит за
/// потоком данных (не проверяет, что именно передаётся в `.insert(...)`
/// в итоге, и не находит `companion`, если он собран не литералом на
/// месте, а, скажем, через `..copyWith`/спред полей без текстового имени
/// колонки) — оно решает вопрос иначе: смотрит только на сам конструктор
/// и его собственный список доводов, поэтому ему не нужно знать, где
/// вставка произойдёт и произойдёт ли вообще текстом `.insert(`. Предел,
/// который остаётся честным: конструктор, собирающий все пять обязательных
/// колонок **не в одном текстовом вызове** (например, через builder,
/// который дописывает часть полей отдельными присваиваниями до финальной
/// сборки `SalesCompanion`), этим правилом не увидится — по всему дереву
/// сегодня такой формы нет (проверено тем же обходом, которым найдена
/// сама правка), но появись она — сторож её не увидит, как сторож провода
/// не видит `ErrorFrame(code, myOwnUnsafeFormat(e))`.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Извлекает текст каждого вызова, совпавшего с [pattern] (обязан
/// оканчиваться на `\(`), целиком — от начала совпадения до соответствующей
/// закрывающей скобки, считая вложенность. Тот же приём, что
/// `no_raw_exception_on_wire_test.dart`.
List<String> _callsMatching(String source, RegExp pattern) {
  final calls = <String>[];
  for (final match in pattern.allMatches(source)) {
    var depth = 1;
    var i = match.end;
    while (i < source.length && depth > 0) {
      if (source[i] == '(') depth++;
      if (source[i] == ')') depth--;
      i++;
    }
    calls.add(source.substring(match.start, i));
  }
  return calls;
}

List<File> _dartFilesUnder(String dir) {
  return Directory(dir)
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'))
      .toList();
}

final _salesCompanionPattern = RegExp(r'\bSalesCompanion(\.insert)?\(');
final _salesInsertPattern = RegExp(r'\bSalesCompanion\.insert\(');
/// Обычный конструктор — намеренно не `.insert`: то, что регекс `(\.insert)?`
/// в [_salesCompanionPattern] делает необязательным, здесь обязано
/// отсутствовать, иначе `SalesCompanion.insert(...)` совпал бы дважды под
/// разными именами и не нёс бы отдельного смысла для правила 5 (см. докстринг
/// файла, круг правки 3: путь через `SaleMapper.toDrift`).
final _bareSalesCompanionPattern = RegExp(r'\bSalesCompanion\(');
final _stateArgPattern = RegExp(r'\bstate\s*:');
final _terminalIdArgPattern = RegExp(r'\bterminalId\s*:');
final _receiptNoArgPattern = RegExp(r'\breceiptNo\s*:');
final _posIdArgPattern = RegExp(r'\bposId\s*:');
final _userIdArgPattern = RegExp(r'\buserId\s*:');
final _amountArgPattern = RegExp(r'\bamount\s*:');
final _timeArgPattern = RegExp(r'\btime\s*:');

/// Признак «этот вызов строит новую строку `Sales`» для правила 5: несёт
/// явно все пять колонок, объявленных без `NULL` и без умолчания
/// (`sale_tables.dart`). Ни одно легитимное частичное обновление в этом
/// дереве не переобъявляет их все разом — проверено обходом при написании
/// (см. докстринг файла).
bool _looksLikeFullSalesRow(String call) =>
    _receiptNoArgPattern.hasMatch(call) &&
    _posIdArgPattern.hasMatch(call) &&
    _userIdArgPattern.hasMatch(call) &&
    _amountArgPattern.hasMatch(call) &&
    _timeArgPattern.hasMatch(call);

/// Сырой SQL, пишущий в `sales`: `INSERT [OR ...] INTO sales` или
/// `UPDATE sales SET`. Дальше берётся окно текста после совпадения (сама
/// строка `customStatement` в этом дереве не длиннее пары сотен символов —
/// 800 с большим запасом) и в нём ищутся `state`/`terminal_id` как имена
/// колонок, а не через баланс скобок: у сырого SQL нет единой пары скобок
/// вызова, список колонок и `VALUES (...)` — разные скобочные группы.
final _rawSalesWritePattern = RegExp(
  r'(INSERT[^;]*?INTO\s+sales\b|UPDATE\s+sales\s+SET)',
  caseSensitive: false,
);
/// Только вставки — подмножество [_rawSalesWritePattern] без `UPDATE`, для
/// правила 4 (вставка обязана нести `state`, обновление — не обязано).
final _rawSalesInsertPattern = RegExp(
  r'INSERT[^;]*?INTO\s+sales\b',
  caseSensitive: false,
);
final _rawStateColumnPattern = RegExp(r'\bstate\b', caseSensitive: false);
final _rawTerminalIdColumnPattern = RegExp(
  r'\bterminal_id\b',
  caseSensitive: false,
);

void main() {
  final files = _dartFilesUnder('lib');

  test(
    'обход lib/ не пуст (страховка от вырожденного результата листинга)',
    () {
      expect(files.length, greaterThan(100));
    },
  );

  test(
    'SalesCompanion(...): запись state несёт решение по terminalId',
    () {
      final offenders = <String>[];
      var stateWritesFound = 0;

      for (final file in files) {
        final source = file.readAsStringSync();
        final calls = _callsMatching(source, _salesCompanionPattern);
        for (final call in calls) {
          if (!_stateArgPattern.hasMatch(call)) continue;
          stateWritesFound++;
          if (!_terminalIdArgPattern.hasMatch(call)) {
            offenders.add(
              '${file.path}: '
              '${call.replaceAll(RegExp(r'\s+'), ' ').trim()}',
            );
          }
        }
      }

      // Страховка: ноль найденных записей state — не «всё чисто», а
      // сломанный обход (переименование SalesCompanion, рефакторинг DAO).
      expect(
        stateWritesFound,
        greaterThan(0),
        reason:
            'ни одной записи state через SalesCompanion не нашлось во всём '
            'lib/ — сам сторож сломан (переименование? рефакторинг, '
            'унёсший все вызовы?)',
      );

      expect(
        offenders,
        isEmpty,
        reason:
            'запись Sales.state не решает, что делать с владельцем '
            '(terminalId) — ровно так осталась незамеченной '
            'SaleUseCaseImpl.perform (completeSale, круг правки 2 задачи 3). '
            'Правило: владельца имеет только state = 0 — любой другой '
            'переход обязан нести terminalId явно (обычно const Value(null)); '
            'переход в 0 — тоже явно, тем, кто поднимает чек. '
            'Нашедшиеся места:\n${offenders.join('\n')}',
      );
    },
  );

  test(
    'сырой SQL в sales: запись state несёт terminal_id в том же списке',
    () {
      final offenders = <String>[];
      var rawWritesFound = 0;

      for (final file in files) {
        final source = file.readAsStringSync();
        for (final match in _rawSalesWritePattern.allMatches(source)) {
          final windowEnd = (match.start + 800).clamp(0, source.length);
          final window = source.substring(match.start, windowEnd);
          if (!_rawStateColumnPattern.hasMatch(window)) continue;
          rawWritesFound++;
          if (!_rawTerminalIdColumnPattern.hasMatch(window)) {
            offenders.add(
              '${file.path}: '
              '${window.replaceAll(RegExp(r'\s+'), ' ').trim().substring(0, 160)}…',
            );
          }
        }
      }

      expect(
        rawWritesFound,
        greaterThan(0),
        reason:
            'ни одной сырой записи state в sales не нашлось во всём lib/ — '
            'сам сторож сломан (переименование таблицы? весь код перешёл '
            'на SalesCompanion?)',
      );

      expect(
        offenders,
        isEmpty,
        reason:
            'сырой SQL пишет Sales.state, не упоминая terminal_id в том же '
            'списке колонок — то же правило, что у SalesCompanion(...), '
            'через другую форму записи. Нашедшиеся места:\n'
            '${offenders.join('\n')}',
      );
    },
  );

  test(
    'SalesCompanion.insert(...): каждая вставка несёт state явно '
    '(круг правки 2 задачи 4)',
    () {
      final offenders = <String>[];
      var insertsFound = 0;

      for (final file in files) {
        final source = file.readAsStringSync();
        final calls = _callsMatching(source, _salesInsertPattern);
        for (final call in calls) {
          insertsFound++;
          if (!_stateArgPattern.hasMatch(call)) {
            offenders.add(
              '${file.path}: '
              '${call.replaceAll(RegExp(r'\s+'), ' ').trim()}',
            );
          }
        }
      }

      // Страховка: та же логика, что у правила 1 — ноль найденных вставок
      // не «всё чисто», а сломанный обход.
      expect(
        insertsFound,
        greaterThan(0),
        reason:
            'ни одной вставки SalesCompanion.insert не нашлось во всём '
            'lib/ — сам сторож сломан (переименование? рефакторинг, '
            'унёсший все вызовы?)',
      );

      expect(
        offenders,
        isEmpty,
        reason:
            'вставка новой строки Sales не несёт state вовсе — ровно так '
            'воспроизвелась бы находка круга правки 1 (строка без '
            'состояния, которую «Печать последнего чека» находит как '
            'настоящий последний чек), только без промежуточного шага '
            '«бронь, потом дозаполнение»: один вызывающий, который просто '
            'не подумал о state. Правило: КАЖДАЯ вставка обязана решить '
            'state явно (правила 1–2 выше — только «если решаешь state, '
            'то полностью»; это правило — «решай state вообще»). '
            'Нашедшиеся места:\n${offenders.join('\n')}',
      );
    },
  );

  test(
    'сырой SQL: INSERT INTO sales несёт state в списке колонок '
    '(круг правки 2 задачи 4)',
    () {
      final offenders = <String>[];
      var rawInsertsFound = 0;

      for (final file in files) {
        final source = file.readAsStringSync();
        for (final match in _rawSalesInsertPattern.allMatches(source)) {
          rawInsertsFound++;
          final windowEnd = (match.start + 800).clamp(0, source.length);
          final window = source.substring(match.start, windowEnd);
          if (!_rawStateColumnPattern.hasMatch(window)) {
            offenders.add(
              '${file.path}: '
              '${window.replaceAll(RegExp(r'\s+'), ' ').trim().substring(0, 160)}…',
            );
          }
        }
      }

      expect(
        rawInsertsFound,
        greaterThan(0),
        reason:
            'ни одной сырой вставки в sales не нашлось во всём lib/ — сам '
            'сторож сломан (переименование таблицы? весь код перешёл на '
            'SalesCompanion?)',
      );

      expect(
        offenders,
        isEmpty,
        reason:
            'сырая вставка в sales не несёт state в списке колонок — то же '
            'правило, что у SalesCompanion.insert(...), через другую форму '
            'записи. Нашедшиеся места:\n${offenders.join('\n')}',
      );
    },
  );

  test(
    'SalesCompanion(...) обычным конструктором: несущий все обязательные '
    'колонки новой строки обязан нести и state (круг правки 3 задачи 4)',
    () {
      final offenders = <String>[];
      var fullRowConstructionsFound = 0;

      for (final file in files) {
        final source = file.readAsStringSync();
        final calls = _callsMatching(source, _bareSalesCompanionPattern);
        for (final call in calls) {
          if (!_looksLikeFullSalesRow(call)) continue;
          fullRowConstructionsFound++;
          if (!_stateArgPattern.hasMatch(call)) {
            offenders.add(
              '${file.path}: '
              '${call.replaceAll(RegExp(r'\s+'), ' ').trim()}',
            );
          }
        }
      }

      // Страховка: находка круга правки 3 — SaleMapper.toDrift — обязана
      // остаться найденной. Ноль здесь значит, что признак (все пять
      // обязательных колонок) сломан, а не что вставок такой формы нет.
      expect(
        fullRowConstructionsFound,
        greaterThan(0),
        reason:
            'ни одного конструктора SalesCompanion(...), несущего все пять '
            'обязательных колонок, не нашлось во всём lib/ — либо '
            'SaleMapper.toDrift переписан не в эту форму, либо признак '
            '(receiptNo+posId+userId+amount+time) сломан.',
      );

      expect(
        offenders,
        isEmpty,
        reason:
            'SalesCompanion(...) строит новую строку Sales (несёт все пять '
            'обязательных колонок — receiptNo, posId, userId, amount, '
            'time), но не решает state. Ровно так эта дыра осталась '
            'незамеченной правилом 3: SaleMapper.toDrift строит компаньон '
            'обычным конструктором (не `.insert`), а SaleRepositoryImpl '
            '.insert() вставляет его через промежуточную переменную — '
            'правило 3 ловит только литерал `SalesCompanion.insert(`, эту '
            'форму не видит вовсе. Нашедшиеся места:\n'
            '${offenders.join('\n')}',
      );
    },
  );
}
