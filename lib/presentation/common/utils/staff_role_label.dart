/// Названия ролей сотрудника — на языке интерфейса.
///
/// `StaffRole` живёт в `lib/telegram` и языка интерфейса не знает. До этой
/// правки расширение `StaffRoleExtension.displayName` там же возвращало
/// «Владелец», «Администратор», «Кассир», и экран чата сотрудников
/// показывал их на любой кассе — в том числе американской.
///
/// Приём тот же, что у каталога оборудования и родов расхода: перечисление
/// хранит устойчивый признак, слово выбирается при показе.
library;

import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/telegram/internal_chat/staff_identity_service.dart';

String staffRoleLabel(StaffRole role, AppLocalizations l10n) => switch (role) {
  StaffRole.owner => l10n.staffRoleOwner,
  StaffRole.administrator => l10n.staffRoleAdministrator,
  StaffRole.user => l10n.staffRoleUser,
  StaffRole.cashier => l10n.staffRoleCashier,
  StaffRole.unknown => l10n.staffRoleUnknown,
};
