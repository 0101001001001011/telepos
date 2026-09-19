import 'package:telepos/data/device/composite_device_profile_catalog.dart';
import 'package:telepos/data/device/device_profile_catalog_builtin.dart';
import 'package:telepos/domain/device/device_profile_catalog.dart';
import 'package:telepos/emulators/emulated_device_profile_catalog.dart';

/// Включены ли виртуальные профили эмуляторов.
///
/// **Константа времени компиляции, и это не стилистика.** `const
/// bool.fromEnvironment` сворачивается компилятором, ветка `else` ниже
/// становится мёртвой, и `EmulatedDeviceProfileCatalog` не входит в дерево
/// достижимости магазинной сборки. Что AOT его действительно выбрасывает —
/// **измерено**, а не предположено: два прогона `strings` записаны в
/// `docs/internal/testing-notes.md`, раздел «Виртуальные профили и AOT».
/// Проектировщик отказался утверждать это без замера, и был прав: первая же
/// команда, которой это собирались мерить, мерила не тот файл.
///
/// Включается сборкой:
///
/// ```
/// flutter run   --dart-define=TELEPOS_EMULATORS=true
/// flutter build windows --release --dart-define=TELEPOS_EMULATORS=true
/// flutter test  --dart-define=TELEPOS_EMULATORS=true
/// ```
const bool kEmulatorsEnabled = bool.fromEnvironment('TELEPOS_EMULATORS');

/// Каталог профилей устройств этой сборки — **одно** определение на всех
/// читателей.
///
/// Читателей было четыре, и три из них строили `BuiltinDeviceProfileCatalog()`
/// прямо на месте (`hardware_module.dart`), мимо того, что зарегистрировано в
/// `service_locator.dart`. Пока каталог был один, разницы не было; со вторым
/// каталогом она появляется сразу и молча: привязка к виртуальному профилю не
/// прошла бы сверку при старте, оборудование не зарегистрировалось бы, а
/// экран настроек показывал бы профиль, которым нельзя пользоваться. Это тот
/// же класс беды, что «гейт раньше способа его пройти».
DeviceProfileCatalog buildDeviceProfileCatalog() {
  if (kEmulatorsEnabled) {
    return CompositeDeviceProfileCatalog([
      // Порядок значим: встроенные профили первыми, чтобы виртуальный не мог
      // затенить настоящую модель. Сторож — в
      // `test/emulators/emulated_profiles_test.dart`.
      BuiltinDeviceProfileCatalog(),
      const EmulatedDeviceProfileCatalog(),
    ]);
  }
  return BuiltinDeviceProfileCatalog();
}
