// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Kazakh (`kk`).
class AppLocalizationsKk extends AppLocalizations {
  AppLocalizationsKk([String locale = 'kk']) : super(locale);

  @override
  String get navReports => 'Есептер';

  @override
  String get navStock => 'Қойма';

  @override
  String get appName => 'TelePOS';

  @override
  String get globalOk => 'OK';

  @override
  String get globalCancel => 'Болдырмау';

  @override
  String get globalYes => 'Иә';

  @override
  String get globalNo => 'Жоқ';

  @override
  String get globalSave => 'Сақтау';

  @override
  String get globalNew => 'Новый';

  @override
  String get globalDelete => 'Жою';

  @override
  String get globalEdit => 'Өңдеу';

  @override
  String get globalAdd => 'Қосу';

  @override
  String get globalSearch => 'Іздеу';

  @override
  String get globalClose => 'Жабу';

  @override
  String get globalBack => 'Артқа';

  @override
  String get globalNext => 'Келесі';

  @override
  String get globalDone => 'Дайын';

  @override
  String get globalLoading => 'Жүктелуде...';

  @override
  String get globalError => 'Қате';

  @override
  String get globalSuccess => 'Сәтті';

  @override
  String get globalWarning => 'Ескерту';

  @override
  String get globalInfo => 'Ақпарат';

  @override
  String get globalConfirm => 'Растау';

  @override
  String get globalClear => 'Тазалау';

  @override
  String get globalSelect => 'Таңдау';

  @override
  String get globalAll => 'Барлығы';

  @override
  String get globalNone => 'Жоқ';

  @override
  String get globalTotal => 'Барлығы';

  @override
  String get globalAmount => 'Сома';

  @override
  String get globalQuantity => 'Саны';

  @override
  String get globalPrice => 'Баға';

  @override
  String get globalDiscount => 'Жеңілдік';

  @override
  String get globalDate => 'Күні';

  @override
  String get globalTime => 'Уақыт';

  @override
  String get loginTitle => 'Жүйеге кіру';

  @override
  String get loginPin => 'PIN енгізіңіз';

  @override
  String get loginPinHint => '4 сан';

  @override
  String get loginEnter => 'Кіру';

  @override
  String get loginSelectUser => 'Пайдаланушыны таңдаңыз';

  @override
  String get loginNoUsers => 'Пайдаланушылар жоқ';

  @override
  String get loginWrongPin => 'Қате PIN';

  @override
  String get loginBlocked => 'Пайдаланушы бұғатталған';

  @override
  String get loginSessionExpired => 'Сессия мерзімі өтті';

  @override
  String get loginShiftRequired => 'Кіру үшін ауысымды ашыңыз';

  @override
  String get loginCashier => 'Кассир';

  @override
  String get loginAdmin => 'Әкімші';

  @override
  String get loginManager => 'Менеджер';

  @override
  String get loginLogout => 'Шығу';

  @override
  String get loginSwitchUser => 'Пайдаланушыны ауыстыру';

  @override
  String get saleTitle => 'Сату';

  @override
  String get saleNewSale => 'Жаңа сату';

  @override
  String get saleAddProduct => 'Тауар қосу';

  @override
  String get saleScanBarcode => 'Штрих-кодты сканерлеу';

  @override
  String get saleEnterBarcode => 'Штрих-кодты енгізіңіз';

  @override
  String get saleProductNotFound => 'Тауар табылмады';

  @override
  String get saleEmptyCart => 'Себет бос';

  @override
  String get saleSubtotal => 'Аралық сома';

  @override
  String get saleTax => 'ҚҚС';

  @override
  String get saleTotalDiscount => 'Жеңілдік';

  @override
  String get saleToPay => 'Төлеуге';

  @override
  String saleItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count тауар',
      one: '$count тауар',
    );
    return '$_temp0';
  }

  @override
  String get saleRemoveItem => 'Тауарды жою';

  @override
  String get saleClearCart => 'Себетті тазалау';

  @override
  String get saleConfirmClear => 'Себетті тазалау керек пе?';

  @override
  String get saleProceedPayment => 'Төлемге өту';

  @override
  String get saleHold => 'Кейінге қалдыру';

  @override
  String get saleRecall => 'Қайтару';

  @override
  String get saleHeldSales => 'Кейінге қалдырылған сатулар';

  @override
  String get saleNoHeldSales => 'Кейінге қалдырылған сатулар жоқ';

  @override
  String get saleProductSearch => 'Тауарларды іздеу';

  @override
  String get saleByCategory => 'Санаттар бойынша';

  @override
  String get saleByName => 'Атауы бойынша';

  @override
  String get saleByBarcode => 'Штрих-код бойынша';

  @override
  String get saleWeight => 'Салмақ';

  @override
  String saleWeightKg(String weight) {
    return 'Салмағы: $weight кг';
  }

  @override
  String get saleEnterWeight => 'Салмақты енгізіңіз';

  @override
  String get saleEnterQuantity => 'Санын енгізіңіз';

  @override
  String get saleEnterPrice => 'Бағаны енгізіңіз';

  @override
  String get saleFreePrice => 'Еркін баға';

  @override
  String saleMaxDiscount(String percent) {
    return 'Макс. жеңілдік: $percent%';
  }

  @override
  String get refundTitle => 'Қайтару';

  @override
  String get refundNewRefund => 'Жаңа қайтару';

  @override
  String get refundByReceipt => 'Чек бойынша';

  @override
  String get refundWithoutReceipt => 'Чексіз';

  @override
  String get refundEnterReceipt => 'Чек нөмірін енгізіңіз';

  @override
  String get refundReceiptNotFound => 'Чек табылмады';

  @override
  String get refundSelectItems => 'Қайтаруға тауарларды таңдаңыз';

  @override
  String get refundReason => 'Қайтару себебі';

  @override
  String get refundConfirm => 'Қайтаруды растау';

  @override
  String get refundAmount => 'Қайтару сомасы';

  @override
  String get refundComplete => 'Қайтару орындалды';

  @override
  String get refundCash => 'Қолма-қол қайтару';

  @override
  String get refundCard => 'Картаға қайтару';

  @override
  String get refundNoItems => 'Қайтаруға тауарлар жоқ';

  @override
  String get refundAlreadyRefunded => 'Тауар қайтарылған';

  @override
  String get refundPartial => 'Ішінара қайтару';

  @override
  String get shiftTitle => 'Ауысым';

  @override
  String get shiftOpen => 'Ауысымды ашу';

  @override
  String get shiftClose => 'Ауысымды жабу';

  @override
  String get shiftCurrent => 'Ағымдағы ауысым';

  @override
  String shiftNumber(int number) {
    return 'Ауысым №: $number';
  }

  @override
  String shiftOpenedAt(String time) {
    return 'Ашылған: $time';
  }

  @override
  String shiftCashier(String name) {
    return 'Кассир: $name';
  }

  @override
  String shiftSalesCount(int count) {
    return 'Сатулар: $count';
  }

  @override
  String shiftRefundsCount(int count) {
    return 'Қайтарулар: $count';
  }

  @override
  String get shiftTotalSales => 'Сату сомасы';

  @override
  String get shiftTotalRefunds => 'Қайтару сомасы';

  @override
  String get shiftCashInDrawer => 'Кассада';

  @override
  String get shiftExpected => 'Күтілетін';

  @override
  String get shiftActual => 'Нақты';

  @override
  String get shiftDifference => 'Айырмашылық';

  @override
  String get shiftXReport => 'X-есеп';

  @override
  String get shiftZReport => 'Z-есеп';

  @override
  String get shiftConfirmClose => 'Ауысымды жабу керек пе?';

  @override
  String get shiftAlreadyOpen => 'Ауысым ашық';

  @override
  String get shiftNotOpen => 'Ауысым ашылмаған';

  @override
  String get shiftOpenFirst => 'Алдымен ауысымды ашыңыз';

  @override
  String get paymentTitle => 'Төлем';

  @override
  String get paymentCash => 'Қолма-қол';

  @override
  String get paymentCard => 'Карта';

  @override
  String get paymentKaspi => 'Kaspi QR';

  @override
  String get paymentBonus => 'Бонустар';

  @override
  String get paymentDebt => 'Қарызға';

  @override
  String get paymentMixed => 'Аралас';

  @override
  String get paymentEnterAmount => 'Соманы енгізіңіз';

  @override
  String paymentRemaining(String amount) {
    return 'Қалды: $amount';
  }

  @override
  String paymentChange(String amount) {
    return 'Қайтарым: $amount';
  }

  @override
  String get paymentComplete => 'Төлем аяқталды';

  @override
  String get paymentFailed => 'Төлем қатесі';

  @override
  String get paymentWaitingCard => 'Картаны күту...';

  @override
  String get paymentWaitingQr => 'QR күту...';

  @override
  String get paymentInsertCard => 'Картаны салыңыз';

  @override
  String get paymentScanQr => 'QR сканерлеңіз';

  @override
  String get paymentApproved => 'Мақұлданды';

  @override
  String get paymentDeclined => 'Қабылданбады';

  @override
  String get paymentReceipt => 'Чек басып шығару';

  @override
  String get paymentNoReceipt => 'Чексіз';

  @override
  String get paymentEmail => 'Email-ге жіберу';

  @override
  String get paymentSms => 'SMS жіберу';

  @override
  String get historyTitle => 'Тарих';

  @override
  String get historyToday => 'Бүгін';

  @override
  String get historyYesterday => 'Кеше';

  @override
  String get historyThisWeek => 'Осы апта';

  @override
  String get historyThisMonth => 'Осы ай';

  @override
  String get historyDateRange => 'Кезеңді таңдау';

  @override
  String get historyNoSales => 'Кезеңде сатулар жоқ';

  @override
  String historyReceipt(String number) {
    return 'Чек №$number';
  }

  @override
  String get historyReprint => 'Қайта басып шығару';

  @override
  String get historyDetails => 'Толығырақ';

  @override
  String get historySale => 'Сату';

  @override
  String get historyRefund => 'Қайтару';

  @override
  String get historyFilter => 'Сүзгі';

  @override
  String get agentTitle => 'Контрагенттер';

  @override
  String get agentClients => 'Клиенттер';

  @override
  String get agentSuppliers => 'Жеткізушілер';

  @override
  String get agentSearch => 'Контрагентті іздеу';

  @override
  String get agentAdd => 'Контрагент қосу';

  @override
  String get agentEdit => 'Өңдеу';

  @override
  String get agentName => 'Атауы/Т.А.Ә.';

  @override
  String get agentPhone => 'Телефон';

  @override
  String get agentEmail => 'Email';

  @override
  String get agentIin => 'ЖСН/БСН';

  @override
  String get agentAddress => 'Мекенжай';

  @override
  String get agentBalance => 'Баланс';

  @override
  String get agentBonusBalance => 'Бонус балансы';

  @override
  String get agentDebt => 'Қарыз';

  @override
  String get agentNoAgents => 'Контрагенттер жоқ';

  @override
  String get agentSaveSuccess => 'Контрагент сақталды';

  @override
  String get agentDeleteConfirm => 'Контрагентті жою керек пе?';

  @override
  String get cashTitle => 'Касса';

  @override
  String get cashInvestment => 'Салым';

  @override
  String get cashExpense => 'Төлем';

  @override
  String get cashBalance => 'Касса балансы';

  @override
  String get cashEnterAmount => 'Соманы енгізіңіз';

  @override
  String get cashReason => 'Негіздеме';

  @override
  String get cashReasonPlaceholder => 'Себебін көрсетіңіз';

  @override
  String get cashSuccess => 'Операция орындалды';

  @override
  String get cashExpenseTypes => 'Шығыс түрі';

  @override
  String get cashSalary => 'Жалақы';

  @override
  String get cashRent => 'Жалға алу';

  @override
  String get cashUtilities => 'Коммуналдық';

  @override
  String get cashSupplies => 'Сатып алулар';

  @override
  String get cashOther => 'Басқа';

  @override
  String get discountTitle => 'Жеңілдік';

  @override
  String get discountPercent => 'Пайыз';

  @override
  String get discountFixed => 'Бекітілген';

  @override
  String get discountEnterValue => 'Мәнін енгізіңіз';

  @override
  String get discountApply => 'Қолдану';

  @override
  String get discountRemove => 'Жеңілдікті алып тастау';

  @override
  String get discountOnItem => 'Тауарға жеңілдік';

  @override
  String get discountOnTotal => 'Чекке жеңілдік';

  @override
  String get discountMaxExceeded => 'Максималды жеңілдік асып кетті';

  @override
  String get quickProductTitle => 'Жылдам тауарлар';

  @override
  String get quickProductAdd => 'Тауар қосу';

  @override
  String get quickProductName => 'Атауы';

  @override
  String get quickProductPrice => 'Бағасы';

  @override
  String get quickProductCategory => 'Санаты';

  @override
  String get quickProductSave => 'Сақтау';

  @override
  String get quickProductDelete => 'Жою';

  @override
  String get syncTitle => 'Синхрондау';

  @override
  String get syncStatus => 'Синхрондау күйі';

  @override
  String syncLastSync(String time) {
    return 'Соңғы синхрондау: $time';
  }

  @override
  String get syncNow => 'Синхрондау';

  @override
  String get syncInProgress => 'Синхрондалуда...';

  @override
  String get syncSuccess => 'Синхрондау аяқталды';

  @override
  String get syncFailed => 'Синхрондау қатесі';

  @override
  String get syncProducts => 'Тауарлар';

  @override
  String get syncPrices => 'Бағалар';

  @override
  String get syncAgents => 'Контрагенттер';

  @override
  String get syncSales => 'Сатулар';

  @override
  String syncPending(int count) {
    return 'Жіберуді күтуде: $count';
  }

  @override
  String get syncOffline => 'Байланыс жоқ';

  @override
  String get syncOnline => 'Қосылған';

  @override
  String get printerTitle => 'Принтер';

  @override
  String get printerStatus => 'Принтер күйі';

  @override
  String get printerConnected => 'Қосылған';

  @override
  String get printerDisconnected => 'Ажыратылған';

  @override
  String get printerError => 'Принтер қатесі';

  @override
  String get printerPaperOut => 'Қағаз жоқ';

  @override
  String get printerConnect => 'Қосу';

  @override
  String get printerDisconnect => 'Ажырату';

  @override
  String get printerTest => 'Сынақ басып шығару';

  @override
  String get printerSettings => 'Принтер баптаулары';

  @override
  String get printerWidth => 'Чек ені';

  @override
  String get additionalTitle => 'Қосымша';

  @override
  String get additionalSettings => 'Баптаулар';

  @override
  String get additionalReports => 'Есептер';

  @override
  String get additionalInventory => 'Түгендеу';

  @override
  String get additionalSupply => 'Тауар қабылдау';

  @override
  String get additionalPriceChange => 'Бағаларды өзгерту';

  @override
  String get additionalBackup => 'Сақтық көшірме';

  @override
  String get additionalRestore => 'Қалпына келтіру';

  @override
  String get additionalUpdate => 'Жаңарту';

  @override
  String get additionalAbout => 'Бағдарлама туралы';

  @override
  String get additionalLicense => 'Лицензия';

  @override
  String get additionalSupport => 'Қолдау';

  @override
  String get receiptTitle => 'Чек';

  @override
  String get receiptNumber => 'Чек №';

  @override
  String get receiptDate => 'Күні';

  @override
  String get receiptCashier => 'Кассир';

  @override
  String get receiptItems => 'Тауарлар';

  @override
  String get receiptSubtotal => 'Аралық сома';

  @override
  String get receiptDiscount => 'Жеңілдік';

  @override
  String get receiptTax => 'ҚҚС';

  @override
  String get receiptTotal => 'БАРЛЫҒЫ';

  @override
  String get receiptCash => 'Қолма-қол';

  @override
  String get receiptCard => 'Карта';

  @override
  String get receiptChange => 'Қайтарым';

  @override
  String get receiptThankYou => 'Сатып алғаныңызға рахмет!';

  @override
  String get receiptFiscalNumber => 'Фискалдық нөмір';

  @override
  String get receiptQrCode => 'Тексеру үшін QR';

  @override
  String get receiptCopy => 'Чек көшірмесі';

  @override
  String get errorUnknown => 'Белгісіз қате';

  @override
  String get errorNetwork => 'Желі қатесі';

  @override
  String get errorServer => 'Сервер қатесі';

  @override
  String get errorTimeout => 'Күту уақыты асып кетті';

  @override
  String get errorNotFound => 'Табылмады';

  @override
  String get errorPermission => 'Рұқсат жоқ';

  @override
  String get errorDatabase => 'Деректер базасы қатесі';

  @override
  String get errorValidation => 'Валидация қатесі';

  @override
  String get errorRequired => 'Міндетті өріс';

  @override
  String get errorInvalidFormat => 'Қате формат';

  @override
  String errorMinLength(int min) {
    return 'Ең аз $min символ';
  }

  @override
  String errorMaxLength(int max) {
    return 'Ең көп $max символ';
  }

  @override
  String errorMinValue(String min) {
    return 'Ең аз $min';
  }

  @override
  String errorMaxValue(String max) {
    return 'Ең көп $max';
  }

  @override
  String get errorPrinter => 'Принтер қатесі';

  @override
  String get errorFiscal => 'Фискализация қатесі';

  @override
  String get errorPayment => 'Төлем қатесі';

  @override
  String get errorSync => 'Синхрондау қатесі';

  @override
  String get errorNoInternet => 'Интернет байланысы жоқ';

  @override
  String get errorTryAgain => 'Қайталап көріңіз';

  @override
  String get helpTitle => 'Анықтама';

  @override
  String get helpTips => 'Кеңестер';

  @override
  String get helpShortcuts => 'Ыстық пернелер';

  @override
  String get helpRelatedScreens => 'Байланысты бөлімдер';

  @override
  String get helpKey => 'Перне';

  @override
  String get helpAction => 'Әрекет';

  @override
  String get navSale => 'Сату';

  @override
  String get navRefund => 'Қайтару';

  @override
  String get navShift => 'Ауысым';

  @override
  String get navHistory => 'Тарих';

  @override
  String get navTables => 'Үстелдер';

  @override
  String get navOrders => 'Тапсырыстар';

  @override
  String get navQueue => 'Кезек';

  @override
  String get navIntake => 'Қабылдау';

  @override
  String get navAgents => 'Контрагенттер';

  @override
  String get navSupply => 'Қабылдау';

  @override
  String get navCash => 'Касса';

  @override
  String get navSettings => 'Баптаулар';

  @override
  String get navSync => 'Синхрондау';

  @override
  String get navMore => 'Тағы да';

  @override
  String get navAdditional => 'Қосымша';

  @override
  String get navLockScreen => 'Құлыптау';

  @override
  String get navMain => 'Негізгі';

  @override
  String get loginEnterSystem => 'Жүйеге кіру';

  @override
  String get loginWithoutPin => 'PIN-сіз кіру';

  @override
  String get loginShiftOpen => 'Ауысым ашық';

  @override
  String get loginShiftClosed => 'Ауысым жабық';

  @override
  String get saleQuickProducts => 'Жылдам тауарлар';

  @override
  String get saleIncrease => 'Көбейту';

  @override
  String get saleDecrease => 'Азайту';

  @override
  String get saleMark => 'Маркировка';

  @override
  String get saleDataMatrix => 'Маркировка (DataMatrix)';

  @override
  String get saleHeld => 'Чек кейінге қалдырылды';

  @override
  String get saleNoDeferredSales => 'Нет отложенных чеков';

  @override
  String get saleReceiptNo => 'Чек №';

  @override
  String get salePositions => 'Тауарлар';

  @override
  String get saleSearchHint => 'Тауар іздеу (атау немесе штрих-код)';

  @override
  String get refundWithReceipt => 'ЧЕКПЕН';

  @override
  String get refundWithoutReceiptUpper => 'ЧЕКСІЗ';

  @override
  String get refundLoadReceipt => 'Чекті жүктеу';

  @override
  String get refundSearchProducts => 'Тауарларды іздеу';

  @override
  String get refundSelectAll => 'Барлығын таңдау';

  @override
  String get refundDeselectAll => 'Барлығын алу';

  @override
  String refundMaxQuantity(String max) {
    return 'Максимум: $max';
  }

  @override
  String get refundConfirmTitle => 'Қайтаруды растаңыз';

  @override
  String refundSelectedItems(int count) {
    return 'Таңдалған позициялар: $count';
  }

  @override
  String get refundSuccessMsg => 'Қайтару сәтті жүргізілді';

  @override
  String get refundSearchHint => 'Қайтару үшін тауар іздеу';

  @override
  String get paymentRefundTitle => 'Қайтару';

  @override
  String get paymentPayTitle => 'Төлем';

  @override
  String get paymentRefundBtn => 'ҚАЙТАРУ';

  @override
  String get paymentPayBtn => 'ТӨЛЕУ';

  @override
  String get paymentChangeLabel => 'Қайтарым:';

  @override
  String get paymentSuccessRefund => 'Қайтару жүргізілді';

  @override
  String get paymentSuccessPay => 'Төлем сәтті';

  @override
  String get paymentCardType => 'Қолма-қолсыз';

  @override
  String get paymentToPay => 'Төлеуге';

  @override
  String get paymentBonusLabel => 'Бонустар';

  @override
  String get paymentTotalToPay => 'Жалпы төлеу';

  @override
  String get paymentByCard => 'Картамен';

  @override
  String get paymentRemainLabel => 'Қалды';

  @override
  String get shiftBills => 'Купюралар';

  @override
  String get shiftTotalAmount => 'Жалпы сома';

  @override
  String get shiftOperations => 'Операциялар';

  @override
  String get shiftOpened => 'Ауысым ашылды';

  @override
  String get shiftClosed => 'Ауысым жабылды';

  @override
  String get shiftOverAgeTitle => 'Смена открыта более 24 часов';

  @override
  String get shiftOverAgeMessage =>
      'Продажа заблокирована. Закройте текущую смену и откройте новую, чтобы продолжить работу.';

  @override
  String shiftSince(String time) {
    return '$time бастап';
  }

  @override
  String get shiftSystem => 'Жүйе';

  @override
  String get shiftEntered => 'Енгізілді';

  @override
  String get shiftRecounting => 'Купюралар бойынша қайта есептеу';

  @override
  String get shiftManualEntry => 'Қолмен сома енгізу';

  @override
  String get shiftCashOps => 'Касса операциялары';

  @override
  String get shiftOpenAction => 'Ауысымды ашу';

  @override
  String get shiftCloseAction => 'Ауысымды жабу';

  @override
  String get historyOperations => 'Операциялар тарихы';

  @override
  String get historyResetFilters => 'Сүзгілерді тастау';

  @override
  String get historyRefresh => 'Жаңарту';

  @override
  String get historyNoRecords => 'Жазбалар жоқ';

  @override
  String get historyChangeFilters => 'Сүзгілерді өзгертіп көріңіз';

  @override
  String get historyEmpty => 'Операциялар тарихы бос';

  @override
  String get historyFilterTitle => 'Сүзгілер';

  @override
  String get historyPeriod => 'Кезең';

  @override
  String get historyOpType => 'Операция түрі';

  @override
  String get historySearchHint => 'Чек нөмірі, сома...';

  @override
  String historyType(String type) {
    return 'Түрі:';
  }

  @override
  String get historyPrint => 'Чекті басып шығару';

  @override
  String agentFound(int count) {
    return 'Табылды: $count';
  }

  @override
  String get agentWithDebt => 'Тек қарызы бар';

  @override
  String get agentSearchHint => 'Аты немесе телефоны бойынша іздеу...';

  @override
  String get agentNewClient => 'Жаңа клиент';

  @override
  String get agentNameRequired => 'Аты *';

  @override
  String get agentEnterName => 'Клиент атын енгізіңіз';

  @override
  String get agentPhoneLabel => 'Телефон';

  @override
  String get agentIinLabel => 'БИН/ЖСН';

  @override
  String get agentIinHint => '12 сан';

  @override
  String get agentDeleteQuestion => 'Клиентті жоюу?';

  @override
  String agentDeleteConfirmMsg(String name) {
    return '$name жоюға сенімдісіз бе?';
  }

  @override
  String get agentDeleted => 'Клиент жойылды';

  @override
  String get agentFoundExisting => 'Клиент табылды';

  @override
  String get supplyTitle => 'Тауарды қабылдау';

  @override
  String get supplySaved => 'Қабылдау сақталды';

  @override
  String get supplySaveError => 'Сақтау қатесі';

  @override
  String get supplyCancelQuestion => 'Қабылдауды бас тарту?';

  @override
  String get supplyDataLost => 'Барлық енгізілген деректер жоғалады.';

  @override
  String supplyProducts(int count) {
    return 'Тауарлар: $count';
  }

  @override
  String get supplyBarcodeHint => 'Штрих-код немесе артикул';

  @override
  String get supplyComment => 'Пікір';

  @override
  String get supplyCommentHint => 'Пікір жазыңыз...';

  @override
  String get supplyNotFound => 'Тауар табылмады';

  @override
  String get supplySelectSupplier => 'Жеткізушіні таңдаңыз';

  @override
  String get supplySelectAccount => 'Шотты таңдаңыз';

  @override
  String supplyBalance(String amount) {
    return 'Баланс: $amount';
  }

  @override
  String get supplyPurchasePrice => 'Келу бағасы';

  @override
  String get supplySerialNumbers => 'Сериялық нөмірлер';

  @override
  String get supplySerialHint => 'S/N енгізіңіз немесе сканерлеңіз';

  @override
  String supplySerialCount(int count, int expected) {
    return '$expected ішінен $count';
  }

  @override
  String get supplySerialMismatch =>
      'Сериялық нөмірлер саны санға сәйкес келмейді';

  @override
  String get supplyInvalidQty => 'Дұрыс санды енгізіңіз';

  @override
  String get supplyInvalidPrice => 'Дұрыс бағаны енгізіңіз';

  @override
  String get inventoryTitle => 'Инвентаризация';

  @override
  String get inventoryFullCount => 'Полная инвентаризация';

  @override
  String get inventoryFullCountSubtitle =>
      'Обнулить остатки непросканированных товаров';

  @override
  String get inventoryStart => 'Бастау';

  @override
  String get inventoryFinish => 'Аяқтау';

  @override
  String get inventoryScanHint => 'Штрих-кодты сканерлеңіз';

  @override
  String get inventoryScanProducts => 'Тауарларды санау үшін сканерлеңіз';

  @override
  String get inventoryPressStart => 'Инвентаризация үшін \"Бастау\" басыңыз';

  @override
  String inventoryProductCount(int count) {
    return 'Тауарлар: $count';
  }

  @override
  String inventoryDiscrepancies(int count) {
    return 'Алшақтықтар: $count';
  }

  @override
  String get inventoryExpected => 'Күтілді:';

  @override
  String get inventoryActual => 'Факт:';

  @override
  String get inventoryProduct => 'Тауар';

  @override
  String get inventoryExpectedQty => 'Күтілетін';

  @override
  String get inventoryActualQty => 'Нақты';

  @override
  String get inventoryDiscrepancy => 'Алшақтық';

  @override
  String get inventoryActualLabel => 'Нақты саны';

  @override
  String get inventoryFinishQuestion => 'Инвентаризацияны аяқтау?';

  @override
  String get inventoryCompleted => 'Инвентаризация аяқталды';

  @override
  String get writeoffTitle => 'Есептен шығару';

  @override
  String get writeoffReason => 'Себеп';

  @override
  String get writeoffProduct => 'Тауар';

  @override
  String get writeoffScanHint => 'Штрих-кодты сканерлеңіз';

  @override
  String get writeoffCommentHint => 'Міндетті емес';

  @override
  String get writeoffReasonBreakage => 'Сыну';

  @override
  String get writeoffReasonExpired => 'Мерзімі өткен';

  @override
  String get writeoffReasonDamage => 'Бүліну';

  @override
  String get writeoffReasonLoss => 'Жоғалу';

  @override
  String get writeoffReasonOther => 'Басқа';

  @override
  String get writeoffCancelQuestion => 'Есептен шығаруды бас тарту?';

  @override
  String get writeoffSaved => 'Есептен шығару сақталды';

  @override
  String get settingsTitle => 'Баптаулар';

  @override
  String get settingsPosInfo => 'Касса ақпараты';

  @override
  String get settingsPosName => 'Касса атауы';

  @override
  String get settingsCompany => 'Компания';

  @override
  String get settingsIin => 'ЖСН/БИН';

  @override
  String get settingsPosId => 'POS ID';

  @override
  String get settingsStoreId => 'Дүкен ID';

  @override
  String get settingsNotSpecified => 'Көрсетілмеген';

  @override
  String get settingsAppVersion => 'Қолданба нұсқасы';

  @override
  String get settingsVersion => 'Нұсқа';

  @override
  String get settingsPlatform => 'Платформа';

  @override
  String get settingsLanguage => 'Интерфейс тілі';

  @override
  String get settingsLanguageChanged => 'Тіл өзгертілді';

  @override
  String get settingsCurrency => 'Валюта';

  @override
  String get settingsCurrencySymbol => 'Белгі';

  @override
  String get settingsCurrencyCode => 'Код';

  @override
  String get settingsCountry => 'Ел';

  @override
  String get settingsAdditional => 'Қосымша баптаулар';

  @override
  String get settingsTransport => 'Көлік';

  @override
  String get settingsTransportDesc => 'Деректерді синхрондау баптаулары';

  @override
  String get settingsPrinter => 'Принтер';

  @override
  String get settingsPrinterDesc => 'Чектерді басып шығару баптаулары';

  @override
  String get settingsFiscal => 'Фискализация';

  @override
  String get settingsFiscalDesc => 'WebKassa, ОФД, ҚҚС';

  @override
  String get settingsTelegram => 'Telegram';

  @override
  String get settingsTelegramDesc => 'Telegram интеграциясы және арналар';

  @override
  String get settingsPermissions => 'Рұқсаттар';

  @override
  String get settingsPermissionsDesc => 'Кассирлерге рұқсаттар';

  @override
  String get fiscalTitle => 'Фискализация';

  @override
  String get fiscalOperator => 'Фискалдық оператор';

  @override
  String get fiscalWebkassa => 'WebKassa баптаулары';

  @override
  String get fiscalTaxpayer => 'Салық төлеуші деректері';

  @override
  String get fiscalVatSettings => 'ҚҚС баптаулары';

  @override
  String get fiscalVatPayer => 'ҚҚС төлеуші';

  @override
  String get fiscalPrintVat => 'Чекте ҚҚС басу';

  @override
  String get fiscalSaved => 'Баптаулар сақталды';

  @override
  String get fiscalSaveError => 'Сақтау қатесі';

  @override
  String get printerSettingsTitle => 'Принтер баптаулары';

  @override
  String get printerConnectionType => 'Қосылу түрі';

  @override
  String get printerAddress => 'Принтер мекенжайы';

  @override
  String get printerPaperWidth => 'Қағаз ені';

  @override
  String get printerTesting => 'Тестілеу';

  @override
  String get printerReady => 'Дайын';

  @override
  String get printerNotConnected => 'Қосылмаған';

  @override
  String get printerPaperOut2 => 'Қағаз жоқ';

  @override
  String get printerCoverOpen => 'Қақпағы ашық';

  @override
  String get printerPrinting => 'Басып шығару...';

  @override
  String get printerCheckStatus => 'Тексеру...';

  @override
  String get printerPrintSuccess => 'Басып шығару сәтті';

  @override
  String get printerPrintError => 'Басып шығару қатесі';

  @override
  String get printerCheckBtn => 'Тексеру';

  @override
  String get printerTestReceipt => 'Тестілік чек';

  @override
  String get printerPort => 'Порт';

  @override
  String get cashOperationTitle => 'Касса операциясы';

  @override
  String get cashWithdrawal => 'Алу';

  @override
  String get cashCommentRequired => 'Пікір *';

  @override
  String get cashCommentOptional => 'Пікір';

  @override
  String get cashCommentHint => 'Пікір жазыңыз...';

  @override
  String get cashEnterAmountMsg => 'Соманы енгізіңіз';

  @override
  String get cashPositiveOnly => 'Сома оң болуы керек';

  @override
  String get cashInsufficient => 'Кассада ақша жеткіліксіз';

  @override
  String get cashInvalidAmount => 'Дұрыс соманы енгізіңіз';

  @override
  String get cashInDrawer => 'Кассада:';

  @override
  String get telegramTitle => 'Telegram баптаулары';

  @override
  String get telegramAuth => 'Авторизация';

  @override
  String get telegramSync => 'Синхрондау';

  @override
  String get telegramNotifications => 'Хабарландыруларды қосу';

  @override
  String get telegramAutoSync => 'Автосинхрондау';

  @override
  String get telegramSyncData => 'Деректерді автоматты синхрондау';

  @override
  String get telegramSyncInterval => 'Синхрондау аралығы';

  @override
  String get telegramForceSync => 'Мәжбүрлі синхрондау';

  @override
  String get telegramFullSync => 'Толық синхрондау';

  @override
  String get telegramRecreateChannels => 'Арналарды қайта құру';

  @override
  String get telegramLogout => 'Telegram-нен шығу';

  @override
  String get telegramSyncComplete => 'Синхрондау аяқталды';

  @override
  String get telegramSyncError => 'Синхрондау қатесі';

  @override
  String get telegramLogoutComplete => 'Шығу орындалды';

  @override
  String get chatTitle => 'Қызметкерлер чаты';

  @override
  String chatParticipants(int count) {
    return '$count қатысушы';
  }

  @override
  String get chatConnected => 'Қосылды';

  @override
  String get chatDisconnected => 'Байланыс жоқ';

  @override
  String get chatNoMessages => 'Хабарламалар жоқ';

  @override
  String get chatStartConversation => 'Команда мүшелерімен сөйлесіңіз';

  @override
  String get chatMessageHint => 'Хабарлама...';

  @override
  String get chatSearch => 'Іздеу';

  @override
  String get chatSearchHint => 'Іздеу мәтінін енгізіңіз...';

  @override
  String get chatMembers => 'Қатысушылар';

  @override
  String get chatLinkTelegram => 'Telegram байлау';

  @override
  String get chatCopied => 'Көшірілді';

  @override
  String get chatReply => 'Жауап беру';

  @override
  String get chatCopy => 'Көшіру';

  @override
  String get chatDeleteMsg => 'Хабарламаны жою?';

  @override
  String get chatDeleteConfirm => 'Хабарлама барлық қатысушылар үшін жойылады.';

  @override
  String get chatPhoto => 'Фото';

  @override
  String get chatDocument => 'Құжат';

  @override
  String get chatLocation => 'Орналасу';

  @override
  String get chatCamera => 'Камера';

  @override
  String get chatGallery => 'Галерея';

  @override
  String get chatSelectSource => 'Көзді таңдаңыз';

  @override
  String get updateAvailable => 'Жаңарту қолжетімді';

  @override
  String get updateInProgress => 'Жаңартылуда...';

  @override
  String updateAutoIn(int seconds) {
    return 'Автожаңарту $seconds сек кейін';
  }

  @override
  String get updateNowBtn => 'Қазір жаңарту';

  @override
  String get updateLater => 'Кейін';

  @override
  String get updateSkip => 'Өткізу';

  @override
  String get updateBtn => 'Жаңарту';

  @override
  String get storageWarningTitle => 'Дискте орын аз';

  @override
  String get storageWarningMsg =>
      'Кассаның тұрақты жұмысы үшін кемінде 2 ГБ босатыңыз.';

  @override
  String get storageUnderstood => 'Түсінікті';

  @override
  String get errorCritical => 'Сыни қате';

  @override
  String get errorAppProblem => 'Қолданба мәселеге тап болды';

  @override
  String get errorDescription => 'Қате сипаттамасы:';

  @override
  String get errorTechnical => 'Техникалық мәліметтер';

  @override
  String get errorRetry => 'Қайталау';

  @override
  String get errorOpenFolder => 'Қалтаны ашу';

  @override
  String get errorOtherVersion => 'Басқа нұсқа';

  @override
  String get errorExit => 'Шығу';

  @override
  String get switchOn => 'Қосу';

  @override
  String get switchOff => 'Өшіру';

  @override
  String get keyboardSpace => 'Бос орын';

  @override
  String get keyboardHide => 'Пернетақтаны жасыру';

  @override
  String get keyboardShow => 'Пернетақтаны көрсету';

  @override
  String get commentReceipt => 'Чекке пікір';

  @override
  String get commentReceiptHint => 'Пікір жазыңыз...';

  @override
  String get productNameLabel => 'Тауар атауы';

  @override
  String get productNameHint => 'Атауын енгізіңіз...';

  @override
  String get nothingFound => 'Ештеңе табылмады';

  @override
  String get datePlaceholder => 'КК.АА.ЖЖЖЖ';

  @override
  String get timePlaceholder => 'СС:ММ';

  @override
  String get dateTimePlaceholder => 'КК.АА.ЖЖЖЖ СС:ММ';

  @override
  String get selectPeriod => 'Кезеңді таңдаңыз';

  @override
  String get bonusProgram => 'Бонус бағдарламасы';

  @override
  String get enterPhone => 'Клиенттің телефон нөмірін енгізіңіз';

  @override
  String get enterSmsCode => 'SMS-тен кодты енгізіңіз';

  @override
  String resendIn(int seconds) {
    return '$seconds сек кейін қайта жіберу';
  }

  @override
  String get resendCode => 'Кодты қайта жіберу';

  @override
  String get availableBonuses => 'Қолжетімді бонустар:';

  @override
  String get useBonuses => 'Бонустарды есептен шығару';

  @override
  String get deferredSales => 'Кейінге қалдырылған сатулар';

  @override
  String get noDeferredSales => 'Кейінге қалдырылған сатулар жоқ';

  @override
  String get fiscalErrors => 'Фискализация қателері';

  @override
  String get selectAllErrors => 'Барлығын таңдау';

  @override
  String get retrySelected => 'Қайталау';

  @override
  String receiptNo(String number) {
    return 'Чек №$number';
  }

  @override
  String get dontAskAgain => 'Қайта сұрамау';

  @override
  String get deleteTitle => 'Жою';

  @override
  String deleteItemConfirm(String name) {
    return '\"$name\" жоюға сенімдісіз бе?';
  }

  @override
  String get exitTitle => 'Шығу';

  @override
  String get exitConfirm => 'Шығуға сенімдісіз бе?';

  @override
  String get exitBtn => 'Шығу';

  @override
  String get valueCannotBeNegative => 'Мән теріс болуы мүмкін емес';

  @override
  String maxPercent(int percent) {
    return 'Максимум $percent%';
  }

  @override
  String maxAmount(String amount) {
    return 'Максимум $amount';
  }

  @override
  String get enterValidNumber => 'Дұрыс санды енгізіңіз';

  @override
  String get discountAmount => 'Жеңілдік сомасы:';

  @override
  String get sumLabel => 'Сома';

  @override
  String get enterAmount => 'Соманы енгізіңіз';

  @override
  String get amountMustBePositive => 'Сома оң болуы керек';

  @override
  String get notEnoughCashInDrawer => 'Кассада ақша жеткіліксіз';

  @override
  String get enterValidAmount => 'Дұрыс соманы енгізіңіз';

  @override
  String get inDrawer => 'Кассада:';

  @override
  String get commentOptional => 'Пікір (міндетті емес)';

  @override
  String get operationReason => 'Операция себебі...';

  @override
  String get positions => 'позициялар';

  @override
  String get enterWeight => 'Салмақты енгізіңіз';

  @override
  String get weightMustBePositive => 'Салмақ оң болуы керек';

  @override
  String maxWeightValue(String max, String unit) {
    return 'Максимум $max $unit';
  }

  @override
  String get unitPcs => 'дана';

  @override
  String get unitKg => 'кг';

  @override
  String lowStorageTooltip(String gb) {
    return 'Орын аз: $gb GB';
  }

  @override
  String storageFree(String gb) {
    return 'Бос: $gb GB';
  }

  @override
  String get storageRecommendation =>
      'Кассаның тұрақты жұмысы үшін кемінде 2 GB бос орын ұсынылады.\n\nДискте орын босатыңыз немесе әкімшіге хабарласыңыз.';

  @override
  String lowStorageBanner(String gb) {
    return 'Бос орын аз: $gb GB. Тұрақты жұмыс үшін кемінде 2 GB босату ұсынылады.';
  }

  @override
  String lowStorageTooltipShort(String gb) {
    return 'Дискте орын аз: $gb GB';
  }

  @override
  String get cashier => 'Кассир:';

  @override
  String get buyer => 'Сатып алушы:';

  @override
  String receiptHeader(int number) {
    return 'ЧЕК #$number';
  }

  @override
  String get receiptDiscountItem => 'Жеңілдік:';

  @override
  String get receiptSubtotalLabel => 'Аралық сома';

  @override
  String get receiptPayment => 'Төлем:';

  @override
  String get fiscalMark => 'ФБ:';

  @override
  String remainingStock(String qty) {
    return 'Қалд: $qty';
  }

  @override
  String get tableHeaderName => 'Атауы';

  @override
  String get tableHeaderPrice => 'Бағасы';

  @override
  String get tableHeaderQty => 'Саны';

  @override
  String get tableHeaderTotal => 'Барлығы';

  @override
  String get emptyReceipt => 'Чек бос';

  @override
  String get addProductsViaSearch =>
      'Іздеу арқылы тауар қосыңыз\nнемесе штрих-кодты сканерлеңіз';

  @override
  String get addProductsViaSearchShort => 'Іздеу арқылы тауар қосыңыз';

  @override
  String get priceLabel => 'Бағасы';

  @override
  String get receiptTotalLabel => 'Чек бойынша барлығы';

  @override
  String get positionsLabel => 'Позициялар';

  @override
  String get toPayLabel => 'ТӨЛЕУГЕ';

  @override
  String get payBtn => 'ТӨЛЕУ';

  @override
  String get totalLabel => 'Барлығы:';

  @override
  String posAndQty(int positions, String qty) {
    return '$positions поз. / $qty дана';
  }

  @override
  String get modeRetail => 'Бөлшек';

  @override
  String get modeWholesale => 'КӨТЕРМЕ';

  @override
  String get quickProducts => 'Жылдам тауарлар';

  @override
  String get editProduct => 'Өңдеу';

  @override
  String get labelComment => 'Пікір';

  @override
  String get selectPackage => 'Фасовканы таңдаңыз';

  @override
  String packageQty(String qty) {
    return '$qty дана';
  }

  @override
  String get allBreadcrumb => 'Барлығы';

  @override
  String productPrice(String price) {
    return '$price ₸';
  }

  @override
  String maxBonusPercent(int percent) {
    return 'Чек сомасының $percent%-на дейін есептен шығаруға болады';
  }

  @override
  String get insufficientBonuses => 'Бонустар жеткіліксіз';

  @override
  String get enterValidPhone => 'Дұрыс телефон нөмірін енгізіңіз';

  @override
  String errorsCount(int count) {
    return '$count қате';
  }

  @override
  String selectAllCount(int count) {
    return 'Барлығын таңдау ($count)';
  }

  @override
  String retryCount(int count) {
    return 'Қайталау ($count)';
  }

  @override
  String receiptHash(int number) {
    return 'Чек #$number';
  }

  @override
  String get enterIntegerNumber => 'Бүтін санды енгізіңіз';

  @override
  String enterDigits(int length) {
    return '$length сан енгізіңіз';
  }

  @override
  String get drawerPrimary => 'Негізгі';

  @override
  String get drawerSecondary => 'Қосымша';

  @override
  String get tooltipMore => 'Тағы да';

  @override
  String get statusOnline => 'Online';

  @override
  String get statusOffline => 'Offline';

  @override
  String get statusSyncing => 'Синхрондау...';

  @override
  String get thankYouForPurchase => 'Сатып алғаныңызға рахмет!';

  @override
  String get searchProductHint => 'Тауар іздеу (атау немесе штрих-код)';

  @override
  String get actionDefer => 'Кейінге қалдыру';

  @override
  String get actionDeferredList => 'Отложенные';

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
  String get actionIncrease => 'Көбейту';

  @override
  String get actionDecrease => 'Азайту';

  @override
  String get restaurantSettings => 'Мейрамхана режимі';

  @override
  String get restaurantSettingsDesc => 'Үстелдер, аймақтар, сервис алымы';

  @override
  String get restaurantOperatingMode => 'Жұмыс режимі';

  @override
  String get restaurantModeRetail => 'Бөлшек сауда';

  @override
  String get restaurantModeRetailDesc => 'Дүкендерге арналған стандартты POS';

  @override
  String get restaurantModeRestaurant => 'Мейрамхана';

  @override
  String get restaurantModeRestaurantDesc =>
      'Үстелдер, тапсырыстар, сервис алымы';

  @override
  String get restaurantModeService => 'Сервис';

  @override
  String get restaurantModeServiceDesc => 'Өтінімдерді қабылдау, кезек';

  @override
  String get restaurantZoneManagement => 'Аймақтарды басқару';

  @override
  String get restaurantZoneAdd => 'Аймақ қосу';

  @override
  String get restaurantZoneRename => 'Атын өзгерту';

  @override
  String get restaurantZonePresets => 'Алдын ала орнату';

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
  String get restaurantZonePrivate => 'Жеке бөлме';

  @override
  String get restaurantTableManagement => 'Үстелдерді басқару';

  @override
  String get restaurantTableAdd => 'Үстел қосу';

  @override
  String get restaurantTableEdit => 'Үстелді өзгерту';

  @override
  String get restaurantTableName => 'Үстел атауы';

  @override
  String get restaurantTableCapacity => 'Сыйымдылық';

  @override
  String get restaurantTableZone => 'Аймақ';

  @override
  String get restaurantTableSortOrder => 'Реттілік';

  @override
  String get restaurantTableDeactivate => 'Үстелді өшіру';

  @override
  String restaurantTableDeactivateConfirm(String name) {
    return '«$name» үстелін өшіру керек пе?';
  }

  @override
  String get restaurantServiceCharge => 'Сервис алымы';

  @override
  String get restaurantServiceChargeEnabled => 'Сервис алымын қосу';

  @override
  String get restaurantServiceChargePercent => 'Сервис алымы пайызы';

  @override
  String get restaurantTableFree => 'Бос';

  @override
  String get restaurantTableOccupied => 'Бос емес';

  @override
  String get restaurantTableReserved => 'Брондалған';

  @override
  String get restaurantTableDirty => 'Жинау';

  @override
  String get restaurantOrderDineIn => 'Залда';

  @override
  String get restaurantOrderTakeout => 'Алып кету';

  @override
  String get restaurantOrderDelivery => 'Жеткізу';

  @override
  String get restaurantAllZones => 'Барлық аймақтар';

  @override
  String get restaurantNoTables => 'Үстелдер жоқ';

  @override
  String get restaurantNoTablesHint =>
      'Мейрамхана параметрлерінде үстелдер қосыңыз';

  @override
  String get restaurantGoToSettings => 'Параметрлерге өту';

  @override
  String get restaurantOrdersEmpty => 'Белсенді тапсырыстар жоқ';

  @override
  String restaurantOrderItems(int count) {
    return '$count позиция';
  }

  @override
  String restaurantOrderGuests(int count) {
    return 'Қонақтар: $count';
  }

  @override
  String restaurantOrderWaiter(String name) {
    return 'Даяшы: $name';
  }

  @override
  String restaurantOrderElapsed(int minutes) {
    return '$minutes мин';
  }

  @override
  String get restaurantNoOrder => 'Белсенді тапсырыс жоқ';

  @override
  String get restaurantOpenOrder => 'Тапсырыс ашу';

  @override
  String get restaurantCloseOrder => 'Тапсырысты жабу';

  @override
  String get restaurantAddItems => 'Позиция қосу';

  @override
  String get restaurantGoToPayment => 'Төлемге';

  @override
  String get restaurantTransfer => 'Ауыстыру';

  @override
  String get restaurantSplitBill => 'Бөлу';

  @override
  String get restaurantChangeStatus => 'Мәртебені өзгерту';

  @override
  String get restaurantSetFree => 'Бос';

  @override
  String get restaurantSetReserved => 'Брондау';

  @override
  String get restaurantSetDirty => 'Жинау қажет';

  @override
  String get restaurantCreateOrder => 'Жаңа тапсырыс';

  @override
  String get restaurantPartySize => 'Қонақтар саны';

  @override
  String get restaurantOrderType => 'Тапсырыс түрі';

  @override
  String get restaurantWaiter => 'Даяшы';

  @override
  String get restaurantNote => 'Ескертпе';

  @override
  String get restaurantDeliveryAddress => 'Жеткізу мекенжайы';

  @override
  String get restaurantDeliveryPhone => 'Телефон';

  @override
  String get restaurantTransferTitle => 'Тапсырысты ауыстыру';

  @override
  String restaurantTransferCurrent(String table) {
    return 'Ағымдағы: $table';
  }

  @override
  String get restaurantTransferSelectFree => 'Бос үстелді таңдаңыз:';

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
  String get restaurantSplitTitle => 'Шотты бөлу';

  @override
  String get restaurantSplitEvenly => 'Тең';

  @override
  String get restaurantSplitByItems => 'Позициялар бойынша';

  @override
  String get restaurantSplitGuestCount => 'Қонақтар саны';

  @override
  String restaurantSplitPerGuest(String amount) {
    return 'Әрқайсысына: $amount';
  }

  @override
  String restaurantSplitGuest(int number) {
    return 'Қонақ $number';
  }

  @override
  String get restaurantSplitApply => 'Қолдану';

  @override
  String get restaurantSplitPaymentTitle => 'Оплата по гостям';

  @override
  String get restaurantSplitPaymentProceed => 'К оплате';

  @override
  String get restaurantPreCheckPrinted =>
      'Алдын ала чек басып шығаруға жіберілді';

  @override
  String get restaurantPreCheckFailed => 'Алдын ала чекті басып шығару қатесі';

  @override
  String get restaurantSubtotal => 'Аралық сома';

  @override
  String restaurantServiceChargeLine(String percent) {
    return 'Сервис алымы ($percent%)';
  }

  @override
  String restaurantOrderNumber(int number) {
    return 'Тапсырыс #$number';
  }

  @override
  String restaurantTakeoutNumber(int number) {
    return 'Алып кету #$number';
  }

  @override
  String restaurantDeliveryNumber(int number) {
    return 'Жеткізу #$number';
  }

  @override
  String get restaurantSaved => 'Мейрамхана параметрлері сақталды';

  @override
  String get restaurantQuickActions => 'Жылдам әрекеттер';

  @override
  String get restaurantNoItems => 'Тауарлар жоқ';

  @override
  String restaurantTableSeats(int count) {
    return '$count орын';
  }

  @override
  String get restaurantOrderTab => 'Тапсырыс';

  @override
  String get restaurantMenuTab => 'Мәзір';

  @override
  String restaurantGuestLabel(int number) {
    return 'Қонақ $number';
  }

  @override
  String get restaurantRemoveItem => 'Тауарды жою';

  @override
  String get restaurantPrintPrecheck => 'Алдын-ала чек';

  @override
  String get restaurantNewTakeout => 'Алып кету';

  @override
  String get restaurantNewDelivery => 'Жеткізу';

  @override
  String get setupSectionOrganization => 'Ұйым';

  @override
  String get setupSectionContact => 'Байланыс тұлғасы';

  @override
  String get setupSectionAddress => 'Мекенжайлар';

  @override
  String get setupSectionCashBox => 'Касса';

  @override
  String get setupSectionUsers => 'Кім жұмыс істейді';

  @override
  String get setupSectionSecurity => 'Кодпен кіру';

  @override
  String get setupSectionScanner => 'Сканер';

  @override
  String get setupSectionScale => 'Таразы';

  @override
  String get setupSectionDisplay => 'Сатып алушы дисплейі';

  @override
  String get setupSectionTerminal => 'Төлем терминалы';

  @override
  String get setupSectionCashback => 'Қолма-қол ақша қайтару';

  @override
  String get setupTaxIdExplanation =>
      'Салық нөмірі әр чекте басылады және фискалдық қызметке жіберіледі. Мұндағы қате салық органымен алғашқы салыстыру кезінде ғана байқалады — чектер сатып алушыларға берілгеннен кейін.';

  @override
  String get setupFiscalCredentialsExplanation =>
      'Деректемелерді фискалдық оператор береді. Олар дұрыс болмаса, чектер әдеттегідей басылады, бірақ фискалдық қызметке жетпейді — айырма сатылым кезінде емес, салыстыру кезінде байқалады.';

  @override
  String get setupKktNumberExplanation =>
      'ККМ нөмірі кассаны оператордағы тіркеуімен байланыстырады. Мұндағы қате чектерді бөтен касса атынан жібереді, ал мұны кассаның өзінен байқау мүмкін емес.';

  @override
  String setupStepProgress(int current, int total) {
    return '$current / $total қадам';
  }

  @override
  String get setupStepChecking => 'Тексеру';

  @override
  String get setupStepTelegram => 'Telegram';

  @override
  String get setupStepCountry => 'Ел';

  @override
  String get setupStepOrganization => 'Ұйым';

  @override
  String get setupStepVat => 'ҚҚС';

  @override
  String get setupStepUsers => 'Пайдаланушылар';

  @override
  String get setupStepWorkMode => 'Жұмыс режимі';

  @override
  String get setupStepPos => 'Касса';

  @override
  String get setupStepFiscal => 'Фискализация';

  @override
  String get setupStepEquipment => 'Жабдық';

  @override
  String get setupStepTerminals => 'Терминалдар';

  @override
  String get setupStepOperatingMode => 'Бизнес түрі';

  @override
  String get setupStepBusinessRules => 'Ережелер';

  @override
  String get setupStepSummary => 'Тексеру';

  @override
  String get setupStepComplete => 'Дайын';

  @override
  String get setupCheckingSettings => 'Баптаулар тексерілуде...';

  @override
  String get setupStateUnreadableTitle => 'Касса жауап бермеді';

  @override
  String get setupStateUnreadableBody =>
      'Шебер касса күйін оқымайынша баптауды бастамайды: әйтпесе ол жұмыс істеп тұрған дүкенді өшіріп жіберуі мүмкін. Кассаның қосулы және желіде қолжетімді екенін тексеріңіз.';

  @override
  String get wtUnavailableTitle => 'Кассамен байланыс жоқ';

  @override
  String get wtUnavailableBody =>
      'Терминал деректерді тек WebTransport арқылы алады. Қосалқы жол жоқ: байланыс болмаса, көрсететін ештеңе жоқ, ал ескі деректерді жаңа деп көрсету — ештеңе көрсетпегеннен жаман. Кассаның қосулы екенін тексеріп, қайталаңыз.';

  @override
  String wtUnavailableReason(String reason) {
    return 'Себебі: $reason';
  }

  @override
  String get terminalHomeWhoHeader => 'Кім кірді';

  @override
  String get terminalHomeUserLabel => 'Кассир';

  @override
  String get terminalHomeSaleNote =>
      'Браузерде сату — бөлек жұмыс: сату экраны кассаның дерекқорын тікелей оқиды және әзірге браузер үшін құрастырылмайды.';

  @override
  String get wtNotPortedTitle => 'Бұл экран әзірге тек кассада';

  @override
  String get wtNotPortedBody =>
      'Браузер терминалы деректерді сым арқылы алады, және экран мұнда оның барлық келісімдері сым үстінен жұмыс істей алғанда пайда болады. Бұл әлі үйренген жоқ. Оны бос көрсеткеннен гөрі, тіке айтқан дұрыс.';

  @override
  String wtNotPortedLocation(String location) {
    return 'Бағыт: $location';
  }

  @override
  String get setupWelcomeTitle => 'TelePOS-қа қош келдіңіз!';

  @override
  String get setupCountryDescription =>
      'Валюта мен салықтарды баптау үшін еліңізді таңдаңыз';

  @override
  String setupPriceExample(String amount) {
    return 'Мысалы: $amount';
  }

  @override
  String setupVatRateLabel(int rate) {
    return 'ҚҚС: $rate%';
  }

  @override
  String get setupOrganizationTitle => 'Ұйым деректері';

  @override
  String get setupOrganizationDescription =>
      'Компанияңыз туралы ақпаратты енгізіңіз';

  @override
  String get setupCompanyNameLabel => 'Ұйым атауы';

  @override
  String get setupCompanyNameHint => 'ЖШС \"Менің компаниям\"';

  @override
  String setupTaxIdDigits(int length) {
    return '$length сан';
  }

  @override
  String get setupLegalAddressLabel => 'Заңды мекенжай';

  @override
  String get setupActualAddressLabel => 'Дүкеннің нақты мекенжайы';

  @override
  String get setupOwnerNameLabel => 'Басшының Т.А.Ә.';

  @override
  String get setupPhoneLabel => 'Телефон';

  @override
  String get setupVatTitle => 'Қосылған құн салығы';

  @override
  String get setupVatDescription => 'Ұйымыңыздың салық салу режимін таңдаңыз';

  @override
  String get setupVatPayerTitle => 'ҚҚС төлеуші';

  @override
  String setupVatPayerRate(int rate) {
    return 'ҚҚС мөлшерлемесі: $rate%';
  }

  @override
  String get setupVatPayerRateUnknown => 'ҚҚС мөлшерлемесі елге байланысты';

  @override
  String get setupVatPayerDescription =>
      'Чектерде ҚҚС бөлінеді.\nЖалпы салық салу жүйесіндегі компаниялар үшін міндетті.';

  @override
  String get setupVatNonPayerTitle => 'ҚҚС-сыз';

  @override
  String get setupVatNonPayerSubtitle => 'ҚҚС қолданылмайды';

  @override
  String get setupVatNonPayerDescription =>
      'Чектерде ҚҚС бөлінбейді.\nЖеңілдетілген жүйедегі немесе патенттегі ЖК үшін.';

  @override
  String get setupWorkModeTitle => 'Жұмыс режимі';

  @override
  String get setupWorkModeDescription => 'Кассаңыздың жұмыс тәсілін таңдаңыз';

  @override
  String get setupAutonomousTitle => 'Автономды режим';

  @override
  String get setupAutonomousSubtitle => 'Интернетсіз жұмыс';

  @override
  String get setupAutonomousDescription =>
      'Касса толығымен автономды жұмыс істейді.\nДеректер тек жергілікті сақталады.\nКассалар арасында синхрондау жоқ.';

  @override
  String get setupNetworkTitle => 'Желілік режим';

  @override
  String get setupNetworkConfigured => 'Telegram бапталған';

  @override
  String get setupNetworkRequired => 'Telegram қажет';

  @override
  String get setupNetworkDescription =>
      'Кассалар арасында деректерді синхрондау.\nБұлтқа сақтық көшірме жасау.\nTelegram-да есептер мен хабарландырулар.';

  @override
  String get setupNetworkRequiresTelegram =>
      'Желілік режим үшін Telegram баптау қажет';

  @override
  String get setupOperatingModeTitle => 'Бизнес түрі';

  @override
  String get setupOperatingModeDescription => 'Бизнесіңіздің түрін таңдаңыз';

  @override
  String get setupRetailTitle => 'Бөлшек касса';

  @override
  String get setupRetailSubtitle => 'Дүкен, дәріхана, супермаркет';

  @override
  String get setupRetailDescription =>
      'Бөлшек сауда үшін стандартты POS.\nСату, қайтару, тауар қабылдау.\nАуысымдар мен есеп беру.';

  @override
  String get setupRestaurantTitle => 'Мейрамхана / Кафе';

  @override
  String get setupRestaurantSubtitle => 'Үстелдер, тапсырыстар, жеткізу';

  @override
  String get setupRestaurantDescription =>
      'Үстелдер мен залды басқару.\nАлып кету және жеткізу.\nШотты бөлу және сервис алымы.';

  @override
  String get setupServiceTitle => 'Сервис орталығы';

  @override
  String get setupServiceSubtitle => 'Жөндеу, қызметтер, рәсімдер';

  @override
  String get setupServiceDescription =>
      'Жөндеуге/қызметке қабылдау.\nТапсырыс-нарядтар және жұмыс белгілері.\nМәртебені бақылау және беру.';

  @override
  String get setupPosConfigTitle => 'Кассаны баптау';

  @override
  String get setupPosConfigDescription =>
      'Кассалық аппараттың параметрлерін көрсетіңіз';

  @override
  String get setupCashBoxNameLabel => 'Касса атауы';

  @override
  String get setupCashBoxNameHint => 'Касса 1';

  @override
  String get setupPosIdLabel => 'Касса ID';

  @override
  String get setupPrinterConfigTitle => 'Чек принтері';

  @override
  String get setupPaperWidthLabel => 'Қағаз ені';

  @override
  String get setupPaperWidth58 => '58 мм (32 символ)';

  @override
  String get setupPaperWidth80 => '80 мм (48 символ)';

  @override
  String get setupPrinterHeaderLabel => 'Чек тақырыбы';

  @override
  String get setupPrinterHeaderHint => 'Дүкен атауы\nМекенжайы';

  @override
  String get setupPrinterFooterLabel => 'Чек төменгі жағы';

  @override
  String get setupPrinterFooterHint => 'Сатып алғаныңызға рахмет!';

  @override
  String get setupFiscalNotRequired => 'Сіздің ел үшін фискализация қажет емес';

  @override
  String get setupFiscalDescription =>
      'Фискалдық оператормен байланысты баптаңыз';

  @override
  String get setupEnableWebkassa => 'WebKassa қосу';

  @override
  String get setupEnableOfd => 'ОФД қосу';

  @override
  String get setupWebkassaDescription =>
      'WebKassa арқылы чектерді фискализациялау (Қазақстан)';

  @override
  String get setupOfdDescription =>
      'ОФД арқылы чектерді фискализациялау (Ресей)';

  @override
  String get setupSkipLater => 'Өткізу (кейін баптау)';

  @override
  String get setupWebkassaAccountTitle => 'WebKassa аккаунты';

  @override
  String get setupWebkassaAccountIdLabel => 'Аккаунт ID';

  @override
  String get setupWebkassaAccountIdHint => 'WebKassa-дағы ID-ңіз';

  @override
  String get setupWebkassaTokenLabel => 'Аккаунт токені';

  @override
  String get setupWebkassaTokenHint => 'API токен';

  @override
  String get setupWebkassaPosTitle => 'WebKassa кассасы';

  @override
  String get setupWebkassaPosIdLabel => 'Касса ID';

  @override
  String get setupWebkassaPosIdHint => 'WebKassa-дағы касса ID';

  @override
  String get setupWebkassaPosTokenLabel => 'Касса токені';

  @override
  String get setupWebkassaPosTokenHint => 'Касса токені';

  @override
  String get setupWebkassaFactoryNoLabel => 'ККМ зауыттық нөмірі';

  @override
  String get setupOfdParamsTitle => 'ОФД параметрлері';

  @override
  String get setupOfdInnLabel => 'Ұйымның ИНН';

  @override
  String get setupOfdKktRegNoLabel => 'ККТ тіркеу нөмірі';

  @override
  String get setupOfdFnNoLabel => 'ФН нөмірі';

  @override
  String get setupOfdUrlLabel => 'ОФД URL';

  @override
  String get setupEquipmentTitle => 'Жабдық';

  @override
  String get setupEquipmentDescription => 'Қосылған жабдықты баптаңыз';

  @override
  String get setupEquipmentPrinter => 'Чек принтері';

  @override
  String get setupEquipmentScanner => 'Штрих-код сканері';

  @override
  String get setupEquipmentScales => 'Таразы';

  @override
  String get setupEquipmentCashDrawer => 'Ақша жәшігі';

  @override
  String get setupEquipmentDisplay => 'Сатып алушы дисплейі';

  @override
  String get setupConnectionTypeLabel => 'Қосылу түрі';

  @override
  String get setupConnectionUsb => 'USB';

  @override
  String get setupConnectionBluetooth => 'Bluetooth';

  @override
  String get setupConnectionWifi => 'Wi-Fi / Ethernet';

  @override
  String get setupConnectionSerial => 'COM-порт';

  @override
  String get setupConnectionNone => 'Таңдалмаған';

  @override
  String get setupPrinterIpLabel => 'Принтер IP-мекенжайы';

  @override
  String get setupPrinterMacLabel => 'Принтер MAC-мекенжайы';

  @override
  String get setupPrinterNameLabel => 'Принтер атауы';

  @override
  String get setupPrinterNameHint => 'Ас үй принтері';

  @override
  String get setupScannerTypeLabel => 'Сканер түрі';

  @override
  String get setupScannerCamera => 'Құрылғы камерасы';

  @override
  String get setupScannerUsb => 'USB-сканер';

  @override
  String get setupScannerBluetooth => 'Bluetooth-сканер';

  @override
  String get setupScalePortLabel => 'COM-порт';

  @override
  String get setupBaudRateLabel => 'Жылдамдық (baud rate)';

  @override
  String get setupCashDrawerConnected => 'Принтерге қосылған';

  @override
  String get setupCashDrawerConnectedDesc => 'Принтер командасымен ашылады';

  @override
  String get setupSkip => 'Өткізу';

  @override
  String get setupPaymentTerminalsTitle => 'Төлем терминалдары';

  @override
  String get setupPaymentTerminalsDescription =>
      'Төлем жүйелерімен интеграцияны баптаңыз';

  @override
  String get setupKaspiIpLabel => 'Терминал IP-мекенжайы';

  @override
  String get setupPortLabel => 'Порт';

  @override
  String get setupApiUrlLabel => 'API URL';

  @override
  String get setupApiKeyLabel => 'API кілті';

  @override
  String get setupNoTerminalsAvailable =>
      'Сіздің аймақ үшін қолжетімді төлем терминалдары жоқ';

  @override
  String get setupBusinessRulesTitle => 'Бизнес-ережелер';

  @override
  String get setupBusinessRulesDescription =>
      'Касса жұмысының ережелерін баптаңыз';

  @override
  String get setupPermissionsTitle => 'Рұқсаттар';

  @override
  String get setupAllowDiscounts => 'Жеңілдіктер';

  @override
  String get setupAllowDiscountsDesc => 'Жеңілдіктерді қолдануға рұқсат беру';

  @override
  String get setupAllowDebtSales => 'Қарызға сату';

  @override
  String get setupAllowDebtSalesDesc => 'Несиеге сатуға рұқсат беру';

  @override
  String get setupAllowPriceEdit => 'Бағаларды өңдеу';

  @override
  String get setupAllowPriceEditDesc =>
      'Сату кезінде бағаларды өзгертуге рұқсат беру';

  @override
  String get setupAllowCashInOut => 'Касса операциялары';

  @override
  String get setupAllowCashInOutDesc => 'Қолма-қол ақша енгізу және беру';

  @override
  String get setupBlockPriceDecrease => 'Бағаны төмендетуді бұғаттау';

  @override
  String get setupBlockPriceDecreaseDesc =>
      'Белгіленген бағадан төмен сатуға тыйым салу';

  @override
  String get setupLimitsTitle => 'Лимиттер';

  @override
  String get setupAllowBigAmount => 'Ірі сомалар';

  @override
  String get setupAllowBigAmountDesc => '> 1 000 000 операцияларға рұқсат беру';

  @override
  String get setupCashWithdrawalLimitLabel => 'Қолма-қол беру лимиті';

  @override
  String get setupCashWithdrawalLimitHelper => 'Лимитсіз үшін бос қалдырыңыз';

  @override
  String get setupLoyaltyTitle => 'Адалдық бағдарламасы';

  @override
  String get setupCashbackLabel => 'Кешбэк';

  @override
  String get setupCashbackDesc => 'Бонустар есептеуді қосу';

  @override
  String get setupCashbackRateLabel => 'Кешбэк пайызы';

  @override
  String get setupRoundingTitle => 'Дөңгелектеу';

  @override
  String get setupDiscountRounding => 'Жеңілдіктерді дөңгелектеу';

  @override
  String get setupWeightRounding => 'Салмақтық тауарларды дөңгелектеу';

  @override
  String get setupRoundingNone => 'Дөңгелектеусіз';

  @override
  String get setupRoundingUp1 => '1-ге дейін (жоғары)';

  @override
  String get setupRoundingDown1 => '1-ге дейін (төмен)';

  @override
  String get setupRoundingUp5 => '5-ке дейін (жоғары)';

  @override
  String get setupRoundingDown5 => '5-ке дейін (төмен)';

  @override
  String get setupRoundingUp10 => '10-ға дейін (жоғары)';

  @override
  String get setupRoundingDown10 => '10-ға дейін (төмен)';

  @override
  String get setupFiscalDisablesRounding =>
      'Фискализация қосылған кезде дөңгелектеу автоматты түрде өшіріледі';

  @override
  String get setupUserCreationTitle => 'Пайдаланушыларды құру';

  @override
  String get setupUserCreationDescription =>
      'Кассамен жұмыс істеу үшін пайдаланушыларды жасаңыз';

  @override
  String get setupAdminLabel => 'ӘКІМШІ';

  @override
  String get setupAdminSubtitle => 'Касса иесі';

  @override
  String get setupUserNameLabel => 'Аты';

  @override
  String get setupUserPinLabel => 'PIN';

  @override
  String get setupUserPinConfirmLabel => 'Растау';

  @override
  String get setupAdminPinDefault => 'Әдепкі: 0000';

  @override
  String get setupSellerLabel => 'САТУШЫ';

  @override
  String get setupSellerOptional => 'Қосымша';

  @override
  String get setupSellerPinDefault => 'Әдепкі: 1111';

  @override
  String get setupAdminPinMismatch => 'Әкімші PIN-кодтары сәйкес келмейді';

  @override
  String get setupSummaryTitle => 'Деректерді тексеріңіз';

  @override
  String get setupSummaryDescription =>
      'Барлығы дұрыс көрсетілгеніне көз жеткізіңіз';

  @override
  String get setupSummaryCountry => 'Ел';

  @override
  String get setupSummaryCurrency => 'Валюта';

  @override
  String get setupSummaryFormat => 'Формат';

  @override
  String get setupSummaryVat => 'ҚҚС';

  @override
  String get setupSummaryTelegram => 'Telegram';

  @override
  String get setupSummaryStatus => 'Мәртебе';

  @override
  String get setupConfigured => 'Бапталған';

  @override
  String get setupNotConfigured => 'Бапталмаған';

  @override
  String get setupSummaryOrganization => 'Ұйым';

  @override
  String get setupSummaryName => 'Атауы';

  @override
  String get setupSummaryAddress => 'Мекенжай';

  @override
  String get setupSummaryWorkMode => 'Жұмыс режимі';

  @override
  String get setupSummaryMode => 'Режим';

  @override
  String get setupSummaryAutonomous => 'Автономды (желісіз)';

  @override
  String get setupSummaryNetwork => 'Желілік (синхрондау)';

  @override
  String get setupSummaryPos => 'Касса';

  @override
  String get setupSummaryId => 'ID';

  @override
  String get setupEnabled => 'Қосылған';

  @override
  String get setupDisabled => 'Өшірілген';

  @override
  String get setupSummaryFiscalType => 'Түрі';

  @override
  String get setupSummaryEquipment => 'Жабдық';

  @override
  String get setupSummaryPrinter => 'Принтер';

  @override
  String get setupSummaryScanner => 'Сканер';

  @override
  String get setupSummaryScales => 'Таразы';

  @override
  String get setupSummaryCashDrawer => 'Ақша жәшігі';

  @override
  String get setupSummaryTerminals => 'Төлем терминалдары';

  @override
  String get setupSummaryRules => 'Бизнес-ережелер';

  @override
  String get setupSummaryDiscounts => 'Жеңілдіктер';

  @override
  String get setupSummaryDebtSales => 'Қарызға';

  @override
  String get setupSummaryCashback => 'Кешбэк';

  @override
  String get setupSummaryBigAmount => 'Ірі сомалар';

  @override
  String get setupSummaryUsers => 'Пайдаланушылар';

  @override
  String get setupSummaryAdmin => 'Әкімші';

  @override
  String get setupSummarySeller => 'Сатушы';

  @override
  String get setupCompleteTitle => 'Баптау аяқталды!';

  @override
  String get setupCompleteSubtitle => 'Касса жұмысқа дайын';

  @override
  String get setupStartWork => 'Жұмысты бастау';

  @override
  String setupVatPayerSummary(int rate) {
    return 'ҚҚС төлеуші ($rate%)';
  }

  @override
  String get setupSummaryWkPosId => 'WK касса ID';

  @override
  String get setupSummaryOfdInn => 'ИНН';

  @override
  String get setupScalesConfigured => 'Бапталған';

  @override
  String get setupScalesNotConfigured => 'Бапталмаған';

  @override
  String get setupCashDrawerOn => 'Қосылған';

  @override
  String get setupAllowed => 'Рұқсат етілген';

  @override
  String get setupDenied => 'Тыйым салынған';

  @override
  String get setupAllowedFem => 'Рұқсат етілген';

  @override
  String get setupDeniedFem => 'Тыйым салынған';

  @override
  String get setupCashbackOff => 'Өшірілген';

  @override
  String get setupBigAmountLimit => 'Лимит 100 000';

  @override
  String get setupDisplayPortLabel => 'COM-порт';

  @override
  String get telegramAuthSkip => 'Өткізу (кейін баптау)';

  @override
  String get telegramInitializing => 'Инициализация';

  @override
  String get telegramErrorTdlib => 'TDLib қатесі';

  @override
  String get telegramAuthLogin => 'Telegram-ға кіру';

  @override
  String get telegramAuthCodeStep => 'Растау коды';

  @override
  String get telegramAuth2fa => 'Екі факторлы аутентификация';

  @override
  String get telegramRegister => 'Тіркелу';

  @override
  String get telegramSearchingChannels => 'Арналарды іздеу';

  @override
  String get telegramLoadingData => 'Деректерді жүктеу';

  @override
  String get telegramOrgData => 'Ұйым деректері';

  @override
  String get telegramSetupChannels => 'Арналарды баптау';

  @override
  String get telegramSetupEncryption => 'Шифрлеуді баптау';

  @override
  String get telegramSetupComplete => 'Дайын';

  @override
  String get telegramInitializingLong => 'Telegram инициализациясы...';

  @override
  String get telegramConnecting => 'Telegram серверлеріне қосылу';

  @override
  String get telegramTdlibNotFound => 'TDLib табылмады';

  @override
  String get telegramTdlibErrorMessage =>
      'TDLib жергілікті кітапханасы табылмады.\nTelegram-мен жұмыс істеу үшін tdjson орнату қажет.';

  @override
  String get telegramForWindows => 'Windows үшін:';

  @override
  String get telegramWindowsInstructions =>
      '1. TDLib жүктеңіз: github.com/tdlib/td/releases\n2. tdjson.dll файлын жоба түбіріне көшіріңіз\n3. Немесе C:\\TDLib\\bin\\ ішіне орнатыңыз';

  @override
  String get telegramPhoneAuthTitle => 'Телефон нөмірімен кіру';

  @override
  String get telegramPhoneAuthDescription =>
      'Telegram аккаунтыңызға байланған телефон нөмірін енгізіңіз';

  @override
  String get telegramCountryCodeLabel => 'Ел коды';

  @override
  String get telegramPhoneNumber => 'Телефон нөмірі';

  @override
  String get telegramGetCode => 'Код алу';

  @override
  String get telegramRefreshQr => 'QR-кодты жаңарту';

  @override
  String get telegramSignUp => 'Тіркелу';

  @override
  String get telegramEnterStoreName => 'Дүкен атауын енгізіңіз';

  @override
  String get telegramInvalidBinIin => 'Дұрыс БИН/ЖСН енгізіңіз (12 сан)';

  @override
  String get telegramInvalidCode => 'Дұрыс кодты енгізіңіз';

  @override
  String get telegramEnterPassword => 'Құпия сөзді енгізіңіз';

  @override
  String get telegramCodeResent => 'Код қайта жіберілді';

  @override
  String get telegramEnterName => 'Атыңызды енгізіңіз';

  @override
  String get telegramManageAccount => 'Аккаунтты басқару';

  @override
  String get telegramNotificationsSection => 'Хабарландырулар';

  @override
  String get telegramNotificationsDesc =>
      'Сату, ауысымдар және т.б. туралы хабарландырулар алу';

  @override
  String get telegramNotifySales => 'Сату хабарландырулары';

  @override
  String get telegramNotifySalesDesc => 'Ірі сатулар, қайтарулар';

  @override
  String get telegramNotifyShifts => 'Ауысым хабарландырулары';

  @override
  String get telegramNotifyShiftsDesc => 'Ауысымдарды ашу және жабу';

  @override
  String get telegramNotifyCritical => 'Сыни хабарландырулар';

  @override
  String get telegramNotifyCriticalDesc => 'Қателер, OFD мәселелері';

  @override
  String get telegramNotifyStock => 'Қалдық хабарландырулары';

  @override
  String get telegramNotifyStockDesc => 'Тауар тапшылығы';

  @override
  String get telegramSyncSettings => 'Синхрондау баптаулары';

  @override
  String get telegramAutoSyncDesc => 'Деректерді автоматты синхрондау';

  @override
  String get telegramSyncInterval1min => '1 минут';

  @override
  String get telegramSyncInterval5min => '5 минут';

  @override
  String get telegramSyncInterval15min => '15 минут';

  @override
  String get telegramSyncInterval30min => '30 минут';

  @override
  String get telegramSyncInterval1hour => '1 сағат';

  @override
  String get telegramSystemChannels => 'Жүйелік арналар';

  @override
  String get telegramRefresh => 'Жаңарту';

  @override
  String get telegramChannelsNotConnected =>
      'Арналар қосылмаған.\nАвтоматты құру үшін Telegram-ға кіріңіз.';

  @override
  String telegramChannelsConnected(int connected, int total) {
    return '$total арнаның $connected қосылған';
  }

  @override
  String telegramChannelsLoadError(String error) {
    return 'Арналарды жүктеу қатесі: $error';
  }

  @override
  String get telegramForceSyncDesc => 'Барлық деректерді қазір синхрондау';

  @override
  String get telegramFullSyncDesc => 'Тастау және барлығын қайта синхрондау';

  @override
  String get telegramRecreateChannelsDesc => 'Жүйелік арналарды қайта құру';

  @override
  String get telegramLogoutDesc => 'Telegram интеграциясын ажырату';

  @override
  String get telegramFullSyncWarning =>
      'Бұл барлық синхрондау уақыт белгілерін тастайды және барлық деректерді қайта жүктейді. Операция ұзаққа созылуы мүмкін.';

  @override
  String get telegramRecreateChannelsWarning =>
      'Бұл әрекет барлық жүйелік арналарды қайта құрады. Арналардағы бар деректер жоғалады.';

  @override
  String get telegramLogoutWarning =>
      'Шығуға сенімдісіз бе? Синхрондау мен хабарландырулар өшіріледі.';

  @override
  String get telegramChannelsRecreated => 'Арналар қайта құрылды';

  @override
  String get telegramConnectedStatus => 'Қосылған';

  @override
  String get telegramNotConnected => 'Қосылмаған';

  @override
  String get telegramAccountLabel => 'Telegram аккаунты';

  @override
  String get telegramLoginForSync => 'Деректерді синхрондау үшін кіріңіз';

  @override
  String get channelDescSystemEvents => 'Жүйелік оқиғалар';

  @override
  String get channelDescSales => 'Сату лентасы';

  @override
  String get channelDescAlerts => 'Сыни хабарландырулар';

  @override
  String get channelDescReports => 'Есептер мен жиынтықтар';

  @override
  String get channelDescSync => 'Деректерді синхрондау';

  @override
  String get channelDescFiscal => 'Фискалдық оқиғалар';

  @override
  String get channelDescStaffChat => 'Қызметкерлер чаты';

  @override
  String get channelDescDataExchange => 'Деректер алмасу';

  @override
  String get channelDescTerminalStatus => 'Терминал мәртебесі';

  @override
  String get channelDescBackup => 'ДБ сақтық көшірмелері';

  @override
  String get chatNoConnectionBanner =>
      'Байланыс жоқ. Хабарламалар қалпына келтірілгенде жіберіледі.';

  @override
  String get chatLinkTelegramForId =>
      'Чатта сәйкестендіру үшін Telegram-ды байлаңыз';

  @override
  String chatSendError(String error) {
    return 'Жіберу қатесі: $error';
  }

  @override
  String chatFoundMessages(int count) {
    return '$count хабарлама табылды';
  }

  @override
  String get chatNoResults => 'Ештеңе табылмады';

  @override
  String get chatCopyUidInstructions =>
      'Басқа жүйелерде пайдалану үшін UID көшіріңіз';

  @override
  String get chatUidExample => 'Мысалы: telepos@pos-1';

  @override
  String get chatServiceUnavailable => 'Қызмет қолжетімсіз';

  @override
  String get chatTelegramLinked => 'Telegram сәтті байланды';

  @override
  String get additionalLogout => 'Шығу';

  @override
  String get additionalLockCashier => 'Бұғаттау';

  @override
  String get additionalPrinterAction => 'Принтер';

  @override
  String get additionalPrintLastReceipt => 'Соңғы чек';

  @override
  String get additionalSyncAction => 'Синхрондау';

  @override
  String get additionalCheckPrice => 'Бағаны тексеру';

  @override
  String get additionalMinimize => 'Жасыру';

  @override
  String get additionalCustomers => 'Сатып алушылар';

  @override
  String get additionalUpdateAction => 'Жаңарту';

  @override
  String get additionalExtraPrinter => 'Қосымша принтер';

  @override
  String get additionalSupplyAction => 'Қабылдау';

  @override
  String get additionalLanguageAction => 'Тіл';

  @override
  String get additionalKaspiPos => 'Kaspi POS';

  @override
  String get additionalPrinterEscPos => 'ESC/POS термопринтер';

  @override
  String get additionalPrinterNotConfigured => 'Принтер бапталмаған';

  @override
  String get additionalPrinterWifi => 'Wi-Fi принтер';

  @override
  String get additionalPrinterWifiDesc => 'IP бойынша қосылу';

  @override
  String get additionalPrinterBluetooth => 'Bluetooth принтер';

  @override
  String get additionalPrinterBluetoothDesc => 'Құрылғыларды іздеу';

  @override
  String get additionalPrinterUsb => 'USB принтер';

  @override
  String get additionalPrinterSystem => 'Жүйелік принтер';

  @override
  String get additionalPrinterDisconnected => 'Принтер ажыратылған';

  @override
  String get additionalPrinterIpLabel => 'IP';

  @override
  String get additionalPrinterEnterIp => 'IP мекенжайын енгізіңіз';

  @override
  String additionalPrinterConnecting(String address) {
    return '$address қосылуда...';
  }

  @override
  String get additionalPrinterConnectingUsb => 'USB принтерді қосу...';

  @override
  String get additionalPrinterNotConnected => 'Принтер қосылмаған';

  @override
  String get additionalPrintingLastReceipt => 'Соңғы чекті басып шығару...';

  @override
  String get additionalTestReceiptTitle => '=== ТЕСТІЛІК ЧЕК ===';

  @override
  String get additionalReceiptPrinted => 'Чек басып шығарылды';

  @override
  String additionalPriceSearching(String query) {
    return 'Іздеу: $query';
  }

  @override
  String get additionalMinimizing => 'Терезені жасыру...';

  @override
  String get additionalLatestVersion => 'Соңғы нұсқа орнатылған';

  @override
  String get additionalExtraPrinterTitle => 'Қосымша принтер';

  @override
  String get additionalExtraPrinterUsedFor =>
      'Қосымша принтер мыналар үшін қолданылады:';

  @override
  String get additionalExtraPrinterLabels => 'Жапсырмаларды басып шығару';

  @override
  String get additionalExtraPrinterKitchen => 'Ас үйге басып шығару';

  @override
  String get additionalExtraPrinterDuplicate => 'Чек дубликаты';

  @override
  String get additionalKaspiPosTitle => 'Kaspi POS';

  @override
  String get additionalKaspiPosDesc =>
      'Төлемдерді қабылдауға арналған Kaspi терминалы.';

  @override
  String get additionalKaspiPosNotConnected => 'Мәртебе: Қосылмаған';

  @override
  String additionalPrinterConnectedName(String name) {
    return 'Принтер қосылды: $name';
  }

  @override
  String additionalErrorWithMessage(String message) {
    return 'Қате: $message';
  }

  @override
  String get additionalPrinterUsbNotSupported =>
      'USB принтерлер қолдау көрсетілмейді';

  @override
  String get additionalPrinterUsbConnected => 'USB принтер қосылды';

  @override
  String get additionalBarcodeLabel => 'Штрихкод';

  @override
  String get additionalBarcodeHint => 'Сканерлеңіз немесе енгізіңіз';

  @override
  String additionalTestReceiptProduct(String number) {
    return 'Тауар $number';
  }

  @override
  String get additionalTestReceiptTotal => 'БАРЛЫҒЫ:';

  @override
  String get additionalTestReceiptThankYou => 'Сатып алғаныңызға рахмет!';

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
      'Бұл барлық синхрондау белгілерін тастайды және барлық деректерді қайта жүктейді. Бұл ұзаққа созылуы мүмкін. Жалғастыру керек пе?';

  @override
  String get transportSyncAbout => 'Синхрондау туралы';

  @override
  String transportSyncStateError(String error) {
    return 'Синхрондау күйін жүктеу қатесі: $error';
  }

  @override
  String get transportSyncInfoDialog =>
      'Деректердің әрбір түрі тәуелсіз синхрондалады. Соңғы синхрондаудан кейін өзгерген элементтер ғана жіберіледі.\n\nАралық: 5 минут (әдепкі)\nДеректер жіберу алдында AES-256-GCM шифрленеді.';

  @override
  String get transportSyncNever => 'Ешқашан';

  @override
  String get transportModeDescription =>
      'Сервермен деректер алмасу тәсілін таңдаңыз';

  @override
  String get transportModeRest => 'REST API';

  @override
  String get transportModeRestDesc => 'Классикалық HTTP/WebSocket қосылу';

  @override
  String get transportModeTelegram => 'Telegram';

  @override
  String get transportModeTelegramDesc => 'Telegram көлік қабаты ретінде';

  @override
  String get transportModeHybrid => 'Гибридті';

  @override
  String get transportModeHybridDesc => 'Telegram негізгі, REST резерв ретінде';

  @override
  String get transportModeRecommended => 'Ұсынылады';

  @override
  String transportSyncIntervalMinutes(int minutes) {
    return '$minutes минут';
  }

  @override
  String get transportSyncOnConnectivity => 'Желі қалпына келгенде синхрондау';

  @override
  String transportSyncIntervalOption(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes минут',
      one: '$minutes минут',
    );
    return '$_temp0';
  }

  @override
  String get transportEnableQueue => 'Операциялар кезегі';

  @override
  String get transportEnableQueueDesc =>
      'Желі болмаған кезде операцияларды буферлеу';

  @override
  String get transportMaxQueueSize => 'Кезек өлшемі';

  @override
  String transportQueueSizeStatus(int size) {
    return '$size операция';
  }

  @override
  String get transportAutoCleanup => 'Автотазалау';

  @override
  String get transportAutoCleanupDesc =>
      'Аяқталған операцияларды 7 күннен кейін жою';

  @override
  String get transportNotifyChanges => 'Көлікті ауыстыру';

  @override
  String get transportNotifyChangesDesc => 'Көлік режимі ауысқанда хабарлау';

  @override
  String get transportNotifySyncErrors => 'Синхрондау қателері';

  @override
  String get transportNotifySyncErrorsDesc =>
      'Синхрондау қателері туралы хабарлау';

  @override
  String get transportNotifyOfflineOnline => 'Байланыс';

  @override
  String get transportNotifyConnectivityDesc => 'Қосылу ауысқанда хабарлау';

  @override
  String get transportNotifyQueueFull => 'Кезек толы';

  @override
  String get transportNotifyQueueFullDesc => 'Кезек толғанда хабарлау';

  @override
  String saleErrorInitiation(String error) {
    return 'Сатуды бастау қатесі: $error';
  }

  @override
  String get saleErrorNotInitialized => 'Сату инициализацияланбаған';

  @override
  String get saleErrorEmpty => 'Чек бос';

  @override
  String saleErrorCompletion(String error) {
    return 'Сатуды аяқтау қатесі: $error';
  }

  @override
  String saleErrorSearch(String error) {
    return 'Іздеу қатесі: $error';
  }

  @override
  String saleErrorDeferred(String error) {
    return 'Чекті кейінге қалдыру қатесі: $error';
  }

  @override
  String get saleErrorDeferredNotFound => 'Кейінге қалдырылған чек табылмады';

  @override
  String saleErrorLoadingDeferred(String error) {
    return 'Кейінге қалдырылған чекті жүктеу қатесі: $error';
  }

  @override
  String get paymentCustomerDefault => 'Клиент';

  @override
  String get paymentErrorFormation =>
      'Төлемді қалыптастыру мүмкін болмады. Шот баптауларын тексеріңіз.';

  @override
  String get paymentErrorSaving => 'Сатуды сақтау қатесі';

  @override
  String paymentErrorProcessing(String error) {
    return 'Төлемді өңдеу қатесі: $error';
  }

  @override
  String paymentAccountDefault(int id) {
    return 'Шот $id';
  }

  @override
  String refundErrorReceiptNotFound(String number) {
    return '#$number чек табылмады';
  }

  @override
  String refundErrorLoadingReceipt(String error) {
    return 'Чекті жүктеу қатесі: $error';
  }

  @override
  String refundErrorSearch(String error) {
    return 'Іздеу қатесі: $error';
  }

  @override
  String get refundErrorProductNotFound => 'Тауар табылмады';

  @override
  String get refundErrorNotAuthenticated => 'Пайдаланушы авторизацияланбаған';

  @override
  String refundErrorProcessing(String error) {
    return 'Қайтару қатесі: $error';
  }

  @override
  String shiftErrorLoadingData(String error) {
    return 'Ауысым деректерін жүктеу қатесі: $error';
  }

  @override
  String shiftErrorOpening(String error) {
    return 'Ауысымды ашу қатесі: $error';
  }

  @override
  String shiftErrorClosing(String error) {
    return 'Ауысымды жабу қатесі: $error';
  }

  @override
  String shiftErrorPrinting(String error) {
    return 'Z-есепті басып шығару қатесі: $error';
  }

  @override
  String get cashOpTypeInvestment => 'Салым';

  @override
  String get cashOpTypeExpense => 'Шығыс';

  @override
  String get cashOpTypeDividend => 'Алу';

  @override
  String get supplyNoName => 'Атаусыз';

  @override
  String get supplyNoTitle => 'Атауы жоқ';

  @override
  String get supplyErrorSupplierNotFound => 'Жеткізуші табылмады';

  @override
  String supplyErrorSelectingSupplier(String error) {
    return 'Жеткізушіні таңдау қатесі: $error';
  }

  @override
  String get supplyErrorAccountNotFound => 'Шот табылмады';

  @override
  String supplyErrorSelectingAccount(String error) {
    return 'Шотты таңдау қатесі: $error';
  }

  @override
  String supplyErrorAddingProduct(String error) {
    return 'Тауар қосу қатесі: $error';
  }

  @override
  String get supplyErrorProductNotFound => 'Тауар табылмады';

  @override
  String get supplyErrorMissingFields => 'Барлық міндетті өрістерді толтырыңыз';

  @override
  String supplyErrorSaving(String error) {
    return 'Сақтау қатесі: $error';
  }

  @override
  String historyErrorLoading(String error) {
    return 'Тарихты жүктеу қатесі: $error';
  }

  @override
  String get syncTypeProducts => 'Тауарлар';

  @override
  String get syncTypePrices => 'Бағалар';

  @override
  String get syncTypeCategories => 'Санаттар';

  @override
  String get syncTypeAgents => 'Контрагенттер';

  @override
  String get syncTypeConfig => 'Баптаулар';

  @override
  String get syncTypeSales => 'Сатулар';

  @override
  String get syncTypeRefunds => 'Қайтарулар';

  @override
  String get syncTypeCashOps => 'Касса операциялары';

  @override
  String get syncTypeShifts => 'Ауысымдар';

  @override
  String get syncTypeSupplies => 'Қабылдаулар';

  @override
  String get syncStepPreparing => 'Дайындау...';

  @override
  String syncStepUploading(String type) {
    return 'Жүктеу: $type';
  }

  @override
  String syncStepDownloading(String type) {
    return 'Жүктеп алу: $type';
  }

  @override
  String get syncCompleted => 'Синхрондау аяқталды';

  @override
  String get loginErrorNoUsers => 'Тіркелген пайдаланушылар жоқ';

  @override
  String loginErrorLoadingData(String error) {
    return 'Деректерді жүктеу қатесі: $error';
  }

  @override
  String get loginErrorSelectUser => 'Пайдаланушыны таңдаңыз';

  @override
  String get loginErrorIncompletePin => 'PIN-кодты енгізіңіз (кемінде 4 сан)';

  @override
  String get loginErrorNoRsaKey =>
      'Қате: RSA кілті бапталмаған. Әкімшіге хабарласыңыз.';

  @override
  String get loginErrorWrongPin => 'Қате PIN-код';

  @override
  String get loginErrorSystemTime =>
      'Жүйелік уақыт дұрыс емес. Күн мен уақыт баптауларын тексеріңіз.';

  @override
  String get receiptLabelBin => 'БИН:';

  @override
  String get receiptLabelPhone => 'Тел:';

  @override
  String get receiptLabelReceiptNo => 'Чек №:';

  @override
  String get receiptLabelPosId => 'Касса:';

  @override
  String get receiptLabelDate => 'Күні:';

  @override
  String get receiptLabelCashier => 'Кассир:';

  @override
  String get receiptLabelTable => 'Үстел:';

  @override
  String get receiptLabelWaiter => 'Даяшы:';

  @override
  String get receiptLabelGuests => 'Қонақтар:';

  @override
  String get receiptLabelCustomer => 'Клиент:';

  @override
  String get receiptLabelSubtotal => 'Аралық сома:';

  @override
  String get receiptLabelDiscount => 'Жеңілдік:';

  @override
  String get receiptLabelServiceCharge => 'Сервис алымы:';

  @override
  String get receiptLabelTotal => 'БАРЛЫҒЫ:';

  @override
  String receiptLabelVat(String percent) {
    return 'оның ішінде ҚҚС $percent%:';
  }

  @override
  String get receiptLabelCash => 'Қолма-қол:';

  @override
  String get receiptLabelCard => 'Карта:';

  @override
  String get receiptLabelChange => 'Қайтарым:';

  @override
  String get receiptLabelCheckReceipt => 'Чекті тексеру:';

  @override
  String get receiptLabelItemName => 'Атауы';

  @override
  String get receiptLabelQty => 'Сан';

  @override
  String get receiptLabelPrice => 'Баға';

  @override
  String get receiptLabelAmount => 'Сома';

  @override
  String get receiptLabelItemDiscount => 'Жеңілдік:';

  @override
  String get receiptLabelFiscalBin => 'БИН:';

  @override
  String get receiptLabelFiscalNo => 'ФН:';

  @override
  String get receiptLabelFiscalSign => 'ФБ:';

  @override
  String get receiptLabelVatCertificate => 'ҚҚС:';

  @override
  String get receiptLabelOfflineMode => '*** ОФФЛАЙН ***';

  @override
  String get receiptLabelRefundHeader => '*** ҚАЙТАРУ ***';

  @override
  String get receiptLabelRefundNo => 'Қайтару №:';

  @override
  String get receiptLabelReason => 'Себебі:';

  @override
  String get receiptLabelRefundTotal => 'ҚАЙТАРУҒА:';

  @override
  String get receiptLabelZReport => 'Z-ЕСЕП';

  @override
  String get receiptLabelShiftClosing => 'АУЫСЫМДЫ ЖАБУ';

  @override
  String get receiptLabelShiftNo => 'Ауысым №:';

  @override
  String get receiptLabelShiftOpenTime => 'Ашылды:';

  @override
  String get receiptLabelShiftCloseTime => 'Жабылды:';

  @override
  String get receiptLabelSales => 'САТУЛАР';

  @override
  String get receiptLabelQuantity => 'Саны:';

  @override
  String get receiptLabelCashSales => 'Қолма-қол:';

  @override
  String get receiptLabelCardSales => 'Карта:';

  @override
  String get receiptLabelSalesTotal => 'Барлығы:';

  @override
  String get receiptLabelRefunds => 'ҚАЙТАРУЛАР';

  @override
  String get receiptLabelRefundQty => 'Саны:';

  @override
  String get receiptLabelRefundAmount => 'Сомасы:';

  @override
  String get receiptLabelCashOperations => 'КАССА ОПЕРАЦИЯЛАРЫ';

  @override
  String get receiptLabelInvestments => 'Салымдар:';

  @override
  String get receiptLabelExpenses => 'Төлемдер:';

  @override
  String get receiptLabelRevenue => 'ТҮСІМ:';

  @override
  String get receiptLabelCashInDrawer => 'КАССАДА:';

  @override
  String get receiptLabelXReport => 'X-ЕСЕП';

  @override
  String get receiptLabelType => 'Түрі:';

  @override
  String get receiptLabelDescription => 'Сипаттама:';

  @override
  String get receiptLabelDebtPayment => 'ҚАРЫЗДЫ ӨТЕУ';

  @override
  String get receiptLabelPreviousDebt => 'Қарыз болған:';

  @override
  String get receiptLabelPaidAmount => 'ТӨЛЕНДІ:';

  @override
  String get receiptLabelRemainingDebt => 'Қалдық:';

  @override
  String get receiptLabelTestPrint => 'TEST PRINT';

  @override
  String get receiptLabelThankYou => 'Сатып алғаныңызға рахмет!';

  @override
  String get receiptLabelSaleReceipt => 'КАССАЛЫҚ ЧЕК';

  @override
  String get receiptLabelOfflineHeader => '*** ОФФЛАЙН РЕЖИМІ ***';

  @override
  String get receiptLabelVatCertificateTitle => 'ҚҚС куәлігі:';

  @override
  String get fiscalErrorBin12Digits => 'БИН 12 саннан тұруы керек';

  @override
  String get fiscalErrorBinDigitsOnly => 'БИН тек сандардан тұруы керек';

  @override
  String get fiscalErrorFiscalNoRequired => 'Фискалдық нөмір міндетті';

  @override
  String get fiscalErrorRnkRequired => 'РНК міндетті';

  @override
  String get fiscalErrorZnkRequired => 'ЗНК міндетті';

  @override
  String get fiscalErrorVatSerialRequired => 'ҚҚС куәлігінің сериясы міндетті';

  @override
  String get fiscalErrorVatNumberRequired => 'ҚҚС куәлігінің нөмірі міндетті';

  @override
  String get telegramTabPhone => 'Телефон бойынша';

  @override
  String get telegramTabQr => 'QR-код';

  @override
  String get telegramQrAuthTitle => 'QR-код арқылы кіру';

  @override
  String get telegramQrAuthDescription =>
      'Телефондағы Telegram қолданбасында QR-кодты сканерлеңіз';

  @override
  String get telegramQrTapToGenerate => 'QR-код жасау үшін\nбасыңыз';

  @override
  String get telegramQrHowToScan => 'Қалай сканерлеуге болады:';

  @override
  String get telegramQrStep1 => 'Телефонда Telegram ашыңыз';

  @override
  String get telegramQrStep2 => 'Баптаулар → Құрылғылар бөліміне өтіңіз';

  @override
  String get telegramQrStep3 => '\"Құрылғыны қосу\" басыңыз';

  @override
  String get telegramQrStep4 => 'QR-кодты сканерлеңіз';

  @override
  String get telegramEnterCode => 'Кодты енгізіңіз';

  @override
  String telegramCodeSentTo(String phone) {
    return 'Код Telegram-ға жіберілді\n$phone нөмірге';
  }

  @override
  String get telegramCodeLabel => 'Растау коды';

  @override
  String get telegramPasswordDescription =>
      'Telegram аккаунтыңыздың құпия сөзін енгізіңіз';

  @override
  String telegramPasswordHint(String hint) {
    return 'Кеңес: $hint';
  }

  @override
  String get telegramPasswordLabel => 'Құпия сөз';

  @override
  String get telegramRegistrationDescription =>
      'Бұл нөмірмен аккаунт табылмады.\nЖаңа Telegram аккаунтын жасаңыз.';

  @override
  String get telegramFirstNameLabel => 'Аты';

  @override
  String get telegramLastNameLabel => 'Тегі (міндетті емес)';

  @override
  String get telegramLoadingOrgData => 'Ұйым деректерін жүктеу...';

  @override
  String get telegramSearchingExistingChannels => 'Бар арналарды іздеу...';

  @override
  String get telegramFoundChannels =>
      'Ұйым арналары табылды.\nКонфигурацияны жүктеу...';

  @override
  String get telegramCheckingChannels => 'Арналардың бар-жоғын тексеру...';

  @override
  String get telegramOrgDataNotLoaded =>
      'Деректерді жүктеу мүмкін болмады.\nҰйымыңыз туралы ақпаратты енгізіңіз.';

  @override
  String get telegramOrgDataFirstRun =>
      'TelePOS-тың алғашқы іске қосылуы.\nҰйымыңыз туралы ақпаратты енгізіңіз.';

  @override
  String get telegramStoreNameLabel => 'Дүкен атауы *';

  @override
  String get telegramStoreNameHint => 'Менің дүкенім';

  @override
  String get telegramBinLabel => 'Ұйымның БИН/ЖСН *';

  @override
  String get telegramAddressLabel => 'Мекенжай (міндетті емес)';

  @override
  String get telegramAddressHint => 'Алматы қ., Мысал көш., 123';

  @override
  String get telegramPosIdLabel => 'Касса ID';

  @override
  String get telegramOwnerNameLabel => 'Иесінің аты (міндетті емес)';

  @override
  String get telegramImportantNote => 'Маңызды';

  @override
  String get telegramOrgDataNote =>
      'Бұл деректер жүйелік арналарды құру және кассалар арасында синхрондау үшін пайдаланылады. Басқа құрылғыларда деректер автоматты жүктеледі.';

  @override
  String get telegramCreatingChannels => 'Жүйелік арналарды құру...';

  @override
  String get telegramSettingUpEncryption => 'Шифрлеуді баптау...';

  @override
  String get telegramSettingUp => 'Баптау...';

  @override
  String get telegramPleaseWait =>
      'Күте тұрыңыз.\nБұл біраз уақыт алуы мүмкін.';

  @override
  String get telegramSetupDone => 'Баптау аяқталды!';

  @override
  String get telegramSetupDoneMessage =>
      'Telegram сәтті бапталды.\nЖүйелік арналар құрылды.';

  @override
  String get telegramTermsNotice =>
      '\"Код алу\" басу арқылы сіз Telegram пайдалану шарттарымен келісесіз';

  @override
  String get telegramActionsSection => 'Әрекеттер';

  @override
  String get chatNotConfigured => 'Чат бапталмаған';

  @override
  String get chatCanDeleteOwnOnly => 'Тек өз хабарламаларын ғана жоюға болады';

  @override
  String get chatMessageDeleted => 'Хабарлама жойылды';

  @override
  String get chatDeleteFailed => 'Хабарламаны жою мүмкін болмады';

  @override
  String get chatTelegramNotLinked => 'Telegram байланбаған';

  @override
  String get chatLinkInstructions =>
      'Қызметкерлер чатында сәйкестендіру үшін Telegram User ID-ді енгізіңіз.';

  @override
  String get chatLinkHowTo =>
      'ID-ді қалай білуге болады:\n1. Telegram-да @userinfobot ашыңыз\n2. /start басыңыз\n3. \"Id\" өрісіндегі санды көшіріңіз';

  @override
  String get chatLinkFailed =>
      'Байлау мүмкін болмады. Мүмкін бұл ID қолданыста.';

  @override
  String get chatPhotoSent => 'Фото жіберілді';

  @override
  String get chatPhotoFailed => 'Фотоны жіберу мүмкін болмады';

  @override
  String get chatPhotoError => 'Фотоны таңдау қатесі';

  @override
  String get chatPhotoUnavailableWeb => 'Веб-нұсқада фото жіберу қолжетімсіз';

  @override
  String get chatDocSent => 'Құжат жіберілді';

  @override
  String get chatDocFailed => 'Құжатты жіберу мүмкін болмады';

  @override
  String get chatDocError => 'Құжатты таңдау қатесі';

  @override
  String get chatDocUnavailableWeb => 'Веб-нұсқада құжат жіберу қолжетімсіз';

  @override
  String get chatDocPathError => 'Файл жолын алу мүмкін болмады';

  @override
  String get chatDocTooLarge => 'Файл тым үлкен (макс. 50 МБ)';

  @override
  String get chatLocationSent => 'Орналасу жіберілді';

  @override
  String get chatLocationFailed => 'Орналасуды жіберу мүмкін болмады';

  @override
  String get chatLocationError => 'Орналасуды алу қатесі';

  @override
  String get chatLocationUnavailableWeb => 'Веб-нұсқада геолокация қолжетімсіз';

  @override
  String get chatLocationDenied => 'Геолокацияға кіру тыйым салынған';

  @override
  String get chatLocationDeniedForever =>
      'Геолокацияға кіру мүлдем тыйым салынған. Баптауларда өзгертіңіз.';

  @override
  String get chatLocationServiceDisabled => 'Құрылғыда геолокацияны қосыңыз';

  @override
  String get syncToUpload => 'Жүктеуге';

  @override
  String get syncToDownload => 'Жүктеп алуға';

  @override
  String get syncDataTypeCol => 'Деректер түрі';

  @override
  String get syncDirectionCol => 'Бағыт';

  @override
  String get syncPendingCol => 'Күтуде';

  @override
  String get syncStatusCol => 'Мәртебесі';

  @override
  String get syncProgressCol => 'Барысы';

  @override
  String get syncUpload => 'Жүктеу';

  @override
  String get syncDownload => 'Жүктеп алу';

  @override
  String syncPendingCount(int count) {
    return 'Күтуде: $count';
  }

  @override
  String get syncInfoTelegram =>
      'Деректер кассалар арасында Telegram арқылы синхрондалады. Пайдаланушылар барлық кассаларға ортақ.';

  @override
  String get syncAutoEnabled => 'Деректер автоматты синхрондалады';

  @override
  String get syncManualOnly => 'Тек қолмен синхрондау';

  @override
  String syncMinutes(int count) {
    return '$count мин';
  }

  @override
  String get agentBinIin => 'БСН/ЖСН';

  @override
  String get agentLastOperation => 'Соңғы операция';

  @override
  String get agentNoAdditionalInfo => 'Қосымша ақпарат жоқ';

  @override
  String get agentNoDebt => 'Қарыз жоқ';

  @override
  String agentDeletedWithName(String name) {
    return 'Клиент \"$name\" жойылды';
  }

  @override
  String agentDeleteError(String error) {
    return 'Жою қатесі: $error';
  }

  @override
  String get agentNewCustomer => 'Жаңа клиент';

  @override
  String get agentTypeCustomer => 'Клиент';

  @override
  String get agentTypeSupplier => 'Поставщик';

  @override
  String get agentNameHint => 'Клиент атын енгізіңіз';

  @override
  String get agentBinHint => '12 сан';

  @override
  String get agentCustomerFound => 'Клиент табылды';

  @override
  String get agentDeletedPhoneMsg => 'Осы телефонмен клиент жойылған';

  @override
  String get agentRestoreQuestion => 'Қалпына келтіру керек пе?';

  @override
  String get agentRestore => 'Қалпына келтіру';

  @override
  String get kaspiTerminal => 'Kaspi POS Терминал';

  @override
  String get kaspiIpAddress => 'Терминал IP-мекенжайы';

  @override
  String get kaspiInvalidIp => 'IP-мекенжай форматы қате';

  @override
  String get kaspiPort => 'Порт';

  @override
  String get kaspiTesting => 'Тексеру...';

  @override
  String get kaspiTest => 'ТЕСТ';

  @override
  String get kaspiDisconnected => 'Қосылмаған';

  @override
  String get kaspiConnecting => 'Қосылуда...';

  @override
  String get kaspiConnected => 'Байланыс орнатылды';

  @override
  String get kaspiNoConnection => 'Байланыс жоқ';

  @override
  String get kaspiTestPassed => 'Тест сәтті';

  @override
  String get kaspiTestFailed => 'Тест сәтсіз';

  @override
  String kaspiLatency(String ms) {
    return 'Кідіріс: $ms мс';
  }

  @override
  String kaspiTerminalInfo(String info) {
    return 'Терминал: $info';
  }

  @override
  String get splashSubtitle => 'Касса жүйесі';

  @override
  String get splashInitializing => 'Инициализация...';

  @override
  String get splashLoadingOrg => 'Ұйым деректерін жүктеу...';

  @override
  String get splashEnterPosKey => 'POS кілтін енгізіңіз';

  @override
  String get splashEnterPosKeyMessage =>
      'Кассаны белсендіру үшін әкімшіден алынған кілтті енгізіңіз.';

  @override
  String get splashPosKeyHint => 'XXXX-XXXX-XXXX-XXXX';

  @override
  String get splashKeyEmpty => 'Кілт бос болмауы керек';

  @override
  String get splashKeyTooShort => 'Кілт тым қысқа';

  @override
  String get splashKeyNotEntered => 'Кілт енгізілмеді';

  @override
  String get splashKeyRequiredMessage =>
      'POS кілтсіз жұмыс істей алмайды. Қолданба жабылады.';

  @override
  String get splashDataCorrupted => 'Деректер зақымдалған';

  @override
  String get splashDataCorruptedMessage =>
      'Қолданбаның міндетті деректері жоқ немесе зақымдалған.\n\nӘрекетті таңдаңыз:';

  @override
  String get splashReconfigure => 'Қайта баптау';

  @override
  String get splashExit => 'Шығу';

  @override
  String get splashDatabaseError => 'Деректер базасы қатесі';

  @override
  String get splashDatabaseErrorMessage =>
      'Деректер базасы зақымдалған немесе қол жетімсіз.\n\nСақтық көшірмеден қалпына келтіруге немесе кассаны қайта баптауға болады.';

  @override
  String get splashRestoreFromBackup => 'Сақтық көшірмеден қалпына келтіру';

  @override
  String get splashSyncSuspended => 'Синхрондау тоқтатылды';

  @override
  String get splashSyncSuspendedMessage =>
      'Деректерді синхрондау уақытша тоқтатылды.\n\nКасса автономды режимде жұмыс істейді. Байланыс қалпына келтірілгенде деректер синхрондалады.';

  @override
  String get splashAuthError =>
      'Авторизация қатесі\n\nКіру токені жарамсыз немесе мерзімі өтті.\nЖаңа кілт алу үшін әкімшіге хабарласыңыз.';

  @override
  String get splashSupportEnded =>
      'Нұсқа қолдау көрсетілмейді\n\nБұл қолданба нұсқасына бұдан былай қолдау көрсетілмейді.\nСоңғы нұсқаға жаңартыңыз.';

  @override
  String get generalSettingsTitle => 'Баптаулар';

  @override
  String get generalSettingsPosInfo => 'Касса туралы ақпарат';

  @override
  String get generalSettingsCashBoxName => 'Касса атауы';

  @override
  String get generalSettingsCompany => 'Компания';

  @override
  String get generalSettingsIinBin => 'ЖСН/БСН';

  @override
  String get generalSettingsPosId => 'POS ID';

  @override
  String get generalSettingsStoreId => 'Дүкен ID';

  @override
  String get generalSettingsNotSpecified => 'Көрсетілмеген';

  @override
  String get generalSettingsAppVersion => 'Қолданба нұсқасы';

  @override
  String get generalSettingsVersion => 'Нұсқа';

  @override
  String get generalSettingsPlatform => 'Платформа';

  @override
  String get generalSettingsLanguage => 'Интерфейс тілі';

  @override
  String get generalSettingsTheme => 'Безендіру';

  @override
  String get generalSettingsThemeDesc => 'Ашық, күңгірт немесе жүйедегідей';

  @override
  String get generalSettingsThemeLight => 'Ашық';

  @override
  String get generalSettingsThemeDark => 'Күңгірт';

  @override
  String get generalSettingsThemeSystem => 'Жүйедегідей';

  @override
  String generalSettingsLanguageChanged(String language) {
    return 'Тіл $language болып өзгертілді';
  }

  @override
  String get generalSettingsCurrency => 'Валюта';

  @override
  String get generalSettingsCurrencySymbol => 'Белгі';

  @override
  String get generalSettingsCurrencyCode => 'Код';

  @override
  String get generalSettingsCountry => 'Ел';

  @override
  String get generalSettingsAdditional => 'Қосымша баптаулар';

  @override
  String get generalSettingsTransport => 'Көлік';

  @override
  String get generalSettingsTransportSubtitle =>
      'Деректерді синхрондау баптаулары';

  @override
  String get generalSettingsPrinter => 'Принтер';

  @override
  String get generalSettingsPrinterSubtitle => 'Чек басып шығару баптаулары';

  @override
  String get generalSettingsPermissions => 'Рұқсаттар';

  @override
  String get generalSettingsPermissionsSubtitle => 'Кассирлер үшін рұқсаттар';

  @override
  String get generalSettingsFiscal => 'Фискализация';

  @override
  String get generalSettingsFiscalSubtitle => 'WebKassa, ОФД, ҚҚС';

  @override
  String get generalSettingsRestaurant => 'Мейрамхана';

  @override
  String get generalSettingsRestaurantSubtitle =>
      'Үстелдер, залдар, қызмет көрсету';

  @override
  String get generalSettingsTelegram => 'Telegram';

  @override
  String get generalSettingsTelegramSubtitle => 'Байланыс арналары және боттар';

  @override
  String get generalSettingsPosInfoDesc => 'Касса атауы, компания, ID';

  @override
  String get generalSettingsVersionDesc => 'Ағымдағы нұсқа және платформа';

  @override
  String get generalSettingsLanguageDesc => 'Интерфейс тілін таңдау';

  @override
  String get generalSettingsCurrencyDesc => 'Валюта және ел';

  @override
  String get generalSettingsUpdate => 'Жаңарту';

  @override
  String get generalSettingsUpdateSubtitle =>
      'Жаңартуларды тексеру және орнату';

  @override
  String get generalSettingsAppUpdate => 'Қосымшаны жаңарту';

  @override
  String get generalSettingsAppUpdateSubtitle =>
      'Касса қосымшасын жаңарту (ОЖ жаңартуымен шатастырмаңыз)';

  @override
  String get generalSettingsUpdateDesc => 'Ағымдағы нұсқа және жаңартулар';

  @override
  String get settingsUpdateTitle => 'Қолданбаны жаңарту';

  @override
  String get settingsUpdateCurrentVersion => 'Ағымдағы нұсқа';

  @override
  String get settingsUpdateCheckBtn => 'Жаңартуларды тексеру';

  @override
  String get settingsUpdateChecking => 'Жаңартулар тексерілуде...';

  @override
  String get settingsUpdateUpToDate => 'Соңғы нұсқа орнатылған';

  @override
  String settingsUpdateAvailable(String version) {
    return '$version нұсқасы қол жетімді';
  }

  @override
  String get settingsUpdateDownloadBtn => 'Жаңартуды жүктеу';

  @override
  String settingsUpdateDownloading(String percent) {
    return 'Жүктелуде... $percent%';
  }

  @override
  String get settingsUpdateInstallBtn => 'Жаңартуды орнату';

  @override
  String get settingsUpdateInstalling => 'Орнатылуда...';

  @override
  String get settingsUpdateFailed => 'Жаңарту қатесі';

  @override
  String get settingsUpdateAutoEnabled => 'Автоматты тексеру әр 3 сағат сайын';

  @override
  String get settingsUpdateCloseShift => 'Жаңарту алдында ауысымды жабыңыз';

  @override
  String get settingsUpdateReleaseNotes => 'Жаңалықтар';

  @override
  String get countryKazakhstan => 'Қазақстан';

  @override
  String get countryRussia => 'Ресей';

  @override
  String get countryKyrgyzstan => 'Қырғызстан';

  @override
  String get countryUzbekistan => 'Өзбекстан';

  @override
  String get countryUSA => 'АҚШ';

  @override
  String get countryTurkmenistan => 'Түрікменстан';

  @override
  String get permEditPrice => 'Бағаны өңдеу';

  @override
  String get permSellInDebt => 'Қарызға сату';

  @override
  String get permDiscounts => 'Жеңілдіктер';

  @override
  String get permCashOperations => 'Касса операциялары';

  @override
  String get permSendToOfd => 'ОФД-ге жіберу';

  @override
  String get permCancelPayment => 'Төлемді болдырмау';

  @override
  String get permDeferSale => 'Кейінге қалдырылған сату';

  @override
  String get permShowHistory => 'Тарихты көрсету';

  @override
  String get printerSettingsSaved => 'Баптаулар сақталды';

  @override
  String printerSettingsSaveError(String error) {
    return 'Сақтау қатесі: $error';
  }

  @override
  String get printerSettingsPrinting => 'Басып шығарылуда...';

  @override
  String get printerSettingsTestReceipt => 'СЫНАҚ ЧЕГІ';

  @override
  String get printerSettingsWidth => 'Ені:';

  @override
  String printerSettingsWidthValue(int width) {
    return '$width символ';
  }

  @override
  String get printerSettingsType => 'Түрі:';

  @override
  String get printerSettingsAddress => 'Мекенжай:';

  @override
  String get printerSettingsNotSpecifiedAddr => 'Көрсетілмеген';

  @override
  String get printerSettingsPrinterWorks => 'Принтер жұмыс істейді!';

  @override
  String get printerSettingsPrintSuccess => 'Басып шығару сәтті';

  @override
  String get printerSettingsPrintError => 'Басып шығару қатесі';

  @override
  String get printerSettingsNotConnected => 'Қосылмаған';

  @override
  String get printerSettingsChecking => 'Тексерілуде...';

  @override
  String get printerSettingsReady => 'Дайын';

  @override
  String get printerSettingsNoPaper => 'Қағаз жоқ';

  @override
  String get printerSettingsCoverOpen => 'Қақпақ ашық';

  @override
  String get printerSettingsSave => 'Сақтау';

  @override
  String get printerSettingsConnectionType => 'Қосылу түрі';

  @override
  String get printerSettingsPrinterAddress => 'Принтер мекенжайы';

  @override
  String get printerSettingsPaperWidth => 'Қағаз ені';

  @override
  String get printerSettingsTesting => 'Тестілеу';

  @override
  String printerSettingsStatus(String status) {
    return 'Күй: $status';
  }

  @override
  String get printerSettingsCheck => 'Тексеру';

  @override
  String get printerSettingsTestCheck => 'Сынақ чегі';

  @override
  String get printerSettingsPort => 'Порт';

  @override
  String get printerSettingsIpAddress => 'Принтердің IP мекенжайы';

  @override
  String get printerSettingsMacAddress => 'MAC мекенжай немесе атауы';

  @override
  String get printerSettingsPrinterName => 'Принтер атауы';

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
  String get fiscalSettingsSaved => 'Баптаулар сақталды';

  @override
  String fiscalSettingsSaveError(String error) {
    return 'Сақтау қатесі: $error';
  }

  @override
  String get fiscalSettingsSave => 'Сақтау';

  @override
  String get fiscalSettingsOperator => 'Фискалдық оператор';

  @override
  String get fiscalSettingsWebkassaSettings => 'WebKassa баптаулары';

  @override
  String get fiscalSettingsTaxpayerInfo => 'Салық төлеуші деректері';

  @override
  String get fiscalSettingsVatSettings => 'ҚҚС баптаулары';

  @override
  String get fiscalSettingsWebkassaLabel => 'WebKassa';

  @override
  String get fiscalSettingsWebkassaDesc => 'Бұлтты фискалдық қызмет';

  @override
  String get fiscalSettingsOfdLabel => 'ОФД';

  @override
  String get fiscalSettingsOfdDesc => 'Фискалдық деректер операторы';

  @override
  String get fiscalSettingsNoneLabel => 'Фискализациясыз';

  @override
  String get fiscalSettingsNoneDesc => 'Чектер ОФД-ге жіберілмейді';

  @override
  String get fiscalSettingsOfdId => 'ОФД ID';

  @override
  String get fiscalSettingsOfdIdHint => 'ОФД идентификаторы';

  @override
  String get fiscalSettingsOfdName => 'ОФД атауы';

  @override
  String get fiscalSettingsOfdNameHint => 'WebKassa / ОФД.kz';

  @override
  String get fiscalSettingsOfdHost => 'ОФД сервер мекенжайы';

  @override
  String get fiscalSettingsOfdHostHint => 'https://api.webkassa.kz';

  @override
  String get fiscalSettingsWebkassaActive => 'WebKassa белсендірілген';

  @override
  String get fiscalSettingsWebkassaInactive => 'WebKassa белсендірілмеген';

  @override
  String get fiscalSettingsCompanyName => 'Атауы';

  @override
  String get fiscalSettingsCashBox => 'Касса';

  @override
  String get fiscalSettingsVatPayer => 'ҚҚС төлеуші';

  @override
  String get fiscalSettingsVatPayerSubtitle =>
      'Ұйым ҚҚС төлеуші болып табылады (12%)';

  @override
  String get fiscalSettingsPrintVat => 'Чекте ҚҚС басып шығару';

  @override
  String get fiscalSettingsPrintVatSubtitle => 'Чекте ҚҚС сомасын көрсету';

  @override
  String get fiscalSettingsVatRate =>
      'ҚҚС мөлшерлемесі: 12% (3/28 формуласы бойынша)';

  @override
  String historyProductUcode(String ucode) {
    return 'Тауар #$ucode';
  }

  @override
  String historyRefundProductId(String id) {
    return 'Қайтару тауары #$id';
  }

  @override
  String historyAccountId(String id) {
    return 'Шот #$id';
  }

  @override
  String historyLoadError(String error) {
    return 'Жүктеу қатесі: $error';
  }

  @override
  String historyReceiptNo(String number) {
    return 'Чек $number';
  }

  @override
  String get historySyncSynced => 'Синхр.';

  @override
  String get historySyncPending => 'Күту';

  @override
  String get historySyncSending => 'Жіб.';

  @override
  String get historySyncDeferred => 'Кейін';

  @override
  String get historySyncInProgress => 'Жұмыста';

  @override
  String get historyClient => 'Клиент';

  @override
  String get historyFiscalization => 'Фискализация';

  @override
  String get historyProducts => 'Тауарлар';

  @override
  String get historyPayment => 'Төлем';

  @override
  String get historyNoProducts => 'Тауарлар жоқ';

  @override
  String get historyNoPayments => 'Төлемдер жоқ';

  @override
  String historyPrintingReceipt(String number) {
    return 'Чекті басып шығару $number...';
  }

  @override
  String get historyReceiptPrinted => 'Чек басылды';

  @override
  String get historyPrintError => 'Басып шығару қатесі';

  @override
  String get historyOperationType => 'Операция түрі';

  @override
  String get historyFilterSales => 'Сатулар';

  @override
  String get historyFilterRefunds => 'Қайтарулар';

  @override
  String get historySearchShort => 'Іздеу...';

  @override
  String get historyFilters => 'Сүзгілер';

  @override
  String get historyDateFrom => 'Бастап';

  @override
  String get historyDateTo => 'Дейін';

  @override
  String get historyReset => 'Тастау';

  @override
  String get historyApply => 'Қолдану';

  @override
  String get historySearchFull => 'Чек нөмірі, сома бойынша іздеу...';

  @override
  String get historySyncStatus => 'Синхрондау күйі';

  @override
  String get historyReceiptColumn => 'Чек';

  @override
  String get historySyncSyncedFull => 'Синхрондалған';

  @override
  String get historySyncPendingFull => 'Синхрондауды күтуде';

  @override
  String get historySyncSendingFull => 'Жіберілуде';

  @override
  String get historySyncDeferredFull => 'Кейінге қалдырылған';

  @override
  String get historySyncInProgressFull => 'Орындалуда';

  @override
  String get historyPaymentCash => 'Қолма-қол';

  @override
  String get historyPaymentCard => 'Карта';

  @override
  String get historyPaymentMixed => 'Аралас';

  @override
  String get historyPaymentBonus => 'Бонустар';

  @override
  String get historyPaymentDebt => 'Қарызға';

  @override
  String get historyPaymentDiscount => 'Жеңілдік';

  @override
  String get historyPaymentWithDiscount => 'Жеңілдікпен';

  @override
  String get historyOfdFiscalized => 'Фискалданған';

  @override
  String get historyOfdError => 'Фискализация қатесі';

  @override
  String get historyOfdNotFiscalized => 'Фискалданбаған';

  @override
  String get historyClearFilters => 'Сүзгілерді тастау';

  @override
  String historyRecordsRange(String start, String end, String total) {
    return 'Жазбалар $start–$end, барлығы $total';
  }

  @override
  String get historyFirstPage => 'Бірінші бет';

  @override
  String get historyPrevious => 'Алдыңғы';

  @override
  String get historyNextPage => 'Келесі';

  @override
  String get historyLastPage => 'Соңғы бет';

  @override
  String historyAmount(String amount) {
    return 'Сома: $amount';
  }

  @override
  String historyDate(String date) {
    return 'Күні: $date';
  }

  @override
  String historyPos(String id) {
    return 'POS: $id';
  }

  @override
  String historyClientName(String name) {
    return 'Клиент: $name';
  }

  @override
  String get historyFiscalYes => 'Иә';

  @override
  String get historyFiscalNo => 'Жоқ';

  @override
  String get historyFiscalError => 'Қате';

  @override
  String get shiftPrintZReport => 'Z-есепті басып шығару';

  @override
  String get shiftZReportQueued =>
      'Z-отчёт принят в очередь печати. Бумаги пока нет: она выйдет, когда принтер сможет. Задание ждёт 30 минут — посмотреть его можно в Настройках → Принтер';

  @override
  String get shiftZReportAlreadyQueued =>
      'Z-отчёт уже сдан в печать — второй раз он не печатается';

  @override
  String get shiftZReportPrintFailed => 'Не удалось сдать Z-отчёт в печать';

  @override
  String get shiftFinishAllSales => 'Барлық сатуларды аяқтаңыз';

  @override
  String get shiftCannotClose => 'Ауысымды жабу мүмкін емес';

  @override
  String get shiftOpeningShift => 'Ауысымды ашу';

  @override
  String get shiftClosingShift => 'Ауысымды жабу';

  @override
  String get shiftEnterInitialAmount => 'Кассадағы бастапқы соманы енгізіңіз:';

  @override
  String get shiftDiscrepancyFound => 'Сәйкессіздік анықталды';

  @override
  String shiftDifferenceAmount(String amount) {
    return 'Айырмашылық: $amount';
  }

  @override
  String get shiftConfirmCloseQuestion => 'Ауысымды жабуға сенімдісіз бе?';

  @override
  String shiftFixedAmount(String amount) {
    return 'Тіркелетін сома: $amount KZT';
  }

  @override
  String get shiftCloseWithDiscrepancy => 'Сәйкессіздікпен жабу';

  @override
  String get shiftCashierLabel => 'Кассир';

  @override
  String get shiftUnknown => 'Белгісіз';

  @override
  String get shiftSystemTotal => 'Жүйелік сома';

  @override
  String get shiftEnteredTotal => 'Енгізілген сома';

  @override
  String get shiftCashOperations => 'Кассалық операциялар';

  @override
  String get shiftSalesLabel => 'Продажи';

  @override
  String get shiftSalesTotal => 'Сумма продаж';

  @override
  String get shiftCashSales => 'Наличные';

  @override
  String get shiftCardSales => 'Карта';

  @override
  String get shiftRefundsTotal => 'Возвраты';

  @override
  String get shiftShortage => 'Тапшылық';

  @override
  String get shiftSurplus => 'Артықшылық';

  @override
  String get shiftBalances => 'Сәйкес келеді';

  @override
  String get shiftCloseBlocked => 'Жабу бұғатталған';

  @override
  String shiftActiveSalesCount(int count) {
    return 'Белсенді сатулар: $count';
  }

  @override
  String shiftPendingSalesCount(int count) {
    return 'Кейінге қалдырылған сатулар: $count';
  }

  @override
  String get shiftFinishSalesBeforeClose =>
      'Ауысымды жабу алдында сатуларды аяқтаңыз немесе болдырмаңыз';

  @override
  String get shiftBillsTab => 'Купюралар';

  @override
  String get shiftTotalTab => 'Жалпы сома';

  @override
  String get shiftOperationsTab => 'Операциялар';

  @override
  String get shiftAmountTab => 'Сома';

  @override
  String get shiftBillCount => 'Купюралар бойынша санау';

  @override
  String get shiftDifferenceLabel => 'Айырмашылық: ';

  @override
  String get supplySupplierRequired => 'Жеткізуші *';

  @override
  String get supplyPaymentType => 'Төлем түрі';

  @override
  String get supplyFullPayment => 'Толық төлем';

  @override
  String get supplyAccountDebit => 'Шоттан есептен шығару';

  @override
  String get supplyConsignment => 'Консигнация';

  @override
  String get supplyDeferredPayment => 'Кейінге қалдырылған төлем';

  @override
  String get supplyPaymentAccountRequired => 'Төлем шоты *';

  @override
  String get supplyAddProduct => 'Тауар қосу';

  @override
  String get supplyBarcodeOrSku => 'Штрихкод немесе артикул';

  @override
  String supplyProductsCount(int count) {
    return 'Тауарлар ($count)';
  }

  @override
  String supplyAmountValue(String amount) {
    return 'Сома: $amount';
  }

  @override
  String get supplyProductNotFound => 'Тауар табылмады';

  @override
  String get supplyInvalidQuantity => 'Дұрыс санын енгізіңіз';

  @override
  String get supplySelectSupplierTitle => 'Жеткізушіні таңдаңыз';

  @override
  String get supplySuppliersNotFound => 'Жеткізушілер табылмады';

  @override
  String get supplySelectAccountTitle => 'Шотты таңдаңыз';

  @override
  String get supplyAccountsNotFound => 'Шоттар табылмады';

  @override
  String supplyAccountBalance(String amount) {
    return 'Баланс: $amount';
  }

  @override
  String supplyProductNumber(String number) {
    return 'Тауар #$number';
  }

  @override
  String supplyProductCountLabel(int count) {
    return 'Тауарлар: $count';
  }

  @override
  String supplyTotalLabel(String amount) {
    return 'Барлығы: $amount';
  }

  @override
  String supplySavedSuccess(int count, String amount) {
    return 'Қабылдау сақталды. Тауарлар: $count, сома: $amount';
  }

  @override
  String get supplyCancelConfirm => 'Қабылдауды болдырмау керек пе?';

  @override
  String get supplyCancelMessage => 'Барлық енгізілген деректер жоғалады.';

  @override
  String get supplyYesCancel => 'Иә, болдырмау';

  @override
  String get supplySearchProduct => 'Тауар іздеу...';

  @override
  String get supplyAddProductsHint => 'Қабылдауға тауарлар қосыңыз';

  @override
  String get supplyScanOrSearch =>
      'Штрихкодты сканерлеңіз немесе тауарды табыңыз';

  @override
  String get refundTotalAmount => 'Қайтару сомасы';

  @override
  String get refundPosLabel => 'Касса';

  @override
  String refundSelectedOfTotal(String selected, String total) {
    return '$selected / $total';
  }

  @override
  String get refundTotalProducts => 'Барлық тауарлар';

  @override
  String get refundToReturn => 'ҚАЙТАРУҒА';

  @override
  String get refundToReturnLabel => 'Қайтаруға:';

  @override
  String get refundAction => 'ҚАЙТАРУ';

  @override
  String refundSelectedItemsShort(String selected, String total) {
    return '$selected / $total поз.';
  }

  @override
  String get refundColumnName => 'Атауы';

  @override
  String get refundColumnQty => 'Саны';

  @override
  String get refundEmptyHint =>
      'Чекті жүктеңіз немесе тауарларды қолмен қосыңыз';

  @override
  String get refundNoItemsShort => 'Тауарлар жоқ';

  @override
  String get refundEmptyHintShort =>
      'Чекті жүктеңіз немесе\nтауарларды қосыңыз';

  @override
  String refundSelectedCount(String count) {
    return 'Таңдалған позициялар: $count';
  }

  @override
  String refundAmountValue(String amount) {
    return 'Қайтару сомасы: $amount';
  }

  @override
  String get refundSuccess => 'Қайтару сәтті орындалды';

  @override
  String get paymentAmountDue => 'Төлеуге';

  @override
  String get paymentTotalDue => 'Барлығы төлеуге';

  @override
  String get paymentCashLabel => 'Қолма-қолмен';

  @override
  String get paymentReceived => 'Алынды';

  @override
  String get paymentRemainingLabel => 'Қалды';

  @override
  String paymentCardAmount(String amount) {
    return 'Картамен төлем $amount сомаға';
  }

  @override
  String get paymentLoyaltyProgram => 'Адалдық бағдарламасы';

  @override
  String get paymentPhoneNumber => 'Телефон нөмірі';

  @override
  String get paymentAvailableBonus => 'Қолжетімді бонустар:';

  @override
  String get paymentUseBonuses => 'Бонустарды пайдалану';

  @override
  String paymentBonusToDeduct(String amount) {
    return 'Есептен шығару: $amount бонус';
  }

  @override
  String get paymentSuccessMessage => 'Төлем сәтті';

  @override
  String get paymentRefundButton => 'ҚАЙТАРУ';

  @override
  String get paymentPayButton => 'ТӨЛЕУ';

  @override
  String get syncWidgetRetry => 'Қайталау';

  @override
  String syncWidgetLastSync(String time) {
    return 'Соңғы синхрондау: $time';
  }

  @override
  String syncWidgetRecordsCount(int count) {
    return '$count жазба';
  }

  @override
  String get syncWidgetWaiting => 'Күтуде';

  @override
  String get syncWidgetSynced => 'Синхрондалған';

  @override
  String get syncWidgetJustNow => 'жаңа ғана';

  @override
  String syncWidgetMinutesAgo(int minutes) {
    return '$minutes мин. бұрын';
  }

  @override
  String syncWidgetHoursAgo(int hours) {
    return '$hours сағ. бұрын';
  }

  @override
  String syncWidgetDaysAgo(int days) {
    return '$days күн бұрын';
  }

  @override
  String get syncWidgetConnecting => 'Серверге қосылуда...';

  @override
  String get syncWidgetSyncingProducts => 'Тауарларды синхрондау...';

  @override
  String get syncWidgetSyncingSales => 'Сатуларды синхрондау...';

  @override
  String get syncWidgetSyncingAgents => 'Контрагенттерді синхрондау...';

  @override
  String get syncWidgetSyncingPrices => 'Бағаларды синхрондау...';

  @override
  String get syncWidgetFinishing => 'Аяқталуда...';

  @override
  String get updateDialogUpdating => 'Жаңарту...';

  @override
  String get updateDialogAvailable => 'Жаңарту қол жетімді';

  @override
  String updateDialogAutoUpdate(int seconds) {
    return 'Автоматты жаңарту $seconds сек. кейін';
  }

  @override
  String get updateDialogUpdateNow => 'Қазір жаңарту';

  @override
  String get updateDialogLater => 'Кейін';

  @override
  String get updateDialogSkip => 'Өткізіп жіберу';

  @override
  String get updateDialogUpdate => 'Жаңарту';

  @override
  String storeUpdateVersion(String version) {
    return 'Нұсқа $version';
  }

  @override
  String storeUpdateNewVersionAvailable(String storeName) {
    return 'Қолданбаның жаңа нұсқасы $storeName ішінде қол жетімді.';
  }

  @override
  String get storeUpdateWhatsNew => 'Жаңалықтар:';

  @override
  String get storeUpdateRequired => 'Бұл міндетті жаңарту';

  @override
  String storeUpdateGoTo(String storeName) {
    return '$storeName ішіне өту';
  }

  @override
  String get storeUpdateButton => 'ЖАҢАРТУ';

  @override
  String get storeUpdateDownloaded => 'Жаңарту жүктелді';

  @override
  String get storeUpdateReadyToInstall =>
      'Жаңарту жүктелді және орнатуға дайын.\nҚазір орнату керек пе? Қолданба қайта іске қосылады.';

  @override
  String get storeUpdateInstall => 'ОРНАТУ';

  @override
  String get storeUpdateDownloading => 'Жаңартуды жүктеу...';

  @override
  String get storeUpdateReadyShort => 'Жаңарту орнатуға дайын';

  @override
  String get versionConflictTitle => 'Нұсқалар қайшылығы';

  @override
  String get versionConflictDescription =>
      'Қолданба нұсқаларының қайшылығы анықталды.';

  @override
  String get versionConflictCurrent => 'Ағымдағы нұсқа';

  @override
  String get versionConflictFound => 'Табылған нұсқа';

  @override
  String get versionConflictChooseAction => 'Әрекетті таңдаңыз:';

  @override
  String get versionConflictOpenFolder => 'Қалтада ашу';

  @override
  String get versionConflictPreviousVersion => 'Алдыңғы нұсқа';

  @override
  String get versionConflictContinue => 'Жалғастыру';

  @override
  String get restoreLoadingBackups => 'Бэкаптар жүктелуде...';

  @override
  String get restoreSearchingBackups => 'Бэкаптарды іздеу...';

  @override
  String restoreLoadError(String error) {
    return 'Жүктеу қатесі: $error';
  }

  @override
  String get restoreRestoring => 'Қалпына келтіру...';

  @override
  String get restoreRestoreError => 'Қалпына келтіру қатесі';

  @override
  String get restoreRestoreFailed => 'Бэкаптан қалпына келтіру сәтсіз аяқталды';

  @override
  String get restoreTitle => 'Қалпына келтіру';

  @override
  String get restoreChooseMethod => 'Баптау тәсілін таңдаңыз';

  @override
  String get restoreSetupNewPos => 'Жаңа кассаны баптау';

  @override
  String get restoreNoBackups => 'Бэкаптар табылмады';

  @override
  String get restoreSetupAsNew => 'Кассаны жаңадан баптаңыз';

  @override
  String get restoreFoundBackups => 'Табылған бэкаптар:';

  @override
  String get agentSearchByNameOrPhone => 'Аты немесе телефоны бойынша іздеу...';

  @override
  String get agentOnlyWithDebt => 'Тек қарызымен';

  @override
  String get agentTypeTooltip => 'Түрі';

  @override
  String agentBinLabel(String bin) {
    return 'БСН: $bin';
  }

  @override
  String agentSelectedMessage(String name) {
    return 'Таңдалды: $name';
  }

  @override
  String agentFoundCount(int count) {
    return 'Табылды: $count';
  }

  @override
  String get agentEnterNameOrPhoneToSearch =>
      'Іздеу үшін атын немесе телефонын енгізіңіз';

  @override
  String get agentNotFound => 'Клиенттер табылмады';

  @override
  String get agentSearchClients => 'Клиенттерді іздеу';

  @override
  String get agentNotFoundShort => 'Табылмады';

  @override
  String get agentEnterNameOrPhone => 'Атын немесе телефонын енгізіңіз';

  @override
  String get agentEnterCustomerName => 'Клиенттің атын енгізіңіз';

  @override
  String get agentDeletedCustomerPhone => 'Осы телефонмен клиент жойылған';

  @override
  String get agentWantRestore => 'Қалпына келтіру керек пе?';

  @override
  String get agentDeleteCustomerTitle => 'Клиентті жою керек пе?';

  @override
  String agentDeleteConfirmMessage(String name) {
    return '\"$name\" жоюға сенімдісіз бе?';
  }

  @override
  String agentCustomerDeleted(String name) {
    return 'Клиент \"$name\" жойылды';
  }

  @override
  String get cashOpTitle => 'Кассалық операция';

  @override
  String get cashOpComment => 'Түсініктеме';

  @override
  String get cashOpCommentRequired => 'Түсініктеме *';

  @override
  String get cashOpCommentHint => 'Түсініктеме енгізіңіз...';

  @override
  String cashOpError(String error) {
    return 'Қате: $error';
  }

  @override
  String get cashOpOperationType => 'Операция түрі';

  @override
  String get cashOpExpense => 'Шығыс';

  @override
  String get cashOpDividend => 'Алу';

  @override
  String get saleReceiptTotal => 'Чек бойынша жиынтығы';

  @override
  String get salePay => 'ТӨЛЕУ';

  @override
  String get saleTotalColon => 'Жиынтығы:';

  @override
  String salePositionsAndQuantity(int count, String qty) {
    return '$count поз. / $qty дана';
  }

  @override
  String get saleWholesale => 'КӨТЕРМЕ';

  @override
  String get saleRetail => 'Бөлшек';

  @override
  String get syncPreparing => 'Дайындалуда...';

  @override
  String errorSaveFailed(String details) {
    return 'Сақтау қатесі: $details';
  }

  @override
  String get errorSaveFailedGeneric => 'Сақтау қатесі';

  @override
  String errorLoadFailed(String details) {
    return 'Деректерді жүктеу қатесі: $details';
  }

  @override
  String get errorLoadFailedGeneric => 'Деректерді жүктеу қатесі';

  @override
  String errorSearchFailed(String details) {
    return 'Іздеу қатесі: $details';
  }

  @override
  String get errorSearchFailedGeneric => 'Іздеу қатесі';

  @override
  String get errorUnknownGeneric => 'Белгісіз қате';

  @override
  String get errorFillRequired => 'Барлық міндетті өрістерді толтырыңыз';

  @override
  String get errorNoUsers => 'Тіркелген пайдаланушылар жоқ';

  @override
  String get errorSelectUser => 'Пайдаланушыны таңдаңыз';

  @override
  String get errorPinTooShort => 'PIN кодты енгізіңіз (кемінде 4 сан)';

  @override
  String get errorRsaNotConfigured =>
      'Қате: RSA кілт бапталмаған. Әкімшіге хабарласыңыз.';

  @override
  String get errorWrongPin => 'Қате PIN код';

  @override
  String get errorAmbiguousPin =>
      'Бұл PIN код бірнеше кассирде бірдей. Атыңызды таңдап, содан кіріңіз.';

  @override
  String get errorNoPinSet =>
      'Бұл кассир үшін PIN код орнатылмаған. Оны орнату үшін әкімшіге хабарласыңыз.';

  @override
  String get errorWalkUpDisabled =>
      'Бұл нүктеде атын таңдамай кіру өшірілген. Тізімнен атыңызды таңдаңыз.';

  @override
  String get errorCredentialUnreadable =>
      'PIN код жазбасы бүлінген. Әкімшіге хабарласыңыз — қайта теру көмектеспейді.';

  @override
  String get errorAuthUnknown =>
      'Касса кіру әрекетіне жауап бере алмады. Қайта көріңіз.';

  @override
  String get errorTillNotConfigured =>
      'Касса әлі бапталмаған — баптау шебері аяқталмайынша кіру мүмкін емес.';

  @override
  String get errorTerminalLimitReached =>
      'Бұл кассада терминалдардың ең көп саны тіркелген. Орын босату үшін әкімшіге хабарласыңыз.';

  @override
  String get errorPairingCodeInvalid =>
      'Байланыстыру коды сәйкес келмеді — мерзімі өткен, бұрын пайдаланылған немесе қате терілген. Кассадан жаңа код алыңыз.';

  @override
  String get errorTerminalSecretInvalid =>
      'Бұл құрылғының байланысы енді жарамсыз — терминал кассадан өшірілген болуы мүмкін. Жаңа байланыстыру кодын енгізіңіз.';

  @override
  String get errorSessionExpired => 'Сеанс мерзімі өтті — қайта кіріңіз.';

  @override
  String get errorSessionEnded => 'Сеансты касса аяқтады — қайта кіріңіз.';

  @override
  String get errorSaleNotInitialized => 'Сатылым іске қосылмаған';

  @override
  String get errorReceiptEmpty => 'Чек бос';

  @override
  String get errorDeferredNotFound => 'Кейінге қалдырылған чек табылмады';

  @override
  String errorReceiptNotFound(String receiptNo) {
    return '#$receiptNo чек табылмады';
  }

  @override
  String get errorReceiptNotFoundGeneric => 'Чек табылмады';

  @override
  String get errorNotAuthorized => 'Пайдаланушы авторизацияланбаған';

  @override
  String get errorSupplierNotFound => 'Жеткізуші табылмады';

  @override
  String get errorAccountNotFound => 'Шот табылмады';

  @override
  String errorProductNotFound(String details) {
    return 'Тауар табылмады: $details';
  }

  @override
  String get errorProductNotFoundGeneric => 'Тауар табылмады';

  @override
  String get errorNameRequired => 'Аты міндетті';

  @override
  String get errorNameTooShort => 'Кемінде 2 таңба';

  @override
  String get errorPhoneInvalid => 'Телефон форматы дұрыс емес';

  @override
  String get errorBinInvalid => 'БИН/ЖСН 12 саннан тұруы тиіс';

  @override
  String get errorPhoneExists => 'Осындай телефоны бар клиент бар';

  @override
  String errorShiftOpenFailed(String details) {
    return 'Ауысымды ашу қатесі: $details';
  }

  @override
  String get errorShiftOpenFailedGeneric => 'Ауысымды ашу қатесі';

  @override
  String errorShiftCloseFailed(String details) {
    return 'Ауысымды жабу қатесі: $details';
  }

  @override
  String get errorShiftCloseFailedGeneric => 'Ауысымды жабу қатесі';

  @override
  String errorShiftLoadFailed(String details) {
    return 'Ауысым деректерін жүктеу қатесі: $details';
  }

  @override
  String get errorShiftLoadFailedGeneric => 'Ауысым деректерін жүктеу қатесі';

  @override
  String get errorPaymentConfig =>
      'Төлемді құрастыру мүмкін болмады. Шот параметрлерін тексеріңіз.';

  @override
  String get errorSaleSaveFailed => 'Сатылымды сақтау қатесі';

  @override
  String get errorInventoryCannotComplete => 'Аяқтау мүмкін емес';

  @override
  String get errorNoProducts => 'Есептен шығаруға тауарлар жоқ';

  @override
  String get errorSelectCountry => 'Елді таңдаңыз';

  @override
  String get errorEnterOrgName => 'Ұйым атауын енгізіңіз';

  @override
  String errorEnterTaxId(String label) {
    return '$label енгізіңіз';
  }

  @override
  String get errorEnterTaxIdGeneric => 'Салық нөмірін енгізіңіз';

  @override
  String errorTaxIdLength(String info) {
    return '$info';
  }

  @override
  String get errorTaxIdLengthGeneric => 'Салық нөмірінің ұзындығы дұрыс емес';

  @override
  String get errorEnterPosName => 'Касса атауын енгізіңіз';

  @override
  String get errorFillWebkassa => 'WebKassa барлық өрістерін толтырыңыз';

  @override
  String get errorFillOfd => 'ОФД барлық өрістерін толтырыңыз';

  @override
  String get errorEnterKaspiIp => 'Kaspi терминалының IP-мекенжайын енгізіңіз';

  @override
  String get errorEnterAdminName => 'Әкімші атын енгізіңіз';

  @override
  String get errorAdminPinShort =>
      'Әкімші PIN коды кемінде 4 саннан тұруы тиіс';

  @override
  String get errorSellerPinShort =>
      'Сатушы PIN коды кемінде 4 саннан тұруы тиіс';

  @override
  String errorCheckFailed(String details) {
    return 'Тексеру қатесі: $details';
  }

  @override
  String get errorCheckFailedGeneric => 'Тексеру қатесі';

  @override
  String get errorTelegramNotInitialized =>
      'TelegramInitializer іске қосылмаған';

  @override
  String get errorTelegramAuthNotInitialized =>
      'TelegramAuthService іске қосылмаған';

  @override
  String errorPhoneSendFailed(String details) {
    return 'Нөмірді жіберу қатесі: $details';
  }

  @override
  String get errorPhoneSendFailedGeneric => 'Нөмірді жіберу қатесі';

  @override
  String errorQrAuthFailed(String details) {
    return 'QR авторизация қатесі: $details';
  }

  @override
  String get errorQrAuthFailedGeneric => 'QR авторизация қатесі';

  @override
  String errorWrongCode(String details) {
    return 'Қате код: $details';
  }

  @override
  String get errorWrongCodeGeneric => 'Қате код';

  @override
  String errorWrongPassword(String details) {
    return 'Қате құпиясөз: $details';
  }

  @override
  String get errorWrongPasswordGeneric => 'Қате құпиясөз';

  @override
  String errorRegistrationFailed(String details) {
    return 'Тіркеу қатесі: $details';
  }

  @override
  String get errorRegistrationFailedGeneric => 'Тіркеу қатесі';

  @override
  String errorChannelSearchFailed(String details) {
    return 'Каналдарды іздеу қатесі: $details';
  }

  @override
  String get errorChannelSearchFailedGeneric => 'Каналдарды іздеу қатесі';

  @override
  String errorChannelConnectFailed(String details) {
    return 'Каналдарға қосылу қатесі: $details';
  }

  @override
  String get errorChannelConnectFailedGeneric => 'Каналдарға қосылу қатесі';

  @override
  String errorChannelCreateFailed(String details) {
    return 'Каналдарды құру қатесі: $details';
  }

  @override
  String get errorChannelCreateFailedGeneric => 'Каналдарды құру қатесі';

  @override
  String get errorFillClientData => 'Клиент деректерін толтырыңыз';

  @override
  String get shiftCashInvestments => 'Салымдар';

  @override
  String get shiftCashExpenses => 'Шығыстар';

  @override
  String get shiftCashDividends => 'Алымдар';

  @override
  String get shiftNoCashOps => 'Кассалық операциялар жоқ';

  @override
  String get shiftNoCashOpsDescription =>
      'Салымдар, шығыстар және алымдар\nмұнда көрсетіледі';

  @override
  String shiftMoreItems(int count) {
    return '+$count тағы';
  }

  @override
  String get shiftEqualsSystem => '= Жүйе';

  @override
  String get shiftBillsTotal => 'Купюралар бойынша:';

  @override
  String get receiptInputTitle => 'Чекті іздеу';

  @override
  String get receiptInputNumber => 'Чек нөмірі';

  @override
  String get receiptInputNumberHint => 'Мысалы: 12345';

  @override
  String get receiptInputPos => 'Касса';

  @override
  String get receiptInputInvalid => 'Дұрыс чек нөмірін енгізіңіз';

  @override
  String get receiptInputFind => 'Табу';

  @override
  String get paymentDenominations => 'Номиналдар';

  @override
  String get paymentExactAmount => 'Қайтарымсыз';

  @override
  String get paymentNumpad => 'Пернетақта';

  @override
  String get paymentIinLabel => 'ЖСН/БСН (міндетті емес)';

  @override
  String get paymentIinInvalid => 'Қате ЖСН/БСН';

  @override
  String get paymentIinHint =>
      'ЖСН — жеке тұлғалар үшін, БСН — заңды тұлғалар үшін';

  @override
  String get paymentIinShort => 'ЖСН/БСН';

  @override
  String get paymentTypeCash => 'Қолма-қол';

  @override
  String get paymentTypeCard => 'Қолма-қолсыз';

  @override
  String get paymentTypeMixed => 'Аралас';

  @override
  String get paymentAccount => 'Шот';

  @override
  String get authNoUsers => 'Тіркелген пайдаланушылар жоқ';

  @override
  String get authNoPin => 'PIN жоқ';

  @override
  String get authSelectUser => 'Пайдаланушыны таңдаңыз';

  @override
  String get authNoUsersShort => 'Пайдаланушылар жоқ';

  @override
  String get authEnterPin => 'PIN-кодты енгізіңіз';

  @override
  String updateVersion(String version) {
    return 'Нұсқа $version';
  }

  @override
  String get updateWhatsNew => 'Жаңалықтар';

  @override
  String get updateFixedIssues => 'Түзетілді';

  @override
  String get updateSize => 'Өлшемі';

  @override
  String get updateDate => 'Күні';

  @override
  String get updateMandatory => 'Бұл міндетті жаңарту';

  @override
  String updateLaterCountdown(int countdown) {
    return 'Кейінірек ($countdown)';
  }

  @override
  String get updateDownloading => 'Жаңарту жүктелуде';

  @override
  String get updateDownloadingFile => 'Жаңарту файлы жүктелуде...';

  @override
  String get updatePosNow => 'КАССАНЫ ЖАҢАРТУ';

  @override
  String get serviceAddNote => 'Белгі қосу';

  @override
  String get serviceClientLookup => 'Клиентті іздеу';

  @override
  String serviceOrderDetail(int orderId) {
    return 'Тапсырыс-наряд мәліметтері #$orderId';
  }

  @override
  String get paymentDefaultLabel => 'Әдепкі';

  @override
  String get currencySymbol => '₸';

  @override
  String get serviceIntakeTitle => 'Тапсырысты қабылдау';

  @override
  String get serviceIntakeClient => 'Клиент';

  @override
  String get serviceIntakeDevice => 'Құрылғы / Зат';

  @override
  String get serviceIntakeServices => 'Қызметтер';

  @override
  String get serviceIntakeDelivery => 'Жеткізу';

  @override
  String get serviceIntakePickup => 'Клиенттен алу';

  @override
  String get serviceIntakeSave => 'Сақтау';

  @override
  String get serviceIntakeCancel => 'Бас тарту';

  @override
  String get serviceQueueTitle => 'Тапсырыс-нарядтар';

  @override
  String get serviceQueueEmpty => 'Тапсырыс-нарядтар жоқ';

  @override
  String get serviceQueueSearch => 'Нөмір, клиент, құрылғы бойынша іздеу';

  @override
  String get serviceDetailTitle => 'Тапсырыс мәліметтері';

  @override
  String get serviceDetailInfo => 'Ақпарат';

  @override
  String get serviceDetailTimeline => 'Жұмыстар';

  @override
  String get serviceDetailCost => 'Құн';

  @override
  String get serviceDetailActions => 'Әрекеттер';

  @override
  String get serviceStatusIntake => 'Қабылдау';

  @override
  String get serviceStatusInProgress => 'Жұмыста';

  @override
  String get serviceStatusCompleted => 'Дайын';

  @override
  String get serviceStatusClosed => 'Жабық';

  @override
  String get serviceStatusCancelled => 'Бас тартылған';

  @override
  String get serviceMarkDiagnostic => 'Диагностика';

  @override
  String get serviceMarkReplacement => 'Бөлшек ауыстыру';

  @override
  String get serviceMarkRepair => 'Жөндеу';

  @override
  String get serviceMarkTesting => 'Тестілеу';

  @override
  String get serviceMarkOther => 'Басқа';

  @override
  String get serviceAddMark => 'Жұмыс қосу';

  @override
  String get serviceDeleteMark => 'Белгіні жою';

  @override
  String get serviceMarkDescription => 'Сипаттама';

  @override
  String get serviceMarkType => 'Жұмыс түрі';

  @override
  String get serviceMarkCost => 'Құн';

  @override
  String get serviceMarkNote => 'Ескертпе';

  @override
  String get serviceCatalogTitle => 'Қызметтер каталогі';

  @override
  String get serviceCatalogAdd => 'Қызмет қосу';

  @override
  String get serviceCatalogDuration => 'мин';

  @override
  String get serviceCatalogWarranty => 'Кепілдік (күн)';

  @override
  String get serviceCatalogRequiresDevice => 'Құрылғы қажет';

  @override
  String get serviceClientNew => 'Жаңа клиент';

  @override
  String get serviceClientPhone => 'Телефон';

  @override
  String get serviceClientName => 'Аты';

  @override
  String get serviceClientAddress => 'Мекенжай';

  @override
  String get serviceAssignTechnician => 'Шебер тағайындау';

  @override
  String get serviceReassignTechnician => 'Шеберді қайта тағайындау';

  @override
  String serviceTechnicianAssigned(String name) {
    return 'Шебер тағайындалды: $name';
  }

  @override
  String get serviceTechnicianSelect => 'Шебер таңдаңыз';

  @override
  String get servicePrepayment => 'Алдын ала төлем';

  @override
  String get servicePrepaymentAmount => 'Алдын ала төлем сомасы';

  @override
  String get serviceEstimatedDate => 'Күтілетін күн';

  @override
  String get serviceEstimatedAmount => 'Сома';

  @override
  String get servicePrintLabel => 'QR-жапсырма';

  @override
  String get servicePrintReceipt => 'Чек басып шығару';

  @override
  String get serviceProgressConfirm => 'Жұмысты бастау';

  @override
  String get serviceCancelConfirm => 'Бас тарту';

  @override
  String get serviceTotalCost => 'Жұмыс құны';

  @override
  String get servicePrepaid => 'Алдын ала төлем';

  @override
  String get serviceRemaining => 'Төлеуге';

  @override
  String get serviceDeliveryAddress => 'Жеткізу мекенжайы';

  @override
  String get serviceNeedsPickup => 'Клиенттен алу';

  @override
  String get serviceNeedsDelivery => 'Клиентке жеткізу';

  @override
  String serviceQrFormat(Object id, Object number) {
    return 'TELEPOS:SO:$id:$number';
  }

  @override
  String get serviceOrderCreated => 'Жаңа тапсырыс';

  @override
  String get serviceOrderUpdated => 'Өзгерту';

  @override
  String get serviceNoOrders => 'Деректер жоқ';

  @override
  String get serviceFilterAll => 'Барлығы';

  @override
  String get navCatalog => 'Каталог';

  @override
  String get catalogTitle => 'Тауарлар каталогы';

  @override
  String get catalogSearch => 'Іздеу';

  @override
  String get catalogSearchHint => 'Атауы немесе штрихкод';

  @override
  String get catalogFilterAll => 'Барлығы';

  @override
  String get catalogFilterProducts => 'Тауарлар';

  @override
  String get catalogFilterWeighted => 'Салмақтық';

  @override
  String get catalogFilterServices => 'Қызметтер';

  @override
  String get catalogFilterPackages => 'Жинақтар';

  @override
  String get catalogAddProduct => 'Тауар қосу';

  @override
  String get catalogEditProduct => 'Тауарды өзгерту';

  @override
  String get catalogDeleteProduct => 'Тауарды жою';

  @override
  String get catalogRestoreProduct => 'Тауарды қалпына келтіру';

  @override
  String get catalogProductName => 'Атауы';

  @override
  String get catalogBarcode => 'Штрихкод';

  @override
  String get catalogType => 'Түрі';

  @override
  String get catalogPrice => 'Сату бағасы';

  @override
  String get catalogWholesalePrice => 'Көтерме баға';

  @override
  String get catalogCategory => 'Санат';

  @override
  String get catalogMeasure => 'Өлшем бірлігі';

  @override
  String get catalogQuantity => 'Қалдық';

  @override
  String get catalogQuickProduct => 'Жылдам тауар';

  @override
  String get catalogAddToQuick => 'Жылдамға қосу';

  @override
  String get catalogRemoveFromQuick => 'Жылдамнан алып тастау';

  @override
  String get catalogNoProducts => 'Тауарлар жоқ';

  @override
  String get catalogDeleted => 'Жойылған';

  @override
  String catalogConfirmDelete(String name) {
    return '\"$name\" тауарын жою керек пе?';
  }

  @override
  String get catalogProductCreated => 'Тауар жасалды';

  @override
  String get catalogProductUpdated => 'Тауар жаңартылды';

  @override
  String get catalogProductDeleted => 'Тауар жойылды';

  @override
  String get catalogProductRestored => 'Тауар қалпына келтірілді';

  @override
  String get catalogShowDeleted => 'Жойылғандарды көрсету';

  @override
  String get catalogTypeNormal => 'Қарапайым';

  @override
  String get catalogTypeWeight => 'Салмақтық';

  @override
  String get catalogTypeInner => 'Ішкі';

  @override
  String get catalogTypePackage => 'Жинақ';

  @override
  String get catalogTypeService => 'Қызмет';

  @override
  String get catalogMeasurePiece => 'Дана';

  @override
  String get catalogMeasureKg => 'Килограмм';

  @override
  String get catalogMeasureLiter => 'Литр';

  @override
  String get catalogMeasureMeter => 'Метр';

  @override
  String get catalogNameRequired => 'Атауын енгізіңіз';

  @override
  String get catalogPriceRequired => 'Бағаны енгізіңіз';

  @override
  String get catalogPriceInvalid => 'Баға 0-ден жоғары болуы керек';

  @override
  String get catalogBarcodeExists => 'Бұл штрихкодпен тауар бар';

  @override
  String get catalogCategories => 'Санаттар';

  @override
  String get catalogAllCategories => 'Барлық санаттар';

  @override
  String get catalogNoCategories => 'Санаттар жоқ';

  @override
  String get catalogQuickProductCategory => 'Жылдам тауар санаты';

  @override
  String get catalogAddCategory => 'Санат қосу';

  @override
  String get catalogCategoryName => 'Санат атауы';

  @override
  String get catalogManageCategories => 'Санаттарды басқару';

  @override
  String get catalogCategoryHasProducts =>
      'Жою мүмкін емес: санатта тауарлар бар';

  @override
  String get catalogConfirmDeleteCategory => 'Санатты жою';

  @override
  String get catalogMenuCategories => 'Мәзір санаттары';

  @override
  String get catalogParentCategory => 'Ата-аналық санат';

  @override
  String get catalogRootCategory => 'Түбір (ата-анасыз)';

  @override
  String get telegramErrorPhoneSendFailed => 'Телефонға код жіберілмеді';

  @override
  String get telegramErrorQrAuthFailed => 'QR-код арқылы авторизация қатесі';

  @override
  String get telegramErrorWrongCode => 'Растау коды дұрыс емес';

  @override
  String get telegramErrorWrongPassword => 'Құпиясөз дұрыс емес';

  @override
  String get telegramErrorRegistrationFailed => 'Тіркелу қатесі';

  @override
  String get telegramErrorChannelSearchFailed => 'Арналарды іздеу қатесі';

  @override
  String get telegramErrorChannelConnectFailed => 'Арналарға қосылу қатесі';

  @override
  String get telegramErrorChannelCreateFailed => 'Арналарды құру қатесі';

  @override
  String get hwSettingsTitle => 'Жабдықтар';

  @override
  String get hwSettingsSubtitle => 'Сканер, дисплей, терминалдар';

  @override
  String get terminalServiceTitle => 'Браузер терминалдары';

  @override
  String get terminalServiceSubtitle =>
      'Планшет немесе телефон — жұмыс орны ретінде';

  @override
  String get terminalServiceEnable => 'Браузер терминалдарына қызмет көрсету';

  @override
  String get terminalServiceEnabledNote =>
      'Касса дүкен желісін тыңдайды. Терминалдар қосыла алады.';

  @override
  String get terminalServiceDisabledNote =>
      'Касса тек өзін тыңдайды. Желіге порт ашылмаған, терминалдар қосыла алмайды.';

  @override
  String get terminalServiceRestartNote =>
      'Өзгеріс касса қайта іске қосылғаннан кейін күшіне енеді.';

  @override
  String get terminalServiceAddress => 'Терминалға арналған мекенжай';

  @override
  String get terminalServiceAddressHint =>
      'Осы мекенжайды планшет браузерінде ашыңыз. Атау ашылмаса, кассаның IP-мекенжайын теріңіз.';

  @override
  String get pairingTitle => 'Терминалды тіркеу';

  @override
  String get pairingSubtitle => 'Жаңа құрылғы үшін код';

  @override
  String get pairingDisabledNote =>
      'Касса браузерлік терминалдарға қызмет көрсетпейді. Тіркеу коды үшін қызметті қосыңыз.';

  @override
  String get pairingDisabledAction => 'Терминал баптауларын ашу';

  @override
  String get pairingAddressLabel => 'Жаңа құрылғы үшін сілтеме';

  @override
  String get pairingAddressHint =>
      'Осы мекенжайды жаңа құрылғыда толығымен теріңіз немесе көшіріңіз — код онда бар.';

  @override
  String get pairingLinkPending =>
      'Сілтеме сіз кодты бергеннен кейін осында пайда болады.';

  @override
  String get pairingRestartNote =>
      'Терминал қызметі баптауларда қосулы, бірақ бұл касса онымен әлі қайта іске қосылған жоқ — мекенжай жауап бермейді. Кассаны қайта іске қосыңыз.';

  @override
  String get pairingMint => 'Код беру';

  @override
  String get pairingMintAgain => 'Жаңа код беру';

  @override
  String get pairingCodeLabel => 'Тіркеу коды';

  @override
  String pairingExpiresAt(String time) {
    return '$time дейін жарамды';
  }

  @override
  String get pairingOnceNote =>
      'Код тек қазір көрсетіледі — осы экраннан кетсеңіз, ол жоғалады. Жаңа код беру, егер бұрынғысы әлі пайдаланылмаса, оны күшінен айырады. Бұл код сілтемені ашқанда жұмсалады — құрылғыдағы кіру экраны содан кейін бөлек, екінші кодты сұрайды: сол сәтте жаңа код беріңіз.';

  @override
  String get enrolTitle => 'Терминалды байланыстыру';

  @override
  String get enrolInstructions =>
      'Бұл құрылғы әлі кассаға байланыстырылмаған. Операторды кассада «Терминалды байланыстыру» экранын ашуын сұраңыз да, сол жерде көрсетілген кодты енгізіңіз.';

  @override
  String get enrolCodeLabel => 'Байланыстыру коды';

  @override
  String get enrolSubmit => 'Байланыстыру';

  @override
  String get accountsSettingsTitle => 'Төлем шоттары';

  @override
  String get accountsSettingsSubtitle => 'Қолма-қол және карта шоттары';

  @override
  String get accountsSettingsAdd => 'Шот қосу';

  @override
  String get accountsSettingsEdit => 'Шотты өңдеу';

  @override
  String get accountsSettingsEmpty => 'Төлем шоттары бапталмаған';

  @override
  String get accountsSettingsName => 'Шот атауы';

  @override
  String get accountsSettingsType => 'Шот түрі';

  @override
  String get accountsSettingsTypePOS => 'Касса (қолма-қол)';

  @override
  String get accountsSettingsTypeBank => 'Банк (карта)';

  @override
  String get accountsSettingsTypeCash => 'Қолма-қол';

  @override
  String get accountsSettingsTypeSystem => 'Жүйелік';

  @override
  String get accountsSettingsTypeBonus => 'Бонустық';

  @override
  String get accountsSettingsTypeOther => 'Басқа';

  @override
  String get accountsSettingsBalance => 'Баланс';

  @override
  String get accountsSettingsVisible => 'POS';

  @override
  String get accountsSettingsVisibleToPos => 'POS-та көрінеді';

  @override
  String get hwSettingsSaved => 'Жабдық параметрлері сақталды';

  @override
  String get hwScannerTitle => 'Штрих-код сканері';

  @override
  String get hwScannerMode => 'Сканер режимі';

  @override
  String get hwScannerModeKeyboard => 'USB / пернетақта (wedge)';

  @override
  String get hwScannerModeSerial => 'Сериялық';

  @override
  String get hwScannerModeCamera => 'Камера';

  @override
  String get hwScannerModeHint => 'USB сканерлер осы режимде жұмыс істейді';

  @override
  String get hwScannerTimeout => 'Таймаут';

  @override
  String get hwScannerMinLength => 'Мин. ұзындық';

  @override
  String get hwScannerMaxLength => 'Макс. ұзындық';

  @override
  String get hwDisplayTitle => 'Сатып алушы дисплейі';

  @override
  String get hwDisplayModel => 'Үлгісі';

  @override
  String get hwDisplayModelLed8 => 'LED 8 таңба';

  @override
  String get hwDisplayModelVfd20 => 'VFD 20x2';

  @override
  String get hwDisplayPort => 'COM-порт';

  @override
  String get hwDisplayBaudRate => 'Жылдамдық';

  @override
  String get hwDisplayDisabled => 'Сатып алушы дисплейі өшірулі';

  @override
  String get hwDrawerTitle => 'Кассалық жәшік';

  @override
  String get hwDrawerMode => 'Ашу режимі';

  @override
  String get hwDrawerModePrinter => 'Принтер арқылы';

  @override
  String get hwDrawerModeSerial => 'Сериялық порт';

  @override
  String get hwDrawerPort => 'COM-порт';

  @override
  String get hwTerminalsTitle => 'Төлем терминалдары';

  @override
  String get hwTerminalIp => 'IP-мекенжай';

  @override
  String get hwTerminalPort => 'Порт';

  @override
  String get hwTerminalMerchantId => 'Merchant ID';

  @override
  String get hwTerminalTerminalId => 'Terminal ID';

  @override
  String get catalogExportCsv => 'Экспорт CSV';

  @override
  String get catalogImport => 'Импорт';

  @override
  String get catalogFilterColumn => 'Фильтр...';

  @override
  String catalogExportSuccess(String path) {
    return 'Экспортировано в $path';
  }

  @override
  String get catalogExportFailed => 'Ошибка экспорта';

  @override
  String get catalogImportResults => 'Результаты импорта';

  @override
  String catalogImportImported(int count) {
    return 'Импортировано: $count';
  }

  @override
  String catalogImportUpdated(int count) {
    return 'Обновлено: $count';
  }

  @override
  String catalogImportSkipped(int count) {
    return 'Пропущено: $count';
  }

  @override
  String get catalogImportErrors => 'Ошибки:';

  @override
  String get catalogTypeConsumable => 'Шығын материалы';

  @override
  String get catalogFilterConsumable => 'Шығындар';

  @override
  String get catalogFilterInner => 'Ішкі';

  @override
  String get serviceMarkConsumable => 'Шығын материалы';

  @override
  String get serviceConsumableSearch => 'Тауар / шығын материалын іздеу';

  @override
  String get serviceConsumableSelected => 'Таңдалған тауар';

  @override
  String get serviceQuickServicesTitle => 'Жылдам қызметтер';

  @override
  String get serviceQuickServicesEmpty => 'Жылдам қызметтер жоқ';

  @override
  String get serviceIntakeItems => 'Принимаемые предметы';

  @override
  String get serviceItemName => 'Что принимаете (предмет, вещь, устройство)';

  @override
  String get serviceItemDescription => 'Описание проблемы / пожелания клиента';

  @override
  String get serviceItemSerial => 'Серийный номер / маркировка';

  @override
  String get serviceItemAdd => 'Добавить предмет';

  @override
  String get serviceItemEmpty => 'Добавьте хотя бы один предмет';

  @override
  String serviceItemCount(int count) {
    return '$count шт.';
  }

  @override
  String get serviceClientQuickName => 'Имя клиента';

  @override
  String get serviceClientQuickPhone => 'Телефон клиента';

  @override
  String get serviceClientOrSearch => 'или найти в базе';

  @override
  String get catalogTypeDish => 'Тағам';

  @override
  String get catalogFilterDish => 'Тағамдар';

  @override
  String get dishCalculation => 'Калькуляция';

  @override
  String get dishCalculationStub =>
      'Калькуляция модулі кейін қолжетімді болады';

  @override
  String get dishIngredients => 'Ингредиенттер';

  @override
  String get serviceConsumablesTitle => 'Шығын нормалары';

  @override
  String get serviceConsumablesEmpty => 'Шығын материалдары жоқ';

  @override
  String get serviceConsumablesAdd => 'Шығынды қосу';

  @override
  String get serviceConsumableQuantity => '1 қызметке саны';

  @override
  String get serviceConsumablesAutoAdded => 'Шығындар автоматты түрде қосылды';

  @override
  String get catalogDescription => 'Сипаттама';

  @override
  String get catalogImagePlaceholder => 'Фото жүктеу үшін басыңыз';

  @override
  String get catalogImageFromGallery => 'Выбрать из галереи';

  @override
  String get catalogImageFromCamera => 'Сделать фото';

  @override
  String get catalogImageRemove => 'Удалить фото';

  @override
  String get catalogImagePickError => 'Не удалось загрузить фото';

  @override
  String get globalRetry => 'Қайталау';

  @override
  String get globalRefresh => 'Жаңарту';

  @override
  String get globalReset => 'Тазалау';

  @override
  String get globalApply => 'Қолдану';

  @override
  String get globalCreate => 'Жасау';

  @override
  String get stockOpSupply => 'Қабылдау';

  @override
  String get stockOpMovement => 'Ауыстыру';

  @override
  String get stockOpSupplierReturn => 'Жеткізушіге қайтару';

  @override
  String get stockOpMovementShort => 'Ауыс.';

  @override
  String get stockOpReturnShort => 'Қайтару';

  @override
  String get stockRegistryTitle => 'Қойма операциялары';

  @override
  String get stockRegistryAppBarTitle => 'Қойма';

  @override
  String get stockRegistryLoadError => 'Тізілімді жүктеу мүмкін болмады';

  @override
  String get stockRegistryResetFilters => 'Сүзгілерді тазалау';

  @override
  String get stockRegistryFilters => 'Сүзгілер';

  @override
  String get stockRegistryEmpty => 'Жазбалар жоқ';

  @override
  String get stockRegistryEmptyFiltered => 'Сүзгі параметрлерін өзгертіңіз';

  @override
  String get stockRegistryEmptyCreate => 'Алғашқы қойма операциясын жасаңыз';

  @override
  String get stockRegistryPeriod => 'Кезең';

  @override
  String get stockRegistryOperationType => 'Операция түрі';

  @override
  String get stockRegistrySearchHint => 'Нөмір, контрагент бойынша іздеу...';

  @override
  String get stockRegistryDateFrom => 'Бастап';

  @override
  String get stockRegistryDateTo => 'Дейін';

  @override
  String get stockRegistryColType => 'Түрі';

  @override
  String get stockRegistryColNumber => 'Нөмір';

  @override
  String get stockRegistryColCounterparty => 'Контрагент / Қойма';

  @override
  String get stockRegistryColProducts => 'Тауарлар';

  @override
  String get stockRegistryColStatus => 'Күйі';

  @override
  String get stockSyncDraft => 'Жұмыста';

  @override
  String get stockSyncPending => 'Күтуде';

  @override
  String get stockSyncSending => 'Жіберілуде';

  @override
  String get stockSyncSynced => 'Синхр.';

  @override
  String stockRegistryDetailType(String type) {
    return 'Түрі: $type';
  }

  @override
  String stockRegistryDetailDate(String date) {
    return 'Күні: $date';
  }

  @override
  String stockRegistryDetailCounterparty(String name) {
    return 'Контрагент: $name';
  }

  @override
  String stockRegistryDetailAmount(String amount) {
    return 'Сома: $amount';
  }

  @override
  String stockRegistryDetailProducts(int count) {
    return 'Тауарлар: $count';
  }

  @override
  String stockRegistryDetailComment(String comment) {
    return 'Түсініктеме: $comment';
  }

  @override
  String stockRegistryProductsShort(int count) {
    return '$count тау.';
  }

  @override
  String stockRegistryPaginationRange(int from, int to, int total) {
    return '$from–$to / $total';
  }

  @override
  String get stockCreateSupplyTitle => 'Жаңа қабылдау';

  @override
  String get stockCreateSupplySubtitle => 'Жеткізушіден тауар қабылдау';

  @override
  String get stockCreateMovementSubtitle => 'Қоймалар арасында ауыстыру';

  @override
  String get stockCreateReturnSubtitle => 'Тауарды жеткізушіге қайтару';

  @override
  String get stockCreateWriteoffSubtitle =>
      'Списание товара (бой, порча, просрочка)';

  @override
  String get stockCreateInventorySubtitle => 'Пересчёт фактических остатков';

  @override
  String get serviceQueueActive => 'Белсенді';

  @override
  String get serviceScanQrTitle => 'Тапсырыс QR-белгісін сканерлеу';

  @override
  String get serviceScanQrHint => 'TELEPOS:SO:... немесе тапсырыс нөмірі';

  @override
  String get serviceIntakePhotos => 'Қабылдау фотосы';

  @override
  String get serviceIntakePhotosHint =>
      'Қабылданатын заттардың фотосын түсіріңіз';

  @override
  String get expenseTypeOther => 'Басқа';

  @override
  String get expenseTypeSmallPurchases => 'Ұсақ сатып алу';

  @override
  String get expenseTypeSalary => 'Жалақы';

  @override
  String get expenseTypeUtilities => 'Коммуналдық';

  @override
  String get expenseTypeCollection => 'Инкассация';

  @override
  String get expenseTypeCustom => 'Теңшелетін';

  @override
  String get networkTitle => 'Желі және қосылымдар';

  @override
  String get networkUnavailableTitle =>
      'Тек TelePOS OS құрылғысында қолжетімді';

  @override
  String get networkUnavailableDesc =>
      'telepos-sysd жүйелік демоны табылмады. Желіні басқару тек POS TelePOS OS құрылғысында іске қосылғанда жұмыс істейді.';

  @override
  String get networkRefresh => 'Жаңарту';

  @override
  String get networkSearch => 'Іздеу';

  @override
  String get networkConnect => 'Қосылу';

  @override
  String get networkDisconnect => 'Ажырату';

  @override
  String get networkConnected => 'Қосылды';

  @override
  String get networkEthernetTitle => 'Сымды желі (Ethernet)';

  @override
  String get networkEthernetDesc =>
      'Кабельдік қосылым күйі және интернетке қолжетімділік.';

  @override
  String get networkCableLabel => 'Кабель';

  @override
  String get networkCableConnected => 'Қосылды';

  @override
  String get networkCableNotConnected => 'Қосылмаған';

  @override
  String get networkInternetLabel => 'Интернет';

  @override
  String get networkInternetAvailable => 'Қолжетімді';

  @override
  String get networkInternetUnavailable => 'Қолжетімсіз';

  @override
  String get networkWifiTitle => 'Wi-Fi';

  @override
  String get networkWifiDesc => 'Сымсыз желіге қосылу.';

  @override
  String get networkWifiSearchHint =>
      'Желілерді табу үшін «Іздеу» түймесін басыңыз.';

  @override
  String get networkBluetoothTitle => 'Bluetooth';

  @override
  String get networkBluetoothDesc =>
      'Принтерлермен, таразылармен және басқа құрылғылармен жұптау.';

  @override
  String get networkBluetoothSearchHint =>
      'Құрылғыларды табу үшін «Іздеу» түймесін басыңыз.';

  @override
  String get networkBluetoothUnavailableInBrowser =>
      'Браузерде қолжетімсіз — Bluetooth тек кассаның өзінде теңшеледі.';

  @override
  String networkWifiPasswordTitle(String ssid) {
    return '«$ssid» үшін құпиясөз';
  }

  @override
  String get networkWifiPasswordLabel => 'Wi-Fi құпиясөзі';

  @override
  String networkConnectedTo(String ssid) {
    return '$ssid желісіне қосылды';
  }

  @override
  String networkConnectFailed(String ssid) {
    return '$ssid желісіне қосыла алмады';
  }

  @override
  String networkPaired(String device) {
    return 'Жұпталды: $device';
  }

  @override
  String get networkPairFailed => 'Жұптау сәтсіз аяқталды';

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
  String get applianceTitle => 'Жүйе (TelePOS OS)';

  @override
  String get applianceHubSubtitle => 'Жүйені басқару, желі, драйверлер';

  @override
  String get applianceUnavailableDesc =>
      'telepos-sysd жүйелік демоны табылмады. Бұл бөлім тек POS TelePOS OS құрылғысында іске қосылғанда жұмыс істейді.';

  @override
  String get applianceNetworkTitle => 'Желі және қосылымдар';

  @override
  String get applianceNetworkDesc =>
      'Wi-Fi, сымды желі және Bluetooth. Кіру мен синхрондау үшін қажет.';

  @override
  String get applianceNetworkButton => 'Желіні баптау';

  @override
  String get applianceDesktopTitle => 'Жұмыс үстелі режимі';

  @override
  String get applianceDesktopDesc =>
      'Қолданбаларды орнату және қызмет көрсетуге арналған толық жұмыс үстелі.';

  @override
  String get applianceCurrentMode => 'Ағымдағы режим: ';

  @override
  String get applianceOpenDesktop => 'Жұмыс үстелін ашу';

  @override
  String get applianceDesktopUnavailable =>
      'Бұл құрастыруда жұмыс үстелі қолжетімсіз.';

  @override
  String get applianceModeKiosk => 'Касса (POS)';

  @override
  String get applianceModeDesktop => 'Жұмыс үстелі';

  @override
  String get applianceDriversTitle => 'Перифериялық драйверлер';

  @override
  String get applianceDriversDesc =>
      'Принтерлер, таразылар және төлем терминалдарының драйверлерін сенімді TelePOS каталогынан орнату.';

  @override
  String get applianceDriversEmpty => 'Драйверлер каталогы бос.';

  @override
  String get applianceDriverInstall => 'Орнату';

  @override
  String get applianceDriverRemove => 'Жою';

  @override
  String applianceDriverInstalled(String title) {
    return 'Драйвер орнатылды: $title';
  }

  @override
  String applianceDriverRemoved(String title) {
    return 'Драйвер жойылды: $title';
  }

  @override
  String applianceError(String message) {
    return 'Қате: $message';
  }

  @override
  String get navNetwork => 'Желі';

  @override
  String get navCollapseMenu => 'Мәзірді жию';

  @override
  String get navExpandMenu => 'Мәзірді жаю';

  @override
  String get languageSwitcherTooltip => 'Тіл / Язык / Language';

  @override
  String get labelPrinterSettingsTitle => 'Жапсырма принтері';

  @override
  String get labelPrinterSettingsSubtitle => 'Бағалар мен штрих-кодтар';

  @override
  String get labelPrinterLanguage => 'Принтер тілі';

  @override
  String get labelPrinterSize => 'Жапсырма өлшемі';

  @override
  String get labelPrinterWidthMm => 'Ені, мм';

  @override
  String get labelPrinterHeightMm => 'Биіктігі, мм';

  @override
  String get labelPrinterTestSuccess => 'Жапсырма басып шығаруға жіберілді';

  @override
  String get labelPrinterNotConfigured =>
      'Жапсырма принтері бапталмаған. Параметрлерде мекенжайды көрсетіңіз.';

  @override
  String get labelTemplatesTitle => 'Жапсырма үлгілері';

  @override
  String get labelTemplatesManage => 'Үлгілерді басқару';

  @override
  String get labelTemplatesManageSubtitle => 'Жаймаларды құру және өңдеу';

  @override
  String get labelTemplatesEmpty => 'Үлгілер табылмады';

  @override
  String get labelTemplateNew => 'Жаңа үлгі';

  @override
  String get labelTemplateEdit => 'Үлгіні өңдеу';

  @override
  String get labelTemplateBuiltIn => 'Кірістірілген';

  @override
  String get labelMmUnit => 'мм';

  @override
  String get labelTemplateDeleteTitle => 'Үлгіні жою';

  @override
  String labelTemplateDeleteConfirm(String name) {
    return '«$name» үлгісін жою керек пе?';
  }

  @override
  String get labelTemplateName => 'Үлгі атауы';

  @override
  String get labelTemplateNameRequired => 'Үлгі атауын енгізіңіз';

  @override
  String get labelTemplatePreview => 'Алдын ала қарау';

  @override
  String get labelTemplateFields => 'Өрістер';

  @override
  String get labelTemplateAddField => 'Өріс қосу';

  @override
  String get labelTemplateNoFields => 'Өрістер жоқ. Кемінде бір өріс қосыңыз.';

  @override
  String get labelFieldKind => 'Өріс түрі';

  @override
  String get labelFieldText => 'Мәтін';

  @override
  String get labelFieldFontSize => 'Қаріп';

  @override
  String get labelFieldBold => 'Қалың';

  @override
  String get labelFieldKindName => 'Атауы';

  @override
  String get labelFieldKindPrice => 'Бағасы';

  @override
  String get labelFieldKindBarcode => 'Штрих-код';

  @override
  String get labelFieldKindSku => 'Артикул';

  @override
  String get labelFieldKindDate => 'Күні';

  @override
  String get labelFieldKindText => 'Мәтін';

  @override
  String get labelPrintTitle => 'Баға басып шығару';

  @override
  String labelPrintBulkTitle(int count) {
    return 'Бағаларды басып шығару ($count)';
  }

  @override
  String get labelPrintChooseTemplate => 'Үлгіні таңдаңыз';

  @override
  String get labelPrintCopies => 'Көшірмелер';

  @override
  String get labelPrintAction => 'Басып шығару';

  @override
  String labelPrintedCount(int count) {
    return 'Басып шығарылды: $count';
  }

  @override
  String get catalogPrintLabel => 'Баға басып шығару';

  @override
  String get receiptTemplatesTitle => 'Чек үлгілері';

  @override
  String get receiptTemplatesSubtitle =>
      'Чек безендірілуі: логотип, тақырып/төменгі, БСН, QR, ені';

  @override
  String get receiptTemplatesEmpty => 'Үлгілер табылмады';

  @override
  String get receiptTemplateNew => 'Жаңа үлгі';

  @override
  String get receiptTemplateEdit => 'Үлгіні өңдеу';

  @override
  String get receiptTemplateBuiltIn => 'Кірістірілген';

  @override
  String get receiptTemplateActive => 'Белсенді';

  @override
  String get receiptTemplateMakeActive => 'Белсенді ету';

  @override
  String get receiptTemplateName => 'Үлгі атауы';

  @override
  String get receiptTemplateNameRequired => 'Үлгі атауын енгізіңіз';

  @override
  String get receiptTemplatePreview => 'Алдын ала қарау';

  @override
  String get receiptTemplatePaperWidth => 'Қағаз ені';

  @override
  String get receiptTemplateContent => 'Чек мазмұны';

  @override
  String get receiptTemplateHeaderFooter => 'Тақырып және төменгі деректеме';

  @override
  String get receiptTemplateHeaderText => 'Тақырып мәтіні';

  @override
  String get receiptTemplateFooterText => 'Төменгі деректеме мәтіні';

  @override
  String get receiptTemplateExtraFooter => 'Қосымша төменгі жолдар';

  @override
  String get receiptTemplateExtraFooterHint =>
      'Әрқайсысы жеке жол (мысалы, қайтару шарттары)';

  @override
  String get receiptTemplateShowBin => 'БСН/ЖСН басып шығару';

  @override
  String get receiptTemplateShowAddress => 'Мекенжайды басып шығару';

  @override
  String get receiptTemplateShowCashier => 'Касса/кассирді басып шығару';

  @override
  String get receiptTemplateShowVat => 'ҚҚС басып шығару';

  @override
  String get receiptTemplateShowQr => 'Тексеру сілтемесін басып шығару (QR)';

  @override
  String get receiptTemplateShowItemNumbers => 'Позицияларды нөмірлеу';

  @override
  String get receiptTemplateShowLogo => 'Логотипті басып шығару';

  @override
  String get receiptTemplateTestPrint => 'Сынақ басып шығару';

  @override
  String get receiptTemplateTestPrintOk =>
      'Чек үлгісі басып шығаруға жіберілді';

  @override
  String get receiptTemplateTestPrintFail =>
      'Басып шығару сәтсіз (принтерді тексеріңіз)';

  @override
  String get receiptTemplateDeleteTitle => 'Үлгіні жою';

  @override
  String receiptTemplateDeleteConfirm(String name) {
    return '«$name» үлгісін жою керек пе?';
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
      'Бұл құрылғыда басқарылатын экран жоқ (backlight жоқ). Жарықтық пен бұрылысты монитордың өзінде реттеңіз.';

  @override
  String get sysmRotation => 'Поворот экрана';

  @override
  String get sysmRemoteTitle => 'Удалённая поддержка';

  @override
  String get sysmRemoteDesc =>
      'Временный защищённый доступ для службы поддержки';

  @override
  String get sysmRemoteHelp =>
      '«Қолдауды қалпына келтіру» TelePOS қолдау қызметіне ақауды қашықтан шешу үшін приставкаға уақытша қорғалған (SSH) арна ашады. Қолжетімділік 30 минуттан кейін автоматты түрде жабылады. Тек қолдау сұраған кезде ғана қосыңыз.';

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
  String get sysmTermGroupNetwork => 'Желі';

  @override
  String get sysmTermGroupSystem => 'Жүйе';

  @override
  String get sysmTermGroupTime => 'Уақыт';

  @override
  String get sysmTermDiagOsAndDaemon => 'ОЖ және демон нұсқасы';

  @override
  String get sysmTermDiagNetworkStatus => 'Желі: күй және мекенжай';

  @override
  String get sysmTermDiagNetworkConnectivity => 'Желі: байланыс';

  @override
  String get sysmTermDiagHardware => 'Жабдық: диск/жад/принтерлер';

  @override
  String get sysmTermPrinterFixAuto => 'Принтерді жөндеу (авто)';

  @override
  String get sysmTermPrinterDiag => 'Принтер диагностикасы';

  @override
  String get sysmTermPrinterLoadUsblp => 'usblp модулін жүктеу';

  @override
  String get sysmTermPrinterNodesAndPerms => 'Принтер түйіндері мен рұқсаттар';

  @override
  String get sysmTermPrinterLsusb => 'USB құрылғылары (lsusb)';

  @override
  String get sysmTermPrinterCupsStatus => 'CUPS: күй және кезектер';

  @override
  String get sysmTermPrinterGiveToKernel => 'Принтерді ядроға беру (usblp)';

  @override
  String get sysmTermPrinterTestPrint => '/dev/usb/lp0 сынақ басып шығару';

  @override
  String get sysmTermNetDeviceStatus => 'Құрылғылар күйі';

  @override
  String get sysmTermNetIpAddresses => 'IP мекенжайлары';

  @override
  String get sysmTermNetConnectEthernet => 'Ethernet қосу';

  @override
  String get sysmTermNetReload => 'Желіні қайта жүктеу';

  @override
  String get sysmTermNetPing => 'Пинг 8.8.8.8';

  @override
  String get sysmTermSysDisk => 'Диск';

  @override
  String get sysmTermSysMemory => 'Жад';

  @override
  String get sysmTermSysSysdStatus => 'telepos-sysd күйі';

  @override
  String get sysmTermSysKioskLogs => 'Киоск журналдары';

  @override
  String get sysmTermTimeDateTime => 'Күн және уақыт';

  @override
  String get sysmTermTimeNtpSync => 'NTP синхрондау';

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
      'Жазып беру деректемелері (ЭЦҚ, қосылым, токен) WebKassa (Фискализация) баптауларынан алынады — бір ортақ конфиг. ЭШФ деректемелерін бөлек баптау қажет емес.';

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
      'Қосылым деректемелері (логин, apiKey, касса, ЭЦҚ) WebKassa (Фискализация) баптауларынан алынады — бір ортақ конфиг.';

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
  String get ismptSettingsTitle => 'ИС МПТ баптаулары';

  @override
  String get ismptSettingsSubtitle => 'Таңбалау (Честный знак KZ)';

  @override
  String get ismptSettingsOperator => 'Оператор / жіберу әдісі';

  @override
  String get ismptSettingsEnable => 'ИС МПТ қосу';

  @override
  String get ismptSettingsEnableSubtitle =>
      'Таңбалау кодтарын тексеру және жіберу (ismet.kz / Tañba)';

  @override
  String get ismptSettingsBackend => 'Бэкенд';

  @override
  String get ismptSettingsTestMode => 'Сынақ режимі';

  @override
  String get ismptSettingsRequisites => 'Салық төлеуші деректемелері';

  @override
  String get ismptSettingsOwnBin => 'БСН / ЖСН (біздің)';

  @override
  String get ismptSettingsApi => 'True API (ismet.kz)';

  @override
  String get ismptSettingsApiUrl => 'API URL';

  @override
  String get ismptSettingsApiKey => 'API кілті / токен';

  @override
  String get ismptSettingsEcp => 'ЭЦҚ (ҚР ҰКО)';

  @override
  String get ismptSettingsCertPath => 'ЭЦҚ кілтінің жолы';

  @override
  String get ismptSettingsCertPassword => 'Кілт құпиясөзі';

  @override
  String get ismptSettingsEcpHint =>
      'ИС МПТ-мен нақты жұмыс ҚР ҰКО ЭЦҚ-сын және тіркелген қатысушы профилін талап етеді. ЭЦҚ-сыз таңбалау кодтары қабылданып, жергілікті сақталады (қабылдау офлайн жұмыс істейді, сату ешқашан бұғатталмайды).';

  @override
  String get ismptSettingsSharedEsfHint =>
      'ИС МПТ мен ЭШФ — МКД ішкі жүйелері. БСН мен ЭЦҚ-ны ЭШФ экранынан баптауға болады.';

  @override
  String get ismptSettingsWebkassaNote =>
      'Таңбалау кодтарын тексеру WebKassa арқылы жүреді. Қосылым деректемелері (логин, apiKey, касса, ЭЦҚ) WebKassa (Фискализация) баптауларынан алынады — бір ортақ конфиг.';

  @override
  String get ismptSettingsOpenEsf => 'ЭШФ баптаулары';

  @override
  String get ismptSettingsSave => 'Сақтау';

  @override
  String get ismptSettingsSaved => 'ИС МПТ баптаулары сақталды';

  @override
  String get ismptSettingsSaveError =>
      'ИС МПТ баптауларын сақтау мүмкін болмады';

  @override
  String get ismptSettingsBinRequired =>
      'Салық төлеушінің БСН / ЖСН-ін көрсетіңіз';

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
  String get catalogPageFirst => 'Бірінші';

  @override
  String get catalogPagePrev => 'Артқа';

  @override
  String get catalogPageNext => 'Алға';

  @override
  String get catalogPageLast => 'Соңғы';

  @override
  String get catalogGoToPage => 'Бетке өту';

  @override
  String catalogPageOf(int total) {
    return '$total ішінен бет';
  }

  @override
  String get shiftClosedGateTitle => 'Ауысым жабық';

  @override
  String get shiftClosedGateMessage =>
      'Операцияларды жалғастыру үшін ауысымды ашыңыз.';

  @override
  String get shiftClosedGateOpen => 'Ауысымды ашу';

  @override
  String get sysmTerminalPresetsDiag => 'Диагностика';

  @override
  String get wmsDashboardTitle => 'WMS — Қойманы басқару';

  @override
  String get wmsDashboardTitleShort => 'WMS — Қойма';

  @override
  String get wmsSettings => 'WMS баптаулары';

  @override
  String get wmsSettingsSubtitle => 'Модульдер конфигурациясы';

  @override
  String get wmsModuleWarehouses => 'Қоймалар';

  @override
  String get wmsModuleWarehousesSubtitle => 'Қоймалар, аймақтар, ұяшықтар';

  @override
  String get wmsModuleBatches => 'Партиялар';

  @override
  String get wmsModuleBatchesSubtitle => 'Партиялық есеп';

  @override
  String get wmsModuleCellStock => 'Ұяшық қалдықтары';

  @override
  String get wmsModuleCellStockSubtitle => 'Қалдықтар, орналастыру, іріктеу';

  @override
  String get wmsModuleSerials => 'Сериялық есеп';

  @override
  String get wmsModuleSerialsSubtitle => 'Сериялық нөмірлер';

  @override
  String get wmsModuleMarking => 'Таңбалау';

  @override
  String get wmsModuleMarkingSubtitle => 'Таңбалау кодтары';

  @override
  String get wmsModuleClaims => 'Шағымдар';

  @override
  String get wmsModuleClaimsSubtitle => 'Талаптар мен қайтарулар';

  @override
  String get wmsWarehousesAndCells => 'Қоймалар мен ұяшықтар';

  @override
  String get wmsWarehouses => 'Қоймалар';

  @override
  String get wmsAddWarehouse => 'Қойма қосу';

  @override
  String get wmsNoWarehouses => 'Қоймалар жоқ';

  @override
  String get wmsNoName => 'Атауы жоқ';

  @override
  String get wmsZones => 'Аймақтар';

  @override
  String wmsZonesNamed(String name) {
    return 'Аймақтар: $name';
  }

  @override
  String get wmsAddZone => 'Аймақ қосу';

  @override
  String get wmsSelectWarehouse => 'Қойманы таңдаңыз';

  @override
  String get wmsNoZones => 'Аймақтар жоқ';

  @override
  String get wmsCells => 'Ұяшықтар';

  @override
  String wmsCellsNamed(String name) {
    return 'Ұяшықтар: $name';
  }

  @override
  String get wmsGenerate => 'Генерациялау';

  @override
  String get wmsSelectZone => 'Аймақты таңдаңыз';

  @override
  String get wmsNoCells => 'Ұяшықтар жоқ';

  @override
  String get wmsNoAddress => 'Мекенжайы жоқ';

  @override
  String get wmsCellBlocked => 'Бұғатталған';

  @override
  String wmsCellsCount(int count) {
    return '$count ұяшық';
  }

  @override
  String get wmsNewWarehouse => 'Жаңа қойма';

  @override
  String get wmsWarehouseCode => 'Қойма коды';

  @override
  String get wmsName => 'Атауы';

  @override
  String get wmsError => 'Қате';

  @override
  String get wmsCreate => 'Жасау';

  @override
  String get wmsSelectWarehouseFirst => 'Алдымен қойманы таңдаңыз';

  @override
  String get wmsNewZone => 'Жаңа аймақ';

  @override
  String get wmsZoneCode => 'Аймақ коды';

  @override
  String get wmsSelectZoneFirst => 'Алдымен аймақты таңдаңыз';

  @override
  String get wmsGenerateCells => 'Ұяшықтарды генерациялау';

  @override
  String get wmsRows => 'Қатарлар';

  @override
  String get wmsRacks => 'Сөрелер';

  @override
  String get wmsLevels => 'Деңгейлер';

  @override
  String get wmsBins => 'Ұяшықтар';

  @override
  String get wmsEditWarehouse => 'Қойманы өңдеу';

  @override
  String get wmsAddress => 'Мекенжай';

  @override
  String get wmsDeleteWarehouseTitle => 'Қойманы жою керек пе?';

  @override
  String wmsDeleteWarehouseConfirm(String name) {
    return '\"$name\" қоймасын жойғыңыз келетініне сенімдісіз бе?';
  }

  @override
  String get wmsCellStockTitle => 'Ұяшық қалдықтары';

  @override
  String get wmsPlace => 'Орналастыру';

  @override
  String get wmsPick => 'Іріктеу';

  @override
  String get wmsTransfer => 'Жылжыту';

  @override
  String get wmsByCell => 'Ұяшық бойынша';

  @override
  String get wmsByProduct => 'Тауар бойынша';

  @override
  String get wmsSearchCellHint => 'Ұяшық ID немесе мекенжайын енгізіңіз...';

  @override
  String get wmsSearchProductHint => 'Тауар ucode енгізіңіз...';

  @override
  String get wmsCell => 'Ұяшық';

  @override
  String get wmsProductUcode => 'Тауар коды (ucode)';

  @override
  String get wmsFind => 'Табу';

  @override
  String get wmsEnterCellIdToSearch =>
      'Қалдықтарды іздеу үшін ұяшық ID енгізіңіз';

  @override
  String get wmsEnterUcodeToSearch => 'Іздеу үшін тауар ucode енгізіңіз';

  @override
  String wmsProductLabeled(String value) {
    return 'Тауар: $value';
  }

  @override
  String wmsCellLabeled(String value) {
    return 'Ұяшық: $value';
  }

  @override
  String wmsStockSummary(String qty, String reserved, String available) {
    return 'Саны: $qty  |  Резерв: $reserved  |  Қолжетімді: $available';
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
  String get wmsAvailable => 'Қолжетімді';

  @override
  String get wmsBatch => 'Партия';

  @override
  String get wmsEnterNumericId => 'Сандық ID енгізіңіз';

  @override
  String get wmsPlaceStockTitle => 'Тауарды ұяшыққа орналастыру';

  @override
  String get wmsCellId => 'Ұяшық ID';

  @override
  String get wmsProductUcodeField => 'Тауар ucode';

  @override
  String get wmsQuantity => 'Саны';

  @override
  String get wmsBatchIdOptional => 'Партия ID (міндетті емес)';

  @override
  String get wmsFillRequiredNumericFields =>
      'Міндетті өрістерді толтырыңыз (сандық мәндер)';

  @override
  String wmsStockPlaced(String cellId) {
    return 'Тауар $cellId ұяшығына орналастырылды';
  }

  @override
  String get wmsPlaceError => 'Орналастыру қатесі';

  @override
  String get wmsPickStockTitle => 'Тауарды ұяшықтан іріктеу';

  @override
  String get wmsFillAllNumericFields =>
      'Барлық өрістерді толтырыңыз (сандық мәндер)';

  @override
  String wmsStockPicked(String cellId) {
    return 'Тауар $cellId ұяшығынан іріктелді';
  }

  @override
  String get wmsPickError => 'Іріктеу қатесі';

  @override
  String get wmsTransferStockTitle => 'Тауарды жылжыту';

  @override
  String get wmsCellIdFrom => 'Ұяшық ID (қайдан)';

  @override
  String get wmsCellIdTo => 'Ұяшық ID (қайда)';

  @override
  String wmsStockTransferred(String from, String to) {
    return 'Тауар $from ұяшығынан $to ұяшығына жылжытылды';
  }

  @override
  String get wmsTransferError => 'Жылжыту қатесі';

  @override
  String get wmsBatches => 'Партиялар';

  @override
  String get wmsBatchTrackingTitle => 'Партиялық есеп';

  @override
  String get wmsBatchTabAll => 'Барлық партиялар';

  @override
  String get wmsBatchTabExpiring => 'Мерзімі бітетін';

  @override
  String get wmsBatchTabExpired => 'Мерзімі өткен';

  @override
  String get wmsBatchTabQuarantine => 'Карантин';

  @override
  String get wmsNoBatches => 'Партиялар жоқ';

  @override
  String get wmsNoExpiringBatches => 'Мерзімі бітетін партиялар жоқ';

  @override
  String get wmsNoExpiredBatches => 'Мерзімі өткен партиялар жоқ';

  @override
  String get wmsNoQuarantinedBatches => 'Карантиндегі партиялар жоқ';

  @override
  String get wmsSearchByUcodeHint => 'Тауар ucode бойынша іздеу...';

  @override
  String get wmsNoNumber => 'Нөмірсіз';

  @override
  String wmsBatchCardSummary(String ucode, String expiry, String qty) {
    return 'Тауар: $ucode  |  Мерзімі: $expiry  |  Саны: $qty';
  }

  @override
  String get wmsBatchNumber => 'Партия нөмірі';

  @override
  String get wmsProduct => 'Тауар';

  @override
  String get wmsExpiryDate => 'Жарамдылық мерзімі';

  @override
  String get wmsStatus => 'Күй';

  @override
  String get wmsActions => 'Әрекеттер';

  @override
  String get wmsQuarantine => 'Карантин';

  @override
  String get wmsApprove => 'Мақұлдау';

  @override
  String get wmsStatusQuarantine => 'Карантин';

  @override
  String get wmsStatusExpired => 'Мерзімі өткен';

  @override
  String get wmsStatusExpiring => 'Мерзімі бітуде';

  @override
  String get wmsStatusOk => 'ОК';

  @override
  String get wmsMoveToQuarantine => 'Карантинге орналастыру';

  @override
  String wmsBatchQuarantined(String number) {
    return '$number партиясы карантинге орналастырылды';
  }

  @override
  String wmsBatchApproved(String number) {
    return '$number партиясы мақұлданды';
  }

  @override
  String get wmsSearchBatchesByProduct => 'Тауар бойынша партияларды іздеу';

  @override
  String get wmsEnterProductCode => 'Тауар кодын енгізіңіз';

  @override
  String get wmsSerialTrackingTitle => 'Сериялық есеп';

  @override
  String get wmsScan => 'Сканерлеу';

  @override
  String get wmsSearchBySerialHint => 'Сериялық нөмір бойынша іздеу...';

  @override
  String get wmsNothingFound => 'Ештеңе табылмады';

  @override
  String get wmsEnterSerialToSearch => 'Іздеу үшін сериялық нөмір енгізіңіз';

  @override
  String get wmsRegister => 'Тіркеу';

  @override
  String get wmsSelectSerial => 'Сериялық нөмірді таңдаңыз';

  @override
  String get wmsSerialNumber => 'Сериялық нөмір';

  @override
  String get wmsLocation => 'Орналасуы';

  @override
  String wmsCellHash(String id) {
    return 'Ұяшық #$id';
  }

  @override
  String get wmsDetails => 'Мәліметтер';

  @override
  String get wmsMarking => 'Таңбалау';

  @override
  String get wmsWarrantyUntil => 'Кепілдік мерзімі';

  @override
  String get wmsNotes => 'Ескертпелер';

  @override
  String get wmsMovementHistory => 'Қозғалыс тарихы';

  @override
  String get wmsNoData => 'Деректер жоқ';

  @override
  String get wmsSerialStatusInStock => 'Қоймада';

  @override
  String get wmsSerialStatusSold => 'Сатылды';

  @override
  String get wmsSerialStatusReturned => 'Қайтарылды';

  @override
  String get wmsSerialStatusWrittenOff => 'Есептен шығарылды';

  @override
  String get wmsSerialStatusUnknown => 'Белгісіз';

  @override
  String get wmsScannerUseHardware =>
      'Сканер: аппараттық сканерді пайдаланыңыз';

  @override
  String get wmsRegisterSerialTitle => 'Сериялық нөмірді тіркеу';

  @override
  String get wmsSerialRegistered => 'Сериялық нөмір тіркелді';

  @override
  String get wmsMarkingCodesTitle => 'Таңбалау кодтары';

  @override
  String get wmsMarkingAccept => 'Қабылдау';

  @override
  String get wmsRefresh => 'Жаңарту';

  @override
  String get wmsIsMptSettings => 'ИС МПТ баптаулары';

  @override
  String get wmsMarkingAcceptTitle => 'Таңбалау кодтарын қабылдау';

  @override
  String get wmsSupplyIdOptional => 'Жеткізу ID (міндетті емес)';

  @override
  String get wmsMarkingCodesPerLine => 'Таңбалау кодтары (әр жолда біреуден)';

  @override
  String get wmsAccept => 'Қабылдау';

  @override
  String get wmsNoCodesEntered => 'Бірде-бір код енгізілмеді';

  @override
  String wmsAcceptedLocally(String count) {
    return 'Жергілікті қабылданды: $count (ИС МПТ — кейінге қалдырылды)';
  }

  @override
  String wmsAccepted(String count) {
    return 'Қабылданды: $count';
  }

  @override
  String wmsAcceptError(String error) {
    return 'Қабылдау қатесі: $error';
  }

  @override
  String wmsMarkingStatusResult(String status) {
    return 'ТК күйі: $status';
  }

  @override
  String get wmsInCirculation => '(айналымда)';

  @override
  String get wmsIsMptNoConnection =>
      'ИС МПТ-мен байланыс жоқ — тексеру кейінге қалдырылды';

  @override
  String get wmsVerifyUnavailable => 'Тексеру қолжетімсіз (ИС МПТ бапталмаған)';

  @override
  String wmsVerifyError(String error) {
    return 'Тексеру қатесі: $error';
  }

  @override
  String get wmsNoMarkingCodes => 'Таңбалау кодтары жоқ';

  @override
  String get wmsVerifyStatus => 'Күйін тексеру (ИС МПТ)';

  @override
  String get wmsMarkingStatusReceived => 'Алынды';

  @override
  String get wmsMarkingStatusInStock => 'Қоймада';

  @override
  String get wmsMarkingStatusSold => 'Сатылды';

  @override
  String get wmsMarkingStatusReturned => 'Қайтарылды';

  @override
  String get wmsMarkingStatusRetired => 'Есептен шығарылды';

  @override
  String get wmsMarkingStatusBlocked => 'Бұғатталған';

  @override
  String get wmsClaims => 'Шағымдар';

  @override
  String get wmsClaimTabOpen => 'Ашық';

  @override
  String get wmsClaimTabInProgress => 'Жұмыста';

  @override
  String get wmsClaimTabResolved => 'Шешілген';

  @override
  String get wmsNoOpenClaims => 'Ашық шағымдар жоқ';

  @override
  String get wmsNoInProgressClaims => 'Жұмыстағы шағымдар жоқ';

  @override
  String get wmsNoResolvedClaims => 'Шешілген шағымдар жоқ';

  @override
  String get wmsNewClaim => 'Жаңа шағым';

  @override
  String get wmsNumber => 'Нөмір';

  @override
  String get wmsType => 'Түрі';

  @override
  String get wmsSeverity => 'Маңыздылығы';

  @override
  String get wmsDate => 'Күні';

  @override
  String get wmsSeverityLow => 'Төмен';

  @override
  String get wmsSeverityMedium => 'Орташа';

  @override
  String get wmsSeverityHigh => 'Жоғары';

  @override
  String get wmsSeverityCritical => 'Сыни';

  @override
  String get wmsClaimTypeDefect => 'Ақау';

  @override
  String get wmsClaimTypeMissort => 'Сұрыптау қатесі';

  @override
  String get wmsClaimTypeShortage => 'Кемшілік';

  @override
  String get wmsClaimTypeDamage => 'Зақым';

  @override
  String get wmsClaimTypeOther => 'Басқа';

  @override
  String get wmsProblemDescription => 'Мәселе сипаттамасы';

  @override
  String get wmsClaimCreated => 'Шағым жасалды';

  @override
  String wmsClaimTitle(String number) {
    return 'Шағым $number';
  }

  @override
  String wmsTypeLabeled(String value) {
    return 'Түрі: $value';
  }

  @override
  String wmsSeverityLabeled(String value) {
    return 'Маңыздылығы: $value';
  }

  @override
  String wmsDateLabeled(String value) {
    return 'Күні: $value';
  }

  @override
  String get wmsProblemDescriptionLabel => 'Мәселе сипаттамасы:';

  @override
  String get wmsNoDescription => 'Сипаттама жоқ';

  @override
  String get wmsResolutionLabel => 'Шешім:';

  @override
  String get wmsNotSpecified => 'Көрсетілмеген';

  @override
  String get wmsHistoryLabel => 'Тарих:';

  @override
  String get wmsNoRecords => 'Жазбалар жоқ';

  @override
  String get wmsResolve => 'Шешу';

  @override
  String get wmsResolveClaimTitle => 'Шағымды шешу';

  @override
  String get wmsResolutionNotes => 'Шешім бойынша ескертпелер';

  @override
  String get wmsClaimResolved => 'Шағым шешілді';

  @override
  String get setUserManagementTitle => 'Пайдаланушылар және рұқсат';

  @override
  String get setUsersTitle => 'Пайдаланушылар';

  @override
  String get setUsersSubtitle => 'Рұқсатты басқару';

  @override
  String get authSettingsTitle => 'Кіру және сеанс';

  @override
  String get authSettingsSubtitle => 'Кассирсіз кіру және сеанс мерзімі';

  @override
  String get authSettingsWalkUpTitle => 'Кассирді таңдамай кіру';

  @override
  String get authSettingsWalkUpSubtitle =>
      'Бір PIN есімсіз кіргізеді. Бірнеше кассир болғанда қауіпсіз емес: әдепкідегідей өшірулі.';

  @override
  String get authSettingsSessionTitle => 'Сеанс мерзімі';

  @override
  String get authSettingsSessionSubtitle =>
      'Кассир әрекетсіз қанша минут сеанста қалады. Дереу қолданылады, кассаны қайта іске қосу қажет емес.';

  @override
  String get authSettingsSessionMinutesLabel => 'Минут';

  @override
  String get authSettingsSaved => 'Сақталды';

  @override
  String get authSettingsInvalidMinutes =>
      '1-ден 1440-қа дейінгі бүтін минут санын енгізіңіз';

  @override
  String get sessionsTitle => 'Белсенді сеанстар';

  @override
  String get sessionsSubtitle => 'Қазір кассада кім бар, батырмамен тоқтату';

  @override
  String get sessionsEmpty => 'Қазір кассада ешкім жоқ';

  @override
  String sessionsTerminalLabel(String id) {
    return 'Терминал №$id';
  }

  @override
  String sessionsTimes(String issued, String expires) {
    return 'Кірді $issued · мерзімі $expires';
  }

  @override
  String get sessionsRevoke => 'Аяқтау';

  @override
  String get sessionsRevokeConfirmTitle => 'Сеансты аяқтау керек пе?';

  @override
  String sessionsRevokeConfirmBody(String name) {
    return '«$name» кассадан дереу шығарылады.';
  }

  @override
  String sessionsRevoked(String name) {
    return '«$name» сеансы аяқталды';
  }

  @override
  String sessionsRevokeError(String error) {
    return 'Сеансты аяқтау мүмкін болмады: $error';
  }

  @override
  String get setUsersEmpty => 'Пайдаланушылар жоқ';

  @override
  String get setAddUser => 'Пайдаланушы қосу';

  @override
  String setUserNumber(String id) {
    return 'Пайдаланушы №$id';
  }

  @override
  String get setUserActive => 'Белсенді';

  @override
  String setUsersLoadError(String error) {
    return 'Қате: $error';
  }

  @override
  String get setNewUser => 'Жаңа пайдаланушы';

  @override
  String get setEditUser => 'Өңдеу';

  @override
  String get setUserTabProfile => 'Профиль';

  @override
  String get setUserTabPermissions => 'Қол жеткізу құқықтары';

  @override
  String get setUserName => 'Аты';

  @override
  String get setUserNameRequired => 'Атын енгізіңіз';

  @override
  String get setUserPinLabel => 'PIN (4-6 сан)';

  @override
  String get setUserPinRequired => 'PIN енгізіңіз';

  @override
  String get setUserPinMin => 'Кемінде 4 сан';

  @override
  String get setUserPinRange => 'PIN 4-6 сан болуы керек';

  @override
  String get setUserRole => 'Рөл';

  @override
  String get setRoleOwner => 'Иесі';

  @override
  String get setRoleAdministrator => 'Әкімші';

  @override
  String get setRoleUser => 'Пайдаланушы';

  @override
  String get setRoleCashier => 'Кассир';

  @override
  String get setUserActiveDesc => 'Пайдаланушы жүйеге кіре алады';

  @override
  String get setUserBlockedDesc => 'Қол жеткізу бұғатталған';

  @override
  String get setUserOwnerFullAccess => 'Иесінде толық рұқсат бар';

  @override
  String get setUserSelectAll => 'Барлығын таңдау';

  @override
  String get setUserDeselectAll => 'Барлығын алып тастау';

  @override
  String get setDeleteUserTitle => 'Пайдаланушыны жою керек пе?';

  @override
  String setDeleteUserConfirm(String name) {
    return '«$name» пайдаланушысы жойылады. Бұл әрекетті болдырмау мүмкін емес.';
  }

  @override
  String setDeleteUserError(String error) {
    return 'Пайдаланушыны жою мүмкін болмады: $error';
  }

  @override
  String get setUserNoEncryptionKey =>
      'Шифрлау кілті бапталмаған. POS бастапқы баптауын аяқтаңыз.';

  @override
  String get setUserPinEncryptFailed => 'PIN шифрлау мүмкін болмады';

  @override
  String get setWmsTitle => 'WMS баптаулары';

  @override
  String get setWmsModules => 'WMS модульдері';

  @override
  String get setWmsCellStorage => 'Ұяшықпен сақтау';

  @override
  String get setWmsCellStorageDesc =>
      'Тауарларды аймақтар мен ұяшықтар бойынша мекенжайлы сақтау';

  @override
  String get setWmsBatchTracking => 'Партиялық есеп';

  @override
  String get setWmsBatchTrackingDesc =>
      'Тауарларды партиялар бойынша жеткізілімді бақылаумен есепке алу';

  @override
  String get setWmsSerialTracking => 'Сериялық есеп';

  @override
  String get setWmsSerialTrackingDesc =>
      'Бірегей сериялық нөмірлер бойынша даналап есеп';

  @override
  String get setWmsExpiryControl => 'Жарамдылық мерзімін бақылау';

  @override
  String get setWmsExpiryControlDesc =>
      'Мерзімнің аяқталуы туралы ескертулер және автоматты FEFO іріктеу';

  @override
  String get setWmsMarking => 'Таңбалау';

  @override
  String get setWmsMarkingDesc =>
      'Міндетті таңбалау кодтарын қолдау (DataMatrix, GS1)';

  @override
  String get setWmsWarranty => 'Кепілдік есебі';

  @override
  String get setWmsWarrantyDesc =>
      'Сериялық нөмірлер бойынша кепілдік мерзімдерін бақылау';

  @override
  String get setWmsPickingStrategy => 'Іріктеу стратегиясы';

  @override
  String get setWmsPickingStrategyDesc =>
      'Тауарларды қоймадан тиеу тәртібін анықтайды';

  @override
  String get setWmsStrategy => 'Стратегия';

  @override
  String get setWmsStrategyFefo =>
      'FEFO — мерзімі бірінші бітеді, бірінші шығады';

  @override
  String get setWmsStrategyFifo => 'FIFO — бірінші келді, бірінші кетті';

  @override
  String get setWmsStrategyLifo => 'LIFO — соңғы келді, бірінші кетті';

  @override
  String get setWmsCostMethod => 'Өзіндік құнды есептеу әдісі';

  @override
  String get setWmsCostMethodDesc =>
      'Сату кезінде өзіндік құнды есептен шығару әдісі';

  @override
  String get setWmsMethod => 'Әдіс';

  @override
  String get setWmsCostFifo => 'FIFO — түсу реті бойынша';

  @override
  String get setWmsCostLifo => 'LIFO — кері тәртіппен';

  @override
  String get setWmsCostAvg => 'Орташа өлшенген құн';

  @override
  String get setWmsExpiryWarnDesc => 'Мерзім бітуіне неше күн қалғанда ескерту';

  @override
  String setWmsDaysShort(int days) {
    return '$days күн';
  }

  @override
  String get setWmsAbcAnalysis => 'ABC талдау';

  @override
  String get setWmsAbcDesc => 'Тауарларды айналым бойынша жіктеу шектері';

  @override
  String get setWmsAbcCategoryA => 'A санаты (жоғары айналым)';

  @override
  String get setWmsAbcCategoryB => 'B санаты (орташа айналым)';

  @override
  String get setWmsAbcCategoryC => 'C санаты (төмен айналым)';

  @override
  String get setWmsSaved => 'WMS баптаулары сақталды';

  @override
  String get setWmsSaveError => 'WMS баптауларын сақтау мүмкін болмады';

  @override
  String get setSalesPolicy => 'Сату саясаты';

  @override
  String get setSalesPolicyDesc => 'Сату кезінде қалдықтарды бақылау';

  @override
  String get setBlockOversell =>
      'Қалдық жеткіліксіз болғанда сатуға тыйым салу';

  @override
  String get setBlockOversellDesc =>
      'Чектегі саны қалдықтан асып кетсе, сатуды аяқтамау (теріс қалдықтан қорғау)';

  @override
  String get setScreenTouch => 'Экран және сенсорлық экран';

  @override
  String get setScreenTouchDesc => 'Сенсорлық экрандағы ыңғайлылық';

  @override
  String get setScrollAssist => 'Сенсорлық экрандағы айналдыру түймелері';

  @override
  String get setScrollAssistDesc =>
      'Сенсорлық экранда ұзын тізімдерді (каталог, чек, есептер, қойма) айналдыруға арналған ▲/▼ түймелері';

  @override
  String get setDemoData => 'Демо деректер';

  @override
  String get setDemoDataSubtitle => '12 ай сату';

  @override
  String get setDemoDataDialogContent =>
      'Барлық режимдер үшін демо деректерді жүктеу:\n• Бөлшек сауда: ~6000 сату, жеткізілім, қайтарым\n• Мейрамхана: 15 үстел, калькуляциясы бар 29 тағам, тапсырыстар\n• Сервис: қызметтер, шығын материалдары, жұмыс тапсырыстары\n\nНемесе таза бастау үшін барлық деректерді тазалау.';

  @override
  String get setDemoClearAll => 'Барлығын тазалау';

  @override
  String get setDemoLoad => 'Демо жүктеу';

  @override
  String get setDemoGenerating => 'Демо деректерді жасау...';

  @override
  String get setDemoLoadedTitle => 'Демо деректер жүктелді';

  @override
  String get setDemoAlreadyExists =>
      'Деректер бұрыннан бар. Алдымен «Барлығын тазалау» басыңыз.';

  @override
  String get setClearDataTitle => 'Деректерді тазалау';

  @override
  String get setClearDataContent =>
      'БАРЛЫҚ деректер жойылады:\n• Сатулар, қайтарымдар, төлемдер\n• Тауарлар, санаттар, бағалар\n• Контрагенттер, жеткізілімдер\n• Тапсырыстар, ауысымдар, касса операциялары\n• Мейрамхана үстелдері, тапсырыстар\n• Сервистік тапсырыстар\n\nPOS баптаулары мен пайдаланушылар сақталады.\nБұл әрекет қайтарылмайды!';

  @override
  String get setClearDeleteAll => 'Барлығын жою';

  @override
  String get setClearInProgress => 'Деректер тазалануда...';

  @override
  String get setClearDone => 'Барлық деректер тазаланды';

  @override
  String setGenericError(String error) {
    return 'Қате: $error';
  }

  @override
  String get setCorrectionTitle => 'Түзету чегі';

  @override
  String get setCorrectionIntro =>
      'Түзету чегі бұрын тіркелген немесе тіркелмеген соманы түзетеді. Себебі мен соманы көрсетіңіз. Егер оператор түзетуді қолдамаса — бұл шынайы көрсетіледі.';

  @override
  String get setCorrectionReasonLabel => 'Түзету себебі';

  @override
  String get setCorrectionReasonHint => 'мыс. өздік түзету';

  @override
  String get setCorrectionAmountLabel => 'Түзету сомасы, KZT';

  @override
  String get setCorrectionPaymentLabel => 'Төлеу әдісі';

  @override
  String get setCorrectionCash => 'Қолма-қол';

  @override
  String get setCorrectionCard => 'Карта';

  @override
  String get setCorrectionSubmit => 'Түзету чегін жіберу';

  @override
  String get setCorrectionDefaultName => 'Түзету';

  @override
  String get setCorrectionInvalidAmount =>
      'Дұрыс түзету сомасын енгізіңіз (> 0)';

  @override
  String get setCorrectionQueued => 'Түзету чегі кезекке қойылды (offline)';

  @override
  String get setCorrectionSent => 'Түзету чегі жіберілді';

  @override
  String get setCorrectionUnsupported =>
      'Түзету чегін ағымдағы оператор қолдамайды';

  @override
  String get setCorrectionNotConfigured => 'Фискалдау бапталмаған';

  @override
  String get setCorrectionError => 'Түзету чегінің қатесі';

  @override
  String get setFiscalConnection => 'Қосылым';

  @override
  String get setFiscalTestMode => 'Сынақ режимі';

  @override
  String get setFiscalLogin => 'Логин';

  @override
  String get setFiscalLoginHint => 'email / телефон';

  @override
  String get setFiscalPassword => 'Құпия сөз';

  @override
  String get setFiscalCashboxSerial => 'ЗНМ (касса сериялық нөмірі)';

  @override
  String get setFiscalCashboxSerialHint => 'мыс. SWK00033717';

  @override
  String get setFiscalRnm => 'РНМ (тіркеу нөмірі)';

  @override
  String get setFiscalKeyPath => 'Кілт/сертификат жолы';

  @override
  String get setFiscalOfflineModule => 'Offline модуль мекенжайы';

  @override
  String get setFiscalVatRate => 'ҚҚС мөлшерлемесі, %';

  @override
  String get dishTabRecipe => 'Рецептура';

  @override
  String get dishTabCosting => 'Өзіндік құны';

  @override
  String get dishTabYield => 'Шығымы және КБЖУ';

  @override
  String get dishVersions => 'Нұсқалар';

  @override
  String get dishCostLabel => 'Өзіндік құны';

  @override
  String get dishPriceLabel => 'Баға';

  @override
  String get dishProfitLabel => 'Пайда';

  @override
  String get dishMarkupLabel => 'Үстеме баға';

  @override
  String get dishNoIngredients => 'Ингредиенттер жоқ';

  @override
  String get dishNoIngredientsHint =>
      'Рецептураны есептеу үшін ингредиенттер қосыңыз';

  @override
  String get dishAddIngredient => 'Ингредиент қосу';

  @override
  String get dishColIngredient => 'Ингредиент';

  @override
  String get dishColGross => 'Брутто';

  @override
  String get dishColColdLoss => 'Өңд.жоғ.%';

  @override
  String get dishColNet => 'Нетто';

  @override
  String get dishColHotLoss => 'Жыл.жоғ.%';

  @override
  String get dishColYield => 'Шығымы';

  @override
  String get dishColCost => 'Құны';

  @override
  String get dishDeleteIngredient => 'Ингредиентті жою';

  @override
  String get dishTotal => 'Барлығы';

  @override
  String get dishDeleteIngredientTitle => 'Ингредиентті жою керек пе?';

  @override
  String dishDeleteIngredientConfirm(String name) {
    return '\"$name\" рецептурадан жойылсын ба?';
  }

  @override
  String get dishSearchIngredientHint =>
      'Ингредиентті атауы немесе штрих-коды бойынша іздеу...';

  @override
  String dishCodeOnly(int code) {
    return 'Коды: $code';
  }

  @override
  String dishCodeWithBarcode(int code, int barcode) {
    return 'Коды: $code  |  Штрих-коды: $barcode';
  }

  @override
  String dishAddTitle(String name) {
    return 'Қосу: $name';
  }

  @override
  String get dishGrossQty => 'Брутто (саны)';

  @override
  String get dishColdLossLabel => 'Өңдеу жоғалтуы, %';

  @override
  String get dishHotLossLabel => 'Жылу өңдеу жоғалтуы, %';

  @override
  String get dishSeasonCoefficient => 'Маусымдық коэффициент';

  @override
  String get dishSeasonStandard => 'Стандарт (x1.0)';

  @override
  String get dishSeasonWinter => 'Қыс (+15%) (x1.15)';

  @override
  String get dishSeasonSummer => 'Жаз (-5%) (x0.95)';

  @override
  String dishEffectiveColdLoss(String value) {
    return 'Тиімді өңдеу жоғалтуы: $value%';
  }

  @override
  String dishTotalYieldSummary(String cost, String yield) {
    return 'Барлығы: $cost ₸  |  Шығымы: $yield';
  }

  @override
  String get dishGostNorms => 'МЕСТ нормалары';

  @override
  String get dishGostNormsTitle => 'МЕСТ жоғалту нормалары';

  @override
  String get dishSearchProductHint => 'Өнімді іздеу...';

  @override
  String get dishReferenceEmpty => 'Анықтамалық бос';

  @override
  String get dishGostNotLoaded => 'МЕСТ нормалары әлі жүктелмеген';

  @override
  String dishGostLossLine(String cold, String hot) {
    return 'Сал: $cold%  Жыл: $hot%';
  }

  @override
  String get dishPhotoSection => 'Тағам фотосы';

  @override
  String get dishMissingPricesWarning =>
      'Кейбір ингредиенттердің сатып алу бағасы жоқ';

  @override
  String get dishProfitPerServing => 'Порциядан пайда';

  @override
  String get dishLossPerServing => 'Порциядан шығын';

  @override
  String get dishCostOfDish => 'Тағамның өзіндік құны';

  @override
  String get dishSellingPrice => 'Сату бағасы';

  @override
  String get dishMargin => 'Маржа';

  @override
  String get dishNoPhoto => 'Фото жоқ';

  @override
  String get dishPhotoLoaded => 'Фото жүктелді';

  @override
  String get dishPhotoAddHint => 'Дайын тағамның фотосын қосыңыз';

  @override
  String get dishCamera => 'Камера';

  @override
  String get dishGallery => 'Галерея';

  @override
  String get dishPhotoLoadError => 'Фото жүктеу мүмкін болмады';

  @override
  String get dishFoodCost => 'Фудкост';

  @override
  String get dishFoodCostExcellent => 'Өте жақсы';

  @override
  String get dishFoodCostNormal => 'Қалыпты';

  @override
  String get dishFoodCostHigh => 'Жоғары';

  @override
  String get dishServingsCount => 'Порция саны:';

  @override
  String get dishCostPerServing => 'Порция құны';

  @override
  String get dishPricePerServing => 'Порция бағасы';

  @override
  String get dishTotalYield => 'Жалпы шығымы';

  @override
  String get dishIngredientsCount => 'Ингредиенттер';

  @override
  String get dishKbjuSection => 'Тағамдық құндылық (1 порцияға)';

  @override
  String get dishKbjuEmpty => 'КБЖУ деректері толтырылмаған';

  @override
  String get dishKbjuCalories => 'Калория';

  @override
  String get dishKbjuProteins => 'Ақуыздар';

  @override
  String get dishKbjuFats => 'Майлар';

  @override
  String get dishKbjuCarbs => 'Көмірсулар';

  @override
  String dishKcalValue(String value) {
    return '$value ккал';
  }

  @override
  String dishGramValue(String value) {
    return '$value г';
  }

  @override
  String get dishVersionHistory => 'Өзгерістер тарихы';

  @override
  String get dishNoVersions => 'Сақталған нұсқалар жоқ';

  @override
  String dishVersionN(String version) {
    return '$version-нұсқа';
  }

  @override
  String get dishViewComposition => 'Құрамын қарау';

  @override
  String get dishRestoreThisVersion => 'Осы нұсқаны қалпына келтіру';

  @override
  String get dishSaveVersion => 'Нұсқаны сақтау';

  @override
  String dishVersionComposition(String version) {
    return '$version-нұсқа — құрамы';
  }

  @override
  String get dishSnapshotUnavailable => 'Құрам суреті қолжетімсіз';

  @override
  String dishSnapshotIngredientLine(
    String gross,
    String cold,
    String hot,
    String yield,
  ) {
    return 'Брутто: $gross  |  Өңд.жоғ.: $cold%  |  Жыл.жоғ.: $hot%  |  Шығымы: $yield';
  }

  @override
  String get dishVersionNotRestorable =>
      'Бұл нұсқаны қалпына келтіру мүмкін емес (ингредиент деректері жоқ), тек қарауға болады';

  @override
  String get dishRestoreVersionTitle => 'Нұсқаны қалпына келтіру керек пе?';

  @override
  String dishRestoreVersionConfirm(String version) {
    return 'Ағымдағы рецептура $version-нұсқаның құрамымен ауыстырылады. Жалғастыру керек пе?';
  }

  @override
  String get dishRestore => 'Қалпына келтіру';

  @override
  String dishVersionRestored(String version) {
    return '$version-нұсқа қалпына келтірілді';
  }

  @override
  String get dishRestoreError => 'Нұсқаны қалпына келтіру мүмкін болмады';

  @override
  String dishVersionSummary(int count, String cost) {
    return 'Ингредиенттер: $count, өзіндік құны: $cost';
  }

  @override
  String get dishSaveVersionError => 'Рецепт нұсқасын сақтау мүмкін болмады';

  @override
  String get prodBarcodeAutoHint => 'Авто';

  @override
  String get prodCatalogAttributes => 'Каталог атрибуттары';

  @override
  String get prodBrand => 'Бренд';

  @override
  String get prodManufacturer => 'Өндіруші';

  @override
  String get prodCountryOfOrigin => 'Шығу елі';

  @override
  String get prodFiscalAttributes => 'Фискалдық атрибуттар';

  @override
  String get prodVatRate => 'ҚҚС мөлшерлемесі';

  @override
  String get prodVatNone => 'ҚҚС-сыз';

  @override
  String get prodNtin => 'НКТ (НТИН)';

  @override
  String get prodMarkable => 'Таңбалауға жатады';

  @override
  String get promoTitle => 'Акциялар';

  @override
  String get promoNew => 'Жаңа акция';

  @override
  String promoError(String error) {
    return 'Қате: $error';
  }

  @override
  String get promoEmpty => 'Акциялар жоқ';

  @override
  String get promoEmptyHint => '1+1 немесе Сыйлық акциясын жасаңыз';

  @override
  String get promoTypeGift => 'Сыйлық';

  @override
  String promoBuyGetFree(int trigger, int reward) {
    return '$trigger сатып ал → $reward тегін';
  }

  @override
  String get promoSupplierTag => 'жеткізушіден';

  @override
  String get promoDefaultName11 => '1+1 акциясы';

  @override
  String get promoNameLabel => 'Атауы';

  @override
  String get promoTriggerLabel => 'Триггер-тауар (нені сатып алу)';

  @override
  String get promoRewardLabel => 'Сыйлық (не тегін)';

  @override
  String get promoSupplierFunded => 'Жеткізушіден акция';

  @override
  String get promoSaveButton => 'Акцияны сақтау';

  @override
  String get saleWeighingPlaceItem => 'Өлшеу... тауарды таразыға қойыңыз';

  @override
  String get saleWeightReadFailed =>
      'Салмақты оқу мүмкін болмады — қолмен енгізіңіз';

  @override
  String get salePriceLabelSent => 'Баға белгісі басып шығаруға жіберілді';

  @override
  String get transPrimary => 'Негізгі';

  @override
  String get transSecondary => 'Қосалқы';

  @override
  String get transStatusOnline => 'Желіде';

  @override
  String get transStatusOffline => 'Желіден тыс';

  @override
  String get transStatusSyncing => 'Синхрондау';

  @override
  String get transStatusQueued => 'Кезекте';

  @override
  String get transStatusWarning => 'Ескерту';

  @override
  String get transStatusError => 'Қате';

  @override
  String transQueuedCount(int count) {
    return 'кезекте $count';
  }

  @override
  String transFailedCount(int count) {
    return '$count сәтсіз';
  }

  @override
  String transLastSyncAgo(String ago) {
    return 'Соңғы синхрондау: $ago бұрын';
  }

  @override
  String get transSyncing => 'Синхрондау...';

  @override
  String get transSyncNow => 'Қазір синхрондау';

  @override
  String get transRetryFailed => 'Сәтсіздерді қайталау';

  @override
  String get restTips => 'Шайпұл';

  @override
  String get restNoTips => 'Шайпұлсыз';

  @override
  String get svcPendingApproval => 'Келісуді күтуде';

  @override
  String get svcApprove => 'Мақұлдау';

  @override
  String get svcReject => 'Қабылдамау';

  @override
  String get svcRejected => 'Қабылданбады';

  @override
  String get svcQr => 'QR';

  @override
  String get catCollapse => 'Жию';

  @override
  String get repError => 'Қате';

  @override
  String get repNoData => 'Деректер жоқ';

  @override
  String get repNoDataForPeriod => 'Таңдалған кезеңде деректер жоқ';

  @override
  String get repKpiLoadError => 'KPI жүктеу қатесі';

  @override
  String get repColIndicator => 'Көрсеткіш';

  @override
  String get repColCount => 'Саны';

  @override
  String get repColSumTenge => 'Сома, ₸';

  @override
  String get repColRow => 'Жол';

  @override
  String get repColTurnoverExclVat => 'Айналым (ҚҚС-сыз)';

  @override
  String get repColVat => 'ҚҚС';

  @override
  String get repColDate => 'Күні';

  @override
  String get repColOperation => 'Операция';

  @override
  String get repColIncome => 'Кіріс';

  @override
  String get repColExpense => 'Шығыс';

  @override
  String get repColBalance => 'Қалдық';

  @override
  String get repColRate => 'Мөлшерлеме';

  @override
  String get repColGross => 'Брутто';

  @override
  String get repColNet => 'Нетто';

  @override
  String get repNoVat => 'ҚҚС-сыз';

  @override
  String get repColCounterparty => 'Контрагент';

  @override
  String get repColType => 'Түрі';

  @override
  String get repColSaldo => 'Сальдо';

  @override
  String get repDebtor => 'Дебитор';

  @override
  String get repCreditor => 'Кредитор';

  @override
  String get repColAccount => 'Шот';

  @override
  String get repColCashier => 'Кассир';

  @override
  String get repColAmount => 'Сома';

  @override
  String get repColProduct => 'Тауар';

  @override
  String get repColRevenue => 'Түсім';

  @override
  String get repColCogs => 'Өзіндік құны';

  @override
  String get repColProfit => 'Пайда';

  @override
  String get repColMarginPct => 'Маржа %';

  @override
  String get repColReason => 'Себеп';

  @override
  String get repColDocuments => 'Құжаттар';

  @override
  String get repColCostShort => 'Өзіндік';

  @override
  String get repF910Title => 'ф.910 — Кіріс (жеңілдетілген)';

  @override
  String repF910Subtitle(String income, String rate, String tax) {
    return 'Салық салынатын кіріс: $income ₸ • салық $rate%: $tax ₸';
  }

  @override
  String get repF910RowSalesIncome => 'Сатудан түскен кіріс';

  @override
  String get repF910RowRefunds => 'Қайтарымдар (минус)';

  @override
  String get repF910RowTaxableIncome => 'Салық салынатын кіріс';

  @override
  String get repF300Title => 'ф.300 — ҚҚС (декларация)';

  @override
  String repF300Subtitle(String turnover, String vat) {
    return 'Салық салынатын айналым: $turnover ₸ • есептелген ҚҚС: $vat ₸';
  }

  @override
  String repF300TaxableTurnoverRate(String rate) {
    return 'Салық салынатын айналым $rate%';
  }

  @override
  String get repF300ZeroRatedTurnover => 'Салық салынбайтын / 0% айналым';

  @override
  String get repCashBookTitle => 'Кассалық кітап (КО-4)';

  @override
  String repCashBookSubtitle(String income, String expense, String balance) {
    return 'Кіріс: $income • Шығыс: $expense • Қалдық: $balance ₸';
  }

  @override
  String get repVatPeriodTitle => 'Кезеңдегі ҚҚС';

  @override
  String repVatPeriodSubtitle(String vat, String base) {
    return 'ҚҚС: $vat ₸ • база: $base ₸';
  }

  @override
  String get repArApTitle => 'Дебиторлық / Кредиторлық';

  @override
  String repArApSubtitle(String receivable, String payable, String saldo) {
    return 'Дебиторлық: $receivable • Кредиторлық: $payable • Сальдо: $saldo';
  }

  @override
  String get repCashCollectionTitle => 'Инкассация';

  @override
  String repCashCollectionSubtitle(int count, String total) {
    return '$count операция • барлығы: $total ₸';
  }

  @override
  String get repProfitCogsTitle => 'Пайда / Маржа (COGS)';

  @override
  String get repProfitMarginTitle => 'Пайда / Маржа';

  @override
  String repProfitMarginSubtitle(String profit, String margin, String note) {
    return 'Пайда: $profit ₸ • маржа $margin% • $note';
  }

  @override
  String get repProfitCostRealCogs => 'өзіндік құны: нақты COGS';

  @override
  String get repProfitCostWholesale =>
      'өзіндік құны: көтерме баға (CalculateCogsUseCase жоқ)';

  @override
  String get repWriteoffTitle => 'Есептен шығару';

  @override
  String repWriteoffSubtitle(int count, String total) {
    return '$count құжат • барлығы: $total ₸';
  }

  @override
  String get repOrderTypesTitle => 'Тапсырыс түрлері';

  @override
  String get repOrderTypesSubtitle => 'қызмет көрсету түрі бойынша бөлу';

  @override
  String get repTableTurnoverTitle => 'Үстелдер айналымы';

  @override
  String get repTableTurnoverSubtitle => 'кезеңдегі отырғызулар (топ-10)';

  @override
  String get repDishPopularityTitle => 'Тағамдар танымалдылығы';

  @override
  String get repDishPopularitySubtitle => 'сату саны бойынша топ-10';

  @override
  String get repFoodCostAnalysisShort => 'Өзіндік құн талдауы';

  @override
  String get repFoodCostAnalysisTitle => 'Өзіндік құн талдауы (Food Cost)';

  @override
  String get repFoodCostAnalysisSubtitle =>
      'жасыл <30%, сары 30-40%, қызыл >40%';

  @override
  String get repColDish => 'Тағам';

  @override
  String get repColFoodCostPct => 'Food Cost %';

  @override
  String get repTipsByWaiterTitle => 'Даяшылар бойынша шай ақы';

  @override
  String get repTipsByWaiterSubtitle => 'шай ақы сомасы бойынша сұрыптау';

  @override
  String get repColWaiter => 'Даяшы';

  @override
  String get repColOrders => 'Тапсырыстар';

  @override
  String get repColTips => 'Шай ақы';

  @override
  String get repColTipsPct => 'Шай ақы %';

  @override
  String get repKpiRestaurantRevenue => 'Мейрамхана түсімі';

  @override
  String get repKpiOrders => 'Тапсырыстар';

  @override
  String get repKpiAvgCheck => 'Орташа чек';

  @override
  String get repKpiTips => 'Шай ақы';

  @override
  String get repKpiRevenue => 'Түсім';

  @override
  String get repKpiExpenses => 'Шығыстар';

  @override
  String get repKpiRefunds => 'Қайтарымдар';

  @override
  String get repKpiSales => 'Сатулар';

  @override
  String get repSubtitleForPeriod => 'кезең ішінде';

  @override
  String get repSubtitleTotal => 'барлығы';

  @override
  String get repSubtitleCashExpenses => 'кассалық шығыстар';

  @override
  String get repSubtitleRefundTotal => 'қайтарым сомасы';

  @override
  String get repSubtitleReceipts => 'чектер';

  @override
  String get repCashFlowTitle => 'Күндер бойынша ақша ағыны';

  @override
  String get repCashFlowInvestments => 'Салымдар';

  @override
  String get repCashFlowExpenses => 'Шығыстар';

  @override
  String get repCashFlowDividends => 'Дивидендтер';

  @override
  String repDaysCount(int count) {
    return '$count күн';
  }

  @override
  String get repTopProfitableTitle => 'Топ-10 пайдалы тауар';

  @override
  String get repTopProfitableSubtitle => 'абсолютті пайда бойынша';

  @override
  String get repProductProfitTitle => 'Тауарлар рентабельділігі';

  @override
  String get repProductProfitSubtitle => 'пайда бойынша топ-20';

  @override
  String get repRefundTrendTitle => 'Қайтарым трендi';

  @override
  String get repSupplierVolumeTitle => 'Жеткізушілер бойынша жеткізілім';

  @override
  String repSuppliersCount(int count) {
    return '$count жеткізуші';
  }

  @override
  String get repSupplierTableTitle => 'Жеткізушілер кестесі';

  @override
  String get repSupplierTableSubtitle => 'жеткізілім саны бойынша сұрыптау';

  @override
  String get repColSupplier => 'Жеткізуші';

  @override
  String get repColSupplyCount => 'Жеткізілім саны';

  @override
  String get repPriceTrendTitle => 'Сатып алу бағаларының динамикасы';

  @override
  String get repPriceTrendSubtitle => 'жеткізілім саны бойынша топ-5 тауар';

  @override
  String get repNotEnoughDataForChart => 'График үшін деректер жеткіліксіз';

  @override
  String get repPriceChangesShort => 'Баға өзгерістері';

  @override
  String get repPriceChangesTitle => 'Жеткізуші бағаларының өзгерістері';

  @override
  String get repPriceChangesSubtitle =>
      'сатып алу бағаларының соңғы өзгерістері';

  @override
  String get repColWas => 'Болды';

  @override
  String get repColBecame => 'Болды';

  @override
  String get repColChangePctShort => 'Өзг. %';

  @override
  String get repNoSupplierData => 'Жеткізушілер туралы деректер жоқ';

  @override
  String get repNoSuppliesForPeriod =>
      'Таңдалған кезеңде жеткізілімдер табылмады';

  @override
  String get navWmsDashboard => 'WMS қойма';

  @override
  String get navWmsWarehouses => 'Қоймалар';

  @override
  String get navWmsBatches => 'Партиялар';

  @override
  String get navWmsSerials => 'Сериялар';

  @override
  String get navWmsCellStock => 'Ұяшықтар';

  @override
  String get navWmsClaims => 'Шағымдар';

  @override
  String get navWmsMarking => 'Таңбалау';

  @override
  String get navWmsSettings => 'WMS баптаулары';

  @override
  String errorInsufficientStock(String name) {
    return 'Қалдық жеткіліксіз: $name';
  }

  @override
  String get errorBigAmountBlocked =>
      'Сату сомасы 1 млн ₸ асады. Касса баптауларында ірі сомаларға рұқсатты қосыңыз.';

  @override
  String errorMarkRequired(String name) {
    return 'Таңбалау коды қажет: $name';
  }

  @override
  String get errorOrderNotFound => 'Тапсырыс табылмады';

  @override
  String get errorSerialNotFound => 'Сериялық нөмір табылмады';

  @override
  String get errorReceiptFailedPrint => 'Чекті басып шығару мүмкін болмады';

  @override
  String get errorDeleteFailed => 'Жою мүмкін болмады';

  @override
  String get errorCancelFailed => 'Болдырмау мүмкін болмады';

  @override
  String get errorShiftZreportFailed => 'Z-есеп қатесі';

  @override
  String get errorTransitionFailed => 'Күйді өзгерту мүмкін болмады';

  @override
  String get logJournalTitle => 'Жұмыс журналы';

  @override
  String get logJournalOpen => 'Журналды ашу';

  @override
  String get logJournalCardDesc =>
      'Күндер бойынша файлдық журнал: флешкаға жүктеу, тазалау';

  @override
  String get logJournalEmpty => 'Журнал бос';

  @override
  String get logJournalPickFolder => 'Жүктеу үшін қалтаны (флешка) таңдаңыз';

  @override
  String get logJournalExport => 'Флешкаға жүктеу';

  @override
  String logJournalExported(int count, String dir) {
    return '$dir ішіне $count файл жүктелді';
  }

  @override
  String logJournalSummary(int count, String size) {
    return 'Файлдар: $count, барлығы $size';
  }

  @override
  String get logJournalDeleteOld => '7 күннен ескі';

  @override
  String logJournalDeletedOld(int count) {
    return '$count файл жойылды';
  }

  @override
  String get logJournalDeleteAllTitle => 'Барлық журналдарды жою керек пе?';

  @override
  String get logJournalDeleteAllConfirm =>
      'Бүгінгіден басқа барлық журнал файлдары жойылады. Бұл әрекет қайтарылмайды.';

  @override
  String get setUserTabPin => 'PIN';

  @override
  String get setUserPinChange => 'PIN ауыстыру';

  @override
  String get setUserPinSetHint => 'Кіру үшін PIN орнатыңыз (4-6 сан)';

  @override
  String get setUserPinKeepHint => 'Ағымдағы PIN сақтау үшін бос қалдырыңыз';

  @override
  String get setUserPinNew => 'Жаңа PIN';

  @override
  String get receiptInputRecent => 'Соңғы чектер';

  @override
  String get receiptInputNoRecent => 'Әзірге чектер жоқ';

  @override
  String get shiftHistoryTitle => 'Ауысымдар тарихы';

  @override
  String get shiftHistoryEmpty => 'Жабық ауысымдар әзірге жоқ';

  @override
  String shiftHistoryShiftNo(int id) {
    return 'Ауысым №$id';
  }

  @override
  String get shiftHistorySales => 'Сатулар';

  @override
  String get shiftHistoryRefunds => 'Қайтарымдар';

  @override
  String get shiftHistoryOpeningCash => 'Бастапқы касса';

  @override
  String saleExpiredBatchWarning(String name) {
    return 'Назар аударыңыз: «$name» тауарының партия мерзімі өткен';
  }

  @override
  String get setPolicyEditProduct => 'Тауарларды өңдеуге рұқсат';

  @override
  String get setPolicyEditProductDesc =>
      'Кассир каталогтағы тауар карточкаларын өзгерте алады';

  @override
  String get setPolicyEditPrice => 'Сатуда бағаны өзгертуге рұқсат';

  @override
  String get setPolicyEditPriceDesc =>
      'Кассир чектегі позиция бағасын қолмен өзгерте алады';

  @override
  String get setPolicyDiscounts => 'Жеңілдіктерге рұқсат';

  @override
  String get setPolicyDiscountsDesc =>
      'Кассир чек позицияларына жеңілдік қолдана алады';

  @override
  String get setPolicyCashInOut => 'Қолма-қол ақша салу/алуға рұқсат';

  @override
  String get setPolicyCashInOutDesc =>
      'Кассир кассадан ақша сала және ала алады';

  @override
  String get setPolicyBigAmount => 'Ірі сомаларға рұқсат (>1 млн)';

  @override
  String get setPolicyBigAmountDesc =>
      'Операциялардағы 1 000 000 шегін алып тастау';

  @override
  String get setPolicyBlockPriceDecrease =>
      'Бағаны карточкадан төмен түсіруге тыйым';

  @override
  String get setPolicyBlockPriceDecreaseDesc =>
      'Чектегі бағаны тауар бағасынан төмен қоюға болмайды';

  @override
  String get printerAutoDetect => 'Принтерді табу';

  @override
  String get printerAutoDetecting => 'Принтер ізделуде…';

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
      'Принтер бірде-бір портта табылмады (USB/serial). Кабель мен қуатты тексеріңіз.';

  @override
  String get printerUsbName => 'USB-принтер';

  @override
  String get printerSelectDevice => 'Принтерді таңдаңыз';

  @override
  String get printerNoAccessGroupLp =>
      'Түйін табылды, бірақ рұқсат жоқ (lp тобы қажет)';

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
      'Түйін табылды, бірақ рұқсат жоқ (lp тобы қажет): usermod -aG lp telepos және сеансты қайта іске қосыңыз.';

  @override
  String printerRawOpenNoPermsHint(String path) {
    return '$path түйіні табылды, бірақ ашу мүмкін емес — рұқсат жоқ. Пайдаланушыны lp тобына қосыңыз (usermod -aG lp telepos) және сеансты/құрылғыны қайта іске қосыңыз.';
  }

  @override
  String get printerNotFoundNoNode =>
      'Принтер табылмады: /dev/usb/lp* char-түйіні де, USB-serial порты да жоқ. Принтердің кабелі мен қуатын тексеріңіз.';

  @override
  String get ownerOnlyTitle => 'Тек касса иесіне қолжетімді';

  @override
  String get ownerOnlyDesc =>
      'Жүйелік операциялар (қайта қосу, ысыру, драйверлер, терминал) тек иесінің тіркелгісінде қолжетімді.';

  @override
  String get telegramApiSectionTitle => 'Telegram қосымшасы';

  @override
  String get telegramApiSectionDesc =>
      'TelePOS Telegram кілттерімен жеткізілмейді. my.telegram.org сайтында қосымша тіркеп, төмендегі жұпты енгізіңіз немесе жинау кезінде --dart-define арқылы беріңіз.';

  @override
  String get telegramApiIdLabel => 'api_id';

  @override
  String get telegramApiHashLabel => 'api_hash';

  @override
  String get telegramApiSave => 'Кілттерді сақтау';

  @override
  String get telegramApiClear => 'Кілттерді жою';

  @override
  String get telegramApiSaved => 'Telegram кілттері сақталды';

  @override
  String get telegramApiCleared => 'Telegram кілттері жойылды';

  @override
  String get telegramApiInvalid =>
      'Сандық api_id және бос емес api_hash енгізіңіз';

  @override
  String get telegramApiStatusConfigured => 'Кілттер берілген';

  @override
  String get telegramApiStatusMissing => 'Кілттер берілмеген';

  @override
  String get deviceSearchButton => 'Іздеу';

  @override
  String get deviceSearchTitle => 'Табылған құрылғылар';

  @override
  String get deviceSearchRunning => 'Іздеу жүріп жатыр…';

  @override
  String get deviceSearchEmpty =>
      'Ештеңе табылмады. Барлық көздер сұралды — құрылғы қосылмаған немесе өшірулі.';

  @override
  String get deviceSearchNoValueForField =>
      'Құрылғылар табылды, бірақ ешқайсысы бұл өріске мән бермейді.';

  @override
  String deviceSearchFailedSources(String sources) {
    return 'Іздеу орындалмады: $sources. Бұл «ештеңе қосылмаған» дегенмен бірдей емес.';
  }

  @override
  String get deviceSearchUnavailable =>
      'Бұл құрастырымда құрылғыларды іздеу қолжетімсіз.';

  @override
  String deviceSearchFieldFilled(String value) {
    return 'Өріс толтырылды: $value';
  }

  @override
  String get deviceSourceSerialPort => 'Тізбекті порт';

  @override
  String get deviceSourceUsb => 'USB';

  @override
  String get deviceSourceNetwork => 'Желі';

  @override
  String get deviceSourceBluetooth => 'Bluetooth';

  @override
  String get deviceCheckButton => 'Құрылғыны тексеру';

  @override
  String get deviceCheckRunning => 'Тексерілуде…';

  @override
  String get deviceCheckUnavailable =>
      'Бұл құрастырымда құрылғыны тексеру қолжетімсіз.';

  @override
  String get deviceCheckSavedBindingNotice =>
      'Сақталған байланыс тексеріледі: құрылғыға осы экрандағы сақталмаған өзгерістер емес, жазылған параметрлер бойынша сұрау жіберіледі. Жаңа байланыс сатуда жұмыс істеуі үшін қолданбаны қайта қосыңыз.';

  @override
  String get deviceCheckReasonOk => 'Құрылғы жауап берді';

  @override
  String get deviceCheckReasonNotConfigured => 'Құрылғы бапталмаған';

  @override
  String get deviceCheckReasonInvalidBinding => 'Байланыс қате';

  @override
  String get deviceCheckReasonDriverNotLive =>
      'Байланыс сақталған, бірақ бұл құрастырма бұл құрылғымен жұмыс істей алмайды';

  @override
  String get deviceCheckReasonConnectionFailed => 'Құрылғы жауап бермейді';

  @override
  String get deviceCheckReasonDeviceRefused => 'Құрылғы әрекеттен бас тартты';

  @override
  String get deviceCheckReasonNotSupportedOnPlatform =>
      'Бұл платформада қолдау көрсетілмейді';

  @override
  String get deviceCheckReasonNotImplemented =>
      'Бұл сынып үшін тексеру әлі жүзеге асырылмаған';

  @override
  String get deviceCheckReasonUnexpectedError => 'Күтпеген қате';

  @override
  String get scannerRulesTitle => 'Штрихкодты оқу ережелері';

  @override
  String get scannerRulesSubtitle =>
      'Сканердің қасиеттері емес, орнату ережелері: қандай оқылған мәнді қабылдау керек.';

  @override
  String get scannerRulesMinLength => 'Штрихкодтың ең аз ұзындығы';

  @override
  String get scannerRulesMaxLength => 'Штрихкодтың ең көп ұзындығы';

  @override
  String get scannerRulesTimeoutMs => 'Сканер таңбалары арасындағы аралық, мс';

  @override
  String scannerRulesDefaultHint(String value) {
    return 'Бос — әдепкі $value';
  }

  @override
  String scannerRulesNotAnInteger(String value) {
    return '«$value» мәні бүтін сан емес';
  }

  @override
  String get scannerRulesUnavailable =>
      'Бұл құрастырымда штрихкодты оқу ережелері қолжетімсіз.';

  @override
  String get scannerRulesSaved => 'Штрихкодты оқу ережелері сақталды';

  @override
  String get printQueueSectionTitle => 'Басып шығару кезегі';

  @override
  String get printQueueSubtitle =>
      'Не басылуды күтуде, не басылмады және неліктен.';

  @override
  String get printQueueEmpty => 'Кезек бос — басылмаған чектер жоқ.';

  @override
  String get printQueueUnavailable =>
      'Басып шығару кезегі бұл құрастыруда қолжетімсіз.';

  @override
  String get printQueueUnreadable => 'Басып шығару кезегін оқу мүмкін емес';

  @override
  String get printQueueUnreadableHint =>
      'Бұл бос кезек емес: тапсырмалар басылуды күтуі мүмкін, бірақ тізімді оқу мүмкін емес. Қызмет көрсету қажет.';

  @override
  String get printQueueStateQueued => 'Басылуды күтуде';

  @override
  String get printQueueStatePrinting => 'Басылып жатыр';

  @override
  String get printQueueStatePrinted => 'Басылды';

  @override
  String get printQueueStateFailed => 'Басылмады, қайталанады';

  @override
  String get printQueueStateExpired => 'Мерзімі өтті, өздігінен қайталанбайды';

  @override
  String get printQueueStateCancelled => 'Оператор тоқтатты';

  @override
  String printQueueAttempts(int count) {
    return 'Әрекеттер: $count';
  }

  @override
  String printQueueDeadline(String moment) {
    return '$moment дейін жарамды';
  }

  @override
  String printQueueReason(String reason) {
    return 'Себебі: $reason';
  }

  @override
  String get printQueueRetry => 'Қайталау';

  @override
  String get printQueueCancelJob => 'Тапсырманы тоқтату';

  @override
  String get printQueueExtendTitle => 'Тапсырманы қанша уақытқа ұзарту керек?';

  @override
  String get printQueueExtend5Minutes => 'Тағы 5 минут';

  @override
  String get printQueueExtend30Minutes => 'Тағы 30 минут';

  @override
  String get printQueueExtend2Hours => 'Тағы 2 сағат';

  @override
  String get printQueueRetryAccepted => 'Тапсырма қайтадан кезекте';

  @override
  String get printQueueRetryAlreadyPrinted =>
      'Бұл чек басылып қойған — екінші рет басылмайды';

  @override
  String get printQueueRetryRejected => 'Қайталау сәтсіз аяқталды';

  @override
  String get printQueueCancelTitle => 'Тапсырманы тоқтату керек пе?';

  @override
  String get printQueueCancelBody =>
      'Тоқтатылған тапсырманы басып шығару мүмкін емес. Дәл сондай чек қажет болса, оны қайта шығару керек.';

  @override
  String get printQueueCancelConfirm => 'Тапсырманы тоқтату';

  @override
  String get printQueueCancelDone => 'Тапсырма тоқтатылды';

  @override
  String get printQueueCancelRefused =>
      'Бұл тапсырманы енді тоқтату мүмкін емес: ол басылып жатыр немесе аяқталған';
}
