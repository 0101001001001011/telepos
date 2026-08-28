import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';

import 'package:telepos/backend/security_journal.dart';
import 'package:telepos/backend/session_registry.dart';
import 'package:telepos/core/errors/safe_error_text.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/presentation/controllers/app/app_state_controller.dart';

/// Настройки входа этой точки: `ThisPos.walkUpEnabled` и
/// `ThisPos.sessionIdleMinutes` (задача 18, закрытие И31).
///
/// До этой задачи оба значения читались (`local_auth_repository.dart`,
/// `service_locator.dart`), но менять их было нечем — `ThisPosDao
/// .saveAuthSettings` не звала ни одна строка `lib/`, только тест.
class AuthSettingsState {
  const AuthSettingsState({
    this.loading = true,
    this.walkUpEnabled = false,
    this.sessionIdleMinutes = 30,
    this.saving = false,
    this.error,
  });

  final bool loading;

  final bool walkUpEnabled;

  final int sessionIdleMinutes;

  final bool saving;

  final String? error;

  AuthSettingsState copyWith({
    bool? loading,
    bool? walkUpEnabled,
    int? sessionIdleMinutes,
    bool? saving,
    String? error,
  }) {
    return AuthSettingsState(
      loading: loading ?? this.loading,
      walkUpEnabled: walkUpEnabled ?? this.walkUpEnabled,
      sessionIdleMinutes: sessionIdleMinutes ?? this.sessionIdleMinutes,
      saving: saving ?? this.saving,
      error: error,
    );
  }
}

class AuthSettingsController extends Notifier<AuthSettingsState> {
  /// Наименьший срок сеанса, который экран разрешит записать. Ноль или
  /// отрицательное число здесь означало бы сеанс, истекающий раньше, чем
  /// успевает открыться, — не настройка, а поломка кассы через собственный
  /// экран настроек.
  static const minSessionIdleMinutes = 1;

  /// Наибольший — сутки. Ограничение не архитектурное, а от опечатки:
  /// без верхней границы поле принимает `99999999`, и `Duration` это
  /// проглотит молча.
  static const maxSessionIdleMinutes = 24 * 60;

  AppDatabase get _db => GetIt.I<AppDatabase>();

  @override
  AuthSettingsState build() => const AuthSettingsState();

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    final settings = await _db.thisPosDao.authSettings();
    state = AuthSettingsState(
      loading: false,
      walkUpEnabled: settings.walkUpEnabled,
      sessionIdleMinutes: settings.sessionIdleMinutes,
    );
  }

  /// Пишет решение сразу, без кнопки «Сохранить» — тот же довод, что и у
  /// `TerminalServiceSettingsScreen._apply`: кнопка была бы третьим
  /// состоянием, «переключил, но не сохранил».
  Future<void> setWalkUpEnabled(bool value) async {
    final previous = state;
    state = state.copyWith(walkUpEnabled: value, saving: true, error: null);
    try {
      await _db.thisPosDao.saveAuthSettings(walkUpEnabled: value);
    } catch (e) {
      // Пункт 7 брифа закрытия долга безопасности (2026-08-22): `e
      // .toString()` в состояние экрана, а не `safeErrorText` — тот же
      // разрыв, что уже чинили у остальных экранов. `SqliteException
      // .toString()` печатает `parameters: …`, и хотя сегодня этот запрос
      // ничего секретного не несёт, разрыв — в самом приёме, не в его
      // сегодняшней безобидности.
      state = previous.copyWith(error: safeErrorText(e));
      return;
    }
    state = state.copyWith(saving: false);
    unawaited(_recordSettingsChange('walkUp=$value'));
  }

  /// Пишет срок бездействия сеанса и применяет его немедленно к живому
  /// процессу — не только к следующему запуску.
  ///
  /// `SessionRegistry.idleTimeout` — синглтон get_it, тот же самый экземпляр,
  /// что решает срок жизни каждого выписываемого и продлеваемого сеанса
  /// (`mint`/`lookup`). Запись сюда сразу после успешного сохранения в базу —
  /// и есть применение «без перезапуска»: см. докстринг
  /// [SessionRegistry.idleTimeout].
  ///
  /// Возвращает `false`, не бросая исключение, когда `minutes` вне разумных
  /// границ — вызывающий экран показывает это как ошибку ввода, а не как сбой
  /// сохранения.
  Future<bool> setSessionIdleMinutes(int minutes) async {
    if (minutes < minSessionIdleMinutes || minutes > maxSessionIdleMinutes) {
      return false;
    }
    final previous = state;
    state = state.copyWith(
      sessionIdleMinutes: minutes,
      saving: true,
      error: null,
    );
    try {
      await _db.thisPosDao.saveAuthSettings(sessionIdleMinutes: minutes);
    } catch (e) {
      // Пункт 7 брифа закрытия долга безопасности (2026-08-22): тот же
      // разрыв, что и в `setWalkUpEnabled` выше — `safeErrorText`, не
      // `e.toString()`.
      state = previous.copyWith(error: safeErrorText(e));
      return false;
    }
    if (GetIt.I.isRegistered<SessionRegistry>()) {
      GetIt.I<SessionRegistry>().idleTimeout = Duration(minutes: minutes);
    }
    state = state.copyWith(saving: false);
    unawaited(_recordSettingsChange('sessionIdleMinutes=$minutes'));
    return true;
  }

  /// Пишет одну запись в журнал событий безопасности — пункт 7 брифа
  /// закрытия долга безопасности (2026-08-22): раздел 15 архитектуры
  /// называет «изменение настроек» точкой, обязанной оставлять след, и до
  /// этой правки `/auth-settings` (вход без называния себя, срок сеанса) не
  /// писал в журнал вовсе, хотя это ровно тот же периметр «кто и как
  /// входит», что и `/user-management` (докстринг `SessionAdmin`).
  ///
  /// `userId` — действующий, не субъект: у этой настройки нет отдельного
  /// субъекта (она не про конкретного кассира, а про кассу целиком), так
  /// что действующего есть куда положить без конфликта смыслов, в отличие
  /// от `_recordUserSecurityEvent` (`user_management_screen.dart`, пункт 4
  /// брифа) — там `userId` уже занят субъектом.
  Future<void> _recordSettingsChange(String outcome) async {
    if (!GetIt.I.isRegistered<SecurityJournal>()) return;
    try {
      final self = await _db.terminalDao.self();
      final actingUserId = ref.read(appStateProvider).userId;
      await GetIt.I<SecurityJournal>().record(
        eventType: SecurityEventType.authSettingsChanged,
        outcome: outcome,
        terminalId: self?.id ?? 0,
        userId: actingUserId,
      );
    } catch (error, stack) {
      if (GetIt.I.isRegistered<Talker>()) {
        GetIt.I<Talker>().warning(
          'журнал безопасности: запись "auth.settingsChanged" не удалась '
          '(${safeErrorText(error)}) — событие потеряно, операция не '
          'остановлена',
          null,
          stack,
        );
      }
    }
  }
}

final authSettingsControllerProvider =
    NotifierProvider<AuthSettingsController, AuthSettingsState>(
      AuthSettingsController.new,
    );
