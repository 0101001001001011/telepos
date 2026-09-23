/// Этап подъёма кассы — КОДОМ, а не готовой строкой.
///
/// # Что измерено 2026-09-21
///
/// На заставке английской кассы стояло «Готово» — по-русски. И не только
/// оно: все шестнадцать сообщений о ходе подъёма собирались готовым русским
/// текстом в `lib/app/config`, то есть в слое, который языка интерфейса не
/// знает и знать не должен.
///
/// Видно это было каждому: заставка — первое, что показывает приложение, и
/// она висит секунд десять.
///
/// # Почему код, а не строка
///
/// Слой подъёма отвечает на вопрос «где мы сейчас», а не «какими словами об
/// этом сказать». Слова знает только тот, кто знает язык, — заставка. Тот же
/// приём, что у названий моделей устройств и стран: устойчивый
/// идентификатор здесь, ключ словаря там.
///
/// Это же снимает долг, записанный отдельной строкой: «BootProgress везёт
/// свободный русский текст, собранный в слое данных».
library;

enum BootStage {
  /// Loading configuration…
  loadingConfig,

  /// Checking the till key…
  checkingPosKey,

  /// Loading counterparties…
  loadingAgents,

  /// Loading accounts…
  loadingAccounts,

  /// Preparing the database…
  initialisingDatabase,

  /// Loading cashiers…
  loadingCashiers,

  /// Loading till data…
  loadingPosData,

  /// Loading products…
  loadingProducts,

  /// Checking receipt numbering…
  checkingReceiptNumbers,

  /// Checking the licence…
  checkingLicence,

  /// Checking reports…
  checkingReports,

  /// Finishing up…
  finishingInitialisation,

  /// Starting background jobs…
  startingBackgroundJobs,

  /// Ready
  ready,

  /// Data loaded
  dataLoaded,

  /// Касса не ответила. Единственный этап с подробностью —
  /// кодом отказа.
  tillNotResponding,

  /// Downloading the backup…
  downloadingBackup,

  /// Could not download the backup
  backupDownloadFailed,

  /// Restoring the database…
  restoringDatabase,

  /// Could not restore the database
  databaseRestoreFailed,

  /// Applying the till key…
  applyingPosKey,

  /// Restore complete
  restoreDone,

  /// Creating a backup…
  creatingBackup,

  /// Could not create the backup
  backupCreateFailed,

  /// Backup created and uploaded
  backupDone,

  /// Loading users…
  loadingUsers,

  /// Loading categories…
  loadingCategories,

  /// Loading settings…
  loadingSettings,

  /// Sync complete
  syncDone,

  /// Something went wrong
  failed,
}
