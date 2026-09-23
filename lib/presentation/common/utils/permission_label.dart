/// Подписи прав — на языке интерфейса.
///
/// # Что было
///
/// `PermissionKeys.label` и `groupLabel` жили в `lib/core` и возвращали
/// тридцать шесть русских слов: «Продажа», «Кассовые операции», «Продажа в
/// долг», «Браузерные терминалы». Экран управления пользователями рисовал
/// их как есть, на любой кассе.
///
/// Экранный сторож молчал: слово лежало в `lib/core`, куда он не смотрит.
///
/// # Восемь ключей, заведённых и не подключённых
///
/// В словаре уже лежали `permEditPrice`, `permSellInDebt`, `permDeferSale`,
/// `permCancelPayment`, `permCashOperations`, `permDiscounts`,
/// `permSendToOfd`, `permShowHistory` — во всех пяти языках, и ни один не
/// спрашивался. Кто-то начал переводить права и не довёл; словарь при этом
/// утверждал, что переведено.
///
/// Здесь они подключены, а недостающие семь добавлены. Двадцать девять слов
/// из тридцати шести взяты из УЖЕ существующих ключей (`navSale`,
/// `settingsFiscal`, `applianceTitle` и прочих): заводить второе слово для
/// одного понятия — как раз то, из-за чего мёртвый набор и появился.
///
/// # Почему ключ права остаётся строкой
///
/// `'nav.sale'` хранится в правах пользователя и ездит по проводу. Менять
/// его нельзя; менять слово рядом с ним — можно и нужно. Тот же приём, что
/// у каталога оборудования (`device_profile_label.dart`).
library;

import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/l10n/app_localizations.dart';

/// Подпись права на языке интерфейса.
///
/// Неизвестный ключ возвращается как есть — он и есть самое понятное, что
/// можно показать о праве, которого этот выпуск ещё не знает.
String permissionLabel(String key, AppLocalizations l10n) => switch (key) {
  PermissionKeys.navSale => l10n.navSale,
  PermissionKeys.navRefund => l10n.navRefund,
  PermissionKeys.navShift => l10n.navShift,
  PermissionKeys.navHistory => l10n.navHistory,
  PermissionKeys.navCatalog => l10n.navCatalog,
  PermissionKeys.navAgent => l10n.navAgents,
  PermissionKeys.navSupply => l10n.navSupply,
  PermissionKeys.navCashOperation => l10n.permCashOperations,
  PermissionKeys.navSettings => l10n.navSettings,
  PermissionKeys.navSync => l10n.navSync,
  PermissionKeys.navReports => l10n.navReports,
  PermissionKeys.navServiceQueue => l10n.permNavServiceQueue,
  PermissionKeys.navServiceIntake => l10n.permNavServiceIntake,
  PermissionKeys.navTables => l10n.navTables,
  PermissionKeys.navOrders => l10n.navOrders,
  PermissionKeys.opEditPrice => l10n.permEditPrice,
  PermissionKeys.opSellDiscount => l10n.permSellWithDiscount,
  PermissionKeys.opSellDebt => l10n.permSellInDebt,
  PermissionKeys.opCashInOut => l10n.permCashInOut,
  PermissionKeys.opCancelPayment => l10n.permCancelPayment,
  PermissionKeys.opDeferSale => l10n.permDeferSale,
  PermissionKeys.opRefund => l10n.permRefundGoods,
  PermissionKeys.opRefundWithoutReceipt => l10n.permRefundWithoutReceipt,
  PermissionKeys.opIssueCertificate => l10n.certificateIssueTitle,
  PermissionKeys.opCreditRepay => l10n.cashReasonCreditRepayment,
  PermissionKeys.settingsUsers => l10n.setUsersTitle,
  PermissionKeys.settingsAccounts => l10n.accountsSettingsTitle,
  PermissionKeys.settingsPrinter => l10n.settingsPrinter,
  PermissionKeys.settingsFiscal => l10n.settingsFiscal,
  PermissionKeys.settingsHardware => l10n.setupStepEquipment,
  PermissionKeys.settingsRestaurant => l10n.restaurantModeRestaurant,
  PermissionKeys.settingsTransport => l10n.settingsTransport,
  PermissionKeys.settingsTelegram => l10n.settingsTelegram,
  PermissionKeys.settingsTerminalService => l10n.terminalServiceTitle,
  PermissionKeys.settingsLogJournal => l10n.logJournalTitle,
  PermissionKeys.settingsAppliance => l10n.applianceTitle,
  _ => key,
};

/// Подпись раздела прав на языке интерфейса.
String permissionGroupLabel(String groupKey, AppLocalizations l10n) =>
    switch (groupKey) {
      'navigation' => l10n.permGroupNavigation,
      'operations' => l10n.shiftOperations,
      'settings' => l10n.settingsTitle,
      _ => groupKey,
    };
