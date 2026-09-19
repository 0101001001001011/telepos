import 'package:telepos/domain/device/device_class.dart';
import 'package:telepos/domain/device/device_profile.dart';
import 'package:telepos/domain/device/device_profile_catalog.dart';

/// Несколько каталогов, читаемых как один, **по порядку**.
///
/// Заведён ради одного: подмешать виртуальные профили эмуляторов
/// (`lib/emulators/emulated_device_profile_catalog.dart`) к встроенным, не
/// трогая ни встроенный каталог, ни его читателей. Правка встроенного
/// каталога означала бы, что эмуляторные модели видит и магазинная касса; а
/// подмена его целиком означала бы, что на стенде с эмуляторами нельзя
/// привязать ни одного настоящего прибора.
///
/// **Порядок значим и проверен сторожем.** Первый каталог, знающий
/// идентификатор, побеждает, и в списке класса профиль появляется ровно один
/// раз. Обратный приоритет дал бы худший из возможных исходов: не отказ, а
/// правдоподобно работающий прибор **не той модели** — ровно тот класс беды,
/// ради которого `DeviceProfileCatalog.byId` обязан отдавать `null`, а не
/// «что-нибудь похожее».
class CompositeDeviceProfileCatalog implements DeviceProfileCatalog {
  const CompositeDeviceProfileCatalog(this._catalogs);

  final List<DeviceProfileCatalog> _catalogs;

  @override
  List<DeviceProfile> forClass(DeviceClass deviceClass) {
    final seen = <String>{};
    final out = <DeviceProfile>[];
    for (final catalog in _catalogs) {
      for (final profile in catalog.forClass(deviceClass)) {
        if (seen.add(profile.id)) out.add(profile);
      }
    }
    return List<DeviceProfile>.unmodifiable(out);
  }

  @override
  DeviceProfile? byId(String id) {
    for (final catalog in _catalogs) {
      final found = catalog.byId(id);
      if (found != null) return found;
    }
    return null;
  }
}
