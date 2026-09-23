class AppConstants {
  AppConstants._();

  static const appName = 'TelePOS';

  static const appVersion = '3.7.0';

  static const buildNumber = 19;

  static const dateTimeFormat = 'yyyy-MM-dd HH:mm';

  static const dateFormat = 'yyyy-MM-dd';

  static const timeFormat = 'HH:mm:ss';

  static const timeFormatShort = 'HH:mm';

  static const displayDateFormat = 'dd.MM.yyyy';

  static const displayDateTimeFormat = 'dd.MM.yyyy HH:mm';

  static const currencySymbol = '₸';

  static const currencyCode = 'KZT';

  static const currencySymbolAfter = true;

  static const priceScale = 2;

  static const quantityScale = 3;

  static const percentScale = 4;

  static const moneyScale = 3;

  static const decimalPrecision = 18;

  static const syncInterval = Duration(minutes: 5);

  static const syncSalesBatchSize = 20;

  static const syncProductsBatchSize = 100;

  static const syncTimeout = Duration(seconds: 30);

  static const oldSaleRetentionDays = 90;

  static const oldSaleCleanupInterval = Duration(days: 7);

  static const maxHistoryRecords = 1000;

  static const updateCheckInterval = Duration(hours: 3);

  static const updateCheckTimeout = Duration(seconds: 10);

  static const githubRepoOwner = '';

  static const githubRepoName = '';

  static const githubReleasesUrl = '';

  static const playStoreUrl = '';

  static const appStoreUrl = '';

  static const userPinRsaCipher = 'RSA/ECB/NoPadding';

  static const rsaKeySize = 2048;

  static const hashAlgorithm = 'SHA-256';

  static const minButtonSize = 48.0;

  static const mobileBreakpoint = 600.0;

  static const tabletBreakpoint = 900.0;

  static const desktopBreakpoint = 1200.0;

  static const defaultPadding = 16.0;

  static const defaultBorderRadius = 8.0;

  static const maxCommentLength = 500;

  static const maxProductNameLength = 255;

  static const maxBarcodeLength = 50;

  static const maxItemsInReceipt = 100;

  static const httpTimeout = Duration(seconds: 30);

  static const connectionTimeout = Duration(seconds: 10);

  static const pinInputTimeout = Duration(minutes: 5);

  static const inactivityTimeout = Duration(minutes: 30);

  static const receiptWidth80mm = 48;

  static const receiptWidth58mm = 32;

  static const printerCodepage = 'CP866';
}
