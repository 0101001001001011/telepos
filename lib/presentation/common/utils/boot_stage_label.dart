/// Слова о ходе подъёма — по коду этапа.
///
/// # Почему здесь, а не в слое подъёма
///
/// Слой подъёма отвечает на вопрос «где мы сейчас», и языка интерфейса не
/// знает. До 2026-09-21 он вёз готовый русский текст, и заставка английской
/// кассы показывала «Готово» — первое, что видит человек, и висит это
/// секунд десять.
///
/// Тот же приём, что у названий моделей устройств, стран и налогового шага:
/// устойчивый код там, ключ словаря здесь.
library;

import 'package:telepos/domain/startup/boot_stage.dart';
import 'package:telepos/l10n/app_localizations.dart';

/// Что показать человеку на этом этапе.
///
/// [detail] — подробность для этапов, у которых она есть: код отказа у
/// [BootStage.tillNotResponding]. Для остальных не читается.
String bootStageLabel(
  BootStage stage,
  AppLocalizations l10n, {
  String? detail,
}) => switch (stage) {
  BootStage.loadingConfig => l10n.bootLoadingConfig,
  BootStage.checkingPosKey => l10n.bootCheckingPosKey,
  BootStage.loadingAgents => l10n.bootLoadingAgents,
  BootStage.loadingAccounts => l10n.bootLoadingAccounts,
  BootStage.initialisingDatabase => l10n.bootInitialisingDatabase,
  BootStage.loadingCashiers => l10n.bootLoadingCashiers,
  BootStage.loadingPosData => l10n.bootLoadingPosData,
  BootStage.loadingProducts => l10n.bootLoadingProducts,
  BootStage.checkingReceiptNumbers => l10n.bootCheckingReceiptNumbers,
  BootStage.checkingLicence => l10n.bootCheckingLicence,
  BootStage.checkingReports => l10n.bootCheckingReports,
  BootStage.finishingInitialisation => l10n.bootFinishingInitialisation,
  BootStage.startingBackgroundJobs => l10n.bootStartingBackgroundJobs,
  BootStage.ready => l10n.bootReady,
  BootStage.dataLoaded => l10n.bootDataLoaded,
  BootStage.tillNotResponding => l10n.bootTillNotResponding(detail ?? ""),
  BootStage.downloadingBackup => l10n.bootDownloadingBackup,
  BootStage.backupDownloadFailed => l10n.bootBackupDownloadFailed,
  BootStage.restoringDatabase => l10n.bootRestoringDatabase,
  BootStage.databaseRestoreFailed => l10n.bootDatabaseRestoreFailed,
  BootStage.applyingPosKey => l10n.bootApplyingPosKey,
  BootStage.restoreDone => l10n.bootRestoreDone,
  BootStage.creatingBackup => l10n.bootCreatingBackup,
  BootStage.backupCreateFailed => l10n.bootBackupCreateFailed,
  BootStage.backupDone => l10n.bootBackupDone,
  BootStage.loadingUsers => l10n.bootLoadingUsers,
  BootStage.loadingCategories => l10n.bootLoadingCategories,
  BootStage.loadingSettings => l10n.bootLoadingSettings,
  BootStage.syncDone => l10n.bootSyncDone,
  BootStage.failed => l10n.bootFailed,
};
