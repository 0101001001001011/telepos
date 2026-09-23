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
  String get globalNew => 'Жаңа';

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
  String get globalConfirm => 'Растау';

  @override
  String get globalClear => 'Тазалау';

  @override
  String get globalSelect => 'Таңдау';

  @override
  String get globalAll => 'Барлығы';

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
  String get loginEnter => 'Кіру';

  @override
  String get staffRoleOwner => 'Иесі';

  @override
  String get staffRoleAdministrator => 'Әкімші';

  @override
  String get staffRoleUser => 'Пайдаланушы';

  @override
  String get staffRoleCashier => 'Кассир';

  @override
  String get staffRoleUnknown => 'Белгісіз';

  @override
  String get loginCashier => 'Кассир';

  @override
  String get loginAdmin => 'Әкімші';

  @override
  String get loginLogout => 'Шығу';

  @override
  String get saleProductNotFound => 'Тауар табылмады';

  @override
  String get saleToPay => 'Төлеуге';

  @override
  String paymentCardChargeUnsettled(String amount) {
    return 'Карта $amount сомасына өткізілді, бұл сома чекке кірмейді. Төлем терминалында операцияны болдырмаңыз.';
  }

  @override
  String get saleRemoveItem => 'Тауарды жою';

  @override
  String get saleHold => 'Кейінге қалдыру';

  @override
  String get saleRecall => 'Қайтару';

  @override
  String saleWeightKg(String weight) {
    return 'Салмағы: $weight кг';
  }

  @override
  String get refundTitle => 'Қайтару';

  @override
  String get refundByReceipt => 'Чек бойынша';

  @override
  String get refundWithoutReceipt => 'Чексіз';

  @override
  String get refundReceiptNotFound => 'Чек табылмады';

  @override
  String get refundAmount => 'Қайтару сомасы';

  @override
  String get refundComplete => 'Қайтару орындалды';

  @override
  String get refundConnectionLostHint =>
      'Терминал кассаға өзі оралады — жұмыс сол жерден жалғасады';

  @override
  String get refundConnectionLost => 'Кассамен байланыс үзілді';

  @override
  String get refundNoItems => 'Қайтаруға тауарлар жоқ';

  @override
  String get shiftTitle => 'Ауысым';

  @override
  String get shiftOpen => 'Ауысымды ашу';

  @override
  String get shiftClose => 'Ауысымды жабу';

  @override
  String shiftNumber(int number) {
    return 'Ауысым №: $number';
  }

  @override
  String shiftOpenedAt(String time) {
    return 'Ашылған: $time';
  }

  @override
  String get shiftCashInDrawer => 'Кассада';

  @override
  String get shiftExpected => 'Күтілетін';

  @override
  String get shiftDifference => 'Айырмашылық';

  @override
  String get shiftXReport => 'X-есеп';

  @override
  String get shiftZReport => 'Z-есеп';

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
  String get paymentInstallment => 'Бөліп төлеу';

  @override
  String get paymentMixed => 'Аралас';

  @override
  String get paymentComplete => 'Төлем аяқталды';

  @override
  String get paymentFailed => 'Төлем қатесі';

  @override
  String get historyTitle => 'Тарих';

  @override
  String get historyToday => 'Бүгін';

  @override
  String get historyYesterday => 'Кеше';

  @override
  String certificateSlipPrintFailed(String number, String reason) {
    return '$number сертификатының слипі басылмады: $reason';
  }

  @override
  String get historySale => 'Сату';

  @override
  String get historyRefund => 'Қайтару';

  @override
  String get agentClients => 'Клиенттер';

  @override
  String get agentSuppliers => 'Жеткізушілер';

  @override
  String get agentEdit => 'Өңдеу';

  @override
  String get agentName => 'Атауы/Т.А.Ә.';

  @override
  String get agentPhone => 'Телефон';

  @override
  String get agentIin => 'ЖСН/БСН';

  @override
  String get agentBalance => 'Баланс';

  @override
  String get agentDebt => 'Қарыз';

  @override
  String get cashTitle => 'Касса';

  @override
  String get cashReasonCreditRepayment => 'Бөліп төлеуді өтеу';

  @override
  String get cashReasonCustomerTopUp => 'Сатып алушы шотын толтыру';

  @override
  String get accountBankCard => 'Банк (карта)';

  @override
  String get accountCertificateLiability =>
      'Сертификаттар бойынша міндеттемелер';

  @override
  String get serviceConsumableFallback => 'Шығыс материалы';

  @override
  String get serviceAutoAddedByNorm => 'Шығыс нормасы бойынша қосылды';

  @override
  String get cashInvestment => 'Салым';

  @override
  String get cashExpense => 'Төлем';

  @override
  String get cashEnterAmount => 'Соманы енгізіңіз';

  @override
  String get cashExpenseTypes => 'Шығыс түрі';

  @override
  String get discountTitle => 'Жеңілдік';

  @override
  String get discountPercent => 'Пайыз';

  @override
  String get discountApply => 'Қолдану';

  @override
  String get quickProductTitle => 'Жылдам тауарлар';

  @override
  String get quickProductCategory => 'Санаты';

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
  String get printerConnected => 'Қосылған';

  @override
  String get printerDisconnected => 'Ажыратылған';

  @override
  String get printerError => 'Принтер қатесі';

  @override
  String get printerConnect => 'Қосу';

  @override
  String get printerDisconnect => 'Ажырату';

  @override
  String get printerSettings => 'Принтер баптаулары';

  @override
  String get additionalTitle => 'Қосымша';

  @override
  String get additionalSupply => 'Тауар қабылдау';

  @override
  String get additionalUpdate => 'Жаңарту';

  @override
  String get receiptNumber => 'Чек №';

  @override
  String get receiptDate => 'Күні';

  @override
  String get receiptTotal => 'БАРЛЫҒЫ';

  @override
  String get errorInvalidFormat => 'Қате формат';

  @override
  String get errorPrinter => 'Принтер қатесі';

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
  String get loginShiftUnknown => 'Ауысым: касса жауап бермеді';

  @override
  String get saleDataMatrix => 'Маркировка (DataMatrix)';

  @override
  String get saleHeld => 'Чек кейінге қалдырылды';

  @override
  String get saleNoDeferredSales => 'Кейінге қалдырылған чектер жоқ';

  @override
  String get saleDeferredListNotPermitted =>
      'Кейінге қалдырылған чектер сізге ашық емес: «чекті кейінге қалдыру» құқығы қажет. Оны әкімші құқықтар параметрлерінде береді; құқығы жоқ адамға касса бас тартады.';

  @override
  String get saleDeferNotPermitted =>
      'Чекті кейінге қалдыруға болмайды: «чекті кейінге қалдыру» құқығы қажет. Оны әкімші құқықтар параметрлерінде береді; құқығы жоқ адамға касса бас тартады.';

  @override
  String get saleReceiptNo => 'Чек №';

  @override
  String get salePositions => 'Тауарлар';

  @override
  String get saleSearchHint => 'Тауар іздеу (атау немесе штрих-код)';

  @override
  String get refundWithReceipt => 'ЧЕКПЕН';

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
  String get refundSearchHint => 'Қайтару үшін тауар іздеу';

  @override
  String get paymentChangeLabel => 'Қайтарым:';

  @override
  String get paymentByCard => 'Картамен';

  @override
  String get shiftOperations => 'Операциялар';

  @override
  String get shiftOpened => 'Ауысым ашылды';

  @override
  String get shiftClosed => 'Ауысым жабылды';

  @override
  String get shiftOverAgeTitle => 'Ауысым 24 сағаттан астам ашық';

  @override
  String get shiftOverAgeMessage =>
      'Сату бұғатталды. Жұмысты жалғастыру үшін ағымдағы ауысымды жауып, жаңасын ашыңыз.';

  @override
  String get shiftOverAgeCloseAtTill =>
      'Сату бұғатталды. Жұмысты жалғастыру үшін ауысымды кассада жауып, жаңасын ашыңыз.';

  @override
  String shiftSince(String time) {
    return '$time бастап';
  }

  @override
  String get shiftSystem => 'Жүйе';

  @override
  String get shiftEntered => 'Енгізілді';

  @override
  String get shiftManualEntry => 'Қолмен сома енгізу';

  @override
  String get shiftOpenAction => 'Ауысымды ашу';

  @override
  String get historyOperations => 'Операциялар тарихы';

  @override
  String get historyRefresh => 'Жаңарту';

  @override
  String get historyNoRecords => 'Жазбалар жоқ';

  @override
  String get historyChangeFilters => 'Сүзгілерді өзгертіп көріңіз';

  @override
  String get historyEmpty => 'Операциялар тарихы бос';

  @override
  String get historyPeriod => 'Кезең';

  @override
  String get historySearchHint => 'Чек нөмірі, сома...';

  @override
  String get historyPrint => 'Чекті басып шығару';

  @override
  String get agentWithDebt => 'Тек қарызы бар';

  @override
  String get agentSearchHint => 'Аты немесе телефоны бойынша іздеу...';

  @override
  String get agentNameRequired => 'Аты *';

  @override
  String get agentDeleteQuestion => 'Клиентті жоюу?';

  @override
  String agentDeleteConfirmMsg(String name) {
    return '$name жоюға сенімдісіз бе?';
  }

  @override
  String get supplyTitle => 'Тауарды қабылдау';

  @override
  String get supplySaveError => 'Сақтау қатесі';

  @override
  String get supplyDataLost => 'Барлық енгізілген деректер жоғалады.';

  @override
  String supplyProducts(int count) {
    return 'Тауарлар: $count';
  }

  @override
  String get supplyComment => 'Пікір';

  @override
  String get supplyCommentHint => 'Пікір жазыңыз...';

  @override
  String get supplySelectSupplier => 'Жеткізушіні таңдаңыз';

  @override
  String get supplySelectAccount => 'Шотты таңдаңыз';

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
  String get inventoryTitle => 'Инвентаризация';

  @override
  String get inventoryFullCount => 'Толық түгендеу';

  @override
  String get inventoryFullCountSubtitle =>
      'Сканерленбеген тауарлардың қалдығын нөлдеу';

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
  String get settingsLanguage => 'Интерфейс тілі';

  @override
  String get settingsLanguageChanged => 'Тіл өзгертілді';

  @override
  String get settingsTransport => 'Көлік';

  @override
  String get settingsPrinter => 'Принтер';

  @override
  String get settingsFiscal => 'Фискализация';

  @override
  String get settingsTelegram => 'Telegram';

  @override
  String get fiscalTitle => 'Фискализация';

  @override
  String get fiscalOperator => 'Фискалдық оператор';

  @override
  String get fiscalWebkassa => 'WebKassa баптаулары';

  @override
  String get fiscalSaved => 'Баптаулар сақталды';

  @override
  String get printerSettingsTitle => 'Принтер баптаулары';

  @override
  String get printerConnectionType => 'Қосылу түрі';

  @override
  String get printerAddress => 'Принтер мекенжайы';

  @override
  String get paymentNotFiscalized => 'Чек фискалданбады — төлем тіркелді';

  @override
  String get paymentFiscalModuleAbsent =>
      'Фискалдау модулі қолжетімсіз — чектер фискалданбайды';

  @override
  String get cashDrawerOpenError => 'Ақша жәшігі ашылмады';

  @override
  String get printerPrintError => 'Басып шығару қатесі';

  @override
  String get printerPort => 'Порт';

  @override
  String get cashWithdrawal => 'Алу';

  @override
  String get cashCommentOptional => 'Пікір';

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
  String get updateLater => 'Кейін';

  @override
  String get storageWarningTitle => 'Дискте орын аз';

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
  String get resendCode => 'Кодты қайта жіберу';

  @override
  String get availableBonuses => 'Қолжетімді бонустар:';

  @override
  String get useBonuses => 'Бонустарды есептен шығару';

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
  String maxPercent(String percent) {
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
  String discountLimitPercent(String percent, String source) {
    return '$percent % дейін рұқсат — $source';
  }

  @override
  String discountLimitAmount(String amount, String source) {
    return '$amount дейін рұқсат — $source';
  }

  @override
  String discountApprovalAbove(String percent) {
    return '$percent % жоғары аға қызметкердің растауы қажет';
  }

  @override
  String get enterAmount => 'Соманы енгізіңіз';

  @override
  String get amountMustBePositive => 'Сома оң болуы керек';

  @override
  String get notEnoughCashInDrawer => 'Кассада ақша жеткіліксіз';

  @override
  String get enterValidAmount => 'Дұрыс соманы енгізіңіз';

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
  String get payBtn => 'ТӨЛЕУ';

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
  String maxBonusPercent(int percent) {
    return 'Чек сомасының $percent%-на дейін есептен шығаруға болады';
  }

  @override
  String get insufficientBonuses => 'Бонустар жеткіліксіз';

  @override
  String get enterValidPhone => 'Дұрыс телефон нөмірін енгізіңіз';

  @override
  String retryCount(int count) {
    return 'Қайталау ($count)';
  }

  @override
  String get enterIntegerNumber => 'Бүтін санды енгізіңіз';

  @override
  String enterDigits(int length) {
    return '$length сан енгізіңіз';
  }

  @override
  String get statusOnline => 'Online';

  @override
  String get statusOffline => 'Offline';

  @override
  String get statusSyncing => 'Синхрондау...';

  @override
  String get searchProductHint => 'Тауар іздеу (атау немесе штрих-код)';

  @override
  String get actionDefer => 'Кейінге қалдыру';

  @override
  String get actionDeferredList => 'Кейінге қалдырылғандар';

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
  String get restaurantAddItems => 'Позиция қосу';

  @override
  String get restaurantGoToPayment => 'Төлемге';

  @override
  String get restaurantTransfer => 'Ауыстыру';

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
  String get restaurantSplitPaymentTitle => 'Қонақтар бойынша төлем';

  @override
  String get restaurantSplitPaymentProceed => 'Төлемге';

  @override
  String get restaurantPreCheckPrinted =>
      'Алдын ала чек басып шығаруға жіберілді';

  @override
  String get restaurantPreCheckFailed => 'Алдын ала чекті басып шығару қатесі';

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
  String get setupStepCountry => 'Ел';

  @override
  String get setupStepOrganization => 'Ұйым';

  @override
  String get setupStepVat => 'ҚҚС';

  @override
  String get setupStepUsers => 'Пайдаланушылар';

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
      'Себет, чек нөмірі және ауысым кассаға тиесілі — терминал чекті көрсетеді және сым арқылы басқарады. Чек басып шығару, фискалдау және ақша жәшігі кассада қалады.';

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
  String get setupVatPayerTitle => 'ҚҚС төлеуші';

  @override
  String setupVatPayerRate(String rate) {
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
  String get setupCashDrawerConnectedDesc => 'Принтер командасымен ашылады';

  @override
  String get setupKaspiIpLabel => 'Терминал IP-мекенжайы';

  @override
  String get setupPortLabel => 'Порт';

  @override
  String get setupNoTerminalsAvailable =>
      'Сіздің аймақ үшін қолжетімді төлем терминалдары жоқ';

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
  String get setupAdminSubtitle => 'Касса иесі';

  @override
  String get setupUserNameLabel => 'Аты';

  @override
  String get setupUserPinLabel => 'PIN';

  @override
  String get setupUserPinConfirmLabel => 'Растау';

  @override
  String get setupSellerLabel => 'Сатушы';

  @override
  String get setupSellerOptional => 'Қосымша';

  @override
  String get setupAdminPinMismatch => 'Әкімші PIN-кодтары сәйкес келмейді';

  @override
  String get setupSummaryFormat => 'Формат';

  @override
  String get setupNotConfigured => 'Бапталмаған';

  @override
  String get setupSummaryOrganization => 'Ұйым';

  @override
  String get setupSummaryName => 'Атауы';

  @override
  String get setupSummaryId => 'ID';

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
  String get setupSummaryAdmin => 'Әкімші';

  @override
  String get setupSummarySeller => 'Сатушы';

  @override
  String get setupCompleteTitle => 'Баптау аяқталды!';

  @override
  String get setupCompleteSubtitle => 'Касса жұмысқа дайын';

  @override
  String setupVatPayerSummary(String rate) {
    return 'ҚҚС төлеуші ($rate%)';
  }

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
  String get additionalReceiptPrinted => 'Чек басып шығарылды';

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
  String get paymentCustomerDefault => 'Клиент';

  @override
  String get refundErrorNotAuthenticated => 'Пайдаланушы авторизацияланбаған';

  @override
  String get cashOpTypeInvestment => 'Салым';

  @override
  String get cashOpTypeExpense => 'Шығыс';

  @override
  String get cashOpTypeDividend => 'Алу';

  @override
  String get supplyNoName => 'Атаусыз';

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
  String get syncCompleted => 'Синхрондау аяқталды';

  @override
  String get receiptLabelTotal => 'БАРЛЫҒЫ:';

  @override
  String get receiptLabelChange => 'Қайтарым:';

  @override
  String get receiptLabelPrice => 'Баға';

  @override
  String get receiptLabelAmount => 'Сома';

  @override
  String get receiptLabelThankYou => 'Сатып алғаныңызға рахмет!';

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
  String get agentTypeSupplier => 'Жеткізуші';

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
  String get generalSettingsDataLocation => 'Деректер қайда сақталады';

  @override
  String get generalSettingsDataLocationDesc =>
      'Касса бәрін осы машинада сақтайды. Қайда екенін білу сақтық көшірме мен көшу үшін қажет.';

  @override
  String get generalSettingsDataDb => 'Дерекқор';

  @override
  String get generalSettingsDataLogs => 'Журналдар';

  @override
  String get generalSettingsDataBackups => 'Сақтық көшірмелер';

  @override
  String get generalSettingsPathCopied => 'Жол көшірілді';

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
  String get generalSettingsTransport => 'Көлік';

  @override
  String get generalSettingsTransportSubtitle =>
      'Деректерді синхрондау баптаулары';

  @override
  String get generalSettingsPrinter => 'Принтер';

  @override
  String get generalSettingsPrinterSubtitle => 'Чек басып шығару баптаулары';

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
  String get generalSettingsAppUpdate => 'Қосымшаны жаңарту';

  @override
  String get generalSettingsAppUpdateSubtitle =>
      'Касса қосымшасын жаңарту (ОЖ жаңартуымен шатастырмаңыз)';

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
  String get permNavServiceQueue => 'Тапсырыстар кезегі';

  @override
  String get permNavServiceIntake => 'Тапсырыс қабылдау';

  @override
  String get permSellWithDiscount => 'Жеңілдікпен сату';

  @override
  String get permCashInOut => 'Енгізу / алу';

  @override
  String get permRefundGoods => 'Тауарды қайтару';

  @override
  String get permRefundWithoutReceipt => 'Чексіз қайтару';

  @override
  String get permGroupNavigation => 'Навигация';

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
  String get printerSettingsSave => 'Сақтау';

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
  String get fiscalSettingsVatSettings => 'ҚҚС баптаулары';

  @override
  String get fiscalSettingsWebkassaLabel => 'WebKassa';

  @override
  String get fiscalSettingsNoneLabel => 'Фискализациясыз';

  @override
  String get fiscalSettingsOfdHost => 'ОФД сервер мекенжайы';

  @override
  String get fiscalSettingsOfdHostHint => 'https://api.webkassa.kz';

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
  String get fiscalOffsetSection => 'Сертификаттар және аванс';

  @override
  String get fiscalOffsetCertificateSale => 'Сертификат сатқанда чек';

  @override
  String get fiscalOffsetCertificateSaleSubtitle =>
      'Сыйлық сертификаты сатылғанда фискалдық чек беру';

  @override
  String get fiscalOffsetLayout => 'Сертификатпен немесе аванспен төлеу';

  @override
  String get fiscalOffsetLayoutSubtitle =>
      'Есепке алу сомасы ОФД чегіне қалай түседі';

  @override
  String get fiscalOffsetLayoutDiscount => 'Тауарларға жеңілдікпен';

  @override
  String get fiscalOffsetLayoutSurchargeOnly => 'Тек қосымша төлемге чек';

  @override
  String get fiscalOffsetPrepaymentReceipt => 'Аванс қабылдағанда чек';

  @override
  String get fiscalOffsetPrepaymentReceiptSubtitle =>
      'Сатып алушы аванс енгізгенде фискалдық чек беру';

  @override
  String get fiscalOffsetSaveError => 'Баптауды сақтау мүмкін болмады';

  @override
  String get customerPaymentTender => 'Немен қабылданды';

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
  String get historyFiscalYes => 'Иә';

  @override
  String get historyFiscalNo => 'Жоқ';

  @override
  String get historyFiscalError => 'Қате';

  @override
  String get shiftPrintZReport => 'Z-есепті басып шығару';

  @override
  String get shiftZReportQueued =>
      'Z-есеп басып шығару кезегіне қабылданды. Қағаз әзірге жоқ: принтер мүмкіндік алғанда шығады. Тапсырма 30 минут күтеді — оны Баптаулар → Принтер бөлімінен көруге болады';

  @override
  String get shiftZReportAlreadyQueued =>
      'Z-есеп басып шығаруға жіберілген — ол екінші рет басылмайды';

  @override
  String get shiftZReportPrintFailed =>
      'Z-есепті басып шығаруға жіберу мүмкін болмады';

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
    return 'Тіркелетін сома: $amount';
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
  String get shiftSalesLabel => 'Сатылымдар';

  @override
  String get shiftSalesTotal => 'Сатылым сомасы';

  @override
  String get shiftCashSales => 'Қолма-қол';

  @override
  String get shiftCardSales => 'Карта';

  @override
  String get shiftRefundsTotal => 'Қайтарулар';

  @override
  String get cashOpeningCount => 'Ашу кезіндегі қайта санау';

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
  String refundRefused(String reason) {
    return 'Қайтару орындалмады: $reason';
  }

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
  String errorRefusalUnknownCode(String code) {
    return 'белгісіз себеп (коды $code)';
  }

  @override
  String get errorReasonUnknown => 'белгісіз себеп';

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
  String get errorTillNotConfiguredSale =>
      'Касса бапталмаған — чекті бастау мүмкін емес. Әкімшіге хабарласыңыз: баптау шеберінен өту керек.';

  @override
  String get errorNotAllowed =>
      'Бұл әрекетке құқық жеткіліксіз. Әкімшіге хабарласыңыз.';

  @override
  String get errorNoSaleModule =>
      'Бұл касса чек жүргізе алмайды: сату модулі жиналмаған. Әкімшіге хабарласыңыз.';

  @override
  String get errorTerminalInBody =>
      'Терминал кассаға дұрыс жүгінбеді. Жұмыс орнындағы қосымшаны жаңартыңыз.';

  @override
  String get errorWholesaleInStart =>
      'Көтерме чек былай басталмайды. Кәдімгі чек бастап, көтермені бөлек түймемен қосыңыз.';

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
  String get errorCartStale =>
      'Сіз теріп жатқанда чек өзгерді. Экран жаңартылды — соңғы әрекетті қайталаңыз.';

  @override
  String get errorCartWrongReceipt =>
      'Бұл чек енді жұмыста емес. Жаңа чек бастаңыз немесе кейінге қалдырылғанын алыңыз.';

  @override
  String get errorCartNotStarted =>
      'Чек әлі басталмаған. Жаңа чек бастаңыз немесе кейінге қалдырылғанын алыңыз.';

  @override
  String get errorLineNotFound =>
      'Бұл жол чекте жоқ. Чекті жаңартып, қайталап көріңіз.';

  @override
  String get errorInvalidAmount =>
      'Жарамсыз мән. Сома теріс бола алмайды, жеңілдік 100%-дан аспауы керек.';

  @override
  String get errorDeferredTaken =>
      'Бұл кейінге қалдырылған чекті басқа жұмыс орны алып қойған.';

  @override
  String get errorCartNotEmpty =>
      'Алдымен ағымдағы чекті аяқтаңыз немесе кейінге қалдырыңыз — оның үстіне басқасын алу мүмкін емес.';

  @override
  String get errorSaleNotStarted =>
      'Касса чекті бастай алмады және себебін айтпады. Қайталап көріңіз.';

  @override
  String get errorShiftNotOpen => 'Ауысым ашылмаған. Ауысымды кассада ашыңыз.';

  @override
  String get errorCardTerminalMisconfigured =>
      'Осы жұмыс орнының төлем терминалы дұрыс бапталмаған. Жабдық баптауларындағы байланысты тексеріңіз.';

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
  String get serviceClientLookup => 'Клиентті іздеу';

  @override
  String get paymentDefaultLabel => 'Әдепкі';

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
  String get serviceMarkDescription => 'Сипаттама';

  @override
  String get serviceMarkType => 'Жұмыс түрі';

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
  String get catalogMeasure => 'Өлшем бірлігі';

  @override
  String get catalogQuantity => 'Қалдық';

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
  String get hwDisplayTitle => 'Сатып алушы дисплейі';

  @override
  String get hwDrawerTitle => 'Кассалық жәшік';

  @override
  String get hwTerminalsTitle => 'Төлем терминалдары';

  @override
  String get catalogExportCsv => 'CSV экспорты';

  @override
  String get catalogImport => 'Импорт';

  @override
  String get catalogFilterColumn => 'Сүзгі...';

  @override
  String catalogExportSuccess(String path) {
    return '$path файлына экспортталды';
  }

  @override
  String get catalogExportFailed => 'Экспорт қатесі';

  @override
  String get catalogImportResults => 'Импорт нәтижелері';

  @override
  String catalogImportImported(int count) {
    return 'Импортталды: $count';
  }

  @override
  String catalogImportUpdated(int count) {
    return 'Жаңартылды: $count';
  }

  @override
  String catalogImportSkipped(int count) {
    return 'Өткізілді: $count';
  }

  @override
  String get catalogImportErrors => 'Қателер:';

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
  String get serviceQuickServicesTitle => 'Жылдам қызметтер';

  @override
  String get serviceIntakeItems => 'Қабылданатын заттар';

  @override
  String get serviceItemName => 'Не қабылдайсыз (зат, бұйым, құрылғы)';

  @override
  String get serviceItemDescription =>
      'Ақаудың сипаттамасы / клиенттің тілектері';

  @override
  String get serviceItemSerial => 'Сериялық нөмір / таңбалау';

  @override
  String get serviceItemAdd => 'Зат қосу';

  @override
  String get serviceItemEmpty => 'Кемінде бір зат қосыңыз';

  @override
  String serviceItemCount(int count) {
    return '$count дана';
  }

  @override
  String get serviceClientQuickName => 'Клиенттің аты';

  @override
  String get serviceClientQuickPhone => 'Клиенттің телефоны';

  @override
  String get serviceClientOrSearch => 'немесе базадан табу';

  @override
  String get catalogTypeDish => 'Тағам';

  @override
  String get catalogFilterDish => 'Тағамдар';

  @override
  String get dishCalculation => 'Калькуляция';

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
  String get labelPrinterWidthMm => 'Ені, мм';

  @override
  String get labelPrinterHeightMm => 'Биіктігі, мм';

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
  String get receiptTemplateShowAddress => 'Мекенжайды басып шығару';

  @override
  String get receiptTemplateShowCashier => 'Касса/кассирді басып шығару';

  @override
  String get receiptTemplateShowItemNumbers => 'Позицияларды нөмірлеу';

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
  String get receiptTemplateHeaderHint =>
      'Бірнеше жол: сәлемдесу, акция, байланыс';

  @override
  String get receiptTemplateFooterHint =>
      'Бірнеше жол: алғыс, қайтару шарттары, сайт, әлеуметтік желілер';

  @override
  String get receiptTemplateAlignLeft => 'Сол жақта';

  @override
  String get receiptTemplateAlignCenter => 'Ортасында';

  @override
  String get receiptTemplateAlignRight => 'Оң жақта';

  @override
  String get receiptTemplateBold => 'Қалың';

  @override
  String get receiptTemplateDoubleSize => 'Ірі (екі есе өлшем)';

  @override
  String get receiptTemplatePaperWidthHint =>
      'Таспа ені принтер баптауларында орнатылады';

  @override
  String get receiptTemplateMandatoryNote =>
      'Міндетті деректемелер — чек нөмірі, жиынтық, төлемдер, ҚҚС, фискалдық белгі және QR — әрқашан тақырып пен төменгі бөліктің арасында басылады';

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
  String get sysmTerminalClear => 'Очистить вывод';

  @override
  String sysmTerminalExitCode(int code) {
    return 'Код возврата: $code';
  }

  @override
  String get sysmTerminalEmpty => 'Вывод появится здесь';

  @override
  String get sysmTerminalPresets => 'Пресеты';

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
  String get sntSettingsRequisites => 'Реквизиты налогоплательщика';

  @override
  String get sntSettingsOwnBin => 'БИН / ИИН (наш)';

  @override
  String get sntSettingsWarehouseCode => 'Код виртуального склада';

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
  String setCorrectionAmountLabel(String currency) {
    return 'Түзету сомасы, $currency';
  }

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
    return 'Барлығы: $cost  |  Шығымы: $yield';
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
  String get promoSubtitle => '1+1 акциялары және сатып алуға сыйлықтар';

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
  String get promoDefaultName11 => '1+1 акциясы';

  @override
  String get promoNameLabel => 'Атауы';

  @override
  String get promoTriggerLabel => 'Триггер-тауар (нені сатып алу)';

  @override
  String get promoRewardLabel => 'Сыйлық (не тегін)';

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
  String repColSumTenge(String currency) {
    return 'Сома, $currency';
  }

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
    return 'Салық салынатын кіріс: $income • салық $rate%: $tax';
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
    return 'Салық салынатын айналым: $turnover • есептелген ҚҚС: $vat';
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
    return 'Кіріс: $income • Шығыс: $expense • Қалдық: $balance';
  }

  @override
  String get repVatPeriodTitle => 'Кезеңдегі ҚҚС';

  @override
  String repVatPeriodSubtitle(String vat, String base) {
    return 'ҚҚС: $vat • база: $base';
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
    return '$count операция • барлығы: $total';
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
  String get repProfitCostRealCogs => 'өзіндік құны: нақты COGS';

  @override
  String get repProfitCostWholesale =>
      'өзіндік құны: көтерме баға (CalculateCogsUseCase жоқ)';

  @override
  String get repWriteoffTitle => 'Есептен шығару';

  @override
  String repWriteoffSubtitle(int count, String total) {
    return '$count құжат • барлығы: $total';
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
  String get discountLimitsTitle => 'Жеңілдік шектеулері';

  @override
  String get discountLimitsSubtitle =>
      'Кассир қолмен қанша жеңілдік бере алады';

  @override
  String get discountLimitsIntro =>
      'Рөл шектеуі әдепкіден басым. Өз жолы жоқ рөлге «Әдепкі» қолданылады. Жүз пайыз «шектеусіз» дегенді білдіреді — бұл жарияланған мән, бос орын емес.';

  @override
  String get discountLimitsDefaultRow => 'Әдепкі (барлық рөлдер)';

  @override
  String get discountLimitsMaxPercent => 'Шектеу, %';

  @override
  String get discountLimitsApprovalAbove => 'Растау шегі, %';

  @override
  String get discountLimitsApprovalHint => 'бос — қажет емес';

  @override
  String get discountLimitsInheritHint => 'бос — әдепкідей';

  @override
  String get discountLimitsTwoDoors =>
      'Назар аударыңыз: сату саясатындағы «бағаны төмендетуге тыйым салу» тек жолдың бағасын өңдеуді жабады. Жеңілдік 100 % шектеуде әлі де рұқсат етіледі — тіпті тегін жолға дейін. Бұл екі бөлек есік; екіншісін жабу үшін шектеуді жүзден төмен қойыңыз.';

  @override
  String get discountLimitsSaved => 'Шектеу сақталды';

  @override
  String get discountLimitsInherited => 'Жол алынды: рөл әдепкіні мұралайды';

  @override
  String get discountLimitsInvalid => 'Шектеу — 0-ден 100-ге дейінгі сан';

  @override
  String get discountLimitsApprovalNotYet =>
      'Аға қызметкердің растауы әзірге іске асырылмаған: шектен асқан жеңілдік код сұрамай, аталған себеппен қабылданбайды.';

  @override
  String errorDeniedPolicy(String detail) {
    return 'Касса баптауларымен тыйым салынған: $detail';
  }

  @override
  String errorDeniedLimit(String detail) {
    return 'Жеңілдік рұқсат етілгеннен артық: $detail';
  }

  @override
  String errorApprovalRequired(String detail) {
    return 'Аға қызметкердің растауы қажет: $detail';
  }

  @override
  String errorBigAmountBlocked(String limit) {
    return 'Сату сомасы касса шегінен жоғары ($limit). Шекті көтеріңіз немесе касса баптауларында ірі сомаларға рұқсатты қосыңыз.';
  }

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
  String get receiptInputRecentUnavailable =>
      'Соңғы чектер тізімі бұл терминалда қолжетімсіз — чек нөмірін қолмен енгізіңіз';

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

  @override
  String get errorPayReceiptNotFound =>
      'Чек енді жұмыста емес — оны төлеу мүмкін емес. Экранды жаңартып, қайта бастаңыз.';

  @override
  String get errorPayNotOwner =>
      'Бұл чекті басқа жұмыс орны жүргізуде — оны осы жерден төлеу мүмкін емес.';

  @override
  String get errorPaymentAlreadyTaken =>
      'Бұл чек төленіп қойған. Касса ақшаны екінші рет алмайды.';

  @override
  String get errorPaymentInsufficient =>
      'Аталған сома чекке жетпейді. Соманы қайта енгізіңіз.';

  @override
  String get errorPaymentAccountMissing =>
      'Кассада бұл төлем түріне арналған шот жоқ. Әкімшіге хабарласыңыз.';

  @override
  String get errorPaymentAccountNotAllowed =>
      'Мұндай шот төлемге ұсынылмаған. Шоттар тізімін жаңартып, қайта таңдаңыз.';

  @override
  String get errorPaymentUnbalanced =>
      'Төлем жолдарының сомасы чек сомасына сәйкес келмейді. Төлемді қайта енгізіңіз.';

  @override
  String get errorPaymentKindInactive =>
      'Бұл төлем түрі касса баптауларында өшірілген. Басқасын таңдаңыз немесе баптауларда қосыңыз.';

  @override
  String get errorPaymentKindUnknown =>
      'Касса мұндай төлем түрін білмейді. Әкімшіге хабарласыңыз.';

  @override
  String get errorCertificateUnknown =>
      'Бұл кассада мұндай нөмірлі сертификат жоқ. Нөмірді тексеріңіз.';

  @override
  String get errorCertificatePinWrong =>
      'Сертификаттың ПИН коды сәйкес келмеді. Қайта теріңіз.';

  @override
  String get errorCertificateRateLimited =>
      'Сертификатты тексерудің сәтсіз әрекеттері тым көп. Бірнеше минут күтіп, қайталаңыз.';

  @override
  String get errorConnectionLost =>
      'Кассамен байланыс үзілді. Желіні тексеріп, қайталаңыз.';

  @override
  String get errorRunIncomplete =>
      'Касса операцияны аяқтамай тоқтатты. Қайталамас бұрын кассадағы нәтижені тексеріңіз.';

  @override
  String get errorWireMismatch =>
      'Жұмыс орны мен касса бірін-бірі түсінбеді — нұсқалары сәйкес емес. Бетті жаңартыңыз; көмектеспесе, әкімшіге хабарласыңыз.';

  @override
  String get errorTillFailed =>
      'Касса операцияны орындай алмады. Қайталаңыз; қате қайталанса, әкімшіге хабарласыңыз.';

  @override
  String get errorTerminalChanged =>
      'Сіз жұмыс орнын ауыстырдыңыз — қайта кіріңіз.';

  @override
  String get errorUnknownTerminal =>
      'Жұмыс орны кассаға байланыстырылмаған. Оны байланыстыру кодымен қайта байланыстырыңыз.';

  @override
  String get errorAlreadyConfigured =>
      'Касса бапталып қойған — бастапқы баптау шебері енді қолжетімсіз.';

  @override
  String get errorCannotDeleteSelf => 'Кассаның өз жұмыс орнын жоюға болмайды.';

  @override
  String get errorNoDrivers =>
      'Касса жабдық драйверлерінсіз жиналған — құрылғыларды іздеу мен тексеру қолжетімсіз. Әкімшіге хабарласыңыз.';

  @override
  String get errorNoNetworkModule =>
      'Бұл касса желі баптауларын басқармайды — жүйелік қызмет жоқ. Әкімшіге хабарласыңыз.';

  @override
  String get errorNoSessionRegistry =>
      'Бұл касса сеанстар тізімін жүргізбейді. Әкімшіге хабарласыңыз.';

  @override
  String get errorNoBackupTransport =>
      'Бұл кассада сақтық көшірмелер бапталмаған. Әкімшіге хабарласыңыз.';

  @override
  String get errorBackupNotFound => 'Сақтық көшірме табылмады.';

  @override
  String get errorCertificatesUnavailable =>
      'Бұл касса сыйлық сертификаттарын желі арқылы шығармайды. Әкімшіге хабарласыңыз.';

  @override
  String get errorRefundStale =>
      'Команда кассаға жеткенше қайтару өзгерді. Әрекетті қайталаңыз.';

  @override
  String get errorRefundWrongDraft =>
      'Бұл қайтару жобасы енді жоқ. Қайтаруды қайта ашыңыз.';

  @override
  String get errorRefundNotStarted =>
      'Қайтару басталмаған — чекті таңдаңыз немесе чексіз қайтаруды бастаңыз.';

  @override
  String get errorRefundEmpty =>
      'Қайтаруда бірде-бір жол жоқ — қайтаратын ештеңе жоқ.';

  @override
  String get errorReceiptAlreadyRefunded =>
      'Бұл чек бойынша қайтару жасалып қойған.';

  @override
  String get errorReceiptNotRefundable =>
      'Бұл чекті мұнда қайтаруға болмайды: төлем басқа кассаның терминалы арқылы өтті. Қайтаруды төлеген жерде рәсімдеңіз.';

  @override
  String get errorLineNotInReceipt =>
      'Бұл тауар чекте жоқ — чек бойынша тек онда сатылғаны қайтарылады.';

  @override
  String get errorSaleNotCompleted =>
      'Бұл чек бойынша сату аяқталмаған — қайтаратын ештеңе жоқ.';

  @override
  String get errorRefundBusy =>
      'Кассада басқа қайтару жүріп жатыр. Оны аяқтап, қайталаңыз.';

  @override
  String get errorRefundCannotStart =>
      'Касса қайтаруды бастай алмады және себебін атамады. Ауысым мен касса баптауын тексеріңіз.';

  @override
  String get errorRefundInstallmentRefused =>
      'Чек бөліп төлеуге сатылған — касса оны қайтармайды. Шартты бұзуды әкімші рәсімдейді.';

  @override
  String get errorRefundCashlessUnavailable =>
      'Бұл ақшаны картаға немесе QR арқылы қайтару керек, бірақ қайтаратын құрал жоқ: терминал немесе провайдер қосылмаған. Касса мұндай қайтаруды жәшіктен қолма-қол бермейді.';

  @override
  String get errorRefundCashlessRefused =>
      'Банк немесе провайдер қайтарудан бас тартты. Терминалды тексеріп, қайталаңыз — бұрын қайтарылғаны екінші рет қайтарылмайды.';

  @override
  String get errorRefundKindNotRefundable =>
      'Бұл төлем түріне қайтаруға төлем түрлерінің анықтамалығында тыйым салынған.';

  @override
  String get errorRefundKindUnknown =>
      'Чек осы кассаның анықтамалығында жоқ төлем түрімен төленген. Касса ол бойынша қайтаруды жүргізбейді: немен төлегені белгісіз, ал ол үшін қолма-қол ақша берілмейді.';

  @override
  String get refundDestinationsTitle => 'Ақша қайда кетеді';

  @override
  String get refundRouteDrawer => 'Жәшіктен қолма-қол';

  @override
  String get refundRouteCard => 'Терминал арқылы картаға';

  @override
  String get refundRouteManual => 'Кассадан тыс — төлеген тәсілмен';

  @override
  String get refundRouteProvider => 'QR провайдері арқылы';

  @override
  String get refundRouteCertificate =>
      'Жаңа сертификатпен (ескісі өтелген күйінде қалады)';

  @override
  String get refundRouteAdvance => 'Сатып алушының алдын ала төлеміне';

  @override
  String get refundRouteBonus => 'Бонустық шотқа';

  @override
  String get refundRouteDebt => 'Сатып алушының қарызы есебіне';

  @override
  String get errorCertificateRefundNoSource =>
      'Чек жолы сертификатпен қайтарылады, бірақ оның сертификат нөмірі жоқ. Касса ол бойынша қайтаруды жүргізбейді: жаңа сертификатты не негізде жазу белгісіз, ал кассаның міндеттемесі бекер өсер еді.';

  @override
  String get errorCertificateCashRefundRefused =>
      'Сертификат үшін қолма-қол ақшамен қайтаруға болмайды — қолма-қол ақшасыз қайтару деректемелерін көрсетіңіз.';

  @override
  String get errorCertificatePaysCertificate =>
      'Сертификатпен басқа сертификаттың сатып алуын төлеуге болмайды.';

  @override
  String get errorCreditContractUnknown =>
      'Мұндай нөмірлі бөліп төлеу шарты жоқ. Нөмірді тексеріңіз.';

  @override
  String get errorCreditContractNotActive =>
      'Бөліп төлеу шарты өтелген немесе қайтарылып алынған — ол бойынша төлейтін ештеңе жоқ.';

  @override
  String get errorCreditOverpayment =>
      'Сома шарт бойынша қалдықтан көп. Соманы тексеріңіз.';

  @override
  String get errorCreditRepaymentInvalid =>
      'Өтеу сомасы нөлден көп болуы керек.';

  @override
  String get errorCreditAllocationRace =>
      'Дәл сол сәтте шарт бойынша басқа кассадан төлеген. Төлемді қайта қабылдаңыз.';

  @override
  String get errorKindTenderCannotDiscount =>
      'Нақты ақша әкелетін төлем түрін чекте «төлем емес» деп жариялауға болмайды.';

  @override
  String get errorKindAccountMissing =>
      'Төлем түріне алушы шот тағайындалмаған.';

  @override
  String get errorKindCounterpartyRequired =>
      'Кейінге қалдырылған төлем түрі аталған сатып алушыны талап етеді.';

  @override
  String get errorKindProviderRequired =>
      'Провайдер (QR) арқылы төлем түріне провайдер қажет.';

  @override
  String get errorKindFiscalKindRequired =>
      'Төлем түрінің фискалдық түсіндірмесі көрсетілмеген.';

  @override
  String get errorKindChangeNotATender =>
      'Қайтарымды тек нақты ақша әкелетін түр береді.';

  @override
  String get errorKindSystemImmutable =>
      'Жүйелік төлем түрінің коды мен идентификаторын өзгертуге де, басқа түрге беруге де болмайды.';

  @override
  String get errorCertificateExpired =>
      'Сертификаттың мерзімі өтіп кеткен. Дүкен иесіне хабарласыңыз.';

  @override
  String get errorCertificateExhausted => 'Сертификатта қаражат қалмаған.';

  @override
  String get errorCertificateDuplicate =>
      'Бір сертификат төлемде екі рет аталған. Қайталауды алып тастаңыз.';

  @override
  String get errorCertificateRace =>
      'Сертификаттың қалдығы өзгерді. Төлемді қайталаңыз.';

  @override
  String get errorCertificateAccountMissing =>
      'Кассада сертификаттар бойынша міндеттеме шоты жоқ. Әкімшіге хабарласыңыз.';

  @override
  String get errorCertificateNumberTaken =>
      'Мұндай нөмірлі сертификат бұрын шығарылған.';

  @override
  String get errorCertificateNominalInvalid =>
      'Сертификаттың номиналы нөлден үлкен болуы керек.';

  @override
  String get errorDebtCustomerRequired =>
      'Қарызға сату сатып алушысыз мүмкін емес — сатып алушыны таңдаңыз.';

  @override
  String get errorDebtNotSoldHere =>
      'Бұл кассада қарызға саудаласпайды — несиеге сату касса параметрлерінде өшірілген.';

  @override
  String get errorDebtAccountMissing =>
      'Сатып алушыда есеп шоты жоқ — қарызды жазатын жер жоқ.';

  @override
  String get errorBonusAccountMissing =>
      'Сатып алушыда бонустық шот жоқ — бонусты есептен шығаратын ештеңе жоқ.';

  @override
  String get errorPrepaymentCustomerRequired =>
      'Аванстық есепке алу үшін сатып алушы қажет — оны таңдаңыз.';

  @override
  String get errorCreditTermInvalid =>
      'Бөліп төлеудің мұндай мерзімін касса ресімдемейді';

  @override
  String get errorCreditPrincipalInvalid =>
      'Бөліп төлеуге сома жоқ: чек толық өтелген';

  @override
  String get errorCreditFeeInvalid => 'Шарт бойынша үстеме дұрыс емес';

  @override
  String get errorCreditSchemeUnknown =>
      'Кестенің мұндай сұлбасын касса білмейді';

  @override
  String get errorCreditOverdue =>
      'Сатып алушының басқа бөліп төлеу шарты мерзімі өткен';

  @override
  String get errorCreditContractDuplicate =>
      'Бұл чекке бөліп төлеу шарты бұрыннан ресімделген';

  @override
  String get errorPrepaymentAccountMissing =>
      'Сатып алушыда есеп шоты жоқ — онда аванс бола алмайды.';

  @override
  String get errorPrepaymentInsufficient =>
      'Енгізілген аванс жетпеді: ол басқа чекпен есепке алынған.';

  @override
  String get errorLoyaltyCustomerUnknown =>
      'Сатып алушы картотекадан табылмады. Сатып алушыны қайта таңдаңыз.';

  @override
  String get errorAmountExceedsReceipt =>
      'Сома чек құнынан асып тұр. Соманы қайта енгізіңіз.';

  @override
  String get errorCardChargeUnproven =>
      'Касса карта арқылы төлемді растамады. Төлем терминалын тексеріңіз.';

  @override
  String get errorPaymentTypeNotAllowed =>
      'Бұл төлем түрі осы жұмыс орнында рұқсат етілмеген.';

  @override
  String get errorPaymentsUnavailable =>
      'Бұл касса сым арқылы төлемді қабылдамайды. Әкімшіге хабарласыңыз.';

  @override
  String get errorNoRefundService =>
      'Бұл касса сым арқылы қайтаруды жүргізбейді. Әкімшіге хабарласыңыз.';

  @override
  String get errorRefundAbandonIsTillSide =>
      'Қайтару жобасын жұмыс орны емес, касса алып тастайды.';

  @override
  String get errorNoAnswer =>
      'Касса жауап бермеді. Байланысты тексеріп, қайталаңыз.';

  @override
  String paymentTypeNotAllowedHere(String type) {
    return '«$type» осы жұмыс орнына рұқсат етілмеген. Төлем түрлері жабдық баптауларында өзгертіледі; басқанмен де касса рұқсат етілмеген түрден бас тартады.';
  }

  @override
  String paymentTypesLimitedHere(String types) {
    return 'Жұмыс орны қабылдайды: $types.';
  }

  @override
  String get paymentDebtNotSoldHere =>
      'Бұл кассада қарызға сатпайды: несиеге сату касса параметрлерінде өшірілген. Түймені бассаңыз да, касса бас тартады.';

  @override
  String get paymentDebtNotPermitted =>
      'Сізге қарызға сатуға рұқсат жоқ: «қарызға сату» құқығы қажет. Оны әкімші құқықтар параметрлерінде береді; құқығы жоқ адамға касса бас тартады.';

  @override
  String get saleDiscountNotPermitted =>
      'Сізге жеңілдік беруге рұқсат жоқ: «жеңілдікпен сату» құқығы қажет. Оны әкімші құқықтар параметрлерінде береді; құқығы жоқ адамға касса бас тартады.';

  @override
  String get paymentDebtPolicyUnknown =>
      'Касса әзірге мұнда қарызға сатылатынын жауап берген жоқ. Кассамен байланысты тексеріп, қайталап көріңіз.';

  @override
  String get paymentOffsetsTitle => 'Аванс және сертификаттар';

  @override
  String get paymentPrepaymentTitle => 'Сатып алушының авансы';

  @override
  String get paymentPrepaymentNeedsCustomer =>
      'Авансты есепке алу үшін сатып алушыны телефон нөмірі бойынша табыңыз.';

  @override
  String get paymentPrepaymentLoading =>
      'Касса әзірге қанша аванс енгізілгенін жауап берген жоқ.';

  @override
  String get paymentPrepaymentNone => 'Сатып алушының енгізілген авансы жоқ.';

  @override
  String get paymentPrepaymentBalance => 'Алдын ала енгізілген:';

  @override
  String get paymentPrepaymentUse => 'Авансты есепке алу';

  @override
  String paymentPrepaymentApplied(String amount) {
    return 'Есепке алынады: $amount';
  }

  @override
  String get paymentCertificateTitle => 'Сыйлық сертификаты';

  @override
  String get paymentCertificateNumber => 'Сертификат нөмірі';

  @override
  String get paymentCertificatePin => 'PIN, бар болса';

  @override
  String get paymentCertificatePresent => 'Тексеру';

  @override
  String paymentCertificateBalance(String amount) {
    return 'Сертификаттағы қалдық: $amount';
  }

  @override
  String paymentCertificateApplied(String amount, String rest) {
    return '$amount есептен шығарылады, $rest қалады';
  }

  @override
  String get paymentCertificateNotNeeded =>
      'Чек толық жабылды — бұл сертификат қажет емес.';

  @override
  String get unfiscalizedTitle => 'Фискалданбаған чектер';

  @override
  String get unfiscalizedEmpty => 'Барлық чектер фискалданған';

  @override
  String get unfiscalizedEmptyHint =>
      'Мұнда ақшасы алынған, бірақ оператор құжат бермеген чектер пайда болады';

  @override
  String unfiscalizedReceiptNo(int number) {
    return 'Чек №$number';
  }

  @override
  String unfiscalizedAgeHours(int hours) {
    return '$hours сағ бұрын';
  }

  @override
  String get unfiscalizedOverdue => '72 сағаттық мерзім өтіп кетті';

  @override
  String get unfiscalizedRetry => 'Қайталау';

  @override
  String unfiscalizedRetryDone(String sign) {
    return 'Құжат алынды: $sign';
  }

  @override
  String unfiscalizedRetryFailed(String message) {
    return 'Оператор қайтадан бас тартты: $message';
  }

  @override
  String get unfiscalizedNoDocument =>
      'Жол бас тартулар құжат алып жүре бастағанға дейін жазылған: қайталайтын ештеңе жоқ, оны тек есептен шығаруға болады';

  @override
  String get unfiscalizedNoOperator =>
      'Фискалдық оператор бапталмаған: қайталайтын жер жоқ';

  @override
  String get unfiscalizedWriteOff => 'Есептен шығару';

  @override
  String get unfiscalizedWriteOffTitle => 'Фискалданбаған чекті есептен шығару';

  @override
  String unfiscalizedWriteOffBy(String name) {
    return 'Шешім мына атқа жазылады: $name';
  }

  @override
  String get unfiscalizedWriteOffReason => 'Есептен шығару себебі';

  @override
  String get unfiscalizedWriteOffDone => 'Чек өңделді деп белгіленді';

  @override
  String unfiscalizedWrittenOff(String name, String reason) {
    return '$name есептен шығарды: $reason';
  }

  @override
  String get unfiscalizedUnknownUser => 'белгісіз пайдаланушы';

  @override
  String unfiscalizedAtShiftClose(int count, String numbers) {
    return 'Ауысым фискалданбаған чектермен жабылды: $count. Нөмірлері: $numbers';
  }

  @override
  String documentsOnTheWayAtShiftClose(int count, String numbers) {
    return 'Ауысым құжаттары әлі операторда жоқ: $count (чектер $numbers). Жабу олардың жіберілуін күтеді; байланыс оралмаса, Z-есеп жіберілмейді — әйтпесе оператор есебі кассамен сәйкес келмейді.';
  }

  @override
  String qrPaidPartial(String paid, String amount) {
    return 'Ішінара төленді: $amount ішінен $paid';
  }

  @override
  String get qrOrphanTitle => 'Чексіз ақша';

  @override
  String get qrOrphanHint =>
      'Сатып алушы QR арқылы төледі, бірақ чек бұл ақшамен жабылмаған.';

  @override
  String qrOrphanLine(String amount, String provider, String key) {
    return '$amount · $provider · $key';
  }

  @override
  String get qrOrphanAfterGiveUp =>
      'Растау касса күтуді тоқтатқаннан кейін келді';

  @override
  String get errorQrIntentUnknown =>
      'Касса бұл QR төлемін білмейді. Чекті жаңартып, қайталаңыз.';

  @override
  String get errorQrIntentNotPaid =>
      'QR төлемін банк әлі растаған жоқ. Растауды күтіңіз немесе басқа тәсілді таңдаңыз.';

  @override
  String errorQrIntentAlreadySettled(String message) {
    return 'Бұл ақша басқа чекті жауып қойған: $message';
  }

  @override
  String get paymentQrTitle => 'QR арқылы төлеу';

  @override
  String get paymentQrAmount => 'QR сомасы';

  @override
  String get paymentQrStart => 'QR көрсету';

  @override
  String paymentQrWaiting(int seconds) {
    return 'Төлемді күтудеміз · $seconds с қалды';
  }

  @override
  String get paymentQrScanHint =>
      'Сатып алушы кодты банк қосымшасында сканерлейді';

  @override
  String get paymentQrCancel => 'Күтуді болдырмау';

  @override
  String get paymentQrNoLink =>
      'Провайдермен байланыс жоқ — касса сұрауды өзі қайталайды';

  @override
  String paymentQrPaid(String amount) {
    return 'QR арқылы төленді: $amount';
  }

  @override
  String paymentQrPaidAfterCancel(String amount) {
    return 'Сатып алушы болдырмауға дейін төлеп үлгерді — $amount осы чекке түседі';
  }

  @override
  String get paymentQrCancelled => 'Күту болдырылмады, провайдер растады';

  @override
  String get paymentQrPatienceSpent =>
      'Сатып алушы белгіленген уақытта төлемеді — касса күтуді тоқтатты';

  @override
  String get paymentQrExpired => 'QR кодтың мерзімі провайдерде бітті';

  @override
  String get paymentQrFailed => 'Провайдер QR төлемінен бас тартты';

  @override
  String get paymentQrCancelUnconfirmed =>
      'Болдырмау расталмады — ақша әлі келуі мүмкін. Касса анықтағанша басқа төлемді қабылдамаңыз.';

  @override
  String get paymentQrRecheck => 'Қайта тексеру';

  @override
  String get paymentQrRestart => 'Жаңа код';

  @override
  String paymentQrOverReceipt(String amount) {
    return 'QR төлемінің $amount сомасы чекке сыймайды';
  }

  @override
  String get paymentQrNothingToPay =>
      'Чек толық жабылған — код көрсетуге негіз жоқ';

  @override
  String get errorQrNotConfigured => 'Кассада QR провайдері бапталмаған';

  @override
  String get errorQrNetwork => 'QR провайдерімен байланыс жоқ';

  @override
  String get errorQrTimeout => 'QR провайдері уақытында жауап бермеді';

  @override
  String get errorQrProviderBusy => 'QR провайдері бос емес — касса қайталайды';

  @override
  String get errorQrMalformedReply =>
      'QR провайдері түсініксіз жауап берді — касса әкімшісіне хабарласыңыз';

  @override
  String get errorQrUnknownIntent => 'QR провайдері бұл төлемді білмейді';

  @override
  String get errorQrRejected => 'QR провайдері сұрауды қабылдамады';

  @override
  String get errorQrReverseUnsupported =>
      'QR провайдері ақшаны қайтара алмайды';

  @override
  String get errorQrIntentLive =>
      'Бұл чекте QR төлемі күтуде — жаңа код көрсетпес бұрын оны болдырмаңыз';

  @override
  String get fiscalReasonNetwork => 'Фискалдық оператормен байланыс жоқ';

  @override
  String get fiscalReasonOperatorUnavailable =>
      'Фискалдық оператор қолжетімсіз';

  @override
  String get fiscalReasonTokenExpired =>
      'Оператор кассаның авторизациясын қабылдамады';

  @override
  String get fiscalReasonRequestNotBuilt =>
      'Операторға сұрау құрастырылмады: фискалдық баптаулардағы сервер мекенжайын тексеріңіз';

  @override
  String get fiscalReasonTlsRejected =>
      'Оператормен қорғалған байланыс орнатылмады: сервер мекенжайын және кассаның сағатын тексеріңіз';

  @override
  String get fiscalReasonClientFault =>
      'Оператормен алмасу кезінде касса ақаулығы';

  @override
  String get fiscalReasonBadCredentials =>
      'Оператордың логині немесе құпиясөзі қате';

  @override
  String get fiscalReasonCashboxNotFound =>
      'Оператор бұл кассаны таппады: зауыттық нөмірді тексеріңіз';

  @override
  String get fiscalReasonCashboxBlocked => 'Касса оператормен бұғатталған';

  @override
  String get fiscalReasonOfflineLimitExceeded =>
      'Автономды құжаттар лимиті асып кетті';

  @override
  String get fiscalReasonOfflineNotSupported =>
      'Бұл кассаға автономды режимге рұқсат жоқ';

  @override
  String get fiscalReasonDuplicate =>
      'Құжат операторда әлдеқашан тіркелген, бірақ фискалдық белгі кассаға берілмеді — оны оператор кабинетінен алыңыз';

  @override
  String get fiscalReasonValidation =>
      'Оператор құжатты қабылдамады: сомалар немесе деректер сәйкес емес';

  @override
  String get fiscalReasonNotEnoughMoney =>
      'Оператор деректері бойынша кассада қолма-қол ақша жеткіліксіз';

  @override
  String get fiscalReasonShiftError => 'Операторда ауысым қатесі';

  @override
  String get fiscalReasonUnsupported => 'Операцияны оператор қолдамайды';

  @override
  String get fiscalReasonNotConfigured => 'Фискализация бапталмаған';

  @override
  String get fiscalReasonUnknown => 'Оператор белгісіз себеппен бас тартты';

  @override
  String get fiscalReasonOfflineWindowExpired =>
      '72 сағаттық автономды терезе аяқталды — құжат берілмеді';

  @override
  String get fiscalReasonRowUnreadable =>
      'Кезек жолы бүлінген: құжат оқылмайды';

  @override
  String fiscalReasonWithCode(String reason, int code) {
    return '$reason (код $code)';
  }

  @override
  String fiscalReasonLegacy(String text) {
    return 'Себеп аудармаға дейін жазылған: $text';
  }

  @override
  String get fiscalReasonNotRecorded => 'Себеп жазылмаған';

  @override
  String get fiscalReasonPaymentTypeNotAccepted =>
      'Төлем түрін оператор қабылдамайды: «несие» және «ыдыс» ОФД 2.0.2 хаттамасынан алынып тасталған';

  @override
  String get errorDeferredListUnavailable =>
      'Кейінге қалдырылған чектер тізімі қолжетімсіз';

  @override
  String errorDeferredListUnavailableReason(String reason) {
    return 'Кейінге қалдырылған чектер тізімі қолжетімсіз: $reason';
  }

  @override
  String get errorRefundSearchUnavailable =>
      'Бұл терминалда қайтару үшін тауар іздеу әлі қосылмаған';

  @override
  String get errorRefundNothingSelected =>
      'Жоба өзгерді — қайтаратын ештеңе жоқ. Белгіленген жолдарды тексеріңіз.';

  @override
  String get errorRefundInvalidAmount =>
      'Мұнша қайтаруға болмайды: саны чек бойынша сатылғаннан көп немесе нөлден аз бола алмайды.';

  @override
  String get errorCertificatePinRequired =>
      'Сертификаттың PIN-коды бар. Сертификаттағы PIN-кодты теріңіз.';

  @override
  String get qrSettingsTitle => 'QR арқылы төлем';

  @override
  String get qrSettingsSubtitle => 'QR провайдері: мекенжай, код, кілт, күту';

  @override
  String get qrSettingsKindTitle => 'QR арқылы төлем қабылдау';

  @override
  String get qrSettingsKindSubtitle => 'Төлем экранындағы «QR» төлем түрі';

  @override
  String get qrSettingsUrl => 'Провайдер мекенжайы';

  @override
  String get qrSettingsCode => 'Провайдер коды';

  @override
  String get qrSettingsKey => 'Қолжетімділік кілті';

  @override
  String get qrSettingsKeyStoredHint =>
      'Кілт сақталған. Ауыстыру үшін жаңасын енгізіңіз';

  @override
  String get qrSettingsKeyEmptyHint => 'Кілт берілмеген';

  @override
  String get qrSettingsClearKey => 'Сақталған кілтті өшіру';

  @override
  String get qrSettingsPatience => 'Төлемді күту, секунд';

  @override
  String get qrSettingsSave => 'Сақтау';

  @override
  String get qrSettingsSaved => 'QR баптауы сақталды';

  @override
  String get qrSettingsRemove => 'Баптауды алып тастау';

  @override
  String get qrSettingsStatusReady => 'Провайдер бапталған';

  @override
  String get qrSettingsStatusNotConfigured =>
      'Провайдер бапталмаған — QR арқылы төлем қолжетімсіз';

  @override
  String get qrSettingsInvalidUrl =>
      'Мекенжай http:// немесе https:// деп басталуы керек';

  @override
  String get qrSettingsCodeRequired => 'Провайдер кодын көрсетіңіз';

  @override
  String qrSettingsInvalidPatience(String min, String max) {
    return 'Күту — $min секундтан $max секундқа дейін';
  }

  @override
  String get qrSettingsSaveFailed => 'QR баптауын сақтау мүмкін болмады';

  @override
  String get qrSettingsTillOnly =>
      'QR провайдерін баптау тек кассаның өзінде қолжетімді';

  @override
  String get installmentTermsTitle => 'Бөліп төлеу';

  @override
  String get installmentTermsMonths => 'Мерзімі, ай';

  @override
  String get installmentTermsScheme => 'Кесте түрі';

  @override
  String get installmentTermsContinue => 'Жалғастыру';

  @override
  String get customerPaymentTitle => 'Төлем қабылдау / қарызды өтеу';

  @override
  String customerPaymentCurrentDebt(String amount) {
    return 'Ағымдағы қарыз: $amount';
  }

  @override
  String customerPaymentBalance(String amount) {
    return 'Баланс: $amount';
  }

  @override
  String get customerPaymentAmount => 'Төлем сомасы';

  @override
  String get customerPaymentAmountInvalid => '0-ден үлкен соманы енгізіңіз';

  @override
  String get customerPaymentFailed => 'Төлемді жүргізу қатесі';

  @override
  String get customerPaymentSubmit => 'Төлем қабылдау';

  @override
  String get errorPrepaymentAmountInvalid =>
      'Аванс сомасы нөлден үлкен болуы керек. Соманы қайта енгізіңіз.';

  @override
  String get errorPrepaymentTenderInvalid =>
      'Аванс қолма-қол ақшамен, картамен немесе QR арқылы қабылданады. Басқа төлем түрін таңдаңыз.';

  @override
  String get errorPrepaymentTillAccountMissing =>
      'Бұл кассада осы төлем түрін қабылдайтын шот жоқ. Қабылдау шотын баптап, қайталаңыз.';

  @override
  String get errorPrepaymentIntakeFailed =>
      'Авансты қабылдау мүмкін болмады. Сатып алушыны тексеріп, қайталаңыз.';

  @override
  String get errorPrepaymentRefundExceedsBalance =>
      'Сатып алушының шотындағы аванс сіз беріп жатқан сомадан аз. Қалдықты тексеріп, соманы азайтыңыз.';

  @override
  String get errorPrepaymentRefundKeyMissing =>
      'Аванс беру өтінімінде қайталау кілті жоқ — касса қайталауды екінші берумен шатастырады. Экранды қайта ашып, соманы қайтадан теріңіз.';

  @override
  String get errorPrepaymentRefundFailed =>
      'Авансты беру мүмкін болмады. Сатып алушыны тексеріп, қайталаңыз.';

  @override
  String get errorPrepaymentRefundUnavailable =>
      'Бұл касса сатып алушының авансын сым арқылы бермейді. Әкімшіге хабарласыңыз.';

  @override
  String get errorPrepaymentIntakeUnavailable =>
      'Бұл касса сатып алушының авансын желі арқылы қабылдамайды. Әкімшіге хабарласыңыз.';

  @override
  String get errorPrepaymentIntakeKeyMissing =>
      'Бұл аванс өтінімінде қайталау кілті жоқ, сондықтан касса қайталауды екінші төлемнен ажырата алмайды. Экранды қайта ашып, соманы қайта енгізіңіз.';

  @override
  String get errorQrSetupUnavailable =>
      'Бұл кассада QR провайдерінің баптауы сақталмайды. QR арқылы төлемді кассаның өзінде баптаңыз немесе әкімшіге хабарласыңыз.';

  @override
  String get errorReceiptTemplatesUnavailable =>
      'Бұл кассада чек үлгілері сақталмайды. Үлгіні кассаның өзінде баптаңыз немесе әкімшіге хабарласыңыз.';

  @override
  String get errorReceiptTemplateNameless =>
      'Чек үлгісінің атауы болуы тиіс. Атауын теріп, қайта сақтаңыз.';

  @override
  String get shiftDeskTitle => 'Ауысым';

  @override
  String get shiftDeskOverAgeWarning =>
      'Ауысым 24 сағаттан астам ашық — сату бұғатталған. Оны жауып, жаңасын ашыңыз.';

  @override
  String shiftDeskOpenedAt(String when) {
    return 'Ашылған: $when';
  }

  @override
  String get shiftDeskCountedLabel => 'Жәшікте саналған';

  @override
  String get shiftDeskCountedHint =>
      'Ешкім санамаса, бос қалдырыңыз — касса өз қорытындысын алады.';

  @override
  String get shiftDeskOpeningCashLabel => 'Басында жәшіктегі ақша';

  @override
  String get shiftDeskClosedNow => 'Ауысым жабылды.';

  @override
  String get shiftDeskOpenedNow => 'Ауысым ашылды.';

  @override
  String get shiftDeskNoShift => 'Кассада ашық ауысым жоқ.';

  @override
  String shiftDeskUnfiscalizedCount(int count) {
    return 'Фискалдық құжатсыз чектер: $count';
  }

  @override
  String shiftDeskUnfinishedCount(int count) {
    return 'Аяқталмаған чектер: $count — жабу оларды тазалайды';
  }

  @override
  String get errorShiftDeskNotOpen =>
      'Бұл кассада ашық ауысым жоқ — жабатын ештеңе жоқ.';

  @override
  String get errorShiftDeskAlreadyOpen => 'Бұл кассада ауысым әлдеқашан ашық.';

  @override
  String get errorShiftDeskUnavailable =>
      'Бұл касса ауысымдарды сым арқылы жүргізбейді. Ауысымды кассаның өзінде жабыңыз немесе әкімшіге хабарласыңыз.';

  @override
  String get errorShiftDeskActorUnknown =>
      'Ауысымды кассир ашады, ал бұл өтінімде кассир аталмаған. Қайта кіріңіз.';

  @override
  String get prepaymentIntakeTitle => 'Аванс қабылдау';

  @override
  String get prepaymentIntakeFind => 'Сатып алушыны табу';

  @override
  String get prepaymentIntakeNotFound =>
      'Мұндай нөмірмен сатып алушы табылмады.';

  @override
  String get prepaymentIntakeSubmit => 'Авансты қабылдау';

  @override
  String prepaymentIntakeAccepted(String amount) {
    return 'Аванс қабылданды. Алдын ала енгізілген: $amount';
  }

  @override
  String get prepaymentIntakeFiscalFailed =>
      'Ақша қабылданды, бірақ аванстың фискалдық чегі жазылмады.';

  @override
  String get emulatorSettingsTitle => 'Кірістірілген эмуляторлар';

  @override
  String get emulatorSettingsHint =>
      'Аспаптарды қоспай-ақ басып шығару мен диагностиканы тексеру';

  @override
  String get emulatorReceiptPrinter => 'Чек принтері және ақша жәшігі';

  @override
  String get emulatorEnabledNote =>
      'Сокет ашық. Касса оған тек байланыстағы мекенжай арқылы жетеді';

  @override
  String get emulatorDisabledNote => 'Өшірулі: сокет ашылмаған';

  @override
  String get emulatorAddress => 'Эмулятор мекенжайы';

  @override
  String get emulatorAddressHint =>
      'Осы IP мен портты принтер баптауларына жазыңыз';

  @override
  String get emulatorBindAction => 'Принтер байланысына жазу';

  @override
  String get emulatorBindDone => 'Принтер байланысы енді эмуляторға қарайды';

  @override
  String get emulatorBindingStale =>
      'Принтер байланысы өшірілген эмуляторға қарайды — басып шығару орындалмайды';

  @override
  String get emulatorStartFailed => 'Эмуляторды іске қосу мүмкін болмады';

  @override
  String get emulatorFiscalOperator => 'Фискалдық оператор (ОФД)';

  @override
  String get emulatorFiscalAddressHint =>
      'Бұл мекенжайды фискалдық баптаулардың «Сервер мекенжайы» өрісіне жазыңыз';

  @override
  String get emulatorFiscalBindAction => 'Фискалдық баптауларға жазу';

  @override
  String get emulatorFiscalBindNote =>
      'Эмулятордың мекенжайын, логинін, паролін, кілтін және зауыттық нөмірін жазады әрі кассаны сынақтық деп жариялайды. Тіркеу нөміріне тиіспейді';

  @override
  String get emulatorFiscalBindDone =>
      'Фискалдық баптаулар енді эмуляторға қарайды';

  @override
  String get emulatorFiscalBindingStale =>
      'Фискалдық баптаулар өшірілген эмуляторға қарайды — фискалдау орындалмайды';

  @override
  String get emulatorFiscalLocalModuleWarning =>
      '«Жергілікті модуль» өрісі толтырылған — ол сервер мекенжайын басып озады, касса эмуляторға бармайды';

  @override
  String get emulatorFiscalBlockedLive =>
      'Касса нақты жұмыс істейді: оператор деректемелері толтырылған. Мұнда ОФД эмуляторына тыйым салынады — жалғанға кеткен чек шынайы көрінеді, бірақ сатып алушыға құжат бермейді';

  @override
  String get emulatorFiscalBlockedUnknown =>
      'Фискалдық баптаулар оқылмады — ОФД эмуляторын қосу мүмкін емес';

  @override
  String get diagnosticsFiscalEmulatorBanner =>
      'Оператор мекенжайы осы компьютерге қарайды — құжаттар эмуляторға кетеді және фискалдық болып саналмайды';

  @override
  String get diagnosticsTitle => 'Жабдық диагностикасы';

  @override
  String get diagnosticsSubtitle => 'Касса аспаптарға шын мәнінде не жібергені';

  @override
  String get diagnosticsTabPrinter => 'Принтер';

  @override
  String get diagnosticsTabFiscal => 'Фискалдау';

  @override
  String get errorDiagnosticsUnavailable =>
      'Бұл кассада диагностиканы сұрайтын ешкім жоқ';

  @override
  String get diagnosticsPrinterQueueMissing =>
      'Бұл жұмыс орнында басып шығару кезегі бапталмаған';

  @override
  String get diagnosticsPrinterNothingSent =>
      'Касса принтерге әзірге ештеңе жіберген жоқ';

  @override
  String diagnosticsAskFailed(String reason) {
    return 'Касса бұл сұраққа жауап бермеді: $reason';
  }

  @override
  String diagnosticsAttempts(int count) {
    return 'әрекет $count';
  }

  @override
  String get diagnosticsJobQueued => 'кезекте тұр';

  @override
  String get diagnosticsJobPrinting => 'басылып жатыр';

  @override
  String get diagnosticsJobPrinted => 'басылды';

  @override
  String get diagnosticsJobFailed => 'басылмады';

  @override
  String get diagnosticsJobExpired => 'мерзімі өтті';

  @override
  String get diagnosticsJobCancelled => 'бас тартылды';

  @override
  String get diagnosticsFiscalNotConfigured =>
      'Бұл кассада фискалдық оператор бапталмаған';

  @override
  String get diagnosticsFiscalAccepted => 'Оператор қабылдады';

  @override
  String get diagnosticsFiscalAcceptedEmpty =>
      'Оператор әзірге бірде-бір құжат қабылдаған жоқ';

  @override
  String get diagnosticsFiscalQueued => 'Кезекте';

  @override
  String get diagnosticsFiscalQueuedEmpty =>
      'Кезек бос — жіберілгеннің бәрін оператор қабылдады';

  @override
  String diagnosticsFiscalSign(String value) {
    return 'Фискалдық белгі $value';
  }

  @override
  String diagnosticsFiscalOperatorDoc(String value) {
    return 'оператор құжаты $value';
  }

  @override
  String diagnosticsFiscalReceiptNo(String value) {
    return 'чек $value';
  }

  @override
  String get diagnosticsFiscalOffline => 'дербес берілген';

  @override
  String get diagnosticsEmulatorBanner =>
      'Принтер байланысы осы компьютерге қарайды — порттың артында қағаз емес, эмулятор';

  @override
  String get diagnosticsTabDrawer => 'Ақша жәшігі';

  @override
  String get drawerDiagnosticsEmpty =>
      'Касса іске қосылғаннан бері жәшік бір рет те ашылған жоқ';

  @override
  String get drawerDiagnosticsUnavailable =>
      'Бұл кассада жәшік импульстерінің жазбасы жоқ — сұрайтын дерек жоқ. Бұл жәшік ашылмады дегенді білдірмейді.';

  @override
  String get drawerDiagnosticsCaveat =>
      'Касса команданың қабылданғанын ғана біледі. Жәшіктің шынымен ашылғаны туралы кері байланыс екі жолда да жоқ.';

  @override
  String get drawerDiagnosticsAccepted => 'Команда қабылданды';

  @override
  String get drawerDiagnosticsRefused => 'Команда қабылданбады';

  @override
  String get drawerDiagnosticsViaSerial => 'тізбекті порт';

  @override
  String get drawerDiagnosticsViaPrinter => 'принтер арқылы (ESC p)';

  @override
  String get diagnosticsTabScales => 'Таразы';

  @override
  String get diagnosticsTabDisplay => 'Дисплей';

  @override
  String get scalesDiagnosticsUnbound =>
      'Бұл кассаға таразы байланбаған.\nОны жабдық баптауларында байланыстырыңыз — сонда мұнда көрсеткіш шығады.';

  @override
  String get scalesDiagnosticsWeight => 'Таразы көрсеткіші';

  @override
  String get scalesDiagnosticsSilent => 'Таразы әлі ештеңе жіберген жоқ';

  @override
  String get scalesDiagnosticsStable => 'Салмақ тұрақталды';

  @override
  String get scalesDiagnosticsSettling => 'Салмақ өзгеруде';

  @override
  String get scalesDiagnosticsOverload => 'Шамадан тыс жүктеме';

  @override
  String get scalesDiagnosticsPort => 'Таразы порты';

  @override
  String get scalesDiagnosticsBaudSuffix => 'бод';

  @override
  String get scalesDiagnosticsConnected => 'Порт ашық';

  @override
  String get scalesDiagnosticsDisconnected => 'Порт жабық';

  @override
  String get scalesDiagnosticsCaveat =>
      'Бұл — аспап жібергені. Көрсеткіштің дұрыстығын касса тексермейді, ол үшін тексеру бар.';

  @override
  String get displayDiagnosticsEmpty =>
      'Касса іске қосылғаннан бері дисплейге ештеңе жіберілмеді';

  @override
  String get displayDiagnosticsUnavailable =>
      'Бұл кассада дисплей жолдарының жазбасы жоқ — сұрайтын дерек жоқ. Бұл дисплейге ештеңе жіберілмеді дегенді білдірмейді.';

  @override
  String get displayDiagnosticsCurrent => 'Қазір дисплейде';

  @override
  String get displayDiagnosticsCaveat =>
      'Касса жолдың портқа кеткенін ғана біледі. Сөнген не ажыратылған дисплей мұнда жұмыс істеп тұрғаннан ажыратылмайды.';

  @override
  String get displayDiagnosticsCallPrice => 'баға';

  @override
  String get displayDiagnosticsCallTotal => 'жиыны';

  @override
  String get displayDiagnosticsCallChange => 'қайтарым';

  @override
  String get displayDiagnosticsCallText => 'мәтін';

  @override
  String get displayDiagnosticsCallWelcome => 'сәлемдесу';

  @override
  String get displayDiagnosticsCallClear => 'тазалау';

  @override
  String get emulatorScaleWeight => 'Табақтағы салмақ';

  @override
  String get emulatorScaleWeightHint =>
      'Эмулятор пульті: таразы кассаға осы санды жібереді';

  @override
  String get emulatorQrProvider => 'QR төлем провайдері';

  @override
  String get emulatorQrBindDone => 'QR баптауы енді эмуляторға қарайды';

  @override
  String get diagnosticsTabPayment => 'Төлем';

  @override
  String get diagnosticsPaymentEmulatorBanner =>
      'QR провайдері осы компьютерде: мекенжайдың артында банк емес, эмулятор';

  @override
  String get paymentDiagnosticsUnavailable =>
      'Бұл жұмыс орнында төлем туралы дерек жоқ';

  @override
  String get paymentDiagnosticsQrSection => 'QR арқылы төлем';

  @override
  String get paymentDiagnosticsQrEmpty =>
      'Касса әзірге бірде-бір төлем кодын жасаған жоқ';

  @override
  String get paymentDiagnosticsQrNotConfigured =>
      'Бұл кассада QR провайдері бапталмаған';

  @override
  String paymentDiagnosticsQrAddress(String address) {
    return 'Провайдер: $address';
  }

  @override
  String get paymentDiagnosticsQrUnknown =>
      'Провайдерге жіберілген сұрау денелерін касса сақтамайды. Көрінетіні — ниетте қалғаны: сома, күй, ол жақтағы сәйкестендіргіш және бас тарту себебі.';

  @override
  String get paymentDiagnosticsTerminalSection => 'Төлем терминалы';

  @override
  String get paymentDiagnosticsTerminalEmpty =>
      'Касса қосылғаннан бері төлем терминалына бірде-бір кадр кеткен жоқ';

  @override
  String get paymentDiagnosticsTerminalUnknown =>
      'Терминал журналы жадта тұрады: қайта қосуға дейінгі алмасулар сақталмайды, ал терминалдың өзінде жасалған операцияларды касса мүлде көрмейді.';

  @override
  String get paymentDiagnosticsRequest => 'Сұрау';

  @override
  String get paymentDiagnosticsReply => 'Жауап';

  @override
  String get paymentDiagnosticsNoReply => 'Жауап болмады';

  @override
  String paymentDiagnosticsApproval(String value) {
    return 'Мақұлдау коды $value';
  }

  @override
  String paymentDiagnosticsTransaction(String value) {
    return 'транзакция $value';
  }

  @override
  String paymentDiagnosticsRefusal(String value) {
    return 'Бас тарту: $value';
  }

  @override
  String paymentDiagnosticsConfirmations(int count) {
    return 'растау саны $count';
  }

  @override
  String get paymentDiagnosticsOrphanMoney => 'чегі жоқ ақша';

  @override
  String get paymentDiagnosticsAfterGiveUp =>
      'касса күтуді тоқтатқаннан кейін расталды';

  @override
  String get paymentDiagnosticsApproved => 'Мақұлданды';

  @override
  String get paymentDiagnosticsDeclined => 'Бас тартылды';

  @override
  String get paymentDiagnosticsOpPurchase => 'сатып алу';

  @override
  String get paymentDiagnosticsOpReversal => 'сторно';

  @override
  String get paymentDiagnosticsOpRefund => 'қайтару';

  @override
  String get paymentDiagnosticsOpUnknown => 'белгісіз түрдегі кадр';

  @override
  String get certificateIssueTitle => 'Сыйлық сертификатын шығару';

  @override
  String get certificateIssueHint =>
      'Қағаз үшін ақшаны сату чегі қабылдайды. Мұнда қағазға қалдық ашылады, касса міндеттеме алады.';

  @override
  String get certificateIssueNumber => 'Қағаз нөмірі';

  @override
  String get certificateIssueNominal => 'Номинал';

  @override
  String get certificateIssuePin => 'ПИН (міндетті емес)';

  @override
  String get certificateIssueExpiresDays =>
      'Жарамдылық мерзімі, күн (міндетті емес)';

  @override
  String get certificateIssueReceipt => 'Сату чегінің нөмірі (міндетті емес)';

  @override
  String get certificateIssueSubmit => 'Сертификат шығару';

  @override
  String certificateIssueDone(String number, String amount) {
    return '$number сертификаты $amount сомасына шығарылды';
  }

  @override
  String get certificateIssueFailed => 'Сертификат шығарылмады';

  @override
  String get certificateIssueNumberRequired => 'Қағаз нөмірін енгізіңіз';

  @override
  String get certificateIssueNominalInvalid =>
      'Номинал нөлден үлкен болуы керек';

  @override
  String get certificateIssueNotPermitted =>
      'Бұл кассирге сертификат шығаруға рұқсат жоқ';

  @override
  String get certificateSlipTitle => 'Слипті қайта басып шығару';

  @override
  String get certificateSlipHint =>
      'Шығару кезінде слип басылмады — қағазды қайталама слип бойынша беруге болады.';

  @override
  String get certificateSlipNumber => 'Сертификат нөмірі';

  @override
  String get certificateSlipPin => 'ПИН, егер бар болса';

  @override
  String get certificateSlipSubmit => 'Слипті басып шығару';

  @override
  String certificateSlipDone(String number) {
    return '$number сертификатының слипі басып шығаруға жіберілді';
  }

  @override
  String get certificateSlipFailed => 'Слип басып шығаруға жіберілмеді';

  @override
  String get certificateSlipUnavailable =>
      'Бұл кассада слип басатын құрылғы жоқ';

  @override
  String get prepaymentRefundTitle => 'Авансты қайтару';

  @override
  String get prepaymentRefundHint =>
      'Сатып алушы алдын ала енгізген ақша қайтарылады. Қарыз бұнымен өтелмейді, бонустар қозғалмайды.';

  @override
  String prepaymentRefundBalance(String amount) {
    return 'Алдын ала енгізілген: $amount';
  }

  @override
  String get prepaymentRefundNothing =>
      'Сатып алушының шотында аванс жоқ — қайтаратын ештеңе жоқ';

  @override
  String get prepaymentRefundAmount => 'Қайтарылатын сома';

  @override
  String get prepaymentRefundTender => 'Немен қайтарылады';

  @override
  String get prepaymentRefundIntake =>
      'Қабылдау жазбасының нөмірі (міндетті емес)';

  @override
  String get prepaymentRefundSubmit => 'Авансты қайтару';

  @override
  String prepaymentRefundDone(String amount) {
    return 'Аванс қайтарылды. Шотта қалғаны: $amount';
  }

  @override
  String get prepaymentRefundFailed => 'Аванс қайтарылмады';

  @override
  String get prepaymentRefundAmountInvalid => 'Сома нөлден үлкен болуы керек';

  @override
  String get prepaymentRefundNotPermitted =>
      'Бұл кассирге авансты қайтаруға рұқсат жоқ';

  @override
  String get prepaymentRefundFiscalFailed =>
      'Ақша берілді, бірақ аванс қайтарымының фискалдық чегі жазылмады.';

  @override
  String get agentRefundPrepayment => 'Авансты қайтару';

  @override
  String get repTitle => 'Есептер';

  @override
  String get repTabAnalytics => 'Аналитика';

  @override
  String get repTabFinance => 'Қаржы';

  @override
  String get repTabForecasts => 'Болжамдар';

  @override
  String get repTabTaxKz => 'Салықтар/ҚР';

  @override
  String get repRangeDays7 => '7 күн';

  @override
  String get repRangeDays30 => '30 күн';

  @override
  String get repRangeCustom => 'Еркін';

  @override
  String get repKpiChange => 'Өзгеріс';

  @override
  String get repSubtitleVsPrev => 'алдыңғы кезеңмен';

  @override
  String get repChartRevenueByDay => 'Күн бойынша түсім';

  @override
  String get repChartTop5Products => 'Үздік 5 тауар';

  @override
  String get repChartPaymentMethods => 'Төлем тәсілдері';

  @override
  String get settingsRestartRequired =>
      'Өзгерістер касса келесі рет іске қосылғанда қолданылады.';

  @override
  String get hardwareRestartRequired =>
      'Құрылғы өзгерістері касса келесі рет іске қосылғанда қолданылады.';

  @override
  String get hardwareDeviceDisabled => 'Құрылғы өшірілген.';

  @override
  String get hardwareCustomerDisplayGraphic =>
      'Сатып алушының графикалық экраны (2-монитор)';

  @override
  String get hardwareCustomerDisplayGraphicOff =>
      'Сатып алушының графикалық экраны өшірілген.';

  @override
  String get hardwarePaymentKinds => 'Жұмыс орнының төлем түрлері';

  @override
  String get hardwarePaymentKindsUnrestricted =>
      'Шектеу жоқ: жұмыс орны барлық төлем түрлерін қабылдайды.';

  @override
  String get fiscalSettingsDirectOfdLabel => 'ОФД-ға тікелей қосылу';

  @override
  String get markupAuto => 'Авто үстеме';

  @override
  String get markupSave => 'Үстемелерді сақтау';

  @override
  String get creditContractNumberLabel => 'Қағаздағы шарт нөмірі';

  @override
  String get creditNoLiveContracts => 'Белсенді бөліп төлеу шарттары жоқ';

  @override
  String get supplierOrderTitle => 'Жеткізушіге өтінім';

  @override
  String get supplierOrderAllStocked => 'Барлық тауар жеткілікті мөлшерде';

  @override
  String get supplierOrderNotNeeded => 'Қосымша тапсырыс қажет емес';

  @override
  String get hwScaleTitle => 'Таразы';

  @override
  String get hwReceiptPrinterTitle => 'Чек принтері';

  @override
  String get repRangeDays14 => '14 күн';

  @override
  String get repForecastSmaLowData => 'SMA (деректер аз)';

  @override
  String get repNoCategory => 'Санатсыз';

  @override
  String get repAllCustomers => 'Барлық клиенттер';

  @override
  String get repAllInStock => 'Барлық тауар қоймада';

  @override
  String get repAllCovered30 => 'Барлық тауар 30+ күнге жетеді';

  @override
  String get repColDays => 'Күн';

  @override
  String get repColDaysLeft => 'Қалған күн';

  @override
  String get repColSharePct => 'Үлес %';

  @override
  String get repColChangePct => 'Өзгеріс %';

  @override
  String get repColSalesCount => 'Сату саны';

  @override
  String get repReceiptCountLabel => 'Чек саны';

  @override
  String get repStockCritical => 'Қалдық тым аз! Шұғыл жеткізу қажет.';

  @override
  String get repColCumulativePct => 'Жинақ. %';

  @override
  String get repNotEnoughSalesData =>
      'Таңдалған кезеңде сату деректері жеткіліксіз';

  @override
  String get repNoForecastData => 'Болжам жасауға дерек жоқ';

  @override
  String get repNoDataLast90 => 'Соңғы 90 күнде дерек жоқ';

  @override
  String get repNoCustomerData => 'Клиенттер туралы дерек жоқ';

  @override
  String get repNoLowStock => 'Қалдығы аз тауар жоқ';

  @override
  String get repLowStock => 'Қалдық аз';

  @override
  String get repNewPrice => 'Жаңа баға';

  @override
  String get repColEstimatedAmount => 'Болжам. сома';

  @override
  String get repColSeatings => 'Отырғызу';

  @override
  String get repForecast => 'Болжам';

  @override
  String get repRevenueForecast => 'Түсім болжамы';

  @override
  String get repRevenueForecastHw => 'Түсім болжамы (Holt-Winters)';

  @override
  String get repStockoutForecast => 'Қалдықтың таусылу болжамы';

  @override
  String get repStockForecast => 'Қалдық болжамы';

  @override
  String get repSalesWithoutCustomerHidden =>
      'Клиентке байланбаған сатулар көрсетілмейді';

  @override
  String get repColSalesPerDay => 'Сату/күн';

  @override
  String get repColSold => 'Сатылды';

  @override
  String get repHourlyDistribution => 'Сағат бойынша бөліну';

  @override
  String get repColRecommendedOrder => 'Ұсын. тапсырыс';

  @override
  String get repRecommendedPurchases => 'Ұсынылатын сатып алу';

  @override
  String get repColAvgSalesPerDay => 'Орт. сату/күн';

  @override
  String get repColAvgCheckShort => 'Орт. чек';

  @override
  String get repAvgPrice => 'Орташа баға';

  @override
  String get repOldPrice => 'Ескі баға';

  @override
  String get repStockValue => 'Қалдық құны';

  @override
  String get repColTable => 'Үстел';

  @override
  String get repCurrentStock => 'Ағымдағы қалдық';

  @override
  String get repTop10Customers => 'Үздік 10 клиент';

  @override
  String get repTop10Products => 'Үздік 10 тауар';

  @override
  String get repActual => 'Нақты';

  @override
  String get repColHour => 'Сағат';

  @override
  String get repExport => 'Экспорт';

  @override
  String get repCashierPerformance => 'Кассирлердің тиімділігі';

  @override
  String get repWeightedAvgHint => 'өлшенген орташа (соңғы күндер салмақтырақ)';

  @override
  String get repSalesCountByHour => 'сағат бойынша сату саны';

  @override
  String get repNoUrgentItems => 'шұғыл позиция жоқ';

  @override
  String get repByRevenueTapHint =>
      'түсім бойынша (егжей-тегжейі үшін басыңыз)';

  @override
  String get repDistributionTapHint => 'бөліну (секторды басыңыз)';

  @override
  String get repRevenueDistributionTapHint =>
      'түсімнің бөлінуі (секторды басыңыз)';

  @override
  String get repAbcRare => 'сирек';

  @override
  String get repAbcMedium => 'орташа';

  @override
  String get repAbcFast => 'өтімді';

  @override
  String get repAbcLegend =>
      'өтімді (A), орташа (B), сирек (C) — түсімге қосқан үлесі бойынша';

  @override
  String repReturnsCount(int count) {
    return '$count қайтару';
  }

  @override
  String repAbcGroupSummary(int count, String pct) {
    return '$count тауар · $pct%';
  }

  @override
  String repCustomerTooltip(String name, String amount, int count) {
    return '$name\n$amount ($count чек)';
  }

  @override
  String repDaysCountTapHint(int count) {
    return '$count күн (егжей-тегжейі үшін басыңыз)';
  }

  @override
  String repCashiersCount(int count) {
    return '$count кассир';
  }

  @override
  String repLowStockCountHint(int count) {
    return '$count тауар (қалдық < 10, басыңыз)';
  }

  @override
  String repOrdersShort(int count) {
    return '$count тапс.';
  }

  @override
  String repOrdersRevenueTooltip(int count, String amount) {
    return '$count тапс.\n$amount';
  }

  @override
  String repPieces(String qty) {
    return '$qty дана';
  }

  @override
  String repPiecesDot(String qty) {
    return '$qty дана';
  }

  @override
  String repForecastSubtitle(int actual, int horizon, String algorithm) {
    return '$actual күн нақты + $horizon күн болжам ($algorithm)';
  }

  @override
  String repSalesCountLine(int count) {
    return '$count сату';
  }

  @override
  String repReceiptsCount(int count) {
    return '$count чек';
  }

  @override
  String repSupplierTooltip(String name, int count) {
    return '$name\n$count жеткізу';
  }

  @override
  String repSeatingsLine(int count) {
    return '$count отырғызу';
  }

  @override
  String repDayOffset(int n) {
    return '+$n күн';
  }

  @override
  String repHoltWintersSeason(int season) {
    return 'Holt-Winters (маусым=$season)';
  }

  @override
  String repInvestmentsLine(String amount) {
    return 'Салымдар: $amount';
  }

  @override
  String repDividendsLine(String amount) {
    return 'Дивидендтер: $amount';
  }

  @override
  String repMarginLine(String pct) {
    return 'Маржа: $pct%';
  }

  @override
  String repKpiLoadErrorWith(String error) {
    return 'KPI жүктелмеді: $error';
  }

  @override
  String repErrorWith(String error) {
    return 'Қате: $error';
  }

  @override
  String repProfitLine(String amount) {
    return 'Пайда: $amount';
  }

  @override
  String repExpensesLine(String amount) {
    return 'Шығыстар: $amount';
  }

  @override
  String repLeadTimeHint(int lead, int safety) {
    return 'жеткізу мерзімі $lead к. + сақтық қор $safety к.';
  }

  @override
  String get markupHint =>
      'Санат бойынша үстеме, %. Тауар келгенде бөлшек баға сатып алу бағасынан қайта есептеледі: сатып алу × (1 + үстеме%).';

  @override
  String get creditContractsTitle => 'Бөліп төлеу';

  @override
  String creditContractsTitleFor(String agent) {
    return 'Бөліп төлеу — $agent';
  }

  @override
  String repExportedTo(String path) {
    return 'Экспортталды: $path';
  }

  @override
  String repExportFailed(String error) {
    return 'Экспорт қатесі: $error';
  }

  @override
  String get hwSetupIncompleteDevices =>
      'Баптау шебері аяқталмаған — құрылғыларды сақтайтын жер жоқ';

  @override
  String get hwSetupIncompleteCheck =>
      'Баптау шебері аяқталмаған — тексеретін ештеңе жоқ';

  @override
  String get settingsSetupIncompleteSave =>
      'Баптау шебері аяқталмаған — сақтайтын жер жоқ';

  @override
  String get hwProfileCatalogUnavailable =>
      'Құрылғы профильдерінің каталогы қолжетімсіз — құрылғы баптауларын қазір өзгерту мүмкін емес.';

  @override
  String get printerProfileCatalogUnavailable =>
      'Құрылғы профильдерінің каталогы қолжетімсіз — принтер баптауларын қазір өзгерту мүмкін емес.';

  @override
  String get labelPrinterProfileCatalogUnavailable =>
      'Құрылғы профильдерінің каталогы қолжетімсіз — затбелгі принтерінің баптауларын қазір өзгерту мүмкін емес.';

  @override
  String get hwPaymentKindsUnsupported =>
      'Бұл құрастырым жұмыс орнының төлем түрлерін сақтай алмайды.';

  @override
  String get hwPaymentKindsEnforcedByTill =>
      'Тыйымды касса тексереді: төлем түріне рұқсаты жоқ терминал бас тарту алады, экранындағы түйме қалса да.';

  @override
  String get hwCustomerDisplayGraphicDesc =>
      'Екінші мониторда сатып алушыға арналған графикалық экран: чек жолдары, саны және жиыны — нақты уақытта.';

  @override
  String get hwCustomerDisplayMonitor =>
      'Сатып алушы экранына арналған монитор';

  @override
  String get hwCustomerDisplayMonitorHint =>
      'POS негізгі мониторда қалады. Касса келесі рет іске қосылғанда автоматты түрде ашылады.';

  @override
  String get hwNoProfilesForClass =>
      'Бұл құрылғы класы үшін қолжетімді үлгі жоқ.';

  @override
  String get hwNoConnectionParams =>
      'Бұл үлгі қосымша қосылу параметрлерін қажет етпейді.';

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
    return 'Төлем түрлері: $error';
  }

  @override
  String hwPaymentKindsUnknown(String list) {
    return 'Бұл жұмыс орнының баптауында осы нұсқа білмейтін түрлер жазылған: $list. Олар бойынша шектеу жоқ. Жазбаны түзету үшін түрлерді қайта таңдаңыз — оған дейін ол сол күйінде қалады.';
  }

  @override
  String hwParamOptional(String description) {
    return '$description (міндетті емес)';
  }

  @override
  String globalMillimetres(String value) {
    return '$value мм';
  }

  @override
  String get devProfilePrinterEscpos80mm => 'ESC/POS чек принтері, 80 мм';

  @override
  String get devProfilePrinterEscpos58mm =>
      'ESC/POS чек принтері, 58 мм (шағын, пышақсыз)';

  @override
  String get devProfilePrinterEscposUsb => 'ESC/POS чек принтері, USB/спулер';

  @override
  String get devProfilePrinterEscposBluetooth =>
      'ESC/POS чек принтері, Bluetooth';

  @override
  String get devProfilePrinterEscposSerial =>
      'ESC/POS чек принтері, тізбекті порт';

  @override
  String get devProfilePrinterLabelZpl104 => 'ZPL затбелгі принтері, 104 мм';

  @override
  String get devProfilePrinterLabelEpl58 => 'EPL затбелгі принтері, 58 мм';

  @override
  String get devProfileScannerUsbHid => 'USB штрихкод сканері (HID)';

  @override
  String get devProfileScannerBluetoothHid =>
      'Bluetooth штрихкод сканері (HID)';

  @override
  String get devProfileScannerCamera => 'Құрылғы камерасы арқылы сканер';

  @override
  String get devProfileScannerSerial => 'Штрихкод сканері, тізбекті порт';

  @override
  String get devProfileScaleCasPd2 => 'CAS PD-II таразысы (тізбекті)';

  @override
  String get devProfileScaleCasErPlus => 'CAS ER-Plus таразысы';

  @override
  String get devProfileDrawerViaPrinter => 'Принтер арқылы ақша жәшігі (RJ11)';

  @override
  String get devProfileDrawerStandalone => 'Автономды ақша жәшігі (RJ11)';

  @override
  String get devProfileDisplayVfd => 'VFD сатып алушы дисплейі (тізбекті)';

  @override
  String get devProfileDisplayLcd2x20 => 'LCD сатып алушы дисплейі 2x20';

  @override
  String get devProfileDisplayLed8 => 'LED сатып алушы дисплейі (8 таңба)';

  @override
  String get devProfilePaymentKaspiPos => 'Kaspi POS терминалы';

  @override
  String get devParamPrinterIpAddress => 'Желілік принтердің IP-мекенжайы';

  @override
  String get devParamTcpPort9100 => 'TCP-порт, әдепкі 9100';

  @override
  String get devParamPrinterDevicePath =>
      'Құрылғы жолы немесе басып шығару кезегінің аты';

  @override
  String get devParamPrinterMac =>
      'Жұптастырылған Bluetooth принтерінің MAC-мекенжайы';

  @override
  String get devParamPrinterComPort => 'Принтердің тізбекті порты, мысалы COM4';

  @override
  String get devParamLabelPrinterIp => 'Затбелгі принтерінің IP-мекенжайы';

  @override
  String get devParamScannerMac =>
      'Жұптастырылған Bluetooth сканерінің MAC-мекенжайы';

  @override
  String get devParamScannerComPort => 'Сканердің тізбекті порты, мысалы COM5';

  @override
  String get devParamScaleComPort => 'Таразының тізбекті порты, мысалы COM3';

  @override
  String get devParamDrawerComPort =>
      'Жәшік интерфейс тақтасының тізбекті порты';

  @override
  String get devParamDisplayComPort => 'Сатып алушы дисплейінің тізбекті порты';

  @override
  String get devParamKaspiIp => 'Kaspi POS терминалының IP-мекенжайы';

  @override
  String get devParamKaspiPort => 'Терминал порты, әдетте 8888';

  @override
  String get devParamCameraId => 'Қай камераны қолдану керек';

  @override
  String get rcpTill => 'Касса';

  @override
  String get rcpTillColon => 'Касса:';

  @override
  String get rcpReceiptNo => 'Чек №';

  @override
  String get rcpCashier => 'Кассир:';

  @override
  String get rcpCustomer => 'Клиент:';

  @override
  String get rcpDate => 'Күні:';

  @override
  String get rcpBinIin => 'БСН/ЖСН:';

  @override
  String get rcpSale => 'САТУ';

  @override
  String get rcpSubtotal => 'Аралық жиын:';

  @override
  String get rcpDiscount => 'Жеңілдік:';

  @override
  String get rcpServiceFee => 'Қызмет ақысы:';

  @override
  String get rcpTotal => 'ЖИЫНЫ:';

  @override
  String get rcpChange => 'Қайтарым:';

  @override
  String get rcpCash => 'ҚОЛМА-ҚОЛ';

  @override
  String get rcpCard => 'КАРТА';

  @override
  String get rcpQuantityShort => 'дана';

  @override
  String get rcpRefund => 'ҚАЙТАРУ';

  @override
  String get rcpRefundNo => 'Қайтару №';

  @override
  String get rcpSaleReceiptNo => 'Сату чегі №';

  @override
  String get rcpDuplicate => '*** ТЕЛНҰСҚА ***';

  @override
  String get rcpTable => 'Үстел:';

  @override
  String get rcpWaiter => 'Даяшы:';

  @override
  String get rcpGuests => 'Қонақтар:';

  @override
  String get rcpFiscalReceipt => 'ФИСКАЛДЫҚ ЧЕК';

  @override
  String get rcpNonFiscalReceipt => 'ФИСКАЛДЫҚ ЕМЕС ЧЕК';

  @override
  String get rcpNotFiscalDocument => 'ФИСКАЛДЫҚ ҚҰЖАТ ЕМЕС';

  @override
  String get rcpFiscalSign => 'ФИСК. БЕЛГІ:';

  @override
  String get rcpFiscalFn => 'ФЖ:';

  @override
  String get rcpFiscalRnm => 'ТНН:';

  @override
  String get rcpFiscalZnm => 'ЗНН:';

  @override
  String get rcpFiscalTime => 'УАҚЫТ:';

  @override
  String get rcpOfdName => 'ФДО';

  @override
  String get rcpOffline => '*** ОФФЛАЙН ***';

  @override
  String get rcpVerifyAt => 'Чекті тексеру үшін кіріңіз';

  @override
  String get rcpCustomerTaxId => 'Сатып алушының ЖСН:';

  @override
  String get rcpTaxA => 'А САЛЫҒЫ БОЙЫНША:';

  @override
  String get rcpFiscalOperatorNotSet => 'Фискалдық оператор бапталмаған';

  @override
  String get rcpFiscalModuleUnavailable => 'Фискалдау модулі қолжетімсіз';

  @override
  String get rcpDocumentNotIssued =>
      'Құжат ресімделмеді — кассирге хабарласыңыз';

  @override
  String get rcpXReport => 'X-ЕСЕП';

  @override
  String get rcpZReport => 'Z-ЕСЕП';

  @override
  String get rcpInterim => 'АРАЛЫҚ (өшірусіз)';

  @override
  String get rcpShiftClose => 'АУЫСЫМДЫ ЖАБУ';

  @override
  String get rcpShiftStart => 'Басталуы:';

  @override
  String get rcpShiftEnd => 'Аяқталуы:';

  @override
  String get rcpSales => 'САТУЛАР';

  @override
  String get rcpRefunds => 'ҚАЙТАРУЛАР';

  @override
  String get rcpCount => 'Саны:';

  @override
  String get rcpAmount => 'Сомасы:';

  @override
  String get rcpCashOps => 'АҚША ОПЕРАЦИЯЛАРЫ';

  @override
  String get rcpOpeningFloat => 'Басына:';

  @override
  String get rcpSlipTitle => 'ТҮБІРТЕК';

  @override
  String get rcpType => 'Түрі:';

  @override
  String get rcpComment => 'Түсініктеме:';

  @override
  String get rcpCashIn => 'Кіріс:';

  @override
  String get rcpCashOut => 'Шығыс:';

  @override
  String get rcpTotalInDrawer => 'КАССАДА ЖИЫНЫ:';

  @override
  String get rcpCertificatesNotRevenue => 'СЕРТИФИКАТТАР (ТҮСІМ ЕМЕС)';

  @override
  String get rcpCertIssuedDebt => 'Шығарылды (касса борышы):';

  @override
  String get rcpCertRedeemed => 'Өтелді (тауармен):';

  @override
  String get rcpGiftCertificate => 'СЫЙЛЫҚ СЕРТИФИКАТЫ';

  @override
  String get rcpCertNo => 'Сертификат №';

  @override
  String get rcpCertFaceValue => 'Номиналы:';

  @override
  String get rcpCertValidUntil => 'Жарамдылығы:';

  @override
  String get rcpCertNoExpiry => 'мерзімсіз';

  @override
  String get rcpCertPinSet => 'ПИН қойылған';

  @override
  String get rcpCertIssuedByRefund => 'Қайтарумен шығарылды №';

  @override
  String get rcpCertInsteadOf => 'Сертификаттың орнына';

  @override
  String get rcpVat => 'ҚҚС';

  @override
  String get rcpSalesTax => 'Сатудан салық';

  @override
  String get rcpTaxExempt => 'Салық салынбайды';

  @override
  String get rcpTaxExemptMark => 'бос';

  @override
  String get taxSettingsTitle => 'Салықтар';

  @override
  String get taxSettingsSubtitle =>
      'Мөлшерлемелер, юрисдикциялар және тауар санаттары';

  @override
  String get taxSettingsIntro =>
      'Мөлшерлеме бір санмен берілмейді: ол касса тұрған юрисдикциялардың үлестерінен құралады және тауар санаты мен күнге байланысты. Дайын жинақты алып, кейін түзетуге болады.';

  @override
  String get taxSettingsNotConfigured =>
      'Салық бапталмаған: касса нөл есептейді.';

  @override
  String get taxSettingsPresetSection => 'Дайын жинақ';

  @override
  String get taxSettingsCountry => 'Ел';

  @override
  String get taxSettingsRegion => 'Штат немесе облыс';

  @override
  String get taxSettingsCity => 'Қала';

  @override
  String get taxSettingsPreset => 'Жинақ';

  @override
  String get taxSettingsApplyPreset => 'Жинақты қолдану';

  @override
  String get taxSettingsPresetReplaces =>
      'Қолдану ағымдағы баптауды толық ауыстырады. Екі жинақты қосуға болмайды: касса салықты екі есе алар еді.';

  @override
  String taxSettingsPresetSource(String source) {
    return 'Дереккөз: $source';
  }

  @override
  String taxSettingsPresetValidFrom(String date) {
    return 'Мөлшерлемелер $date бастап қолданылады';
  }

  @override
  String get taxSettingsPresetApplied => 'Жинақ қолданылды';

  @override
  String taxSettingsRateForStandard(String rate) {
    return 'Кәдімгі тауар: $rate%';
  }

  @override
  String get taxSettingsJurisdictions => 'Юрисдикциялар';

  @override
  String get taxSettingsCategories => 'Тауар санаттары';

  @override
  String get taxSettingsTillLocation => 'Касса осында тұр';

  @override
  String get taxSettingsTillLocationHint =>
      'Белгі бірнеше болуы мүмкін: қала және арнайы аудандар. Жоғарғылары өздігінен қосылады.';

  @override
  String get taxSettingsRuleTaxed => 'салықталады';

  @override
  String get taxSettingsRuleZero => 'нөлдік мөлшерлеме';

  @override
  String get taxSettingsRuleExempt => 'босатылған';

  @override
  String get taxSettingsAllCategories => 'барлық санаттар';

  @override
  String get taxSettingsAddJurisdiction => 'Юрисдикция қосу';

  @override
  String get taxSettingsAddCategory => 'Санат қосу';

  @override
  String get taxSettingsName => 'Атауы';

  @override
  String get taxSettingsDelete => 'Жою';

  @override
  String get taxSettingsResponsibility =>
      'Жинақтардағы сандар ашық дереккөздерден алынған және сілтемемен аталған. Салықтың дұрыстығына бағдарлама емес, салық төлеуші жауап береді.';

  @override
  String get taxSettingsNoPresetsForCountry =>
      'Бұл ел үшін дайын жинақ жоқ — қолмен баптаңыз.';

  @override
  String get taxSettingsAdd => 'Қосу';

  @override
  String get taxSettingsCancel => 'Бас тарту';

  @override
  String get setupStoreAddressHint => 'Абай к-сі, 10, Алматы';

  @override
  String get setupStoreAddressHelper =>
      'Чекке басылады. Онсыз сатып алушы сатып алу қай жерде жасалғанын көрмейді.';

  @override
  String get countryKz => 'Қазақстан';

  @override
  String get countryRu => 'Ресей';

  @override
  String get countryKg => 'Қырғызстан';

  @override
  String get countryUz => 'Өзбекстан';

  @override
  String get countryUs => 'АҚШ';

  @override
  String get countryTm => 'Түрікменстан';

  @override
  String get currencyKzt => 'Қазақстан теңгесі';

  @override
  String get currencyRub => 'Ресей рублі';

  @override
  String get currencyKgs => 'Қырғыз сомы';

  @override
  String get currencyUzs => 'Өзбек сумы';

  @override
  String get currencyUsd => 'АҚШ доллары';

  @override
  String get currencyTmt => 'Түрікмен манаты';

  @override
  String get setupStepSalesTax => 'Сатудан салық';

  @override
  String get setupSalesTaxPayerTitle => 'Сатудан салық жинаймын';

  @override
  String get setupSalesTaxPayerSubtitle =>
      'Мөлшерлемелер «Баптаулар → Салықтар» бөлімінде юрисдикция бойынша беріледі';

  @override
  String get setupSalesTaxPayerDescription =>
      'Салық баға үстіне қосылады және чекте жеке жолмен басылады.';

  @override
  String get setupSalesTaxNonPayerTitle => 'Сатудан салықсыз';

  @override
  String get setupSalesTaxNonPayerSubtitle => 'Бағаға ештеңе қосылмайды';

  @override
  String get setupSalesTaxNonPayerDescription =>
      'Бағаға ештеңе қосылмайды, чекте салық жолы жоқ.';

  @override
  String get bootLoadingConfig => 'Конфигурацияны жүктеу…';

  @override
  String get bootCheckingPosKey => 'Касса кілтін тексеру…';

  @override
  String get bootLoadingAgents => 'Контрагенттерді жүктеу…';

  @override
  String get bootLoadingAccounts => 'Шоттарды жүктеу…';

  @override
  String get bootInitialisingDatabase => 'Дерекқорды дайындау…';

  @override
  String get bootLoadingCashiers => 'Кассирлерді жүктеу…';

  @override
  String get bootLoadingPosData => 'Касса деректерін жүктеу…';

  @override
  String get bootLoadingProducts => 'Тауарларды жүктеу…';

  @override
  String get bootCheckingReceiptNumbers => 'Чек нөмірлеуін тексеру…';

  @override
  String get bootCheckingLicence => 'Лицензияны тексеру…';

  @override
  String get bootCheckingReports => 'Есептерді тексеру…';

  @override
  String get bootFinishingInitialisation => 'Аяқтау…';

  @override
  String get bootStartingBackgroundJobs => 'Фондық тапсырмаларды қосу…';

  @override
  String get bootReady => 'Дайын';

  @override
  String get bootDataLoaded => 'Деректер жүктелді';

  @override
  String bootTillNotResponding(String code) {
    return 'Касса жауап бермейді: $code';
  }

  @override
  String get bootDownloadingBackup => 'Сақтық көшірмені жүктеу…';

  @override
  String get bootBackupDownloadFailed =>
      'Сақтық көшірмені жүктеу мүмкін болмады';

  @override
  String get bootRestoringDatabase => 'Дерекқорды қалпына келтіру…';

  @override
  String get bootDatabaseRestoreFailed =>
      'Дерекқорды қалпына келтіру мүмкін болмады';

  @override
  String get bootApplyingPosKey => 'Касса кілтін баптау…';

  @override
  String get bootRestoreDone => 'Қалпына келтіру аяқталды';

  @override
  String get bootCreatingBackup => 'Сақтық көшірме жасау…';

  @override
  String get bootBackupCreateFailed => 'Сақтық көшірме жасау мүмкін болмады';

  @override
  String get bootBackupDone => 'Сақтық көшірме жасалып жүктелді';

  @override
  String get bootLoadingUsers => 'Пайдаланушыларды жүктеу…';

  @override
  String get bootLoadingCategories => 'Санаттарды жүктеу…';

  @override
  String get bootLoadingSettings => 'Баптауларды жүктеу…';

  @override
  String get bootSyncDone => 'Синхрондау аяқталды';

  @override
  String get bootFailed => 'Қате';

  @override
  String get countryDeu => 'Германия';

  @override
  String get currencyDeu => 'Еуро';

  @override
  String get countryFra => 'Франция';

  @override
  String get currencyFra => 'Еуро';

  @override
  String get countryEsp => 'Испания';

  @override
  String get currencyEsp => 'Еуро';

  @override
  String get countryIta => 'Италия';

  @override
  String get currencyIta => 'Еуро';

  @override
  String get countryGbr => 'Ұлыбритания';

  @override
  String get currencyGbr => 'Фунт стерлинг';

  @override
  String get countryPol => 'Польша';

  @override
  String get currencyPol => 'Поляк злотыйы';

  @override
  String get countryTur => 'Түркия';

  @override
  String get currencyTur => 'Түрік лирасы';

  @override
  String get countryChn => 'Қытай';

  @override
  String get currencyChn => 'Қытай юані';

  @override
  String get countryJpn => 'Жапония';

  @override
  String get currencyJpn => 'Жапон иенасы';

  @override
  String get countryKor => 'Оңтүстік Корея';

  @override
  String get currencyKor => 'Корей вонасы';

  @override
  String get countryAre => 'БАӘ';

  @override
  String get currencyAre => 'БАӘ дирхамы';

  @override
  String get countrySau => 'Сауд Арабиясы';

  @override
  String get currencySau => 'Сауд риялы';

  @override
  String get countryInd => 'Үндістан';

  @override
  String get currencyInd => 'Үнді рупиясы';

  @override
  String get countryCan => 'Канада';

  @override
  String get currencyCan => 'Канада доллары';

  @override
  String get countryAus => 'Австралия';

  @override
  String get currencyAus => 'Австралия доллары';

  @override
  String get agentPaymentAccepted => 'Төлем қабылданды';

  @override
  String get catalogCategoryHasChildren => 'Санатта ішкі санаттар бар';

  @override
  String creditOutstanding(String amount) {
    return 'Қалды: $amount';
  }

  @override
  String get creditTakePayment => 'Төлемді қабылдау';

  @override
  String get creditPrintContract => 'Шартты басып шығару';

  @override
  String creditPaymentFor(String number) {
    return '$number бойынша төлем';
  }

  @override
  String creditOutstandingOnContract(String amount) {
    return 'Шарт бойынша қалды: $amount';
  }

  @override
  String get creditPayInFull => 'Толық өтеу';

  @override
  String get creditAccept => 'Қабылдау';

  @override
  String get displayProduct => 'Тауар';

  @override
  String markupSaved(int count) {
    return 'Үстемелер сақталды: $count санат';
  }

  @override
  String genericErrorWith(String detail) {
    return 'Қате: $detail';
  }

  @override
  String get serviceAttachPhoto => 'Фото';

  @override
  String get serviceAttachVideo => 'Бейне';

  @override
  String get shiftCorrectionReceipt => 'Түзету чегі';

  @override
  String get supplierChoose => 'Жеткізушіні таңдаңыз';

  @override
  String get supplierProduct => 'Тауар';

  @override
  String get supplierStock => 'Қалдық';

  @override
  String get supplierOrderQty => 'Тапсырыс';

  @override
  String get supplierCreateRequest => 'Өтінім жасау';

  @override
  String get supplierNeedQuantity => 'Кем дегенде бір тауарға саны керек';

  @override
  String unitMonthsShort(int count) {
    return '$count ай';
  }

  @override
  String unitDaysShort(int count) {
    return '$count күн';
  }

  @override
  String get displayWelcome => 'Қош келдіңіз!';

  @override
  String get displayWelcomeSubtitle => 'Сізді көргенімізге қуаныштымыз';

  @override
  String get displayPromoFree => 'Акция · тегін';

  @override
  String displayDiscountAmount(String amount) {
    return 'Жеңілдік −$amount';
  }

  @override
  String get displayWindowTitle => 'Сатып алушы экраны';

  @override
  String get shiftXReportPrinted => 'X-есеп басып шығарылды';

  @override
  String get shiftXReportPrintedOffline =>
      'X-есеп басылды (фискалдық X кезекте, байланыс жоқ)';

  @override
  String get shiftXReportFailed => 'X-есепті басып шығару мүмкін болмады';

  @override
  String creditContractNotFound(String number) {
    return '$number шарты кассада жоқ';
  }

  @override
  String creditOverdue(String amount, int count) {
    return 'МЕРЗІМІ ӨТКЕН: $amount ($count төлем)';
  }

  @override
  String creditNextPayment(String date, String amount) {
    return 'Келесі төлем $date: $amount';
  }

  @override
  String get creditNoTillAccount =>
      'Кассаның шоты жоқ — ақшаны қабылдайтын жер жоқ';

  @override
  String creditContractClosed(String number) {
    return '$number шарты жабылды';
  }

  @override
  String creditPartiallyPaid(String paid, String left) {
    return '$paid қабылданды, $left қалды';
  }

  @override
  String get creditPaymentAmount => 'Төлем сомасы';

  @override
  String get serviceWarrantyAndQuality => 'Кепілдік және сапа';

  @override
  String serviceWarrantyDays(int days) {
    return 'Кепілдік: $days күн';
  }

  @override
  String get serviceWarrantyNotSet => 'Кепілдік белгіленбеген';

  @override
  String get serviceQualityRatingTitle => 'Сапа бағасы';

  @override
  String serviceQualityRatingValue(int rating) {
    return 'Бағасы: $rating/5';
  }

  @override
  String get serviceRepairMedia => 'Жөндеу фото/бейнесі';

  @override
  String get serviceNoRepairMedia => 'Жөндеу медиасы жоқ';

  @override
  String get supplierLabel => 'Жеткізуші:';

  @override
  String supplierLinesToOrder(int count) {
    return 'Тапсырысқа позиция: $count';
  }

  @override
  String supplierRequestCreated(int count) {
    return 'Өтінім жасалды: $count поз.';
  }

  @override
  String get modifierRequired => 'Міндетті';

  @override
  String modifierMax(int count) {
    return 'макс. $count';
  }

  @override
  String get writeoffReasonUnspecified => 'Көрсетілмеген';

  @override
  String get labelSampleProduct => 'Тауар үлгісі';

  @override
  String markupCategoryNumbered(int id) {
    return 'Санат #$id';
  }

  @override
  String get salePolicyForbids =>
      'Әрекетке касса баптауы рұқсат бермейді (Баптаулар → Сату саясаты)';

  @override
  String get labelPrintFailed => 'Заттаңбаны басып шығару қатесі';

  @override
  String get labelPrintFromTillOnly =>
      'Заттаңба кассадан басылады, терминалдан емес';

  @override
  String get stockLowStockReorder => 'Қалдығы аз тауарларға қосымша тапсырыс';

  @override
  String get serviceNoteNeedsApproval => 'Клиенттің келісімі қажет';

  @override
  String deferredFromTill(String id) {
    return 'касса $id';
  }

  @override
  String prepaymentIssueTo(String name) {
    return 'Сатып алушыға аванс беру ($name)';
  }

  @override
  String prepaymentFrom(String name) {
    return 'Сатып алушының авансы ($name)';
  }

  @override
  String prepaymentRefundTo(String name) {
    return 'Сатып алушыға авансты қайтару ($name)';
  }

  @override
  String get setupPartOrganization => 'ұйым';

  @override
  String get setupPartTill => 'касса';

  @override
  String get setupPartFiscal => 'фискализация';

  @override
  String get setupPartEquipment => 'жабдық';

  @override
  String get setupPartTerminals => 'төлем терминалдары';

  @override
  String get setupPartRules => 'ережелер';

  @override
  String get setupPartUser => 'пайдаланушы';

  @override
  String customerPaymentNote(String name) {
    return 'Қарызды өтеу / төлем ($name)';
  }

  @override
  String get chatMembersUnavailable => 'Қатысушылар тізімі жүктелмеді';

  @override
  String get chatMe => 'Мен';

  @override
  String get setPolicyBigAmountLimit => 'Чек сомасының шегі';

  @override
  String setPolicyBigAmountLimitDesc(String fallback) {
    return 'Осы сомадан жоғары касса рұқсат сұрайды. Бос — $fallback.';
  }

  @override
  String get cashRefusedNotPositive => 'Сома нөлден үлкен болуы керек';

  @override
  String cashRefusedAboveCeiling(String limit) {
    return 'Сома касса шегінен жоғары ($limit). Баптауларда шекті көтеріңіз немесе ірі сомаларға рұқсатты қосыңыз.';
  }

  @override
  String errorProductHasNoPrice(String name) {
    return '«$name» тауарының бағасы жоқ — сату мүмкін емес. Каталогта баға қойыңыз.';
  }

  @override
  String get sellingHoursTitle => 'Сатуға тыйым сағаттары';

  @override
  String get sellingHoursAdd => 'Терезе қосу';

  @override
  String get sellingHoursCategory => 'Санат';

  @override
  String get sellingHoursFrom => 'Басы (СС:ММ)';

  @override
  String get sellingHoursTo => 'Аяғы (СС:ММ)';

  @override
  String get sellingHoursActive => 'Тыйым күшінде';

  @override
  String sellingHoursBanned(String window) {
    return 'Сату тыйым салынған $window';
  }

  @override
  String sellingHoursOff(String window) {
    return '$window терезесі өшірілген';
  }

  @override
  String sellingHoursBroken(String window) {
    return '«$window» сағаттары оқылмады — тыйым жұмыс істемейді';
  }

  @override
  String get sellingHoursBadTime => 'Уақыт СС:ММ түрінде, мысалы 23:00';

  @override
  String sellingHoursPreviewDay(String window) {
    return 'Тәулік ішінде: $window';
  }

  @override
  String sellingHoursPreviewNight(String window) {
    return 'Түнгі тыйым, түн ортасы арқылы: $window';
  }

  @override
  String get sellingHoursExplainer =>
      'Сағаттарды өзіңіз қоясыз: заң әр елде басқа. Санатқа тыйым оның ішіндегілерге де әсер етеді.';

  @override
  String get sellingHoursNoCategories =>
      'Алдымен каталогта санат жасаңыз — тыйым санатқа қойылады.';

  @override
  String sellingHoursCategoryGone(int id) {
    return '#$id санаты жойылған';
  }

  @override
  String errorSellingHoursBanned(String category, String window) {
    return '«$category» қазір сатуға болмайды: тыйым $window.';
  }

  @override
  String errorSellingHoursBannedNoWindow(String category) {
    return '«$category» қазір сатуға болмайды.';
  }

  @override
  String get generalSettingsStoreAddress => 'Сауда нүктесінің мекенжайы';

  @override
  String get generalSettingsStoreAddressHint =>
      'Чекте басылады. Дүкен көшсе, өзгертіңіз.';
}
