/// **Один отказ провода — одна запись `AsyncError`, не две.**
///
/// Найдено живой проверкой в браузере (задача 22 закрытия долга
/// безопасности): примерно на каждом девятом открытии
/// страницы консоль несла ДВЕ подряд записи ERROR из `_probeOf`
/// (`initial_setup_controller.dart:369`) на один и тот же отказ подписки
/// `setup.state`, самоисправлявшиеся позже свежим значением.
///
/// Причина установлена здесь, без браузера и без QUIC: `_endedIsNotAnAnswer`
/// решает, было ли закрытие потока отказом, флагом `spoke`, который ставит
/// только `.map()` — а `.map()` не трогает событий ошибки вовсе (это
/// свойство `Stream`, а не этого файла). Поток, который открывающая сторона
/// закрывает СРАЗУ после единственной настоящей ошибки (ровно так и делает
/// `WtDispatcher._exchange` при неудавшемся `openStream()` —
/// `controller.addError(...); await controller.close();`), проходит здесь
/// как «закрылся, не сказав ничего», и получает ВТОРУЮ, синтетическую
/// ошибку поверх первой, настоящей. `_probeOf` реагирует на каждую запись
/// `AsyncError` отдельно (`ref.listen` в `InitialSetupNotifier.build()`) —
/// отсюда и двукратная запись.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/domain/startup/startup_state_repository.dart';
import 'package:telepos/domain/wire/setup_state.dart';
import 'package:telepos/presentation/controllers/startup/startup_state_provider.dart';

/// Воспроизводит РОВНО ту форму отказа, что и `WtDispatcher._exchange`,
/// когда `openStream()` не удаётся: одна ошибка, и тут же следом —
/// закрытие. Ни одного значения поток не отдаёт никогда.
class _FailsOnceThenCloses implements StartupStateRepository {
  int watchCalls = 0;

  @override
  Stream<SetupState> watch() {
    watchCalls++;
    final controller = StreamController<SetupState>();
    controller.addError(Exception('провод недоступен'));
    unawaited(controller.close());
    return controller.stream;
  }
}

/// Поток, что закрывается, не сказав вовсе ничего — ни значения, ни ошибки.
/// Контрольный случай: именно на нём `_endedIsNotAnAnswer` обязана
/// синтезировать ошибку — это исходное поведение, и правка не имеет права
/// его сломать.
class _ClosesWithoutAWord implements StartupStateRepository {
  @override
  Stream<SetupState> watch() {
    final controller = StreamController<SetupState>();
    unawaited(controller.close());
    return controller.stream;
  }
}

/// Поток, что отдаёт настоящее значение и на этом заканчивается. Второй
/// контрольный случай: закрытие ПОСЛЕ значения — не отказ, и правка не
/// имеет права начать считать его отказом.
class _AnswersOnceThenCloses implements StartupStateRepository {
  @override
  Stream<SetupState> watch() {
    final controller = StreamController<SetupState>();
    controller.add(const SetupState(configured: false, hasUsers: false));
    unawaited(controller.close());
    return controller.stream;
  }
}

void main() {
  tearDown(() async {
    await GetIt.I.reset();
  });

  test('один отказ подписки, закрывшейся сразу следом, — ровно одна запись '
      'AsyncError, не две', () async {
    GetIt.I.registerSingleton<StartupStateRepository>(_FailsOnceThenCloses());

    final container = ProviderContainer();
    addTearDown(container.dispose);

    final errors = <Object>[];
    container.listen<AsyncValue<SetupState>>(startupStateProvider, (_, next) {
      if (next.hasError) errors.add(next.error!);
    });

    // Даёт стриму провайдера домотать оба события (ошибку и `done`) —
    // оба уже поставлены в очередь синхронно при регистрации, но каждое
    // проходит свой микротаск через `StreamController`/`AsyncNotifier`.
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(
      errors.length,
      1,
      reason:
          'единственный настоящий отказ провода не имеет права стать '
          'двумя записями AsyncError — ровно так `_probeOf` в '
          '`InitialSetupNotifier` дважды пишет ERROR на одну причину. '
          'Увидено: $errors',
    );
  });

  test(
    'поток, закрывшийся не сказав вовсе ничего, — синтетическая ошибка '
    'сохраняется (контрольный случай, правка её не имеет права снять)',
    () async {
      GetIt.I.registerSingleton<StartupStateRepository>(_ClosesWithoutAWord());

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final errors = <Object>[];
      container.listen<AsyncValue<SetupState>>(startupStateProvider, (_, next) {
        if (next.hasError) errors.add(next.error!);
      });

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(
        errors.length,
        1,
        reason:
            'молчаливое закрытие — законный отказ («ответа не будет»), и он '
            'обязан остаться названным ровно одной ошибкой',
      );
    },
  );

  test('поток, отдавший значение и на этом закрывшийся, — отказа нет вовсе '
      '(контрольный случай)', () async {
    GetIt.I.registerSingleton<StartupStateRepository>(_AnswersOnceThenCloses());

    final container = ProviderContainer();
    addTearDown(container.dispose);

    final events = <AsyncValue<SetupState>>[];
    container.listen<AsyncValue<SetupState>>(startupStateProvider, (_, next) {
      events.add(next);
    });

    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(
      events.any((e) => e.hasError),
      isFalse,
      reason:
          'закрытие ПОСЛЕ настоящего значения — не отказ: значение уже '
          'сказано, дальше «новостей больше не будет», а не «неизвестно»',
    );
  });
}
