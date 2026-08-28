import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/domain/startup/startup_state_repository.dart';
import 'package:telepos/domain/wire/setup_state.dart';
import 'package:telepos/presentation/controllers/setup/initial_setup_controller.dart';

/// "The till did not answer" must never be reported as "the till is empty".
///
/// Found live on 2026-08-02. The database failed to open, `/api/setup/state`
/// answered HTTP 500 with the body `Internal Server Error`, the browser client
/// could not parse that as JSON — and the catch around the probe returned
/// `false`, which the screen reads as *not configured*. It then offered the
/// first-run wizard to a shop with a full database behind it. Nothing was lost
/// only because nobody pressed the button.
///
/// The shape of the bug is the same one `PinCredential` was built to end:
/// a question that has three answers being squeezed into a `bool`, so the
/// unknown case silently borrows the meaning of a known one — and it borrows
/// the destructive one.
class _Unreachable implements StartupStateRepository {
  @override
  Stream<SetupState> watch() =>
      Stream.error(Exception('FormatException: Unexpected token I in JSON'));
}

class _ConfiguredTill implements StartupStateRepository {
  @override
  Stream<SetupState> watch() =>
      Stream.value(const SetupState(configured: true, hasUsers: true));
}

class _FreshTill implements StartupStateRepository {
  @override
  Stream<SetupState> watch() =>
      Stream.value(const SetupState(configured: false, hasUsers: false));
}

/// Подписка завелась и закрылась, не сказав ни слова.
///
/// Наследник `_HalfAnswering`: когда состояние спрашивалось двумя вопросами,
/// касса могла ответить на первый и сломаться на втором. Одним потоком та же
/// беда выглядит иначе — поток кончается без единого значения, — и она опаснее:
/// `Stream.first` на пустом потоке бросает `StateError`, который **не**
/// является `Exception` и мимо `on Exception` проходит насквозь. Ровно эта
/// форма отказа белила экран 2026-08-04.
class _SilentTill implements StartupStateRepository {
  @override
  Stream<SetupState> watch() => const Stream.empty();
}

Future<InitialSetupStep> _stepAfterCheck(StartupStateRepository repo) async {
  await GetIt.I.reset();
  GetIt.I.registerSingleton<StartupStateRepository>(repo);

  final container = ProviderContainer();

  // Слушатель обязателен, и это не украшение. В Riverpod 3 провайдер, которого
  // никто не слушает, **не получает обновлений от своих зависимостей**:
  // измерено 2026-08-05 отдельной пробой — подписка внутри `build()` отдавала
  // только `AsyncLoading` и молчала навсегда. Один `read` — это не то, как
  // мастером пользуется приложение: там его слушает экран.
  container.listen(initialSetupControllerProvider, (_, __) {});

  // Reading the notifier builds it, and `build()` starts its own check on a
  // microtask. That check must be allowed to finish *before* the container is
  // disposed: it ends by writing state, and writing state through a disposed
  // Ref throws. `_checkInitialState` opens with a 300 ms delay of its own, so
  // this waits past it rather than guessing at microtask ordering.
  container.read(initialSetupControllerProvider.notifier);

  // Wait for the answer, not for a duration. A fixed delay was flaky here —
  // `checking` is the state the probe *starts* in, so a wait that ends too
  // early reads "still thinking" and reports it as the verdict.
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (container.read(initialSetupControllerProvider).currentStep ==
      InitialSetupStep.checking) {
    if (DateTime.now().isAfter(deadline)) {
      fail('the configuration probe never finished');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }

  final step = container.read(initialSetupControllerProvider).currentStep;
  container.dispose();
  return step;
}

void main() {
  tearDown(() async {
    await GetIt.I.reset();
  });

  test('a till that cannot answer does NOT get the wizard', () async {
    final step = await _stepAfterCheck(_Unreachable());

    expect(
      step,
      InitialSetupStep.unreadable,
      reason: 'this is the defect: an unreadable till used to land on the '
          'first screen of the setup wizard',
    );
    expect(
      step,
      isNot(InitialSetupStep.countrySelection),
      reason: 'offering to set up a shop that may already exist is the one '
          'outcome this state was added to make impossible',
    );
  });

  test('подписка, закрывшаяся без единого значения, — тоже «неизвестно»', () async {
    final step = await _stepAfterCheck(_SilentTill());

    expect(
      step,
      InitialSetupStep.unreadable,
      reason: 'касса ничего не сказала — это меньше сведений, чем было, а не '
          'больше; и `StateError` из `first` не ловится `on Exception`',
    );
  });

  test('a genuinely fresh till still gets the wizard', () async {
    final step = await _stepAfterCheck(_FreshTill());

    expect(
      step,
      InitialSetupStep.countrySelection,
      reason: 'the fix must not block first-run setup, which is the whole '
          'purpose of this screen',
    );
  });

  test('a configured till still goes straight through', () async {
    final step = await _stepAfterCheck(_ConfiguredTill());

    expect(step, InitialSetupStep.complete);
  });
}
