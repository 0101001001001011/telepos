import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/core/errors/safe_error_text.dart';
import 'package:telepos/domain/auth/live_session.dart';
import 'package:telepos/domain/auth/session_admin.dart';
import 'package:telepos/domain/wire/session_lost.dart';
import 'package:telepos/presentation/controllers/auth/login_controller.dart';

/// Живые сеансы этой кассы — задача 19 закрытия долга безопасности.
/// `SessionRegistry.revokeAll()` существовал с задачи 9 и не звался ни
/// одной строкой рабочего кода (снят задачей 21) — этот экран зовёт
/// `revokeSession` (по одному терминалу) и есть недостающий вызывающий для
/// него.
///
/// # Через узкий порт `SessionAdmin`, не напрямую через `SessionRegistry`
///
/// Правка «второй порядок» закрытия долга безопасности (2026-08-22), пункт
/// 6: до неё контроллер держал `GetIt.I<SessionRegistry>()` напрямую, и
/// экран не мог достаться браузерной сборке — `lib/backend/` запрещён из UI
/// (`test/architecture/layering_test.dart`, `forbiddenFromUi`). `SessionAdmin`
/// — тот же узкий порт («смотреть и гасить», не весь реестр), которым уже
/// собран `till_operations.dart`; на кассе он биндится на тот же
/// `SessionRegistry` (`service_locator.dart`), в браузере — на
/// `WtSessionAdminRepository` (`main_web.dart`), которая зовёт те же две
/// операции провода (`TillOps.authSessions`/`authSessionRevoke`) — задача 19
/// завела их с готовым обработчиком на кассе, но без единого вызывающего в
/// `lib/`, пока браузерный экран (`/sessions` в `setup_router.dart`) не стал
/// вторым. Экран один и тот же на обеих платформах — `SessionsScreen` не
/// изменился ни строкой.
class SessionsState {
  const SessionsState({
    this.loading = true,
    this.sessions = const [],
    this.error,
    this.revokingTerminalId,
  });

  final bool loading;

  final List<LiveSession> sessions;

  final String? error;

  /// Терминал, чей отзыв сейчас в полёте — кнопка этой строки гасится, пока
  /// ответ не пришёл, чтобы двойной щелчок не отправил два отзыва подряд.
  final int? revokingTerminalId;

  SessionsState copyWith({
    bool? loading,
    List<LiveSession>? sessions,
    String? error,
    bool clearError = false,
    int? revokingTerminalId,
    bool clearRevoking = false,
  }) {
    return SessionsState(
      loading: loading ?? this.loading,
      sessions: sessions ?? this.sessions,
      error: clearError ? null : (error ?? this.error),
      revokingTerminalId: clearRevoking
          ? null
          : (revokingTerminalId ?? this.revokingTerminalId),
    );
  }
}

class SessionsController extends Notifier<SessionsState> {
  SessionAdmin get _registry => GetIt.I<SessionAdmin>();

  StreamSubscription<List<LiveSession>>? _subscription;

  @override
  SessionsState build() {
    ref.onDispose(() => _subscription?.cancel());
    return const SessionsState();
  }

  /// Подписывается на живой список — касса говорит первой: чужой вход и
  /// чужой отзыв (с другого экрана, с другой вкладки) доезжают сюда без
  /// перезахода на этот экран.
  void load() {
    _subscription?.cancel();
    state = state.copyWith(loading: true, clearError: true);
    _subscription = _registry.watchLiveSessions().listen(
      (sessions) {
        // Свежие сверху — то, что человек, открывший этот экран, скорее
        // всего ищет: кто вошёл только что.
        final sorted = [...sessions]
          ..sort((a, b) => b.issuedAt.compareTo(a.issuedAt));
        state = state.copyWith(loading: false, sessions: sorted);
      },
      // Блокер 1 финальной волны закрытия долга безопасности (2026-08-22):
      // до этой правки `.listen(...)` не имел `onError` вовсе — отказ
      // подписки (тот же `unauthorized` → SessionLost, что и у
      // `revoke()` ниже) не обрабатывался: экран оставался в вечной
      // загрузке, а ошибка уходила необработанной в зону. `SessionLost`
      // гасит сеанс тем же путём, каким его уже гасят пять экранов
      // настроек ([_handleSessionLost]) — остальное заворачивается в
      // `safeErrorText`, как и в `revoke()`.
      onError: (Object error, StackTrace _) {
        if (error is SessionLost) {
          _handleSessionLost(error);
          return;
        }
        state = state.copyWith(loading: false, error: safeErrorText(error));
      },
    );
  }

  /// Гасит сеанс терминала. `true` — было что гасить.
  Future<bool> revoke(int terminalId) async {
    state = state.copyWith(revokingTerminalId: terminalId, clearError: true);
    try {
      final revoked = await _registry.revokeSession(terminalId);
      state = state.copyWith(clearRevoking: true);
      return revoked;
    } on SessionLost catch (error) {
      // Блокер 1 финальной волны закрытия долга безопасности (2026-08-22):
      // до этой правки голый `catch (e)` ниже заворачивал `SessionLost` в
      // `safeErrorText` и показывал его текстом на экране `/sessions` —
      // тот же дефект, что четыре круга уже чинили на четырёх других
      // экранах настроек, но этот экран завёлся позже них и остался без
      // приёма. `_handleSessionLost` гасит сеанс тем же путём, каким его
      // уже гасят те четыре.
      _handleSessionLost(error);
      return false;
    } catch (e) {
      // Пункт 7 брифа закрытия долга безопасности (2026-08-22): `e
      // .toString()` в состояние экрана, тот же разрыв, что уже чинили —
      // `safeErrorText`, не текст исключения как есть.
      state = state.copyWith(clearRevoking: true, error: safeErrorText(e));
      return false;
    }
  }

  /// Единая реакция на `SessionLost`, пойманный любой операцией этого
  /// контроллера — задача, названная в п.1 брифа: приём был скопирован
  /// дословно в пяти экранах настроек и не переведён на шестой ('/sessions'),
  /// заведённый позже. У контроллера нет `BuildContext` (это `Notifier`, не
  /// виджет) — навигацию на `/login` берёт на себя тот же общий сторож
  /// (`routerProvider`'s `redirect`, `app_router.dart`), который уже уводит
  /// с любого экрана, как только `appStateProvider.isLoggedIn` становится
  /// `false`; `LoginNotifier.sessionLost` выставляет это состояние тем же
  /// путём, каким уже гасит его отозванный/истёкший сеанс.
  void _handleSessionLost(SessionLost error) {
    ref.read(loginControllerProvider.notifier).sessionLost(error);
  }
}

final sessionsControllerProvider =
    NotifierProvider<SessionsController, SessionsState>(SessionsController.new);
