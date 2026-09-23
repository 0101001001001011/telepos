/// Блокер 1 финальной волны правок закрытия долга безопасности
/// (2026-08-22): `SessionsController` (`lib/presentation/controllers/settings/
/// sessions_controller.dart`) ловила `SessionLost` голым `catch` в
/// `revoke()` — экран `/sessions` показал бы красный снекбар «SessionLost»
/// вместо ухода на вход — и не обрабатывала отказ живой подписки в
/// `load()` вовсе (`.listen(...)` без `onError`): экран оставался бы в
/// вечной загрузке, а ошибка уходила бы необработанной в зону. Ни одного
/// теста на этот экран не было до этой правки — оба теста здесь красные без
/// неё.
///
/// `_SpyLoginNotifier` — тот же приём, что уже покрывает четыре других
/// экрана (`hardware_settings_screen_test.dart`,
/// `printer_settings_screen_session_lost_test.dart`,
/// `label_printer_settings_screen_session_lost_test.dart`,
/// `print_price_tag_dialog_session_lost_test.dart`): важно только то, что
/// контроллер **зовёт** `sessionLost()`, а не то, что делает сам нотифаер
/// внутри.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/domain/auth/live_session.dart';
import 'package:telepos/domain/auth/session_admin.dart';
import 'package:telepos/domain/wire/session_lost.dart';
import 'package:telepos/presentation/controllers/auth/login_controller.dart';
import 'package:telepos/presentation/controllers/settings/sessions_controller.dart';

class _SpyLoginNotifier extends LoginNotifier {
  int sessionLostCalls = 0;
  SessionLost? lastError;

  @override
  LoginState build() => const LoginState();

  @override
  void sessionLost(SessionLost error) {
    sessionLostCalls++;
    lastError = error;
  }
}

class _FakeSessionAdmin implements SessionAdmin {
  _FakeSessionAdmin({
    Stream<List<LiveSession>>? watchStream,
    this.throwOnRevoke,
  }) : _watchStream = watchStream ?? const Stream.empty();

  final Stream<List<LiveSession>> _watchStream;
  final Object? throwOnRevoke;

  @override
  Stream<List<LiveSession>> watchLiveSessions() => _watchStream;

  @override
  Future<bool> revokeSession(int terminalId) async {
    final error = throwOnRevoke;
    if (error != null) throw error;
    return true;
  }
}

const _sessionLost = SessionLost('auth.sessions: сеанс неизвестен или истёк');

void main() {
  tearDown(() => GetIt.instance.reset());

  test('revoke(): SessionLost гасит сеанс через LoginNotifier, а не оседает '
      'текстом в state.error', () async {
    GetIt.I.registerSingleton<SessionAdmin>(
      _FakeSessionAdmin(throwOnRevoke: _sessionLost),
    );
    final spy = _SpyLoginNotifier();
    final container = ProviderContainer(
      overrides: [loginControllerProvider.overrideWith(() => spy)],
    );
    addTearDown(container.dispose);

    final controller = container.read(sessionsControllerProvider.notifier);
    final result = await controller.revoke(1);

    expect(result, isFalse);
    expect(
      spy.sessionLostCalls,
      1,
      reason:
          'красный без правки: голый `catch (e)` заворачивал SessionLost '
          'в safeErrorText вместо гашения сеанса',
    );
    expect(spy.lastError, same(_sessionLost));
  });

  test('load(): отказ живой подписки SessionLost гасит сеанс, не оставляет '
      'экран в вечной загрузке', () async {
    final streamController = StreamController<List<LiveSession>>();
    addTearDown(streamController.close);
    GetIt.I.registerSingleton<SessionAdmin>(
      _FakeSessionAdmin(watchStream: streamController.stream),
    );
    final spy = _SpyLoginNotifier();
    final container = ProviderContainer(
      overrides: [loginControllerProvider.overrideWith(() => spy)],
    );
    addTearDown(container.dispose);

    final controller = container.read(sessionsControllerProvider.notifier);
    controller.load();
    streamController.addError(_sessionLost);
    await Future<void>.delayed(Duration.zero);

    expect(
      spy.sessionLostCalls,
      1,
      reason:
          'красный без правки: `.listen(...)` без onError не ловит отказ '
          'подписки вовсе — экран остаётся в загрузке навсегда, а ошибка '
          'уходит необработанной в зону',
    );
    expect(spy.lastError, same(_sessionLost));
  });
}
