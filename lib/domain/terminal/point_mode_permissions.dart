import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/domain/terminal/terminal.dart';

/// Что режим терминала запрещает независимо от роли человека.
///
/// # Откуда это взялось
///
/// docs/system-architecture.md, раздел 11: право — у пары «кто» и «откуда»,
/// и действующее право есть **пересечение**:
///
/// ```
/// право = права роли пользователя ∩ права терминала ∩ ограничения режима
/// ```
///
/// До 2026-08-20 пересечения в коде не было вовсе: вход отдавал права роли как
/// есть, и терминал самообслуживания получал ровно то же, что касса кассира.
///
/// # Чего здесь нет
///
/// Пример из самого документа — «терминал самообслуживания не открывает
/// денежный ящик даже директору» — **невыразим**: в `PermissionKeys` 34 ключа
/// (на 2026-08-22, `PermissionKeys.allPermissions`), и ключа на ящик среди
/// них нет; ящик открывается через `drawerViaPrinter` в устройствах
/// терминала, минуя права целиком. Заводить ключ здесь значило бы объявить
/// право, которое никто не проверяет. Пробел записан в спеке.
abstract final class PointModePermissions {
  /// Запреты для терминала без ответственного лица: ни деньги, ни возвраты,
  /// ни настройки. Объявлены явно (не как литерал) потому что совпадение
  /// самообслуживания и беспилотного режима — намеренное, и развести их
  /// можно только по названной причине, а не случайно.
  static const Set<String> _unattendedLikePermissions = <String>{
    PermissionKeys.opCashInOut,
    PermissionKeys.opSellDebt,
    PermissionKeys.opRefundWithoutReceipt,
    PermissionKeys.opRefund,
    PermissionKeys
        .navRefund, // Возврат недоступен целиком, не «виден и не работает»
    PermissionKeys.opEditPrice,
    PermissionKeys.opSellDiscount,
    PermissionKeys.navSettings,
    PermissionKeys.navReports,
    PermissionKeys.navCashOperation,
    PermissionKeys.settingsUsers,
    PermissionKeys.settingsAccounts,
    PermissionKeys.settingsPrinter,
    PermissionKeys.settingsFiscal,
    PermissionKeys.settingsHardware,
    PermissionKeys.settingsRestaurant,
    PermissionKeys.settingsTransport,
    PermissionKeys.settingsTelegram,
  };

  /// Что отнимает режим. Объявлены **все** члены [PointMode]: пустой набор
  /// пишется явно, потому что «ничего не отнимает» и «забыли объявить»
  /// снаружи неразличимы.
  static const Map<PointMode, Set<String>> _denied = {
    // Рабочее место кассира — эталон, относительно которого сужают остальные.
    PointMode.cashier: <String>{},

    // Покупатель у экрана. Отнимаются деньги мимо чека, долг, возврат без
    // чека, правка цены и всё, что ведёт в настройки: за этим терминалом
    // никто не отвечает лицом.
    PointMode.selfService: _unattendedLikePermissions,

    // Без человека вовсе. Те же ограничения, что у самообслуживания: ни
    // денег, ни возвратов, ни настроек.
    PointMode.unattended: _unattendedLikePermissions,

    // Кухня: экран заказов, денег не касается вовсе.
    PointMode.kitchen: <String>{
      PermissionKeys.navSale,
      PermissionKeys.navRefund,
      PermissionKeys.navCashOperation,
      PermissionKeys.navSettings,
      PermissionKeys.navReports,
      PermissionKeys.opCashInOut,
      PermissionKeys.opSellDebt,
      PermissionKeys.opRefund,
      PermissionKeys.opRefundWithoutReceipt,
      PermissionKeys.settingsUsers,
      PermissionKeys.settingsAccounts,
      PermissionKeys.settingsFiscal,
    },
  };

  /// Что отнимает [mode].
  static Set<String> deniedFor(PointMode mode) => _denied[mode]!;

  /// Действующее право: права роли за вычетом запретов режима.
  ///
  /// Только сужает. Режим не умеет **давать** право, которого нет у роли, и
  /// это свойство проверяется тестом: иначе настройка терминала стала бы
  /// способом обойти роль.
  static Set<String> effective({
    required Set<String> ofRole,
    required PointMode at,
  }) => ofRole.difference(deniedFor(at));
}
