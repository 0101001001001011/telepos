/// Мастер настройки не показывает хэш PIN на экране (задача 3, шаг 1).
///
/// `SqliteException.toString()` печатает `parametersToStatement` как есть для
/// любого текстового параметра (`package:sqlite3`, `lib/src/exception.dart`);
/// маскирует только `Uint8List`. `Users.password_enc` — текстовый столбец
/// (PBKDF2-строка из `PinCredential`), и `UPDATE users SET password_enc = ?`
/// — ровно та статья, что уходит при финализации настройки. До этой задачи
/// `InitialSetupNotifier.finishSetup()` подставляла пойманное исключение в
/// `state.error` через `'$e'`, то есть через `toString()`, — и хэш попадал
/// прямо на итоговый экран мастера, который видит оператор.
///
/// Двойник `SetupRepository` собран по образцу
/// `test/data/transport/till_wire_safe_error_test.dart` — настоящий класс,
/// бросающий настоящий `SqliteException` такой же формы, а не сфабрикованная
/// строка ошибки.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;
import 'package:telepos/core/constants/enums/country_code.dart';
import 'package:telepos/domain/setup/setup_repository.dart';
import 'package:telepos/domain/startup/startup_state_repository.dart';
import 'package:telepos/domain/wire/setup_state.dart';
import 'package:telepos/presentation/controllers/setup/initial_setup_controller.dart';

import '../../fixtures/pin_hash_fixture.dart';

class _LeakingSetupRepository implements SetupRepository {
  @override
  Future<void> completeSetup(SetupDraft draft) async {
    throw SqliteException(
      2067, // SQLITE_CONSTRAINT_UNIQUE
      'UNIQUE constraint failed: users.password_enc',
      'columns password_enc are not unique',
      'UPDATE users SET password_enc = ? WHERE id = ?',
      [testPbkdf2PinHash, 1],
      'executing a prepared statement',
    );
  }
}

/// Двойник `StartupStateRepository`, чей `watch()` бросает синхронно ту же
/// форму `SqliteException`, что и `_LeakingSetupRepository` выше — тем же
/// приёмом, что `test/data/transport/till_wire_safe_error_test.dart`.
///
/// Используется тестом `_checkInitialState`-пути ниже. **Важная оговорка,
/// найденная при написании этого теста** — см. докстрок у самого теста:
/// вопреки первому впечатлению («такой же сосед, как finishSetup»), этот
/// путь **не** проходит через `catch (e)` в `_checkInitialState`
/// (`initial_setup_controller.dart`, ключ `error.check_failed:`). Класс тем
/// не менее остаётся здесь: тест ниже проверяет реально достижимый путь
/// отказа чтения состояния кассы, а не воображаемый.
class _LeakingStartupStateRepository implements StartupStateRepository {
  @override
  Stream<SetupState> watch() {
    throw SqliteException(
      1, // SQLITE_ERROR
      'disk I/O error',
      'unable to read database header',
      'UPDATE users SET password_enc = ? WHERE id = ?',
      [testPbkdf2PinHash, 1],
      'executing a prepared statement',
    );
  }
}

class TestableInitialSetupNotifier extends InitialSetupNotifier {
  TestableInitialSetupNotifier(this._initialStep);

  final InitialSetupStep _initialStep;

  @override
  InitialSetupState build() {
    return InitialSetupState(currentStep: _initialStep);
  }
}

void main() {
  setUp(() {
    final getIt = GetIt.instance;
    if (getIt.isRegistered<SetupRepository>()) {
      getIt.unregister<SetupRepository>();
    }
    getIt.registerSingleton<SetupRepository>(_LeakingSetupRepository());
    if (getIt.isRegistered<StartupStateRepository>()) {
      getIt.unregister<StartupStateRepository>();
    }
    getIt.registerSingleton<StartupStateRepository>(
      _LeakingStartupStateRepository(),
    );
  });

  tearDown(() {
    GetIt.instance.reset();
  });

  test(
    'finishSetup: SqliteException с хэшем PIN в параметрах — хэш не '
    'попадает в state.error',
    () async {
      final container = ProviderContainer(
        overrides: [
          initialSetupControllerProvider.overrideWith(() {
            return TestableInitialSetupNotifier(
              InitialSetupStep.operatingModeSelection,
            );
          }),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(initialSetupControllerProvider.notifier);
      notifier
        ..selectCountry(CountryCode.kzt)
        ..updateOrganization(companyName: 'ЖШС «Тест»', taxId: '123456789012')
        ..updatePosConfig(cashBoxName: 'Касса 1')
        ..updateFirstUser(name: 'Админ', pin: '0000');

      await notifier.finishSetup();

      final state = container.read(initialSetupControllerProvider);

      expect(state.hasError, isTrue);
      expect(
        state.error,
        isNot(contains('pbkdf2')),
        reason: 'хэш PIN не должен покидать кассу ни в каком виде',
      );
      expect(
        state.error,
        isNot(contains(testPbkdf2PinHash)),
        reason: 'хэш PIN не должен покидать кассу ни в каком виде',
      );
      // Осмысленная часть по-прежнему видна — это не «ошибка исчезла»,
      // а «ошибка без параметров».
      expect(
        state.error,
        contains('UNIQUE constraint failed: users.password_enc'),
      );
    },
  );

  test(
    '_checkInitialState: касса не отвечает — хэш PIN, которым мог бы '
    'провалиться отказ чтения, не попадает в state.error ни в каком виде',
    () async {
      // Задача 6 волны правок просила «завести тест по образцу соседнего»
      // для `error.check_failed:${safeErrorText(e)}`
      // (`initial_setup_controller.dart`, `_checkInitialState`) — тем же
      // приёмом, что тест `finishSetup` выше.
      //
      // **Честно о том, что этот тест на самом деле проверяет.** Приём
      // «репозиторий бросает настоящий SqliteException с хэшем в
      // параметрах» здесь не воспроизводит тот же код-путь: у `finishSetup`
      // `completeSetup()` — прямой вызов внутри `try`, и его исключение
      // долетает до `catch (e)` без посредников. У `_checkInitialState`
      // единственное действие в `try`, которое может отказать, —
      // `ref.read(startupStateProvider)`, а `startupStateProvider` это
      // `StreamProvider` — и Riverpod ловит исключение из `watch()` (что
      // синхронное, что из потока) сам, превращая его в `AsyncValue.error`
      // ДО того, как оно дошло бы до `ref.read`. Значение уходит в
      // `_probeOf`, которая видит `answer.hasError` и возвращает
      // `_ConfigurationProbe.unreadable` — `catch (e)` в
      // `_checkInitialState` в этот момент не участвует вовсе.
      //
      // Проверено эмпирически (не логическим выводом): `ref.read(...)`
      // с этим же двойником не бросает — `catch` в
      // `_checkInitialState` не срабатывает, что видно по логу
      // (`_applyTillState: probe=unreadable`, а не `_checkInitialState
      // FAILED`). Это значит: `catch` на `initial_setup_controller.dart`
      // (ключ `error.check_failed:`) сегодня недостижим через отказ
      // чтения состояния кассы — единственный канал, которым туда мог бы
      // доехать `SqliteException` с хэшем. Дотянуться до него натурально,
      // не добавляя тестовый шов в рабочий код (`@visibleForTesting` на
      // приватном методе или его аналог), не удалось — а вносить такой шов
      // без отдельного решения показалось более рискованной правкой, чем
      // сама задача 6.
      //
      // Тест ниже проверяет то, что достижимо натурально — ровно ту же
      // гарантию («хэш PIN не покидает мастер настройки, чем бы касса ни
      // отказала при проверке состояния») через путь, которым отказ
      // действительно едет: `_probeOf` → `error.setup_state_unreadable`.
      // Этот путь безопасен по другой причине, чем `safeErrorText`, — код
      // ошибки там фиксированная строка, объект исключения в `state.error`
      // не попадает вовсе, — и именно поэтому этот тест зелёный
      // независимо от того, живёт ли `safeErrorText` на строке
      // `error.check_failed:` или нет: он **не** доказывает эту конкретную
      // строку, и не должен восприниматься как доказавший её.
      final container = ProviderContainer(
        overrides: [
          initialSetupControllerProvider.overrideWith(() {
            return TestableInitialSetupNotifier(InitialSetupStep.unreadable);
          }),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(initialSetupControllerProvider.notifier);
      await notifier.retryInitialCheck();
      // `_checkInitialState` ждёт `Future.delayed(300ms)` перед чтением —
      // время должно пройти по-настоящему, `pumpAndSettle` здесь нет
      // (нет `WidgetTester`).
      await Future.delayed(const Duration(milliseconds: 400));

      final state = container.read(initialSetupControllerProvider);

      expect(state.hasError, isTrue);
      expect(
        state.error,
        isNot(contains('pbkdf2')),
        reason: 'хэш PIN не должен покидать кассу ни в каком виде',
      );
      expect(
        state.error,
        isNot(contains(testPbkdf2PinHash)),
        reason: 'хэш PIN не должен покидать кассу ни в каком виде',
      );
      // Путь `_probeOf` не несёт текст исключения вовсе — код фиксированный.
      expect(state.error, equals('error.setup_state_unreadable'));
    },
  );
}
