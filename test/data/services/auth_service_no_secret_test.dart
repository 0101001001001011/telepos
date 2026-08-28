/// Токен устройства не уходит в `Talker` целиком (задача 3, шаг 2).
///
/// **Ставка неточная, поправлено волной правок фазы 1 (задача 7): не
/// сеть.** `Talker` в проде собран с файловым **и syslog**-наблюдателем, но
/// это не значит, что всё, долетевшее до `_observer.onException`/`.onError`,
/// уходит по сети. Измерено разбором: `file_log_observer.dart`'s
/// `_writeToFile` отдаёт в сток (`_sink?.submit(...)`, строка 123) **только**
/// `messagePart` — а `messagePart = message ?? error?.toString() ?? ''`
/// (строка 101), где `message` — это `err.displayMessage`, а он равен
/// `message ?? ''` из самого `TalkerData`
/// (`talker-5.1.13/lib/src/models/talker_data.dart:113-119`) — то есть
/// строка, которую вызывающий сам передал третьим параметром в `.handle()`/
/// `.error()`, а не производная от объекта исключения. Сам объект
/// исключения (`error`, второй параметр `.handle()`/`.error()`) в сток не
/// попадает **никогда** — он пишется только в **местный файл**
/// (`fileSink.writeln('  $error')`, строка 112), причём собственным
/// `.toString()`. До правки `AuthServiceImpl.authenticate()` звала
/// `_logger.handle(e, st, 'AuthService: failed to save authentication
/// data')` — фиксированный литерал сообщением и `e` отдельным объектом, а
/// не `'...: $e'` — так что даже тогда в сток уходил тот же безопасный
/// литерал, а не текст исключения; удар был в местный файл. Ставка была на
/// сеть, а канал утечки — местный файл; правка от этого не становится
/// лишней (местный файл читает журнал настроек, `И…` про наблюдаемость), но
/// обоснование ниже — верное.
/// `SqliteException.toString()` (`package:sqlite3`, `lib/src/exception.dart`)
/// печатает `parametersToStatement` как есть для текстовых параметров;
/// `ThisPosEntries.token` — текстовый столбец. `Talker` оборачивает `e` в
/// `TalkerException` как есть, и `generateTextMessage()` (которым читает сам
/// этот тест через `_CapturingObserver`, а не `file_log_observer.dart`)
/// печатает `exception.toString()` без всякой очистки — этим и ловится
/// утечка ниже, хотя в проде она реально достигала только местного файла.
///
/// Исключение здесь настоящее, не сфабрикованное — но не через `DROP
/// COLUMN`, как в `test/unit/data/this_pos_migration_test.dart`: та ошибка
/// («no such column») бьёт на этапе `PREPARE`, до связывания параметров, и
/// `parametersToStatement` у неё пуст — измерено при первой попытке написать
/// этот тест. Настоящая утечка параметров (`sqlite3/src/implementation/
/// statement.dart`, `_execute()` → `throwException(..., statementArgs:
/// _latestArguments)`) происходит на этапе выполнения, **после**
/// связывания. Поэтому здесь — триггер, который отказывает каждой попытке
/// записи уже во время `step()`: параметры к этому моменту связаны, и
/// значение токена оказывается в `SqliteException.parametersToStatement`
/// ровно как в проде при настоящем конфликте.
///
/// Точное значение токена — `'local-<миллисекунды>'`
/// (`AuthServiceImpl.authenticate`) — недоступно тесту заранее: оно строится
/// из `DateTime.now()` внутри метода. Утверждение поэтому ловит форму
/// значения (`local-` и не меньше 9 цифр), а не один жёстко вшитый литерал —
/// этого достаточно, чтобы поймать утечку, и не завязывает тест на
/// нестабильное время.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/services/auth_service_impl.dart';
import 'package:telepos/domain/services/auth_service.dart';

/// Форма значения, которое `authenticate()` кладёт в `token`:
/// `local-<millisecondsSinceEpoch>`. `\d{9,}` — заведомо меньше, чем любой
/// реальный `millisecondsSinceEpoch` (13 цифр), с запасом.
final _tokenShape = RegExp(r'local-\d{9,}');

class _CapturingObserver extends TalkerObserver {
  final List<String> captured = [];

  @override
  void onException(TalkerException err) {
    captured.add(err.generateTextMessage());
  }

  @override
  void onError(TalkerError err) {
    captured.add(err.generateTextMessage());
  }

  @override
  void onLog(TalkerData log) {
    captured.add(log.generateTextMessage());
  }
}

void main() {
  late AppDatabase db;
  late _CapturingObserver observer;
  late Talker logger;
  late AuthServiceImpl auth;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    // Триггер отказывает любой записи в таблицу уже на этапе выполнения
    // (после связывания параметров) — см. объяснение вверху файла про
    // разницу между отказом на PREPARE и отказом на STEP.
    await db.customStatement(
      'CREATE TRIGGER refuse_this_pos_write '
      'BEFORE INSERT ON ${db.thisPosEntries.actualTableName} '
      "BEGIN SELECT RAISE(ABORT, 'refused for test'); END",
    );

    observer = _CapturingObserver();
    logger = Talker(observer: observer);
    auth = AuthServiceImpl(db: db, logger: logger);
  });

  tearDown(() => db.close());

  test(
    'authenticate: SqliteException с токеном в параметрах — значение '
    'токена не долетает до Talker',
    () async {
      await expectLater(
        () => auth.authenticate('TELEPOS-TEST-0001'),
        throwsA(isA<AuthorizationFailed>()),
      );

      expect(
        observer.captured,
        isNotEmpty,
        reason: 'ожидали хотя бы одну запись — иначе проверка ниже пуста',
      );

      final combined = observer.captured.join('\n');
      expect(
        combined,
        contains('failed to save authentication data'),
        reason: 'осмысленная часть сообщения по-прежнему видна',
      );
      expect(
        _tokenShape.hasMatch(combined),
        isFalse,
        reason: 'токен устройства не должен уезжать в Talker (файл+syslog)',
      );
      // Задача 7 волны правок: тест утверждал отсутствие токена, но не
      // ключа — тот же INSERT/UPDATE пишет `key` и `token` одним
      // оператором (`ThisPosEntriesCompanion(key: ..., token: ...)`,
      // `AuthServiceImpl.authenticate`), и оба — параметры одного и того же
      // отказавшего `SqliteException`. `TELEPOS-TEST-0001` — тот же
      // столбец-удостоверение (`ThisPosEntries.key`), и ему тоже нечего
      // делать в Talker.
      expect(
        combined,
        isNot(contains('TELEPOS-TEST-0001')),
        reason: 'ключ устройства (тот же столбец-удостоверения, что и '
            'токен) не должен уезжать в Talker',
      );
    },
  );
}
