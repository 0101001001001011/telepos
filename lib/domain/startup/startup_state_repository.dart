import 'package:telepos/domain/wire/setup_state.dart';

/// What the splash screen needs to decide where to send the operator.
///
/// The screen used to ask the database directly, which tied the first thing the
/// application draws to drift, `dart:io` and a native sqlite3 binary — none of
/// which exist in a browser.
///
/// # Почему один поток, а не два вопроса
///
/// Раньше здесь было `Future<bool> isConfigured()` и `Future<bool> hasUsers()`.
/// Состояние установки при этом одно, а спрашивалось оно дважды за один экран —
/// и по HTTP это были два запроса, между которыми состояние могло измениться:
/// «настроена, пользователей нет» отвечалось про две разные кассы во времени.
///
/// Хуже была вторая половина: ответ приходил только на вопрос. Пользователь,
/// заведённый на кассе, доезжал до браузерного терминала при следующем
/// вопросе, а не в момент, когда его завели. Ради этого и менялся транспорт
/// (`docs/internal/superpowers/specs/2026-08-04-webtransport-browser-terminal-design.md`),
/// поэтому договор — поток: первое значение текущее, дальнейшие приходят сами.
///
/// Вызывающему, которому нужно принять решение один раз (заставка выбирает
/// маршрут), достаточно `watch().first` — подписка при этом снимается. Это не
/// обход договора: одно значение из потока честно означает «сейчас», а
/// перезапрашивать его никто не обязан.
abstract interface class StartupStateRepository {
  /// Состояние установки сейчас и при каждом его изменении.
  Stream<SetupState> watch();
}
