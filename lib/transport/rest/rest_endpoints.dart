class RestEndpoints {
  final String baseUrl;

  const RestEndpoints(this.baseUrl);

  String get login => '$baseUrl/api/v1/auth/login';

  String get loginByPin => '$baseUrl/api/v1/auth/pin';

  String get refreshToken => '$baseUrl/api/v1/auth/refresh';

  String get logout => '$baseUrl/api/v1/auth/logout';

  String get registerPos => '$baseUrl/api/v1/pos/register';

  String get uploadSales => '$baseUrl/api/v1/sync/sales';

  String get uploadRefunds => '$baseUrl/api/v1/sync/refunds';

  String get uploadShifts => '$baseUrl/api/v1/sync/shifts';

  String get uploadCashOperations => '$baseUrl/api/v1/sync/cash-operations';

  String get uploadSupplies => '$baseUrl/api/v1/sync/supplies';

  String get uploadAgents => '$baseUrl/api/v1/sync/agents';

  String get uploadFiscal => '$baseUrl/api/v1/sync/fiscal';

  String get downloadProducts => '$baseUrl/api/v1/sync/products';

  String get downloadPrices => '$baseUrl/api/v1/sync/prices';

  String get downloadAgents => '$baseUrl/api/v1/sync/agents/download';

  String get downloadCategories => '$baseUrl/api/v1/sync/categories';

  String get downloadPosConfig => '$baseUrl/api/v1/pos/config';

  String get uploadBackup => '$baseUrl/api/v1/backup/upload';

  String downloadBackup(String backupId) => '$baseUrl/api/v1/backup/$backupId';

  String get listBackups => '$baseUrl/api/v1/backup/list';

  String get sendNotification => '$baseUrl/api/v1/notifications/send';

  String get registerFcmToken => '$baseUrl/api/v1/notifications/fcm';

  String get sendReport => '$baseUrl/api/v1/reports/send';

  String get reportHistory => '$baseUrl/api/v1/reports/history';

  String get sendP2P => '$baseUrl/api/v1/p2p/send';

  String get receiveP2P => '$baseUrl/api/v1/p2p/receive';

  String get websocket => '${baseUrl.replaceFirst(RegExp(r'^http'), 'ws')}/ws';

  String get sse => '$baseUrl/api/v1/sse/subscribe';

  String get health => '$baseUrl/api/v1/health';

  String get version => '$baseUrl/api/v1/version';
}
