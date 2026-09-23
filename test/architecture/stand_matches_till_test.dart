@Tags(['architecture'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Стенд живой проверки обязан собирать **ту же кассу**, что и приложение.
///
/// # Что случилось, из-за чего этот сторож появился
///
/// `ApiServer` принимает восемь необязательных сотрудников. Пропущенный
/// сотрудник — не падение и не пустой ответ: операция вежливо отказывает
/// названной причиной («нет службы»). Это верное поведение продукта и
/// одновременно ловушка для стенда: **обрезанная касса выглядит исправной**,
/// и заметить обрезку может только тот, кто позовёт операцию и прочитает
/// причину.
///
/// Стенд расходился с приложением уже трижды, и каждый раз это находил
/// человек, пришедший проверять что-то другое:
///
/// * 2026-08-22 — нет `sessionAdmin`: живая проверка отзыва сеансов мерила
///   отказ сборки стенда (`testing-notes.md`, задача 22);
/// * 2026-09-06 — нет `refund`: **шести операций возврата на стенде не
///   существовало вовсе**, и охранная правка задачи 19 была проверена
///   только набором;
/// * тогда же — нет `network` и `terminalSessions`: `network.*` отказывали
///   `no_network_module` вместо продуктового «демон не найден», а уборка
///   брошенных строк `terminals` не работала (чем и объясняется запись
///   2026-08-24 про стенд, копящий терминалы).
///
/// # Почему сторож смотрит в исходник, а не в поднятую кассу
///
/// Вторая половина защиты — `_assertStandIsWholeTill` в самом стенде: она
/// спрашивает **поднятую** кассу, чего у неё нет
/// (`TillOperations.absentCollaborators`), и не даёт стенду подняться
/// обрезанным. Но она слепа ровно там, где слеп любой список полей: новый
/// необязательный довод `ApiServer`, который забыли добавить и в
/// `absentCollaborators`, ей не виден.
///
/// Этот сторож закрывает вторую половину и смотрит **на текст, которым кассу
/// собирают**: множество имён доводов в `lib/main.dart` и в
/// `test/manual/wt_stand.dart` обязано совпадать с точностью до
/// [_justifiedDifferences]. Новый довод, названный в приложении и не
/// названный на стенде, красит эту проверку в тот же день, когда его
/// добавили, — а не через месяц, на живом прогоне, которого не будет.
///
/// # Почему сравниваются имена, а не значения
///
/// Значения расходятся законно и обязаны: у приложения `GetIt.I<…>`, у
/// стенда — собранный руками экземпляр над базой в памяти. Совпадать обязано
/// **решение**: про каждого сотрудника кассы стенд обязан сказать что-то
/// вслух, а не промолчать.
void main() {
  test('стенд собирает ApiServer теми же доводами, что и приложение', () {
    final till = _callArgumentNames('lib/main.dart', 'ApiServer');
    final stand = _callArgumentNames('test/manual/wt_stand.dart', 'ApiServer');

    // Сама выемка обязана что-то найти: пустое множество прошло бы проверку
    // молча, а именно так ломаются сторожа, читающие исходник.
    expect(
      till.length,
      greaterThan(15),
      reason:
          'в lib/main.dart найдено ${till.length} доводов ApiServer — '
          'разбор сломался, а не касса похудела',
    );

    final missingOnStand = till
        .difference(stand)
        .difference(_justifiedDifferences.keys.toSet());
    final extraOnStand = stand
        .difference(till)
        .difference(_justifiedDifferences.keys.toSet());

    expect(
      missingOnStand,
      isEmpty,
      reason:
          'приложение называет $missingOnStand, а стенд — нет. Эти операции '
          'на стенде отвечали бы «нет службы», и живая проверка мерила бы '
          'обрезок кассы. Собери их в test/manual/wt_stand.dart или, если '
          'на стенде их держать действительно нельзя, впиши довод в '
          '_justifiedDifferences здесь и в _standAbsentByDesign там.',
    );
    expect(
      extraOnStand,
      isEmpty,
      reason:
          'стенд называет $extraOnStand, а приложение — нет: стенд поднимает '
          'не то, что уедет заказчику',
    );

    // Оговорки не имеют права пережить свою причину: запись про довод,
    // который на самом деле называют оба, — это разрешение, выданное
    // навсегда и никем не перечитанное.
    for (final entry in _justifiedDifferences.entries) {
      final named = <String>[
        if (till.contains(entry.key)) 'приложение',
        if (stand.contains(entry.key)) 'стенд',
      ];
      expect(
        named.length,
        1,
        reason:
            'оговорка про «${entry.key}» (${entry.value}) устарела: довод '
            'называют ${named.isEmpty ? "ни один" : named.join(" и ")}',
      );
    }
  });

  // ── Сторож провода обязан быть собран целиком — и на кассе, и на стенде ──
  //
  // # Почему у этой проверки правило строже, чем у соседней
  //
  // Соседняя сверяет два вызова между собой: `ApiServer` принимает и доводы,
  // не имеющие отношения к защите (`port`, `publicHost`, `frontendDirectory`),
  // и требовать от обоих одинакового набора там нельзя.
  //
  // У `wireGuardForTill` доводов немного, и **каждый — сотрудник защиты**.
  // Пропущенный не ломает ни сборку, ни прогон: сторож просто перестаёт
  // делать одну из своих сверок и продолжает пропускать всё остальное. Поэтому
  // здесь сверяются не два вызова друг с другом, а **оба вызова с объявлением
  // функции**: назван обязан быть каждый параметр, включая необязательные.
  //
  // # Что это ловит — три разных беды одной проверкой
  //
  // 1. **Приложение перестало передавать довод.** Круг правки 3 задачи 19
  //    завёл `boundTerminalId` — сверку «место сеанса совпадает с местом
  //    сессии сейчас». Довод необязательный, `null` означает «сверка не
  //    делается». Разбор закомментировал эту единственную строку в
  //    `lib/main.dart` и прогнал `test/architecture/ test/backend/` —
  //    **282 passed, 0 failed**, `dart analyze` 0 error. То есть строку,
  //    которой охрана существует в продукте, можно было удалить молча.
  // 2. **Стенд отстал от приложения.** Ровно это и случилось на ветви
  //    возвратов: стенд зовёт сторожа под комментарием «то же, чем главная
  //    касса проверяет провод», и это перестало быть правдой в тот же день,
  //    когда довод появился в `main.dart`. Живая проверка на таком стенде
  //    мерила бы кассу **без** охранной правки — та самая ловушка «стенд
  //    мерил прошлогодний продукт».
  //
  //    **На этой ветви расхождения ещё нет и быть не может:** `2d8bab5` в
  //    неё не влит, у `wireGuardForTill` здесь три параметра, и оба вызова
  //    называют все три. Проверка написана не «на всякий случай»: слом
  //    показал, что она краснеет `Set:['boundTerminalId']`, как только этот
  //    параметр появляется в объявлении, — то есть **в момент слияния**, а
  //    не через месяц, на живом прогоне, которого не будет.
  // 3. **Новый сотрудник, которого не подключил никто.** Параметр, заведённый
  //    в `wireGuardForTill` и не переданный ни одним вызовом, красит проверку
  //    в тот же день.
  //
  // # Почему сверка с объявлением, а не список имён здесь
  //
  // Имя довода **изменится**: круг правки 4 задачи 19 идёт на соседней ветви и
  // правит ровно эту защиту. Проверка, знающая имя `boundTerminalId`, устарела
  // бы вместе с ним и покраснела бы не по делу. Объявление функции — истина,
  // которая переименовывается вместе с доводом, и сверка с ней переживает
  // переименование.
  test('и касса, и стенд зовут wireGuardForTill всеми его доводами', () {
    const declaring = 'lib/backend/till_wire_guard.dart';
    final declared = _namedParametersOf(declaring, 'wireGuardForTill');
    final till = _callArgumentNames('lib/main.dart', 'wireGuardForTill');
    final stand = _callArgumentNames(
      'test/manual/wt_stand.dart',
      'wireGuardForTill',
    );

    // Выемка обязана что-то найти: пустое объявление прошло бы проверку
    // молча — так ломаются сторожа, читающие исходник.
    expect(
      declared.length,
      greaterThanOrEqualTo(3),
      reason:
          'в $declaring найдено ${declared.length} параметров '
          'wireGuardForTill — разбор сломался, а не сторож похудел',
    );

    expect(
      declared.difference(till),
      isEmpty,
      reason:
          'wireGuardForTill объявляет ${declared.difference(till)}, а '
          'lib/main.dart их не передаёт. Необязательный довод сторожа — это '
          'не украшение: без него сторож молча перестаёт делать свою сверку '
          'и продолжает пропускать всё остальное. Настоящая касса обязана '
          'называть каждого.',
    );
    expect(
      declared.difference(stand),
      isEmpty,
      reason:
          'wireGuardForTill объявляет ${declared.difference(stand)}, а '
          'test/manual/wt_stand.dart их не передаёт: стенд поднимает сторожа '
          'слабее продуктового, и живая проверка мерила бы кассу без этой '
          'защиты — «стенд мерил прошлогодний продукт».',
    );

    // Обратная сторона: довод, которого в объявлении нет, а в вызове есть,
    // означает, что разбор читает не тот вызов. Молчать об этом нельзя —
    // сторож, читающий не то, зелен всегда.
    expect(
      till.difference(declared),
      isEmpty,
      reason:
          'lib/main.dart называет ${till.difference(declared)}, чего '
          'wireGuardForTill не объявляет — разбор читает не тот вызов',
    );
    expect(
      stand.difference(declared),
      isEmpty,
      reason:
          'стенд называет ${stand.difference(declared)}, чего '
          'wireGuardForTill не объявляет — разбор читает не тот вызов',
    );
  });

  // ── Сотрудники, собранные ВНУТРИ кассы, а не доводами ApiServer ──────────
  //
  // Приёмка 2026-09-17: возврат на стенде не давал фискального документа и
  // не печатал слип нового сертификата, а выпуск сертификата — слипа вовсе.
  // Проверка выше была зелёной: `ApiServer` получал `refund:` и
  // `certificates:` и там, и там. Обрезка сидела **внутри**: стенд собирал
  // `RefundUseCaseImpl(db, logger)` и `LocalCertificateIssuer(db, logger)`
  // без необязательных `tenders` и `slips`, которые касса передаёт
  // (`service_locator.dart`). `null` у них значит «нет», и молчит.
  //
  // Сверка — с объявлением конструктора, тем же приёмом, что у
  // `wireGuardForTill`: необязательный довод, забытый вызовом, выключает
  // работу молча.
  for (final (label, declaring, className, tillCall, standCall) in const [
    (
      'RefundUseCaseImpl',
      'lib/data/usecases/refund/refund_use_case_impl.dart',
      'RefundUseCaseImpl',
      '() => RefundUseCaseImpl',
      'refunds: RefundUseCaseImpl',
    ),
    // Приёмка 2026-09-17, вторая находка той же природы: у
    // `LocalRefundService` не было довода ящика вовсе, и возврат с наличной
    // частью ящика не открывал. Довод `drawer` заведён обязательным — забыть
    // его нельзя по сборке, — а сверка здесь стережёт соседний
    // необязательный `printer` и всё, что заведут после.
    (
      'LocalRefundService',
      'lib/data/refund/local_refund_service.dart',
      'LocalRefundService',
      '() => LocalRefundService',
      'final refund = LocalRefundService',
    ),
    (
      'LocalCertificateIssuer',
      'lib/data/payment/local_certificate_issuer.dart',
      'LocalCertificateIssuer',
      'LocalCertificateIssuer',
      'LocalCertificateIssuer',
    ),
  ]) {
    test('касса и стенд собирают $label всеми его доводами', () {
      final declared = _namedParametersOf(declaring, className);
      final till = _callArgumentNames(
        'lib/app/di/service_locator.dart',
        tillCall,
      );
      final stand = _callArgumentNames('test/manual/wt_stand.dart', standCall);

      expect(
        declared.length,
        greaterThanOrEqualTo(3),
        reason:
            'в $declaring найдено ${declared.length} параметров $className '
            '— разбор сломался',
      );
      expect(
        declared.difference(till),
        isEmpty,
        reason:
            'касса не передаёт $className ${declared.difference(till)} — '
            'необязательный довод выключает работу молча',
      );
      expect(
        declared.difference(stand),
        isEmpty,
        reason:
            'стенд не передаёт $className ${declared.difference(stand)}: '
            'живая проверка мерила бы обрезок кассы (приёмка 2026-09-17 — '
            'возврат без фискального документа и без слипа)',
      );
    });
  }

  // Печать на стенде — настоящая, и это проверяется здесь, потому что
  // обратное не падает и не краснеет: заглушка отвечает `accepted`, продажа
  // проходит, журнал стенда показывает «принтер позван». Ровно так оно и
  // жило до 2026-09-18, когда заказчик назвал это пробелом: «эмулятор
  // Принтера мы делали именно для этого».
  //
  // Сторож разрешительный — требует присутствия трёх вещей, а не отсутствия
  // подделки: запретительная форма («в стенде нет слова заглушка») обходится
  // переименованием и зелена по построению.
  test('стенд собирает печать теми же вызовами, что и касса', () {
    final stand = File('test/manual/wt_stand.dart').readAsStringSync();

    for (final (needle, why) in const [
      (
        'registerPrintQueue(',
        'очередь печати — та же функция DI, что у кассы: без неё сдача '
            'задания отвечает «очередь не настроена», и байтов не возникает',
      ),
      (
        'buildReceiptPrinterManager(',
        'драйвер принтера строится по привязке тем же построителем, что у '
            'кассы: свой `PrinterManager` снял бы с проверки `WifiPrinterManager`, '
            'кадры ESC/POS и опрос `DLE EOT` — то есть всё, ради чего написан '
            'эмулятор',
      ),
      (
        'inner: ReceiptPrintServiceImpl(',
        'журнал стенда стоит ПОВЕРХ настоящей службы чеков, а не вместо неё: '
            'без `inner` ширина ленты, шапка, подвал, кодовая страница и рез '
            'не проверяются ничем',
      ),
    ]) {
      expect(stand, contains(needle), reason: 'стенд не зовёт `$needle`: $why');
    }
  });

  // Проба «стенд регистрирует FiscalService в GetIt, раз возврат ищет её
  // там» жила здесь и **снята вместе со своей причиной**: `fiscal` стал
  // обязательным доводом `RefundUseCaseImpl`, поиска в `GetIt` больше нет, и
  // сверка доводов выше видит его сама — тем же чтением объявления
  // конструктора, что и остальных. Проба была написана так, чтобы покраснеть
  // в день, когда поиск исчезнет (`fail` с подсказкой), и покраснела.
  //
  // Повторять её обратной формой («в возврате нет `GetIt.I<`») нельзя по
  // доводу из докстринга `LocalPaymentService._fiscal`: исходно-сканирующий
  // запретительный сторож зелен по построению и обходится переименованием.
  // Здесь сторожит компилятор — `RefundUseCaseImpl(...)` без `fiscal:` не
  // собирается.
}

/// Доводы, которые названы только у одного из двух — и почему это верно.
///
/// Ключ — имя довода, значение — довод человеческими словами. Список
/// **закрытый**: пополнять его можно, но каждая запись читается как
/// «на стенде это не проверяется никогда», и стоить должна ровно столько.
const _justifiedDifferences = <String, String>{
  // Приложение слушает 8787 (умолчание `ApiServer.port`), стенду порт задают
  // переменной `TELEPOS_STAND_PORT`: две кассы на одной машине иначе не
  // поднять, а поднимать их одновременно — обычный ход проверки.
  'port': 'только стенд: порт задаётся переменной окружения',
  // Приложение обязано уметь отказать браузеру, когда бандла нет вовсе;
  // у стенда бандл — обязательное условие запуска (`TELEPOS_STAND_WEB`),
  // и рассказывать «почему его нет» было бы рассказом о невозможном.
  'frontendUnavailableReason':
      'только приложение: у стенда бандл обязателен, отсутствовать не может',
};

/// Имена именованных доводов единственного вызова `<callee>(...)` в файле.
///
/// Разбор скобочный, а не построчный: довод вида
/// `frontendDirectory: switch (bundle) { … }` занимает пять строк, и наивная
/// построчная выемка нашла бы внутри него `WebBundleFound()` и прочий шум.
Set<String> _callArgumentNames(String path, String callee) {
  final body = _parenthesisedBody(
    path: path,
    opener: '$callee(',
    what: 'вызова $callee',
  );

  final names = <String>{};
  final naming = RegExp(r'^\s*([A-Za-z_][A-Za-z0-9_]*)\s*:');
  for (final part in _splitTopLevel(body)) {
    final match = naming.firstMatch(part);
    if (match != null) names.add(match.group(1)!);
  }
  return names;
}

/// Имена именованных параметров, которые объявляет функция [functionName].
///
/// Читается **объявление**, а не вызов, и в этом весь смысл: список
/// сотрудников сторожа переименовывается вместе с ними, а проверка, знающая
/// имена наизусть, устарела бы на первом же переименовании (круг правки 4
/// задачи 19 идёт прямо сейчас и правит ровно эту защиту).
///
/// Из каждого параметра берётся **последний опознаватель до знака `=`**:
/// `required AppDatabase db` → `db`,
/// `int? Function(int sessionKey)? boundTerminalId` → `boundTerminalId`,
/// `Duration grace = const Duration(minutes: 5)` → `grace`. Имя внутри
/// сигнатуры типа (`sessionKey`) при этом не годится — оно живёт в скобках,
/// а разбор смотрит только на верхний уровень.
Set<String> _namedParametersOf(String path, String functionName) {
  final body = _parenthesisedBody(
    path: path,
    opener: '$functionName({',
    what: 'объявления $functionName',
  );

  final names = <String>{};
  // Последний опознаватель части — то есть её имя. Всё правее первого `=` —
  // значение по умолчанию, и опознаватели в нём чужие.
  final naming = RegExp(r'([A-Za-z_][A-Za-z0-9_]*)\s*$');
  for (final part in _splitTopLevel(_stripGenerics(body))) {
    final head = part.split('=').first.trim();
    final match = naming.firstMatch(head);
    if (match != null) names.add(match.group(1)!);
  }
  return names;
}

/// Текст между [opener] и парной ему закрывающей скобкой, без строк-комментариев.
///
/// Единственность вхождения проверяется здесь же: два вызова в одном файле
/// означали бы, что разбор читает наугад, — а сторож, читающий не то, зелен
/// всегда.
String _parenthesisedBody({
  required String path,
  required String opener,
  required String what,
}) {
  final source = File(path).readAsStringSync();
  final start = source.indexOf(opener);
  expect(start, isNot(-1), reason: 'в $path нет $what');
  expect(
    source.indexOf(opener, start + 1),
    -1,
    reason:
        'в $path вхождений «$opener» больше одного — разбор читал бы наугад, '
        'его надо уточнить',
  );

  final open = start + opener.length;
  // `opener` может сам содержать открывающие скобки (`f({`), и глубину надо
  // начинать с их числа, иначе поиск закроется на первой же `}`.
  var depth = opener.split('').where((c) => '([{'.contains(c)).length;
  var end = open;
  while (end < source.length && depth > 0) {
    final ch = source[end];
    if (ch == '(' || ch == '[' || ch == '{') {
      depth++;
    } else if (ch == ')' || ch == ']' || ch == '}') {
      depth--;
      if (depth == 0) break;
    }
    end++;
  }
  expect(depth, 0, reason: 'скобки $what в $path не закрылись');

  // Комментарии снимаются целыми строками: внутри них живут и запятые, и
  // двоеточия, и `http://` — то есть ровно то, за чем охотится разбор.
  return source
      .substring(open, end)
      .split('\n')
      .where((line) => !line.trimLeft().startsWith('//'))
      .join('\n');
}

/// Убирает параметры обобщённых типов: `Map<String, WireAccess> access` →
/// `Map access`.
///
/// Нужно **до** разбиения по запятым: запятая внутри `Map<String, X>` —
/// не разделитель параметров, и без этого шага `required Map<String`
/// прочиталось бы как параметр по имени `String`. Измерено первым же
/// прогоном этой проверки: она покраснела на `Set:['String']`.
///
/// Угловая скобка считается началом типа только тогда, когда стоит сразу
/// после опознавателя (`Map<`), — иначе под нож попали бы `=>` и сравнения.
String _stripGenerics(String source) {
  final out = StringBuffer();
  var depth = 0;
  for (var i = 0; i < source.length; i++) {
    final ch = source[i];
    final previous = i == 0 ? '' : source[i - 1];
    if (ch == '<' && RegExp(r'[A-Za-z0-9_?]').hasMatch(previous)) {
      depth++;
      continue;
    }
    if (ch == '>' && depth > 0) {
      depth--;
      continue;
    }
    if (depth == 0) out.write(ch);
  }
  return out.toString();
}

/// Части, разделённые запятыми **верхнего уровня**: вложенные скобки не
/// считаются, иначе `Duration(minutes: 5)` развалилось бы надвое.
List<String> _splitTopLevel(String body) {
  final parts = <String>[];
  var level = 0;
  final part = StringBuffer();
  for (final ch in body.split('')) {
    if (ch == '(' || ch == '[' || ch == '{') level++;
    if (ch == ')' || ch == ']' || ch == '}') level--;
    if (ch == ',' && level == 0) {
      parts.add(part.toString());
      part.clear();
    } else {
      part.write(ch);
    }
  }
  parts.add(part.toString());
  return parts;
}
