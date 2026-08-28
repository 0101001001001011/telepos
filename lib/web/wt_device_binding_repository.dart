import 'package:telepos/domain/terminal/device_binding.dart';
import 'package:telepos/domain/terminal/device_binding_repository.dart';
import 'package:telepos/domain/wire/till_ops.dart';
import 'package:telepos/web/wt_channel.dart';
import 'package:telepos/web/wt_dispatcher.dart';

/// Устройства терминала — по проводу.
///
/// [watchForTerminal] — подписка: устройство, появившееся или отвалившееся на
/// кассе, видно на экране настроек сразу. [forTerminal] — её первое значение,
/// а не второй запрос.
///
/// Форма привязки — общая пара из `terminal_wire.dart`, и разбор её живёт в
/// `TillOps.deviceBindings.decode`, а не здесь: третий читатель одной формы —
/// это третье место, где она может разойтись.
class WtDeviceBindingRepository implements DeviceBindingRepository {
  const WtDeviceBindingRepository(this._wire);

  final WtDispatcher _wire;

  @override
  Stream<List<DeviceBinding>> watchForTerminal(int terminalId) =>
      _wire.watch(TillOps.deviceBindings, terminalId);

  @override
  Future<List<DeviceBinding>> forTerminal(int terminalId) =>
      watchForTerminal(terminalId).first;

  @override
  Future<void> save(int terminalId, DeviceBinding binding) async {
    // Проверку привязки по каталогу делает касса — у неё каталог и есть, — и
    // её отказ обязан прийти сюда, а не быть проглоченным: договор обещает
    // `ArgumentError` с названным полем, и биндинг, молча «сохраняющий»
    // невалидную привязку, обещание нарушает.
    //
    // Истёкший сеанс сюда не заворачивается: `WtDispatcher` отдаёт его как
    // `SessionLost` (`lib/domain/wire/session_lost.dart`), а не как
    // `WtProtocolError`, — ловушка ниже типизирована на второе и на первое
    // не срабатывает. Раньше это была одна и та же ветка, и любой отказ
    // сеанса читался кассиром как «касса отклонила привязку».
    try {
      await _wire.ask(TillOps.deviceBindingSave, (
        terminalId: terminalId,
        binding: binding,
      ));
    } on WtProtocolError catch (error) {
      throw ArgumentError.value(
        binding.profileId,
        'binding',
        'касса отклонила привязку: ${error.code} — ${error.detail}',
      );
    }
  }
}
