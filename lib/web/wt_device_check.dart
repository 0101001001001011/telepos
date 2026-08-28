import 'package:telepos/core/errors/safe_error_text.dart';
import 'package:telepos/domain/device/device_check.dart';
import 'package:telepos/domain/device/device_class.dart';
import 'package:telepos/domain/wire/session_lost.dart';
import 'package:telepos/domain/wire/till_ops.dart';
import 'package:telepos/web/wt_channel.dart';
import 'package:telepos/web/wt_dispatcher.dart';

/// Проверка устройства кассы — по проводу.
///
/// **Неизвестный terminalId:** решает касса и намеренно отвечает тем же
/// `notConfigured`, что дал бы `DeviceCheckLocal`. Здесь ничего не решается
/// заново — только передаётся то, что она прислала.
class WtDeviceCheck implements DeviceCheck {
  const WtDeviceCheck(this._wire);

  final WtDispatcher _wire;

  @override
  Future<DeviceCheckOutcome> check({
    required int terminalId,
    required DeviceClass deviceClass,
  }) async {
    try {
      return await _wire.ask(TillOps.deviceCheck, (
        terminalId: terminalId,
        deviceClass: deviceClass,
      ));
    } on SessionLost {
      // Истёкший сеанс — не отказ устройства и не обрыв связи: касса ответила,
      // сторож её просто не пустил дальше. Заворачивать это в
      // `DeviceCheckOutcome.unexpectedError` значило бы дать оператору тот же
      // текст, что при неотвечающей кассе, и отправить его чинить устройство,
      // когда чинить нужно вход. Наверх, не завёрнутым — куда его увести,
      // решает задача 5.
      rethrow;
    } on Object catch (error) {
      // `DeviceCheck.check` не бросает никогда, кроме `SessionLost` выше (см.
      // доку контракта): обрыв сети и не поднявшуюся кассу оператор обязан
      // увидеть тем же путём, что и отказ самого устройства, а не крашем
      // экрана настроек.
      //
      // Пункт 7 финальной волны закрытия долга безопасности (2026-08-22):
      // здесь стоял сырой `$error`, найденный переводом
      // `no_raw_exception_on_wire_test.dart` с фиксированного списка путей на
      // обход по имени вызова через весь `lib/`.
      //
      // Но очищать надо только чужое. `WtProtocolError` — наш собственный
      // отказ: `code` канонический и наш, `detail` приезжает кадром с кассы,
      // а касса вычистила его ещё в первой фазе (`safeErrorText` в
      // `till_wire`, `WireRefusal` для названных причин). Пропустив его через
      // очистку для чужих исключений, оператор увидел бы `WtProtocolError`
      // вместо `forbidden` — то есть мы потеряли бы названную причину ровно
      // там, где четыре круга работы её заводили.
      final named = error is WtProtocolError
          ? '${error.code}: ${error.detail}'
          : safeErrorText(error);
      return DeviceCheckOutcome.unexpectedError(
        'Не удалось обратиться к кассе для проверки устройства: $named',
      );
    }
  }
}
