enum TransportOperation {
  uploadSales,

  uploadRefunds,

  uploadShifts,

  uploadCashOperations,

  uploadSupplies,

  downloadProducts,

  downloadPrices,

  downloadCategories,

  downloadAgents,

  downloadConfig,

  downloadUsers,

  downloadStock,

  uploadBackup,

  listBackups,

  downloadBackup,

  deleteBackup,

  notifyShiftOpen,

  notifyShiftClose,

  notifyLargeSale,

  notifyRefund,

  notifyError,

  notifyLowStock,

  notifyFiscalError,

  sendZReport,

  sendDailyReport,

  sendWeeklyReport,

  sendInventoryReport,

  authPhone,

  authQr,

  authCredentials,

  authRefreshToken,

  authLogout,

  subscribePriceUpdates,

  subscribeStockUpdates,

  subscribeConfigUpdates,

  receiveRemoteCommands,

  p2pDirectSync,

  p2pStockTransfer,

  p2pPriceShare;

  OperationCategory get category => switch (this) {
    TransportOperation.uploadSales ||
    TransportOperation.uploadRefunds ||
    TransportOperation.uploadShifts ||
    TransportOperation.uploadCashOperations ||
    TransportOperation.uploadSupplies => OperationCategory.syncUpload,
    TransportOperation.downloadProducts ||
    TransportOperation.downloadPrices ||
    TransportOperation.downloadCategories ||
    TransportOperation.downloadAgents ||
    TransportOperation.downloadConfig ||
    TransportOperation.downloadUsers ||
    TransportOperation.downloadStock => OperationCategory.syncDownload,
    TransportOperation.uploadBackup ||
    TransportOperation.listBackups ||
    TransportOperation.downloadBackup ||
    TransportOperation.deleteBackup => OperationCategory.backup,
    TransportOperation.notifyShiftOpen ||
    TransportOperation.notifyShiftClose ||
    TransportOperation.notifyLargeSale ||
    TransportOperation.notifyRefund ||
    TransportOperation.notifyError ||
    TransportOperation.notifyLowStock ||
    TransportOperation.notifyFiscalError => OperationCategory.notification,
    TransportOperation.sendZReport ||
    TransportOperation.sendDailyReport ||
    TransportOperation.sendWeeklyReport ||
    TransportOperation.sendInventoryReport => OperationCategory.report,
    TransportOperation.authPhone ||
    TransportOperation.authQr ||
    TransportOperation.authCredentials ||
    TransportOperation.authRefreshToken ||
    TransportOperation.authLogout => OperationCategory.auth,
    TransportOperation.subscribePriceUpdates ||
    TransportOperation.subscribeStockUpdates ||
    TransportOperation.subscribeConfigUpdates ||
    TransportOperation.receiveRemoteCommands => OperationCategory.realtime,
    TransportOperation.p2pDirectSync ||
    TransportOperation.p2pStockTransfer ||
    TransportOperation.p2pPriceShare => OperationCategory.p2p,
  };

  bool get isCritical => switch (this) {
    TransportOperation.uploadSales ||
    TransportOperation.uploadRefunds ||
    TransportOperation.uploadShifts ||
    TransportOperation.uploadBackup ||
    TransportOperation.notifyFiscalError => true,
    _ => false,
  };
}

enum OperationCategory {
  syncUpload,
  syncDownload,
  backup,
  notification,
  report,
  auth,
  realtime,
  p2p,
}
