/// Подпись роли для человека.
///
/// # Почему не в `UserRole`
///
/// `UserRole` живёт в `lib/core` и не знает ни о словаре, ни о дереве
/// виджетов — и знать не должен: подпись для человека это дело слоя показа.
/// До этой правки `UserRole.displayName` возвращала русское слово, и оно
/// доезжало до экрана входа на любом языке, а заодно уезжало по проводу как
/// данные. Теперь по проводу едет устойчивый ключ (`cashier`), а слово
/// выбирается здесь.
library;

import 'package:telepos/core/constants/enums/user_role.dart';
import 'package:telepos/l10n/app_localizations.dart';

extension UserRoleLabel on UserRole {
  /// Название роли на языке интерфейса.
  String label(AppLocalizations l10n) => switch (this) {
    UserRole.owner => l10n.setRoleOwner,
    UserRole.administrator => l10n.setRoleAdministrator,
    UserRole.user => l10n.setRoleUser,
    UserRole.cashier => l10n.loginCashier,
  };
}

/// Подпись роли, пришедшей строкой-ключом (`owner`, `cashier`, …).
///
/// Ключ приезжает по проводу и из базы. Неизвестный ключ возвращается как
/// есть: показать сырое значение честнее, чем подставить чужую роль, —
/// человек увидит, что касса знает о нём что-то незнакомое.
String userRoleLabelOfKey(String? key, AppLocalizations l10n) {
  if (key == null || key.isEmpty) return '';
  for (final role in UserRole.values) {
    if (role.name == key) return role.label(l10n);
  }
  return key;
}
