import 'package:telepos/domain/terminal/terminal.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/domain/wire/till_ops.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';
import 'package:telepos/web/wt_channel.dart';
import 'package:telepos/web/wt_dispatcher.dart';

/// Терминалы кассы — по проводу.
///
/// # Два чтения из одной подписки
///
/// [watchAll] и [watchSelf] — подписки: появившийся терминал и переименование
/// доезжают в момент события. [list] и [self] берут **первое значение той же
/// подписки** и закрывают её. Второго пути к тем же данным здесь нет: это одна
/// операция, прочитанная один раз, а не второй запрос.
///
/// # Почему `self()` бросает, а `watchSelf()` отдаёт `null`
///
/// Это разные вопросы, и так же они разведены в самом договоре. [self]
/// спрашивают, чтобы действовать от имени терминала, и действовать от имени
/// несуществующего нельзя — отсюда [InstallationNotConfiguredException],
/// который бросает и локальный биндинг. За [watchSelf] следит экран, и «его
/// ещё нет» для него — состояние свежей установки, которое надо показать.
class WtTerminalRepository implements TerminalRepository {
  const WtTerminalRepository(this._wire);

  final WtDispatcher _wire;

  @override
  Stream<List<Terminal>> watchAll() => _wire.watch(TillOps.terminalsList, null);

  @override
  Future<List<Terminal>> list() => watchAll().first;

  @override
  Stream<Terminal?> watchSelf() => _wire.watch(TillOps.terminalSelf, null);

  /// Своя операция, а не первое значение [watchSelf], и это не отход от
  /// правила «одна реализация».
  ///
  /// [watchSelf] наблюдает и строки не заводит: наблюдение не имеет права
  /// менять то, за чем наблюдает, иначе открытая вкладка создавала бы терминал.
  /// [self] спрашивают, чтобы действовать от его имени, и он обязан
  /// существовать — ровно это делает и локальный биндинг, и делал
  /// `GET /api/terminals/self` до провода. Свести их к одному значило бы, что
  /// на свежей кассе браузер своего терминала не получит никогда.
  @override
  Future<Terminal> self() async =>
      // Явные доводы типа: без них вывод берёт `Res` из типа возврата метода
      // (`Terminal`), а операция отдаёт `Terminal?` — и сборка отказывает там,
      // где ошибки нет.
      await _wire.ask<void, Terminal?>(TillOps.terminalSelfEnsure, null) ??
      (throw const InstallationNotConfiguredException());

  /// Пункт 7 фазы 3/4 закрытия долга (2026-08-21): потолок в 200 терминалов
  /// (`LocalTerminalRepository.maxTerminals`) отвечает кодом
  /// `terminal_limit_reached` — по проводу это `WtProtocolError`, тот же
  /// код в `.code`, но другой тип, чем то, что бросает десктопный
  /// `LocalTerminalRepository.register()` напрямую (`WireRefusal`).
  /// `pairing_code_invalid` (задача 6 плана «знакомство терминала с кассой»,
  /// шаг 3 спеки — гейт `TillOperations.askHandlers[terminalRegister.name]`)
  /// переводится тем же приёмом рядом с ним: десктоп до этого кода никогда
  /// не доходит (он не проходит через этот метод — [self] вместо [register]),
  /// а браузер обязан отличить «код не подошёл» от прочих отказов провода тем
  /// же способом, что и потолок. Без перевода здесь `login_controller.dart`
  /// не смог бы поймать один и тот же смысл одним `catch` для обеих
  /// платформ — тем же приёмом, каким
  /// `WtAuthRepository.login()` переводит `unknown_terminal` в
  /// [UnknownTerminalException].
  @override
  Future<TerminalEnrollment> register({
    required String name,
    String code = '',
  }) async {
    try {
      return await _wire.ask(TillOps.terminalRegister, (
        name: name,
        code: code,
      ));
    } on WtProtocolError catch (error) {
      if (error.code == 'terminal_limit_reached' ||
          error.code == 'pairing_code_invalid') {
        throw WireRefusal(error.code, error.detail);
      }
      rethrow;
    }
  }

  /// Задача 5 плана «знакомство терминала с кассой», шаг 2 спеки. Тот же
  /// приём перевода, что у [register]: касса отвечает `terminal_secret_invalid`
  /// кадром отказа (`WtProtocolError` по проводу), и здесь он переводится в
  /// [WireRefusal] — тот же тип, которым десктопный `LocalTerminalRepository
  /// .resume()` бросает его напрямую. Без перевода `login_controller.dart`
  /// не смог бы поймать одну и ту же причину одним `catch` для обеих
  /// платформ.
  @override
  Future<Terminal> resume({
    required int terminalId,
    required String secret,
  }) async {
    try {
      return await _wire.ask(TillOps.terminalResume, (
        terminalId: terminalId,
        secret: secret,
      ));
    } on WtProtocolError catch (error) {
      if (error.code == 'terminal_secret_invalid') {
        throw WireRefusal(error.code, error.detail);
      }
      rethrow;
    }
  }

  // Ничего не ловит и не заворачивает — в том числе `SessionLost`
  // (`lib/domain/wire/session_lost.dart`), которым `WtDispatcher` отвечает на
  // истёкший сеанс: он и так доходит до вызывающего нетронутым.
  @override
  Future<void> rename(int terminalId, String name) =>
      _wire.ask(TillOps.terminalRename, (terminalId: terminalId, name: name));

  // Тот же приём, что у [rename]: `WireRefusal` (`unknown_terminal` от
  // `LocalTerminalRepository.delete`, `cannot_delete_self` от него же на
  // `isSelf` или от `TillOperations.askHandlers[terminals.delete]` на
  // терминале вызывающей вкладки — задача 9 закрытия долга), доходит до
  // вызывающего нетронутым — ловить и переводить здесь нечего.
  @override
  Future<void> delete(int terminalId) =>
      _wire.ask(TillOps.terminalDelete, terminalId);
}
