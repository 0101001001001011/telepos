// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Kirghiz Kyrgyz (`ky`).
class AppLocalizationsKy extends AppLocalizations {
  AppLocalizationsKy([String locale = 'ky']) : super(locale);

  @override
  String get navReports => 'Отчёттор';

  @override
  String get navStock => 'Кампа';

  @override
  String get appName => 'TelePOS';

  @override
  String get globalOk => 'OK';

  @override
  String get globalCancel => 'Жокко чыгаруу';

  @override
  String get globalYes => 'Ооба';

  @override
  String get globalNo => 'Жок';

  @override
  String get globalSave => 'Сактоо';

  @override
  String get globalNew => 'Жаңы';

  @override
  String get globalDelete => 'Жок кылуу';

  @override
  String get globalEdit => 'Түзөтүү';

  @override
  String get globalAdd => 'Кошуу';

  @override
  String get globalSearch => 'Издөө';

  @override
  String get globalClose => 'Жабуу';

  @override
  String get globalBack => 'Артка';

  @override
  String get globalNext => 'Кийинки';

  @override
  String get globalDone => 'Даяр';

  @override
  String get globalLoading => 'Жүктөлүүдө...';

  @override
  String get globalError => 'Ката';

  @override
  String get globalSuccess => 'Ийгиликтүү';

  @override
  String get globalWarning => 'Эскертүү';

  @override
  String get globalInfo => 'Маалымат';

  @override
  String get globalConfirm => 'Ырастоо';

  @override
  String get globalClear => 'Тазалоо';

  @override
  String get globalSelect => 'Тандоо';

  @override
  String get globalAll => 'Баары';

  @override
  String get globalNone => 'Жок';

  @override
  String get globalTotal => 'Жалпы';

  @override
  String get globalAmount => 'Сумма';

  @override
  String get globalQuantity => 'Саны';

  @override
  String get globalPrice => 'Баа';

  @override
  String get globalDiscount => 'Арзандатуу';

  @override
  String get globalDate => 'Күнү';

  @override
  String get globalTime => 'Убакыт';

  @override
  String get loginTitle => 'Системага кирүү';

  @override
  String get loginPin => 'PIN киргизиңиз';

  @override
  String get loginPinHint => '4 сан';

  @override
  String get loginEnter => 'Кирүү';

  @override
  String get loginSelectUser => 'Колдонуучуну тандаңыз';

  @override
  String get loginNoUsers => 'Колдонуучулар жок';

  @override
  String get loginWrongPin => 'Туура эмес PIN';

  @override
  String get loginBlocked => 'Колдонуучу бөгөттөлгөн';

  @override
  String get loginSessionExpired => 'Сессия мөөнөтү бүттү';

  @override
  String get loginShiftRequired => 'Кирүү үчүн сменаны ачыңыз';

  @override
  String get staffRoleOwner => 'Ээси';

  @override
  String get staffRoleAdministrator => 'Администратор';

  @override
  String get staffRoleUser => 'Колдонуучу';

  @override
  String get staffRoleCashier => 'Кассир';

  @override
  String get staffRoleUnknown => 'Белгисиз';

  @override
  String get loginCashier => 'Кассир';

  @override
  String get loginAdmin => 'Администратор';

  @override
  String get loginManager => 'Менеджер';

  @override
  String get loginLogout => 'Чыгуу';

  @override
  String get loginSwitchUser => 'Колдонуучуну алмаштыруу';

  @override
  String get saleTitle => 'Сатуу';

  @override
  String get saleNewSale => 'Жаңы сатуу';

  @override
  String get saleAddProduct => 'Товар кошуу';

  @override
  String get saleScanBarcode => 'Штрих-кодду сканерлөө';

  @override
  String get saleEnterBarcode => 'Штрих-кодду киргизиңиз';

  @override
  String get saleProductNotFound => 'Товар табылган жок';

  @override
  String get saleEmptyCart => 'Себет бош';

  @override
  String get saleSubtotal => 'Аралык сумма';

  @override
  String get saleTax => 'КНС';

  @override
  String get saleTotalDiscount => 'Арзандатуу';

  @override
  String get saleToPay => 'Төлөөгө';

  @override
  String saleItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count товар',
      one: '$count товар',
    );
    return '$_temp0';
  }

  @override
  String paymentCardChargeUnsettled(String amount) {
    return 'Карта $amount суммасына өткөрүлдү, бул сумма чекке кирбейт. Төлөм терминалында операцияны жокко чыгарыңыз.';
  }

  @override
  String get saleRemoveItem => 'Товарды алып салуу';

  @override
  String get saleClearCart => 'Себетти тазалоо';

  @override
  String get saleConfirmClear => 'Себетти тазалоо керекпи?';

  @override
  String get saleProceedPayment => 'Төлөмгө өтүү';

  @override
  String get saleHold => 'Кийинкиге калтыруу';

  @override
  String get saleRecall => 'Кайтаруу';

  @override
  String get saleHeldSales => 'Кийинкиге калтырылган сатуулар';

  @override
  String get saleNoHeldSales => 'Кийинкиге калтырылган сатуулар жок';

  @override
  String get saleProductSearch => 'Товарларды издөө';

  @override
  String get saleByCategory => 'Категориялар боюнча';

  @override
  String get saleByName => 'Аталышы боюнча';

  @override
  String get saleByBarcode => 'Штрих-код боюнча';

  @override
  String get saleWeight => 'Салмагы';

  @override
  String saleWeightKg(String weight) {
    return 'Салмагы: $weight кг';
  }

  @override
  String get saleEnterWeight => 'Салмакты киргизиңиз';

  @override
  String get saleEnterQuantity => 'Санын киргизиңиз';

  @override
  String get saleEnterPrice => 'Бааны киргизиңиз';

  @override
  String get saleFreePrice => 'Эркин баа';

  @override
  String saleMaxDiscount(String percent) {
    return 'Макс. арзандатуу: $percent%';
  }

  @override
  String get refundTitle => 'Кайтаруу';

  @override
  String get refundNewRefund => 'Жаңы кайтаруу';

  @override
  String get refundByReceipt => 'Чек боюнча';

  @override
  String get refundWithoutReceipt => 'Чексиз';

  @override
  String get refundEnterReceipt => 'Чек номерин киргизиңиз';

  @override
  String get refundReceiptNotFound => 'Чек табылган жок';

  @override
  String get refundSelectItems => 'Кайтаруу үчүн товарларды тандаңыз';

  @override
  String get refundReason => 'Кайтаруу себеби';

  @override
  String get refundConfirm => 'Кайтарууну ырастоо';

  @override
  String get refundAmount => 'Кайтаруу суммасы';

  @override
  String get refundComplete => 'Кайтаруу аткарылды';

  @override
  String get refundCash => 'Накталай кайтаруу';

  @override
  String get refundCard => 'Картага кайтаруу';

  @override
  String get refundConnectionLostHint =>
      'Терминал кассага өзү кайтат — иш ошол жерден уланат';

  @override
  String get refundConnectionLost => 'Касса менен байланыш үзүлдү';

  @override
  String get refundNoItems => 'Кайтаруу үчүн товарлар жок';

  @override
  String get refundAlreadyRefunded => 'Товар мурда кайтарылган';

  @override
  String get refundPartial => 'Жарым-жартылай кайтаруу';

  @override
  String get shiftTitle => 'Смена';

  @override
  String get shiftOpen => 'Сменаны ачуу';

  @override
  String get shiftClose => 'Сменаны жабуу';

  @override
  String get shiftCurrent => 'Учурдагы смена';

  @override
  String shiftNumber(int number) {
    return 'Смена №: $number';
  }

  @override
  String shiftOpenedAt(String time) {
    return 'Ачылган: $time';
  }

  @override
  String shiftCashier(String name) {
    return 'Кассир: $name';
  }

  @override
  String shiftSalesCount(int count) {
    return 'Сатуулар: $count';
  }

  @override
  String shiftRefundsCount(int count) {
    return 'Кайтаруулар: $count';
  }

  @override
  String get shiftTotalSales => 'Сатуу суммасы';

  @override
  String get shiftTotalRefunds => 'Кайтаруу суммасы';

  @override
  String get shiftCashInDrawer => 'Кассада';

  @override
  String get shiftExpected => 'Күтүлгөн';

  @override
  String get shiftActual => 'Чыныгы';

  @override
  String get shiftDifference => 'Айырма';

  @override
  String get shiftXReport => 'X-отчет';

  @override
  String get shiftZReport => 'Z-отчет';

  @override
  String get shiftConfirmClose => 'Сменаны жабуу керекпи?';

  @override
  String get shiftAlreadyOpen => 'Смена ачык';

  @override
  String get shiftNotOpen => 'Смена ачылган эмес';

  @override
  String get shiftOpenFirst => 'Алгач сменаны ачыңыз';

  @override
  String get paymentTitle => 'Төлөм';

  @override
  String get paymentCash => 'Накталай';

  @override
  String get paymentCard => 'Карта';

  @override
  String get paymentKaspi => 'Kaspi QR';

  @override
  String get paymentBonus => 'Бонустар';

  @override
  String get paymentDebt => 'Карызга';

  @override
  String get paymentInstallment => 'Бөлүп төлөө';

  @override
  String get paymentMixed => 'Аралаш';

  @override
  String get paymentEnterAmount => 'Сумманы киргизиңиз';

  @override
  String paymentRemaining(String amount) {
    return 'Калды: $amount';
  }

  @override
  String paymentChange(String amount) {
    return 'Кайтарым: $amount';
  }

  @override
  String get paymentComplete => 'Төлөм аяктады';

  @override
  String get paymentFailed => 'Төлөм катасы';

  @override
  String get paymentWaitingCard => 'Картаны күтүү...';

  @override
  String get paymentWaitingQr => 'QR күтүү...';

  @override
  String get paymentInsertCard => 'Картаны салыңыз';

  @override
  String get paymentScanQr => 'QR сканерлеңиз';

  @override
  String get paymentApproved => 'Жактырылды';

  @override
  String get paymentDeclined => 'Четке кагылды';

  @override
  String get paymentReceipt => 'Чек басып чыгаруу';

  @override
  String get paymentNoReceipt => 'Чексиз';

  @override
  String get paymentEmail => 'Email-ге жөнөтүү';

  @override
  String get paymentSms => 'SMS жөнөтүү';

  @override
  String get historyTitle => 'Тарых';

  @override
  String get historyToday => 'Бүгүн';

  @override
  String get historyYesterday => 'Кечээ';

  @override
  String get historyThisWeek => 'Бул жума';

  @override
  String get historyThisMonth => 'Бул ай';

  @override
  String get historyDateRange => 'Мезгилди тандоо';

  @override
  String get historyNoSales => 'Мезгилде сатуулар жок';

  @override
  String historyReceipt(String number) {
    return 'Чек №$number';
  }

  @override
  String get historyReprint => 'Кайра басып чыгаруу';

  @override
  String certificateSlipPrintFailed(String number, String reason) {
    return '$number сертификатынын слиби басылган жок: $reason';
  }

  @override
  String get historyDetails => 'Толугураак';

  @override
  String get historySale => 'Сатуу';

  @override
  String get historyRefund => 'Кайтаруу';

  @override
  String get historyFilter => 'Чыпка';

  @override
  String get agentTitle => 'Контрагенттер';

  @override
  String get agentClients => 'Кардарлар';

  @override
  String get agentSuppliers => 'Жеткирүүчүлөр';

  @override
  String get agentSearch => 'Контрагентти издөө';

  @override
  String get agentAdd => 'Контрагент кошуу';

  @override
  String get agentEdit => 'Түзөтүү';

  @override
  String get agentName => 'Аталышы/А.Ж.А.';

  @override
  String get agentPhone => 'Телефон';

  @override
  String get agentEmail => 'Email';

  @override
  String get agentIin => 'ИЖН/ИСН';

  @override
  String get agentAddress => 'Дарек';

  @override
  String get agentBalance => 'Баланс';

  @override
  String get agentBonusBalance => 'Бонус балансы';

  @override
  String get agentDebt => 'Карыз';

  @override
  String get agentNoAgents => 'Контрагенттер жок';

  @override
  String get agentSaveSuccess => 'Контрагент сакталды';

  @override
  String get agentDeleteConfirm => 'Контрагентти жок кылуу керекпи?';

  @override
  String get cashTitle => 'Касса';

  @override
  String get cashReasonCreditRepayment => 'Бөлүп төлөөнү жабуу';

  @override
  String get cashReasonCustomerTopUp => 'Сатып алуучунун эсебин толтуруу';

  @override
  String get accountBankCard => 'Банк (карта)';

  @override
  String get accountCertificateLiability =>
      'Сертификаттар боюнча милдеттенмелер';

  @override
  String get serviceConsumableFallback => 'Чыгым материалы';

  @override
  String get serviceAutoAddedByNorm => 'Чыгым ченеми боюнча кошулду';

  @override
  String get cashInvestment => 'Салым';

  @override
  String get cashExpense => 'Чыгым';

  @override
  String get cashBalance => 'Касса балансы';

  @override
  String get cashEnterAmount => 'Сумманы киргизиңиз';

  @override
  String get cashReason => 'Негиздеме';

  @override
  String get cashReasonPlaceholder => 'Себебин көрсөтүңүз';

  @override
  String get cashSuccess => 'Операция аткарылды';

  @override
  String get cashExpenseTypes => 'Чыгым түрү';

  @override
  String get discountTitle => 'Арзандатуу';

  @override
  String get discountPercent => 'Пайыз';

  @override
  String get discountFixed => 'Белгиленген';

  @override
  String get discountEnterValue => 'Маанини киргизиңиз';

  @override
  String get discountApply => 'Колдонуу';

  @override
  String get discountRemove => 'Арзандатууну алып салуу';

  @override
  String get discountOnItem => 'Товарга арзандатуу';

  @override
  String get discountOnTotal => 'Чекке арзандатуу';

  @override
  String get discountMaxExceeded => 'Максималдык арзандатуу ашып кетти';

  @override
  String get quickProductTitle => 'Тез товарлар';

  @override
  String get quickProductAdd => 'Товар кошуу';

  @override
  String get quickProductName => 'Аталышы';

  @override
  String get quickProductPrice => 'Баасы';

  @override
  String get quickProductCategory => 'Категориясы';

  @override
  String get quickProductSave => 'Сактоо';

  @override
  String get quickProductDelete => 'Жок кылуу';

  @override
  String get syncTitle => 'Синхрондоо';

  @override
  String get syncStatus => 'Синхрондоо абалы';

  @override
  String syncLastSync(String time) {
    return 'Акыркы синхрондоо: $time';
  }

  @override
  String get syncNow => 'Синхрондоо';

  @override
  String get syncInProgress => 'Синхрондолуп жатат...';

  @override
  String get syncSuccess => 'Синхрондоо аяктады';

  @override
  String get syncFailed => 'Синхрондоо катасы';

  @override
  String get syncProducts => 'Товарлар';

  @override
  String get syncPrices => 'Баалар';

  @override
  String get syncAgents => 'Контрагенттер';

  @override
  String get syncSales => 'Сатуулар';

  @override
  String syncPending(int count) {
    return 'Жөнөтүүнү күтүүдө: $count';
  }

  @override
  String get syncOffline => 'Байланыш жок';

  @override
  String get syncOnline => 'Туташкан';

  @override
  String get printerTitle => 'Принтер';

  @override
  String get printerStatus => 'Принтер абалы';

  @override
  String get printerConnected => 'Туташкан';

  @override
  String get printerDisconnected => 'Ажыратылган';

  @override
  String get printerError => 'Принтер катасы';

  @override
  String get printerPaperOut => 'Кагаз жок';

  @override
  String get printerConnect => 'Туташуу';

  @override
  String get printerDisconnect => 'Ажыратуу';

  @override
  String get printerTest => 'Тесттик басып чыгаруу';

  @override
  String get printerSettings => 'Принтер орнотуулары';

  @override
  String get printerWidth => 'Чек туурасы';

  @override
  String get additionalTitle => 'Кошумча';

  @override
  String get additionalSettings => 'Орнотуулар';

  @override
  String get additionalReports => 'Отчеттор';

  @override
  String get additionalInventory => 'Түгөндөө';

  @override
  String get additionalSupply => 'Товар кабыл алуу';

  @override
  String get additionalPriceChange => 'Бааларды өзгөртүү';

  @override
  String get additionalBackup => 'Камдык көчүрмө';

  @override
  String get additionalRestore => 'Калыбына келтирүү';

  @override
  String get additionalUpdate => 'Жаңыртуу';

  @override
  String get additionalAbout => 'Программа жөнүндө';

  @override
  String get additionalLicense => 'Лицензия';

  @override
  String get additionalSupport => 'Колдоо';

  @override
  String get receiptTitle => 'Чек';

  @override
  String get receiptNumber => 'Чек №';

  @override
  String get receiptDate => 'Күнү';

  @override
  String get receiptCashier => 'Кассир';

  @override
  String get receiptItems => 'Товарлар';

  @override
  String get receiptSubtotal => 'Аралык сумма';

  @override
  String get receiptDiscount => 'Арзандатуу';

  @override
  String get receiptTax => 'КНС';

  @override
  String get receiptTotal => 'ЖАЛПЫ';

  @override
  String get receiptCash => 'Накталай';

  @override
  String get receiptCard => 'Карта';

  @override
  String get receiptChange => 'Кайтарым';

  @override
  String get receiptThankYou => 'Сатып алганыңызга рахмат!';

  @override
  String get receiptFiscalNumber => 'Фискалдык номер';

  @override
  String get receiptQrCode => 'Текшерүү үчүн QR';

  @override
  String get receiptCopy => 'Чек көчүрмөсү';

  @override
  String get errorUnknown => 'Белгисиз ката';

  @override
  String get errorNetwork => 'Тармак катасы';

  @override
  String get errorServer => 'Сервер катасы';

  @override
  String get errorTimeout => 'Күтүү убактысы бүттү';

  @override
  String get errorNotFound => 'Табылган жок';

  @override
  String get errorPermission => 'Уруксат жок';

  @override
  String get errorDatabase => 'Маалыматтар базасынын катасы';

  @override
  String get errorValidation => 'Валидация катасы';

  @override
  String get errorRequired => 'Милдеттүү талаа';

  @override
  String get errorInvalidFormat => 'Туура эмес формат';

  @override
  String errorMinLength(int min) {
    return 'Минимум $min символ';
  }

  @override
  String errorMaxLength(int max) {
    return 'Максимум $max символ';
  }

  @override
  String errorMinValue(String min) {
    return 'Минимум $min';
  }

  @override
  String errorMaxValue(String max) {
    return 'Максимум $max';
  }

  @override
  String get errorPrinter => 'Принтер катасы';

  @override
  String get errorFiscal => 'Фискализация катасы';

  @override
  String get errorPayment => 'Төлөм катасы';

  @override
  String get errorSync => 'Синхрондоо катасы';

  @override
  String get errorNoInternet => 'Интернет байланышы жок';

  @override
  String get errorTryAgain => 'Кайра аракет кылыңыз';

  @override
  String get helpTitle => 'Маалымат';

  @override
  String get helpTips => 'Кеңештер';

  @override
  String get helpShortcuts => 'Ысык баскычтар';

  @override
  String get helpRelatedScreens => 'Байланышкан бөлүмдөр';

  @override
  String get helpKey => 'Баскыч';

  @override
  String get helpAction => 'Аракет';

  @override
  String get navSale => 'Сатуу';

  @override
  String get navRefund => 'Кайтаруу';

  @override
  String get navShift => 'Смена';

  @override
  String get navHistory => 'Тарых';

  @override
  String get navTables => 'Столдор';

  @override
  String get navOrders => 'Заказдар';

  @override
  String get navQueue => 'Кезек';

  @override
  String get navIntake => 'Кабыл алуу';

  @override
  String get navAgents => 'Контрагенттер';

  @override
  String get navSupply => 'Кабылдоо';

  @override
  String get navCash => 'Касса';

  @override
  String get navSettings => 'Жөндөөлөр';

  @override
  String get navSync => 'Шайкештирүү';

  @override
  String get navMore => 'Дагы';

  @override
  String get navAdditional => 'Кошумча';

  @override
  String get navLockScreen => 'Кулпулоо';

  @override
  String get navMain => 'Негизги';

  @override
  String get loginEnterSystem => 'Системага кирүү';

  @override
  String get loginWithoutPin => 'PIN-сиз кирүү';

  @override
  String get loginShiftOpen => 'Смена ачык';

  @override
  String get loginShiftClosed => 'Смена жабык';

  @override
  String get loginShiftUnknown => 'Смена: касса жооп берген жок';

  @override
  String get saleQuickProducts => 'Тез товарлар';

  @override
  String get saleIncrease => 'Көбөйтүү';

  @override
  String get saleDecrease => 'Азайтуу';

  @override
  String get saleMark => 'Маркировка';

  @override
  String get saleDataMatrix => 'Маркировка (DataMatrix)';

  @override
  String get saleHeld => 'Чек кийинкиге калтырылды';

  @override
  String get saleNoDeferredSales => 'Кийинкиге калтырылган чектер жок';

  @override
  String get saleDeferredListNotPermitted =>
      'Кийинкиге калтырылган чектер сизге ачык эмес: «чекти кийинкиге калтыруу» укугу керек. Аны администратор укуктар жөндөөлөрүндө берет; укугу жоктун бардыгына касса баш тартат.';

  @override
  String get saleDeferNotPermitted =>
      'Чекти кийинкиге калтыра албайсыз: «чекти кийинкиге калтыруу» укугу керек. Аны администратор укуктар жөндөөлөрүндө берет; укугу жоктун бардыгына касса баш тартат.';

  @override
  String get saleReceiptNo => 'Чек №';

  @override
  String get salePositions => 'Товарлар';

  @override
  String get saleSearchHint => 'Товар издөө (аты же штрих-код)';

  @override
  String get refundWithReceipt => 'ЧЕК МЕНЕН';

  @override
  String get refundWithoutReceiptUpper => 'ЧЕКСИЗ';

  @override
  String get refundLoadReceipt => 'Чекти жүктөө';

  @override
  String get refundSearchProducts => 'Товарларды издөө';

  @override
  String get refundSelectAll => 'Баарын тандоо';

  @override
  String get refundDeselectAll => 'Баарын алуу';

  @override
  String refundMaxQuantity(String max) {
    return 'Максимум: $max';
  }

  @override
  String get refundConfirmTitle => 'Кайтарууну ырастаңыз';

  @override
  String refundSelectedItems(int count) {
    return 'Тандалган позициялар: $count';
  }

  @override
  String get refundSuccessMsg => 'Кайтаруу ийгиликтүү аяктады';

  @override
  String get refundSearchHint => 'Кайтаруу үчүн товар издөө';

  @override
  String get paymentRefundTitle => 'Кайтаруу';

  @override
  String get paymentPayTitle => 'Төлөм';

  @override
  String get paymentRefundBtn => 'КАЙТАРУУ';

  @override
  String get paymentPayBtn => 'ТӨЛӨӨ';

  @override
  String get paymentChangeLabel => 'Кайтарым:';

  @override
  String get paymentSuccessRefund => 'Кайтаруу аяктады';

  @override
  String get paymentSuccessPay => 'Төлөм ийгиликтүү';

  @override
  String get paymentCardType => 'Накталай эмес';

  @override
  String get paymentToPay => 'Төлөөгө';

  @override
  String get paymentBonusLabel => 'Бонустар';

  @override
  String get paymentTotalToPay => 'Жалпы төлөө';

  @override
  String get paymentByCard => 'Карта менен';

  @override
  String get paymentRemainLabel => 'Калды';

  @override
  String get shiftBills => 'Купюралар';

  @override
  String get shiftTotalAmount => 'Жалпы сумма';

  @override
  String get shiftOperations => 'Операциялар';

  @override
  String get shiftOpened => 'Смена ачылды';

  @override
  String get shiftClosed => 'Смена жабылды';

  @override
  String get shiftOverAgeTitle => 'Смена 24 сааттан ашык турат';

  @override
  String get shiftOverAgeMessage =>
      'Сатуу бөгөттөлдү. Иштөөнү улантуу үчүн учурдагы сменаны жаап, жаңысын ачыңыз.';

  @override
  String get shiftOverAgeCloseAtTill =>
      'Сатуу бөгөттөлдү. Иштөөнү улантуу үчүн сменаны кассада жаап, жаңысын ачыңыз.';

  @override
  String shiftSince(String time) {
    return '$time бери';
  }

  @override
  String get shiftSystem => 'Система';

  @override
  String get shiftEntered => 'Киргизилди';

  @override
  String get shiftRecounting => 'Купюралар боюнча кайра эсептөө';

  @override
  String get shiftManualEntry => 'Кол менен сумма киргизүү';

  @override
  String get shiftCashOps => 'Касса операциялары';

  @override
  String get shiftOpenAction => 'Смена ачуу';

  @override
  String get shiftCloseAction => 'Смена жабуу';

  @override
  String get historyOperations => 'Операциялар тарыхы';

  @override
  String get historyResetFilters => 'Фильтрлерди тазалоо';

  @override
  String get historyRefresh => 'Жаңыртуу';

  @override
  String get historyNoRecords => 'Жазуулар жок';

  @override
  String get historyChangeFilters => 'Фильтрлерди өзгөртүп көрүңүз';

  @override
  String get historyEmpty => 'Операциялар тарыхы бош';

  @override
  String get historyFilterTitle => 'Фильтрлер';

  @override
  String get historyPeriod => 'Мезгил';

  @override
  String get historyOpType => 'Операция түрү';

  @override
  String get historySearchHint => 'Чек номери, сумма...';

  @override
  String historyType(String type) {
    return 'Түрү:';
  }

  @override
  String get historyPrint => 'Чекти басып чыгаруу';

  @override
  String agentFound(int count) {
    return 'Табылды: $count';
  }

  @override
  String get agentWithDebt => 'Карызы бар гана';

  @override
  String get agentSearchHint => 'Аты же телефону боюнча издөө...';

  @override
  String get agentNewClient => 'Жаңы клиент';

  @override
  String get agentNameRequired => 'Аты *';

  @override
  String get agentEnterName => 'Клиенттин атын киргизиңиз';

  @override
  String get agentPhoneLabel => 'Телефон';

  @override
  String get agentIinLabel => 'БИН/ЖСН';

  @override
  String get agentIinHint => '12 сан';

  @override
  String get agentDeleteQuestion => 'Клиентти жок кылуу?';

  @override
  String agentDeleteConfirmMsg(String name) {
    return '$name жок кылганга ишенесизби?';
  }

  @override
  String get agentDeleted => 'Клиент жок кылынды';

  @override
  String get agentFoundExisting => 'Клиент табылды';

  @override
  String get supplyTitle => 'Товар кабылдоо';

  @override
  String get supplySaved => 'Кабылдоо сакталды';

  @override
  String get supplySaveError => 'Сактоо катасы';

  @override
  String get supplyCancelQuestion => 'Кабылдоону жокко чыгаруу?';

  @override
  String get supplyDataLost => 'Киргизилген бардык маалыматтар жоголот.';

  @override
  String supplyProducts(int count) {
    return 'Товарлар: $count';
  }

  @override
  String get supplyBarcodeHint => 'Штрих-код же артикул';

  @override
  String get supplyComment => 'Комментарий';

  @override
  String get supplyCommentHint => 'Комментарий жазыңыз...';

  @override
  String get supplyNotFound => 'Товар табылган жок';

  @override
  String get supplySelectSupplier => 'Жеткирүүчүнү тандаңыз';

  @override
  String get supplySelectAccount => 'Эсепти тандаңыз';

  @override
  String supplyBalance(String amount) {
    return 'Баланс: $amount';
  }

  @override
  String get supplyPurchasePrice => 'Келүү баасы';

  @override
  String get supplySerialNumbers => 'Сериялык номерлер';

  @override
  String get supplySerialHint => 'S/N киргизиңиз же сканерлеңиз';

  @override
  String supplySerialCount(int count, int expected) {
    return '$expected ичинен $count';
  }

  @override
  String get supplySerialMismatch =>
      'Сериялык номерлердин саны санга дал келбейт';

  @override
  String get supplyInvalidQty => 'Туура санды киргизиңиз';

  @override
  String get supplyInvalidPrice => 'Туура бааны киргизиңиз';

  @override
  String get inventoryTitle => 'Инвентаризация';

  @override
  String get inventoryFullCount => 'Толук инвентаризация';

  @override
  String get inventoryFullCountSubtitle =>
      'Скандалбаган товарлардын калдыгын нөлгө түшүрүү';

  @override
  String get inventoryStart => 'Баштоо';

  @override
  String get inventoryFinish => 'Аяктоо';

  @override
  String get inventoryScanHint => 'Штрих-кодду сканерлеңиз';

  @override
  String get inventoryScanProducts => 'Товарларды санап чыгуу үчүн сканерлеңиз';

  @override
  String get inventoryPressStart => 'Инвентаризация үчүн \"Баштоо\" басыңыз';

  @override
  String inventoryProductCount(int count) {
    return 'Товарлар: $count';
  }

  @override
  String inventoryDiscrepancies(int count) {
    return 'Айырмачылыктар: $count';
  }

  @override
  String get inventoryExpected => 'Күтүлдү:';

  @override
  String get inventoryActual => 'Факт:';

  @override
  String get inventoryProduct => 'Товар';

  @override
  String get inventoryExpectedQty => 'Күтүлгөн';

  @override
  String get inventoryActualQty => 'Чыныгы';

  @override
  String get inventoryDiscrepancy => 'Айырмачылык';

  @override
  String get inventoryActualLabel => 'Чыныгы саны';

  @override
  String get inventoryFinishQuestion => 'Инвентаризацияны аяктоо?';

  @override
  String get inventoryCompleted => 'Инвентаризация аякталды';

  @override
  String get writeoffTitle => 'Эсептен чыгаруу';

  @override
  String get writeoffReason => 'Себеп';

  @override
  String get writeoffProduct => 'Товар';

  @override
  String get writeoffScanHint => 'Штрих-кодду сканерлеңиз';

  @override
  String get writeoffCommentHint => 'Милдеттүү эмес';

  @override
  String get writeoffReasonBreakage => 'Сынуу';

  @override
  String get writeoffReasonExpired => 'Мөөнөтү өтүп кеткен';

  @override
  String get writeoffReasonDamage => 'Бузулуу';

  @override
  String get writeoffReasonLoss => 'Жоголуу';

  @override
  String get writeoffReasonOther => 'Башка';

  @override
  String get writeoffCancelQuestion => 'Эсептен чыгарууну жокко чыгаруу?';

  @override
  String get writeoffSaved => 'Эсептен чыгаруу сакталды';

  @override
  String get settingsTitle => 'Жөндөөлөр';

  @override
  String get settingsPosInfo => 'Касса маалыматы';

  @override
  String get settingsPosName => 'Касса аталышы';

  @override
  String get settingsCompany => 'Компания';

  @override
  String get settingsIin => 'ЖСН/БИН';

  @override
  String get settingsPosId => 'POS ID';

  @override
  String get settingsStoreId => 'Дүкөн ID';

  @override
  String get settingsNotSpecified => 'Көрсөтүлгөн эмес';

  @override
  String get settingsAppVersion => 'Колдонмо версиясы';

  @override
  String get settingsVersion => 'Версия';

  @override
  String get settingsPlatform => 'Платформа';

  @override
  String get settingsLanguage => 'Интерфейс тили';

  @override
  String get settingsLanguageChanged => 'Тил өзгөртүлдү';

  @override
  String get settingsCurrency => 'Валюта';

  @override
  String get settingsCurrencySymbol => 'Белги';

  @override
  String get settingsCurrencyCode => 'Код';

  @override
  String get settingsCountry => 'Өлкө';

  @override
  String get settingsAdditional => 'Кошумча жөндөөлөр';

  @override
  String get settingsTransport => 'Транспорт';

  @override
  String get settingsTransportDesc => 'Маалыматтарды шайкештирүү жөндөөлөрү';

  @override
  String get settingsPrinter => 'Принтер';

  @override
  String get settingsPrinterDesc => 'Чектерди басып чыгаруу жөндөөлөрү';

  @override
  String get settingsFiscal => 'Фискализация';

  @override
  String get settingsFiscalDesc => 'WebKassa, ОФД, КНС';

  @override
  String get settingsTelegram => 'Telegram';

  @override
  String get settingsTelegramDesc => 'Telegram интеграциясы жана каналдар';

  @override
  String get settingsPermissions => 'Уруксаттар';

  @override
  String get settingsPermissionsDesc => 'Кассирлерге уруксаттар';

  @override
  String get fiscalTitle => 'Фискализация';

  @override
  String get fiscalOperator => 'Фискалдык оператор';

  @override
  String get fiscalWebkassa => 'WebKassa жөндөөлөрү';

  @override
  String get fiscalTaxpayer => 'Салык төлөөчүнүн маалыматы';

  @override
  String get fiscalVatSettings => 'КНС жөндөөлөрү';

  @override
  String get fiscalVatPayer => 'КНС төлөөчү';

  @override
  String get fiscalPrintVat => 'Чекте КНС басуу';

  @override
  String get fiscalSaved => 'Жөндөөлөр сакталды';

  @override
  String get fiscalSaveError => 'Сактоо катасы';

  @override
  String get printerSettingsTitle => 'Принтер жөндөөлөрү';

  @override
  String get printerConnectionType => 'Туташуу түрү';

  @override
  String get printerAddress => 'Принтер дареги';

  @override
  String get printerPaperWidth => 'Кагаз эни';

  @override
  String get printerTesting => 'Тестирлөө';

  @override
  String get printerReady => 'Даяр';

  @override
  String get printerNotConnected => 'Туташкан эмес';

  @override
  String get printerPaperOut2 => 'Кагаз жок';

  @override
  String get printerCoverOpen => 'Капкагы ачык';

  @override
  String get printerPrinting => 'Басып чыгаруу...';

  @override
  String get printerCheckStatus => 'Текшерүү...';

  @override
  String get printerPrintSuccess => 'Басып чыгаруу ийгиликтүү';

  @override
  String get paymentNotFiscalized => 'Чек фискалдашпады — төлөм катталды';

  @override
  String get paymentFiscalModuleAbsent =>
      'Фискалдаштыруу модулу жеткиликсиз — чектер фискалдашпайт';

  @override
  String get cashDrawerOpenError => 'Акча кутучасы ачылган жок';

  @override
  String get printerPrintError => 'Басып чыгаруу катасы';

  @override
  String get printerCheckBtn => 'Текшерүү';

  @override
  String get printerTestReceipt => 'Тесттик чек';

  @override
  String get printerPort => 'Порт';

  @override
  String get cashOperationTitle => 'Касса операциясы';

  @override
  String get cashWithdrawal => 'Алуу';

  @override
  String get cashCommentRequired => 'Комментарий *';

  @override
  String get cashCommentOptional => 'Комментарий';

  @override
  String get cashCommentHint => 'Комментарий жазыңыз...';

  @override
  String get cashEnterAmountMsg => 'Сумманы киргизиңиз';

  @override
  String get cashPositiveOnly => 'Сумма оң болушу керек';

  @override
  String get cashInsufficient => 'Кассада акча жетишсиз';

  @override
  String get cashInvalidAmount => 'Туура сумманы киргизиңиз';

  @override
  String get cashInDrawer => 'Кассада:';

  @override
  String get telegramTitle => 'Telegram жөндөөлөрү';

  @override
  String get telegramAuth => 'Авторизация';

  @override
  String get telegramSync => 'Шайкештирүү';

  @override
  String get telegramNotifications => 'Билдирмелерди иштетүү';

  @override
  String get telegramAutoSync => 'Автошайкештирүү';

  @override
  String get telegramSyncData => 'Маалыматтарды автоматтык шайкештирүү';

  @override
  String get telegramSyncInterval => 'Шайкештирүү аралыгы';

  @override
  String get telegramForceSync => 'Мажбурлоо шайкештирүү';

  @override
  String get telegramFullSync => 'Толук шайкештирүү';

  @override
  String get telegramRecreateChannels => 'Каналдарды кайра түзүү';

  @override
  String get telegramLogout => 'Telegram-дан чыгуу';

  @override
  String get telegramSyncComplete => 'Шайкештирүү аякталды';

  @override
  String get telegramSyncError => 'Шайкештирүү катасы';

  @override
  String get telegramLogoutComplete => 'Чыгуу аткарылды';

  @override
  String get chatTitle => 'Кызматкерлер чаты';

  @override
  String chatParticipants(int count) {
    return '$count катышуучу';
  }

  @override
  String get chatConnected => 'Туташты';

  @override
  String get chatDisconnected => 'Байланыш жок';

  @override
  String get chatNoMessages => 'Билдирүүлөр жок';

  @override
  String get chatStartConversation => 'Команда менен баарлашыңыз';

  @override
  String get chatMessageHint => 'Билдирүү...';

  @override
  String get chatSearch => 'Издөө';

  @override
  String get chatSearchHint => 'Издөө текстин киргизиңиз...';

  @override
  String get chatMembers => 'Катышуучулар';

  @override
  String get chatLinkTelegram => 'Telegram байлоо';

  @override
  String get chatCopied => 'Көчүрүлдү';

  @override
  String get chatReply => 'Жооп берүү';

  @override
  String get chatCopy => 'Көчүрүү';

  @override
  String get chatDeleteMsg => 'Билдирүүнү жок кылуу?';

  @override
  String get chatDeleteConfirm =>
      'Билдирүү бардык катышуучулар үчүн жок кылынат.';

  @override
  String get chatPhoto => 'Фото';

  @override
  String get chatDocument => 'Документ';

  @override
  String get chatLocation => 'Жайгашуу';

  @override
  String get chatCamera => 'Камера';

  @override
  String get chatGallery => 'Галерея';

  @override
  String get chatSelectSource => 'Булакты тандаңыз';

  @override
  String get updateAvailable => 'Жаңыртуу жеткиликтүү';

  @override
  String get updateInProgress => 'Жаңыртылууда...';

  @override
  String updateAutoIn(int seconds) {
    return 'Автожаңыртуу $seconds сек кийин';
  }

  @override
  String get updateNowBtn => 'Азыр жаңыртуу';

  @override
  String get updateLater => 'Кийин';

  @override
  String get updateSkip => 'Өткөрүп жиберүү';

  @override
  String get updateBtn => 'Жаңыртуу';

  @override
  String get storageWarningTitle => 'Дискте орун аз';

  @override
  String get storageWarningMsg =>
      'Кассанын туруктуу иштеши үчүн эң аз дегенде 2 ГБ бошотуңуз.';

  @override
  String get storageUnderstood => 'Түшүнүктүү';

  @override
  String get errorCritical => 'Олуттуу ката';

  @override
  String get errorAppProblem => 'Колдонмо маселеге учурады';

  @override
  String get errorDescription => 'Ката сүрөттөмөсү:';

  @override
  String get errorTechnical => 'Техникалык маалыматтар';

  @override
  String get errorRetry => 'Кайталоо';

  @override
  String get errorOpenFolder => 'Папканы ачуу';

  @override
  String get errorOtherVersion => 'Башка версия';

  @override
  String get errorExit => 'Чыгуу';

  @override
  String get switchOn => 'Күйгүзүү';

  @override
  String get switchOff => 'Өчүрүү';

  @override
  String get keyboardSpace => 'Боштук';

  @override
  String get keyboardHide => 'Клавиатураны жашыруу';

  @override
  String get keyboardShow => 'Клавиатураны көрсөтүү';

  @override
  String get commentReceipt => 'Чекке комментарий';

  @override
  String get commentReceiptHint => 'Комментарий жазыңыз...';

  @override
  String get productNameLabel => 'Товар аталышы';

  @override
  String get productNameHint => 'Аталышын киргизиңиз...';

  @override
  String get nothingFound => 'Эч нерсе табылган жок';

  @override
  String get datePlaceholder => 'КК.АА.ЖЖЖЖ';

  @override
  String get timePlaceholder => 'СС:ММ';

  @override
  String get dateTimePlaceholder => 'КК.АА.ЖЖЖЖ СС:ММ';

  @override
  String get selectPeriod => 'Мезгилди тандаңыз';

  @override
  String get bonusProgram => 'Бонус программасы';

  @override
  String get enterPhone => 'Клиенттин телефон номерин киргизиңиз';

  @override
  String get enterSmsCode => 'SMS-тен кодду киргизиңиз';

  @override
  String resendIn(int seconds) {
    return '$seconds сек кийин кайра жөнөтүү';
  }

  @override
  String get resendCode => 'Кодду кайра жөнөтүү';

  @override
  String get availableBonuses => 'Жеткиликтүү бонустар:';

  @override
  String get useBonuses => 'Бонустарды эсептен чыгаруу';

  @override
  String get deferredSales => 'Кийинкиге калтырылган сатуулар';

  @override
  String get noDeferredSales => 'Кийинкиге калтырылган сатуулар жок';

  @override
  String get fiscalErrors => 'Фискализация каталары';

  @override
  String get selectAllErrors => 'Баарын тандоо';

  @override
  String get retrySelected => 'Кайталоо';

  @override
  String receiptNo(String number) {
    return 'Чек №$number';
  }

  @override
  String get dontAskAgain => 'Кайра сурабоо';

  @override
  String get deleteTitle => 'Жок кылуу';

  @override
  String deleteItemConfirm(String name) {
    return '\"$name\" жок кылганга ишенесизби?';
  }

  @override
  String get exitTitle => 'Чыгуу';

  @override
  String get exitConfirm => 'Чыгууга ишенесизби?';

  @override
  String get exitBtn => 'Чыгуу';

  @override
  String get valueCannotBeNegative => 'Маани терс болушу мүмкүн эмес';

  @override
  String maxPercent(String percent) {
    return 'Максимум $percent%';
  }

  @override
  String maxAmount(String amount) {
    return 'Максимум $amount';
  }

  @override
  String get enterValidNumber => 'Туура санды киргизиңиз';

  @override
  String get discountAmount => 'Арзандатуу суммасы:';

  @override
  String discountLimitPercent(String percent, String source) {
    return '$percent % чейин уруксат — $source';
  }

  @override
  String discountLimitAmount(String amount, String source) {
    return '$amount чейин уруксат — $source';
  }

  @override
  String discountApprovalAbove(String percent) {
    return '$percent % жогору улуунун ырастоосу керек';
  }

  @override
  String get sumLabel => 'Сумма';

  @override
  String get enterAmount => 'Сумманы киргизиңиз';

  @override
  String get amountMustBePositive => 'Сумма оң болушу керек';

  @override
  String get notEnoughCashInDrawer => 'Кассада акча жетишсиз';

  @override
  String get enterValidAmount => 'Туура сумманы киргизиңиз';

  @override
  String get inDrawer => 'Кассада:';

  @override
  String get commentOptional => 'Комментарий (милдеттүү эмес)';

  @override
  String get operationReason => 'Операция себеби...';

  @override
  String get positions => 'позициялар';

  @override
  String get enterWeight => 'Салмакты киргизиңиз';

  @override
  String get weightMustBePositive => 'Салмак оң болушу керек';

  @override
  String maxWeightValue(String max, String unit) {
    return 'Максимум $max $unit';
  }

  @override
  String get unitPcs => 'даана';

  @override
  String get unitKg => 'кг';

  @override
  String lowStorageTooltip(String gb) {
    return 'Орун аз: $gb GB';
  }

  @override
  String storageFree(String gb) {
    return 'Бош: $gb GB';
  }

  @override
  String get storageRecommendation =>
      'Кассанын туруктуу иштеши үчүн эң аз дегенде 2 GB бош орун сунушталат.\n\nДискте орун бошотуңуз же администраторго кайрылыңыз.';

  @override
  String lowStorageBanner(String gb) {
    return 'Бош орун аз: $gb GB. Туруктуу иштөө үчүн эң аз дегенде 2 GB бошотуу сунушталат.';
  }

  @override
  String lowStorageTooltipShort(String gb) {
    return 'Дискте орун аз: $gb GB';
  }

  @override
  String get cashier => 'Кассир:';

  @override
  String get buyer => 'Сатып алуучу:';

  @override
  String receiptHeader(int number) {
    return 'ЧЕК #$number';
  }

  @override
  String get receiptDiscountItem => 'Арзандатуу:';

  @override
  String get receiptSubtotalLabel => 'Аралык сумма';

  @override
  String get receiptPayment => 'Төлөм:';

  @override
  String get fiscalMark => 'ФБ:';

  @override
  String remainingStock(String qty) {
    return 'Калд: $qty';
  }

  @override
  String get tableHeaderName => 'Аталышы';

  @override
  String get tableHeaderPrice => 'Баасы';

  @override
  String get tableHeaderQty => 'Саны';

  @override
  String get tableHeaderTotal => 'Жалпы';

  @override
  String get emptyReceipt => 'Чек бош';

  @override
  String get addProductsViaSearch =>
      'Издөө аркылуу товар кошуңуз\nже штрих-кодду сканерлеңиз';

  @override
  String get addProductsViaSearchShort => 'Издөө аркылуу товар кошуңуз';

  @override
  String get priceLabel => 'Баасы';

  @override
  String get receiptTotalLabel => 'Чек боюнча жалпы';

  @override
  String get positionsLabel => 'Позициялар';

  @override
  String get toPayLabel => 'ТӨЛӨӨГӨ';

  @override
  String get payBtn => 'ТӨЛӨӨ';

  @override
  String get totalLabel => 'Жалпы:';

  @override
  String posAndQty(int positions, String qty) {
    return '$positions поз. / $qty даана';
  }

  @override
  String get modeRetail => 'Чекене';

  @override
  String get modeWholesale => 'ДҮҢҮНӨН';

  @override
  String get quickProducts => 'Тез товарлар';

  @override
  String get editProduct => 'Түзөтүү';

  @override
  String get labelComment => 'Комментарий';

  @override
  String get selectPackage => 'Фасовканы тандаңыз';

  @override
  String packageQty(String qty) {
    return '$qty даана';
  }

  @override
  String get allBreadcrumb => 'Баары';

  @override
  String maxBonusPercent(int percent) {
    return 'Чек суммасынын $percent%-на чейин эсептен чыгарса болот';
  }

  @override
  String get insufficientBonuses => 'Бонустар жетишсиз';

  @override
  String get enterValidPhone => 'Туура телефон номерин киргизиңиз';

  @override
  String errorsCount(int count) {
    return '$count ката';
  }

  @override
  String selectAllCount(int count) {
    return 'Баарын тандоо ($count)';
  }

  @override
  String retryCount(int count) {
    return 'Кайталоо ($count)';
  }

  @override
  String receiptHash(int number) {
    return 'Чек #$number';
  }

  @override
  String get enterIntegerNumber => 'Бүтүн санды киргизиңиз';

  @override
  String enterDigits(int length) {
    return '$length сан киргизиңиз';
  }

  @override
  String get drawerPrimary => 'Негизги';

  @override
  String get drawerSecondary => 'Кошумча';

  @override
  String get tooltipMore => 'Дагы';

  @override
  String get statusOnline => 'Online';

  @override
  String get statusOffline => 'Offline';

  @override
  String get statusSyncing => 'Синхрондоо...';

  @override
  String get thankYouForPurchase => 'Сатып алганыңызга рахмат!';

  @override
  String get searchProductHint => 'Товар издөө (аты же штрих-код)';

  @override
  String get actionDefer => 'Кийинкиге калтыруу';

  @override
  String get actionDeferredList => 'Кийинкиге калтырылгандар';

  @override
  String get actionMark => 'Маркировка';

  @override
  String get actionWeigh => 'Весы';

  @override
  String get actionPrintLabel => 'Ценник';

  @override
  String get supplierRepayTitle => 'Погасить долг поставщику';

  @override
  String supplierRepayCurrentDebt(String amount) {
    return 'Текущий долг: $amount';
  }

  @override
  String get supplierRepayNoDebt => 'Долга перед поставщиком нет';

  @override
  String get supplierRepayAmountLabel => 'Сумма оплаты';

  @override
  String get supplierRepayAmountError => 'Введите сумму больше 0';

  @override
  String get supplierRepaySubmit => 'Оплатить поставщику';

  @override
  String get supplierRepayDone => 'Оплата поставщику проведена';

  @override
  String get supplierRepayError => 'Ошибка проведения оплаты';

  @override
  String get actionIncrease => 'Көбөйтүү';

  @override
  String get actionDecrease => 'Азайтуу';

  @override
  String get restaurantSettings => 'Ресторан режими';

  @override
  String get restaurantSettingsDesc => 'Столдор, зоналар, сервис алымы';

  @override
  String get restaurantOperatingMode => 'Иштөө режими';

  @override
  String get restaurantModeRetail => 'Чекене соода';

  @override
  String get restaurantModeRetailDesc => 'Дүкөндөр үчүн стандарттуу POS';

  @override
  String get restaurantModeRestaurant => 'Ресторан';

  @override
  String get restaurantModeRestaurantDesc => 'Столдор, заказдар, сервис алымы';

  @override
  String get restaurantModeService => 'Сервис';

  @override
  String get restaurantModeServiceDesc => 'Кабыл алуу, кезек';

  @override
  String get restaurantZoneManagement => 'Зоналарды башкаруу';

  @override
  String get restaurantZoneAdd => 'Зона кошуу';

  @override
  String get restaurantZoneRename => 'Атын өзгөртүү';

  @override
  String get restaurantZonePresets => 'Алдын ала орнотуулар';

  @override
  String get restaurantZoneHall => 'Зал';

  @override
  String get restaurantZoneTerrace => 'Терраса';

  @override
  String get restaurantZoneVip => 'VIP';

  @override
  String get restaurantZoneBar => 'Бар';

  @override
  String get restaurantZoneBooth => 'Кабинка';

  @override
  String get restaurantZoneKaraoke => 'Караоке';

  @override
  String get restaurantZoneVeranda => 'Веранда';

  @override
  String get restaurantZonePrivate => 'Жеке бөлмө';

  @override
  String get restaurantTableManagement => 'Столдорду башкаруу';

  @override
  String get restaurantTableAdd => 'Стол кошуу';

  @override
  String get restaurantTableEdit => 'Столду өзгөртүү';

  @override
  String get restaurantTableName => 'Стол аты';

  @override
  String get restaurantTableCapacity => 'Сыйымдуулук';

  @override
  String get restaurantTableZone => 'Зона';

  @override
  String get restaurantTableSortOrder => 'Тартип';

  @override
  String get restaurantTableDeactivate => 'Столду өчүрүү';

  @override
  String restaurantTableDeactivateConfirm(String name) {
    return '«$name» столун өчүрүү керекпи?';
  }

  @override
  String get restaurantServiceCharge => 'Сервис алымы';

  @override
  String get restaurantServiceChargeEnabled => 'Сервис алымын иштетүү';

  @override
  String get restaurantServiceChargePercent => 'Сервис алымы пайызы';

  @override
  String get restaurantTableFree => 'Бош';

  @override
  String get restaurantTableOccupied => 'Ээлөнгөн';

  @override
  String get restaurantTableReserved => 'Брондолгон';

  @override
  String get restaurantTableDirty => 'Тазалоо';

  @override
  String get restaurantOrderDineIn => 'Залда';

  @override
  String get restaurantOrderTakeout => 'Алып кетүү';

  @override
  String get restaurantOrderDelivery => 'Жеткирүү';

  @override
  String get restaurantAllZones => 'Бардык зоналар';

  @override
  String get restaurantNoTables => 'Столдор жок';

  @override
  String get restaurantNoTablesHint =>
      'Ресторан жөндөөлөрүндө столдорду кошуңуз';

  @override
  String get restaurantGoToSettings => 'Жөндөөлөргө өтүү';

  @override
  String get restaurantOrdersEmpty => 'Активдүү заказдар жок';

  @override
  String restaurantOrderItems(int count) {
    return '$count позиция';
  }

  @override
  String restaurantOrderGuests(int count) {
    return 'Конокторо: $count';
  }

  @override
  String restaurantOrderWaiter(String name) {
    return 'Официант: $name';
  }

  @override
  String restaurantOrderElapsed(int minutes) {
    return '$minutes мин';
  }

  @override
  String get restaurantNoOrder => 'Активдүү заказ жок';

  @override
  String get restaurantOpenOrder => 'Заказ ачуу';

  @override
  String get restaurantCloseOrder => 'Заказды жабуу';

  @override
  String get restaurantAddItems => 'Позиция кошуу';

  @override
  String get restaurantGoToPayment => 'Төлөмгө';

  @override
  String get restaurantTransfer => 'Которуу';

  @override
  String get restaurantSplitBill => 'Бөлүү';

  @override
  String get restaurantChangeStatus => 'Статусту өзгөртүү';

  @override
  String get restaurantSetFree => 'Бош';

  @override
  String get restaurantSetReserved => 'Брондоо';

  @override
  String get restaurantSetDirty => 'Тазалоо керек';

  @override
  String get restaurantCreateOrder => 'Жаңы заказ';

  @override
  String get restaurantPartySize => 'Конок саны';

  @override
  String get restaurantOrderType => 'Заказ түрү';

  @override
  String get restaurantWaiter => 'Официант';

  @override
  String get restaurantNote => 'Эскертүү';

  @override
  String get restaurantDeliveryAddress => 'Жеткирүү дареги';

  @override
  String get restaurantDeliveryPhone => 'Телефон';

  @override
  String get restaurantTransferTitle => 'Заказды которуу';

  @override
  String restaurantTransferCurrent(String table) {
    return 'Азыркы: $table';
  }

  @override
  String get restaurantTransferSelectFree => 'Бош столду тандаңыз:';

  @override
  String get restaurantMergeTitle => 'Объединить столы';

  @override
  String restaurantMergeTarget(String table) {
    return 'В стол: $table';
  }

  @override
  String get restaurantMergeSelectSources =>
      'Выберите столы для присоединения:';

  @override
  String get restaurantMergeNoOpenTables => 'Нет других занятых столов';

  @override
  String restaurantMergeConfirm(int count) {
    return 'Объединить ($count)';
  }

  @override
  String get restaurantMergeDone => 'Столы объединены';

  @override
  String get restaurantMergeNeedTarget =>
      'На текущем столе нет открытого заказа';

  @override
  String get restaurantSplitTitle => 'Эсепти бөлүү';

  @override
  String get restaurantSplitEvenly => 'Тең';

  @override
  String get restaurantSplitByItems => 'Позициялар боюнча';

  @override
  String get restaurantSplitGuestCount => 'Конок саны';

  @override
  String restaurantSplitPerGuest(String amount) {
    return 'Ар бирине: $amount';
  }

  @override
  String restaurantSplitGuest(int number) {
    return 'Конок $number';
  }

  @override
  String get restaurantSplitApply => 'Колдонуу';

  @override
  String get restaurantSplitPaymentTitle => 'Коноктор боюнча төлөм';

  @override
  String get restaurantSplitPaymentProceed => 'Төлөмгө';

  @override
  String get restaurantPreCheckPrinted => 'Пре-чек принтерге жөнөтүлдү';

  @override
  String get restaurantPreCheckFailed => 'Пре-чек басып чыгаруу катасы';

  @override
  String get restaurantSubtotal => 'Аралык сумма';

  @override
  String restaurantServiceChargeLine(String percent) {
    return 'Сервис алымы ($percent%)';
  }

  @override
  String restaurantOrderNumber(int number) {
    return 'Заказ #$number';
  }

  @override
  String restaurantTakeoutNumber(int number) {
    return 'Алып кетүү #$number';
  }

  @override
  String restaurantDeliveryNumber(int number) {
    return 'Жеткирүү #$number';
  }

  @override
  String get restaurantSaved => 'Ресторан жөндөөлөрү сакталды';

  @override
  String get restaurantQuickActions => 'Тез аракеттер';

  @override
  String get restaurantNoItems => 'Товарлар жок';

  @override
  String restaurantTableSeats(int count) {
    return '$count орун';
  }

  @override
  String get restaurantOrderTab => 'Заказ';

  @override
  String get restaurantMenuTab => 'Меню';

  @override
  String restaurantGuestLabel(int number) {
    return 'Конок $number';
  }

  @override
  String get restaurantRemoveItem => 'Товарды жок кылуу';

  @override
  String get restaurantPrintPrecheck => 'Алдын ала чек';

  @override
  String get restaurantNewTakeout => 'Алып кетүү';

  @override
  String get restaurantNewDelivery => 'Жеткирүү';

  @override
  String get setupSectionOrganization => 'Уюм';

  @override
  String get setupSectionContact => 'Байланыш адам';

  @override
  String get setupSectionAddress => 'Даректер';

  @override
  String get setupSectionCashBox => 'Касса';

  @override
  String get setupSectionUsers => 'Ким иштейт';

  @override
  String get setupSectionSecurity => 'Код менен кирүү';

  @override
  String get setupSectionScanner => 'Сканер';

  @override
  String get setupSectionScale => 'Таразы';

  @override
  String get setupSectionDisplay => 'Сатып алуучунун экраны';

  @override
  String get setupSectionTerminal => 'Төлөм терминалы';

  @override
  String get setupSectionCashback => 'Накталай кайтаруу';

  @override
  String get setupTaxIdExplanation =>
      'Салык номери ар бир чекте басылат жана фискалдык кызматка жөнөтүлөт. Бул жердеги ката салык органы менен биринчи салыштырууда гана билинет — чектер сатып алуучуларга берилгенден кийин.';

  @override
  String get setupFiscalCredentialsExplanation =>
      'Реквизиттерди фискалдык оператор берет. Алар туура эмес болсо, чектер адаттагыдай басылат, бирок фискалдык кызматка жетпейт — айырма сатуу учурунда эмес, салыштырууда байкалат.';

  @override
  String get setupKktNumberExplanation =>
      'ККМ номери кассаны оператордогу катталышы менен байланыштырат. Бул жердеги ката чектерди башка касса атынан жөнөтөт жана муну кассанын өзүнөн байкоо мүмкүн эмес.';

  @override
  String setupStepProgress(int current, int total) {
    return '$current / $total кадам';
  }

  @override
  String get setupStepChecking => 'Текшерүү';

  @override
  String get setupStepTelegram => 'Telegram';

  @override
  String get setupStepCountry => 'Өлкө';

  @override
  String get setupStepOrganization => 'Уюм';

  @override
  String get setupStepVat => 'КНС';

  @override
  String get setupStepUsers => 'Колдонуучулар';

  @override
  String get setupStepWorkMode => 'Иштөө режими';

  @override
  String get setupStepPos => 'Касса';

  @override
  String get setupStepFiscal => 'Фискализация';

  @override
  String get setupStepEquipment => 'Жабдуулар';

  @override
  String get setupStepTerminals => 'Терминалдар';

  @override
  String get setupStepOperatingMode => 'Бизнес түрү';

  @override
  String get setupStepBusinessRules => 'Эрежелер';

  @override
  String get setupStepSummary => 'Текшерүү';

  @override
  String get setupStepComplete => 'Даяр';

  @override
  String get setupCheckingSettings => 'Жөндөөлөр текшерилүүдө...';

  @override
  String get setupStateUnreadableTitle => 'Касса жооп берген жок';

  @override
  String get setupStateUnreadableBody =>
      'Устат касса абалын окумайынча жөндөөнү баштабайт: болбосо ал иштеп жаткан дүкөндү өчүрүп жиберишi мүмкүн. Кассанын күйгүзүлүп, тармакта жеткиликтүү экенин текшериңиз.';

  @override
  String get wtUnavailableTitle => 'Касса менен байланыш жок';

  @override
  String get wtUnavailableBody =>
      'Терминал маалыматты WebTransport аркылуу гана алат. Камдык жол жок: байланыш болбосо, көрсөтүүгө эч нерсе жок, ал эми эскини жаңы катары көрсөтүү — эч нерсе көрсөтпөгөндөн жаман. Кассанын күйгүзүлгөнүн текшерип, кайталаңыз.';

  @override
  String wtUnavailableReason(String reason) {
    return 'Себеби: $reason';
  }

  @override
  String get terminalHomeWhoHeader => 'Ким кирди';

  @override
  String get terminalHomeUserLabel => 'Кассир';

  @override
  String get terminalHomeSaleNote =>
      'Себет, чектин номери жана смена кассага таандык — терминал чекти көрсөтөт жана зым аркылуу буйрук берет. Чек басып чыгаруу, фискалдаштыруу жана акча кутусу кассада калат.';

  @override
  String get wtNotPortedTitle => 'Бул экран азырынча кассада гана';

  @override
  String get wtNotPortedBody =>
      'Браузер терминалы маалыматты зым аркылуу алат, жана экран бул жерде анын бардык келишимдери зым үстүнөн иштей алганда пайда болот. Бул азырынча үйрөнө элек. Аны бош көрсөткөндөн көрө, түз айткан жакшы.';

  @override
  String wtNotPortedLocation(String location) {
    return 'Багыт: $location';
  }

  @override
  String get setupWelcomeTitle => 'TelePOS-ко кош келиңиз!';

  @override
  String get setupCountryDescription =>
      'Валюта жана салыктарды жөндөө үчүн өлкөңүздү тандаңыз';

  @override
  String setupPriceExample(String amount) {
    return 'Мисалы: $amount';
  }

  @override
  String setupVatRateLabel(int rate) {
    return 'КНС: $rate%';
  }

  @override
  String get setupOrganizationTitle => 'Уюм маалыматтары';

  @override
  String get setupOrganizationDescription =>
      'Компанияңыз жөнүндө маалыматты киргизиңиз';

  @override
  String get setupCompanyNameLabel => 'Уюмдун аталышы';

  @override
  String get setupCompanyNameHint => 'ЖЧК \"Менин компаниям\"';

  @override
  String setupTaxIdDigits(int length) {
    return '$length сан';
  }

  @override
  String get setupLegalAddressLabel => 'Юридикалык дарек';

  @override
  String get setupActualAddressLabel => 'Дүкөндүн чыныгы дареги';

  @override
  String get setupOwnerNameLabel => 'Жетекчинин А.Ж.А.';

  @override
  String get setupPhoneLabel => 'Телефон';

  @override
  String get setupVatTitle => 'Кошумча наркка салык';

  @override
  String get setupVatDescription => 'Уюмуңуздун салык режимин тандаңыз';

  @override
  String get setupVatPayerTitle => 'КНС төлөөчү';

  @override
  String setupVatPayerRate(String rate) {
    return 'КНС ченеми: $rate%';
  }

  @override
  String get setupVatPayerRateUnknown => 'КНС ченеми өлкөгө жараша болот';

  @override
  String get setupVatPayerDescription =>
      'Чектерде КНС бөлүнүп көрсөтүлөт.\nЖалпы салык системасындагы компаниялар үчүн милдеттүү.';

  @override
  String get setupVatNonPayerTitle => 'КНС-сиз';

  @override
  String get setupVatNonPayerSubtitle => 'КНС колдонулбайт';

  @override
  String get setupVatNonPayerDescription =>
      'Чектерде КНС бөлүнбөйт.\nЖөнөкөйлөштүрүлгөн системадагы ЖИ үчүн.';

  @override
  String get setupWorkModeTitle => 'Иштөө режими';

  @override
  String get setupWorkModeDescription => 'Кассаңыз кантип иштээрин тандаңыз';

  @override
  String get setupAutonomousTitle => 'Автономдук режим';

  @override
  String get setupAutonomousSubtitle => 'Интернетсиз иштөө';

  @override
  String get setupAutonomousDescription =>
      'Касса толугу менен автономдук иштейт.\nМаалыматтар жергиликтүү гана сакталат.\nКассалар ортосунда шайкештирүү жок.';

  @override
  String get setupNetworkTitle => 'Тармактык режим';

  @override
  String get setupNetworkConfigured => 'Telegram жөндөлгөн';

  @override
  String get setupNetworkRequired => 'Telegram талап кылынат';

  @override
  String get setupNetworkDescription =>
      'Кассалар ортосунда маалыматтарды шайкештирүү.\nБулутка камдык көчүрмө.\nTelegram-да отчеттор жана билдирмелер.';

  @override
  String get setupNetworkRequiresTelegram =>
      'Тармактык режим үчүн Telegram жөндөө зарыл';

  @override
  String get setupOperatingModeTitle => 'Бизнес түрү';

  @override
  String get setupOperatingModeDescription => 'Бизнесиңиздин түрүн тандаңыз';

  @override
  String get setupRetailTitle => 'Чекене касса';

  @override
  String get setupRetailSubtitle => 'Дүкөн, дарыкана, супермаркет';

  @override
  String get setupRetailDescription =>
      'Чекене соода үчүн стандарттуу POS.\nСатуулар, кайтаруулар, товар кабылдоо.\nСменалар жана отчеттуулук.';

  @override
  String get setupRestaurantTitle => 'Ресторан / Кафе';

  @override
  String get setupRestaurantSubtitle => 'Столдор, заказдар, жеткирүү';

  @override
  String get setupRestaurantDescription =>
      'Столдорду жана залды башкаруу.\nАлып кетүү жана жеткирүү.\nЭсепти бөлүү жана сервис алымы.';

  @override
  String get setupServiceTitle => 'Сервис борбору';

  @override
  String get setupServiceSubtitle => 'Оңдоо, кызматтар, процедуралар';

  @override
  String get setupServiceDescription =>
      'Оңдоого/тейлөөгө кабыл алуу.\nЗаказ-наряддар жана иштер белгилери.\nСтатусту көзөмөлдөө жана берүү.';

  @override
  String get setupPosConfigTitle => 'Кассаны жөндөө';

  @override
  String get setupPosConfigDescription =>
      'Касса аппаратынын параметрлерин көрсөтүңүз';

  @override
  String get setupCashBoxNameLabel => 'Касса аталышы';

  @override
  String get setupCashBoxNameHint => 'Касса 1';

  @override
  String get setupPosIdLabel => 'Касса ID';

  @override
  String get setupPrinterConfigTitle => 'Чек принтери';

  @override
  String get setupPaperWidthLabel => 'Кагаз эни';

  @override
  String get setupPaperWidth58 => '58 мм (32 символ)';

  @override
  String get setupPaperWidth80 => '80 мм (48 символ)';

  @override
  String get setupPrinterHeaderLabel => 'Чек баш сөзү';

  @override
  String get setupPrinterHeaderHint => 'Дүкөн аталышы\nДарек';

  @override
  String get setupPrinterFooterLabel => 'Чек аягы';

  @override
  String get setupPrinterFooterHint => 'Сатып алганыңызга рахмат!';

  @override
  String get setupFiscalNotRequired =>
      'Сиздин өлкө үчүн фискализация талап кылынбайт';

  @override
  String get setupFiscalDescription =>
      'Фискалдык оператор менен туташууну жөндөңүз';

  @override
  String get setupEnableWebkassa => 'WebKassa иштетүү';

  @override
  String get setupEnableOfd => 'ОФД иштетүү';

  @override
  String get setupWebkassaDescription =>
      'WebKassa аркылуу чектерди фискализациялоо (Казакстан)';

  @override
  String get setupOfdDescription =>
      'ОФД аркылуу чектерди фискализациялоо (Россия)';

  @override
  String get setupSkipLater => 'Өткөрүп жиберүү (кийин жөндөө)';

  @override
  String get setupWebkassaAccountTitle => 'WebKassa аккаунту';

  @override
  String get setupWebkassaAccountIdLabel => 'Аккаунт ID';

  @override
  String get setupWebkassaAccountIdHint => 'WebKassa-дагы ID-ңиз';

  @override
  String get setupWebkassaTokenLabel => 'Аккаунт токени';

  @override
  String get setupWebkassaTokenHint => 'API токен';

  @override
  String get setupWebkassaPosTitle => 'WebKassa кассасы';

  @override
  String get setupWebkassaPosIdLabel => 'Касса ID';

  @override
  String get setupWebkassaPosIdHint => 'WebKassa-дагы касса ID';

  @override
  String get setupWebkassaPosTokenLabel => 'Касса токени';

  @override
  String get setupWebkassaPosTokenHint => 'Касса токени';

  @override
  String get setupWebkassaFactoryNoLabel => 'ККМ заводдук номери';

  @override
  String get setupOfdParamsTitle => 'ОФД параметрлери';

  @override
  String get setupOfdInnLabel => 'Уюмдун ИНН';

  @override
  String get setupOfdKktRegNoLabel => 'ККТ каттоо номери';

  @override
  String get setupOfdFnNoLabel => 'ФН номери';

  @override
  String get setupOfdUrlLabel => 'ОФД URL';

  @override
  String get setupEquipmentTitle => 'Жабдуулар';

  @override
  String get setupEquipmentDescription => 'Туташкан жабдууларды жөндөңүз';

  @override
  String get setupEquipmentPrinter => 'Чек принтери';

  @override
  String get setupEquipmentScanner => 'Штрих-код сканери';

  @override
  String get setupEquipmentScales => 'Тараза';

  @override
  String get setupEquipmentCashDrawer => 'Акча кутусу';

  @override
  String get setupEquipmentDisplay => 'Сатып алуучу дисплейи';

  @override
  String get setupConnectionTypeLabel => 'Туташуу түрү';

  @override
  String get setupConnectionUsb => 'USB';

  @override
  String get setupConnectionBluetooth => 'Bluetooth';

  @override
  String get setupConnectionWifi => 'Wi-Fi / Ethernet';

  @override
  String get setupConnectionSerial => 'COM-порт';

  @override
  String get setupConnectionNone => 'Тандалган эмес';

  @override
  String get setupPrinterIpLabel => 'Принтердин IP-дареги';

  @override
  String get setupPrinterMacLabel => 'Принтердин MAC-дареги';

  @override
  String get setupPrinterNameLabel => 'Принтердин аталышы';

  @override
  String get setupPrinterNameHint => 'Ашкана принтери';

  @override
  String get setupScannerTypeLabel => 'Сканер түрү';

  @override
  String get setupScannerCamera => 'Аппараттын камерасы';

  @override
  String get setupScannerUsb => 'USB-сканер';

  @override
  String get setupScannerBluetooth => 'Bluetooth-сканер';

  @override
  String get setupScalePortLabel => 'COM-порт';

  @override
  String get setupBaudRateLabel => 'Ылдамдык (baud rate)';

  @override
  String get setupCashDrawerConnected => 'Принтерге туташкан';

  @override
  String get setupCashDrawerConnectedDesc => 'Принтердин буйругу менен ачылат';

  @override
  String get setupSkip => 'Өткөрүп жиберүү';

  @override
  String get setupPaymentTerminalsTitle => 'Төлөм терминалдары';

  @override
  String get setupPaymentTerminalsDescription =>
      'Төлөм системалары менен интеграцияны жөндөңүз';

  @override
  String get setupKaspiIpLabel => 'Терминалдын IP-дареги';

  @override
  String get setupPortLabel => 'Порт';

  @override
  String get setupApiUrlLabel => 'API URL';

  @override
  String get setupApiKeyLabel => 'API ачкыч';

  @override
  String get setupNoTerminalsAvailable =>
      'Сиздин аймак үчүн жеткиликтүү төлөм терминалдары жок';

  @override
  String get setupBusinessRulesTitle => 'Бизнес-эрежелер';

  @override
  String get setupBusinessRulesDescription =>
      'Кассанын иштөө эрежелерин жөндөңүз';

  @override
  String get setupPermissionsTitle => 'Уруксаттар';

  @override
  String get setupAllowDiscounts => 'Арзандатуулар';

  @override
  String get setupAllowDiscountsDesc => 'Арзандатуу колдонууга уруксат берүү';

  @override
  String get setupAllowDebtSales => 'Карызга сатуу';

  @override
  String get setupAllowDebtSalesDesc => 'Кредитке сатууга уруксат берүү';

  @override
  String get setupAllowPriceEdit => 'Бааларды түзөтүү';

  @override
  String get setupAllowPriceEditDesc =>
      'Сатууда бааларды өзгөртүүгө уруксат берүү';

  @override
  String get setupAllowCashInOut => 'Касса операциялары';

  @override
  String get setupAllowCashInOutDesc => 'Накталай акча салуу жана берүү';

  @override
  String get setupBlockPriceDecrease => 'Баа түшүрүүнү бөгөттөө';

  @override
  String get setupBlockPriceDecreaseDesc =>
      'Белгиленген баадан төмөн сатууга тыюу салуу';

  @override
  String get setupLimitsTitle => 'Лимиттер';

  @override
  String get setupAllowBigAmount => 'Чоң суммалар';

  @override
  String get setupAllowBigAmountDesc =>
      '1 000 000-дон ашкан операцияларга уруксат берүү';

  @override
  String get setupCashWithdrawalLimitLabel => 'Накталай берүү лимити';

  @override
  String get setupCashWithdrawalLimitHelper =>
      'Лимитсиз болушу үчүн бош калтырыңыз';

  @override
  String get setupLoyaltyTitle => 'Лоялдуулук программасы';

  @override
  String get setupCashbackLabel => 'Кешбэк';

  @override
  String get setupCashbackDesc => 'Бонус чегерүүнү иштетүү';

  @override
  String get setupCashbackRateLabel => 'Кешбэк пайызы';

  @override
  String get setupRoundingTitle => 'Тегеректөө';

  @override
  String get setupDiscountRounding => 'Арзандатууларды тегеректөө';

  @override
  String get setupWeightRounding => 'Салмак товарларды тегеректөө';

  @override
  String get setupRoundingNone => 'Тегеректөөсүз';

  @override
  String get setupRoundingUp1 => '1-ге чейин (жогору)';

  @override
  String get setupRoundingDown1 => '1-ге чейин (төмөн)';

  @override
  String get setupRoundingUp5 => '5-ке чейин (жогору)';

  @override
  String get setupRoundingDown5 => '5-ке чейин (төмөн)';

  @override
  String get setupRoundingUp10 => '10-го чейин (жогору)';

  @override
  String get setupRoundingDown10 => '10-го чейин (төмөн)';

  @override
  String get setupFiscalDisablesRounding =>
      'Фискализация иштетилгенде тегеректөө автоматтык түрдө өчүрүлөт';

  @override
  String get setupUserCreationTitle => 'Колдонуучуларды түзүү';

  @override
  String get setupUserCreationDescription =>
      'Касса менен иштөө үчүн колдонуучуларды түзүңүз';

  @override
  String get setupAdminLabel => 'Администратор';

  @override
  String get setupAdminSubtitle => 'Касса ээси';

  @override
  String get setupUserNameLabel => 'Аты';

  @override
  String get setupUserPinLabel => 'PIN';

  @override
  String get setupUserPinConfirmLabel => 'Ырастоо';

  @override
  String get setupAdminPinDefault => 'Демейки боюнча: 0000';

  @override
  String get setupSellerLabel => 'Сатуучу';

  @override
  String get setupSellerOptional => 'Кошумча';

  @override
  String get setupSellerPinDefault => 'Демейки боюнча: 1111';

  @override
  String get setupAdminPinMismatch =>
      'Администратордун PIN-коддору дал келбейт';

  @override
  String get setupSummaryTitle => 'Маалыматтарды текшериңиз';

  @override
  String get setupSummaryDescription => 'Баары туура көрсөтүлгөнүн текшериңиз';

  @override
  String get setupSummaryCountry => 'Өлкө';

  @override
  String get setupSummaryCurrency => 'Валюта';

  @override
  String get setupSummaryFormat => 'Формат';

  @override
  String get setupSummaryVat => 'КНС';

  @override
  String get setupSummaryTelegram => 'Telegram';

  @override
  String get setupSummaryStatus => 'Статус';

  @override
  String get setupConfigured => 'Жөндөлгөн';

  @override
  String get setupNotConfigured => 'Жөндөлгөн эмес';

  @override
  String get setupSummaryOrganization => 'Уюм';

  @override
  String get setupSummaryName => 'Аталышы';

  @override
  String get setupSummaryAddress => 'Дарек';

  @override
  String get setupSummaryWorkMode => 'Иштөө режими';

  @override
  String get setupSummaryMode => 'Режим';

  @override
  String get setupSummaryAutonomous => 'Автономдук (тармаксыз)';

  @override
  String get setupSummaryNetwork => 'Тармактык (шайкештирүү)';

  @override
  String get setupSummaryPos => 'Касса';

  @override
  String get setupSummaryId => 'ID';

  @override
  String get setupEnabled => 'Иштетилген';

  @override
  String get setupDisabled => 'Өчүрүлгөн';

  @override
  String get setupSummaryFiscalType => 'Түрү';

  @override
  String get setupSummaryEquipment => 'Жабдуулар';

  @override
  String get setupSummaryPrinter => 'Принтер';

  @override
  String get setupSummaryScanner => 'Сканер';

  @override
  String get setupSummaryScales => 'Тараза';

  @override
  String get setupSummaryCashDrawer => 'Акча кутусу';

  @override
  String get setupSummaryTerminals => 'Төлөм терминалдары';

  @override
  String get setupSummaryRules => 'Бизнес-эрежелер';

  @override
  String get setupSummaryDiscounts => 'Арзандатуулар';

  @override
  String get setupSummaryDebtSales => 'Карызга';

  @override
  String get setupSummaryCashback => 'Кешбэк';

  @override
  String get setupSummaryBigAmount => 'Чоң суммалар';

  @override
  String get setupSummaryUsers => 'Колдонуучулар';

  @override
  String get setupSummaryAdmin => 'Администратор';

  @override
  String get setupSummarySeller => 'Сатуучу';

  @override
  String get setupCompleteTitle => 'Жөндөө аяктады!';

  @override
  String get setupCompleteSubtitle => 'Касса иштөөгө даяр';

  @override
  String get setupStartWork => 'Иштей баштоо';

  @override
  String setupVatPayerSummary(String rate) {
    return 'КНС төлөөчү ($rate%)';
  }

  @override
  String get setupSummaryWkPosId => 'Касса ID WK';

  @override
  String get setupSummaryOfdInn => 'ИНН';

  @override
  String get setupScalesConfigured => 'Жөндөлгөн';

  @override
  String get setupScalesNotConfigured => 'Жөндөлгөн эмес';

  @override
  String get setupCashDrawerOn => 'Күйгүзүлгөн';

  @override
  String get setupAllowed => 'Уруксат берилген';

  @override
  String get setupDenied => 'Тыюу салынган';

  @override
  String get setupAllowedFem => 'Уруксат берилген';

  @override
  String get setupDeniedFem => 'Тыюу салынган';

  @override
  String get setupCashbackOff => 'Өчүрүлгөн';

  @override
  String get setupBigAmountLimit => 'Лимит 100 000';

  @override
  String get setupDisplayPortLabel => 'COM-порт';

  @override
  String get telegramAuthSkip => 'Өткөрүп жиберүү (кийин жөндөө)';

  @override
  String get telegramInitializing => 'Инициализация';

  @override
  String get telegramErrorTdlib => 'TDLib катасы';

  @override
  String get telegramAuthLogin => 'Telegram-га кирүү';

  @override
  String get telegramAuthCodeStep => 'Ырастоо коду';

  @override
  String get telegramAuth2fa => 'Эки факторлуу аутентификация';

  @override
  String get telegramRegister => 'Каттоо';

  @override
  String get telegramSearchingChannels => 'Каналдарды издөө';

  @override
  String get telegramLoadingData => 'Маалыматтарды жүктөө';

  @override
  String get telegramOrgData => 'Уюм маалыматтары';

  @override
  String get telegramSetupChannels => 'Каналдарды жөндөө';

  @override
  String get telegramSetupEncryption => 'Шифрлөөнү жөндөө';

  @override
  String get telegramSetupComplete => 'Даяр';

  @override
  String get telegramInitializingLong => 'Telegram инициализацияланууда...';

  @override
  String get telegramConnecting => 'Telegram серверлерине туташуу';

  @override
  String get telegramTdlibNotFound => 'TDLib табылган жок';

  @override
  String get telegramTdlibErrorMessage =>
      'TDLib жергиликтүү китепканасы табылган жок.\nTelegram менен иштөө үчүн tdjson орнотуу зарыл.';

  @override
  String get telegramForWindows => 'Windows үчүн:';

  @override
  String get telegramWindowsInstructions =>
      '1. TDLib жүктөп алыңыз: github.com/tdlib/td/releases\n2. tdjson.dll файлын проекттин тамырына көчүрүңүз\n3. Же C:\\TDLib\\bin\\ ичине орнотуңуз';

  @override
  String get telegramPhoneAuthTitle => 'Телефон номери менен кирүү';

  @override
  String get telegramPhoneAuthDescription =>
      'Telegram аккаунтуңузга байланган телефон номерин киргизиңиз';

  @override
  String get telegramCountryCodeLabel => 'Өлкө коду';

  @override
  String get telegramPhoneNumber => 'Телефон номери';

  @override
  String get telegramGetCode => 'Кодду алуу';

  @override
  String get telegramRefreshQr => 'QR-кодду жаңыртуу';

  @override
  String get telegramSignUp => 'Каттоодон өтүү';

  @override
  String get telegramEnterStoreName => 'Дүкөн аталышын киргизиңиз';

  @override
  String get telegramInvalidBinIin => 'Туура БИН/ИИН киргизиңиз (12 сан)';

  @override
  String get telegramInvalidCode => 'Туура кодду киргизиңиз';

  @override
  String get telegramEnterPassword => 'Сырсөздү киргизиңиз';

  @override
  String get telegramCodeResent => 'Код кайра жөнөтүлдү';

  @override
  String get telegramEnterName => 'Атыңызды киргизиңиз';

  @override
  String get telegramManageAccount => 'Аккаунтту башкаруу';

  @override
  String get telegramNotificationsSection => 'Билдирмелер';

  @override
  String get telegramNotificationsDesc =>
      'Сатуулар, сменалар ж.б. жөнүндө билдирмелерди алуу';

  @override
  String get telegramNotifySales => 'Сатуу билдирмелери';

  @override
  String get telegramNotifySalesDesc => 'Чоң сатуулар, кайтаруулар';

  @override
  String get telegramNotifyShifts => 'Смена билдирмелери';

  @override
  String get telegramNotifyShiftsDesc => 'Сменалардын ачылышы жана жабылышы';

  @override
  String get telegramNotifyCritical => 'Олуттуу билдирмелер';

  @override
  String get telegramNotifyCriticalDesc => 'Каталар, OFD менен маселелер';

  @override
  String get telegramNotifyStock => 'Калдык билдирмелери';

  @override
  String get telegramNotifyStockDesc => 'Товарлардын жетишсиздиги';

  @override
  String get telegramSyncSettings => 'Шайкештирүү жөндөөлөрү';

  @override
  String get telegramAutoSyncDesc => 'Маалыматтарды автоматтык шайкештирүү';

  @override
  String get telegramSyncInterval1min => '1 мүнөт';

  @override
  String get telegramSyncInterval5min => '5 мүнөт';

  @override
  String get telegramSyncInterval15min => '15 мүнөт';

  @override
  String get telegramSyncInterval30min => '30 мүнөт';

  @override
  String get telegramSyncInterval1hour => '1 саат';

  @override
  String get telegramSystemChannels => 'Системалык каналдар';

  @override
  String get telegramRefresh => 'Жаңыртуу';

  @override
  String get telegramChannelsNotConnected =>
      'Каналдар туташкан эмес.\nАвтоматтык түзүү үчүн Telegram-га кириңиз.';

  @override
  String telegramChannelsConnected(int connected, int total) {
    return '$total каналдан $connected туташкан';
  }

  @override
  String telegramChannelsLoadError(String error) {
    return 'Каналдарды жүктөө катасы: $error';
  }

  @override
  String get telegramForceSyncDesc => 'Бардык маалыматтарды азыр шайкештирүү';

  @override
  String get telegramFullSyncDesc => 'Тазалап, баарын кайра шайкештирүү';

  @override
  String get telegramRecreateChannelsDesc =>
      'Системалык каналдарды кайра түзүү';

  @override
  String get telegramLogoutDesc => 'Telegram интеграциясын өчүрүү';

  @override
  String get telegramFullSyncWarning =>
      'Бул бардык шайкештирүү убакыт белгилерин тазалап, бардык маалыматтарды кайра жүктөйт. Операция көп убакыт алышы мүмкүн.';

  @override
  String get telegramRecreateChannelsWarning =>
      'Бул аракет бардык системалык каналдарды кайра түзөт. Каналдардагы учурдагы маалыматтар жоголот.';

  @override
  String get telegramLogoutWarning =>
      'Чыгууга ишенесизби? Шайкештирүү жана билдирмелер өчүрүлөт.';

  @override
  String get telegramChannelsRecreated => 'Каналдар кайра түзүлдү';

  @override
  String get telegramConnectedStatus => 'Туташкан';

  @override
  String get telegramNotConnected => 'Туташкан эмес';

  @override
  String get telegramAccountLabel => 'Telegram аккаунту';

  @override
  String get telegramLoginForSync => 'Маалыматтарды шайкештирүү үчүн кириңиз';

  @override
  String get channelDescSystemEvents => 'Системалык окуялар';

  @override
  String get channelDescSales => 'Сатуулар лентасы';

  @override
  String get channelDescAlerts => 'Олуттуу билдирмелер';

  @override
  String get channelDescReports => 'Отчеттор жана жыйынтыктар';

  @override
  String get channelDescSync => 'Маалыматтарды шайкештирүү';

  @override
  String get channelDescFiscal => 'Фискалдык окуялар';

  @override
  String get channelDescStaffChat => 'Кызматкерлер чаты';

  @override
  String get channelDescDataExchange => 'Маалымат алмашуу';

  @override
  String get channelDescTerminalStatus => 'Терминал статусу';

  @override
  String get channelDescBackup => 'МБ камдык көчүрмөлөрү';

  @override
  String get chatNoConnectionBanner =>
      'Байланыш жок. Билдирүүлөр калыбына келгенде жөнөтүлөт.';

  @override
  String get chatLinkTelegramForId => 'Чатта аныктоо үчүн Telegram байлаңыз';

  @override
  String chatSendError(String error) {
    return 'Жөнөтүү катасы: $error';
  }

  @override
  String chatFoundMessages(int count) {
    return '$count билдирүү табылды';
  }

  @override
  String get chatNoResults => 'Эч нерсе табылган жок';

  @override
  String get chatCopyUidInstructions =>
      'UID-ди башка системаларда колдонуу үчүн көчүрүңүз';

  @override
  String get chatUidExample => 'Мисалы: telepos@pos-1';

  @override
  String get chatServiceUnavailable => 'Кызмат жеткиликсиз';

  @override
  String get chatTelegramLinked => 'Telegram ийгиликтүү байланды';

  @override
  String get additionalLogout => 'Чыгуу';

  @override
  String get additionalLockCashier => 'Бөгөттөө';

  @override
  String get additionalPrinterAction => 'Принтер';

  @override
  String get additionalPrintLastReceipt => 'Акыркы чек';

  @override
  String get additionalSyncAction => 'Шайкештирүү';

  @override
  String get additionalCheckPrice => 'Бааны текшерүү';

  @override
  String get additionalMinimize => 'Кичирейтүү';

  @override
  String get additionalCustomers => 'Сатып алуучулар';

  @override
  String get additionalUpdateAction => 'Жаңыртуу';

  @override
  String get additionalExtraPrinter => 'Кошумча принтер';

  @override
  String get additionalSupplyAction => 'Кабылдоо';

  @override
  String get additionalLanguageAction => 'Тил';

  @override
  String get additionalKaspiPos => 'Kaspi POS';

  @override
  String get additionalPrinterEscPos => 'ESC/POS термопринтер';

  @override
  String get additionalPrinterNotConfigured => 'Принтер жөндөлгөн эмес';

  @override
  String get additionalPrinterWifi => 'Wi-Fi принтер';

  @override
  String get additionalPrinterWifiDesc => 'IP менен туташуу';

  @override
  String get additionalPrinterBluetooth => 'Bluetooth принтер';

  @override
  String get additionalPrinterBluetoothDesc => 'Аппараттарды издөө';

  @override
  String get additionalPrinterUsb => 'USB принтер';

  @override
  String get additionalPrinterSystem => 'Системалык принтер';

  @override
  String get additionalPrinterDisconnected => 'Принтер ажыратылган';

  @override
  String get additionalPrinterIpLabel => 'IP';

  @override
  String get additionalPrinterEnterIp => 'IP даректи киргизиңиз';

  @override
  String additionalPrinterConnecting(String address) {
    return '$address-ке туташуу...';
  }

  @override
  String get additionalPrinterConnectingUsb => 'USB принтерге туташуу...';

  @override
  String get additionalPrinterNotConnected => 'Принтер туташкан эмес';

  @override
  String get additionalPrintingLastReceipt => 'Акыркы чекти басып чыгаруу...';

  @override
  String get additionalTestReceiptTitle => '=== ТЕСТТИК ЧЕК ===';

  @override
  String get additionalReceiptPrinted => 'Чек басылды';

  @override
  String additionalPriceSearching(String query) {
    return 'Издөө: $query';
  }

  @override
  String get additionalMinimizing => 'Терезени кичирейтүү...';

  @override
  String get additionalLatestVersion => 'Акыркы версия орнотулган';

  @override
  String get additionalExtraPrinterTitle => 'Кошумча принтер';

  @override
  String get additionalExtraPrinterUsedFor => 'Кошумча принтер колдонулат:';

  @override
  String get additionalExtraPrinterLabels => 'Этикетка басып чыгаруу';

  @override
  String get additionalExtraPrinterKitchen => 'Ашканага басып чыгаруу';

  @override
  String get additionalExtraPrinterDuplicate => 'Чек көчүрмөсү';

  @override
  String get additionalKaspiPosTitle => 'Kaspi POS';

  @override
  String get additionalKaspiPosDesc =>
      'Kaspi менен төлөм кабыл алуу терминалы.';

  @override
  String get additionalKaspiPosNotConnected => 'Статус: Туташкан эмес';

  @override
  String additionalPrinterConnectedName(String name) {
    return 'Принтер туташтырылды: $name';
  }

  @override
  String additionalErrorWithMessage(String message) {
    return 'Ката: $message';
  }

  @override
  String get additionalPrinterUsbNotSupported =>
      'USB принтерлер колдоого алынбайт';

  @override
  String get additionalPrinterUsbConnected => 'USB принтер туташтырылды';

  @override
  String get additionalBarcodeLabel => 'Штрихкод';

  @override
  String get additionalBarcodeHint => 'Сканерлеңиз же киргизиңиз';

  @override
  String additionalTestReceiptProduct(String number) {
    return 'Товар $number';
  }

  @override
  String get additionalTestReceiptTotal => 'ЖАЛПЫ:';

  @override
  String get additionalTestReceiptThankYou => 'Сатып алганыңыз үчүн рахмат!';

  @override
  String get langRussian => 'Русский';

  @override
  String get langEnglish => 'English';

  @override
  String get langKazakh => 'Қазақша';

  @override
  String get langKyrgyz => 'Кыргызча';

  @override
  String get langUzbek => 'O\'zbekcha';

  @override
  String get transportFullSyncWarning =>
      'Бул бардык шайкештирүү белгилерин тазалап, бардык маалыматтарды кайра жүктөйт. Бул көп убакыт алышы мүмкүн. Улантасызбы?';

  @override
  String get transportSyncAbout => 'Шайкештирүү жөнүндө';

  @override
  String transportSyncStateError(String error) {
    return 'Шайкештирүү абалын жүктөө катасы: $error';
  }

  @override
  String get transportSyncInfoDialog =>
      'Ар бир маалымат түрү өз алдынча шайкештирилет. Акыркы шайкештирүүдөн кийин өзгөргөн элементтер гана берилет.\n\nАралык: 5 мүнөт (демейки боюнча)\nМаалыматтар берүү алдында AES-256-GCM менен шифрленет.';

  @override
  String get transportSyncNever => 'Эч качан';

  @override
  String get transportModeDescription =>
      'Сервер менен маалымат алмашуу ыкмасын тандаңыз';

  @override
  String get transportModeRest => 'REST API';

  @override
  String get transportModeRestDesc => 'Классикалык HTTP/WebSocket туташуу';

  @override
  String get transportModeTelegram => 'Telegram';

  @override
  String get transportModeTelegramDesc => 'Telegram транспорт катмары катары';

  @override
  String get transportModeHybrid => 'Гибриддик';

  @override
  String get transportModeHybridDesc => 'Telegram негизги, REST камдык';

  @override
  String get transportModeRecommended => 'Сунушталат';

  @override
  String transportSyncIntervalMinutes(int minutes) {
    return '$minutes мүнөт';
  }

  @override
  String get transportSyncOnConnectivity =>
      'Тармак калыбына келгенде шайкештирүү';

  @override
  String transportSyncIntervalOption(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes мүнөт',
      one: '$minutes мүнөт',
    );
    return '$_temp0';
  }

  @override
  String get transportEnableQueue => 'Операциялар кезеги';

  @override
  String get transportEnableQueueDesc =>
      'Тармак жок учурда операцияларды буферлөө';

  @override
  String get transportMaxQueueSize => 'Кезек көлөмү';

  @override
  String transportQueueSizeStatus(int size) {
    return '$size операция';
  }

  @override
  String get transportAutoCleanup => 'Автотазалоо';

  @override
  String get transportAutoCleanupDesc =>
      'Аяктаган операцияларды 7 күндөн кийин жок кылуу';

  @override
  String get transportNotifyChanges => 'Транспортту өзгөртүү';

  @override
  String get transportNotifyChangesDesc =>
      'Транспорт режими өзгөргөндө кабарлоо';

  @override
  String get transportNotifySyncErrors => 'Шайкештирүү каталары';

  @override
  String get transportNotifySyncErrorsDesc =>
      'Шайкештирүү каталары жөнүндө кабарлоо';

  @override
  String get transportNotifyOfflineOnline => 'Байланыш';

  @override
  String get transportNotifyConnectivityDesc => 'Туташуу өзгөргөндө кабарлоо';

  @override
  String get transportNotifyQueueFull => 'Кезек толду';

  @override
  String get transportNotifyQueueFullDesc => 'Кезек толгондо кабарлоо';

  @override
  String saleErrorInitiation(String error) {
    return 'Сатуу баштоо катасы: $error';
  }

  @override
  String get saleErrorNotInitialized => 'Сатуу башталган эмес';

  @override
  String get saleErrorEmpty => 'Чек бош';

  @override
  String saleErrorCompletion(String error) {
    return 'Сатууну аяктоо катасы: $error';
  }

  @override
  String saleErrorSearch(String error) {
    return 'Издөө катасы: $error';
  }

  @override
  String saleErrorDeferred(String error) {
    return 'Чекти кийинкиге калтыруу катасы: $error';
  }

  @override
  String get saleErrorDeferredNotFound =>
      'Кийинкиге калтырылган чек табылган жок';

  @override
  String saleErrorLoadingDeferred(String error) {
    return 'Кийинкиге калтырылган чекти жүктөө катасы: $error';
  }

  @override
  String get paymentCustomerDefault => 'Клиент';

  @override
  String get paymentErrorFormation =>
      'Төлөмдү түзүү мүмкүн болгон жок. Эсептердин жөндөөлөрүн текшериңиз.';

  @override
  String get paymentErrorSaving => 'Сатууну сактоо катасы';

  @override
  String paymentErrorProcessing(String error) {
    return 'Төлөмдү иштетүү катасы: $error';
  }

  @override
  String paymentAccountDefault(int id) {
    return 'Эсеп $id';
  }

  @override
  String refundErrorReceiptNotFound(String number) {
    return 'Чек #$number табылган жок';
  }

  @override
  String refundErrorLoadingReceipt(String error) {
    return 'Чекти жүктөө катасы: $error';
  }

  @override
  String refundErrorSearch(String error) {
    return 'Издөө катасы: $error';
  }

  @override
  String get refundErrorProductNotFound => 'Товар табылган жок';

  @override
  String get refundErrorNotAuthenticated => 'Колдонуучу авторизацияланган эмес';

  @override
  String refundErrorProcessing(String error) {
    return 'Кайтаруу катасы: $error';
  }

  @override
  String shiftErrorLoadingData(String error) {
    return 'Смена маалыматтарын жүктөө катасы: $error';
  }

  @override
  String shiftErrorOpening(String error) {
    return 'Сменаны ачуу катасы: $error';
  }

  @override
  String shiftErrorClosing(String error) {
    return 'Сменаны жабуу катасы: $error';
  }

  @override
  String shiftErrorPrinting(String error) {
    return 'Z-отчетту басып чыгаруу катасы: $error';
  }

  @override
  String get cashOpTypeInvestment => 'Салуу';

  @override
  String get cashOpTypeExpense => 'Чыгым';

  @override
  String get cashOpTypeDividend => 'Алуу';

  @override
  String get supplyNoName => 'Аты жок';

  @override
  String get supplyNoTitle => 'Аталышы жок';

  @override
  String get supplyErrorSupplierNotFound => 'Жеткирүүчү табылган жок';

  @override
  String supplyErrorSelectingSupplier(String error) {
    return 'Жеткирүүчүнү тандоо катасы: $error';
  }

  @override
  String get supplyErrorAccountNotFound => 'Эсеп табылган жок';

  @override
  String supplyErrorSelectingAccount(String error) {
    return 'Эсепти тандоо катасы: $error';
  }

  @override
  String supplyErrorAddingProduct(String error) {
    return 'Товар кошуу катасы: $error';
  }

  @override
  String get supplyErrorProductNotFound => 'Товар табылган жок';

  @override
  String get supplyErrorMissingFields =>
      'Бардык милдеттүү талааларды толтуруңуз';

  @override
  String supplyErrorSaving(String error) {
    return 'Сактоо катасы: $error';
  }

  @override
  String historyErrorLoading(String error) {
    return 'Тарыхты жүктөө катасы: $error';
  }

  @override
  String get syncTypeProducts => 'Товарлар';

  @override
  String get syncTypePrices => 'Баалар';

  @override
  String get syncTypeCategories => 'Категориялар';

  @override
  String get syncTypeAgents => 'Контрагенттер';

  @override
  String get syncTypeConfig => 'Жөндөөлөр';

  @override
  String get syncTypeSales => 'Сатуулар';

  @override
  String get syncTypeRefunds => 'Кайтаруулар';

  @override
  String get syncTypeCashOps => 'Касса операциялары';

  @override
  String get syncTypeShifts => 'Сменалар';

  @override
  String get syncTypeSupplies => 'Кабылдоолор';

  @override
  String get syncStepPreparing => 'Даярдоо...';

  @override
  String syncStepUploading(String type) {
    return 'Чыгаруу: $type';
  }

  @override
  String syncStepDownloading(String type) {
    return 'Жүктөө: $type';
  }

  @override
  String get syncCompleted => 'Шайкештирүү аяктады';

  @override
  String get loginErrorNoUsers => 'Каттоодон өткөн колдонуучулар жок';

  @override
  String loginErrorLoadingData(String error) {
    return 'Маалыматтарды жүктөө катасы: $error';
  }

  @override
  String get loginErrorSelectUser => 'Колдонуучуну тандаңыз';

  @override
  String get loginErrorIncompletePin => 'PIN-кодду киргизиңиз (минимум 4 сан)';

  @override
  String get loginErrorNoRsaKey =>
      'Ката: RSA ачкычы жөндөлгөн эмес. Администраторго кайрылыңыз.';

  @override
  String get loginErrorWrongPin => 'Туура эмес PIN-код';

  @override
  String get loginErrorSystemTime =>
      'Системалык убакыт туура эмес. Күн жана убакыт жөндөөлөрүн текшериңиз.';

  @override
  String get receiptLabelBin => 'БИН:';

  @override
  String get receiptLabelPhone => 'Тел:';

  @override
  String get receiptLabelReceiptNo => 'Чек №:';

  @override
  String get receiptLabelPosId => 'Касса:';

  @override
  String get receiptLabelDate => 'Күнү:';

  @override
  String get receiptLabelCashier => 'Кассир:';

  @override
  String get receiptLabelTable => 'Стол:';

  @override
  String get receiptLabelWaiter => 'Официант:';

  @override
  String get receiptLabelGuests => 'Конок:';

  @override
  String get receiptLabelCustomer => 'Клиент:';

  @override
  String get receiptLabelSubtotal => 'Аралык жыйынтык:';

  @override
  String get receiptLabelDiscount => 'Арзандатуу:';

  @override
  String get receiptLabelServiceCharge => 'Сервис алымы:';

  @override
  String get receiptLabelTotal => 'ЖАЛПЫ:';

  @override
  String receiptLabelVat(String percent) {
    return 'анын ичинде КНС $percent%:';
  }

  @override
  String get receiptLabelCash => 'Накталай:';

  @override
  String get receiptLabelCard => 'Карта:';

  @override
  String get receiptLabelChange => 'Кайтарым:';

  @override
  String get receiptLabelCheckReceipt => 'Чекти текшерүү:';

  @override
  String get receiptLabelItemName => 'Аталышы';

  @override
  String get receiptLabelQty => 'Сан';

  @override
  String get receiptLabelPrice => 'Баа';

  @override
  String get receiptLabelAmount => 'Сумма';

  @override
  String get receiptLabelItemDiscount => 'Арзандатуу:';

  @override
  String get receiptLabelFiscalBin => 'БИН:';

  @override
  String get receiptLabelFiscalNo => 'ФН:';

  @override
  String get receiptLabelFiscalSign => 'ФП:';

  @override
  String get receiptLabelVatCertificate => 'КНС:';

  @override
  String get receiptLabelOfflineMode => '*** ОФФЛАЙН ***';

  @override
  String get receiptLabelRefundHeader => '*** КАЙТАРУУ ***';

  @override
  String get receiptLabelRefundNo => 'Кайтаруу №:';

  @override
  String get receiptLabelReason => 'Себеп:';

  @override
  String get receiptLabelRefundTotal => 'КАЙТАРУУГА:';

  @override
  String get receiptLabelZReport => 'Z-ОТЧЕТ';

  @override
  String get receiptLabelShiftClosing => 'СМЕНА ЖАБУУ';

  @override
  String get receiptLabelShiftNo => 'Смена №:';

  @override
  String get receiptLabelShiftOpenTime => 'Ачылган:';

  @override
  String get receiptLabelShiftCloseTime => 'Жабылган:';

  @override
  String get receiptLabelSales => 'САТУУЛАР';

  @override
  String get receiptLabelQuantity => 'Саны:';

  @override
  String get receiptLabelCashSales => 'Накталай:';

  @override
  String get receiptLabelCardSales => 'Карта:';

  @override
  String get receiptLabelSalesTotal => 'Жалпы:';

  @override
  String get receiptLabelRefunds => 'КАЙТАРУУЛАР';

  @override
  String get receiptLabelRefundQty => 'Саны:';

  @override
  String get receiptLabelRefundAmount => 'Суммасы:';

  @override
  String get receiptLabelCashOperations => 'КАССА ОПЕРАЦИЯЛАРЫ';

  @override
  String get receiptLabelInvestments => 'Салуулар:';

  @override
  String get receiptLabelExpenses => 'Чыгымдар:';

  @override
  String get receiptLabelRevenue => 'КИРЕШE:';

  @override
  String get receiptLabelCashInDrawer => 'КАССАДА:';

  @override
  String get receiptLabelXReport => 'X-ОТЧЕТ';

  @override
  String get receiptLabelType => 'Түрү:';

  @override
  String get receiptLabelDescription => 'Сүрөттөмө:';

  @override
  String get receiptLabelDebtPayment => 'КАРЫЗДЫ ЖАБУУ';

  @override
  String get receiptLabelPreviousDebt => 'Карыз болгон:';

  @override
  String get receiptLabelPaidAmount => 'ТӨЛӨНДҮ:';

  @override
  String get receiptLabelRemainingDebt => 'Калдык:';

  @override
  String get receiptLabelTestPrint => 'TEST PRINT';

  @override
  String get receiptLabelThankYou => 'Сатып алганыңызга рахмат!';

  @override
  String get receiptLabelSaleReceipt => 'КАССАЛЫК ЧЕК';

  @override
  String get receiptLabelOfflineHeader => '*** ОФФЛАЙН РЕЖИМ ***';

  @override
  String get receiptLabelVatCertificateTitle => 'КНС күбөлүгү:';

  @override
  String get fiscalErrorBin12Digits => 'БИН 12 сандан турушу керек';

  @override
  String get fiscalErrorBinDigitsOnly => 'БИН сандардан гана турушу керек';

  @override
  String get fiscalErrorFiscalNoRequired => 'Фискалдык номер милдеттүү';

  @override
  String get fiscalErrorRnkRequired => 'РНК милдеттүү';

  @override
  String get fiscalErrorZnkRequired => 'ЗНК милдеттүү';

  @override
  String get fiscalErrorVatSerialRequired =>
      'КНС күбөлүгүнүн сериясы милдеттүү';

  @override
  String get fiscalErrorVatNumberRequired => 'КНС күбөлүгүнүн номери милдеттүү';

  @override
  String get telegramTabPhone => 'Телефон менен';

  @override
  String get telegramTabQr => 'QR-код';

  @override
  String get telegramQrAuthTitle => 'QR-код аркылуу кирүү';

  @override
  String get telegramQrAuthDescription =>
      'Телефонуңуздагы Telegram колдонмосунда QR-кодду сканерлеңиз';

  @override
  String get telegramQrTapToGenerate => 'QR-код түзүү үчүн\nбасыңыз';

  @override
  String get telegramQrHowToScan => 'Кантип сканерлөө:';

  @override
  String get telegramQrStep1 => 'Телефонуңузда Telegram ачыңыз';

  @override
  String get telegramQrStep2 => 'Жөндөөлөр → Түзмөктөр бөлүмүнө өтүңүз';

  @override
  String get telegramQrStep3 => '\"Түзмөктү туташтыруу\" басыңыз';

  @override
  String get telegramQrStep4 => 'QR-кодду сканерлеңиз';

  @override
  String get telegramEnterCode => 'Кодду киргизиңиз';

  @override
  String telegramCodeSentTo(String phone) {
    return 'Код Telegram-га жөнөтүлдү\n$phone номерине';
  }

  @override
  String get telegramCodeLabel => 'Ырастоо коду';

  @override
  String get telegramPasswordDescription =>
      'Telegram аккаунтуңуздун сырсөзүн киргизиңиз';

  @override
  String telegramPasswordHint(String hint) {
    return 'Кеңеш: $hint';
  }

  @override
  String get telegramPasswordLabel => 'Сырсөз';

  @override
  String get telegramRegistrationDescription =>
      'Бул номердеги аккаунт табылган жок.\nЖаңы Telegram аккаунтун түзүңүз.';

  @override
  String get telegramFirstNameLabel => 'Аты';

  @override
  String get telegramLastNameLabel => 'Фамилиясы (милдеттүү эмес)';

  @override
  String get telegramLoadingOrgData => 'Уюм маалыматтары жүктөлүүдө...';

  @override
  String get telegramSearchingExistingChannels =>
      'Учурдагы каналдар изделүүдө...';

  @override
  String get telegramFoundChannels =>
      'Уюм каналдары табылды.\nКонфигурация жүктөлүүдө...';

  @override
  String get telegramCheckingChannels => 'Каналдар текшерилүүдө...';

  @override
  String get telegramOrgDataNotLoaded =>
      'Маалыматтарды жүктөө мүмкүн болгон жок.\nУюмуңуз жөнүндө маалыматты киргизиңиз.';

  @override
  String get telegramOrgDataFirstRun =>
      'TelePOS-тун биринчи иштетилиши.\nУюмуңуз жөнүндө маалыматты киргизиңиз.';

  @override
  String get telegramStoreNameLabel => 'Дүкөн аталышы *';

  @override
  String get telegramStoreNameHint => 'Менин дүкөнүм';

  @override
  String get telegramBinLabel => 'Уюмдун БИН/ИИН *';

  @override
  String get telegramAddressLabel => 'Дарек (милдеттүү эмес)';

  @override
  String get telegramAddressHint => 'Бишкек ш., Мисал көч., 123';

  @override
  String get telegramPosIdLabel => 'Касса ID';

  @override
  String get telegramOwnerNameLabel => 'Ээсинин аты (милдеттүү эмес)';

  @override
  String get telegramImportantNote => 'Маанилүү';

  @override
  String get telegramOrgDataNote =>
      'Бул маалыматтар системалык каналдарды түзүү жана кассалар ортосунда шайкештирүү үчүн колдонулат. Башка түзмөктөрдө маалыматтар автоматтык жүктөлөт.';

  @override
  String get telegramCreatingChannels => 'Системалык каналдар түзүлүүдө...';

  @override
  String get telegramSettingUpEncryption => 'Шифрлөө жөндөлүүдө...';

  @override
  String get telegramSettingUp => 'Жөндөлүүдө...';

  @override
  String get telegramPleaseWait =>
      'Күтө туруңуз.\nБул бир аз убакыт алышы мүмкүн.';

  @override
  String get telegramSetupDone => 'Жөндөө аяктады!';

  @override
  String get telegramSetupDoneMessage =>
      'Telegram ийгиликтүү жөндөлдү.\nСистемалык каналдар түзүлдү.';

  @override
  String get telegramTermsNotice =>
      '\"Кодду алуу\" басуу менен, Telegram колдонуу шарттарына макулдугуңузду билдиресиз';

  @override
  String get telegramActionsSection => 'Аракеттер';

  @override
  String get chatNotConfigured => 'Чат жөндөлгөн эмес';

  @override
  String get chatCanDeleteOwnOnly =>
      'Өзүңүздүн билдирүүлөрүңүздү гана жок кыла аласыз';

  @override
  String get chatMessageDeleted => 'Билдирүү жок кылынды';

  @override
  String get chatDeleteFailed => 'Билдирүүнү жок кылуу мүмкүн болгон жок';

  @override
  String get chatTelegramNotLinked => 'Telegram байланган эмес';

  @override
  String get chatLinkInstructions =>
      'Кызматкерлер чатында аныктоо үчүн Telegram User ID-ңизди киргизиңиз.';

  @override
  String get chatLinkHowTo =>
      'ID-ни кантип билүү:\n1. Telegram-да @userinfobot ачыңыз\n2. /start басыңыз\n3. \"Id\" талаасындагы санды көчүрүңүз';

  @override
  String get chatLinkFailed =>
      'Байлоо мүмкүн болгон жок. Мүмкүн, бул ID мурдатан колдонулат.';

  @override
  String get chatPhotoSent => 'Фото жөнөтүлдү';

  @override
  String get chatPhotoFailed => 'Фото жөнөтүү мүмкүн болгон жок';

  @override
  String get chatPhotoError => 'Фото тандоодо ката';

  @override
  String get chatPhotoUnavailableWeb => 'Фото жөнөтүү веб-версияда жеткиликсиз';

  @override
  String get chatDocSent => 'Документ жөнөтүлдү';

  @override
  String get chatDocFailed => 'Документ жөнөтүү мүмкүн болгон жок';

  @override
  String get chatDocError => 'Документ тандоодо ката';

  @override
  String get chatDocUnavailableWeb =>
      'Документ жөнөтүү веб-версияда жеткиликсиз';

  @override
  String get chatDocPathError => 'Файлдын жолун алуу мүмкүн болгон жок';

  @override
  String get chatDocTooLarge => 'Файл өтө чоң (макс. 50 МБ)';

  @override
  String get chatLocationSent => 'Жайгашуу жөнөтүлдү';

  @override
  String get chatLocationFailed => 'Жайгашууну жөнөтүү мүмкүн болгон жок';

  @override
  String get chatLocationError => 'Жайгашууну алуу катасы';

  @override
  String get chatLocationUnavailableWeb =>
      'Геолокация веб-версияда жеткиликсиз';

  @override
  String get chatLocationDenied => 'Геолокацияга кирүү тыюу салынган';

  @override
  String get chatLocationDeniedForever =>
      'Геолокацияга кирүү биротоло тыюу салынган. Жөндөөлөрдөн өзгөртүңүз.';

  @override
  String get chatLocationServiceDisabled => 'Түзмөктө геолокацияны иштетиңиз';

  @override
  String get syncToUpload => 'Жүктөөгө';

  @override
  String get syncToDownload => 'Жүктөп алууга';

  @override
  String get syncDataTypeCol => 'Маалымат түрү';

  @override
  String get syncDirectionCol => 'Багыт';

  @override
  String get syncPendingCol => 'Күтүүдө';

  @override
  String get syncStatusCol => 'Статус';

  @override
  String get syncProgressCol => 'Жүрүшү';

  @override
  String get syncUpload => 'Жүктөө';

  @override
  String get syncDownload => 'Жүктөп алуу';

  @override
  String syncPendingCount(int count) {
    return 'Күтүүдө: $count';
  }

  @override
  String get syncInfoTelegram =>
      'Маалыматтар кассалар ортосунда Telegram аркылуу синхрондолот. Колдонуучулар бардык кассаларга жалпы.';

  @override
  String get syncAutoEnabled => 'Маалыматтар автоматтык синхрондолот';

  @override
  String get syncManualOnly => 'Кол менен гана синхрондоо';

  @override
  String syncMinutes(int count) {
    return '$count мин';
  }

  @override
  String get agentBinIin => 'ИНН/ИИН';

  @override
  String get agentLastOperation => 'Акыркы операция';

  @override
  String get agentNoAdditionalInfo => 'Кошумча маалымат жок';

  @override
  String get agentNoDebt => 'Карыз жок';

  @override
  String agentDeletedWithName(String name) {
    return 'Клиент \"$name\" өчүрүлдү';
  }

  @override
  String agentDeleteError(String error) {
    return 'Өчүрүү катасы: $error';
  }

  @override
  String get agentNewCustomer => 'Жаңы клиент';

  @override
  String get agentTypeCustomer => 'Кардар';

  @override
  String get agentTypeSupplier => 'Жеткирүүчү';

  @override
  String get agentNameHint => 'Клиенттин атын киргизиңиз';

  @override
  String get agentBinHint => '12 сан';

  @override
  String get agentCustomerFound => 'Клиент табылды';

  @override
  String get agentDeletedPhoneMsg => 'Бул телефон менен клиент өчүрүлгөн';

  @override
  String get agentRestoreQuestion => 'Калыбына келтирүү керекпи?';

  @override
  String get agentRestore => 'Калыбына келтирүү';

  @override
  String get kaspiTerminal => 'Kaspi POS Терминал';

  @override
  String get kaspiIpAddress => 'Терминал IP-дареги';

  @override
  String get kaspiInvalidIp => 'IP-дарек форматы туура эмес';

  @override
  String get kaspiPort => 'Порт';

  @override
  String get kaspiTesting => 'Текшерүү...';

  @override
  String get kaspiTest => 'ТЕСТ';

  @override
  String get kaspiDisconnected => 'Туташкан эмес';

  @override
  String get kaspiConnecting => 'Туташууда...';

  @override
  String get kaspiConnected => 'Байланыш орнотулду';

  @override
  String get kaspiNoConnection => 'Байланыш жок';

  @override
  String get kaspiTestPassed => 'Тест ийгиликтүү';

  @override
  String get kaspiTestFailed => 'Тест ийгиликсиз';

  @override
  String kaspiLatency(String ms) {
    return 'Кечигүү: $ms мс';
  }

  @override
  String kaspiTerminalInfo(String info) {
    return 'Терминал: $info';
  }

  @override
  String get splashSubtitle => 'Касса тутуму';

  @override
  String get splashInitializing => 'Инициализация...';

  @override
  String get splashLoadingOrg => 'Уюм маалыматтары жүктөлүүдө...';

  @override
  String get splashEnterPosKey => 'POS ачкычын киргизиңиз';

  @override
  String get splashEnterPosKeyMessage =>
      'Кассаны активдештирүү үчүн администратордон алынган ачкычты киргизиңиз.';

  @override
  String get splashPosKeyHint => 'XXXX-XXXX-XXXX-XXXX';

  @override
  String get splashKeyEmpty => 'Ачкыч бош болбошу керек';

  @override
  String get splashKeyTooShort => 'Ачкыч өтө кыска';

  @override
  String get splashKeyNotEntered => 'Ачкыч киргизилген жок';

  @override
  String get splashKeyRequiredMessage =>
      'POS ачкычсыз иштей албайт. Колдонмо жабылат.';

  @override
  String get splashDataCorrupted => 'Маалыматтар бузулган';

  @override
  String get splashDataCorruptedMessage =>
      'Колдонмонун милдеттүү маалыматтары жок же бузулган.\n\nАракетти тандаңыз:';

  @override
  String get splashReconfigure => 'Кайра тууралоо';

  @override
  String get splashExit => 'Чыгуу';

  @override
  String get splashDatabaseError => 'Маалыматтар базасынын катасы';

  @override
  String get splashDatabaseErrorMessage =>
      'Маалыматтар базасы бузулган же жеткиликсиз.\n\nКамдык көчүрмөдөн калыбына келтирүүгө же кассаны кайра тууралоого болот.';

  @override
  String get splashRestoreFromBackup => 'Камдык көчүрмөдөн калыбына келтирүү';

  @override
  String get splashSyncSuspended => 'Синхрондоо токтотулду';

  @override
  String get splashSyncSuspendedMessage =>
      'Маалыматтарды синхрондоо убактылуу токтотулду.\n\nКасса автономдук режимде иштейт. Байланыш калыбына келгенде маалыматтар синхрондолот.';

  @override
  String get splashAuthError =>
      'Авторизация катасы\n\nКирүү токени жараксыз же мөөнөтү бүткөн.\nЖаңы ачкыч алуу үчүн администраторго кайрылыңыз.';

  @override
  String get splashSupportEnded =>
      'Версия колдоого алынбайт\n\nКолдонмонун бул версиясы мындан ары колдоого алынбайт.\nАкыркы версияга жаңыртыңыз.';

  @override
  String get generalSettingsTitle => 'Орнотуулар';

  @override
  String get generalSettingsPosInfo => 'Касса жөнүндө маалымат';

  @override
  String get generalSettingsCashBoxName => 'Кассанын аталышы';

  @override
  String get generalSettingsCompany => 'Компания';

  @override
  String get generalSettingsIinBin => 'ИЖН/ИСН';

  @override
  String get generalSettingsPosId => 'POS ID';

  @override
  String get generalSettingsStoreId => 'Дүкөн ID';

  @override
  String get generalSettingsNotSpecified => 'Көрсөтүлгөн эмес';

  @override
  String get generalSettingsAppVersion => 'Тиркеменин версиясы';

  @override
  String get generalSettingsVersion => 'Версия';

  @override
  String get generalSettingsPlatform => 'Платформа';

  @override
  String get generalSettingsLanguage => 'Интерфейс тили';

  @override
  String get generalSettingsTheme => 'Жасалгасы';

  @override
  String get generalSettingsThemeDesc => 'Ачык, күңүрт же системадагыдай';

  @override
  String get generalSettingsThemeLight => 'Ачык';

  @override
  String get generalSettingsThemeDark => 'Күңүрт';

  @override
  String get generalSettingsThemeSystem => 'Системадагыдай';

  @override
  String generalSettingsLanguageChanged(String language) {
    return 'Тил $language болуп өзгөртүлдү';
  }

  @override
  String get generalSettingsCurrency => 'Валюта';

  @override
  String get generalSettingsCurrencySymbol => 'Белги';

  @override
  String get generalSettingsCurrencyCode => 'Код';

  @override
  String get generalSettingsCountry => 'Өлкө';

  @override
  String get generalSettingsAdditional => 'Кошумча орнотуулар';

  @override
  String get generalSettingsTransport => 'Транспорт';

  @override
  String get generalSettingsTransportSubtitle =>
      'Маалыматтарды синхрондоо орнотуулары';

  @override
  String get generalSettingsPrinter => 'Принтер';

  @override
  String get generalSettingsPrinterSubtitle => 'Чек басып чыгаруу орнотуулары';

  @override
  String get generalSettingsPermissions => 'Уруксаттар';

  @override
  String get generalSettingsPermissionsSubtitle => 'Кассирлер үчүн уруксаттар';

  @override
  String get generalSettingsFiscal => 'Фискализация';

  @override
  String get generalSettingsFiscalSubtitle => 'WebKassa, ОФД, КНС';

  @override
  String get generalSettingsRestaurant => 'Ресторан';

  @override
  String get generalSettingsRestaurantSubtitle =>
      'Столдор, залдар, тейлөө режими';

  @override
  String get generalSettingsTelegram => 'Telegram';

  @override
  String get generalSettingsTelegramSubtitle =>
      'Байланыш каналдары жана боттор';

  @override
  String get generalSettingsPosInfoDesc => 'Касса аталышы, компания, ID';

  @override
  String get generalSettingsVersionDesc => 'Учурдагы версия жана платформа';

  @override
  String get generalSettingsLanguageDesc => 'Интерфейс тилин тандоо';

  @override
  String get generalSettingsCurrencyDesc => 'Валюта жана өлкө';

  @override
  String get generalSettingsUpdate => 'Жаңыртуу';

  @override
  String get generalSettingsUpdateSubtitle =>
      'Жаңыртууларды текшерүү жана орнотуу';

  @override
  String get generalSettingsAppUpdate => 'Тиркемени жаңыртуу';

  @override
  String get generalSettingsAppUpdateSubtitle =>
      'Касса тиркемесин жаңыртуу (ОС жаңыртуусу менен чаташтырбаңыз)';

  @override
  String get generalSettingsUpdateDesc => 'Учурдагы версия жана жаңыртуулар';

  @override
  String get settingsUpdateTitle => 'Колдонмону жаңыртуу';

  @override
  String get settingsUpdateCurrentVersion => 'Учурдагы версия';

  @override
  String get settingsUpdateCheckBtn => 'Жаңыртууларды текшерүү';

  @override
  String get settingsUpdateChecking => 'Жаңыртуулар текшерилүүдө...';

  @override
  String get settingsUpdateUpToDate => 'Акыркы версия орнотулган';

  @override
  String settingsUpdateAvailable(String version) {
    return '$version версиясы жеткиликтүү';
  }

  @override
  String get settingsUpdateDownloadBtn => 'Жаңыртууну жүктөө';

  @override
  String settingsUpdateDownloading(String percent) {
    return 'Жүктөлүүдө... $percent%';
  }

  @override
  String get settingsUpdateInstallBtn => 'Жаңыртууну орнотуу';

  @override
  String get settingsUpdateInstalling => 'Орнотулууда...';

  @override
  String get settingsUpdateFailed => 'Жаңыртуу катасы';

  @override
  String get settingsUpdateAutoEnabled => 'Автоматтык текшерүү ар 3 сааттан';

  @override
  String get settingsUpdateCloseShift => 'Жаңыртуу алдында сменаны жабыңыз';

  @override
  String get settingsUpdateReleaseNotes => 'Жаңылыктар';

  @override
  String get countryKazakhstan => 'Казакстан';

  @override
  String get countryRussia => 'Россия';

  @override
  String get countryKyrgyzstan => 'Кыргызстан';

  @override
  String get countryUzbekistan => 'Өзбекстан';

  @override
  String get countryUSA => 'АКШ';

  @override
  String get countryTurkmenistan => 'Түркмөнстан';

  @override
  String get permNavServiceQueue => 'Заказдар кезеги';

  @override
  String get permNavServiceIntake => 'Заказ кабыл алуу';

  @override
  String get permSellWithDiscount => 'Арзандатуу менен сатуу';

  @override
  String get permCashInOut => 'Киргизүү / алуу';

  @override
  String get permRefundGoods => 'Товарды кайтаруу';

  @override
  String get permRefundWithoutReceipt => 'Чексиз кайтаруу';

  @override
  String get permGroupNavigation => 'Навигация';

  @override
  String get permEditPrice => 'Бааны түзөтүү';

  @override
  String get permSellInDebt => 'Карызга сатуу';

  @override
  String get permDiscounts => 'Арзандатуулар';

  @override
  String get permCashOperations => 'Касса операциялары';

  @override
  String get permSendToOfd => 'ОФД-ге жөнөтүү';

  @override
  String get permCancelPayment => 'Төлөмдү жокко чыгаруу';

  @override
  String get permDeferSale => 'Кийинкиге калтырылган сатуу';

  @override
  String get permShowHistory => 'Тарыхты көрсөтүү';

  @override
  String get printerSettingsSaved => 'Орнотуулар сакталды';

  @override
  String printerSettingsSaveError(String error) {
    return 'Сактоо катасы: $error';
  }

  @override
  String get printerSettingsPrinting => 'Басып чыгарылууда...';

  @override
  String get printerSettingsTestReceipt => 'ТЕСТТИК ЧЕК';

  @override
  String get printerSettingsWidth => 'Туурасы:';

  @override
  String printerSettingsWidthValue(int width) {
    return '$width символ';
  }

  @override
  String get printerSettingsType => 'Түрү:';

  @override
  String get printerSettingsAddress => 'Дарек:';

  @override
  String get printerSettingsNotSpecifiedAddr => 'Көрсөтүлгөн эмес';

  @override
  String get printerSettingsPrinterWorks => 'Принтер иштейт!';

  @override
  String get printerSettingsPrintSuccess => 'Басып чыгаруу ийгиликтүү';

  @override
  String get printerSettingsPrintError => 'Басып чыгаруу катасы';

  @override
  String get printerSettingsNotConnected => 'Туташкан эмес';

  @override
  String get printerSettingsChecking => 'Текшерилүүдө...';

  @override
  String get printerSettingsReady => 'Даяр';

  @override
  String get printerSettingsNoPaper => 'Кагаз жок';

  @override
  String get printerSettingsCoverOpen => 'Капкак ачык';

  @override
  String get printerSettingsSave => 'Сактоо';

  @override
  String get printerSettingsConnectionType => 'Туташуу түрү';

  @override
  String get printerSettingsPrinterAddress => 'Принтер дареги';

  @override
  String get printerSettingsPaperWidth => 'Кагаз туурасы';

  @override
  String get printerSettingsTesting => 'Тестирлөө';

  @override
  String printerSettingsStatus(String status) {
    return 'Абал: $status';
  }

  @override
  String get printerSettingsCheck => 'Текшерүү';

  @override
  String get printerSettingsTestCheck => 'Тесттик чек';

  @override
  String get printerSettingsPort => 'Порт';

  @override
  String get printerSettingsIpAddress => 'Принтердин IP дареги';

  @override
  String get printerSettingsMacAddress => 'MAC дарек же аталышы';

  @override
  String get printerSettingsPrinterName => 'Принтер аталышы';

  @override
  String get printerSettingsComPort => 'COM порт';

  @override
  String get printerSettingsSerialCom => 'Serial (COM)';

  @override
  String get printerSettingsPaperWidth58 => '58мм (32 символ)';

  @override
  String get printerSettingsPaperWidth80_42 => '80мм (42 символ)';

  @override
  String get printerSettingsPaperWidth80_48 => '80мм (48 символ)';

  @override
  String get fiscalSettingsTitle => 'Фискализация';

  @override
  String get fiscalSettingsSaved => 'Орнотуулар сакталды';

  @override
  String fiscalSettingsSaveError(String error) {
    return 'Сактоо катасы: $error';
  }

  @override
  String get fiscalSettingsSave => 'Сактоо';

  @override
  String get fiscalSettingsOperator => 'Фискалдык оператор';

  @override
  String get fiscalSettingsWebkassaSettings => 'WebKassa орнотуулары';

  @override
  String get fiscalSettingsTaxpayerInfo => 'Салык төлөөчүнүн маалыматтары';

  @override
  String get fiscalSettingsVatSettings => 'КНС орнотуулары';

  @override
  String get fiscalSettingsWebkassaLabel => 'WebKassa';

  @override
  String get fiscalSettingsWebkassaDesc => 'Булуттук фискалдык кызмат';

  @override
  String get fiscalSettingsOfdLabel => 'ОФД';

  @override
  String get fiscalSettingsOfdDesc => 'Фискалдык маалыматтар операторлору';

  @override
  String get fiscalSettingsNoneLabel => 'Фискализациясыз';

  @override
  String get fiscalSettingsNoneDesc => 'Чектер ОФД-ге жөнөтүлбөйт';

  @override
  String get fiscalSettingsOfdId => 'ОФД ID';

  @override
  String get fiscalSettingsOfdIdHint => 'ОФД идентификатору';

  @override
  String get fiscalSettingsOfdName => 'ОФД аталышы';

  @override
  String get fiscalSettingsOfdNameHint => 'WebKassa / ОФД.kz';

  @override
  String get fiscalSettingsOfdHost => 'ОФД сервер дареги';

  @override
  String get fiscalSettingsOfdHostHint => 'https://api.webkassa.kz';

  @override
  String get fiscalSettingsWebkassaActive => 'WebKassa активдештирилди';

  @override
  String get fiscalSettingsWebkassaInactive => 'WebKassa активдештирилген эмес';

  @override
  String get fiscalSettingsCompanyName => 'Аталышы';

  @override
  String get fiscalSettingsCashBox => 'Касса';

  @override
  String get fiscalSettingsVatPayer => 'КНС төлөөчү';

  @override
  String get fiscalSettingsVatPayerSubtitle =>
      'Уюм КНС төлөөчү болуп саналат (12%)';

  @override
  String get fiscalSettingsPrintVat => 'Чекте КНС басып чыгаруу';

  @override
  String get fiscalSettingsPrintVatSubtitle => 'Чекте КНС суммасын көрсөтүү';

  @override
  String get fiscalOffsetSection => 'Сертификаттар жана аванс';

  @override
  String get fiscalOffsetCertificateSale => 'Сертификат сатылганда чек';

  @override
  String get fiscalOffsetCertificateSaleSubtitle =>
      'Белек сертификаты сатылганда фискалдык чек берүү';

  @override
  String get fiscalOffsetLayout => 'Сертификат же аванс менен төлөө';

  @override
  String get fiscalOffsetLayoutSubtitle =>
      'Эсепке алуу суммасы ОФД чегине кантип түшөт';

  @override
  String get fiscalOffsetLayoutDiscount => 'Товарларга арзандатуу менен';

  @override
  String get fiscalOffsetLayoutSurchargeOnly => 'Кошумча төлөмгө гана чек';

  @override
  String get fiscalOffsetPrepaymentReceipt => 'Аванс кабыл алынганда чек';

  @override
  String get fiscalOffsetPrepaymentReceiptSubtitle =>
      'Сатып алуучу аванс салганда фискалдык чек берүү';

  @override
  String get fiscalOffsetSaveError => 'Жөндөөнү сактоо мүмкүн болбоду';

  @override
  String get customerPaymentTender => 'Эмне менен кабыл алынды';

  @override
  String get fiscalSettingsVatRate =>
      'КНС ставкасы: 12% (3/28 формуласы менен)';

  @override
  String historyProductUcode(String ucode) {
    return 'Товар #$ucode';
  }

  @override
  String historyRefundProductId(String id) {
    return 'Кайтаруу товары #$id';
  }

  @override
  String historyAccountId(String id) {
    return 'Эсеп #$id';
  }

  @override
  String historyLoadError(String error) {
    return 'Жүктөө катасы: $error';
  }

  @override
  String historyReceiptNo(String number) {
    return 'Чек $number';
  }

  @override
  String get historySyncSynced => 'Синхр.';

  @override
  String get historySyncPending => 'Күтүү';

  @override
  String get historySyncSending => 'Жөн.';

  @override
  String get historySyncDeferred => 'Кийин';

  @override
  String get historySyncInProgress => 'Жүрүүдө';

  @override
  String get historyClient => 'Кардар';

  @override
  String get historyFiscalization => 'Фискализация';

  @override
  String get historyProducts => 'Товарлар';

  @override
  String get historyPayment => 'Төлөм';

  @override
  String get historyNoProducts => 'Товарлар жок';

  @override
  String get historyNoPayments => 'Төлөмдөр жок';

  @override
  String historyPrintingReceipt(String number) {
    return 'Чекти басып чыгаруу $number...';
  }

  @override
  String get historyReceiptPrinted => 'Чек басылды';

  @override
  String get historyPrintError => 'Басып чыгаруу катасы';

  @override
  String get historyOperationType => 'Операция түрү';

  @override
  String get historyFilterSales => 'Сатуулар';

  @override
  String get historyFilterRefunds => 'Кайтаруулар';

  @override
  String get historySearchShort => 'Издөө...';

  @override
  String get historyFilters => 'Чыпкалар';

  @override
  String get historyDateFrom => 'Баштап';

  @override
  String get historyDateTo => 'Чейин';

  @override
  String get historyReset => 'Тазалоо';

  @override
  String get historyApply => 'Колдонуу';

  @override
  String get historySearchFull => 'Чек номери, сумма боюнча издөө...';

  @override
  String get historySyncStatus => 'Синхрондоо абалы';

  @override
  String get historyReceiptColumn => 'Чек';

  @override
  String get historySyncSyncedFull => 'Синхрондолгон';

  @override
  String get historySyncPendingFull => 'Синхрондоону күтүүдө';

  @override
  String get historySyncSendingFull => 'Жөнөтүлүүдө';

  @override
  String get historySyncDeferredFull => 'Кийинкиге калтырылган';

  @override
  String get historySyncInProgressFull => 'Жүрүп жатат';

  @override
  String get historyPaymentCash => 'Накталай';

  @override
  String get historyPaymentCard => 'Карта';

  @override
  String get historyPaymentMixed => 'Аралаш';

  @override
  String get historyPaymentBonus => 'Бонустар';

  @override
  String get historyPaymentDebt => 'Карызга';

  @override
  String get historyPaymentDiscount => 'Арзандатуу';

  @override
  String get historyPaymentWithDiscount => 'Арзандатуу менен';

  @override
  String get historyOfdFiscalized => 'Фискалдалган';

  @override
  String get historyOfdError => 'Фискализация катасы';

  @override
  String get historyOfdNotFiscalized => 'Фискалдалган эмес';

  @override
  String get historyClearFilters => 'Чыпкаларды тазалоо';

  @override
  String historyRecordsRange(String start, String end, String total) {
    return 'Жазуулар $start–$end, жалпы $total';
  }

  @override
  String get historyFirstPage => 'Биринчи бет';

  @override
  String get historyPrevious => 'Мурунку';

  @override
  String get historyNextPage => 'Кийинки';

  @override
  String get historyLastPage => 'Акыркы бет';

  @override
  String historyAmount(String amount) {
    return 'Сумма: $amount';
  }

  @override
  String historyDate(String date) {
    return 'Күнү: $date';
  }

  @override
  String historyPos(String id) {
    return 'POS: $id';
  }

  @override
  String historyClientName(String name) {
    return 'Кардар: $name';
  }

  @override
  String get historyFiscalYes => 'Ооба';

  @override
  String get historyFiscalNo => 'Жок';

  @override
  String get historyFiscalError => 'Ката';

  @override
  String get shiftPrintZReport => 'Z-отчетту басып чыгаруу';

  @override
  String get shiftZReportQueued =>
      'Z-отчет басып чыгаруу кезегине кабыл алынды. Кагаз азырынча жок: принтер мүмкүн болгондо чыгат. Тапшырма 30 мүнөт күтөт — аны Жөндөөлөр → Принтер бөлүмүнөн көрүүгө болот';

  @override
  String get shiftZReportAlreadyQueued =>
      'Z-отчет басып чыгарууга жиберилген — ал экинчи жолу басылбайт';

  @override
  String get shiftZReportPrintFailed =>
      'Z-отчетту басып чыгарууга жиберүү мүмкүн болбоду';

  @override
  String get shiftFinishAllSales => 'Бардык сатууларды аяктаңыз';

  @override
  String get shiftCannotClose => 'Сменаны жабуу мүмкүн эмес';

  @override
  String get shiftOpeningShift => 'Сменаны ачуу';

  @override
  String get shiftClosingShift => 'Сменаны жабуу';

  @override
  String get shiftEnterInitialAmount =>
      'Кассадагы баштапкы сумманы киргизиңиз:';

  @override
  String get shiftDiscrepancyFound => 'Дал келбестик табылды';

  @override
  String shiftDifferenceAmount(String amount) {
    return 'Айырма: $amount';
  }

  @override
  String get shiftConfirmCloseQuestion => 'Сменаны жабууга ишенесизби?';

  @override
  String shiftFixedAmount(String amount) {
    return 'Катталуучу сумма: $amount';
  }

  @override
  String get shiftCloseWithDiscrepancy => 'Дал келбестик менен жабуу';

  @override
  String get shiftCashierLabel => 'Кассир';

  @override
  String get shiftUnknown => 'Белгисиз';

  @override
  String get shiftSystemTotal => 'Системалык сумма';

  @override
  String get shiftEnteredTotal => 'Киргизилген сумма';

  @override
  String get shiftCashOperations => 'Кассалык операциялар';

  @override
  String get shiftSalesLabel => 'Сатуулар';

  @override
  String get shiftSalesTotal => 'Сатуулардын суммасы';

  @override
  String get shiftCashSales => 'Накталай';

  @override
  String get shiftCardSales => 'Карта';

  @override
  String get shiftRefundsTotal => 'Кайтаруулар';

  @override
  String get cashOpeningCount => 'Ачууда кайра саноо';

  @override
  String get shiftShortage => 'Жетишсиздик';

  @override
  String get shiftSurplus => 'Ашыкча';

  @override
  String get shiftBalances => 'Дал келет';

  @override
  String get shiftCloseBlocked => 'Жабуу бөгөттөлгөн';

  @override
  String shiftActiveSalesCount(int count) {
    return 'Активдүү сатуулар: $count';
  }

  @override
  String shiftPendingSalesCount(int count) {
    return 'Кийинкиге калтырылган сатуулар: $count';
  }

  @override
  String get shiftFinishSalesBeforeClose =>
      'Сменаны жабуудан мурун сатууларды аяктаңыз же жокко чыгарыңыз';

  @override
  String get shiftBillsTab => 'Купюралар';

  @override
  String get shiftTotalTab => 'Жалпы сумма';

  @override
  String get shiftOperationsTab => 'Операциялар';

  @override
  String get shiftAmountTab => 'Сумма';

  @override
  String get shiftBillCount => 'Купюралар боюнча эсеп';

  @override
  String get shiftDifferenceLabel => 'Айырма: ';

  @override
  String get supplySupplierRequired => 'Жеткирүүчү *';

  @override
  String get supplyPaymentType => 'Төлөм түрү';

  @override
  String get supplyFullPayment => 'Толук төлөм';

  @override
  String get supplyAccountDebit => 'Эсептен чыгаруу';

  @override
  String get supplyConsignment => 'Консигнация';

  @override
  String get supplyDeferredPayment => 'Кийинкиге калтырылган төлөм';

  @override
  String get supplyPaymentAccountRequired => 'Төлөм эсеби *';

  @override
  String get supplyAddProduct => 'Товар кошуу';

  @override
  String get supplyBarcodeOrSku => 'Штрихкод же артикул';

  @override
  String supplyProductsCount(int count) {
    return 'Товарлар ($count)';
  }

  @override
  String supplyAmountValue(String amount) {
    return 'Сумма: $amount';
  }

  @override
  String get supplyProductNotFound => 'Товар табылган жок';

  @override
  String get supplyInvalidQuantity => 'Туура санды киргизиңиз';

  @override
  String get supplySelectSupplierTitle => 'Жеткирүүчүнү тандаңыз';

  @override
  String get supplySuppliersNotFound => 'Жеткирүүчүлөр табылган жок';

  @override
  String get supplySelectAccountTitle => 'Эсепти тандаңыз';

  @override
  String get supplyAccountsNotFound => 'Эсептер табылган жок';

  @override
  String supplyAccountBalance(String amount) {
    return 'Баланс: $amount';
  }

  @override
  String supplyProductNumber(String number) {
    return 'Товар #$number';
  }

  @override
  String supplyProductCountLabel(int count) {
    return 'Товарлар: $count';
  }

  @override
  String supplyTotalLabel(String amount) {
    return 'Жалпы: $amount';
  }

  @override
  String supplySavedSuccess(int count, String amount) {
    return 'Кабыл алуу сакталды. Товарлар: $count, сумма: $amount';
  }

  @override
  String get supplyCancelConfirm => 'Кабыл алууну жокко чыгаруу керекпи?';

  @override
  String get supplyCancelMessage => 'Бардык киргизилген маалыматтар жоголот.';

  @override
  String get supplyYesCancel => 'Ооба, жокко чыгаруу';

  @override
  String get supplySearchProduct => 'Товар издөө...';

  @override
  String get supplyAddProductsHint => 'Кабыл алууга товарларды кошуңуз';

  @override
  String get supplyScanOrSearch => 'Штрихкодду сканерлеңиз же товарды табыңыз';

  @override
  String get refundTotalAmount => 'Кайтаруу суммасы';

  @override
  String get refundPosLabel => 'Касса';

  @override
  String refundSelectedOfTotal(String selected, String total) {
    return '$selected / $total';
  }

  @override
  String get refundTotalProducts => 'Бардык товарлар';

  @override
  String get refundToReturn => 'КАЙТАРУУГА';

  @override
  String get refundToReturnLabel => 'Кайтарууга:';

  @override
  String get refundAction => 'КАЙТАРУУ';

  @override
  String refundSelectedItemsShort(String selected, String total) {
    return '$selected / $total поз.';
  }

  @override
  String get refundColumnName => 'Аталышы';

  @override
  String get refundColumnQty => 'Саны';

  @override
  String get refundEmptyHint =>
      'Чекти жүктөңүз же товарларды кол менен кошуңуз';

  @override
  String get refundNoItemsShort => 'Товарлар жок';

  @override
  String get refundEmptyHintShort => 'Чекти жүктөңүз же\nтоварларды кошуңуз';

  @override
  String refundSelectedCount(String count) {
    return 'Тандалган позициялар: $count';
  }

  @override
  String refundAmountValue(String amount) {
    return 'Кайтаруу суммасы: $amount';
  }

  @override
  String get refundSuccess => 'Кайтаруу ийгиликтүү аткарылды';

  @override
  String get paymentAmountDue => 'Төлөөгө';

  @override
  String get paymentTotalDue => 'Жалпы төлөөгө';

  @override
  String get paymentCashLabel => 'Накталай';

  @override
  String get paymentReceived => 'Алынды';

  @override
  String get paymentRemainingLabel => 'Калды';

  @override
  String paymentCardAmount(String amount) {
    return 'Карта менен төлөм $amount суммага';
  }

  @override
  String get paymentLoyaltyProgram => 'Лоялдуулук программасы';

  @override
  String get paymentPhoneNumber => 'Телефон номери';

  @override
  String get paymentAvailableBonus => 'Жеткиликтүү бонустар:';

  @override
  String get paymentUseBonuses => 'Бонустарды колдонуу';

  @override
  String paymentBonusToDeduct(String amount) {
    return 'Эсептен чыгаруу: $amount бонус';
  }

  @override
  String get paymentSuccessMessage => 'Төлөм ийгиликтүү';

  @override
  String get paymentRefundButton => 'КАЙТАРУУ';

  @override
  String get paymentPayButton => 'ТӨЛӨӨ';

  @override
  String get syncWidgetRetry => 'Кайталоо';

  @override
  String syncWidgetLastSync(String time) {
    return 'Акыркы синхрондоо: $time';
  }

  @override
  String syncWidgetRecordsCount(int count) {
    return '$count жазуу';
  }

  @override
  String get syncWidgetWaiting => 'Күтүүдө';

  @override
  String get syncWidgetSynced => 'Синхрондолду';

  @override
  String get syncWidgetJustNow => 'жаңы эле';

  @override
  String syncWidgetMinutesAgo(int minutes) {
    return '$minutes мин. мурун';
  }

  @override
  String syncWidgetHoursAgo(int hours) {
    return '$hours саат мурун';
  }

  @override
  String syncWidgetDaysAgo(int days) {
    return '$days күн мурун';
  }

  @override
  String get syncWidgetConnecting => 'Серверге туташууда...';

  @override
  String get syncWidgetSyncingProducts => 'Товарларды синхрондоо...';

  @override
  String get syncWidgetSyncingSales => 'Сатууларды синхрондоо...';

  @override
  String get syncWidgetSyncingAgents => 'Контрагенттерди синхрондоо...';

  @override
  String get syncWidgetSyncingPrices => 'Бааларды синхрондоо...';

  @override
  String get syncWidgetFinishing => 'Аяктоодо...';

  @override
  String get updateDialogUpdating => 'Жаңыртуу...';

  @override
  String get updateDialogAvailable => 'Жаңыртуу жеткиликтүү';

  @override
  String updateDialogAutoUpdate(int seconds) {
    return 'Автоматтык жаңыртуу $seconds сек. кийин';
  }

  @override
  String get updateDialogUpdateNow => 'Азыр жаңыртуу';

  @override
  String get updateDialogLater => 'Кийинчерээк';

  @override
  String get updateDialogSkip => 'Өткөрүп жиберүү';

  @override
  String get updateDialogUpdate => 'Жаңыртуу';

  @override
  String storeUpdateVersion(String version) {
    return 'Версия $version';
  }

  @override
  String storeUpdateNewVersionAvailable(String storeName) {
    return 'Колдонмонун жаңы версиясы $storeName ичинде жеткиликтүү.';
  }

  @override
  String get storeUpdateWhatsNew => 'Жаңылыктар:';

  @override
  String get storeUpdateRequired => 'Бул милдеттүү жаңыртуу';

  @override
  String storeUpdateGoTo(String storeName) {
    return '$storeName ичине өтүү';
  }

  @override
  String get storeUpdateButton => 'ЖАҢЫРТУУ';

  @override
  String get storeUpdateDownloaded => 'Жаңыртуу жүктөлдү';

  @override
  String get storeUpdateReadyToInstall =>
      'Жаңыртуу жүктөлдү жана орнотууга даяр.\nАзыр орнотуу керекпи? Колдонмо кайра иштетилет.';

  @override
  String get storeUpdateInstall => 'ОРНОТУУ';

  @override
  String get storeUpdateDownloading => 'Жаңыртуу жүктөлүүдө...';

  @override
  String get storeUpdateReadyShort => 'Жаңыртуу орнотууга даяр';

  @override
  String get versionConflictTitle => 'Версиялар карама-каршылыгы';

  @override
  String get versionConflictDescription =>
      'Колдонмо версияларынын карама-каршылыгы аныкталды.';

  @override
  String get versionConflictCurrent => 'Учурдагы версия';

  @override
  String get versionConflictFound => 'Табылган версия';

  @override
  String get versionConflictChooseAction => 'Аракетти тандаңыз:';

  @override
  String get versionConflictOpenFolder => 'Папкада ачуу';

  @override
  String get versionConflictPreviousVersion => 'Мурунку версия';

  @override
  String get versionConflictContinue => 'Улантуу';

  @override
  String get restoreLoadingBackups => 'Бэкаптар жүктөлүүдө...';

  @override
  String get restoreSearchingBackups => 'Бэкаптарды издөө...';

  @override
  String restoreLoadError(String error) {
    return 'Жүктөө катасы: $error';
  }

  @override
  String get restoreRestoring => 'Калыбына келтирүү...';

  @override
  String get restoreRestoreError => 'Калыбына келтирүү катасы';

  @override
  String get restoreRestoreFailed =>
      'Бэкаптан калыбына келтирүү ишке ашкан жок';

  @override
  String get restoreTitle => 'Калыбына келтирүү';

  @override
  String get restoreChooseMethod => 'Орнотуу ыкмасын тандаңыз';

  @override
  String get restoreSetupNewPos => 'Жаңы кассаны орнотуу';

  @override
  String get restoreNoBackups => 'Бэкаптар табылган жок';

  @override
  String get restoreSetupAsNew => 'Кассаны жаңыдан орнотуңуз';

  @override
  String get restoreFoundBackups => 'Табылган бэкаптар:';

  @override
  String get agentSearchByNameOrPhone => 'Аты же телефону боюнча издөө...';

  @override
  String get agentOnlyWithDebt => 'Карызы менен гана';

  @override
  String get agentTypeTooltip => 'Түрү';

  @override
  String agentBinLabel(String bin) {
    return 'БИН: $bin';
  }

  @override
  String agentSelectedMessage(String name) {
    return 'Тандалды: $name';
  }

  @override
  String agentFoundCount(int count) {
    return 'Табылды: $count';
  }

  @override
  String get agentEnterNameOrPhoneToSearch =>
      'Издөө үчүн атын же телефонун жазыңыз';

  @override
  String get agentNotFound => 'Кардарлар табылган жок';

  @override
  String get agentSearchClients => 'Кардарларды издөө';

  @override
  String get agentNotFoundShort => 'Табылган жок';

  @override
  String get agentEnterNameOrPhone => 'Атын же телефонун жазыңыз';

  @override
  String get agentEnterCustomerName => 'Кардардын атын жазыңыз';

  @override
  String get agentDeletedCustomerPhone => 'Бул телефон менен кардар өчүрүлгөн';

  @override
  String get agentWantRestore => 'Калыбына келтиресизби?';

  @override
  String get agentDeleteCustomerTitle => 'Кардарды өчүрөсүзбү?';

  @override
  String agentDeleteConfirmMessage(String name) {
    return '\"$name\" өчүрүүгө ишенесизби?';
  }

  @override
  String agentCustomerDeleted(String name) {
    return 'Кардар \"$name\" өчүрүлдү';
  }

  @override
  String get cashOpTitle => 'Кассалык операция';

  @override
  String get cashOpComment => 'Комментарий';

  @override
  String get cashOpCommentRequired => 'Комментарий *';

  @override
  String get cashOpCommentHint => 'Комментарий жазыңыз...';

  @override
  String cashOpError(String error) {
    return 'Ката: $error';
  }

  @override
  String get cashOpOperationType => 'Операция түрү';

  @override
  String get cashOpExpense => 'Чыгым';

  @override
  String get cashOpDividend => 'Алып чыгуу';

  @override
  String get saleReceiptTotal => 'Чек боюнча жалпы';

  @override
  String get salePay => 'ТӨЛӨӨ';

  @override
  String get saleTotalColon => 'Жалпы:';

  @override
  String salePositionsAndQuantity(int count, String qty) {
    return '$count поз. / $qty шт.';
  }

  @override
  String get saleWholesale => 'ДҮҢҮНӨН';

  @override
  String get saleRetail => 'Чекене';

  @override
  String get syncPreparing => 'Даярдоо...';

  @override
  String refundRefused(String reason) {
    return 'Кайтаруу аткарылган жок: $reason';
  }

  @override
  String errorSaveFailed(String details) {
    return 'Сактоо катасы: $details';
  }

  @override
  String get errorSaveFailedGeneric => 'Сактоо катасы';

  @override
  String errorLoadFailed(String details) {
    return 'Маалыматтарды жүктөө катасы: $details';
  }

  @override
  String get errorLoadFailedGeneric => 'Маалыматтарды жүктөө катасы';

  @override
  String errorSearchFailed(String details) {
    return 'Издөө катасы: $details';
  }

  @override
  String get errorSearchFailedGeneric => 'Издөө катасы';

  @override
  String get errorUnknownGeneric => 'Белгисиз ката';

  @override
  String errorRefusalUnknownCode(String code) {
    return 'белгисиз себеп (коду $code)';
  }

  @override
  String get errorReasonUnknown => 'белгисиз себеп';

  @override
  String get errorFillRequired => 'Бардык милдеттүү талааларды толтуруңуз';

  @override
  String get errorNoUsers => 'Катталган колдонуучулар жок';

  @override
  String get errorSelectUser => 'Колдонуучуну тандаңыз';

  @override
  String get errorPinTooShort => 'PIN кодду киргизиңиз (кеминде 4 сан)';

  @override
  String get errorRsaNotConfigured =>
      'Ката: RSA ачкыч конфигурацияланган эмес. Администраторго кайрылыңыз.';

  @override
  String get errorWrongPin => 'Туура эмес PIN код';

  @override
  String get errorAmbiguousPin =>
      'Бул PIN код бир нече кассирде бирдей. Атыңызды тандап, ошол аркылуу кириңиз.';

  @override
  String get errorNoPinSet =>
      'Бул кассир үчүн PIN код коюлган эмес. Аны коюу үчүн администраторго кайрылыңыз.';

  @override
  String get errorWalkUpDisabled =>
      'Бул түйүндө атын тандабай кирүү өчүрүлгөн. Тизмеден атыңызды тандаңыз.';

  @override
  String get errorCredentialUnreadable =>
      'PIN код жазуусу бузулган. Администраторго кайрылыңыз — кайра терүү жардам бербейт.';

  @override
  String get errorAuthUnknown =>
      'Касса кирүү аракетине жооп бере алган жок. Кайра аракет кылыңыз.';

  @override
  String get errorTillNotConfigured =>
      'Касса азырынча ырасталган эмес — тууралоо устасы аякталмайынча кирүү мүмкүн эмес.';

  @override
  String get errorTillNotConfiguredSale =>
      'Касса жөндөлгөн эмес — чек баштоого болбойт. Администраторго кайрылыңыз: жөндөө устасынан өтүү керек.';

  @override
  String get errorNotAllowed =>
      'Бул аракетке укук жетишсиз. Администраторго кайрылыңыз.';

  @override
  String get errorNoSaleModule =>
      'Бул касса чек жүргүзө албайт: сатуу модулу чогултулган эмес. Администраторго кайрылыңыз.';

  @override
  String get errorTerminalInBody =>
      'Терминал кассага туура эмес кайрылды. Жумуш ордундагы колдонмону жаңыртыңыз.';

  @override
  String get errorWholesaleInStart =>
      'Дүң чек мындай башталбайт. Кадимки чек баштап, дүңдү өзүнчө баскыч менен күйгүзүңүз.';

  @override
  String get errorTerminalLimitReached =>
      'Бул кассада терминалдардын эң көп саны катталган. Орун бошотуу үчүн администраторго кайрылыңыз.';

  @override
  String get errorPairingCodeInvalid =>
      'Байланыштыруу коду туура келген жок — мөөнөтү өткөн, мурда колдонулган же туура эмес терилген. Кассадан жаңы код алыңыз.';

  @override
  String get errorTerminalSecretInvalid =>
      'Бул түзмөктүн байланышы эми жарактуу эмес — терминал кассадан өчүрүлгөн болушу мүмкүн. Жаңы байланыштыруу кодун киргизиңиз.';

  @override
  String get errorSessionExpired => 'Сеанстын мөөнөтү бүттү — кайра кириңиз.';

  @override
  String get errorSessionEnded => 'Сеансты касса аяктады — кайра кириңиз.';

  @override
  String get errorSaleNotInitialized => 'Сатуу инициализациялана элек';

  @override
  String get errorReceiptEmpty => 'Чек бош';

  @override
  String get errorDeferredNotFound => 'Кийинкиге калтырылган чек табылган жок';

  @override
  String get errorCartStale =>
      'Сиз терип жатканда чек өзгөрдү. Экран жаңыртылды — акыркы аракетти кайталаңыз.';

  @override
  String get errorCartWrongReceipt =>
      'Бул чек мындан ары иште эмес. Жаңы чек баштаңыз же кийинкиге калтырылганын алыңыз.';

  @override
  String get errorCartNotStarted =>
      'Чек азырынча башталган жок. Жаңы чек баштаңыз же кийинкиге калтырылганын алыңыз.';

  @override
  String get errorLineNotFound =>
      'Бул сап чекте жок. Чекти жаңыртып, кайра аракет кылыңыз.';

  @override
  String get errorInvalidAmount =>
      'Жараксыз маани. Сумма терс боло албайт, арзандатуу 100%дан ашпашы керек.';

  @override
  String get errorDeferredTaken =>
      'Бул кийинкиге калтырылган чекти башка жумуш орду алып койгон.';

  @override
  String get errorCartNotEmpty =>
      'Адегенде учурдагы чекти аяктаңыз же кийинкиге калтырыңыз — анын үстүнө башкасын алууга болбойт.';

  @override
  String get errorSaleNotStarted =>
      'Касса чекти баштай алган жок жана себебин айткан жок. Кайра аракет кылыңыз.';

  @override
  String get errorShiftNotOpen => 'Смена ачылган жок. Сменаны кассада ачыңыз.';

  @override
  String get errorCardTerminalMisconfigured =>
      'Бул жумуш ордунун төлөм терминалы туура эмес жөндөлгөн. Жабдык жөндөөлөрүндөгү байланышты текшериңиз.';

  @override
  String errorReceiptNotFound(String receiptNo) {
    return '#$receiptNo чек табылган жок';
  }

  @override
  String get errorReceiptNotFoundGeneric => 'Чек табылган жок';

  @override
  String get errorNotAuthorized => 'Колдонуучу авторизацияланган эмес';

  @override
  String get errorSupplierNotFound => 'Жеткирүүчү табылган жок';

  @override
  String get errorAccountNotFound => 'Эсеп табылган жок';

  @override
  String errorProductNotFound(String details) {
    return 'Товар табылган жок: $details';
  }

  @override
  String get errorProductNotFoundGeneric => 'Товар табылган жок';

  @override
  String get errorNameRequired => 'Аты милдеттүү';

  @override
  String get errorNameTooShort => 'Кеминде 2 белги';

  @override
  String get errorPhoneInvalid => 'Телефон форматы туура эмес';

  @override
  String get errorBinInvalid => 'БИН/ЖИН 12 сандан турушу керек';

  @override
  String get errorPhoneExists => 'Ушул телефону менен кардар бар';

  @override
  String errorShiftOpenFailed(String details) {
    return 'Сменаны ачуу катасы: $details';
  }

  @override
  String get errorShiftOpenFailedGeneric => 'Сменаны ачуу катасы';

  @override
  String errorShiftCloseFailed(String details) {
    return 'Сменаны жабуу катасы: $details';
  }

  @override
  String get errorShiftCloseFailedGeneric => 'Сменаны жабуу катасы';

  @override
  String errorShiftLoadFailed(String details) {
    return 'Смена маалыматтарын жүктөө катасы: $details';
  }

  @override
  String get errorShiftLoadFailedGeneric => 'Смена маалыматтарын жүктөө катасы';

  @override
  String get errorPaymentConfig =>
      'Төлөмдү түзүү мүмкүн болгон жок. Эсеп жөндөөлөрүн текшериңиз.';

  @override
  String get errorSaleSaveFailed => 'Сатууну сактоо катасы';

  @override
  String get errorInventoryCannotComplete => 'Аяктоо мүмкүн эмес';

  @override
  String get errorNoProducts => 'Эсептен чыгарууга товарлар жок';

  @override
  String get errorSelectCountry => 'Өлкөнү тандаңыз';

  @override
  String get errorEnterOrgName => 'Уюмдун аталышын киргизиңиз';

  @override
  String errorEnterTaxId(String label) {
    return '$label киргизиңиз';
  }

  @override
  String get errorEnterTaxIdGeneric => 'Салык номерин киргизиңиз';

  @override
  String errorTaxIdLength(String info) {
    return '$info';
  }

  @override
  String get errorTaxIdLengthGeneric => 'Салык номеринин узундугу туура эмес';

  @override
  String get errorEnterPosName => 'Касса аталышын киргизиңиз';

  @override
  String get errorFillWebkassa => 'WebKassa бардык талааларын толтуруңуз';

  @override
  String get errorFillOfd => 'ОФД бардык талааларын толтуруңуз';

  @override
  String get errorEnterKaspiIp => 'Kaspi терминалынын IP-даректин киргизиңиз';

  @override
  String get errorEnterAdminName => 'Администратордун атын киргизиңиз';

  @override
  String get errorAdminPinShort =>
      'Администратор PIN коду кеминде 4 сандан турушу керек';

  @override
  String get errorSellerPinShort =>
      'Сатуучу PIN коду кеминде 4 сандан турушу керек';

  @override
  String errorCheckFailed(String details) {
    return 'Текшерүү катасы: $details';
  }

  @override
  String get errorCheckFailedGeneric => 'Текшерүү катасы';

  @override
  String get errorTelegramNotInitialized =>
      'TelegramInitializer инициализацияланган эмес';

  @override
  String get errorTelegramAuthNotInitialized =>
      'TelegramAuthService инициализацияланган эмес';

  @override
  String errorPhoneSendFailed(String details) {
    return 'Номерди жөнөтүү катасы: $details';
  }

  @override
  String get errorPhoneSendFailedGeneric => 'Номерди жөнөтүү катасы';

  @override
  String errorQrAuthFailed(String details) {
    return 'QR авторизация катасы: $details';
  }

  @override
  String get errorQrAuthFailedGeneric => 'QR авторизация катасы';

  @override
  String errorWrongCode(String details) {
    return 'Туура эмес код: $details';
  }

  @override
  String get errorWrongCodeGeneric => 'Туура эмес код';

  @override
  String errorWrongPassword(String details) {
    return 'Туура эмес сырсөз: $details';
  }

  @override
  String get errorWrongPasswordGeneric => 'Туура эмес сырсөз';

  @override
  String errorRegistrationFailed(String details) {
    return 'Каттоо катасы: $details';
  }

  @override
  String get errorRegistrationFailedGeneric => 'Каттоо катасы';

  @override
  String errorChannelSearchFailed(String details) {
    return 'Каналдарды издөө катасы: $details';
  }

  @override
  String get errorChannelSearchFailedGeneric => 'Каналдарды издөө катасы';

  @override
  String errorChannelConnectFailed(String details) {
    return 'Каналдарга туташуу катасы: $details';
  }

  @override
  String get errorChannelConnectFailedGeneric => 'Каналдарга туташуу катасы';

  @override
  String errorChannelCreateFailed(String details) {
    return 'Каналдарды түзүү катасы: $details';
  }

  @override
  String get errorChannelCreateFailedGeneric => 'Каналдарды түзүү катасы';

  @override
  String get errorFillClientData => 'Кардардын маалыматтарын толтуруңуз';

  @override
  String get shiftCashInvestments => 'Салымдар';

  @override
  String get shiftCashExpenses => 'Чыгымдар';

  @override
  String get shiftCashDividends => 'Алуулар';

  @override
  String get shiftNoCashOps => 'Кассалык операциялар жок';

  @override
  String get shiftNoCashOpsDescription =>
      'Салымдар, чыгымдар жана алуулар\nбул жерде көрсөтүлөт';

  @override
  String shiftMoreItems(int count) {
    return '+$count дагы';
  }

  @override
  String get shiftEqualsSystem => '= Система';

  @override
  String get shiftBillsTotal => 'Купюралар боюнча:';

  @override
  String get receiptInputTitle => 'Чекти издөө';

  @override
  String get receiptInputNumber => 'Чек номери';

  @override
  String get receiptInputNumberHint => 'Мисалы: 12345';

  @override
  String get receiptInputPos => 'Касса';

  @override
  String get receiptInputInvalid => 'Туура чек номерин киргизиңиз';

  @override
  String get receiptInputFind => 'Табуу';

  @override
  String get paymentDenominations => 'Номиналдар';

  @override
  String get paymentExactAmount => 'Кайтарымсыз';

  @override
  String get paymentNumpad => 'Баскычтоп';

  @override
  String get paymentIinLabel => 'ИЖН/ИСН (милдеттүү эмес)';

  @override
  String get paymentIinInvalid => 'Туура эмес ИЖН/ИСН';

  @override
  String get paymentIinHint =>
      'ИЖН — жеке жактар үчүн, ИСН — юридикалык жактар үчүн';

  @override
  String get paymentIinShort => 'ИЖН/ИСН';

  @override
  String get paymentTypeCash => 'Накталай';

  @override
  String get paymentTypeCard => 'Накталай эмес';

  @override
  String get paymentTypeMixed => 'Аралаш';

  @override
  String get paymentAccount => 'Эсеп';

  @override
  String get authNoUsers => 'Катталган колдонуучулар жок';

  @override
  String get authNoPin => 'PIN жок';

  @override
  String get authSelectUser => 'Колдонуучуну тандаңыз';

  @override
  String get authNoUsersShort => 'Колдонуучулар жок';

  @override
  String get authEnterPin => 'PIN-кодду киргизиңиз';

  @override
  String updateVersion(String version) {
    return 'Версия $version';
  }

  @override
  String get updateWhatsNew => 'Жаңылыктар';

  @override
  String get updateFixedIssues => 'Оңдолду';

  @override
  String get updateSize => 'Өлчөмү';

  @override
  String get updateDate => 'Күнү';

  @override
  String get updateMandatory => 'Бул милдеттүү жаңыртуу';

  @override
  String updateLaterCountdown(int countdown) {
    return 'Кийинчерээк ($countdown)';
  }

  @override
  String get updateDownloading => 'Жаңыртуу жүктөлүүдө';

  @override
  String get updateDownloadingFile => 'Жаңыртуу файлы жүктөлүүдө...';

  @override
  String get updatePosNow => 'КАССАНЫ ЖАҢЫРТУУ';

  @override
  String get serviceAddNote => 'Белги кошуу';

  @override
  String get serviceClientLookup => 'Кардарды издөө';

  @override
  String serviceOrderDetail(int orderId) {
    return 'Тапшырма-наряд чоо-жайы #$orderId';
  }

  @override
  String get paymentDefaultLabel => 'Демейки';

  @override
  String get serviceIntakeTitle => 'Тапшырма кабыл алуу';

  @override
  String get serviceIntakeClient => 'Кардар';

  @override
  String get serviceIntakeDevice => 'Түзмөк / Буюм';

  @override
  String get serviceIntakeServices => 'Кызматтар';

  @override
  String get serviceIntakeDelivery => 'Жеткирүү';

  @override
  String get serviceIntakePickup => 'Кардардан алуу';

  @override
  String get serviceIntakeSave => 'Сактоо';

  @override
  String get serviceIntakeCancel => 'Баш тартуу';

  @override
  String get serviceQueueTitle => 'Тапшырма-нарядтар';

  @override
  String get serviceQueueEmpty => 'Тапшырма-нарядтар жок';

  @override
  String get serviceQueueSearch => 'Номер, кардар, түзмөк боюнча издөө';

  @override
  String get serviceDetailTitle => 'Тапшырма чоо-жайы';

  @override
  String get serviceDetailInfo => 'Маалымат';

  @override
  String get serviceDetailTimeline => 'Иштер';

  @override
  String get serviceDetailCost => 'Баа';

  @override
  String get serviceDetailActions => 'Аракеттер';

  @override
  String get serviceStatusIntake => 'Кабыл алуу';

  @override
  String get serviceStatusInProgress => 'Иште';

  @override
  String get serviceStatusCompleted => 'Даяр';

  @override
  String get serviceStatusClosed => 'Жабык';

  @override
  String get serviceStatusCancelled => 'Баш тартылган';

  @override
  String get serviceMarkDiagnostic => 'Диагностика';

  @override
  String get serviceMarkReplacement => 'Бөлүк алмаштыруу';

  @override
  String get serviceMarkRepair => 'Оңдоо';

  @override
  String get serviceMarkTesting => 'Тестирлөө';

  @override
  String get serviceMarkOther => 'Башка';

  @override
  String get serviceAddMark => 'Иш кошуу';

  @override
  String get serviceDeleteMark => 'Белгини жок кылуу';

  @override
  String get serviceMarkDescription => 'Сүрөттөмө';

  @override
  String get serviceMarkType => 'Иш түрү';

  @override
  String get serviceMarkCost => 'Баа';

  @override
  String get serviceMarkNote => 'Эскертүү';

  @override
  String get serviceCatalogTitle => 'Кызматтар каталогу';

  @override
  String get serviceCatalogAdd => 'Кызмат кошуу';

  @override
  String get serviceCatalogDuration => 'мин';

  @override
  String get serviceCatalogWarranty => 'Кепилдик (күн)';

  @override
  String get serviceCatalogRequiresDevice => 'Түзмөк керек';

  @override
  String get serviceClientNew => 'Жаңы кардар';

  @override
  String get serviceClientPhone => 'Телефон';

  @override
  String get serviceClientName => 'Аты';

  @override
  String get serviceClientAddress => 'Дарек';

  @override
  String get serviceAssignTechnician => 'Уста дайындоо';

  @override
  String get serviceReassignTechnician => 'Устаны кайра дайындоо';

  @override
  String serviceTechnicianAssigned(String name) {
    return 'Уста дайындалды: $name';
  }

  @override
  String get serviceTechnicianSelect => 'Уста тандаңыз';

  @override
  String get servicePrepayment => 'Алдын ала төлөм';

  @override
  String get servicePrepaymentAmount => 'Алдын ала төлөм суммасы';

  @override
  String get serviceEstimatedDate => 'Күтүлгөн күн';

  @override
  String get serviceEstimatedAmount => 'Сумма';

  @override
  String get servicePrintLabel => 'QR-этикетка';

  @override
  String get servicePrintReceipt => 'Чек басып чыгаруу';

  @override
  String get serviceProgressConfirm => 'Ишти баштоо';

  @override
  String get serviceCancelConfirm => 'Баш тартуу';

  @override
  String get serviceTotalCost => 'Иш баасы';

  @override
  String get servicePrepaid => 'Алдын ала төлөм';

  @override
  String get serviceRemaining => 'Төлөөгө';

  @override
  String get serviceDeliveryAddress => 'Жеткирүү дареги';

  @override
  String get serviceNeedsPickup => 'Кардардан алуу';

  @override
  String get serviceNeedsDelivery => 'Кардарга жеткирүү';

  @override
  String serviceQrFormat(Object id, Object number) {
    return 'TELEPOS:SO:$id:$number';
  }

  @override
  String get serviceOrderCreated => 'Жаңы тапшырма';

  @override
  String get serviceOrderUpdated => 'Өзгөртүү';

  @override
  String get serviceNoOrders => 'Маалымат жок';

  @override
  String get serviceFilterAll => 'Баары';

  @override
  String get navCatalog => 'Каталог';

  @override
  String get catalogTitle => 'Товарлар каталогу';

  @override
  String get catalogSearch => 'Издөө';

  @override
  String get catalogSearchHint => 'Аталышы же штрихкод';

  @override
  String get catalogFilterAll => 'Баары';

  @override
  String get catalogFilterProducts => 'Товарлар';

  @override
  String get catalogFilterWeighted => 'Салмактык';

  @override
  String get catalogFilterServices => 'Кызматтар';

  @override
  String get catalogFilterPackages => 'Топтомдор';

  @override
  String get catalogAddProduct => 'Товар кошуу';

  @override
  String get catalogEditProduct => 'Товарды өзгөртүү';

  @override
  String get catalogDeleteProduct => 'Товарды жок кылуу';

  @override
  String get catalogRestoreProduct => 'Товарды калыбына келтирүү';

  @override
  String get catalogProductName => 'Аталышы';

  @override
  String get catalogBarcode => 'Штрихкод';

  @override
  String get catalogType => 'Түрү';

  @override
  String get catalogPrice => 'Сатуу баасы';

  @override
  String get catalogWholesalePrice => 'Дүңүнөн баа';

  @override
  String get catalogCategory => 'Категория';

  @override
  String get catalogMeasure => 'Өлчөм бирдиги';

  @override
  String get catalogQuantity => 'Калдык';

  @override
  String get catalogQuickProduct => 'Ыкчам товар';

  @override
  String get catalogAddToQuick => 'Ыкчамга кошуу';

  @override
  String get catalogRemoveFromQuick => 'Ыкчамдан алып салуу';

  @override
  String get catalogNoProducts => 'Товарлар жок';

  @override
  String get catalogDeleted => 'Жок кылынган';

  @override
  String catalogConfirmDelete(String name) {
    return '\"$name\" товарын жок кылуу керекпи?';
  }

  @override
  String get catalogProductCreated => 'Товар түзүлдү';

  @override
  String get catalogProductUpdated => 'Товар жаңыланды';

  @override
  String get catalogProductDeleted => 'Товар жок кылынды';

  @override
  String get catalogProductRestored => 'Товар калыбына келтирилди';

  @override
  String get catalogShowDeleted => 'Жок кылынгандарды көрсөтүү';

  @override
  String get catalogTypeNormal => 'Жөнөкөй';

  @override
  String get catalogTypeWeight => 'Салмактык';

  @override
  String get catalogTypeInner => 'Ички';

  @override
  String get catalogTypePackage => 'Топтом';

  @override
  String get catalogTypeService => 'Кызмат';

  @override
  String get catalogMeasurePiece => 'Даана';

  @override
  String get catalogMeasureKg => 'Килограмм';

  @override
  String get catalogMeasureLiter => 'Литр';

  @override
  String get catalogMeasureMeter => 'Метр';

  @override
  String get catalogNameRequired => 'Аталышын жазыңыз';

  @override
  String get catalogPriceRequired => 'Баасын жазыңыз';

  @override
  String get catalogPriceInvalid => 'Баа 0дөн жогору болушу керек';

  @override
  String get catalogBarcodeExists => 'Бул штрихкоддогу товар бар';

  @override
  String get catalogCategories => 'Категориялар';

  @override
  String get catalogAllCategories => 'Бардык категориялар';

  @override
  String get catalogNoCategories => 'Категориялар жок';

  @override
  String get catalogQuickProductCategory => 'Ыкчам товар категориясы';

  @override
  String get catalogAddCategory => 'Категория кошуу';

  @override
  String get catalogCategoryName => 'Категория аталышы';

  @override
  String get catalogManageCategories => 'Категорияларды башкаруу';

  @override
  String get catalogCategoryHasProducts =>
      'Жоюу мүмкүн эмес: категорияда товарлар бар';

  @override
  String get catalogConfirmDeleteCategory => 'Категорияны жоюу';

  @override
  String get catalogMenuCategories => 'Меню категориялары';

  @override
  String get catalogParentCategory => 'Ата-эне категория';

  @override
  String get catalogRootCategory => 'Тамыр (ата-энесиз)';

  @override
  String get telegramErrorPhoneSendFailed => 'Телефонго код жөнөтүлгөн жок';

  @override
  String get telegramErrorQrAuthFailed => 'QR-код аркылуу авторизация катасы';

  @override
  String get telegramErrorWrongCode => 'Ырастоо коду туура эмес';

  @override
  String get telegramErrorWrongPassword => 'Сырсөз туура эмес';

  @override
  String get telegramErrorRegistrationFailed => 'Каттоо катасы';

  @override
  String get telegramErrorChannelSearchFailed => 'Каналдарды издөө катасы';

  @override
  String get telegramErrorChannelConnectFailed => 'Каналдарга кошулуу катасы';

  @override
  String get telegramErrorChannelCreateFailed => 'Каналдарды түзүү катасы';

  @override
  String get hwSettingsTitle => 'Жабдыктар';

  @override
  String get hwSettingsSubtitle => 'Сканер, дисплей, терминалдар';

  @override
  String get terminalServiceTitle => 'Браузер терминалдары';

  @override
  String get terminalServiceSubtitle =>
      'Планшет же телефон — жумуш орду катары';

  @override
  String get terminalServiceEnable => 'Браузер терминалдарына кызмат кылуу';

  @override
  String get terminalServiceEnabledNote =>
      'Касса дүкөн тармагын угат. Терминалдар туташа алат.';

  @override
  String get terminalServiceDisabledNote =>
      'Касса өзүн гана угат. Тармакка порт ачылган эмес, терминалдар туташа албайт.';

  @override
  String get terminalServiceRestartNote =>
      'Өзгөрүү касса кайра иштетилгенден кийин күчүнө кирет.';

  @override
  String get terminalServiceAddress => 'Терминал үчүн дарек';

  @override
  String get terminalServiceAddressHint =>
      'Бул даректи планшеттин браузеринде ачыңыз. Аты ачылбаса, кассанын IP-дарегин териңиз.';

  @override
  String get pairingTitle => 'Терминалды байланыштыруу';

  @override
  String get pairingSubtitle => 'Жаңы түзмөк үчүн код';

  @override
  String get pairingDisabledNote =>
      'Касса браузердик терминалдарга кызмат көрсөтпөйт. Байланыштыруу коду үчүн кызматты күйгүзүңүз.';

  @override
  String get pairingDisabledAction => 'Терминал жөндөөлөрүн ачуу';

  @override
  String get pairingAddressLabel => 'Жаңы түзмөк үчүн шилтеме';

  @override
  String get pairingAddressHint =>
      'Бул даректи жаңы түзмөктө толугу менен териңиз же көчүрүңүз — код анын ичинде.';

  @override
  String get pairingLinkPending =>
      'Шилтеме сиз код бергенден кийин ушул жерде пайда болот.';

  @override
  String get pairingRestartNote =>
      'Терминал кызматы жөндөөлөрдө күйгүзүлгөн, бирок бул касса аны менен азырынча кайра күйгүзүлгөн эмес — дарек жооп бербейт. Кассаны кайра күйгүзүңүз.';

  @override
  String get pairingMint => 'Код берүү';

  @override
  String get pairingMintAgain => 'Жаңы код берүү';

  @override
  String get pairingCodeLabel => 'Байланыштыруу коду';

  @override
  String pairingExpiresAt(String time) {
    return '$time чейин жарактуу';
  }

  @override
  String get pairingOnceNote =>
      'Код азыр гана көрсөтүлөт — бул экрандан кетсеңиз, ал жоголот. Жаңы код берүү, эгер мурункусу колдонулбаса, аны жокко чыгарат. Бул код шилтемени ачканда жумшалат — түзмөктөгү кирүү экраны андан кийин өзүнчө, экинчи кодду сурайт: ошол учурда жаңы код бериңиз.';

  @override
  String get enrolTitle => 'Терминалды байланыштыруу';

  @override
  String get enrolInstructions =>
      'Бул түзмөк азырынча кассага байланыштырылган эмес. Операторду кассада «Терминалды байланыштыруу» экранын ачууну сураңыз жана ошол жерде көрсөтүлгөн кодду киргизиңиз.';

  @override
  String get enrolCodeLabel => 'Байланыштыруу коду';

  @override
  String get enrolSubmit => 'Байланыштыруу';

  @override
  String get accountsSettingsTitle => 'Төлөм эсептери';

  @override
  String get accountsSettingsSubtitle => 'Накталай жана карта эсептери';

  @override
  String get accountsSettingsAdd => 'Эсеп кошуу';

  @override
  String get accountsSettingsEdit => 'Эсепти өзгөртүү';

  @override
  String get accountsSettingsEmpty => 'Төлөм эсептери жок';

  @override
  String get accountsSettingsName => 'Эсеп аты';

  @override
  String get accountsSettingsType => 'Эсеп түрү';

  @override
  String get accountsSettingsTypePOS => 'Касса (накталай)';

  @override
  String get accountsSettingsTypeBank => 'Банк (карта)';

  @override
  String get accountsSettingsTypeCash => 'Накталай';

  @override
  String get accountsSettingsTypeSystem => 'Системалык';

  @override
  String get accountsSettingsTypeBonus => 'Бонустук';

  @override
  String get accountsSettingsTypeOther => 'Башка';

  @override
  String get accountsSettingsBalance => 'Баланс';

  @override
  String get accountsSettingsVisible => 'POS';

  @override
  String get accountsSettingsVisibleToPos => 'POS-то көрүнөт';

  @override
  String get hwSettingsSaved => 'Жабдык параметрлери сакталды';

  @override
  String get hwScannerTitle => 'Штрих-код сканери';

  @override
  String get hwScannerMode => 'Сканер режими';

  @override
  String get hwScannerModeKeyboard => 'USB / клавиатура (wedge)';

  @override
  String get hwScannerModeSerial => 'Сериялык';

  @override
  String get hwScannerModeCamera => 'Камера';

  @override
  String get hwScannerModeHint => 'USB сканерлер ушул режимде иштейт';

  @override
  String get hwScannerTimeout => 'Таймаут';

  @override
  String get hwScannerMinLength => 'Мин. узундук';

  @override
  String get hwScannerMaxLength => 'Макс. узундук';

  @override
  String get hwDisplayTitle => 'Сатып алуучу дисплейи';

  @override
  String get hwDisplayModel => 'Модель';

  @override
  String get hwDisplayModelLed8 => 'LED 8 символ';

  @override
  String get hwDisplayModelVfd20 => 'VFD 20x2';

  @override
  String get hwDisplayPort => 'COM-порт';

  @override
  String get hwDisplayBaudRate => 'Ылдамдык';

  @override
  String get hwDisplayDisabled => 'Сатып алуучу дисплейи өчүрүлгөн';

  @override
  String get hwDrawerTitle => 'Кассалык ящик';

  @override
  String get hwDrawerMode => 'Ачуу режими';

  @override
  String get hwDrawerModePrinter => 'Принтер аркылуу';

  @override
  String get hwDrawerModeSerial => 'Сериялык порт';

  @override
  String get hwDrawerPort => 'COM-порт';

  @override
  String get hwTerminalsTitle => 'Төлөм терминалдары';

  @override
  String get hwTerminalIp => 'IP-дарек';

  @override
  String get hwTerminalPort => 'Порт';

  @override
  String get hwTerminalMerchantId => 'Merchant ID';

  @override
  String get hwTerminalTerminalId => 'Terminal ID';

  @override
  String get catalogExportCsv => 'CSV экспорттоо';

  @override
  String get catalogImport => 'Импорттоо';

  @override
  String get catalogFilterColumn => 'Чыпка...';

  @override
  String catalogExportSuccess(String path) {
    return '$path файлына экспорттолду';
  }

  @override
  String get catalogExportFailed => 'Экспорттоо катасы';

  @override
  String get catalogImportResults => 'Импорттун жыйынтыктары';

  @override
  String catalogImportImported(int count) {
    return 'Импорттолду: $count';
  }

  @override
  String catalogImportUpdated(int count) {
    return 'Жаңыртылды: $count';
  }

  @override
  String catalogImportSkipped(int count) {
    return 'Өткөрүлүп жиберилди: $count';
  }

  @override
  String get catalogImportErrors => 'Каталар:';

  @override
  String get catalogTypeConsumable => 'Чыгым материалы';

  @override
  String get catalogFilterConsumable => 'Чыгымдар';

  @override
  String get catalogFilterInner => 'Ички';

  @override
  String get serviceMarkConsumable => 'Чыгым материалы';

  @override
  String get serviceConsumableSearch => 'Товар / чыгымды издөө';

  @override
  String get serviceConsumableSelected => 'Тандалган товар';

  @override
  String get serviceQuickServicesTitle => 'Тез кызматтар';

  @override
  String get serviceQuickServicesEmpty => 'Тез кызматтар жок';

  @override
  String get serviceIntakeItems => 'Кабыл алынуучу буюмдар';

  @override
  String get serviceItemName => 'Эмнени кабыл аласыз (буюм, нерсе, түзмөк)';

  @override
  String get serviceItemDescription =>
      'Көйгөйдүн сүрөттөмөсү / кардардын каалоолору';

  @override
  String get serviceItemSerial => 'Сериялык номер / белгилөө';

  @override
  String get serviceItemAdd => 'Буюм кошуу';

  @override
  String get serviceItemEmpty => 'Жок дегенде бир буюм кошуңуз';

  @override
  String serviceItemCount(int count) {
    return '$count даана';
  }

  @override
  String get serviceClientQuickName => 'Кардардын аты';

  @override
  String get serviceClientQuickPhone => 'Кардардын телефону';

  @override
  String get serviceClientOrSearch => 'же базадан табуу';

  @override
  String get catalogTypeDish => 'Тамак';

  @override
  String get catalogFilterDish => 'Тамактар';

  @override
  String get dishCalculation => 'Калькуляция';

  @override
  String get dishCalculationStub =>
      'Калькуляция модулу кийинчерээк жеткиликтүү болот';

  @override
  String get dishIngredients => 'Ингредиенттер';

  @override
  String get serviceConsumablesTitle => 'Чыгым нормалары';

  @override
  String get serviceConsumablesEmpty => 'Чыгым материалдары жок';

  @override
  String get serviceConsumablesAdd => 'Чыгымды кошуу';

  @override
  String get serviceConsumableQuantity => '1 кызматка саны';

  @override
  String get serviceConsumablesAutoAdded => 'Чыгымдар автоматтык түрдө кошулду';

  @override
  String get catalogDescription => 'Сүрөттөмө';

  @override
  String get catalogImagePlaceholder => 'Сүрөт жүктөө үчүн басыңыз';

  @override
  String get catalogImageFromGallery => 'Выбрать из галереи';

  @override
  String get catalogImageFromCamera => 'Сделать фото';

  @override
  String get catalogImageRemove => 'Удалить фото';

  @override
  String get catalogImagePickError => 'Не удалось загрузить фото';

  @override
  String get globalRetry => 'Кайталоо';

  @override
  String get globalRefresh => 'Жаңылоо';

  @override
  String get globalReset => 'Тазалоо';

  @override
  String get globalApply => 'Колдонуу';

  @override
  String get globalCreate => 'Түзүү';

  @override
  String get stockOpSupply => 'Кабыл алуу';

  @override
  String get stockOpMovement => 'Жылдыруу';

  @override
  String get stockOpSupplierReturn => 'Жеткирүүчүгө кайтаруу';

  @override
  String get stockOpMovementShort => 'Жылд.';

  @override
  String get stockOpReturnShort => 'Кайтаруу';

  @override
  String get stockRegistryTitle => 'Кампа операциялары';

  @override
  String get stockRegistryAppBarTitle => 'Кампа';

  @override
  String get stockRegistryLoadError => 'Реестрди жүктөө мүмкүн болгон жок';

  @override
  String get stockRegistryResetFilters => 'Чыпкаларды тазалоо';

  @override
  String get stockRegistryFilters => 'Чыпкалар';

  @override
  String get stockRegistryEmpty => 'Жазуулар жок';

  @override
  String get stockRegistryEmptyFiltered => 'Чыпка параметрлерин өзгөртүңүз';

  @override
  String get stockRegistryEmptyCreate => 'Биринчи кампа операциясын түзүңүз';

  @override
  String get stockRegistryPeriod => 'Мезгил';

  @override
  String get stockRegistryOperationType => 'Операция түрү';

  @override
  String get stockRegistrySearchHint => 'Номер, контрагент боюнча издөө...';

  @override
  String get stockRegistryDateFrom => 'Баштап';

  @override
  String get stockRegistryDateTo => 'Чейин';

  @override
  String get stockRegistryColType => 'Түрү';

  @override
  String get stockRegistryColNumber => 'Номер';

  @override
  String get stockRegistryColCounterparty => 'Контрагент / Кампа';

  @override
  String get stockRegistryColProducts => 'Товарлар';

  @override
  String get stockRegistryColStatus => 'Статус';

  @override
  String get stockSyncDraft => 'Иштөөдө';

  @override
  String get stockSyncPending => 'Күтүүдө';

  @override
  String get stockSyncSending => 'Жөнөтүлүүдө';

  @override
  String get stockSyncSynced => 'Синхр.';

  @override
  String stockRegistryDetailType(String type) {
    return 'Түрү: $type';
  }

  @override
  String stockRegistryDetailDate(String date) {
    return 'Күнү: $date';
  }

  @override
  String stockRegistryDetailCounterparty(String name) {
    return 'Контрагент: $name';
  }

  @override
  String stockRegistryDetailAmount(String amount) {
    return 'Сумма: $amount';
  }

  @override
  String stockRegistryDetailProducts(int count) {
    return 'Товарлар: $count';
  }

  @override
  String stockRegistryDetailComment(String comment) {
    return 'Комментарий: $comment';
  }

  @override
  String stockRegistryProductsShort(int count) {
    return '$count тов.';
  }

  @override
  String stockRegistryPaginationRange(int from, int to, int total) {
    return '$from–$to / $total';
  }

  @override
  String get stockCreateSupplyTitle => 'Жаңы кабыл алуу';

  @override
  String get stockCreateSupplySubtitle => 'Жеткирүүчүдөн товар кабыл алуу';

  @override
  String get stockCreateMovementSubtitle => 'Кампалар ортосунда жылдыруу';

  @override
  String get stockCreateReturnSubtitle => 'Товарды жеткирүүчүгө кайтаруу';

  @override
  String get stockCreateWriteoffSubtitle =>
      'Списание товара (бой, порча, просрочка)';

  @override
  String get stockCreateInventorySubtitle => 'Пересчёт фактических остатков';

  @override
  String get serviceQueueActive => 'Активдүү';

  @override
  String get serviceScanQrTitle => 'Заказдын QR-белгисин сканерлөө';

  @override
  String get serviceScanQrHint => 'TELEPOS:SO:... же заказ номери';

  @override
  String get serviceIntakePhotos => 'Кабыл алуу сүрөтү';

  @override
  String get serviceIntakePhotosHint =>
      'Кабыл алынуучу буюмдардын сүрөтүн тартыңыз';

  @override
  String get expenseTypeOther => 'Башка';

  @override
  String get expenseTypeSmallPurchases => 'Майда сатып алуу';

  @override
  String get expenseTypeSalary => 'Айлык';

  @override
  String get expenseTypeUtilities => 'Коммуналдык';

  @override
  String get expenseTypeCollection => 'Инкассация';

  @override
  String get expenseTypeCustom => 'Ыңгайлаштырылган';

  @override
  String get networkTitle => 'Тармак жана туташуулар';

  @override
  String get networkUnavailableTitle =>
      'Бул бөлүм TelePOS OS түзмөгүндө гана жеткиликтүү';

  @override
  String get networkUnavailableDesc =>
      'telepos-sysd системалык демону табылган жок. Тармакты башкаруу POS TelePOS OS түзмөгүндө иштегенде гана колдонулат.';

  @override
  String get networkRefresh => 'Жаңылоо';

  @override
  String get networkSearch => 'Издөө';

  @override
  String get networkConnect => 'Туташуу';

  @override
  String get networkDisconnect => 'Ажыратуу';

  @override
  String get networkConnected => 'Туташты';

  @override
  String get networkEthernetTitle => 'Зымдуу тармак (Ethernet)';

  @override
  String get networkEthernetDesc =>
      'Кабелдик туташуунун абалы жана интернетке жеткиликтүүлүк.';

  @override
  String get networkCableLabel => 'Кабель';

  @override
  String get networkCableConnected => 'Туташты';

  @override
  String get networkCableNotConnected => 'Туташкан эмес';

  @override
  String get networkInternetLabel => 'Интернет';

  @override
  String get networkInternetAvailable => 'Жеткиликтүү';

  @override
  String get networkInternetUnavailable => 'Жеткиликсиз';

  @override
  String get networkWifiTitle => 'Wi-Fi';

  @override
  String get networkWifiDesc => 'Зымсыз тармакка туташуу.';

  @override
  String get networkWifiSearchHint =>
      'Тармактарды табуу үчүн «Издөө» баскычын басыңыз.';

  @override
  String get networkBluetoothTitle => 'Bluetooth';

  @override
  String get networkBluetoothDesc =>
      'Принтерлер, таразалар жана башка түзмөктөр менен жупташтыруу.';

  @override
  String get networkBluetoothSearchHint =>
      'Түзмөктөрдү табуу үчүн «Издөө» баскычын басыңыз.';

  @override
  String get networkBluetoothUnavailableInBrowser =>
      'Браузерде жеткиликсиз — Bluetooth кассанын өзүндө гана тууралайт.';

  @override
  String networkWifiPasswordTitle(String ssid) {
    return '«$ssid» үчүн сырсөз';
  }

  @override
  String get networkWifiPasswordLabel => 'Wi-Fi сырсөзү';

  @override
  String networkConnectedTo(String ssid) {
    return '$ssid тармагына туташты';
  }

  @override
  String networkConnectFailed(String ssid) {
    return '$ssid тармагына туташуу мүмкүн болгон жок';
  }

  @override
  String networkPaired(String device) {
    return 'Жупташтырылды: $device';
  }

  @override
  String get networkPairFailed => 'Жупташтыруу ишке ашкан жок';

  @override
  String get networkEthernetConfigure => 'Настроить';

  @override
  String get networkEthernetConfigTitle => 'Настройка Ethernet';

  @override
  String get networkEthernetInterface => 'Интерфейс';

  @override
  String get networkEthernetCurrentIp => 'Текущий IP';

  @override
  String get networkEthernetMode => 'Способ получения адреса';

  @override
  String get networkEthernetModeDhcp => 'Автоматически (DHCP)';

  @override
  String get networkEthernetModeStatic => 'Вручную (статический)';

  @override
  String get networkEthernetIpLabel => 'IP-адрес';

  @override
  String get networkEthernetPrefixLabel => 'Префикс (маска)';

  @override
  String get networkEthernetGatewayLabel => 'Шлюз';

  @override
  String get networkEthernetDnsLabel => 'DNS-сервер';

  @override
  String get networkEthernetApply => 'Применить';

  @override
  String get networkEthernetApplied => 'Настройки сети применены';

  @override
  String get networkEthernetApplyFailed =>
      'Не удалось применить настройки сети';

  @override
  String get networkEthernetNoInterface => 'Интерфейс Ethernet не определён';

  @override
  String get networkEthernetInvalidIp => 'Неверный IP-адрес';

  @override
  String get networkEthernetInvalidGateway => 'Неверный адрес шлюза';

  @override
  String get networkEthernetInvalidDns => 'Неверный адрес DNS';

  @override
  String get networkEthernetInvalidPrefix => 'Префикс должен быть от 0 до 32';

  @override
  String get networkEthernetIpRequired => 'Укажите IP-адрес';

  @override
  String get networkEthernetOptional => 'необязательно';

  @override
  String get applianceTitle => 'Система (TelePOS OS)';

  @override
  String get applianceHubSubtitle => 'Системаны башкаруу, тармак, драйверлер';

  @override
  String get applianceUnavailableDesc =>
      'telepos-sysd системалык демону табылган жок. Бул бөлүм POS TelePOS OS түзмөгүндө иштегенде гана колдонулат.';

  @override
  String get applianceNetworkTitle => 'Тармак жана туташуулар';

  @override
  String get applianceNetworkDesc =>
      'Wi-Fi, зымдуу тармак жана Bluetooth. Кирүү жана синхрондоштуруу үчүн керек.';

  @override
  String get applianceNetworkButton => 'Тармакты тууралоо';

  @override
  String get applianceDesktopTitle => 'Иш такта режими';

  @override
  String get applianceDesktopDesc =>
      'Колдонмолорду орнотуу жана тейлөө үчүн толук иш такта.';

  @override
  String get applianceCurrentMode => 'Учурдагы режим: ';

  @override
  String get applianceOpenDesktop => 'Иш тактаны ачуу';

  @override
  String get applianceDesktopUnavailable => 'Бул куроодо иш такта жеткиликсиз.';

  @override
  String get applianceModeKiosk => 'Касса (POS)';

  @override
  String get applianceModeDesktop => 'Иш такта';

  @override
  String get applianceDriversTitle => 'Перифериялык драйверлер';

  @override
  String get applianceDriversDesc =>
      'Принтерлердин, таразалардын жана төлөм терминалдарынын драйверлерин ишеничтүү TelePOS каталогунан орнотуу.';

  @override
  String get applianceDriversEmpty => 'Драйверлер каталогу бош.';

  @override
  String get applianceDriverInstall => 'Орнотуу';

  @override
  String get applianceDriverRemove => 'Өчүрүү';

  @override
  String applianceDriverInstalled(String title) {
    return 'Драйвер орнотулду: $title';
  }

  @override
  String applianceDriverRemoved(String title) {
    return 'Драйвер өчүрүлдү: $title';
  }

  @override
  String applianceError(String message) {
    return 'Ката: $message';
  }

  @override
  String get navNetwork => 'Тармак';

  @override
  String get navCollapseMenu => 'Менюну жыйноо';

  @override
  String get navExpandMenu => 'Менюну жайуу';

  @override
  String get languageSwitcherTooltip => 'Тил / Язык / Language';

  @override
  String get labelPrinterSettingsTitle => 'Этикетка принтери';

  @override
  String get labelPrinterSettingsSubtitle => 'Баалар жана штрих-коддор';

  @override
  String get labelPrinterLanguage => 'Принтер тили';

  @override
  String get labelPrinterSize => 'Этикетканын өлчөмү';

  @override
  String get labelPrinterWidthMm => 'Туурасы, мм';

  @override
  String get labelPrinterHeightMm => 'Бийиктиги, мм';

  @override
  String get labelPrinterTestSuccess => 'Этикетка басып чыгарууга жөнөтүлдү';

  @override
  String get labelPrinterNotConfigured =>
      'Этикетка принтери жөндөлгөн эмес. Жөндөөлөрдө дарегин көрсөтүңүз.';

  @override
  String get labelTemplatesTitle => 'Этикетка үлгүлөрү';

  @override
  String get labelTemplatesManage => 'Үлгүлөрдү башкаруу';

  @override
  String get labelTemplatesManageSubtitle =>
      'Жайгаштырууларды түзүү жана түзөтүү';

  @override
  String get labelTemplatesEmpty => 'Үлгүлөр табылган жок';

  @override
  String get labelTemplateNew => 'Жаңы үлгү';

  @override
  String get labelTemplateEdit => 'Үлгүнү түзөтүү';

  @override
  String get labelTemplateBuiltIn => 'Орнотулган';

  @override
  String get labelMmUnit => 'мм';

  @override
  String get labelTemplateDeleteTitle => 'Үлгүнү өчүрүү';

  @override
  String labelTemplateDeleteConfirm(String name) {
    return '«$name» үлгүсүн өчүрөсүзбү?';
  }

  @override
  String get labelTemplateName => 'Үлгүнүн аты';

  @override
  String get labelTemplateNameRequired => 'Үлгүнүн атын киргизиңиз';

  @override
  String get labelTemplatePreview => 'Алдын ала көрүү';

  @override
  String get labelTemplateFields => 'Талаалар';

  @override
  String get labelTemplateAddField => 'Талаа кошуу';

  @override
  String get labelTemplateNoFields =>
      'Талаалар жок. Жок дегенде бир талаа кошуңуз.';

  @override
  String get labelFieldKind => 'Талаа түрү';

  @override
  String get labelFieldText => 'Текст';

  @override
  String get labelFieldFontSize => 'Арип';

  @override
  String get labelFieldBold => 'Калың';

  @override
  String get labelFieldKindName => 'Аты';

  @override
  String get labelFieldKindPrice => 'Баасы';

  @override
  String get labelFieldKindBarcode => 'Штрих-код';

  @override
  String get labelFieldKindSku => 'Артикул';

  @override
  String get labelFieldKindDate => 'Күнү';

  @override
  String get labelFieldKindText => 'Текст';

  @override
  String get labelPrintTitle => 'Баа басып чыгаруу';

  @override
  String labelPrintBulkTitle(int count) {
    return 'Бааларды басып чыгаруу ($count)';
  }

  @override
  String get labelPrintChooseTemplate => 'Үлгүнү тандаңыз';

  @override
  String get labelPrintCopies => 'Көчүрмөлөр';

  @override
  String get labelPrintAction => 'Басып чыгаруу';

  @override
  String labelPrintedCount(int count) {
    return 'Басып чыгарылды: $count';
  }

  @override
  String get catalogPrintLabel => 'Баа басып чыгаруу';

  @override
  String get receiptTemplatesTitle => 'Чек шаблондору';

  @override
  String get receiptTemplatesSubtitle =>
      'Чектин жасалгасы: логотип, баш/аяк, БСН, QR, туурасы';

  @override
  String get receiptTemplatesEmpty => 'Шаблондор табылган жок';

  @override
  String get receiptTemplateNew => 'Жаңы шаблон';

  @override
  String get receiptTemplateEdit => 'Шаблонду түзөтүү';

  @override
  String get receiptTemplateBuiltIn => 'Орнотулган';

  @override
  String get receiptTemplateActive => 'Активдүү';

  @override
  String get receiptTemplateMakeActive => 'Активдүү кылуу';

  @override
  String get receiptTemplateName => 'Шаблондун аты';

  @override
  String get receiptTemplateNameRequired => 'Шаблондун атын киргизиңиз';

  @override
  String get receiptTemplatePreview => 'Алдын ала көрүү';

  @override
  String get receiptTemplatePaperWidth => 'Кагаздын туурасы';

  @override
  String get receiptTemplateContent => 'Чектин мазмуну';

  @override
  String get receiptTemplateHeaderFooter => 'Баш жана аяк';

  @override
  String get receiptTemplateHeaderText => 'Баш текст';

  @override
  String get receiptTemplateFooterText => 'Аяк текст';

  @override
  String get receiptTemplateExtraFooter => 'Кошумча аяк саптар';

  @override
  String get receiptTemplateExtraFooterHint =>
      'Ар бири өзүнчө сап (мисалы, кайтаруу шарттары)';

  @override
  String get receiptTemplateShowBin => 'БСН/ЖСН басып чыгаруу';

  @override
  String get receiptTemplateShowAddress => 'Дарек басып чыгаруу';

  @override
  String get receiptTemplateShowCashier => 'Касса/кассирди басып чыгаруу';

  @override
  String get receiptTemplateShowVat => 'КНС басып чыгаруу';

  @override
  String get receiptTemplateShowQr => 'Текшерүү шилтемесин басып чыгаруу (QR)';

  @override
  String get receiptTemplateShowItemNumbers => 'Позицияларды номерлөө';

  @override
  String get receiptTemplateShowLogo => 'Логотипти басып чыгаруу';

  @override
  String get receiptTemplateTestPrint => 'Сыноо басып чыгаруу';

  @override
  String get receiptTemplateTestPrintOk =>
      'Чектин үлгүсү басып чыгарууга жөнөтүлдү';

  @override
  String get receiptTemplateTestPrintFail =>
      'Басып чыгаруу ийгиликсиз (принтерди текшериңиз)';

  @override
  String get receiptTemplateDeleteTitle => 'Шаблонду өчүрүү';

  @override
  String get receiptTemplateHeaderHint =>
      'Бир нече сап: саламдашуу, акция, байланыш';

  @override
  String get receiptTemplateFooterHint =>
      'Бир нече сап: ыраазычылык, кайтаруу шарттары, сайт, социалдык тармактар';

  @override
  String get receiptTemplateAlignLeft => 'Солго';

  @override
  String get receiptTemplateAlignCenter => 'Ортого';

  @override
  String get receiptTemplateAlignRight => 'Оңго';

  @override
  String get receiptTemplateBold => 'Калың';

  @override
  String get receiptTemplateDoubleSize => 'Ири (эки эселенген өлчөм)';

  @override
  String get receiptTemplatePaperWidthHint =>
      'Тасманын туурасы принтердин жөндөөлөрүндө коюлат';

  @override
  String get receiptTemplateMandatoryNote =>
      'Милдеттүү реквизиттер — чектин номери, жыйынтык, төлөмдөр, КНС, фискалдык белги жана QR — ар дайым баш жана аяк бөлүгүнүн ортосунда басылат';

  @override
  String receiptTemplateDeleteConfirm(String name) {
    return '«$name» шаблонун өчүрөсүзбү?';
  }

  @override
  String get sysmTitle => 'Управление системой';

  @override
  String get sysmHubSubtitle => 'Состояние, обновления, бэкапы, питание';

  @override
  String get sysmOpenPanel => 'Открыть панель управления';

  @override
  String get sysmNoData => 'Нет данных';

  @override
  String get sysmGenericError => 'Не удалось выполнить операцию';

  @override
  String get sysmHealthTitle => 'Состояние системы';

  @override
  String get sysmHealthDesc =>
      'Загрузка процессора, память, диск, температура и время работы';

  @override
  String get sysmCpu => 'Процессор';

  @override
  String get sysmCores => 'ядер';

  @override
  String get sysmRam => 'Память';

  @override
  String get sysmMb => 'МБ';

  @override
  String get sysmDisk => 'Диск';

  @override
  String get sysmGb => 'ГБ';

  @override
  String get sysmGbFree => 'ГБ свободно';

  @override
  String get sysmTemperature => 'Температура';

  @override
  String get sysmUptime => 'Время работы';

  @override
  String get sysmDaysShort => 'д';

  @override
  String get sysmHoursShort => 'ч';

  @override
  String get sysmMinsShort => 'м';

  @override
  String get sysmUpdateTitle => 'Обновление ПО';

  @override
  String get sysmUpdateDesc => 'Проверка и установка обновлений системы';

  @override
  String get sysmCurrentVersion => 'Текущая версия';

  @override
  String get sysmLatestVersion => 'Доступная версия';

  @override
  String get sysmUpdateAvailable => 'Доступно обновление';

  @override
  String get sysmCheckUpdate => 'Проверить';

  @override
  String get sysmUpdateNow => 'Обновить';

  @override
  String get sysmUpdateConfirm =>
      'Система загрузит и установит обновление. После установки может потребоваться перезагрузка. Продолжить?';

  @override
  String get sysmUpdateStarted => 'Обновление запущено';

  @override
  String get sysmUpdateFailed => 'Не удалось обновить';

  @override
  String get sysmUpdatePhaseDownload => 'Загрузка обновления…';

  @override
  String get sysmUpdatePhaseApply => 'Установка обновления…';

  @override
  String get sysmRollback => 'Откатить версию';

  @override
  String get sysmRollbackConfirm => 'Откатиться к предыдущей версии системы?';

  @override
  String get sysmRollbackDone => 'Откат выполнен';

  @override
  String get sysmBackupTitle => 'Резервные копии';

  @override
  String get sysmBackupDesc =>
      'Создание, восстановление и перенос копий на USB';

  @override
  String get sysmBackupEmpty => 'Резервных копий нет';

  @override
  String get sysmBackupCreate => 'Создать копию';

  @override
  String get sysmBackupCreated => 'Резервная копия создана';

  @override
  String get sysmBackupRestore => 'Восстановить';

  @override
  String sysmBackupRestoreConfirm(String name) {
    return 'Восстановить систему из копии «$name»? Текущие данные будут заменены.';
  }

  @override
  String get sysmBackupRestored => 'Восстановление запущено';

  @override
  String get sysmBackupExport => 'На USB';

  @override
  String get sysmBackupExported => 'Копия экспортирована на USB';

  @override
  String get sysmBackupImport => 'Импорт с USB';

  @override
  String get sysmBackupImported => 'Копия импортирована с USB';

  @override
  String get sysmSnapshotTitle => 'Снапшоты и сброс';

  @override
  String get sysmSnapshotDesc =>
      'Точки восстановления системы и заводской сброс';

  @override
  String get sysmSnapshotUnsupported =>
      'Снапшоты не поддерживаются на этом устройстве';

  @override
  String get sysmSnapshotEmpty => 'Снапшотов нет';

  @override
  String get sysmSnapshotCreate => 'Создать снапшот';

  @override
  String get sysmSnapshotCreated => 'Снапшот создан';

  @override
  String get sysmSnapshotRollback => 'Откатить';

  @override
  String sysmSnapshotRollbackConfirm(String name) {
    return 'Откатить систему к снапшоту «$name»?';
  }

  @override
  String get sysmSnapshotRolledBack => 'Откат к снапшоту выполнен';

  @override
  String get sysmSnapshotRebootRequired =>
      'Откат выполнен. Требуется перезагрузка.';

  @override
  String get sysmFactoryReset => 'Заводской сброс';

  @override
  String get sysmFactoryResetWarn =>
      'Удалит все данные и настройки, вернёт устройство к заводскому состоянию.';

  @override
  String get sysmFactoryResetConfirm1 =>
      'Заводской сброс удалит ВСЕ данные, настройки и продажи. Это действие необратимо. Продолжить?';

  @override
  String get sysmFactoryResetConfirm2 =>
      'Вы уверены? Все данные будут безвозвратно удалены. Подтвердите заводской сброс.';

  @override
  String get sysmFactoryResetDo => 'Сбросить';

  @override
  String get sysmFactoryResetStarted => 'Заводской сброс запущен';

  @override
  String get sysmDisplayTitle => 'Экран';

  @override
  String get sysmDisplayDesc => 'Яркость и поворот экрана';

  @override
  String get sysmDisplayUnsupported =>
      'Бул түзмөктө башкарылуучу экран жок (backlight жок). Жарыктыкты жана бурулуну монитордун өзүндө жөнгө салыңыз.';

  @override
  String get sysmRotation => 'Поворот экрана';

  @override
  String get sysmRemoteTitle => 'Удалённая поддержка';

  @override
  String get sysmRemoteDesc =>
      'Временный защищённый доступ для службы поддержки';

  @override
  String get sysmRemoteHelp =>
      '«Колдоону калыбына келтирүү» TelePOS колдоо кызматына көйгөйдү алыстан чечүү үчүн приставкага убактылуу корголгон (SSH) канал ачат. Кирүү 30 мүнөттөн кийин автоматтык түрдө жабылат. Колдоо суранганда гана күйгүзүңүз.';

  @override
  String get sysmRemoteOn => 'Доступ включён';

  @override
  String get sysmRemoteOff => 'Доступ выключен';

  @override
  String sysmRemoteExpires(String minutes) {
    return 'Истекает через $minutes мин';
  }

  @override
  String get sysmRemoteEnable => 'Включить на 30 минут';

  @override
  String get sysmRemoteEnabled => 'Удалённый доступ включён';

  @override
  String get sysmRemoteDisable => 'Отключить доступ';

  @override
  String get sysmRemoteDisabled => 'Удалённый доступ отключён';

  @override
  String get sysmPowerTitle => 'Питание';

  @override
  String get sysmPowerDesc => 'Перезагрузка и выключение устройства';

  @override
  String get sysmReboot => 'Перезагрузить';

  @override
  String get sysmRebootConfirm => 'Перезагрузить устройство сейчас?';

  @override
  String get sysmRebooting => 'Перезагрузка…';

  @override
  String get sysmShutdown => 'Выключить';

  @override
  String get sysmShutdownConfirm => 'Выключить устройство сейчас?';

  @override
  String get sysmShuttingDown => 'Выключение…';

  @override
  String get sysmTimeTitle => 'Время и часовой пояс';

  @override
  String get sysmTimeDesc =>
      'Текущее время, часовой пояс и синхронизация по NTP';

  @override
  String get sysmTimeCurrent => 'Текущее время';

  @override
  String get sysmTimezone => 'Часовой пояс';

  @override
  String get sysmTimezoneSave => 'Сохранить часовой пояс';

  @override
  String get sysmTimezoneSaved => 'Часовой пояс сохранён';

  @override
  String get sysmTimezoneSaveError => 'Не удалось сохранить часовой пояс';

  @override
  String get sysmNtpSync => 'Синхронизировать время (NTP)';

  @override
  String get sysmNtpSyncing => 'Синхронизация…';

  @override
  String get sysmNtpDone => 'Время синхронизировано';

  @override
  String get sysmNtpFailed => 'Не удалось синхронизировать время';

  @override
  String get sysmTerminalTitle => 'Терминал';

  @override
  String get sysmTerminalDesc =>
      'Диагностика и управление приставкой (командная строка)';

  @override
  String get sysmTerminalOpen => 'Открыть терминал';

  @override
  String get sysmTerminalRootNote =>
      'Команды выполняются как root на приставке.';

  @override
  String get sysmTerminalHint =>
      'Введите команду (например: systemctl status telepos-sysd)';

  @override
  String get sysmTerminalRun => 'Выполнить';

  @override
  String get sysmTerminalClear => 'Очистить вывод';

  @override
  String get sysmTerminalRunning => 'Выполняется…';

  @override
  String sysmTerminalExitCode(int code) {
    return 'Код возврата: $code';
  }

  @override
  String get sysmTerminalEmpty => 'Вывод появится здесь';

  @override
  String get sysmTerminalHistory => 'История команд';

  @override
  String get sysmTerminalPresets => 'Пресеты';

  @override
  String get sysmTerminalPresetsNetwork => 'Сеть';

  @override
  String get sysmTerminalPresetsPrinters => 'Принтеры';

  @override
  String get sysmTerminalPresetsSystem => 'Система';

  @override
  String get sysmTerminalPresetsTime => 'Время';

  @override
  String get sysmTermGroupDiagnostics => 'Диагностика';

  @override
  String get sysmTermGroupPrinter => 'Принтер';

  @override
  String get sysmTermGroupNetwork => 'Тармак';

  @override
  String get sysmTermGroupSystem => 'Система';

  @override
  String get sysmTermGroupTime => 'Убакыт';

  @override
  String get sysmTermDiagOsAndDaemon => 'ОС жана демон версиясы';

  @override
  String get sysmTermDiagNetworkStatus => 'Тармак: абал жана дарек';

  @override
  String get sysmTermDiagNetworkConnectivity => 'Тармак: байланыш';

  @override
  String get sysmTermDiagHardware => 'Жабдык: диск/эс тутум/принтерлер';

  @override
  String get sysmTermPrinterFixAuto => 'Принтерди оңдоо (авто)';

  @override
  String get sysmTermPrinterDiag => 'Принтер диагностикасы';

  @override
  String get sysmTermPrinterLoadUsblp => 'usblp модулин жүктөө';

  @override
  String get sysmTermPrinterNodesAndPerms =>
      'Принтер түйүндөрү жана уруксаттар';

  @override
  String get sysmTermPrinterLsusb => 'USB түзмөктөр (lsusb)';

  @override
  String get sysmTermPrinterCupsStatus => 'CUPS: абал жана кезектер';

  @override
  String get sysmTermPrinterGiveToKernel => 'Принтерди ядрого берүү (usblp)';

  @override
  String get sysmTermPrinterTestPrint => '/dev/usb/lp0 сыноо басып чыгаруу';

  @override
  String get sysmTermNetDeviceStatus => 'Түзмөктөрдүн абалы';

  @override
  String get sysmTermNetIpAddresses => 'IP даректер';

  @override
  String get sysmTermNetConnectEthernet => 'Ethernet туташтыруу';

  @override
  String get sysmTermNetReload => 'Тармакты кайра жүктөө';

  @override
  String get sysmTermNetPing => 'Пинг 8.8.8.8';

  @override
  String get sysmTermSysDisk => 'Диск';

  @override
  String get sysmTermSysMemory => 'Эс тутум';

  @override
  String get sysmTermSysSysdStatus => 'telepos-sysd абалы';

  @override
  String get sysmTermSysKioskLogs => 'Киоск журналдары';

  @override
  String get sysmTermTimeDateTime => 'Күн жана убакыт';

  @override
  String get sysmTermTimeNtpSync => 'NTP синхрондоо';

  @override
  String get labelPrinterDevicePath => 'Путь к устройству';

  @override
  String get labelPrinterDevicePathHint =>
      'Например: /dev/usb/lp0 (USB) или /dev/ttyUSB0 (Serial). Оставьте пустым для значения по умолчанию.';

  @override
  String get movementTitle => 'Перемещение';

  @override
  String get movementTitleFull => 'Перемещение товаров';

  @override
  String get movementFrom => 'Откуда *';

  @override
  String get movementTo => 'Куда *';

  @override
  String get movementLocationHint => 'Название склада / точки';

  @override
  String movementProductsCount(int count) {
    return 'Товаров: $count';
  }

  @override
  String movementSumLabel(String amount) {
    return 'Сумма: $amount';
  }

  @override
  String get movementAddProduct => 'Добавить товар';

  @override
  String get movementBarcodeHint => 'Штрихкод или артикул';

  @override
  String get movementComment => 'Комментарий';

  @override
  String get movementCommentHint => 'Примечание к перемещению...';

  @override
  String get movementCommentHintShort => 'Примечание...';

  @override
  String get movementProductNotFound => 'Товар не найден';

  @override
  String movementSavedMessage(int count, String amount) {
    return 'Перемещение сохранено: $count товаров на $amount';
  }

  @override
  String get movementCancelTitle => 'Отменить перемещение?';

  @override
  String get movementCancelMessage =>
      'Все несохранённые данные будут потеряны.';

  @override
  String get movementCancelConfirm => 'Да, отменить';

  @override
  String movementProductFallback(String ucode) {
    return 'Товар #$ucode';
  }

  @override
  String get movementPriceLabel => 'Цена';

  @override
  String get movementSaveError => 'Ошибка сохранения';

  @override
  String get movementEmptyTitle => 'Добавьте товары для перемещения';

  @override
  String get movementEmptyHint => 'Отсканируйте штрихкод или введите вручную';

  @override
  String get supplierReturnTitle => 'Возврат поставщику';

  @override
  String supplierReturnProductsCount(int count) {
    return 'Товаров: $count';
  }

  @override
  String supplierReturnSumLabel(String amount) {
    return 'Сумма: $amount';
  }

  @override
  String get supplierReturnSupplier => 'Поставщик *';

  @override
  String get supplierReturnSelectSupplier => 'Выберите поставщика';

  @override
  String get supplierReturnAccount => 'Счёт возврата';

  @override
  String get supplierReturnSelectAccount => 'Выберите счёт';

  @override
  String get supplierReturnAddProduct => 'Добавить товар';

  @override
  String get supplierReturnBarcodeHint => 'Штрихкод или артикул';

  @override
  String get supplierReturnComment => 'Комментарий';

  @override
  String get supplierReturnCommentHint => 'Причина возврата...';

  @override
  String get supplierReturnProductNotFound => 'Товар не найден';

  @override
  String supplierReturnSavedMessage(int count, String amount) {
    return 'Возврат сохранён: $count товаров на $amount';
  }

  @override
  String get supplierReturnCancelTitle => 'Отменить возврат?';

  @override
  String get supplierReturnCancelMessage =>
      'Все несохранённые данные будут потеряны.';

  @override
  String get supplierReturnCancelConfirm => 'Да, отменить';

  @override
  String supplierReturnProductFallback(String ucode) {
    return 'Товар #$ucode';
  }

  @override
  String get supplierReturnNoSuppliers => 'Нет поставщиков';

  @override
  String get supplierReturnNoAccounts => 'Нет счетов';

  @override
  String supplierReturnBalance(String amount) {
    return 'Баланс: $amount';
  }

  @override
  String get supplierReturnPriceLabel => 'Цена';

  @override
  String get supplierReturnSaveError => 'Ошибка сохранения';

  @override
  String get supplierReturnEmptyTitle => 'Добавьте товары для возврата';

  @override
  String get supplierReturnEmptyHint =>
      'Отсканируйте штрихкод или введите вручную';

  @override
  String get esfSettingsTitle => 'ЭСФ (электронные счета-фактуры)';

  @override
  String get esfSettingsSubtitle => 'Реквизиты, ЭЦП, исходящие документы';

  @override
  String get esfSettingsSave => 'Сохранить';

  @override
  String get esfSettingsSaved => 'Настройки ЭСФ сохранены';

  @override
  String get esfSettingsSaveError => 'Ошибка сохранения настроек ЭСФ';

  @override
  String get esfSettingsEnable => 'Включить ЭСФ';

  @override
  String get esfSettingsEnableSubtitle =>
      'Формировать счета-фактуры по продажам B2B (по БИН покупателя)';

  @override
  String get esfSettingsOperator => 'Оператор ЭСФ';

  @override
  String get esfSettingsTestMode => 'Тестовый режим';

  @override
  String get esfSettingsSupplier => 'Реквизиты поставщика (наша организация)';

  @override
  String get esfSettingsBin => 'БИН/ИИН';

  @override
  String get esfSettingsName => 'Наименование';

  @override
  String get esfSettingsAddress => 'Адрес';

  @override
  String get esfSettingsVatPayer => 'Плательщик НДС';

  @override
  String get esfSettingsVatSeries => 'Серия свидетельства НДС';

  @override
  String get esfSettingsVatNumber => 'Номер свидетельства НДС';

  @override
  String get esfSettingsVatRate => 'Ставка НДС, %';

  @override
  String get esfSettingsEcp => 'ЭЦП (НУЦ РК)';

  @override
  String get esfSettingsEcpKeyPath => 'Путь к ключу ЭЦП';

  @override
  String get esfSettingsEcpKeyAlias => 'Алиас ключа';

  @override
  String get esfSettingsB2bOnly => 'Только B2B';

  @override
  String get esfSettingsB2bOnlySubtitle =>
      'Не формировать ЭСФ для розничных продаж физлицам';

  @override
  String get esfSettingsEcpHint =>
      'Для реальной выписки требуется ЭЦП НУЦ РК и профиль ИС ЭСФ. Черновики формируются и хранятся офлайн без ЭЦП.';

  @override
  String get esfSettingsWebkassaNote =>
      'Реквизиты выписки (ЭЦП, подключение, токен) берутся из настроек WebKassa (Фискализация) — один общий конфиг. Отдельная настройка ЭСФ-реквизитов здесь не требуется.';

  @override
  String get esfOutboxTitle => 'Исходящие ЭСФ';

  @override
  String get esfOutboxEmpty => 'Нет документов ЭСФ';

  @override
  String get esfOutboxEmptyHint =>
      'Счета-фактуры появятся здесь после продаж B2B';

  @override
  String get esfOutboxRetry => 'Повторить отправку';

  @override
  String get esfOutboxRetryAll => 'Повторить все';

  @override
  String esfOutboxRetryDone(int delivered, int queued, int failed) {
    return 'Обработано: доставлено $delivered, в очереди $queued, ошибок $failed';
  }

  @override
  String get esfOutboxStatusDraft => 'Черновик';

  @override
  String get esfOutboxStatusQueued => 'В очереди';

  @override
  String get esfOutboxStatusSubmitted => 'Отправлен';

  @override
  String get esfOutboxStatusDelivered => 'Зарегистрирован';

  @override
  String get esfOutboxStatusRejected => 'Отклонён';

  @override
  String get esfOutboxStatusRevoked => 'Отозван';

  @override
  String get esfOutboxStatusError => 'Ошибка';

  @override
  String esfOutboxAttempts(int count) {
    return 'Попыток: $count';
  }

  @override
  String esfOutboxRegNumber(String number) {
    return 'Рег. №: $number';
  }

  @override
  String get sntTitle => 'СНТ (сопроводительные накладные)';

  @override
  String get sntSubtitle => 'Виртуальный склад, движение товаров';

  @override
  String get sntEmpty => 'Нет документов СНТ';

  @override
  String get sntEmptyHint =>
      'СНТ формируются автоматически после приёмки прослеживаемых товаров';

  @override
  String get sntRefresh => 'Обновить очередь';

  @override
  String sntDrainDone(int submitted, int remaining, int failed) {
    return 'Обработано: отправлено $submitted, в очереди $remaining, ошибок $failed';
  }

  @override
  String get sntDirectionInbound => 'Входящая';

  @override
  String get sntDirectionOutbound => 'Исходящая';

  @override
  String get sntStatusDraft => 'Черновик';

  @override
  String get sntStatusQueued => 'В очереди';

  @override
  String get sntStatusRegistered => 'Зарегистрирована';

  @override
  String get sntStatusDelivered => 'Доставлена';

  @override
  String get sntStatusConfirmed => 'Подтверждена';

  @override
  String get sntStatusRejected => 'Отклонена';

  @override
  String get sntStatusRevoked => 'Отозвана';

  @override
  String get sntStatusAnnulled => 'Аннулирована';

  @override
  String get sntStatusFailed => 'Ошибка';

  @override
  String sntLinesCount(int count) {
    return 'Позиций: $count';
  }

  @override
  String sntRegNumber(String number) {
    return 'Рег. №: $number';
  }

  @override
  String get sntNotConfigured =>
      'СНТ / Виртуальный склад не настроены. Документы хранятся локально и будут отправлены после настройки ЭЦП.';

  @override
  String get sntConfigure => 'Настроить СНТ';

  @override
  String get sntSettingsTitle => 'Настройки СНТ';

  @override
  String get sntSettingsOperator => 'Оператор / способ отправки';

  @override
  String get sntSettingsEnable => 'Включить СНТ';

  @override
  String get sntSettingsEnableSubtitle =>
      'Сборка и отправка сопроводительных накладных (ИС ЭСФ)';

  @override
  String get sntSettingsProvider => 'Способ отправки';

  @override
  String get sntSettingsTestMode => 'Тестовый режим';

  @override
  String get sntSettingsRequisites => 'Реквизиты налогоплательщика';

  @override
  String get sntSettingsOwnBin => 'БИН / ИИН (наш)';

  @override
  String get sntSettingsWarehouseCode => 'Код виртуального склада';

  @override
  String get sntSettingsBackend => 'TelePOS backend (прокси ИС ЭСФ)';

  @override
  String get sntSettingsBackendUrl => 'URL бэкенда';

  @override
  String get sntSettingsApiKey => 'API-ключ';

  @override
  String get sntSettingsEcp => 'ЭЦП (НУЦ РК)';

  @override
  String get sntSettingsCertPath => 'Путь к ключу ЭЦП';

  @override
  String get sntSettingsCertPassword => 'Пароль ключа';

  @override
  String get sntSettingsEcpHint =>
      'Реальная отправка СНТ требует ЭЦП НУЦ РК и зарегистрированного профиля ИС ЭСФ. Без ЭЦП документы собираются и хранятся локально (Виртуальный склад работает офлайн).';

  @override
  String get sntSettingsSharedEsfHint =>
      'СНТ и ЭСФ — подсистемы КГД. БИН и ЭЦП можно настроить на экране ЭСФ.';

  @override
  String get sntSettingsWebkassaNote =>
      'Реквизиты подключения (логин, apiKey, касса, ЭЦП) берутся из настроек WebKassa (Фискализация) — один общий конфиг.';

  @override
  String get sntSettingsOpenEsf => 'Настройки ЭСФ';

  @override
  String get sntSettingsSave => 'Сохранить';

  @override
  String get sntSettingsSaved => 'Настройки СНТ сохранены';

  @override
  String get sntSettingsSaveError => 'Не удалось сохранить настройки СНТ';

  @override
  String get sntSettingsBinRequired => 'Укажите БИН / ИИН налогоплательщика';

  @override
  String get esutdTitle => 'ЕСУТД (электронные ТТН)';

  @override
  String get esutdSubtitle => 'Товарно-транспортные накладные (e-waybill)';

  @override
  String get esutdNotConfigured =>
      'ЕСУТД не настроена. Укажите логин портала, чтобы загружать ТТН.';

  @override
  String get esutdNotConfiguredShort => 'ЕСУТД не настроена';

  @override
  String get esutdConfigure => 'Настроить ЕСУТД';

  @override
  String get esutdRefresh => 'Обновить';

  @override
  String get esutdInbound => 'Входящие ТТН';

  @override
  String get esutdOutbound => 'Исходящие ТТН';

  @override
  String get esutdEmpty => 'Нет ТТН';

  @override
  String esutdWaybillNumber(String number) {
    return 'ТТН № $number';
  }

  @override
  String esutdCargoCount(int count) {
    return 'Грузов: $count';
  }

  @override
  String get esutdSettingsTitle => 'Настройки ЕСУТД';

  @override
  String get esutdSettingsConnection => 'Подключение';

  @override
  String get esutdSettingsEnable => 'Включить ЕСУТД';

  @override
  String get esutdSettingsEnableSubtitle =>
      'Загрузка и отправка электронных ТТН (esutd.gov.kz)';

  @override
  String get esutdSettingsCredentials => 'Учётные данные портала';

  @override
  String get esutdSettingsEmail => 'Email (логин портала)';

  @override
  String get esutdSettingsPassword => 'Пароль';

  @override
  String get esutdSettingsApiUrl => 'URL API (необязательно)';

  @override
  String get esutdSettingsApiUrlHint =>
      'Оставьте пустым для значения по умолчанию: https://esutd.gov.kz/api';

  @override
  String get esutdSettingsTestLogin => 'Проверить вход / Войти';

  @override
  String get esutdSettingsSessionActive => 'Сессия активна';

  @override
  String get esutdSettingsLoginOk => 'Вход в ЕСУТД выполнен';

  @override
  String esutdSettingsLoginError(String error) {
    return 'Ошибка входа: $error';
  }

  @override
  String get esutdSettingsCredsRequired =>
      'Укажите email и пароль портала ЕСУТД';

  @override
  String get esutdSettingsSave => 'Сохранить';

  @override
  String get esutdSettingsSaved => 'Настройки ЕСУТД сохранены';

  @override
  String get esutdSettingsSaveError => 'Не удалось сохранить настройки ЕСУТД';

  @override
  String get esutdSettingsHint =>
      'ЕСУТД не имеет публичного API. Интеграция использует внутренние эндпоинты портала: вход по логину/паролю даёт сессию, которая переиспользуется и автоматически обновляется. Создание/подтверждение ТТН требует сложных справочников (КАТО, классификатор товаров, перевозчики) и пока недоступно из POS.';

  @override
  String get ismptSettingsTitle => 'Настройки ИС МПТ';

  @override
  String get ismptSettingsSubtitle => 'Маркировка (Честный знак KZ)';

  @override
  String get ismptSettingsOperator => 'Оператор / способ отправки';

  @override
  String get ismptSettingsEnable => 'Включить ИС МПТ';

  @override
  String get ismptSettingsEnableSubtitle =>
      'Проверка и отправка кодов маркировки (ismet.kz / Tañba)';

  @override
  String get ismptSettingsBackend => 'Бэкенд';

  @override
  String get ismptSettingsTestMode => 'Тестовый режим';

  @override
  String get ismptSettingsRequisites => 'Реквизиты налогоплательщика';

  @override
  String get ismptSettingsOwnBin => 'БИН / ИИН (наш)';

  @override
  String get ismptSettingsApi => 'True API (ismet.kz)';

  @override
  String get ismptSettingsApiUrl => 'URL API';

  @override
  String get ismptSettingsApiKey => 'API-ключ / токен';

  @override
  String get ismptSettingsEcp => 'ЭЦП (НУЦ РК)';

  @override
  String get ismptSettingsCertPath => 'Путь к ключу ЭЦП';

  @override
  String get ismptSettingsCertPassword => 'Пароль ключа';

  @override
  String get ismptSettingsEcpHint =>
      'Реальная работа с ИС МПТ требует ЭЦП НУЦ РК и зарегистрированного профиля участника оборота. Без ЭЦП коды маркировки принимаются и хранятся локально (приёмка работает офлайн, продажа не блокируется).';

  @override
  String get ismptSettingsSharedEsfHint =>
      'ИС МПТ и ЭСФ — подсистемы КГД. БИН и ЭЦП можно настроить на экране ЭСФ.';

  @override
  String get ismptSettingsWebkassaNote =>
      'Проверка кодов маркировки идёт через WebKassa. Реквизиты подключения (логин, apiKey, касса, ЭЦП) берутся из настроек WebKassa (Фискализация) — один общий конфиг.';

  @override
  String get ismptSettingsOpenEsf => 'Настройки ЭСФ';

  @override
  String get ismptSettingsSave => 'Сохранить';

  @override
  String get ismptSettingsSaved => 'Настройки ИС МПТ сохранены';

  @override
  String get ismptSettingsSaveError => 'Не удалось сохранить настройки ИС МПТ';

  @override
  String get ismptSettingsBinRequired => 'Укажите БИН / ИИН налогоплательщика';

  @override
  String get reorderRulesTitle => 'Правила перезаказа';

  @override
  String get reorderRulesSubtitle => 'Минимальный остаток по товарам';

  @override
  String get reorderRulesEmpty => 'Нет правил перезаказа';

  @override
  String get reorderRulesEmptyHint =>
      'Задайте минимальный остаток для товаров, чтобы получать сигналы дозаказа';

  @override
  String get reorderRulesAdd => 'Добавить правило';

  @override
  String get reorderRulesMinStock => 'Минимальный остаток';

  @override
  String get reorderRulesReorderQty => 'Размер заказа';

  @override
  String get reorderRulesProduct => 'Товар (ucode)';

  @override
  String get reorderRulesProductHint => 'Код товара';

  @override
  String get reorderRulesSave => 'Сохранить';

  @override
  String get reorderRulesSaved => 'Правило сохранено';

  @override
  String get reorderRulesInvalid => 'Укажите код товара и минимальный остаток';

  @override
  String reorderRulesBelowPoint(int count) {
    return 'Ниже точки перезаказа: $count';
  }

  @override
  String get reorderRulesEditTitle => 'Правило перезаказа';

  @override
  String get supplierOrderRuleBased => 'По правилам перезаказа';

  @override
  String supplierOrderGlobalThreshold(String threshold) {
    return 'Глобальный порог ($threshold)';
  }

  @override
  String get catalogPageFirst => 'Биринчи';

  @override
  String get catalogPagePrev => 'Артка';

  @override
  String get catalogPageNext => 'Алдыга';

  @override
  String get catalogPageLast => 'Акыркы';

  @override
  String get catalogGoToPage => 'Бетке өтүү';

  @override
  String catalogPageOf(int total) {
    return '$total ичинен бет';
  }

  @override
  String get shiftClosedGateTitle => 'Алмашуу жабык';

  @override
  String get shiftClosedGateMessage =>
      'Операцияларды улантуу үчүн алмашууну ачыңыз.';

  @override
  String get shiftClosedGateOpen => 'Алмашууну ачуу';

  @override
  String get sysmTerminalPresetsDiag => 'Диагностика';

  @override
  String get wmsDashboardTitle => 'WMS — Кампаны башкаруу';

  @override
  String get wmsDashboardTitleShort => 'WMS — Кампа';

  @override
  String get wmsSettings => 'WMS жөндөөлөрү';

  @override
  String get wmsSettingsSubtitle => 'Модулдердин конфигурациясы';

  @override
  String get wmsModuleWarehouses => 'Кампалар';

  @override
  String get wmsModuleWarehousesSubtitle => 'Кампалар, аймактар, уячалар';

  @override
  String get wmsModuleBatches => 'Партиялар';

  @override
  String get wmsModuleBatchesSubtitle => 'Партиялык эсеп';

  @override
  String get wmsModuleCellStock => 'Уячалардагы калдыктар';

  @override
  String get wmsModuleCellStockSubtitle => 'Калдыктар, жайгаштыруу, тандоо';

  @override
  String get wmsModuleSerials => 'Сериялык эсеп';

  @override
  String get wmsModuleSerialsSubtitle => 'Сериялык номерлер';

  @override
  String get wmsModuleMarking => 'Маркировка';

  @override
  String get wmsModuleMarkingSubtitle => 'Маркировка коддору';

  @override
  String get wmsModuleClaims => 'Доолор';

  @override
  String get wmsModuleClaimsSubtitle => 'Доолор жана кайтаруулар';

  @override
  String get wmsWarehousesAndCells => 'Кампалар жана уячалар';

  @override
  String get wmsWarehouses => 'Кампалар';

  @override
  String get wmsAddWarehouse => 'Кампа кошуу';

  @override
  String get wmsNoWarehouses => 'Кампалар жок';

  @override
  String get wmsNoName => 'Аты жок';

  @override
  String get wmsZones => 'Аймактар';

  @override
  String wmsZonesNamed(String name) {
    return 'Аймактар: $name';
  }

  @override
  String get wmsAddZone => 'Аймак кошуу';

  @override
  String get wmsSelectWarehouse => 'Кампаны тандаңыз';

  @override
  String get wmsNoZones => 'Аймактар жок';

  @override
  String get wmsCells => 'Уячалар';

  @override
  String wmsCellsNamed(String name) {
    return 'Уячалар: $name';
  }

  @override
  String get wmsGenerate => 'Генерациялоо';

  @override
  String get wmsSelectZone => 'Аймакты тандаңыз';

  @override
  String get wmsNoCells => 'Уячалар жок';

  @override
  String get wmsNoAddress => 'Дареги жок';

  @override
  String get wmsCellBlocked => 'Бөгөттөлгөн';

  @override
  String wmsCellsCount(int count) {
    return '$count уяча';
  }

  @override
  String get wmsNewWarehouse => 'Жаңы кампа';

  @override
  String get wmsWarehouseCode => 'Кампа коду';

  @override
  String get wmsName => 'Аталышы';

  @override
  String get wmsError => 'Ката';

  @override
  String get wmsCreate => 'Түзүү';

  @override
  String get wmsSelectWarehouseFirst => 'Адегенде кампаны тандаңыз';

  @override
  String get wmsNewZone => 'Жаңы аймак';

  @override
  String get wmsZoneCode => 'Аймак коду';

  @override
  String get wmsSelectZoneFirst => 'Адегенде аймакты тандаңыз';

  @override
  String get wmsGenerateCells => 'Уячаларды генерациялоо';

  @override
  String get wmsRows => 'Катарлар';

  @override
  String get wmsRacks => 'Текчелер';

  @override
  String get wmsLevels => 'Деңгээлдер';

  @override
  String get wmsBins => 'Уячалар';

  @override
  String get wmsEditWarehouse => 'Кампаны түзөтүү';

  @override
  String get wmsAddress => 'Дарек';

  @override
  String get wmsDeleteWarehouseTitle => 'Кампаны өчүрөсүзбү?';

  @override
  String wmsDeleteWarehouseConfirm(String name) {
    return '\"$name\" кампасын өчүргүңүз келгенине ишенесизби?';
  }

  @override
  String get wmsCellStockTitle => 'Уячалардагы калдыктар';

  @override
  String get wmsPlace => 'Жайгаштыруу';

  @override
  String get wmsPick => 'Тандоо';

  @override
  String get wmsTransfer => 'Жылдыруу';

  @override
  String get wmsByCell => 'Уяча боюнча';

  @override
  String get wmsByProduct => 'Товар боюнча';

  @override
  String get wmsSearchCellHint => 'Уячанын ID же дарегин киргизиңиз...';

  @override
  String get wmsSearchProductHint => 'Товардын ucode киргизиңиз...';

  @override
  String get wmsCell => 'Уяча';

  @override
  String get wmsProductUcode => 'Товар коду (ucode)';

  @override
  String get wmsFind => 'Табуу';

  @override
  String get wmsEnterCellIdToSearch =>
      'Калдыктарды издөө үчүн уячанын ID киргизиңиз';

  @override
  String get wmsEnterUcodeToSearch => 'Издөө үчүн товардын ucode киргизиңиз';

  @override
  String wmsProductLabeled(String value) {
    return 'Товар: $value';
  }

  @override
  String wmsCellLabeled(String value) {
    return 'Уяча: $value';
  }

  @override
  String wmsStockSummary(String qty, String reserved, String available) {
    return 'Саны: $qty  |  Резерв: $reserved  |  Жеткиликтүү: $available';
  }

  @override
  String wmsBatchLabeled(String value) {
    return 'Партия: $value';
  }

  @override
  String get wmsQuantityShort => 'Саны';

  @override
  String get wmsReserved => 'Резерв';

  @override
  String get wmsAvailable => 'Жеткиликтүү';

  @override
  String get wmsBatch => 'Партия';

  @override
  String get wmsEnterNumericId => 'Сандык ID киргизиңиз';

  @override
  String get wmsPlaceStockTitle => 'Товарды уячага жайгаштыруу';

  @override
  String get wmsCellId => 'Уяча ID';

  @override
  String get wmsProductUcodeField => 'Товардын ucode';

  @override
  String get wmsQuantity => 'Саны';

  @override
  String get wmsBatchIdOptional => 'Партия ID (милдеттүү эмес)';

  @override
  String get wmsFillRequiredNumericFields =>
      'Милдеттүү талааларды толтуруңуз (сандык маанилер)';

  @override
  String wmsStockPlaced(String cellId) {
    return 'Товар $cellId уячасына жайгаштырылды';
  }

  @override
  String get wmsPlaceError => 'Жайгаштыруу катасы';

  @override
  String get wmsPickStockTitle => 'Товарды уячадан тандоо';

  @override
  String get wmsFillAllNumericFields =>
      'Бардык талааларды толтуруңуз (сандык маанилер)';

  @override
  String wmsStockPicked(String cellId) {
    return 'Товар $cellId уячасынан тандалды';
  }

  @override
  String get wmsPickError => 'Тандоо катасы';

  @override
  String get wmsTransferStockTitle => 'Товарды жылдыруу';

  @override
  String get wmsCellIdFrom => 'Уяча ID (кайдан)';

  @override
  String get wmsCellIdTo => 'Уяча ID (кайда)';

  @override
  String wmsStockTransferred(String from, String to) {
    return 'Товар $from уячасынан $to уячасына жылдырылды';
  }

  @override
  String get wmsTransferError => 'Жылдыруу катасы';

  @override
  String get wmsBatches => 'Партиялар';

  @override
  String get wmsBatchTrackingTitle => 'Партиялык эсеп';

  @override
  String get wmsBatchTabAll => 'Бардык партиялар';

  @override
  String get wmsBatchTabExpiring => 'Мөөнөтү бүтүп жаткан';

  @override
  String get wmsBatchTabExpired => 'Мөөнөтү өткөн';

  @override
  String get wmsBatchTabQuarantine => 'Карантин';

  @override
  String get wmsNoBatches => 'Партиялар жок';

  @override
  String get wmsNoExpiringBatches => 'Мөөнөтү бүтүп жаткан партиялар жок';

  @override
  String get wmsNoExpiredBatches => 'Мөөнөтү өткөн партиялар жок';

  @override
  String get wmsNoQuarantinedBatches => 'Карантиндеги партиялар жок';

  @override
  String get wmsSearchByUcodeHint => 'Товардын ucode боюнча издөө...';

  @override
  String get wmsNoNumber => 'Номерсиз';

  @override
  String wmsBatchCardSummary(String ucode, String expiry, String qty) {
    return 'Товар: $ucode  |  Мөөнөтү: $expiry  |  Саны: $qty';
  }

  @override
  String get wmsBatchNumber => 'Партия номери';

  @override
  String get wmsProduct => 'Товар';

  @override
  String get wmsExpiryDate => 'Жарактуулук мөөнөтү';

  @override
  String get wmsStatus => 'Абал';

  @override
  String get wmsActions => 'Аракеттер';

  @override
  String get wmsQuarantine => 'Карантин';

  @override
  String get wmsApprove => 'Жактыруу';

  @override
  String get wmsStatusQuarantine => 'Карантин';

  @override
  String get wmsStatusExpired => 'Мөөнөтү өткөн';

  @override
  String get wmsStatusExpiring => 'Мөөнөтү бүтүп жатат';

  @override
  String get wmsStatusOk => 'ОК';

  @override
  String get wmsMoveToQuarantine => 'Карантинге коюу';

  @override
  String wmsBatchQuarantined(String number) {
    return '$number партиясы карантинге коюлду';
  }

  @override
  String wmsBatchApproved(String number) {
    return '$number партиясы жактырылды';
  }

  @override
  String get wmsSearchBatchesByProduct => 'Товар боюнча партияларды издөө';

  @override
  String get wmsEnterProductCode => 'Товардын кодун киргизиңиз';

  @override
  String get wmsSerialTrackingTitle => 'Сериялык эсеп';

  @override
  String get wmsScan => 'Сканерлөө';

  @override
  String get wmsSearchBySerialHint => 'Сериялык номер боюнча издөө...';

  @override
  String get wmsNothingFound => 'Эч нерсе табылган жок';

  @override
  String get wmsEnterSerialToSearch => 'Издөө үчүн сериялык номер киргизиңиз';

  @override
  String get wmsRegister => 'Каттоо';

  @override
  String get wmsSelectSerial => 'Сериялык номерди тандаңыз';

  @override
  String get wmsSerialNumber => 'Сериялык номер';

  @override
  String get wmsLocation => 'Жайгашкан жери';

  @override
  String wmsCellHash(String id) {
    return 'Уяча #$id';
  }

  @override
  String get wmsDetails => 'Чоо-жайы';

  @override
  String get wmsMarking => 'Маркировка';

  @override
  String get wmsWarrantyUntil => 'Кепилдик мөөнөтү';

  @override
  String get wmsNotes => 'Эскертүүлөр';

  @override
  String get wmsMovementHistory => 'Кыймыл тарыхы';

  @override
  String get wmsNoData => 'Маалымат жок';

  @override
  String get wmsSerialStatusInStock => 'Кампада';

  @override
  String get wmsSerialStatusSold => 'Сатылды';

  @override
  String get wmsSerialStatusReturned => 'Кайтарылды';

  @override
  String get wmsSerialStatusWrittenOff => 'Эсептен чыгарылды';

  @override
  String get wmsSerialStatusUnknown => 'Белгисиз';

  @override
  String get wmsScannerUseHardware => 'Сканер: аппараттык сканерди колдонуңуз';

  @override
  String get wmsRegisterSerialTitle => 'Сериялык номерди каттоо';

  @override
  String get wmsSerialRegistered => 'Сериялык номер катталды';

  @override
  String get wmsMarkingCodesTitle => 'Маркировка коддору';

  @override
  String get wmsMarkingAccept => 'Кабыл алуу';

  @override
  String get wmsRefresh => 'Жаңыртуу';

  @override
  String get wmsIsMptSettings => 'ИС МПТ жөндөөлөрү';

  @override
  String get wmsMarkingAcceptTitle => 'Маркировка коддорун кабыл алуу';

  @override
  String get wmsSupplyIdOptional => 'Жеткирүү ID (милдеттүү эмес)';

  @override
  String get wmsMarkingCodesPerLine => 'Маркировка коддору (ар сапта бирден)';

  @override
  String get wmsAccept => 'Кабыл алуу';

  @override
  String get wmsNoCodesEntered => 'Бир да код киргизилген жок';

  @override
  String wmsAcceptedLocally(String count) {
    return 'Жергиликтүү кабыл алынды: $count (ИС МПТ — кийинкиге калтырылды)';
  }

  @override
  String wmsAccepted(String count) {
    return 'Кабыл алынды: $count';
  }

  @override
  String wmsAcceptError(String error) {
    return 'Кабыл алуу катасы: $error';
  }

  @override
  String wmsMarkingStatusResult(String status) {
    return 'МК абалы: $status';
  }

  @override
  String get wmsInCirculation => '(жүгүртүүдө)';

  @override
  String get wmsIsMptNoConnection =>
      'ИС МПТ менен байланыш жок — текшерүү кийинкиге калтырылды';

  @override
  String get wmsVerifyUnavailable =>
      'Текшерүү жеткиликсиз (ИС МПТ жөндөлгөн эмес)';

  @override
  String wmsVerifyError(String error) {
    return 'Текшерүү катасы: $error';
  }

  @override
  String get wmsNoMarkingCodes => 'Маркировка коддору жок';

  @override
  String get wmsVerifyStatus => 'Абалын текшерүү (ИС МПТ)';

  @override
  String get wmsMarkingStatusReceived => 'Алынды';

  @override
  String get wmsMarkingStatusInStock => 'Кампада';

  @override
  String get wmsMarkingStatusSold => 'Сатылды';

  @override
  String get wmsMarkingStatusReturned => 'Кайтарылды';

  @override
  String get wmsMarkingStatusRetired => 'Эсептен чыгарылды';

  @override
  String get wmsMarkingStatusBlocked => 'Бөгөттөлгөн';

  @override
  String get wmsClaims => 'Доолор';

  @override
  String get wmsClaimTabOpen => 'Ачык';

  @override
  String get wmsClaimTabInProgress => 'Иштөөдө';

  @override
  String get wmsClaimTabResolved => 'Чечилген';

  @override
  String get wmsNoOpenClaims => 'Ачык доолор жок';

  @override
  String get wmsNoInProgressClaims => 'Иштөөдөгү доолор жок';

  @override
  String get wmsNoResolvedClaims => 'Чечилген доолор жок';

  @override
  String get wmsNewClaim => 'Жаңы доо';

  @override
  String get wmsNumber => 'Номер';

  @override
  String get wmsType => 'Түрү';

  @override
  String get wmsSeverity => 'Олуттуулугу';

  @override
  String get wmsDate => 'Күнү';

  @override
  String get wmsSeverityLow => 'Төмөн';

  @override
  String get wmsSeverityMedium => 'Орточо';

  @override
  String get wmsSeverityHigh => 'Жогору';

  @override
  String get wmsSeverityCritical => 'Критикалык';

  @override
  String get wmsClaimTypeDefect => 'Жарак';

  @override
  String get wmsClaimTypeMissort => 'Сорттоо катасы';

  @override
  String get wmsClaimTypeShortage => 'Жетишсиздик';

  @override
  String get wmsClaimTypeDamage => 'Зыян';

  @override
  String get wmsClaimTypeOther => 'Башка';

  @override
  String get wmsProblemDescription => 'Көйгөйдүн сүрөттөлүшү';

  @override
  String get wmsClaimCreated => 'Доо түзүлдү';

  @override
  String wmsClaimTitle(String number) {
    return 'Доо $number';
  }

  @override
  String wmsTypeLabeled(String value) {
    return 'Түрү: $value';
  }

  @override
  String wmsSeverityLabeled(String value) {
    return 'Олуттуулугу: $value';
  }

  @override
  String wmsDateLabeled(String value) {
    return 'Күнү: $value';
  }

  @override
  String get wmsProblemDescriptionLabel => 'Көйгөйдүн сүрөттөлүшү:';

  @override
  String get wmsNoDescription => 'Сүрөттөмө жок';

  @override
  String get wmsResolutionLabel => 'Чечим:';

  @override
  String get wmsNotSpecified => 'Көрсөтүлгөн эмес';

  @override
  String get wmsHistoryLabel => 'Тарых:';

  @override
  String get wmsNoRecords => 'Жазуулар жок';

  @override
  String get wmsResolve => 'Чечүү';

  @override
  String get wmsResolveClaimTitle => 'Доону чечүү';

  @override
  String get wmsResolutionNotes => 'Чечим боюнча эскертүүлөр';

  @override
  String get wmsClaimResolved => 'Доо чечилди';

  @override
  String get setUserManagementTitle => 'Колдонуучулар жана уруксат';

  @override
  String get setUsersTitle => 'Колдонуучулар';

  @override
  String get setUsersSubtitle => 'Кирүүнү башкаруу';

  @override
  String get authSettingsTitle => 'Кирүү жана сеанс';

  @override
  String get authSettingsSubtitle => 'Кассирсиз кирүү жана сеанс мөөнөтү';

  @override
  String get authSettingsWalkUpTitle => 'Кассирди тандабай кирүү';

  @override
  String get authSettingsWalkUpSubtitle =>
      'Бир PIN атсыз киргизет. Бир нече кассир болгондо коопсуз эмес: демейки боюнча өчүрүлгөн.';

  @override
  String get authSettingsSessionTitle => 'Сеанс мөөнөтү';

  @override
  String get authSettingsSessionSubtitle =>
      'Кассир аракетсиз канча мүнөт сеансында калат. Дароо колдонулат, кассаны кайра иштетүү керек эмес.';

  @override
  String get authSettingsSessionMinutesLabel => 'Мүнөт';

  @override
  String get authSettingsSaved => 'Сакталды';

  @override
  String get authSettingsInvalidMinutes =>
      '1ден 1440ка чейинки бүтүн мүнөт санын киргизиңиз';

  @override
  String get sessionsTitle => 'Активдүү сеанстар';

  @override
  String get sessionsSubtitle => 'Азыр кассада ким бар, кнопка менен токтотуу';

  @override
  String get sessionsEmpty => 'Азыр кассада эч ким жок';

  @override
  String sessionsTerminalLabel(String id) {
    return 'Терминал №$id';
  }

  @override
  String sessionsTimes(String issued, String expires) {
    return 'Кирди $issued · мөөнөтү $expires';
  }

  @override
  String get sessionsRevoke => 'Аяктоо';

  @override
  String get sessionsRevokeConfirmTitle => 'Сеансты аяктоо керекпи?';

  @override
  String sessionsRevokeConfirmBody(String name) {
    return '«$name» кассадан дароо чыгарылат.';
  }

  @override
  String sessionsRevoked(String name) {
    return '«$name» сеансы аяктады';
  }

  @override
  String sessionsRevokeError(String error) {
    return 'Сеансты аяктоо мүмкүн болгон жок: $error';
  }

  @override
  String get setUsersEmpty => 'Колдонуучулар жок';

  @override
  String get setAddUser => 'Колдонуучу кошуу';

  @override
  String setUserNumber(String id) {
    return 'Колдонуучу №$id';
  }

  @override
  String get setUserActive => 'Активдүү';

  @override
  String setUsersLoadError(String error) {
    return 'Ката: $error';
  }

  @override
  String get setNewUser => 'Жаңы колдонуучу';

  @override
  String get setEditUser => 'Түзөтүү';

  @override
  String get setUserTabProfile => 'Профиль';

  @override
  String get setUserTabPermissions => 'Кирүү укуктары';

  @override
  String get setUserName => 'Аты';

  @override
  String get setUserNameRequired => 'Атын киргизиңиз';

  @override
  String get setUserPinLabel => 'PIN (4-6 сан)';

  @override
  String get setUserPinRequired => 'PIN киргизиңиз';

  @override
  String get setUserPinMin => 'Кеминде 4 сан';

  @override
  String get setUserPinRange => 'PIN 4-6 сан болушу керек';

  @override
  String get setUserRole => 'Ролу';

  @override
  String get setRoleOwner => 'Ээси';

  @override
  String get setRoleAdministrator => 'Администратор';

  @override
  String get setRoleUser => 'Колдонуучу';

  @override
  String get setRoleCashier => 'Кассир';

  @override
  String get setUserActiveDesc => 'Колдонуучу системага кире алат';

  @override
  String get setUserBlockedDesc => 'Кирүү бөгөттөлгөн';

  @override
  String get setUserOwnerFullAccess => 'Ээсинде толук уруксат бар';

  @override
  String get setUserSelectAll => 'Баарын тандоо';

  @override
  String get setUserDeselectAll => 'Баарын алып салуу';

  @override
  String get setDeleteUserTitle => 'Колдонуучуну өчүрөсүзбү?';

  @override
  String setDeleteUserConfirm(String name) {
    return '«$name» колдонуучусу өчүрүлөт. Бул аракетти артка кайтарууга болбойт.';
  }

  @override
  String setDeleteUserError(String error) {
    return 'Колдонуучуну өчүрүү мүмкүн болбоду: $error';
  }

  @override
  String get setUserNoEncryptionKey =>
      'Шифрлоо ачкычы тууралбаган. POS алгачкы тууралоосун аяктаңыз.';

  @override
  String get setUserPinEncryptFailed => 'PIN шифрлоо мүмкүн болбоду';

  @override
  String get setWmsTitle => 'WMS жөндөөлөрү';

  @override
  String get setWmsModules => 'WMS модулдары';

  @override
  String get setWmsCellStorage => 'Уячалуу сактоо';

  @override
  String get setWmsCellStorageDesc =>
      'Товарларды зоналар жана уячалар боюнча даректүү сактоо';

  @override
  String get setWmsBatchTracking => 'Партиялык эсеп';

  @override
  String get setWmsBatchTrackingDesc =>
      'Товарларды партиялар боюнча жеткирүүнү көзөмөлдөө менен эсепке алуу';

  @override
  String get setWmsSerialTracking => 'Сериялык эсеп';

  @override
  String get setWmsSerialTrackingDesc =>
      'Уникалдуу сериялык номерлер боюнча даналап эсеп';

  @override
  String get setWmsExpiryControl => 'Жарактуулук мөөнөтүн көзөмөлдөө';

  @override
  String get setWmsExpiryControlDesc =>
      'Мөөнөттүн бүтүшү жөнүндө эскертүүлөр жана автоматтык FEFO тандоо';

  @override
  String get setWmsMarking => 'Маркалоо';

  @override
  String get setWmsMarkingDesc =>
      'Милдеттүү маркалоо коддорун колдоо (DataMatrix, GS1)';

  @override
  String get setWmsWarranty => 'Кепилдик эсеби';

  @override
  String get setWmsWarrantyDesc =>
      'Сериялык номерлер боюнча кепилдик мөөнөттөрүн көзөмөлдөө';

  @override
  String get setWmsPickingStrategy => 'Тандоо стратегиясы';

  @override
  String get setWmsPickingStrategyDesc =>
      'Товарларды кампадан жөнөтүү тартибин аныктайт';

  @override
  String get setWmsStrategy => 'Стратегия';

  @override
  String get setWmsStrategyFefo =>
      'FEFO — мөөнөтү биринчи бүтөт, биринчи чыгат';

  @override
  String get setWmsStrategyFifo => 'FIFO — биринчи келди, биринчи кетти';

  @override
  String get setWmsStrategyLifo => 'LIFO — акыркы келди, биринчи кетти';

  @override
  String get setWmsCostMethod => 'Өздук нарканы эсептөө ыкмасы';

  @override
  String get setWmsCostMethodDesc =>
      'Сатуу учурунда өздук нарканы эсептен чыгаруу ыкмасы';

  @override
  String get setWmsMethod => 'Ыкма';

  @override
  String get setWmsCostFifo => 'FIFO — келүү тартиби боюнча';

  @override
  String get setWmsCostLifo => 'LIFO — тескери тартипте';

  @override
  String get setWmsCostAvg => 'Орточо салмактанган наркы';

  @override
  String get setWmsExpiryWarnDesc =>
      'Мөөнөт бүтүшүнө канча күн калганда эскертүү';

  @override
  String setWmsDaysShort(int days) {
    return '$days күн';
  }

  @override
  String get setWmsAbcAnalysis => 'ABC талдоо';

  @override
  String get setWmsAbcDesc =>
      'Товарларды жүгүртүү боюнча классификациялоо чектери';

  @override
  String get setWmsAbcCategoryA => 'A категориясы (жогорку жүгүртүү)';

  @override
  String get setWmsAbcCategoryB => 'B категориясы (орточо жүгүртүү)';

  @override
  String get setWmsAbcCategoryC => 'C категориясы (төмөнкү жүгүртүү)';

  @override
  String get setWmsSaved => 'WMS жөндөөлөрү сакталды';

  @override
  String get setWmsSaveError => 'WMS жөндөөлөрүн сактоо мүмкүн болбоду';

  @override
  String get setSalesPolicy => 'Сатуу саясаты';

  @override
  String get setSalesPolicyDesc => 'Сатуу учурунда калдыктарды көзөмөлдөө';

  @override
  String get setBlockOversell => 'Калдык жетишсиз болгондо сатууга тыюу салуу';

  @override
  String get setBlockOversellDesc =>
      'Чектеги саны калдыктан ашып кетсе, сатууну аяктабоо (терс калдыктан коргоо)';

  @override
  String get setScreenTouch => 'Экран жана тачскрин';

  @override
  String get setScreenTouchDesc => 'Сенсордук экрандагы ыңгайлуулук';

  @override
  String get setScrollAssist => 'Сенсордук экрандагы жылдыруу баскычтары';

  @override
  String get setScrollAssistDesc =>
      'Сенсордук экранда узун тизмелерди (каталог, чек, отчёттор, кампа) жылдыруу үчүн ▲/▼ баскычтары';

  @override
  String get setDemoData => 'Демо маалыматтар';

  @override
  String get setDemoDataSubtitle => '12 ай сатуу';

  @override
  String get setDemoDataDialogContent =>
      'Бардык режимдер үчүн демо маалыматтарды жүктөө:\n• Чекене: ~6000 сатуу, жеткирүүлөр, кайтарымдар\n• Ресторан: 15 стол, калькуляциясы бар 29 тамак, заказдар\n• Сервис: кызматтар, чыгым материалдары, иш заказдары\n\nЖе таза баштоо үчүн бардык маалыматтарды тазалоо.';

  @override
  String get setDemoClearAll => 'Баарын тазалоо';

  @override
  String get setDemoLoad => 'Демо жүктөө';

  @override
  String get setDemoGenerating => 'Демо маалыматтарды түзүү...';

  @override
  String get setDemoLoadedTitle => 'Демо маалыматтар жүктөлдү';

  @override
  String get setDemoAlreadyExists =>
      'Маалыматтар буга чейин бар. Адегенде «Баарын тазалоо» басыңыз.';

  @override
  String get setClearDataTitle => 'Маалыматтарды тазалоо';

  @override
  String get setClearDataContent =>
      'БАРДЫК маалыматтар өчүрүлөт:\n• Сатуулар, кайтарымдар, төлөмдөр\n• Товарлар, категориялар, баалар\n• Контрагенттер, жеткирүүлөр\n• Заказдар, сменалар, касса операциялары\n• Ресторан столдору, заказдар\n• Сервистик заказдар\n\nPOS жөндөөлөрү жана колдонуучулар сакталат.\nБул аракет артка кайтарылбайт!';

  @override
  String get setClearDeleteAll => 'Баарын өчүрүү';

  @override
  String get setClearInProgress => 'Маалыматтар тазаланууда...';

  @override
  String get setClearDone => 'Бардык маалыматтар тазаланды';

  @override
  String setGenericError(String error) {
    return 'Ката: $error';
  }

  @override
  String get setCorrectionTitle => 'Оңдоо чеги';

  @override
  String get setCorrectionIntro =>
      'Оңдоо чеги мурда катталган же катталбаган сумманы оңдойт. Себебин жана сумманы көрсөтүңүз. Эгер оператор оңдоону колдобосо — бул чынчылдык менен көрсөтүлөт.';

  @override
  String get setCorrectionReasonLabel => 'Оңдоо себеби';

  @override
  String get setCorrectionReasonHint => 'мис. өз алдынча оңдоо';

  @override
  String setCorrectionAmountLabel(String currency) {
    return 'Оңдоо суммасы, $currency';
  }

  @override
  String get setCorrectionPaymentLabel => 'Төлөө ыкмасы';

  @override
  String get setCorrectionCash => 'Накталай';

  @override
  String get setCorrectionCard => 'Карта';

  @override
  String get setCorrectionSubmit => 'Оңдоо чегин жөнөтүү';

  @override
  String get setCorrectionDefaultName => 'Оңдоо';

  @override
  String get setCorrectionInvalidAmount =>
      'Туура оңдоо суммасын киргизиңиз (> 0)';

  @override
  String get setCorrectionQueued => 'Оңдоо чеги кезекке коюлду (offline)';

  @override
  String get setCorrectionSent => 'Оңдоо чеги жөнөтүлдү';

  @override
  String get setCorrectionUnsupported =>
      'Оңдоо чегин учурдагы оператор колдобойт';

  @override
  String get setCorrectionNotConfigured => 'Фискалдоо тууралбаган';

  @override
  String get setCorrectionError => 'Оңдоо чегинин катасы';

  @override
  String get setFiscalConnection => 'Туташуу';

  @override
  String get setFiscalTestMode => 'Сыноо режими';

  @override
  String get setFiscalLogin => 'Логин';

  @override
  String get setFiscalLoginHint => 'email / телефон';

  @override
  String get setFiscalPassword => 'Сырсөз';

  @override
  String get setFiscalCashboxSerial => 'ЗНМ (касса сериялык номери)';

  @override
  String get setFiscalCashboxSerialHint => 'мис. SWK00033717';

  @override
  String get setFiscalRnm => 'РНМ (каттоо номери)';

  @override
  String get setFiscalKeyPath => 'Ачкыч/сертификат жолу';

  @override
  String get setFiscalOfflineModule => 'Offline модулдун дареги';

  @override
  String get setFiscalVatRate => 'КНС өлчөмү, %';

  @override
  String get dishTabRecipe => 'Рецептура';

  @override
  String get dishTabCosting => 'Өздүк наркы';

  @override
  String get dishTabYield => 'Чыгымы жана КБЖУ';

  @override
  String get dishVersions => 'Версиялар';

  @override
  String get dishCostLabel => 'Өздүк наркы';

  @override
  String get dishPriceLabel => 'Баа';

  @override
  String get dishProfitLabel => 'Пайда';

  @override
  String get dishMarkupLabel => 'Үстөк';

  @override
  String get dishNoIngredients => 'Ингредиенттер жок';

  @override
  String get dishNoIngredientsHint =>
      'Рецептураны эсептөө үчүн ингредиенттерди кошуңуз';

  @override
  String get dishAddIngredient => 'Ингредиент кошуу';

  @override
  String get dishColIngredient => 'Ингредиент';

  @override
  String get dishColGross => 'Брутто';

  @override
  String get dishColColdLoss => 'Иштет.жог.%';

  @override
  String get dishColNet => 'Нетто';

  @override
  String get dishColHotLoss => 'Жыл.жог.%';

  @override
  String get dishColYield => 'Чыгымы';

  @override
  String get dishColCost => 'Наркы';

  @override
  String get dishDeleteIngredient => 'Ингредиентти өчүрүү';

  @override
  String get dishTotal => 'Жыйынтык';

  @override
  String get dishDeleteIngredientTitle => 'Ингредиентти өчүрөсүзбү?';

  @override
  String dishDeleteIngredientConfirm(String name) {
    return '\"$name\" рецептурадан өчүрүлсүнбү?';
  }

  @override
  String get dishSearchIngredientHint =>
      'Ингредиентти аты же штрих-коду боюнча издөө...';

  @override
  String dishCodeOnly(int code) {
    return 'Коду: $code';
  }

  @override
  String dishCodeWithBarcode(int code, int barcode) {
    return 'Коду: $code  |  Штрих-коду: $barcode';
  }

  @override
  String dishAddTitle(String name) {
    return 'Кошуу: $name';
  }

  @override
  String get dishGrossQty => 'Брутто (саны)';

  @override
  String get dishColdLossLabel => 'Иштетүү жоготуусу, %';

  @override
  String get dishHotLossLabel => 'Жылуулук иштетүү жоготуусу, %';

  @override
  String get dishSeasonCoefficient => 'Сезондук коэффициент';

  @override
  String get dishSeasonStandard => 'Стандарт (x1.0)';

  @override
  String get dishSeasonWinter => 'Кыш (+15%) (x1.15)';

  @override
  String get dishSeasonSummer => 'Жай (-5%) (x0.95)';

  @override
  String dishEffectiveColdLoss(String value) {
    return 'Натыйжалуу иштетүү жоготуусу: $value%';
  }

  @override
  String dishTotalYieldSummary(String cost, String yield) {
    return 'Жыйынтык: $cost  |  Чыгымы: $yield';
  }

  @override
  String get dishGostNorms => 'МАМСТ нормалары';

  @override
  String get dishGostNormsTitle => 'МАМСТ жоготуу нормалары';

  @override
  String get dishSearchProductHint => 'Продуктту издөө...';

  @override
  String get dishReferenceEmpty => 'Маалымдама бош';

  @override
  String get dishGostNotLoaded => 'МАМСТ нормалары азырынча жүктөлгөн жок';

  @override
  String dishGostLossLine(String cold, String hot) {
    return 'Сал: $cold%  Жыл: $hot%';
  }

  @override
  String get dishPhotoSection => 'Тамактын сүрөтү';

  @override
  String get dishMissingPricesWarning =>
      'Кээ бир ингредиенттердин сатып алуу баасы жок';

  @override
  String get dishProfitPerServing => 'Порциядан пайда';

  @override
  String get dishLossPerServing => 'Порциядан зыян';

  @override
  String get dishCostOfDish => 'Тамактын өздүк наркы';

  @override
  String get dishSellingPrice => 'Сатуу баасы';

  @override
  String get dishMargin => 'Маржа';

  @override
  String get dishNoPhoto => 'Сүрөт жок';

  @override
  String get dishPhotoLoaded => 'Сүрөт жүктөлдү';

  @override
  String get dishPhotoAddHint => 'Даяр тамактын сүрөтүн кошуңуз';

  @override
  String get dishCamera => 'Камера';

  @override
  String get dishGallery => 'Галерея';

  @override
  String get dishPhotoLoadError => 'Сүрөт жүктөө мүмкүн болбоду';

  @override
  String get dishFoodCost => 'Фудкост';

  @override
  String get dishFoodCostExcellent => 'Эң жакшы';

  @override
  String get dishFoodCostNormal => 'Калыпта';

  @override
  String get dishFoodCostHigh => 'Жогору';

  @override
  String get dishServingsCount => 'Порция саны:';

  @override
  String get dishCostPerServing => 'Порциянын наркы';

  @override
  String get dishPricePerServing => 'Порциянын баасы';

  @override
  String get dishTotalYield => 'Жалпы чыгымы';

  @override
  String get dishIngredientsCount => 'Ингредиенттер';

  @override
  String get dishKbjuSection => 'Тамактык баалуулук (1 порцияга)';

  @override
  String get dishKbjuEmpty => 'КБЖУ маалыматы толтурулган эмес';

  @override
  String get dishKbjuCalories => 'Калория';

  @override
  String get dishKbjuProteins => 'Белоктор';

  @override
  String get dishKbjuFats => 'Майлар';

  @override
  String get dishKbjuCarbs => 'Углеводдор';

  @override
  String dishKcalValue(String value) {
    return '$value ккал';
  }

  @override
  String dishGramValue(String value) {
    return '$value г';
  }

  @override
  String get dishVersionHistory => 'Өзгөрүүлөр тарыхы';

  @override
  String get dishNoVersions => 'Сакталган версиялар жок';

  @override
  String dishVersionN(String version) {
    return '$version-версия';
  }

  @override
  String get dishViewComposition => 'Курамын көрүү';

  @override
  String get dishRestoreThisVersion => 'Бул версияны калыбына келтирүү';

  @override
  String get dishSaveVersion => 'Версияны сактоо';

  @override
  String dishVersionComposition(String version) {
    return '$version-версия — курамы';
  }

  @override
  String get dishSnapshotUnavailable => 'Курам сүрөтү жеткиликсиз';

  @override
  String dishSnapshotIngredientLine(
    String gross,
    String cold,
    String hot,
    String yield,
  ) {
    return 'Брутто: $gross  |  Иштет.жог.: $cold%  |  Жыл.жог.: $hot%  |  Чыгымы: $yield';
  }

  @override
  String get dishVersionNotRestorable =>
      'Бул версияны калыбына келтирүү мүмкүн эмес (ингредиент маалыматы жок), көрүү гана мүмкүн';

  @override
  String get dishRestoreVersionTitle => 'Версияны калыбына келтиресизби?';

  @override
  String dishRestoreVersionConfirm(String version) {
    return 'Учурдагы рецептура $version-версиянын курамы менен алмаштырылат. Улантасызбы?';
  }

  @override
  String get dishRestore => 'Калыбына келтирүү';

  @override
  String dishVersionRestored(String version) {
    return '$version-версия калыбына келтирилди';
  }

  @override
  String get dishRestoreError => 'Версияны калыбына келтирүү мүмкүн болбоду';

  @override
  String dishVersionSummary(int count, String cost) {
    return 'Ингредиенттер: $count, өздүк наркы: $cost';
  }

  @override
  String get dishSaveVersionError => 'Рецепт версиясын сактоо мүмкүн болбоду';

  @override
  String get prodBarcodeAutoHint => 'Авто';

  @override
  String get prodCatalogAttributes => 'Каталог атрибуттары';

  @override
  String get prodBrand => 'Бренд';

  @override
  String get prodManufacturer => 'Өндүрүүчү';

  @override
  String get prodCountryOfOrigin => 'Чыккан өлкөсү';

  @override
  String get prodFiscalAttributes => 'Фискалдык атрибуттар';

  @override
  String get prodVatRate => 'КНС ставкасы';

  @override
  String get prodVatNone => 'КНСсиз';

  @override
  String get prodNtin => 'НКТ (НТИН)';

  @override
  String get prodMarkable => 'Маркировкага жатат';

  @override
  String get promoTitle => 'Акциялар';

  @override
  String get promoSubtitle => '1+1 акциялары жана сатып алууга белектер';

  @override
  String get promoNew => 'Жаңы акция';

  @override
  String promoError(String error) {
    return 'Ката: $error';
  }

  @override
  String get promoEmpty => 'Акциялар жок';

  @override
  String get promoEmptyHint => '1+1 же Белек акциясын түзүңүз';

  @override
  String get promoTypeGift => 'Белек';

  @override
  String promoBuyGetFree(int trigger, int reward) {
    return '$trigger сатып ал → $reward акысыз';
  }

  @override
  String get promoDefaultName11 => '1+1 акциясы';

  @override
  String get promoNameLabel => 'Аталышы';

  @override
  String get promoTriggerLabel => 'Триггер-товар (эмнени сатып алуу)';

  @override
  String get promoRewardLabel => 'Белек (эмне акысыз)';

  @override
  String get promoSaveButton => 'Акцияны сактоо';

  @override
  String get saleWeighingPlaceItem => 'Таразалоо... товарды таразага коюңуз';

  @override
  String get saleWeightReadFailed =>
      'Салмакты окуу мүмкүн болбоду — кол менен киргизиңиз';

  @override
  String get salePriceLabelSent => 'Баа этикеткасы басып чыгарууга жөнөтүлдү';

  @override
  String get transPrimary => 'Негизги';

  @override
  String get transSecondary => 'Кошумча';

  @override
  String get transStatusOnline => 'Тармакта';

  @override
  String get transStatusOffline => 'Тармактан тышкары';

  @override
  String get transStatusSyncing => 'Шайкештирүү';

  @override
  String get transStatusQueued => 'Кезекте';

  @override
  String get transStatusWarning => 'Эскертүү';

  @override
  String get transStatusError => 'Ката';

  @override
  String transQueuedCount(int count) {
    return 'кезекте $count';
  }

  @override
  String transFailedCount(int count) {
    return '$count ката';
  }

  @override
  String transLastSyncAgo(String ago) {
    return 'Акыркы шайкештирүү: $ago мурун';
  }

  @override
  String get transSyncing => 'Шайкештирүү...';

  @override
  String get transSyncNow => 'Азыр шайкештирүү';

  @override
  String get transRetryFailed => 'Ийгиликсиздерди кайталоо';

  @override
  String get restTips => 'Чайпул';

  @override
  String get restNoTips => 'Чайпулсуз';

  @override
  String get svcPendingApproval => 'Макулдоону күтүүдө';

  @override
  String get svcApprove => 'Бекитүү';

  @override
  String get svcReject => 'Четке кагуу';

  @override
  String get svcRejected => 'Четке кагылды';

  @override
  String get svcQr => 'QR';

  @override
  String get catCollapse => 'Жыйноо';

  @override
  String get repError => 'Ката';

  @override
  String get repNoData => 'Маалымат жок';

  @override
  String get repNoDataForPeriod => 'Тандалган мезгилде маалымат жок';

  @override
  String get repKpiLoadError => 'KPI жүктөө катасы';

  @override
  String get repColIndicator => 'Көрсөткүч';

  @override
  String get repColCount => 'Саны';

  @override
  String repColSumTenge(String currency) {
    return 'Сумма, $currency';
  }

  @override
  String get repColRow => 'Сап';

  @override
  String get repColTurnoverExclVat => 'Жүгүртүм (КНСсиз)';

  @override
  String get repColVat => 'КНС';

  @override
  String get repColDate => 'Күнү';

  @override
  String get repColOperation => 'Операция';

  @override
  String get repColIncome => 'Киреше';

  @override
  String get repColExpense => 'Чыгым';

  @override
  String get repColBalance => 'Калдык';

  @override
  String get repColRate => 'Чен';

  @override
  String get repColGross => 'Брутто';

  @override
  String get repColNet => 'Нетто';

  @override
  String get repNoVat => 'КНСсиз';

  @override
  String get repColCounterparty => 'Контрагент';

  @override
  String get repColType => 'Түрү';

  @override
  String get repColSaldo => 'Сальдо';

  @override
  String get repDebtor => 'Дебитор';

  @override
  String get repCreditor => 'Кредитор';

  @override
  String get repColAccount => 'Эсеп';

  @override
  String get repColCashier => 'Кассир';

  @override
  String get repColAmount => 'Сумма';

  @override
  String get repColProduct => 'Товар';

  @override
  String get repColRevenue => 'Киреше';

  @override
  String get repColCogs => 'Өздүк наркы';

  @override
  String get repColProfit => 'Пайда';

  @override
  String get repColMarginPct => 'Маржа %';

  @override
  String get repColReason => 'Себеп';

  @override
  String get repColDocuments => 'Документтер';

  @override
  String get repColCostShort => 'Өздүк';

  @override
  String get repF910Title => 'ф.910 — Киреше (жеңилдетилген)';

  @override
  String repF910Subtitle(String income, String rate, String tax) {
    return 'Салык салынуучу киреше: $income • салык $rate%: $tax';
  }

  @override
  String get repF910RowSalesIncome => 'Сатуудан киреше';

  @override
  String get repF910RowRefunds => 'Кайтарымдар (минус)';

  @override
  String get repF910RowTaxableIncome => 'Салык салынуучу киреше';

  @override
  String get repF300Title => 'ф.300 — КНС (декларация)';

  @override
  String repF300Subtitle(String turnover, String vat) {
    return 'Салык салынуучу жүгүртүм: $turnover • эсептелген КНС: $vat';
  }

  @override
  String repF300TaxableTurnoverRate(String rate) {
    return 'Салык салынуучу жүгүртүм $rate%';
  }

  @override
  String get repF300ZeroRatedTurnover => 'Салык салынбаган / 0% жүгүртүм';

  @override
  String get repCashBookTitle => 'Касса китеби (КО-4)';

  @override
  String repCashBookSubtitle(String income, String expense, String balance) {
    return 'Киреше: $income • Чыгым: $expense • Калдык: $balance';
  }

  @override
  String get repVatPeriodTitle => 'Мезгилдеги КНС';

  @override
  String repVatPeriodSubtitle(String vat, String base) {
    return 'КНС: $vat • база: $base';
  }

  @override
  String get repArApTitle => 'Дебитордук / Кредитордук';

  @override
  String repArApSubtitle(String receivable, String payable, String saldo) {
    return 'Дебитордук: $receivable • Кредитордук: $payable • Сальдо: $saldo';
  }

  @override
  String get repCashCollectionTitle => 'Инкассация';

  @override
  String repCashCollectionSubtitle(int count, String total) {
    return '$count операция • баары: $total';
  }

  @override
  String get repProfitCogsTitle => 'Пайда / Маржа (COGS)';

  @override
  String get repProfitMarginTitle => 'Пайда / Маржа';

  @override
  String repProfitMarginSubtitle(String profit, String margin, String note) {
    return 'Пайда: $profit • маржа $margin% • $note';
  }

  @override
  String get repProfitCostRealCogs => 'өздүк наркы: чыныгы COGS';

  @override
  String get repProfitCostWholesale =>
      'өздүк наркы: дүң баа (CalculateCogsUseCase жок)';

  @override
  String get repWriteoffTitle => 'Эсептен чыгаруу';

  @override
  String repWriteoffSubtitle(int count, String total) {
    return '$count документ • баары: $total';
  }

  @override
  String get repOrderTypesTitle => 'Заказ түрлөрү';

  @override
  String get repOrderTypesSubtitle => 'тейлөө түрү боюнча бөлүштүрүү';

  @override
  String get repTableTurnoverTitle => 'Үстөлдөрдүн жүгүртүмү';

  @override
  String get repTableTurnoverSubtitle => 'мезгилдеги отургузуулар (топ-10)';

  @override
  String get repDishPopularityTitle => 'Тамактардын популярдуулугу';

  @override
  String get repDishPopularitySubtitle => 'сатуу саны боюнча топ-10';

  @override
  String get repFoodCostAnalysisShort => 'Өздүк нарк талдоосу';

  @override
  String get repFoodCostAnalysisTitle => 'Өздүк нарк талдоосу (Food Cost)';

  @override
  String get repFoodCostAnalysisSubtitle =>
      'жашыл <30%, сары 30-40%, кызыл >40%';

  @override
  String get repColDish => 'Тамак';

  @override
  String get repColFoodCostPct => 'Food Cost %';

  @override
  String get repTipsByWaiterTitle => 'Официанттар боюнча чай акы';

  @override
  String get repTipsByWaiterSubtitle => 'чай акы суммасы боюнча сорттоо';

  @override
  String get repColWaiter => 'Официант';

  @override
  String get repColOrders => 'Заказдар';

  @override
  String get repColTips => 'Чай акы';

  @override
  String get repColTipsPct => 'Чай акы %';

  @override
  String get repKpiRestaurantRevenue => 'Ресторандын кирешеси';

  @override
  String get repKpiOrders => 'Заказдар';

  @override
  String get repKpiAvgCheck => 'Орточо чек';

  @override
  String get repKpiTips => 'Чай акы';

  @override
  String get repKpiRevenue => 'Киреше';

  @override
  String get repKpiExpenses => 'Чыгымдар';

  @override
  String get repKpiRefunds => 'Кайтарымдар';

  @override
  String get repKpiSales => 'Сатуулар';

  @override
  String get repSubtitleForPeriod => 'мезгил үчүн';

  @override
  String get repSubtitleTotal => 'баары';

  @override
  String get repSubtitleCashExpenses => 'касса чыгымдары';

  @override
  String get repSubtitleRefundTotal => 'кайтарым суммасы';

  @override
  String get repSubtitleReceipts => 'чектер';

  @override
  String get repCashFlowTitle => 'Күндөр боюнча акча агымы';

  @override
  String get repCashFlowInvestments => 'Салымдар';

  @override
  String get repCashFlowExpenses => 'Чыгымдар';

  @override
  String get repCashFlowDividends => 'Дивиденддер';

  @override
  String repDaysCount(int count) {
    return '$count күн';
  }

  @override
  String get repTopProfitableTitle => 'Топ-10 пайдалуу товар';

  @override
  String get repTopProfitableSubtitle => 'абсолюттук пайда боюнча';

  @override
  String get repProductProfitTitle => 'Товарлардын рентабелдүүлүгү';

  @override
  String get repProductProfitSubtitle => 'пайда боюнча топ-20';

  @override
  String get repRefundTrendTitle => 'Кайтарым тренди';

  @override
  String get repSupplierVolumeTitle => 'Жеткирүүчүлөр боюнча жеткирүү';

  @override
  String repSuppliersCount(int count) {
    return '$count жеткирүүчү';
  }

  @override
  String get repSupplierTableTitle => 'Жеткирүүчүлөр таблицасы';

  @override
  String get repSupplierTableSubtitle => 'жеткирүү саны боюнча сорттоо';

  @override
  String get repColSupplier => 'Жеткирүүчү';

  @override
  String get repColSupplyCount => 'Жеткирүү саны';

  @override
  String get repPriceTrendTitle => 'Сатып алуу баалардын динамикасы';

  @override
  String get repPriceTrendSubtitle => 'жеткирүү саны боюнча топ-5 товар';

  @override
  String get repNotEnoughDataForChart => 'График үчүн маалымат жетишсиз';

  @override
  String get repPriceChangesShort => 'Баа өзгөрүүлөрү';

  @override
  String get repPriceChangesTitle => 'Жеткирүүчү баалардын өзгөрүүлөрү';

  @override
  String get repPriceChangesSubtitle =>
      'сатып алуу баалардын акыркы өзгөрүүлөрү';

  @override
  String get repColWas => 'Болгон';

  @override
  String get repColBecame => 'Болду';

  @override
  String get repColChangePctShort => 'Өзг. %';

  @override
  String get repNoSupplierData => 'Жеткирүүчүлөр жөнүндө маалымат жок';

  @override
  String get repNoSuppliesForPeriod =>
      'Тандалган мезгилде жеткирүүлөр табылган жок';

  @override
  String get navWmsDashboard => 'WMS кампа';

  @override
  String get navWmsWarehouses => 'Кампалар';

  @override
  String get navWmsBatches => 'Партиялар';

  @override
  String get navWmsSerials => 'Сериялар';

  @override
  String get navWmsCellStock => 'Уячалар';

  @override
  String get navWmsClaims => 'Доолор';

  @override
  String get navWmsMarking => 'Маркировка';

  @override
  String get navWmsSettings => 'WMS жөндөөлөрү';

  @override
  String errorInsufficientStock(String name) {
    return 'Калдык жетишсиз: $name';
  }

  @override
  String get discountLimitsTitle => 'Арзандатуу чектөөлөрү';

  @override
  String get discountLimitsSubtitle => 'Кассир кол менен канча арзандата алат';

  @override
  String get discountLimitsIntro =>
      'Ролдун чеги демейкини алмаштырат. Өз сабы жок ролго «Демейки» колдонулат. Жүз пайыз «чексиз» дегенди билдирет — бул жарыяланган маани, бош орун эмес.';

  @override
  String get discountLimitsDefaultRow => 'Демейки (бардык ролдор)';

  @override
  String get discountLimitsMaxPercent => 'Чек, %';

  @override
  String get discountLimitsApprovalAbove => 'Ырастоо чеги, %';

  @override
  String get discountLimitsApprovalHint => 'бош — талап кылынбайт';

  @override
  String get discountLimitsInheritHint => 'бош — демейкидей';

  @override
  String get discountLimitsTwoDoors =>
      'Эскертүү: сатуу саясатындагы «бааны төмөндөтүүгө тыюу» сап баасын оңдоону гана жабат. Арзандатуу 100 % чекте дагы деле уруксат — акысыз сапка чейин. Бул эки башка эшик; экинчисин жабуу үчүн чекти жүздөн төмөн коюңуз.';

  @override
  String get discountLimitsSaved => 'Чек сакталды';

  @override
  String get discountLimitsInherited => 'Сап алынды: рол демейкини мурастайт';

  @override
  String get discountLimitsInvalid => 'Чек — 0дөн 100гө чейинки сан';

  @override
  String get discountLimitsApprovalNotYet =>
      'Улуу кызматкердин ырастоосу азырынча ишке ашырылган эмес: чектен ашкан арзандатуу код сурабай, аталган себеп менен четке кагылат.';

  @override
  String errorDeniedPolicy(String detail) {
    return 'Касса жөндөөлөрү менен тыюу салынган: $detail';
  }

  @override
  String errorDeniedLimit(String detail) {
    return 'Арзандатуу уруксат берилгенден ашык: $detail';
  }

  @override
  String errorApprovalRequired(String detail) {
    return 'Улуу кызматкердин ырастоосу керек: $detail';
  }

  @override
  String errorBigAmountBlocked(String limit) {
    return 'Сатуу суммасы касса чегинен жогору ($limit). Чекти көтөрүңүз же касса жөндөөлөрүндө чоң суммаларга уруксат бериңиз.';
  }

  @override
  String errorMarkRequired(String name) {
    return 'Маркировка коду керек: $name';
  }

  @override
  String get errorOrderNotFound => 'Заказ табылган жок';

  @override
  String get errorSerialNotFound => 'Сериялык номер табылган жок';

  @override
  String get errorReceiptFailedPrint => 'Чекти басып чыгаруу мүмкүн болбоду';

  @override
  String get errorDeleteFailed => 'Өчүрүү мүмкүн болбоду';

  @override
  String get errorCancelFailed => 'Жокко чыгаруу мүмкүн болбоду';

  @override
  String get errorShiftZreportFailed => 'Z-отчёт катасы';

  @override
  String get errorTransitionFailed => 'Статусту өзгөртүү мүмкүн болбоду';

  @override
  String get logJournalTitle => 'Иш журналы';

  @override
  String get logJournalOpen => 'Журналды ачуу';

  @override
  String get logJournalCardDesc =>
      'Күндөр боюнча файлдык журнал: флешкага жүктөө, тазалоо';

  @override
  String get logJournalEmpty => 'Журнал бош';

  @override
  String get logJournalPickFolder => 'Жүктөө үчүн папканы (флешка) тандаңыз';

  @override
  String get logJournalExport => 'Флешкага жүктөө';

  @override
  String logJournalExported(int count, String dir) {
    return '$dir ичине $count файл жүктөлдү';
  }

  @override
  String logJournalSummary(int count, String size) {
    return 'Файлдар: $count, баары $size';
  }

  @override
  String get logJournalDeleteOld => '7 күндөн эски';

  @override
  String logJournalDeletedOld(int count) {
    return '$count файл өчүрүлдү';
  }

  @override
  String get logJournalDeleteAllTitle => 'Бардык журналдарды өчүрөсүзбү?';

  @override
  String get logJournalDeleteAllConfirm =>
      'Бүгүнкүдөн башка бардык журнал файлдары өчүрүлөт. Бул кайтарылбайт.';

  @override
  String get setUserTabPin => 'PIN';

  @override
  String get setUserPinChange => 'PIN өзгөртүү';

  @override
  String get setUserPinSetHint => 'Кирүү үчүн PIN коюңуз (4-6 сан)';

  @override
  String get setUserPinKeepHint => 'Учурдагы PIN сактоо үчүн бош калтырыңыз';

  @override
  String get setUserPinNew => 'Жаңы PIN';

  @override
  String get receiptInputRecent => 'Акыркы чектер';

  @override
  String get receiptInputNoRecent => 'Азырынча чектер жок';

  @override
  String get receiptInputRecentUnavailable =>
      'Акыркы чектердин тизмеси бул терминалда жеткиликсиз — чектин номерин кол менен киргизиңиз';

  @override
  String get shiftHistoryTitle => 'Алмашуулар тарыхы';

  @override
  String get shiftHistoryEmpty => 'Жабык алмашуулар азырынча жок';

  @override
  String shiftHistoryShiftNo(int id) {
    return 'Алмашуу №$id';
  }

  @override
  String get shiftHistorySales => 'Сатуулар';

  @override
  String get shiftHistoryRefunds => 'Кайтарымдар';

  @override
  String get shiftHistoryOpeningCash => 'Башталгыч касса';

  @override
  String saleExpiredBatchWarning(String name) {
    return 'Көңүл буруңуз: «$name» товарынын партиясынын мөөнөтү өткөн';
  }

  @override
  String get setPolicyEditProduct => 'Товарларды түзөтүүгө уруксат';

  @override
  String get setPolicyEditProductDesc =>
      'Кассир каталогдогу товар карточкаларын өзгөртө алат';

  @override
  String get setPolicyEditPrice => 'Сатууда бааны өзгөртүүгө уруксат';

  @override
  String get setPolicyEditPriceDesc =>
      'Кассир чектеги позициянын баасын кол менен өзгөртө алат';

  @override
  String get setPolicyDiscounts => 'Арзандатууларга уруксат';

  @override
  String get setPolicyDiscountsDesc =>
      'Кассир чек позицияларына арзандатуу колдоно алат';

  @override
  String get setPolicyCashInOut => 'Накталай киргизүү/чыгарууга уруксат';

  @override
  String get setPolicyCashInOutDesc =>
      'Кассир кассадан накталай сала жана ала алат';

  @override
  String get setPolicyBigAmount => 'Чоң суммаларга уруксат (>1 млн)';

  @override
  String get setPolicyBigAmountDesc =>
      'Операциялардагы 1 000 000 чегин алып салуу';

  @override
  String get setPolicyBlockPriceDecrease =>
      'Бааны карточкадан төмөн түшүрүүгө тыюу';

  @override
  String get setPolicyBlockPriceDecreaseDesc =>
      'Чектеги бааны товардын баасынан төмөн коюуга болбойт';

  @override
  String get printerAutoDetect => 'Принтерди табуу';

  @override
  String get printerAutoDetecting => 'Принтер изделүүдө…';

  @override
  String printerFound(String device) {
    return 'Табылды: $device';
  }

  @override
  String printerFoundWithNote(String device, String note) {
    return 'Табылды: $device — $note';
  }

  @override
  String get printerNotFoundAnyPort =>
      'Принтер бир да портто табылган жок (USB/serial). Кабелди жана кубатты текшериңиз.';

  @override
  String get printerUsbName => 'USB-принтер';

  @override
  String get printerSelectDevice => 'Принтерди тандаңыз';

  @override
  String get printerNoAccessGroupLp =>
      'Түйүн табылды, бирок уруксат жок (lp тобу керек)';

  @override
  String printerLabelUsb(String path) {
    return 'USB-принтер ($path)';
  }

  @override
  String printerLabelSerial(String path) {
    return 'Serial-принтер ($path)';
  }

  @override
  String get printerNoAccessGroupLpHint =>
      'Түйүн табылды, бирок уруксат жок (lp тобу керек): usermod -aG lp telepos жана сеансты кайра иштетиңиз.';

  @override
  String printerRawOpenNoPermsHint(String path) {
    return '$path түйүнү табылды, бирок ачуу мүмкүн эмес — уруксат жок. Колдонуучуну lp тобуна кошуңуз (usermod -aG lp telepos) жана сеансты/түзмөктү кайра иштетиңиз.';
  }

  @override
  String get printerNotFoundNoNode =>
      'Принтер табылган жок: /dev/usb/lp* char-түйүнү да, USB-serial порту да жок. Принтердин кабелин жана кубатын текшериңиз.';

  @override
  String get ownerOnlyTitle => 'Бул касса ээсине гана жеткиликтүү';

  @override
  String get ownerOnlyDesc =>
      'Системалык операциялар (өчүрүп-күйгүзүү, баштапкы абалга келтирүү, драйверлер, терминал) ээсинин эсебинде гана жеткиликтүү.';

  @override
  String get telegramApiSectionTitle => 'Telegram колдонмосу';

  @override
  String get telegramApiSectionDesc =>
      'TelePOS Telegram ачкычтары менен жеткирилбейт. my.telegram.org сайтында колдонмо каттап, төмөнкү жупту киргизиңиз же чогултууда --dart-define аркылуу бериңиз.';

  @override
  String get telegramApiIdLabel => 'api_id';

  @override
  String get telegramApiHashLabel => 'api_hash';

  @override
  String get telegramApiSave => 'Ачкычтарды сактоо';

  @override
  String get telegramApiClear => 'Ачкычтарды өчүрүү';

  @override
  String get telegramApiSaved => 'Telegram ачкычтары сакталды';

  @override
  String get telegramApiCleared => 'Telegram ачкычтары өчүрүлдү';

  @override
  String get telegramApiInvalid =>
      'Сандык api_id жана бош эмес api_hash киргизиңиз';

  @override
  String get telegramApiStatusConfigured => 'Ачкычтар берилген';

  @override
  String get telegramApiStatusMissing => 'Ачкычтар берилген эмес';

  @override
  String get deviceSearchButton => 'Издөө';

  @override
  String get deviceSearchTitle => 'Табылган түзмөктөр';

  @override
  String get deviceSearchRunning => 'Издөө жүрүүдө…';

  @override
  String get deviceSearchEmpty =>
      'Эч нерсе табылган жок. Бардык булактар суралды — түзмөк туташтырылган эмес же өчүк.';

  @override
  String get deviceSearchNoValueForField =>
      'Түзмөктөр табылды, бирок эч кайсысы бул талаага маани бербейт.';

  @override
  String deviceSearchFailedSources(String sources) {
    return 'Издөө аткарылган жок: $sources. Бул «эч нерсе туташтырылган эмес» дегенге барабар эмес.';
  }

  @override
  String get deviceSearchUnavailable =>
      'Бул курулушта түзмөктөрдү издөө жеткиликсиз.';

  @override
  String deviceSearchFieldFilled(String value) {
    return 'Талаа толтурулду: $value';
  }

  @override
  String get deviceSourceSerialPort => 'Ырааттуу порт';

  @override
  String get deviceSourceUsb => 'USB';

  @override
  String get deviceSourceNetwork => 'Тармак';

  @override
  String get deviceSourceBluetooth => 'Bluetooth';

  @override
  String get deviceCheckButton => 'Түзмөктү текшерүү';

  @override
  String get deviceCheckRunning => 'Текшерилүүдө…';

  @override
  String get deviceCheckUnavailable =>
      'Бул курулушта түзмөктү текшерүү жеткиликсиз.';

  @override
  String get deviceCheckSavedBindingNotice =>
      'Сакталган байланыш текшерилет: түзмөккө бул экрандагы сакталбаган өзгөрүүлөр эмес, жазылган параметрлер боюнча суроо жөнөтүлөт. Жаңы байланыш сатууда иштеши үчүн колдонмону өчүрүп-күйгүзүңүз.';

  @override
  String get deviceCheckReasonOk => 'Түзмөк жооп берди';

  @override
  String get deviceCheckReasonNotConfigured => 'Түзмөк тууралбаган';

  @override
  String get deviceCheckReasonInvalidBinding => 'Байланыш ката';

  @override
  String get deviceCheckReasonDriverNotLive =>
      'Байланыш сакталган, бирок бул курама бул түзмөк менен иштей албайт';

  @override
  String get deviceCheckReasonConnectionFailed => 'Түзмөк жооп бербейт';

  @override
  String get deviceCheckReasonDeviceRefused => 'Түзмөк операциядан баш тартты';

  @override
  String get deviceCheckReasonNotSupportedOnPlatform =>
      'Бул платформада колдоого алынбайт';

  @override
  String get deviceCheckReasonNotImplemented =>
      'Бул класс үчүн текшерүү азырынча ишке ашырылган эмес';

  @override
  String get deviceCheckReasonUnexpectedError => 'Күтүлбөгөн ката';

  @override
  String get scannerRulesTitle => 'Штрихкоду окуу эрежелери';

  @override
  String get scannerRulesSubtitle =>
      'Сканердин касиеттери эмес, орнотуу эрежелери: кайсы окулган маанини кабыл алуу керек.';

  @override
  String get scannerRulesMinLength => 'Штрихкоддун эң аз узундугу';

  @override
  String get scannerRulesMaxLength => 'Штрихкоддун эң көп узундугу';

  @override
  String get scannerRulesTimeoutMs =>
      'Сканер белгилеринин ортосундагы аралык, мс';

  @override
  String scannerRulesDefaultHint(String value) {
    return 'Бош — демейки $value';
  }

  @override
  String scannerRulesNotAnInteger(String value) {
    return '«$value» мааниси бүтүн сан эмес';
  }

  @override
  String get scannerRulesSaved => 'Штрихкодду окуу эрежелери сакталды';

  @override
  String get printQueueSectionTitle => 'Басып чыгаруу кезеги';

  @override
  String get printQueueSubtitle =>
      'Эмне басылууну күтүүдө, эмне басылган жок жана эмне үчүн.';

  @override
  String get printQueueEmpty => 'Кезек бош — басылбаган чектер жок.';

  @override
  String get printQueueUnavailable =>
      'Басып чыгаруу кезеги бул курамада жеткиликсиз.';

  @override
  String get printQueueUnreadable => 'Басып чыгаруу кезегин окуу мүмкүн эмес';

  @override
  String get printQueueUnreadableHint =>
      'Бул бош кезек эмес: тапшырмалар басылууну күтүшү мүмкүн, бирок тизмени окуу мүмкүн эмес. Тейлөө талап кылынат.';

  @override
  String get printQueueStateQueued => 'Басылууну күтүүдө';

  @override
  String get printQueueStatePrinting => 'Басылып жатат';

  @override
  String get printQueueStatePrinted => 'Басылды';

  @override
  String get printQueueStateFailed => 'Басылган жок, кайталанат';

  @override
  String get printQueueStateExpired => 'Мөөнөтү бүттү, өз алдынча кайталанбайт';

  @override
  String get printQueueStateCancelled => 'Оператор жокко чыгарды';

  @override
  String printQueueAttempts(int count) {
    return 'Аракеттер: $count';
  }

  @override
  String printQueueDeadline(String moment) {
    return '$moment чейин жарактуу';
  }

  @override
  String printQueueReason(String reason) {
    return 'Себеби: $reason';
  }

  @override
  String get printQueueRetry => 'Кайталоо';

  @override
  String get printQueueCancelJob => 'Тапшырманы жокко чыгаруу';

  @override
  String get printQueueExtendTitle =>
      'Тапшырманы канча убакытка узартуу керек?';

  @override
  String get printQueueExtend5Minutes => 'Дагы 5 мүнөт';

  @override
  String get printQueueExtend30Minutes => 'Дагы 30 мүнөт';

  @override
  String get printQueueExtend2Hours => 'Дагы 2 саат';

  @override
  String get printQueueRetryAccepted => 'Тапшырма кайра кезекте';

  @override
  String get printQueueRetryAlreadyPrinted =>
      'Бул чек басылып койгон — экинчи жолу басылбайт';

  @override
  String get printQueueRetryRejected => 'Кайталоо ишке ашкан жок';

  @override
  String get printQueueCancelTitle => 'Тапшырманы жокко чыгарасызбы?';

  @override
  String get printQueueCancelBody =>
      'Жокко чыгарылган тапшырманы басып чыгаруу мүмкүн эмес. Ошондой чек керек болсо, аны кайра чыгаруу керек.';

  @override
  String get printQueueCancelConfirm => 'Тапшырманы жокко чыгаруу';

  @override
  String get printQueueCancelDone => 'Тапшырма жокко чыгарылды';

  @override
  String get printQueueCancelRefused =>
      'Бул тапшырманы эми жокко чыгаруу мүмкүн эмес: ал басылып жатат же аяктаган';

  @override
  String get errorPayReceiptNotFound =>
      'Чек эми иште эмес — аны төлөө мүмкүн эмес. Экранды жаңыртып, кайра баштаңыз.';

  @override
  String get errorPayNotOwner =>
      'Бул чекти башка жумуш орду жүргүзүүдө — аны бул жерден төлөө мүмкүн эмес.';

  @override
  String get errorPaymentAlreadyTaken =>
      'Бул чек төлөнүп калган. Касса акчаны экинчи жолу албайт.';

  @override
  String get errorPaymentInsufficient =>
      'Аталган сумма чекке жетпейт. Сумманы кайра киргизиңиз.';

  @override
  String get errorPaymentAccountMissing =>
      'Кассада бул төлөм түрүнө арналган эсеп жок. Администраторго кайрылыңыз.';

  @override
  String get errorPaymentAccountNotAllowed =>
      'Мындай эсеп төлөмгө сунушталган эмес. Эсептер тизмесин жаңыртып, кайра тандаңыз.';

  @override
  String get errorPaymentUnbalanced =>
      'Төлөм саптарынын суммасы чектин суммасына дал келбейт. Төлөмдү кайра киргизиңиз.';

  @override
  String get errorPaymentKindInactive =>
      'Бул төлөм түрү касса жөндөөлөрүндө өчүрүлгөн. Башкасын тандаңыз же жөндөөлөрдөн күйгүзүңүз.';

  @override
  String get errorPaymentKindUnknown =>
      'Касса мындай төлөм түрүн билбейт. Администраторго кайрылыңыз.';

  @override
  String get errorCertificateUnknown =>
      'Бул кассада мындай номердеги сертификат жок. Номерди текшериңиз.';

  @override
  String get errorCertificatePinWrong =>
      'Сертификаттын ПИН коду туура келген жок. Кайра териңиз.';

  @override
  String get errorCertificateRateLimited =>
      'Сертификатты текшерүүнүн ийгиликсиз аракеттери өтө көп. Бир нече мүнөт күтүп, кайталаңыз.';

  @override
  String get errorConnectionLost =>
      'Касса менен байланыш үзүлдү. Тармакты текшерип, кайталаңыз.';

  @override
  String get errorRunIncomplete =>
      'Касса операцияны аягына чыгарбай токтотту. Кайталоодон мурун кассадагы жыйынтыкты текшериңиз.';

  @override
  String get errorWireMismatch =>
      'Жумуш орду менен касса бири-бирин түшүнгөн жок — версиялары дал келбейт. Баракты жаңылаңыз; жардам бербесе, администраторго кайрылыңыз.';

  @override
  String get errorTillFailed =>
      'Касса операцияны аткара алган жок. Кайталаңыз; ката кайталанса, администраторго кайрылыңыз.';

  @override
  String get errorTerminalChanged =>
      'Сиз жумуш ордун алмаштырдыңыз — кайра кириңиз.';

  @override
  String get errorUnknownTerminal =>
      'Жумуш орду кассага байланган эмес. Аны байлоо коду менен кайра байлаңыз.';

  @override
  String get errorAlreadyConfigured =>
      'Касса мурунтан эле жөндөлгөн — баштапкы жөндөө устасы мындан ары жеткиликсиз.';

  @override
  String get errorCannotDeleteSelf =>
      'Кассанын өз жумуш ордун өчүрүүгө болбойт.';

  @override
  String get errorNoDrivers =>
      'Касса жабдуу драйверлерисиз курулган — түзмөктөрдү издөө жана текшерүү жеткиликсиз. Администраторго кайрылыңыз.';

  @override
  String get errorNoNetworkModule =>
      'Бул касса тармак жөндөөлөрүн башкарбайт — системалык кызмат жок. Администраторго кайрылыңыз.';

  @override
  String get errorNoSessionRegistry =>
      'Бул касса сеанстардын тизмесин жүргүзбөйт. Администраторго кайрылыңыз.';

  @override
  String get errorNoBackupTransport =>
      'Бул кассада камдык көчүрмөлөр жөндөлгөн эмес. Администраторго кайрылыңыз.';

  @override
  String get errorBackupNotFound => 'Камдык көчүрмө табылган жок.';

  @override
  String get errorCertificatesUnavailable =>
      'Бул касса белек сертификаттарын тармак аркылуу чыгарбайт. Администраторго кайрылыңыз.';

  @override
  String get errorRefundStale =>
      'Буйрук кассага жеткенче кайтаруу өзгөрдү. Аракетти кайталаңыз.';

  @override
  String get errorRefundWrongDraft =>
      'Бул кайтаруунун долбоору мындан ары жок. Кайтарууну кайра ачыңыз.';

  @override
  String get errorRefundNotStarted =>
      'Кайтаруу башталган жок — чекти тандаңыз же чексиз кайтарууну баштаңыз.';

  @override
  String get errorRefundEmpty =>
      'Кайтарууда бир да сап жок — кайтара турган эч нерсе жок.';

  @override
  String get errorReceiptAlreadyRefunded =>
      'Бул чек боюнча кайтаруу мурунтан эле жасалган.';

  @override
  String get errorReceiptNotRefundable =>
      'Бул чекти бул жерде кайтарууга болбойт: төлөм башка кассанын терминалы аркылуу өттү. Кайтарууну төлөгөн жерде тариздеңиз.';

  @override
  String get errorLineNotInReceipt =>
      'Бул товар чекте жок — чек боюнча анда сатылгандар гана кайтарылат.';

  @override
  String get errorSaleNotCompleted =>
      'Бул чек боюнча сатуу аяктаган жок — кайтара турган эч нерсе жок.';

  @override
  String get errorRefundBusy =>
      'Кассада башка кайтаруу жүрүп жатат. Аны аяктап, кайталаңыз.';

  @override
  String get errorRefundCannotStart =>
      'Касса кайтарууну баштай алган жок жана себебин айткан жок. Смена менен кассанын жөндөөсүн текшериңиз.';

  @override
  String get errorRefundInstallmentRefused =>
      'Чек бөлүп төлөөгө сатылган — касса аны кайтарбайт. Келишимди бузууну администратор тариздейт.';

  @override
  String get errorRefundCashlessUnavailable =>
      'Бул акчаны картага же QR аркылуу кайтаруу керек, бирок кайтара турган каражат жок: терминал же провайдер туташкан эмес. Касса мындай кайтарууну кутудан накталай бербейт.';

  @override
  String get errorRefundCashlessRefused =>
      'Банк же провайдер кайтаруудан баш тартты. Терминалды текшерип, кайталаңыз — мурда кайтарылганы экинчи жолу кайтарылбайт.';

  @override
  String get errorRefundKindNotRefundable =>
      'Бул төлөм түрүнө кайтаруу төлөм түрлөрүнүн маалымдамасында тыюу салынган.';

  @override
  String get errorRefundKindUnknown =>
      'Чек бул кассанын маалымдамасында жок төлөм түрү менен төлөнгөн. Касса ал боюнча кайтарууну жүргүзбөйт: эмне менен төлөгөнү белгисиз, ал үчүн накталай акча берилбейт.';

  @override
  String get refundDestinationsTitle => 'Акча кайда кетет';

  @override
  String get refundRouteDrawer => 'Кутудан накталай';

  @override
  String get refundRouteCard => 'Терминал аркылуу картага';

  @override
  String get refundRouteManual => 'Кассадан тышкары — төлөгөн жол менен';

  @override
  String get refundRouteProvider => 'QR провайдери аркылуу';

  @override
  String get refundRouteCertificate =>
      'Жаңы сертификат менен (эскиси өтөлгөн бойдон калат)';

  @override
  String get refundRouteAdvance => 'Сатып алуучунун алдын ала төлөмүнө';

  @override
  String get refundRouteBonus => 'Бонустук эсепке';

  @override
  String get refundRouteDebt => 'Сатып алуучунун карызынын эсебине';

  @override
  String get errorCertificateRefundNoSource =>
      'Чектин сабы сертификат менен кайтарылат, бирок анын сертификат номери жок. Касса ал боюнча кайтарууну жүргүзбөйт: жаңы сертификатты эмнеден жазууну билүүгө болбойт, ал эми кассанын милдеттенмеси бекер өсмөк.';

  @override
  String get errorCertificateCashRefundRefused =>
      'Сертификат үчүн накталай акча менен кайтарууга болбойт — накталай эмес кайтаруу реквизиттерин көрсөтүңүз.';

  @override
  String get errorCertificatePaysCertificate =>
      'Сертификат менен башка сертификаттын сатып алуусун төлөөгө болбойт.';

  @override
  String get errorCreditContractUnknown =>
      'Мындай номердеги бөлүп төлөө келишими жок. Номерди текшериңиз.';

  @override
  String get errorCreditContractNotActive =>
      'Бөлүп төлөө келишими төлөнүп бүткөн же жокко чыгарылган — ал боюнча төлөй турган эч нерсе жок.';

  @override
  String get errorCreditOverpayment =>
      'Сумма келишим боюнча калдыктан көп. Сумманы текшериңиз.';

  @override
  String get errorCreditRepaymentInvalid =>
      'Төлөө суммасы нөлдөн чоң болушу керек.';

  @override
  String get errorCreditAllocationRace =>
      'Ошол эле учурда келишим боюнча башка кассадан төлөнгөн. Төлөмдү кайра кабыл алыңыз.';

  @override
  String get errorKindTenderCannotDiscount =>
      'Чыныгы акча алып келген төлөм түрүн чекте «төлөм эмес» деп жарыялоого болбойт.';

  @override
  String get errorKindAccountMissing =>
      'Төлөм түрүнө алуучу эсеп дайындалган эмес.';

  @override
  String get errorKindCounterpartyRequired =>
      'Кийинкиге калтырылган төлөм түрү аталган сатып алуучуну талап кылат.';

  @override
  String get errorKindProviderRequired =>
      'Провайдер (QR) аркылуу төлөм түрүнө провайдер керек.';

  @override
  String get errorKindFiscalKindRequired =>
      'Төлөм түрүнүн фискалдык мааниси көрсөтүлгөн эмес.';

  @override
  String get errorKindChangeNotATender =>
      'Кайтарымды чыныгы акча алып келген түр гана берет.';

  @override
  String get errorKindSystemImmutable =>
      'Системалык төлөм түрүнүн кодун же идентификаторун өзгөртүүгө да, башка түргө берүүгө да болбойт.';

  @override
  String get errorCertificateExpired =>
      'Сертификаттын мөөнөтү бүткөн. Дүкөндүн ээсине кайрылыңыз.';

  @override
  String get errorCertificateExhausted => 'Сертификатта каражат калган жок.';

  @override
  String get errorCertificateDuplicate =>
      'Бир сертификат төлөмдө эки жолу аталган. Кайталоону алып салыңыз.';

  @override
  String get errorCertificateRace =>
      'Сертификаттын калдыгы өзгөрдү. Төлөмдү кайталаңыз.';

  @override
  String get errorCertificateAccountMissing =>
      'Кассада сертификаттар боюнча милдеттенме эсеби жок. Администраторго кайрылыңыз.';

  @override
  String get errorCertificateNumberTaken =>
      'Мындай номердеги сертификат мурун чыгарылган.';

  @override
  String get errorCertificateNominalInvalid =>
      'Сертификаттын наркы нөлдөн чоң болушу керек.';

  @override
  String get errorDebtCustomerRequired =>
      'Карызга сатуу сатып алуучусуз мүмкүн эмес — сатып алуучуну тандаңыз.';

  @override
  String get errorDebtNotSoldHere =>
      'Бул кассада карызга сатылбайт — насыяга сатуу касса жөндөөлөрүндө өчүрүлгөн.';

  @override
  String get errorDebtAccountMissing =>
      'Сатып алуучуда эсеп жок — карызды жазганга жер жок.';

  @override
  String get errorBonusAccountMissing =>
      'Сатып алуучуда бонустук эсеп жок — бонусту эсептен чыгарууга эч нерсе жок.';

  @override
  String get errorPrepaymentCustomerRequired =>
      'Аванстын эсептелиши үчүн сатып алуучу керек — аны тандаңыз.';

  @override
  String get errorCreditTermInvalid => 'Мындай мөөнөткө бөлүп төлөө түзүлбөйт';

  @override
  String get errorCreditPrincipalInvalid =>
      'Бөлүп төлөөгө сумма жок: чек толук жабылган';

  @override
  String get errorCreditFeeInvalid => 'Келишим боюнча үстөк туура эмес';

  @override
  String get errorCreditSchemeUnknown => 'Мындай график схемасын касса билбейт';

  @override
  String get errorCreditOverdue =>
      'Сатып алуучунун башка бөлүп төлөө келишими мөөнөтү өткөн';

  @override
  String get errorCreditContractDuplicate =>
      'Бул чекке бөлүп төлөө келишими мурда түзүлгөн';

  @override
  String get errorPrepaymentAccountMissing =>
      'Сатып алуучуда эсеп жок — анда аванс болушу мүмкүн эмес.';

  @override
  String get errorPrepaymentInsufficient =>
      'Киргизилген аванс жетпеди: ал башка чек менен эсептелип калган.';

  @override
  String get errorLoyaltyCustomerUnknown =>
      'Сатып алуучу картотекадан табылган жок. Сатып алуучуну кайра тандаңыз.';

  @override
  String get errorAmountExceedsReceipt =>
      'Сумма чектин наркынан ашык. Сумманы кайра киргизиңиз.';

  @override
  String get errorCardChargeUnproven =>
      'Касса карта аркылуу төлөмдү тастыктаган жок. Төлөм терминалын текшериңиз.';

  @override
  String get errorPaymentTypeNotAllowed =>
      'Бул төлөм түрү бул жумуш ордунда уруксат берилген эмес.';

  @override
  String get errorPaymentsUnavailable =>
      'Бул касса зым аркылуу төлөмдү кабыл албайт. Администраторго кайрылыңыз.';

  @override
  String get errorNoRefundService =>
      'Бул касса зым аркылуу кайтарууну жүргүзбөйт. Администраторго кайрылыңыз.';

  @override
  String get errorRefundAbandonIsTillSide =>
      'Кайтаруу долбоорун жумуш орду эмес, касса алып салат.';

  @override
  String get errorNoAnswer =>
      'Касса жооп берген жок. Байланышты текшерип, кайталаңыз.';

  @override
  String paymentTypeNotAllowedHere(String type) {
    return '«$type» бул жумуш ордуна уруксат берилген эмес. Төлөм түрлөрү жабдуу жөндөөлөрүндө өзгөртүлөт; басканда да касса уруксатсыз түрдөн баш тартат.';
  }

  @override
  String paymentTypesLimitedHere(String types) {
    return 'Жумуш орду кабыл алат: $types.';
  }

  @override
  String get paymentDebtNotSoldHere =>
      'Бул кассада карызга сатылбайт: насыяга сатуу касса жөндөөлөрүндө өчүрүлгөн. Баскычты бассаңыз да, касса баш тартат.';

  @override
  String get paymentDebtNotPermitted =>
      'Сизге карызга сатууга уруксат жок: «карызга сатуу» укугу керек. Аны администратор укуктар жөндөөлөрүндө берет; укугу жоктун бардыгына касса баш тартат.';

  @override
  String get saleDiscountNotPermitted =>
      'Сизге арзандатуу берүүгө уруксат жок: «арзандатуу менен сатуу» укугу керек. Аны администратор укуктар жөндөөлөрүндө берет; укугу жоктун бардыгына касса баш тартат.';

  @override
  String get paymentDebtPolicyUnknown =>
      'Касса азырынча бул жерде карызга сатыларын жооп берген жок. Касса менен байланышты текшерип, кайра аракет кылыңыз.';

  @override
  String get paymentOffsetsTitle => 'Аванс жана сертификаттар';

  @override
  String get paymentPrepaymentTitle => 'Сатып алуучунун авансы';

  @override
  String get paymentPrepaymentNeedsCustomer =>
      'Авансты эсепке алуу үчүн сатып алуучуну телефон номери боюнча табыңыз.';

  @override
  String get paymentPrepaymentLoading =>
      'Касса азырынча канча аванс киргизилгенин жооп берген жок.';

  @override
  String get paymentPrepaymentNone => 'Сатып алуучунун киргизилген авансы жок.';

  @override
  String get paymentPrepaymentBalance => 'Алдын ала киргизилген:';

  @override
  String get paymentPrepaymentUse => 'Авансты эсепке алуу';

  @override
  String paymentPrepaymentApplied(String amount) {
    return 'Эсепке алынат: $amount';
  }

  @override
  String get paymentCertificateTitle => 'Белек сертификаты';

  @override
  String get paymentCertificateNumber => 'Сертификаттын номери';

  @override
  String get paymentCertificatePin => 'PIN, бар болсо';

  @override
  String get paymentCertificatePresent => 'Текшерүү';

  @override
  String paymentCertificateBalance(String amount) {
    return 'Сертификаттагы калдык: $amount';
  }

  @override
  String paymentCertificateApplied(String amount, String rest) {
    return '$amount эсептен чыгарылат, $rest калат';
  }

  @override
  String get paymentCertificateNotNeeded =>
      'Чек толук жабылды — бул сертификат керек болбойт.';

  @override
  String get unfiscalizedTitle => 'Фискалдашпаган чектер';

  @override
  String get unfiscalizedEmpty => 'Бардык чектер фискалдашкан';

  @override
  String get unfiscalizedEmptyHint =>
      'Бул жерде акчасы алынган, бирок оператор документ бербеген чектер пайда болот';

  @override
  String unfiscalizedReceiptNo(int number) {
    return 'Чек №$number';
  }

  @override
  String unfiscalizedAgeHours(int hours) {
    return '$hours саат мурун';
  }

  @override
  String get unfiscalizedOverdue => '72 сааттык мөөнөт өтүп кетти';

  @override
  String get unfiscalizedRetry => 'Кайталоо';

  @override
  String unfiscalizedRetryDone(String sign) {
    return 'Документ алынды: $sign';
  }

  @override
  String unfiscalizedRetryFailed(String message) {
    return 'Оператор кайра баш тартты: $message';
  }

  @override
  String get unfiscalizedNoDocument =>
      'Сап баш тартуулар документ ала баштаганга чейин жазылган: кайталай турган эч нерсе жок, аны эсептен гана чыгарууга болот';

  @override
  String get unfiscalizedNoOperator =>
      'Фискалдык оператор жөндөлгөн эмес: кайталоого жер жок';

  @override
  String get unfiscalizedWriteOff => 'Эсептен чыгаруу';

  @override
  String get unfiscalizedWriteOffTitle =>
      'Фискалдашпаган чекти эсептен чыгаруу';

  @override
  String unfiscalizedWriteOffBy(String name) {
    return 'Чечим ушул ысымга жазылат: $name';
  }

  @override
  String get unfiscalizedWriteOffReason => 'Эсептен чыгаруунун себеби';

  @override
  String get unfiscalizedWriteOffDone => 'Чек иштелип чыкты деп белгиленди';

  @override
  String unfiscalizedWrittenOff(String name, String reason) {
    return '$name эсептен чыгарды: $reason';
  }

  @override
  String get unfiscalizedUnknownUser => 'белгисиз колдонуучу';

  @override
  String unfiscalizedAtShiftClose(int count, String numbers) {
    return 'Смена фискалдашпаган чектер менен жабылды: $count. Номерлер: $numbers';
  }

  @override
  String documentsOnTheWayAtShiftClose(int count, String numbers) {
    return 'Смена документтери операторго али жеткен жок: $count (чектер $numbers). Жабуу аларды жөнөтүүнү күтөт; байланыш кайтпаса, Z-отчёт жөнөтүлбөйт — антпесе оператордун отчёту касса менен дал келбейт.';
  }

  @override
  String qrPaidPartial(String paid, String amount) {
    return 'Жарым-жартылай төлөндү: $amount ичинен $paid';
  }

  @override
  String get qrOrphanTitle => 'Чексиз акча';

  @override
  String get qrOrphanHint =>
      'Сатып алуучу QR аркылуу төлөдү, бирок чек бул акча менен жабылган жок.';

  @override
  String qrOrphanLine(String amount, String provider, String key) {
    return '$amount · $provider · $key';
  }

  @override
  String get qrOrphanAfterGiveUp =>
      'Ырастоо касса күтүүнү токтоткондон кийин келди';

  @override
  String get errorQrIntentUnknown =>
      'Касса бул QR төлөмүн билбейт. Чекти жаңыртып, кайталаңыз.';

  @override
  String get errorQrIntentNotPaid =>
      'QR төлөмүн банк дагы деле ырастай элек. Ырастоону күтүңүз же башка ыкманы тандаңыз.';

  @override
  String errorQrIntentAlreadySettled(String message) {
    return 'Бул акча башка чекти жаап койгон: $message';
  }

  @override
  String get paymentQrTitle => 'QR менен төлөө';

  @override
  String get paymentQrAmount => 'QR суммасы';

  @override
  String get paymentQrStart => 'QR көрсөтүү';

  @override
  String paymentQrWaiting(int seconds) {
    return 'Төлөмдү күтүп жатабыз · $seconds с калды';
  }

  @override
  String get paymentQrScanHint =>
      'Сатып алуучу кодду банк тиркемесинде сканерлейт';

  @override
  String get paymentQrCancel => 'Күтүүнү жокко чыгаруу';

  @override
  String get paymentQrNoLink =>
      'Провайдер менен байланыш жок — касса сурамды өзү кайталайт';

  @override
  String paymentQrPaid(String amount) {
    return 'QR менен төлөндү: $amount';
  }

  @override
  String paymentQrPaidAfterCancel(String amount) {
    return 'Сатып алуучу жокко чыгарууга чейин төлөп үлгүрдү — $amount ушул чекке кирет';
  }

  @override
  String get paymentQrCancelled => 'Күтүү жокко чыгарылды, провайдер ырастады';

  @override
  String get paymentQrPatienceSpent =>
      'Сатып алуучу белгиленген убакытта төлөгөн жок — касса күтүүнү токтотту';

  @override
  String get paymentQrExpired => 'QR коддун мөөнөтү провайдерде бүттү';

  @override
  String get paymentQrFailed => 'Провайдер QR төлөмүнөн баш тартты';

  @override
  String get paymentQrCancelUnconfirmed =>
      'Жокко чыгаруу ырасталган жок — акча дагы келиши мүмкүн. Касса аныктамайынча башка төлөмдү кабыл албаңыз.';

  @override
  String get paymentQrRecheck => 'Кайра текшерүү';

  @override
  String get paymentQrRestart => 'Жаңы код';

  @override
  String paymentQrOverReceipt(String amount) {
    return 'QR төлөмүнүн $amount суммасы чекке батпайт';
  }

  @override
  String get paymentQrNothingToPay =>
      'Чек толук жабылган — код көрсөтүүгө негиз жок';

  @override
  String get errorQrNotConfigured => 'Кассада QR провайдери жөндөлгөн эмес';

  @override
  String get errorQrNetwork => 'QR провайдери менен байланыш жок';

  @override
  String get errorQrTimeout => 'QR провайдери убагында жооп берген жок';

  @override
  String get errorQrProviderBusy => 'QR провайдери бош эмес — касса кайталайт';

  @override
  String get errorQrMalformedReply =>
      'QR провайдери түшүнүксүз жооп берди — кассанын администраторуна кайрылыңыз';

  @override
  String get errorQrUnknownIntent => 'QR провайдери бул төлөмдү билбейт';

  @override
  String get errorQrRejected => 'QR провайдери сурамды четке какты';

  @override
  String get errorQrReverseUnsupported => 'QR провайдери акчаны кайтара албайт';

  @override
  String get errorQrIntentLive =>
      'Бул чекте QR төлөмү күтүүдө — жаңы код көрсөтүүдөн мурун аны жокко чыгарыңыз';

  @override
  String get fiscalReasonNetwork => 'Фискалдык оператор менен байланыш жок';

  @override
  String get fiscalReasonOperatorUnavailable =>
      'Фискалдык оператор жеткиликсиз';

  @override
  String get fiscalReasonTokenExpired =>
      'Оператор кассанын авторизациясын кабыл алган жок';

  @override
  String get fiscalReasonRequestNotBuilt =>
      'Операторго суроо түзүлгөн жок: фискалдык жөндөөлөрдөгү сервердин дарегин текшериңиз';

  @override
  String get fiscalReasonTlsRejected =>
      'Оператор менен корголгон байланыш түзүлгөн жок: сервердин дарегин жана кассанын саатын текшериңиз';

  @override
  String get fiscalReasonClientFault =>
      'Оператор менен алмашууда кассанын катасы';

  @override
  String get fiscalReasonBadCredentials =>
      'Оператордун логини же сырсөзү туура эмес';

  @override
  String get fiscalReasonCashboxNotFound =>
      'Оператор бул кассаны тапкан жок: заводдук номерди текшериңиз';

  @override
  String get fiscalReasonCashboxBlocked =>
      'Касса оператор тарабынан бөгөттөлгөн';

  @override
  String get fiscalReasonOfflineLimitExceeded =>
      'Автономдуу документтердин чеги ашты';

  @override
  String get fiscalReasonOfflineNotSupported =>
      'Бул кассага автономдуу режимге уруксат жок';

  @override
  String get fiscalReasonDuplicate =>
      'Документ оператордо мурунтан катталган, бирок фискалдык белги кассага берилген эмес — аны оператордун кабинетинен алыңыз';

  @override
  String get fiscalReasonValidation =>
      'Оператор документти четке какты: суммалар же маалыматтар дал келбейт';

  @override
  String get fiscalReasonNotEnoughMoney =>
      'Оператордун маалыматы боюнча кассада накталай акча жетишсиз';

  @override
  String get fiscalReasonShiftError => 'Оператордо нөөмөт катасы';

  @override
  String get fiscalReasonUnsupported => 'Операцияны оператор колдобойт';

  @override
  String get fiscalReasonNotConfigured => 'Фискалдаштыруу жөндөлгөн эмес';

  @override
  String get fiscalReasonUnknown => 'Оператор белгисиз себеп менен баш тартты';

  @override
  String get fiscalReasonOfflineWindowExpired =>
      '72 сааттык автономдуу терезе бүттү — документ берилген жок';

  @override
  String get fiscalReasonRowUnreadable =>
      'Кезек сабы бузулган: документ окулбайт';

  @override
  String fiscalReasonWithCode(String reason, int code) {
    return '$reason (код $code)';
  }

  @override
  String fiscalReasonLegacy(String text) {
    return 'Себеп котормого чейин жазылган: $text';
  }

  @override
  String get fiscalReasonNotRecorded => 'Себеп жазылган эмес';

  @override
  String get fiscalReasonPaymentTypeNotAccepted =>
      'Төлөм түрүн оператор кабыл албайт: «кредит» жана «тара» ОФД 2.0.2 протоколунан алынып салынган';

  @override
  String get errorDeferredListUnavailable =>
      'Кийинкиге калтырылган чектердин тизмеси жеткиликсиз';

  @override
  String errorDeferredListUnavailableReason(String reason) {
    return 'Кийинкиге калтырылган чектердин тизмеси жеткиликсиз: $reason';
  }

  @override
  String get errorRefundSearchUnavailable =>
      'Бул терминалда кайтаруу үчүн товар издөө азырынча туташтырылган эмес';

  @override
  String get errorRefundNothingSelected =>
      'Долбоор өзгөрдү — кайтара турган эч нерсе жок. Белгиленген саптарды текшериңиз.';

  @override
  String get errorRefundInvalidAmount =>
      'Мынчалык кайтарууга болбойт: саны чек боюнча сатылгандан көп же нөлдөн аз боло албайт.';

  @override
  String get errorCertificatePinRequired =>
      'Сертификаттын PIN-коду бар. Сертификаттагы PIN-кодду териңиз.';

  @override
  String get qrSettingsTitle => 'QR аркылуу төлөм';

  @override
  String get qrSettingsSubtitle => 'QR провайдери: дарек, код, ачкыч, күтүү';

  @override
  String get qrSettingsKindTitle => 'QR аркылуу төлөм кабыл алуу';

  @override
  String get qrSettingsKindSubtitle => 'Төлөм экранындагы «QR» төлөм түрү';

  @override
  String get qrSettingsUrl => 'Провайдердин дареги';

  @override
  String get qrSettingsCode => 'Провайдердин коду';

  @override
  String get qrSettingsKey => 'Кирүү ачкычы';

  @override
  String get qrSettingsKeyStoredHint =>
      'Ачкыч сакталган. Алмаштыруу үчүн жаңысын киргизиңиз';

  @override
  String get qrSettingsKeyEmptyHint => 'Ачкыч берилген эмес';

  @override
  String get qrSettingsClearKey => 'Сакталган ачкычты өчүрүү';

  @override
  String get qrSettingsPatience => 'Төлөмдү күтүү, секунд';

  @override
  String get qrSettingsSave => 'Сактоо';

  @override
  String get qrSettingsSaved => 'QR жөндөөсү сакталды';

  @override
  String get qrSettingsRemove => 'Жөндөөнү алып салуу';

  @override
  String get qrSettingsStatusReady => 'Провайдер жөндөлгөн';

  @override
  String get qrSettingsStatusNotConfigured =>
      'Провайдер жөндөлгөн эмес — QR аркылуу төлөм жеткиликсиз';

  @override
  String get qrSettingsInvalidUrl =>
      'Дарек http:// же https:// менен башталышы керек';

  @override
  String get qrSettingsCodeRequired => 'Провайдердин кодун көрсөтүңүз';

  @override
  String qrSettingsInvalidPatience(String min, String max) {
    return 'Күтүү — $min секунддан $max секундга чейин';
  }

  @override
  String get qrSettingsSaveFailed => 'QR жөндөөсүн сактоо мүмкүн болбоду';

  @override
  String get qrSettingsTillOnly =>
      'QR провайдерин жөндөө кассанын өзүндө гана жеткиликтүү';

  @override
  String get installmentTermsTitle => 'Бөлүп төлөө';

  @override
  String get installmentTermsMonths => 'Мөөнөтү, ай';

  @override
  String get installmentTermsScheme => 'Графиктин түрү';

  @override
  String get installmentTermsContinue => 'Улантуу';

  @override
  String get customerPaymentTitle => 'Төлөм кабыл алуу / карызды төлөө';

  @override
  String customerPaymentCurrentDebt(String amount) {
    return 'Учурдагы карыз: $amount';
  }

  @override
  String customerPaymentBalance(String amount) {
    return 'Баланс: $amount';
  }

  @override
  String get customerPaymentAmount => 'Төлөм суммасы';

  @override
  String get customerPaymentAmountInvalid => '0дөн чоң сумманы киргизиңиз';

  @override
  String get customerPaymentFailed => 'Төлөмдү жүргүзүү катасы';

  @override
  String get customerPaymentSubmit => 'Төлөм кабыл алуу';

  @override
  String get errorPrepaymentAmountInvalid =>
      'Аванс суммасы нөлдөн чоң болушу керек. Сумманы кайра киргизиңиз.';

  @override
  String get errorPrepaymentTenderInvalid =>
      'Аванс накталай акча, карта же QR аркылуу кабыл алынат. Башка төлөм түрүн тандаңыз.';

  @override
  String get errorPrepaymentTillAccountMissing =>
      'Бул кассада бул төлөм түрүн кабыл алуучу эсеп жок. Кабыл алуу эсебин тууралап, кайталаңыз.';

  @override
  String get errorPrepaymentIntakeFailed =>
      'Авансты кабыл алуу мүмкүн болгон жок. Сатып алуучуну текшерип, кайталаңыз.';

  @override
  String get errorPrepaymentRefundExceedsBalance =>
      'Сатып алуучунун эсебиндеги аванс сиз берип жаткан суммадан аз. Калдыкты текшерип, сумманы азайтыңыз.';

  @override
  String get errorPrepaymentRefundKeyMissing =>
      'Аванс берүү арызында кайталоо ачкычы жок — касса кайталоону экинчи берүүдөн айырмалай албайт. Экранды кайра ачып, сумманы кайтадан териңиз.';

  @override
  String get errorPrepaymentRefundFailed =>
      'Авансты берүү мүмкүн болгон жок. Сатып алуучуну текшерип, кайталаңыз.';

  @override
  String get errorPrepaymentRefundUnavailable =>
      'Бул касса сатып алуучунун авансын зым аркылуу бербейт. Администраторго кайрылыңыз.';

  @override
  String get errorPrepaymentIntakeUnavailable =>
      'Бул касса сатып алуучунун авансын зым аркылуу кабыл албайт. Администраторго кайрылыңыз.';

  @override
  String get errorPrepaymentIntakeKeyMissing =>
      'Бул аванс өтүнмөсүндө кайталоо ачкычы жок, ошондуктан касса кайталоону экинчи төлөмдөн айырмалай албайт. Экранды кайра ачып, сумманы кайра киргизиңиз.';

  @override
  String get errorQrSetupUnavailable =>
      'Бул кассада QR провайдеринин жөндөөсү сакталбайт. QR аркылуу төлөмдү кассанын өзүндө жөндөңүз же администраторго кайрылыңыз.';

  @override
  String get errorReceiptTemplatesUnavailable =>
      'Бул кассада чек үлгүлөрү сакталбайт. Үлгүнү кассанын өзүндө жөндөңүз же администраторго кайрылыңыз.';

  @override
  String get errorReceiptTemplateNameless =>
      'Чек үлгүсүнүн аталышы болушу керек. Аталышын жазып, кайра сактаңыз.';

  @override
  String get shiftDeskTitle => 'Смена';

  @override
  String get shiftDeskOverAgeWarning =>
      'Смена 24 сааттан ашык — сатуу бөгөттөлгөн. Аны жаап, жаңысын ачыңыз.';

  @override
  String shiftDeskOpenedAt(String when) {
    return 'Ачылган: $when';
  }

  @override
  String get shiftDeskCountedLabel => 'Кутучада эсептелген';

  @override
  String get shiftDeskCountedHint =>
      'Эч ким санабаса, бош калтырыңыз — касса өз жыйынтыгын алат.';

  @override
  String get shiftDeskOpeningCashLabel => 'Башында кутучадагы акча';

  @override
  String get shiftDeskClosedNow => 'Смена жабылды.';

  @override
  String get shiftDeskOpenedNow => 'Смена ачылды.';

  @override
  String get shiftDeskNoShift => 'Кассада ачык смена жок.';

  @override
  String shiftDeskUnfiscalizedCount(int count) {
    return 'Фискалдык документсиз чектер: $count';
  }

  @override
  String shiftDeskUnfinishedCount(int count) {
    return 'Аякталбаган чектер: $count — жабуу аларды тазалайт';
  }

  @override
  String get errorShiftDeskNotOpen =>
      'Бул кассада ачык смена жок — жабууга эч нерсе жок.';

  @override
  String get errorShiftDeskAlreadyOpen => 'Бул кассада смена мурунтан ачык.';

  @override
  String get errorShiftDeskUnavailable =>
      'Бул касса сменаларды зым аркылуу жүргүзбөйт. Смонаны кассанын өзүндө жабыңыз же администраторго кайрылыңыз.';

  @override
  String get errorShiftDeskActorUnknown =>
      'Смонаны кассир ачат, бул өтүнүчтө кассир аталган эмес. Кайра кириңиз.';

  @override
  String get prepaymentIntakeTitle => 'Аванс кабыл алуу';

  @override
  String get prepaymentIntakeFind => 'Сатып алуучуну табуу';

  @override
  String get prepaymentIntakeNotFound =>
      'Мындай номер менен сатып алуучу табылган жок.';

  @override
  String get prepaymentIntakeSubmit => 'Авансты кабыл алуу';

  @override
  String prepaymentIntakeAccepted(String amount) {
    return 'Аванс кабыл алынды. Алдын ала киргизилген: $amount';
  }

  @override
  String get prepaymentIntakeFiscalFailed =>
      'Акча кабыл алынды, бирок аванстын фискалдык чеги жазылган жок.';

  @override
  String get emulatorSettingsTitle => 'Орнотулган эмуляторлор';

  @override
  String get emulatorSettingsHint =>
      'Аспаптарды туташтырбай басып чыгарууну жана диагностиканы текшерүү';

  @override
  String get emulatorReceiptPrinter => 'Чек принтери жана акча кутусу';

  @override
  String get emulatorEnabledNote =>
      'Сокет ачык. Касса ага байланыштагы дарек аркылуу гана жетет';

  @override
  String get emulatorDisabledNote => 'Өчүк: сокет ачылган эмес';

  @override
  String get emulatorAddress => 'Эмулятордун дареги';

  @override
  String get emulatorAddressHint =>
      'Бул IP менен портту принтер жөндөөлөрүнө жазыңыз';

  @override
  String get emulatorBindAction => 'Принтер байланышына жазуу';

  @override
  String get emulatorBindDone => 'Принтер байланышы эми эмуляторго карайт';

  @override
  String get emulatorBindingStale =>
      'Принтер байланышы өчүрүлгөн эмуляторго карайт — басып чыгаруу иштебейт';

  @override
  String get emulatorStartFailed => 'Эмуляторду иштетүү мүмкүн болгон жок';

  @override
  String get emulatorFiscalOperator => 'Фискалдык оператор (ОФД)';

  @override
  String get emulatorFiscalAddressHint =>
      'Бул даректи фискалдык жөндөөлөрдүн «Сервер дареги» талаасына жазыңыз';

  @override
  String get emulatorFiscalBindAction => 'Фискалдык жөндөөлөргө жазуу';

  @override
  String get emulatorFiscalBindNote =>
      'Эмулятордун дарегин, логинин, сырсөзүн, ачкычын жана заводдук номерин жазат жана кассаны сыноо кассасы деп жарыялайт. Каттоо номерине тийбейт';

  @override
  String get emulatorFiscalBindDone =>
      'Фискалдык жөндөөлөр эми эмуляторго карайт';

  @override
  String get emulatorFiscalBindingStale =>
      'Фискалдык жөндөөлөр өчүрүлгөн эмуляторго карайт — фискалдаштыруу иштебейт';

  @override
  String get emulatorFiscalLocalModuleWarning =>
      '«Жергиликтүү модуль» талаасы толтурулган — ал сервер дарегин басып өтөт, касса эмуляторго барбайт';

  @override
  String get emulatorFiscalBlockedLive =>
      'Касса чыныгы иштейт: оператордун реквизиттери толтурулган. Бул жерде ОФД эмуляторуна тыюу салынат — жасалмага кеткен чек чыныгыдай көрүнөт, бирок сатып алуучуга документ бербейт';

  @override
  String get emulatorFiscalBlockedUnknown =>
      'Фискалдык жөндөөлөр окулган жок — ОФД эмуляторун күйгүзүүгө болбойт';

  @override
  String get diagnosticsFiscalEmulatorBanner =>
      'Оператордун дареги ушул эле компьютерге карайт — документтер эмуляторго кетет жана фискалдык эмес';

  @override
  String get diagnosticsTitle => 'Жабдуу диагностикасы';

  @override
  String get diagnosticsSubtitle =>
      'Касса аспаптарга чындыгында эмне жибергени';

  @override
  String get diagnosticsTabPrinter => 'Принтер';

  @override
  String get diagnosticsTabFiscal => 'Фискалдаштыруу';

  @override
  String get errorDiagnosticsUnavailable =>
      'Бул кассада диагностиканы сурай турган эч ким жок';

  @override
  String get diagnosticsPrinterQueueMissing =>
      'Бул жумуш ордунда басып чыгаруу кезеги бапталган эмес';

  @override
  String get diagnosticsPrinterNothingSent =>
      'Касса принтерге азырынча эч нерсе жөнөткөн жок';

  @override
  String diagnosticsAskFailed(String reason) {
    return 'Касса бул суроого жооп берген жок: $reason';
  }

  @override
  String diagnosticsAttempts(int count) {
    return 'аракет $count';
  }

  @override
  String get diagnosticsJobQueued => 'кезекте турат';

  @override
  String get diagnosticsJobPrinting => 'басылып жатат';

  @override
  String get diagnosticsJobPrinted => 'басылды';

  @override
  String get diagnosticsJobFailed => 'басылган жок';

  @override
  String get diagnosticsJobExpired => 'мөөнөтү өттү';

  @override
  String get diagnosticsJobCancelled => 'жокко чыгарылды';

  @override
  String get diagnosticsFiscalNotConfigured =>
      'Бул кассада фискалдык оператор бапталган эмес';

  @override
  String get diagnosticsFiscalAccepted => 'Оператор кабыл алды';

  @override
  String get diagnosticsFiscalAcceptedEmpty =>
      'Оператор азырынча бир да документ кабыл алган жок';

  @override
  String get diagnosticsFiscalQueued => 'Кезекте';

  @override
  String get diagnosticsFiscalQueuedEmpty =>
      'Кезек бош — жөнөтүлгөндүн баарын оператор кабыл алды';

  @override
  String diagnosticsFiscalSign(String value) {
    return 'Фискалдык белги $value';
  }

  @override
  String diagnosticsFiscalOperatorDoc(String value) {
    return 'оператор документи $value';
  }

  @override
  String diagnosticsFiscalReceiptNo(String value) {
    return 'чек $value';
  }

  @override
  String get diagnosticsFiscalOffline => 'өз алдынча берилген';

  @override
  String get diagnosticsEmulatorBanner =>
      'Принтер байланышы ушул эле компьютерге карайт — порттун артында кагаз эмес, эмулятор';

  @override
  String get diagnosticsTabDrawer => 'Акча кутусу';

  @override
  String get drawerDiagnosticsEmpty =>
      'Касса иштегенден бери кутуча бир да жолу ачылган жок';

  @override
  String get drawerDiagnosticsUnavailable =>
      'Бул кассада кутуча импульстеринин жазуусу жок — сурай турган нерсе жок. Бул кутуча ачылган эмес дегенди билдирбейт.';

  @override
  String get drawerDiagnosticsCaveat =>
      'Касса команданын кабыл алынганын гана билет. Кутучанын чындап ачылганы тууралуу кайтарым байланыш эки жолдо тең жок.';

  @override
  String get drawerDiagnosticsAccepted => 'Команда кабыл алынды';

  @override
  String get drawerDiagnosticsRefused => 'Команда четке кагылды';

  @override
  String get drawerDiagnosticsViaSerial => 'тизмектүү порт';

  @override
  String get drawerDiagnosticsViaPrinter => 'принтер аркылуу (ESC p)';

  @override
  String get diagnosticsTabScales => 'Таразы';

  @override
  String get diagnosticsTabDisplay => 'Дисплей';

  @override
  String get scalesDiagnosticsUnbound =>
      'Бул кассага таразы байланган эмес.\nАны жабдуу жөндөөлөрүндө байланыштырыңыз — ошондо бул жерде көрсөткүч чыгат.';

  @override
  String get scalesDiagnosticsWeight => 'Таразы көрсөткүчү';

  @override
  String get scalesDiagnosticsSilent => 'Таразы азырынча эч нерсе жиберген жок';

  @override
  String get scalesDiagnosticsStable => 'Салмак турукталды';

  @override
  String get scalesDiagnosticsSettling => 'Салмак өзгөрүүдө';

  @override
  String get scalesDiagnosticsOverload => 'Ашыкча жүк';

  @override
  String get scalesDiagnosticsPort => 'Таразы порту';

  @override
  String get scalesDiagnosticsBaudSuffix => 'бод';

  @override
  String get scalesDiagnosticsConnected => 'Порт ачык';

  @override
  String get scalesDiagnosticsDisconnected => 'Порт жабык';

  @override
  String get scalesDiagnosticsCaveat =>
      'Бул — аспап жибергени. Көрсөткүчтүн тууралыгын касса текшербейт, ага текшерүү жооптуу.';

  @override
  String get displayDiagnosticsEmpty =>
      'Касса иштегенден бери дисплейге эч нерсе жиберилген жок';

  @override
  String get displayDiagnosticsUnavailable =>
      'Бул кассада дисплей саптарынын жазуусу жок — сурай турган нерсе жок. Бул дисплейге эч нерсе жиберилген эмес дегенди билдирбейт.';

  @override
  String get displayDiagnosticsCurrent => 'Азыр дисплейде';

  @override
  String get displayDiagnosticsCaveat =>
      'Касса сап портко кеткенин гана билет. Өчкөн же ажыратылган дисплей бул жерден иштеп турганынан айырмаланбайт.';

  @override
  String get displayDiagnosticsCallPrice => 'баа';

  @override
  String get displayDiagnosticsCallTotal => 'жыйынтык';

  @override
  String get displayDiagnosticsCallChange => 'кайтарым';

  @override
  String get displayDiagnosticsCallText => 'текст';

  @override
  String get displayDiagnosticsCallWelcome => 'саламдашуу';

  @override
  String get displayDiagnosticsCallClear => 'тазалоо';

  @override
  String get emulatorScaleWeight => 'Табактагы салмак';

  @override
  String get emulatorScaleWeightHint =>
      'Эмулятор пульту: таразы кассага ушул санды жиберет';

  @override
  String get emulatorQrProvider => 'QR төлөм провайдери';

  @override
  String get emulatorQrAddressHint =>
      'Бул даректи QR провайдеринин жөндөөсүнө жазыңыз';

  @override
  String get emulatorQrBindAction => 'QR жөндөөсүнө жазуу';

  @override
  String get emulatorQrBindDone => 'QR жөндөөсү эми эмуляторго багытталган';

  @override
  String get emulatorQrBindingStale =>
      'QR жөндөөсү өчүрүлгөн эмуляторго багытталган — код боюнча төлөм четке кагылат';

  @override
  String get diagnosticsTabPayment => 'Төлөм';

  @override
  String get diagnosticsPaymentEmulatorBanner =>
      'QR провайдери ушул эле компьютерде: даректин артында банк эмес, эмулятор';

  @override
  String get paymentDiagnosticsUnavailable =>
      'Бул жумуш ордунда төлөм жөнүндө маалымат жок';

  @override
  String get paymentDiagnosticsQrSection => 'QR аркылуу төлөм';

  @override
  String get paymentDiagnosticsQrEmpty =>
      'Касса азырынча бир да төлөм кодун түзгөн жок';

  @override
  String get paymentDiagnosticsQrNotConfigured =>
      'Бул кассада QR провайдери бапталган эмес';

  @override
  String paymentDiagnosticsQrAddress(String address) {
    return 'Провайдер: $address';
  }

  @override
  String get paymentDiagnosticsQrUnknown =>
      'Провайдерге жөнөтүлгөн суроо-талап денелерин касса сактабайт. Көрүнгөнү — ниетте калганы: сумма, абал, ал жактагы идентификатор жана четке кагуу себеби.';

  @override
  String get paymentDiagnosticsTerminalSection => 'Төлөм терминалы';

  @override
  String get paymentDiagnosticsTerminalEmpty =>
      'Касса күйгөндөн бери төлөм терминалына бир да кадр кеткен жок';

  @override
  String get paymentDiagnosticsTerminalUnknown =>
      'Терминал журналы эстутумда турат: кайра күйгүзүүгө чейинки алмашуулар сакталбайт, ал эми терминалдын өзүндө жасалган операцияларды касса такыр көрбөйт.';

  @override
  String get paymentDiagnosticsRequest => 'Суроо-талап';

  @override
  String get paymentDiagnosticsReply => 'Жооп';

  @override
  String get paymentDiagnosticsNoReply => 'Жооп болгон жок';

  @override
  String paymentDiagnosticsApproval(String value) {
    return 'Жактыруу коду $value';
  }

  @override
  String paymentDiagnosticsTransaction(String value) {
    return 'транзакция $value';
  }

  @override
  String paymentDiagnosticsRefusal(String value) {
    return 'Четке кагуу: $value';
  }

  @override
  String paymentDiagnosticsConfirmations(int count) {
    return 'ырастоо саны $count';
  }

  @override
  String get paymentDiagnosticsOrphanMoney => 'чеги жок акча';

  @override
  String get paymentDiagnosticsAfterGiveUp =>
      'касса күтүүнү токтоткондон кийин ырасталды';

  @override
  String get paymentDiagnosticsApproved => 'Жактырылды';

  @override
  String get paymentDiagnosticsDeclined => 'Четке кагылды';

  @override
  String get paymentDiagnosticsOpPurchase => 'сатып алуу';

  @override
  String get paymentDiagnosticsOpReversal => 'сторно';

  @override
  String get paymentDiagnosticsOpRefund => 'кайтаруу';

  @override
  String get paymentDiagnosticsOpUnknown => 'белгисиз түрдөгү кадр';

  @override
  String get certificateIssueTitle => 'Белек сертификатын чыгаруу';

  @override
  String get certificateIssueHint =>
      'Кагаз үчүн акчаны сатуу чеги кабыл алат. Бул жерде кагазга калдык ачылат, касса милдеттенме алат.';

  @override
  String get certificateIssueNumber => 'Кагаздын номери';

  @override
  String get certificateIssueNominal => 'Номинал';

  @override
  String get certificateIssuePin => 'ПИН (милдеттүү эмес)';

  @override
  String get certificateIssueExpiresDays =>
      'Жарактуулук мөөнөтү, күн (милдеттүү эмес)';

  @override
  String get certificateIssueReceipt => 'Сатуу чегинин номери (милдеттүү эмес)';

  @override
  String get certificateIssueSubmit => 'Сертификат чыгаруу';

  @override
  String certificateIssueDone(String number, String amount) {
    return '$number сертификаты $amount суммасына чыгарылды';
  }

  @override
  String get certificateIssueFailed => 'Сертификат чыгарылган жок';

  @override
  String get certificateIssueNumberRequired => 'Кагаздын номерин киргизиңиз';

  @override
  String get certificateIssueNominalInvalid =>
      'Номинал нөлдөн чоң болушу керек';

  @override
  String get certificateIssueNotPermitted =>
      'Бул кассирге сертификат чыгарууга уруксат жок';

  @override
  String get certificateSlipTitle => 'Слипти кайра басып чыгаруу';

  @override
  String get certificateSlipHint =>
      'Чыгарууда слип басылган жок — кагазды кайталама слип боюнча берсе болот.';

  @override
  String get certificateSlipNumber => 'Сертификаттын номери';

  @override
  String get certificateSlipPin => 'ПИН, эгер бар болсо';

  @override
  String get certificateSlipSubmit => 'Слипти басып чыгаруу';

  @override
  String certificateSlipDone(String number) {
    return '$number сертификатынын слиби басып чыгарууга жөнөтүлдү';
  }

  @override
  String get certificateSlipFailed => 'Слип басып чыгарууга жөнөтүлгөн жок';

  @override
  String get certificateSlipUnavailable => 'Бул кассада слип басчу түзмөк жок';

  @override
  String get prepaymentRefundTitle => 'Авансты кайтаруу';

  @override
  String get prepaymentRefundHint =>
      'Сатып алуучу алдын ала киргизген акча кайтарылат. Карыз мунун жардамы менен төлөнбөйт, бонустар тийбейт.';

  @override
  String prepaymentRefundBalance(String amount) {
    return 'Алдын ала киргизилген: $amount';
  }

  @override
  String get prepaymentRefundNothing =>
      'Сатып алуучунун эсебинде аванс жок — кайтара турган эч нерсе жок';

  @override
  String get prepaymentRefundAmount => 'Кайтарыла турган сумма';

  @override
  String get prepaymentRefundTender => 'Эмне менен кайтарылат';

  @override
  String get prepaymentRefundIntake =>
      'Кабыл алуу жазуусунун номери (милдеттүү эмес)';

  @override
  String get prepaymentRefundSubmit => 'Авансты кайтаруу';

  @override
  String prepaymentRefundDone(String amount) {
    return 'Аванс кайтарылды. Эсепте калганы: $amount';
  }

  @override
  String get prepaymentRefundFailed => 'Аванс кайтарылган жок';

  @override
  String get prepaymentRefundAmountInvalid => 'Сумма нөлдөн чоң болушу керек';

  @override
  String get prepaymentRefundNotPermitted =>
      'Бул кассирге авансты кайтарууга уруксат жок';

  @override
  String get prepaymentRefundFiscalFailed =>
      'Акча берилди, бирок аванс кайтарымынын фискалдык чеги жазылган жок.';

  @override
  String get agentRefundPrepayment => 'Авансты кайтаруу';

  @override
  String get repTitle => 'Отчёттор';

  @override
  String get repTabAnalytics => 'Аналитика';

  @override
  String get repTabFinance => 'Каржы';

  @override
  String get repTabForecasts => 'Болжолдор';

  @override
  String get repTabTaxKz => 'Салыктар/КЗ';

  @override
  String get repRangeDays7 => '7 күн';

  @override
  String get repRangeDays30 => '30 күн';

  @override
  String get repRangeCustom => 'Ыктыярдуу';

  @override
  String get repKpiChange => 'Өзгөрүү';

  @override
  String get repSubtitleVsPrev => 'мурунку мезгил м-н';

  @override
  String get repChartRevenueByDay => 'Күн боюнча түшүм';

  @override
  String get repChartTop5Products => 'Мыкты 5 товар';

  @override
  String get repChartPaymentMethods => 'Төлөм ыкмалары';

  @override
  String get settingsRestartRequired =>
      'Өзгөрүүлөр касса кийинки жолу иштегенде колдонулат.';

  @override
  String get hardwareRestartRequired =>
      'Түзмөк өзгөрүүлөрү касса кийинки жолу иштегенде колдонулат.';

  @override
  String get hardwareDeviceDisabled => 'Түзмөк өчүрүлгөн.';

  @override
  String get hardwareCustomerDisplayGraphic =>
      'Сатып алуучунун графикалык экраны (2-монитор)';

  @override
  String get hardwareCustomerDisplayGraphicOff =>
      'Сатып алуучунун графикалык экраны өчүрүлгөн.';

  @override
  String get hardwarePaymentKinds => 'Жумуш ордунун төлөм түрлөрү';

  @override
  String get hardwarePaymentKindsUnrestricted =>
      'Чектөө жок: жумуш орду бардык төлөм түрлөрүн кабыл алат.';

  @override
  String get fiscalSettingsDirectOfdLabel => 'ОФД-га түз туташуу';

  @override
  String get markupAuto => 'Авто үстөк';

  @override
  String get markupSave => 'Үстөктөрдү сактоо';

  @override
  String get creditContractNumberLabel => 'Кагаздагы келишим номери';

  @override
  String get creditNoLiveContracts => 'Активдүү бөлүп төлөө келишимдери жок';

  @override
  String get supplierOrderTitle => 'Жеткирүүчүгө өтүнмө';

  @override
  String get supplierOrderAllStocked => 'Бардык товар жетиштүү өлчөмдө';

  @override
  String get supplierOrderNotNeeded => 'Кошумча буйрутма талап кылынбайт';

  @override
  String get hwScaleTitle => 'Таразы';

  @override
  String get hwReceiptPrinterTitle => 'Чек принтери';

  @override
  String get repRangeDays14 => '14 күн';

  @override
  String get repForecastSmaLowData => 'SMA (маалымат аз)';

  @override
  String get repNoCategory => 'Категориясыз';

  @override
  String get repAllCustomers => 'Бардык кардарлар';

  @override
  String get repAllInStock => 'Бардык товар кампада';

  @override
  String get repAllCovered30 => 'Бардык товар 30+ күнгө жетет';

  @override
  String get repColDays => 'Күн';

  @override
  String get repColDaysLeft => 'Калган күн';

  @override
  String get repColSharePct => 'Үлүш %';

  @override
  String get repColChangePct => 'Өзгөрүү %';

  @override
  String get repColSalesCount => 'Сатуу саны';

  @override
  String get repReceiptCountLabel => 'Чек саны';

  @override
  String get repStockCritical => 'Калдык өтө аз! Шашылыш жеткирүү керек.';

  @override
  String get repColCumulativePct => 'Жыйнал. %';

  @override
  String get repNotEnoughSalesData =>
      'Тандалган мезгилде сатуу маалыматы жетишсиз';

  @override
  String get repNoForecastData => 'Болжол үчүн маалымат жок';

  @override
  String get repNoDataLast90 => 'Акыркы 90 күндө маалымат жок';

  @override
  String get repNoCustomerData => 'Кардарлар жөнүндө маалымат жок';

  @override
  String get repNoLowStock => 'Калдыгы аз товар жок';

  @override
  String get repLowStock => 'Калдык аз';

  @override
  String get repNewPrice => 'Жаңы баа';

  @override
  String get repColEstimatedAmount => 'Болжол. сумма';

  @override
  String get repColSeatings => 'Отургузуу';

  @override
  String get repForecast => 'Болжол';

  @override
  String get repRevenueForecast => 'Түшүм болжолу';

  @override
  String get repRevenueForecastHw => 'Түшүм болжолу (Holt-Winters)';

  @override
  String get repStockoutForecast => 'Калдыктын түгөнүү болжолу';

  @override
  String get repStockForecast => 'Калдык болжолу';

  @override
  String get repSalesWithoutCustomerHidden =>
      'Кардарга байланбаган сатуулар көрсөтүлбөйт';

  @override
  String get repColSalesPerDay => 'Сатуу/күн';

  @override
  String get repColSold => 'Сатылды';

  @override
  String get repHourlyDistribution => 'Саат боюнча бөлүштүрүү';

  @override
  String get repColRecommendedOrder => 'Сунуш. буйрутма';

  @override
  String get repRecommendedPurchases => 'Сунушталган сатып алуу';

  @override
  String get repColAvgSalesPerDay => 'Орт. сатуу/күн';

  @override
  String get repColAvgCheckShort => 'Орт. чек';

  @override
  String get repAvgPrice => 'Орточо баа';

  @override
  String get repOldPrice => 'Эски баа';

  @override
  String get repStockValue => 'Калдык наркы';

  @override
  String get repColTable => 'Стол';

  @override
  String get repCurrentStock => 'Учурдагы калдык';

  @override
  String get repTop10Customers => 'Мыкты 10 кардар';

  @override
  String get repTop10Products => 'Мыкты 10 товар';

  @override
  String get repActual => 'Иш жүзүндө';

  @override
  String get repColHour => 'Саат';

  @override
  String get repExport => 'Экспорт';

  @override
  String get repCashierPerformance => 'Кассирлердин натыйжалуулугу';

  @override
  String get repWeightedAvgHint =>
      'салмактанган орточо (акыркы күндөр оорураак)';

  @override
  String get repSalesCountByHour => 'саат боюнча сатуу саны';

  @override
  String get repNoUrgentItems => 'шашылыш позиция жок';

  @override
  String get repByRevenueTapHint => 'түшүм боюнча (чоо-жайы үчүн басыңыз)';

  @override
  String get repDistributionTapHint => 'бөлүштүрүү (секторду басыңыз)';

  @override
  String get repRevenueDistributionTapHint =>
      'түшүмдүн бөлүштүрүлүшү (секторду басыңыз)';

  @override
  String get repAbcRare => 'сейрек';

  @override
  String get repAbcMedium => 'орточо';

  @override
  String get repAbcFast => 'өтүмдүү';

  @override
  String get repAbcLegend =>
      'өтүмдүү (A), орточо (B), сейрек (C) — түшүмгө кошкон салымы боюнча';

  @override
  String repReturnsCount(int count) {
    return '$count кайтаруу';
  }

  @override
  String repAbcGroupSummary(int count, String pct) {
    return '$count товар · $pct%';
  }

  @override
  String repCustomerTooltip(String name, String amount, int count) {
    return '$name\n$amount ($count чек)';
  }

  @override
  String repDaysCountTapHint(int count) {
    return '$count күн (чоо-жайы үчүн басыңыз)';
  }

  @override
  String repCashiersCount(int count) {
    return '$count кассир';
  }

  @override
  String repLowStockCountHint(int count) {
    return '$count товар (калдык < 10, басыңыз)';
  }

  @override
  String repOrdersShort(int count) {
    return '$count буйр.';
  }

  @override
  String repOrdersRevenueTooltip(int count, String amount) {
    return '$count буйр.\n$amount';
  }

  @override
  String repPieces(String qty) {
    return '$qty даана';
  }

  @override
  String repPiecesDot(String qty) {
    return '$qty даана';
  }

  @override
  String repForecastSubtitle(int actual, int horizon, String algorithm) {
    return '$actual күн иш жүзүндө + $horizon күн болжол ($algorithm)';
  }

  @override
  String repSalesCountLine(int count) {
    return '$count сатуу';
  }

  @override
  String repReceiptsCount(int count) {
    return '$count чек';
  }

  @override
  String repSupplierTooltip(String name, int count) {
    return '$name\n$count жеткирүү';
  }

  @override
  String repSeatingsLine(int count) {
    return '$count отургузуу';
  }

  @override
  String repDayOffset(int n) {
    return '+$n күн';
  }

  @override
  String repHoltWintersSeason(int season) {
    return 'Holt-Winters (сезон=$season)';
  }

  @override
  String repInvestmentsLine(String amount) {
    return 'Салымдар: $amount';
  }

  @override
  String repDividendsLine(String amount) {
    return 'Дивиденддер: $amount';
  }

  @override
  String repMarginLine(String pct) {
    return 'Маржа: $pct%';
  }

  @override
  String repKpiLoadErrorWith(String error) {
    return 'KPI жүктөлбөдү: $error';
  }

  @override
  String repErrorWith(String error) {
    return 'Ката: $error';
  }

  @override
  String repProfitLine(String amount) {
    return 'Пайда: $amount';
  }

  @override
  String repExpensesLine(String amount) {
    return 'Чыгымдар: $amount';
  }

  @override
  String repLeadTimeHint(int lead, int safety) {
    return 'жеткирүү мөөнөтү $lead к. + камсыздык кор $safety к.';
  }

  @override
  String get markupHint =>
      'Категория боюнча үстөк, %. Товар келгенде чекене баа сатып алуу баасынан кайра эсептелет: сатып алуу × (1 + үстөк%).';

  @override
  String get creditContractsTitle => 'Бөлүп төлөө';

  @override
  String creditContractsTitleFor(String agent) {
    return 'Бөлүп төлөө — $agent';
  }

  @override
  String repExportedTo(String path) {
    return 'Экспорттолду: $path';
  }

  @override
  String repExportFailed(String error) {
    return 'Экспорт катасы: $error';
  }

  @override
  String get hwSetupIncompleteDevices =>
      'Жөндөө устасы бүтө элек — түзмөктөрдү сактаганга жер жок';

  @override
  String get hwSetupIncompleteCheck =>
      'Жөндөө устасы бүтө элек — текшере турган эч нерсе жок';

  @override
  String get settingsSetupIncompleteSave =>
      'Жөндөө устасы бүтө элек — сактаганга жер жок';

  @override
  String get hwProfileCatalogUnavailable =>
      'Түзмөк профилдеринин каталогу жеткиликсиз — түзмөк жөндөөлөрүн азыр өзгөртүүгө болбойт.';

  @override
  String get printerProfileCatalogUnavailable =>
      'Түзмөк профилдеринин каталогу жеткиликсиз — принтер жөндөөлөрүн азыр өзгөртүүгө болбойт.';

  @override
  String get labelPrinterProfileCatalogUnavailable =>
      'Түзмөк профилдеринин каталогу жеткиликсиз — энбелги принтеринин жөндөөлөрүн азыр өзгөртүүгө болбойт.';

  @override
  String get hwPaymentKindsUnsupported =>
      'Бул чогултма жумуш ордунун төлөм түрлөрүн сактай албайт.';

  @override
  String get hwPaymentKindsEnforcedByTill =>
      'Тыюуну касса текшерет: төлөм түрүнө уруксаты жок терминал баш тартуу алат, экранындагы баскыч калса да.';

  @override
  String get hwCustomerDisplayGraphicDesc =>
      'Экинчи мониторго сатып алуучу үчүн графикалык экран: чек саптары, саны жана жыйынтыгы — реалдуу убакытта.';

  @override
  String get hwCustomerDisplayMonitor => 'Сатып алуучунун экраны үчүн монитор';

  @override
  String get hwCustomerDisplayMonitorHint =>
      'POS негизги мониторго калат. Касса кийинки жолу иштегенде автоматтык түрдө ачылат.';

  @override
  String get hwNoProfilesForClass =>
      'Бул түзмөк классы үчүн жеткиликтүү модель жок.';

  @override
  String get hwNoConnectionParams =>
      'Бул модель кошумча туташуу параметрлерин талап кылбайт.';

  @override
  String hwMonitorWithSize(int index, String size) {
    return 'Монитор $index — $size';
  }

  @override
  String hwMonitorNumbered(int index) {
    return 'Монитор $index';
  }

  @override
  String hwPaymentKindsError(String error) {
    return 'Төлөм түрлөрү: $error';
  }

  @override
  String hwPaymentKindsUnknown(String list) {
    return 'Бул жумуш ордунун жөндөөсүндө бул версия билбеген түрлөр жазылган: $list. Алар боюнча чектөө жок. Жазууну оңдоо үчүн түрлөрдү кайра тандаңыз — ага чейин ал ошол бойдон калат.';
  }

  @override
  String hwParamOptional(String description) {
    return '$description (милдеттүү эмес)';
  }

  @override
  String globalMillimetres(String value) {
    return '$value мм';
  }

  @override
  String get devProfilePrinterEscpos80mm => 'ESC/POS чек принтери, 80 мм';

  @override
  String get devProfilePrinterEscpos58mm =>
      'ESC/POS чек принтери, 58 мм (ыкчам, бычаксыз)';

  @override
  String get devProfilePrinterEscposUsb => 'ESC/POS чек принтери, USB/спулер';

  @override
  String get devProfilePrinterEscposBluetooth =>
      'ESC/POS чек принтери, Bluetooth';

  @override
  String get devProfilePrinterEscposSerial =>
      'ESC/POS чек принтери, ырааттуу порт';

  @override
  String get devProfilePrinterLabelZpl104 => 'ZPL энбелги принтери, 104 мм';

  @override
  String get devProfilePrinterLabelEpl58 => 'EPL энбелги принтери, 58 мм';

  @override
  String get devProfileScannerUsbHid => 'USB штрихкод сканери (HID)';

  @override
  String get devProfileScannerBluetoothHid =>
      'Bluetooth штрихкод сканери (HID)';

  @override
  String get devProfileScannerCamera => 'Түзмөк камерасы аркылуу сканер';

  @override
  String get devProfileScannerSerial => 'Штрихкод сканери, ырааттуу порт';

  @override
  String get devProfileScaleCasPd2 => 'CAS PD-II таразысы (ырааттуу)';

  @override
  String get devProfileScaleCasErPlus => 'CAS ER-Plus таразысы';

  @override
  String get devProfileDrawerViaPrinter => 'Принтер аркылуу акча кутусу (RJ11)';

  @override
  String get devProfileDrawerStandalone => 'Автономдуу акча кутусу (RJ11)';

  @override
  String get devProfileDisplayVfd => 'VFD сатып алуучу дисплейи (ырааттуу)';

  @override
  String get devProfileDisplayLcd2x20 => 'LCD сатып алуучу дисплейи 2x20';

  @override
  String get devProfileDisplayLed8 => 'LED сатып алуучу дисплейи (8 белги)';

  @override
  String get devProfilePaymentKaspiPos => 'Kaspi POS терминалы';

  @override
  String get devParamPrinterIpAddress => 'Тармактык принтердин IP-дареги';

  @override
  String get devParamTcpPort9100 => 'TCP-порт, демейки 9100';

  @override
  String get devParamPrinterDevicePath =>
      'Түзмөк жолу же басып чыгаруу кезегинин аты';

  @override
  String get devParamPrinterMac =>
      'Жупташтырылган Bluetooth принтеринин MAC-дареги';

  @override
  String get devParamPrinterComPort => 'Принтердин ырааттуу порту, мисалы COM4';

  @override
  String get devParamLabelPrinterIp => 'Энбелги принтеринин IP-дареги';

  @override
  String get devParamScannerMac =>
      'Жупташтырылган Bluetooth сканеринин MAC-дареги';

  @override
  String get devParamScannerComPort => 'Сканердин ырааттуу порту, мисалы COM5';

  @override
  String get devParamScaleComPort => 'Таразынын ырааттуу порту, мисалы COM3';

  @override
  String get devParamDrawerComPort =>
      'Кутунун интерфейс тактасынын ырааттуу порту';

  @override
  String get devParamDisplayComPort =>
      'Сатып алуучу дисплейинин ырааттуу порту';

  @override
  String get devParamKaspiIp => 'Kaspi POS терминалынын IP-дареги';

  @override
  String get devParamKaspiPort => 'Терминал порту, адатта 8888';

  @override
  String get devParamCameraId => 'Кайсы камераны колдонуу керек';

  @override
  String get rcpTill => 'Касса';

  @override
  String get rcpTillColon => 'Касса:';

  @override
  String get rcpReceiptNo => 'Чек №';

  @override
  String get rcpCashier => 'Кассир:';

  @override
  String get rcpCustomer => 'Кардар:';

  @override
  String get rcpDate => 'Күнү:';

  @override
  String get rcpBinIin => 'БИН/ЖИН:';

  @override
  String get rcpThankYou => 'Сатып алганыңыз үчүн рахмат!';

  @override
  String get rcpSale => 'САТУУ';

  @override
  String get rcpSubtotal => 'Аралык жыйынтык:';

  @override
  String get rcpDiscount => 'Арзандатуу:';

  @override
  String get rcpServiceFee => 'Кызмат акысы:';

  @override
  String get rcpTotal => 'ЖЫЙЫНТЫГЫ:';

  @override
  String get rcpChange => 'Кайтарым:';

  @override
  String get rcpCash => 'КОЛМО-КОЛ';

  @override
  String get rcpCard => 'КАРТА';

  @override
  String get rcpQuantityShort => 'даана';

  @override
  String get rcpRefund => 'КАЙТАРУУ';

  @override
  String get rcpRefundNo => 'Кайтаруу №';

  @override
  String get rcpSaleReceiptNo => 'Сатуу чеги №';

  @override
  String get rcpDuplicate => '*** КӨЧҮРМӨ ***';

  @override
  String get rcpTable => 'Стол:';

  @override
  String get rcpWaiter => 'Официант:';

  @override
  String get rcpGuests => 'Конактар:';

  @override
  String get rcpFiscalReceipt => 'ФИСКАЛДЫК ЧЕК';

  @override
  String get rcpNonFiscalReceipt => 'ФИСКАЛДЫК ЭМЕС ЧЕК';

  @override
  String get rcpNotFiscalDocument => 'ФИСКАЛДЫК ДОКУМЕНТ ЭМЕС';

  @override
  String get rcpFiscalSign => 'ФИСК. БЕЛГИ:';

  @override
  String get rcpFiscalFn => 'ФЖ:';

  @override
  String get rcpFiscalRnm => 'ТНН:';

  @override
  String get rcpFiscalZnm => 'ЗНН:';

  @override
  String get rcpFiscalTime => 'УБАКЫТ:';

  @override
  String get rcpOfdName => 'ФДО';

  @override
  String get rcpOffline => '*** ОФФЛАЙН ***';

  @override
  String get rcpVerifyAt => 'Чекти текшерүү үчүн кириңиз';

  @override
  String get rcpCustomerTaxId => 'Сатып алуучунун ЖИН:';

  @override
  String get rcpTaxA => 'А САЛЫГЫ БОЮНЧА:';

  @override
  String get rcpFiscalOperatorNotSet => 'Фискалдык оператор жөндөлбөгөн';

  @override
  String get rcpFiscalModuleUnavailable => 'Фискалдаштыруу модулу жеткиликсиз';

  @override
  String get rcpDocumentNotIssued =>
      'Документ таризделген жок — кассирге кайрылыңыз';

  @override
  String get rcpXReport => 'X-ОТЧЁТ';

  @override
  String get rcpZReport => 'Z-ОТЧЁТ';

  @override
  String get rcpInterim => 'АРАЛЫК (өчүрүүсүз)';

  @override
  String get rcpShiftClose => 'СМЕНАНЫ ЖАБУУ';

  @override
  String get rcpShiftStart => 'Башталышы:';

  @override
  String get rcpShiftEnd => 'Аякталышы:';

  @override
  String get rcpSales => 'САТУУЛАР';

  @override
  String get rcpRefunds => 'КАЙТАРУУЛАР';

  @override
  String get rcpCount => 'Саны:';

  @override
  String get rcpAmount => 'Суммасы:';

  @override
  String get rcpCashOps => 'АКЧА ОПЕРАЦИЯЛАРЫ';

  @override
  String get rcpOpeningFloat => 'Башына:';

  @override
  String get rcpSlipTitle => 'КВИТАНЦИЯ';

  @override
  String get rcpType => 'Түрү:';

  @override
  String get rcpComment => 'Комментарий:';

  @override
  String get rcpCashIn => 'Кирим:';

  @override
  String get rcpCashOut => 'Чыгым:';

  @override
  String get rcpTotalInDrawer => 'КАССАДА ЖЫЙЫНТЫГЫ:';

  @override
  String get rcpCertificatesNotRevenue => 'СЕРТИФИКАТТАР (ТҮШҮМ ЭМЕС)';

  @override
  String get rcpCertIssuedDebt => 'Чыгарылды (касса карызы):';

  @override
  String get rcpCertRedeemed => 'Төлөндү (товар менен):';

  @override
  String get rcpGiftCertificate => 'БЕЛЕК СЕРТИФИКАТЫ';

  @override
  String get rcpCertNo => 'Сертификат №';

  @override
  String get rcpCertFaceValue => 'Номиналы:';

  @override
  String get rcpCertValidUntil => 'Жарактуу:';

  @override
  String get rcpCertNoExpiry => 'мөөнөтсүз';

  @override
  String get rcpCertPinSet => 'ПИН коюлган';

  @override
  String get rcpCertIssuedByRefund => 'Кайтаруу менен чыгарылды №';

  @override
  String get rcpCertInsteadOf => 'Сертификаттын ордуна';

  @override
  String get rcpVat => 'КНС';

  @override
  String get rcpSalesTax => 'Сатуудан салык';

  @override
  String get rcpTaxExempt => 'Салык салынбайт';

  @override
  String get rcpTaxExemptMark => 'бош';

  @override
  String get taxSettingsTitle => 'Салыктар';

  @override
  String get taxSettingsSubtitle =>
      'Чендер, юрисдикциялар жана товар категориялары';

  @override
  String get taxSettingsIntro =>
      'Чен бир сан менен берилбейт: ал касса турган юрисдикциялардын үлүштөрүнөн курулат жана товардын категориясы менен күнгө көз каранды. Даяр топтомду алып, кийин оңдоого болот.';

  @override
  String get taxSettingsNotConfigured =>
      'Салык жөндөлгөн эмес: касса нөл эсептейт.';

  @override
  String get taxSettingsPresetSection => 'Даяр топтом';

  @override
  String get taxSettingsCountry => 'Өлкө';

  @override
  String get taxSettingsRegion => 'Штат же облус';

  @override
  String get taxSettingsCity => 'Шаар';

  @override
  String get taxSettingsPreset => 'Топтом';

  @override
  String get taxSettingsApplyPreset => 'Топтомду колдонуу';

  @override
  String get taxSettingsPresetReplaces =>
      'Колдонуу учурдагы жөндөөнү толук алмаштырат. Эки топтомду кошууга болбойт: касса салыкты эки эсе алмак.';

  @override
  String taxSettingsPresetSource(String source) {
    return 'Булак: $source';
  }

  @override
  String taxSettingsPresetValidFrom(String date) {
    return 'Чендер $date тартып колдонулат';
  }

  @override
  String get taxSettingsPresetApplied => 'Топтом колдонулду';

  @override
  String get taxSettingsCurrentSection => 'Учурдагы жөндөө';

  @override
  String taxSettingsRateForStandard(String rate) {
    return 'Кадимки товар: $rate%';
  }

  @override
  String get taxSettingsJurisdictions => 'Юрисдикциялар';

  @override
  String get taxSettingsCategories => 'Товар категориялары';

  @override
  String get taxSettingsTillLocation => 'Касса ушул жерде турат';

  @override
  String get taxSettingsTillLocationHint =>
      'Белги бирден көп болушу мүмкүн: шаар жана атайын райондор. Жогоркулары өзү кошулат.';

  @override
  String get taxSettingsRules => 'Эрежелер';

  @override
  String get taxSettingsRuleTaxed => 'салыкталат';

  @override
  String get taxSettingsRuleZero => 'нөлдүк чен';

  @override
  String get taxSettingsRuleExempt => 'бошотулган';

  @override
  String get taxSettingsAllCategories => 'бардык категориялар';

  @override
  String get taxSettingsAddJurisdiction => 'Юрисдикция кошуу';

  @override
  String get taxSettingsAddCategory => 'Категория кошуу';

  @override
  String get taxSettingsAddRule => 'Эреже кошуу';

  @override
  String get taxSettingsName => 'Аталышы';

  @override
  String get taxSettingsCode => 'Коду';

  @override
  String get taxSettingsRate => 'Чен, %';

  @override
  String get taxSettingsValidFrom => 'Тартып колдонулат';

  @override
  String get taxSettingsParent => 'Жогорку';

  @override
  String get taxSettingsNoParent => 'жок (тамыр)';

  @override
  String get taxSettingsLevel => 'Деңгээл';

  @override
  String get taxSettingsLevelCountry => 'Өлкө';

  @override
  String get taxSettingsLevelState => 'Штат';

  @override
  String get taxSettingsLevelCounty => 'Округ';

  @override
  String get taxSettingsLevelCity => 'Шаар';

  @override
  String get taxSettingsLevelDistrict => 'Атайын район';

  @override
  String get taxSettingsDelete => 'Өчүрүү';

  @override
  String get taxSettingsDeleteJurisdictionWarning =>
      'Аны менен кошо эрежелери жана ички юрисдикциялары өчөт.';

  @override
  String get taxSettingsResponsibility =>
      'Топтомдордогу сандар ачык булактардан алынган жана шилтеме менен аталган. Салыктын туурасына программа эмес, салык төлөөчү жооп берет.';

  @override
  String get taxSettingsNoPresetsForCountry =>
      'Бул өлкө үчүн даяр топтом жок — колмо-кол жөндөңүз.';

  @override
  String get taxSettingsAdd => 'Кошуу';

  @override
  String get taxSettingsCancel => 'Жокко чыгаруу';

  @override
  String get setupStoreAddressHint => 'Абай к., 10, Бишкек';

  @override
  String get setupStoreAddressHelper =>
      'Чекке басылат. Ансыз сатып алуучу сатып алуу кайда жасалганын көрбөйт.';

  @override
  String get countryKz => 'Казакстан';

  @override
  String get countryRu => 'Орусия';

  @override
  String get countryKg => 'Кыргызстан';

  @override
  String get countryUz => 'Өзбекстан';

  @override
  String get countryUs => 'АКШ';

  @override
  String get countryTm => 'Түркмөнстан';

  @override
  String get currencyKzt => 'Казак теңгеси';

  @override
  String get currencyRub => 'Орус рубли';

  @override
  String get currencyKgs => 'Кыргыз сому';

  @override
  String get currencyUzs => 'Өзбек сому';

  @override
  String get currencyUsd => 'АКШ доллары';

  @override
  String get currencyTmt => 'Түркмөн манаты';

  @override
  String get setupStepSalesTax => 'Сатуудан салык';

  @override
  String get setupSalesTaxPayerTitle => 'Сатуудан салык чогултам';

  @override
  String get setupSalesTaxPayerSubtitle =>
      'Чендер «Жөндөөлөр → Салыктар» бөлүмүндө юрисдикция боюнча коюлат';

  @override
  String get setupSalesTaxPayerDescription =>
      'Салык баанын үстүнө кошулат жана чекте өзүнчө сапта басылат.';

  @override
  String get setupSalesTaxNonPayerTitle => 'Сатуудан салыксыз';

  @override
  String get setupSalesTaxNonPayerSubtitle => 'Баага эч нерсе кошулбайт';

  @override
  String get setupSalesTaxNonPayerDescription =>
      'Баага эч нерсе кошулбайт, чекте салык сабы жок.';

  @override
  String get bootLoadingConfig => 'Конфигурацияны жүктөө…';

  @override
  String get bootCheckingPosKey => 'Касса ачкычын текшерүү…';

  @override
  String get bootLoadingAgents => 'Контрагенттерди жүктөө…';

  @override
  String get bootLoadingAccounts => 'Эсептерди жүктөө…';

  @override
  String get bootInitialisingDatabase => 'Маалымат базасын даярдоо…';

  @override
  String get bootLoadingCashiers => 'Кассирлерди жүктөө…';

  @override
  String get bootLoadingPosData => 'Касса маалыматын жүктөө…';

  @override
  String get bootLoadingProducts => 'Товарларды жүктөө…';

  @override
  String get bootCheckingReceiptNumbers => 'Чек номерлөөсүн текшерүү…';

  @override
  String get bootCheckingLicence => 'Лицензияны текшерүү…';

  @override
  String get bootCheckingReports => 'Отчётторду текшерүү…';

  @override
  String get bootFinishingInitialisation => 'Аяктоо…';

  @override
  String get bootStartingBackgroundJobs => 'Фондук тапшырмаларды баштоо…';

  @override
  String get bootReady => 'Даяр';

  @override
  String get bootDataLoaded => 'Маалымат жүктөлдү';

  @override
  String bootTillNotResponding(String code) {
    return 'Касса жооп бербейт: $code';
  }

  @override
  String get bootDownloadingBackup => 'Камдык көчүрмөнү жүктөө…';

  @override
  String get bootBackupDownloadFailed =>
      'Камдык көчүрмөнү жүктөө мүмкүн болбоду';

  @override
  String get bootRestoringDatabase => 'Маалымат базасын калыбына келтирүү…';

  @override
  String get bootDatabaseRestoreFailed =>
      'Маалымат базасын калыбына келтирүү мүмкүн болбоду';

  @override
  String get bootApplyingPosKey => 'Касса ачкычын жөндөө…';

  @override
  String get bootRestoreDone => 'Калыбына келтирүү аяктады';

  @override
  String get bootCreatingBackup => 'Камдык көчүрмө түзүү…';

  @override
  String get bootBackupCreateFailed => 'Камдык көчүрмө түзүү мүмкүн болбоду';

  @override
  String get bootBackupDone => 'Камдык көчүрмө түзүлүп жүктөлдү';

  @override
  String get bootLoadingUsers => 'Колдонуучуларды жүктөө…';

  @override
  String get bootLoadingCategories => 'Категорияларды жүктөө…';

  @override
  String get bootLoadingSettings => 'Жөндөөлөрдү жүктөө…';

  @override
  String get bootSyncDone => 'Синхрондоо аяктады';

  @override
  String get bootFailed => 'Ката';

  @override
  String get countryDeu => 'Германия';

  @override
  String get currencyDeu => 'Евро';

  @override
  String get countryFra => 'Франция';

  @override
  String get currencyFra => 'Евро';

  @override
  String get countryEsp => 'Испания';

  @override
  String get currencyEsp => 'Евро';

  @override
  String get countryIta => 'Италия';

  @override
  String get currencyIta => 'Евро';

  @override
  String get countryGbr => 'Улуу Британия';

  @override
  String get currencyGbr => 'Фунт стерлинг';

  @override
  String get countryPol => 'Польша';

  @override
  String get currencyPol => 'Поляк злотыйы';

  @override
  String get countryTur => 'Түркия';

  @override
  String get currencyTur => 'Түрк лирасы';

  @override
  String get countryChn => 'Кытай';

  @override
  String get currencyChn => 'Кытай юаны';

  @override
  String get countryJpn => 'Япония';

  @override
  String get currencyJpn => 'Жапон иенасы';

  @override
  String get countryKor => 'Түштүк Корея';

  @override
  String get currencyKor => 'Корей вонасы';

  @override
  String get countryAre => 'БАЭ';

  @override
  String get currencyAre => 'БАЭ дирхамы';

  @override
  String get countrySau => 'Сауд Арабиясы';

  @override
  String get currencySau => 'Сауд риялы';

  @override
  String get countryInd => 'Индия';

  @override
  String get currencyInd => 'Инди рупиясы';

  @override
  String get countryCan => 'Канада';

  @override
  String get currencyCan => 'Канада доллары';

  @override
  String get countryAus => 'Австралия';

  @override
  String get currencyAus => 'Австралия доллары';

  @override
  String get agentPaymentAccepted => 'Төлөм кабыл алынды';

  @override
  String get catalogCategoryHasChildren => 'Категорияда ички категориялар бар';

  @override
  String creditOutstanding(String amount) {
    return 'Калды: $amount';
  }

  @override
  String get creditTakePayment => 'Төлөмдү кабыл алуу';

  @override
  String get creditPrintContract => 'Келишимди басып чыгаруу';

  @override
  String creditPaymentFor(String number) {
    return '$number боюнча төлөм';
  }

  @override
  String creditOutstandingOnContract(String amount) {
    return 'Келишим боюнча калды: $amount';
  }

  @override
  String get creditPayInFull => 'Толук төлөө';

  @override
  String get creditAccept => 'Кабыл алуу';

  @override
  String get displayProduct => 'Товар';

  @override
  String markupSaved(int count) {
    return 'Үстөктөр сакталды: $count категория';
  }

  @override
  String genericErrorWith(String detail) {
    return 'Ката: $detail';
  }

  @override
  String get serviceAttachPhoto => 'Фото';

  @override
  String get serviceAttachVideo => 'Видео';

  @override
  String get shiftCorrectionReceipt => 'Оңдоо чеги';

  @override
  String get supplierChoose => 'Жеткирүүчүнү тандаңыз';

  @override
  String get supplierProduct => 'Товар';

  @override
  String get supplierStock => 'Калдык';

  @override
  String get supplierOrderQty => 'Заказ';

  @override
  String get supplierCreateRequest => 'Өтүнмө түзүү';

  @override
  String get supplierNeedQuantity => 'Жок дегенде бир товарга саны керек';

  @override
  String unitMonthsShort(int count) {
    return '$count ай';
  }

  @override
  String unitDaysShort(int count) {
    return '$count күн';
  }

  @override
  String get displayWelcome => 'Кош келиңиз!';

  @override
  String get displayWelcomeSubtitle => 'Сизди көргөнүбүзгө кубанычтуубуз';

  @override
  String get displayPromoFree => 'Акция · акысыз';

  @override
  String displayDiscountAmount(String amount) {
    return 'Арзандатуу −$amount';
  }

  @override
  String get displayWindowTitle => 'Сатып алуучунун экраны';

  @override
  String get shiftXReportPrinted => 'X-отчёт басылды';

  @override
  String get shiftXReportPrintedOffline =>
      'X-отчёт басылды (фискалдык X кезекте, байланыш жок)';

  @override
  String get shiftXReportFailed => 'X-отчётту басып чыгаруу мүмкүн болгон жок';

  @override
  String creditContractNotFound(String number) {
    return '$number келишими кассада жок';
  }

  @override
  String creditOverdue(String amount, int count) {
    return 'МӨӨНӨТҮ ӨТКӨН: $amount ($count төлөм)';
  }

  @override
  String creditNextPayment(String date, String amount) {
    return 'Кийинки төлөм $date: $amount';
  }

  @override
  String get creditNoTillAccount =>
      'Кассанын эсеби жок — акчаны кабыл алар жер жок';

  @override
  String creditContractClosed(String number) {
    return '$number келишими жабылды';
  }

  @override
  String creditPartiallyPaid(String paid, String left) {
    return '$paid кабыл алынды, $left калды';
  }

  @override
  String get creditPaymentAmount => 'Төлөм суммасы';

  @override
  String get serviceWarrantyAndQuality => 'Кепилдик жана сапат';

  @override
  String serviceWarrantyDays(int days) {
    return 'Кепилдик: $days күн';
  }

  @override
  String get serviceWarrantyNotSet => 'Кепилдик коюлган эмес';

  @override
  String get serviceQualityRatingTitle => 'Сапат баасы';

  @override
  String serviceQualityRatingValue(int rating) {
    return 'Баасы: $rating/5';
  }

  @override
  String get serviceRepairMedia => 'Оңдоо фото/видеосу';

  @override
  String get serviceNoRepairMedia => 'Оңдоо медиасы жок';

  @override
  String get supplierLabel => 'Жеткирүүчү:';

  @override
  String supplierLinesToOrder(int count) {
    return 'Заказга позиция: $count';
  }

  @override
  String supplierRequestCreated(int count) {
    return 'Өтүнмө түзүлдү: $count поз.';
  }

  @override
  String get modifierRequired => 'Милдеттүү';

  @override
  String modifierMax(int count) {
    return 'макс. $count';
  }

  @override
  String get writeoffReasonUnspecified => 'Көрсөтүлгөн эмес';

  @override
  String get labelSampleProduct => 'Товар үлгүсү';

  @override
  String markupCategoryNumbered(int id) {
    return 'Категория #$id';
  }

  @override
  String get salePolicyForbids =>
      'Аракетке кассанын жөндөөлөрү уруксат бербейт (Жөндөөлөр → Сатуу саясаты)';

  @override
  String get labelPrintFailed => 'Этикетканы басып чыгаруу катасы';

  @override
  String get labelPrintFromTillOnly =>
      'Этикетка кассадан басылат, терминалдан эмес';

  @override
  String get orphanQrTillNotRegistered =>
      'Касса катталган эмес — QR боюнча аныкталбаган акчаны сурар жер жок';

  @override
  String get stockLowStockReorder => 'Калдыгы аз товарларга кошумча заказ';

  @override
  String get serviceNoteNeedsApproval => 'Кардардын макулдугу керек';

  @override
  String deferredFromTill(String id) {
    return 'касса $id';
  }

  @override
  String dishSummary(int count, String cost) {
    return 'Ингредиент: $count, өздүк наркы: $cost';
  }

  @override
  String prepaymentIssueTo(String name) {
    return 'Сатып алуучуга аванс берүү ($name)';
  }

  @override
  String prepaymentFrom(String name) {
    return 'Сатып алуучунун авансы ($name)';
  }

  @override
  String prepaymentRefundTo(String name) {
    return 'Сатып алуучуга авансты кайтаруу ($name)';
  }

  @override
  String get setupPartOrganization => 'уюм';

  @override
  String get setupPartTill => 'касса';

  @override
  String get setupPartFiscal => 'фискализация';

  @override
  String get setupPartEquipment => 'жабдуу';

  @override
  String get setupPartTerminals => 'төлөм терминалдары';

  @override
  String get setupPartRules => 'эрежелер';

  @override
  String get setupPartUser => 'колдонуучу';

  @override
  String customerPaymentNote(String name) {
    return 'Карызды жабуу / төлөм ($name)';
  }

  @override
  String get chatMembersUnavailable => 'Катышуучулар тизмеси жүктөлгөн жок';

  @override
  String get chatMe => 'Мен';

  @override
  String get setPolicyBigAmountLimit => 'Чек суммасынын чеги';

  @override
  String setPolicyBigAmountLimitDesc(String fallback) {
    return 'Бул суммадан жогору касса уруксат сурайт. Бош — $fallback.';
  }

  @override
  String get cashRefusedNotPositive => 'Сумма нөлдөн чоң болушу керек';

  @override
  String cashRefusedAboveCeiling(String limit) {
    return 'Сумма касса чегинен жогору ($limit). Жөндөөлөрдө чекти көтөрүңүз же чоң суммаларга уруксат бериңиз.';
  }

  @override
  String errorProductHasNoPrice(String name) {
    return '«$name» товарынын баасы жок — сатууга болбойт. Каталогдо баа коюңуз.';
  }

  @override
  String get sellingHoursTitle => 'Сатууга тыюу саат';

  @override
  String get sellingHoursAdd => 'Терезе кошуу';

  @override
  String get sellingHoursCategory => 'Категория';

  @override
  String get sellingHoursFrom => 'Башы (СС:ММ)';

  @override
  String get sellingHoursTo => 'Аягы (СС:ММ)';

  @override
  String get sellingHoursActive => 'Тыюу күчүндө';

  @override
  String sellingHoursBanned(String window) {
    return 'Сатуу тыюу салынган $window';
  }

  @override
  String sellingHoursOff(String window) {
    return '$window терезеси өчүрүлгөн';
  }

  @override
  String sellingHoursBroken(String window) {
    return '«$window» сааттары окулган жок — тыюу иштебейт';
  }

  @override
  String get sellingHoursBadTime => 'Убакыт СС:ММ түрүндө, мисалы 23:00';

  @override
  String sellingHoursPreviewDay(String window) {
    return 'Бир сутка ичинде: $window';
  }

  @override
  String sellingHoursPreviewNight(String window) {
    return 'Түнкү тыюу, түн ортосу аркылуу: $window';
  }

  @override
  String get sellingHoursExplainer =>
      'Сааттарды өзүңүз коёсуз: мыйзам ар өлкөдө башка. Категорияга тыюу анын ичиндегилерге да тиет.';

  @override
  String get sellingHoursNoCategories =>
      'Адегенде каталогдо категория түзүңүз — тыюу категорияга коюлат.';

  @override
  String sellingHoursCategoryGone(int id) {
    return '#$id категориясы өчүрүлгөн';
  }

  @override
  String errorSellingHoursBanned(String category, String window) {
    return '«$category» азыр сатууга болбойт: тыюу $window.';
  }

  @override
  String errorSellingHoursBannedNoWindow(String category) {
    return '«$category» азыр сатууга болбойт.';
  }

  @override
  String get generalSettingsStoreAddress => 'Соода түйнүнүн дареги';

  @override
  String get generalSettingsStoreAddressHint =>
      'Чекте басылат. Дүкөн көчсө, өзгөртүңүз.';
}
