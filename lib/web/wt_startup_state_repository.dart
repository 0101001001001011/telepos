import 'package:telepos/domain/startup/startup_state_repository.dart';
import 'package:telepos/domain/wire/setup_state.dart';
import 'package:telepos/domain/wire/till_ops.dart';
import 'package:telepos/web/wt_dispatcher.dart';

/// Состояние установки — **подпиской**, а не вопросом.
///
/// Ровно та операция, ради которой менялся транспорт. По HTTP это был
/// `GET /api/setup/state`, задаваемый дважды за один экран, и пройденный на
/// кассе мастер настройки доезжал сюда при следующем вопросе, а не в момент,
/// когда его прошли.
///
/// Отказа здесь не ловится ни одного, и это сознательно: отказ подписки уезжает
/// ошибкой в тот же `Stream`, где вызывающий и так ждёт значения. Свернуть его
/// в «ничего не настроено» значило бы отправить оператора в мастер настройки
/// поверх работающей кассы — тот самый дефект, который уже закрывала пара
/// `setup_state.dart`.
class WtStartupStateRepository implements StartupStateRepository {
  const WtStartupStateRepository(this._wire);

  final WtDispatcher _wire;

  @override
  Stream<SetupState> watch() => _wire.watch(TillOps.setupState, null);
}
