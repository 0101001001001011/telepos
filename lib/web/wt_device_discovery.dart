import 'package:telepos/domain/device/device_class.dart';
import 'package:telepos/domain/device/device_discovery.dart';
import 'package:telepos/domain/device/device_profile_catalog.dart';
import 'package:telepos/domain/wire/session_lost.dart';
import 'package:telepos/domain/wire/till_ops.dart';
import 'package:telepos/web/wt_dispatcher.dart';

/// Устройства кассы — по проводу.
///
/// Браузер сам ничего не перечисляет: портов, сокетов и спулера у него нет
/// (docs/system-architecture.md, раздел 8). Он спрашивает ту машину, к которой
/// подключён.
///
/// Вопрос, а не подписка, и это названо в каталоге операций: поиск железа —
/// работа по нажатию кнопки, а не состояние, за которым следят.
class WtDeviceDiscovery implements DeviceDiscovery {
  const WtDeviceDiscovery(this._wire, this._catalog);

  final WtDispatcher _wire;
  final DeviceProfileCatalog _catalog;

  @override
  Future<DeviceDiscoveryResult> find(DeviceClass deviceClass) async {
    try {
      return await _wire.ask(TillOps.deviceDiscovery, deviceClass);
    } on SessionLost {
      // Пункт 4 второго круга разбора (2026-08-21) — пятое место одной и той
      // же болезни, в файле, который задача 4 первого круга объявила
      // починенным: не задела этот класс вовсе. Истёкший сеанс — не отказ
      // устройства и не обрыв связи: касса ответила, сторож её просто не
      // пустил дальше. Свернуть это в `failedSources` ниже значило бы дать
      // оператору тот же диалог «эти источники опросить не удалось», что и
      // при неотвечающей кассе, и не увести его на вход — та же формулировка
      // «обрыв связи», ради устранения которой делалась задача 4. Наверх, не
      // завёрнутым — симметрично соседу, `WtDeviceCheck.check`.
      rethrow;
    } on Object {
      // `DeviceDiscovery.find` не бросает никогда, кроме `SessionLost` выше
      // (см. доку контракта), и не имеет права свернуть «не смогли даже
      // спросить кассу» в тот же пустой список, что и «на кассе искренне
      // ничего нет» — ради этого различия в контракте и появился
      // `failedSources`.
      //
      // `discoverableSourcesFor` — единственное проверенное определение того,
      // какие источники относятся к этому классу; то же самое, которым
      // пользуется `DeviceDiscoveryLocal`. Взято не чтобы что-то искать, а
      // чтобы честно назвать, чего спросить не удалось, вместо угадывания.
      return DeviceDiscoveryResult(
        failedSources: discoverableSourcesFor(deviceClass, _catalog),
      );
    }
  }
}
