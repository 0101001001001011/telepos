// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Uzbek (`uz`).
class AppLocalizationsUz extends AppLocalizations {
  AppLocalizationsUz([String locale = 'uz']) : super(locale);

  @override
  String get navReports => 'Hisobotlar';

  @override
  String get navStock => 'Ombor';

  @override
  String get appName => 'TelePOS';

  @override
  String get globalOk => 'OK';

  @override
  String get globalCancel => 'Bekor qilish';

  @override
  String get globalYes => 'Ha';

  @override
  String get globalNo => 'Yo\'q';

  @override
  String get globalSave => 'Saqlash';

  @override
  String get globalNew => 'Yangi';

  @override
  String get globalDelete => 'O\'chirish';

  @override
  String get globalEdit => 'Tahrirlash';

  @override
  String get globalAdd => 'Qo\'shish';

  @override
  String get globalSearch => 'Qidirish';

  @override
  String get globalClose => 'Yopish';

  @override
  String get globalBack => 'Orqaga';

  @override
  String get globalNext => 'Keyingi';

  @override
  String get globalDone => 'Tayyor';

  @override
  String get globalLoading => 'Yuklanmoqda...';

  @override
  String get globalError => 'Xato';

  @override
  String get globalSuccess => 'Muvaffaqiyatli';

  @override
  String get globalWarning => 'Ogohlantirish';

  @override
  String get globalInfo => 'Ma\'lumot';

  @override
  String get globalConfirm => 'Tasdiqlash';

  @override
  String get globalClear => 'Tozalash';

  @override
  String get globalSelect => 'Tanlash';

  @override
  String get globalAll => 'Hammasi';

  @override
  String get globalNone => 'Yo\'q';

  @override
  String get globalTotal => 'Jami';

  @override
  String get globalAmount => 'Summa';

  @override
  String get globalQuantity => 'Miqdori';

  @override
  String get globalPrice => 'Narx';

  @override
  String get globalDiscount => 'Chegirma';

  @override
  String get globalDate => 'Sana';

  @override
  String get globalTime => 'Vaqt';

  @override
  String get loginTitle => 'Tizimga kirish';

  @override
  String get loginPin => 'PIN kiriting';

  @override
  String get loginPinHint => '4 raqam';

  @override
  String get loginEnter => 'Kirish';

  @override
  String get loginSelectUser => 'Foydalanuvchini tanlang';

  @override
  String get loginNoUsers => 'Foydalanuvchilar yo\'q';

  @override
  String get loginWrongPin => 'Noto\'g\'ri PIN';

  @override
  String get loginBlocked => 'Foydalanuvchi bloklangan';

  @override
  String get loginSessionExpired => 'Sessiya muddati tugadi';

  @override
  String get loginShiftRequired => 'Kirish uchun smenani oching';

  @override
  String get loginCashier => 'Kassir';

  @override
  String get loginAdmin => 'Administrator';

  @override
  String get loginManager => 'Menejer';

  @override
  String get loginLogout => 'Chiqish';

  @override
  String get loginSwitchUser => 'Foydalanuvchini almashtirish';

  @override
  String get saleTitle => 'Sotuv';

  @override
  String get saleNewSale => 'Yangi sotuv';

  @override
  String get saleAddProduct => 'Tovar qo\'shish';

  @override
  String get saleScanBarcode => 'Shtrix-kodni skanerlash';

  @override
  String get saleEnterBarcode => 'Shtrix-kodni kiriting';

  @override
  String get saleProductNotFound => 'Tovar topilmadi';

  @override
  String get saleEmptyCart => 'Savat bo\'sh';

  @override
  String get saleSubtotal => 'Oraliq summa';

  @override
  String get saleTax => 'QQS';

  @override
  String get saleTotalDiscount => 'Chegirma';

  @override
  String get saleToPay => 'To\'lashga';

  @override
  String saleItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ta tovar',
      one: '$count ta tovar',
    );
    return '$_temp0';
  }

  @override
  String paymentCardChargeUnsettled(String amount) {
    return 'Karta allaqachon $amount miqdorida oʻtkazilgan va bu summa chekka tushmaydi. Toʻlov terminalida operatsiyani bekor qiling.';
  }

  @override
  String get saleRemoveItem => 'Tovarni o\'chirish';

  @override
  String get saleClearCart => 'Savatni tozalash';

  @override
  String get saleConfirmClear => 'Savatni tozalash kerakmi?';

  @override
  String get saleProceedPayment => 'To\'lovga o\'tish';

  @override
  String get saleHold => 'Keyinga qoldirish';

  @override
  String get saleRecall => 'Qaytarish';

  @override
  String get saleHeldSales => 'Keyinga qoldirilgan sotuvlar';

  @override
  String get saleNoHeldSales => 'Keyinga qoldirilgan sotuvlar yo\'q';

  @override
  String get saleProductSearch => 'Tovarlarni qidirish';

  @override
  String get saleByCategory => 'Kategoriyalar bo\'yicha';

  @override
  String get saleByName => 'Nomi bo\'yicha';

  @override
  String get saleByBarcode => 'Shtrix-kod bo\'yicha';

  @override
  String get saleWeight => 'Og\'irligi';

  @override
  String saleWeightKg(String weight) {
    return 'Ogʻirligi: $weight kg';
  }

  @override
  String get saleEnterWeight => 'Og\'irlikni kiriting';

  @override
  String get saleEnterQuantity => 'Miqdorini kiriting';

  @override
  String get saleEnterPrice => 'Narxni kiriting';

  @override
  String get saleFreePrice => 'Erkin narx';

  @override
  String saleMaxDiscount(String percent) {
    return 'Maks. chegirma: $percent%';
  }

  @override
  String get refundTitle => 'Qaytarish';

  @override
  String get refundNewRefund => 'Yangi qaytarish';

  @override
  String get refundByReceipt => 'Chek bo\'yicha';

  @override
  String get refundWithoutReceipt => 'Cheksiz';

  @override
  String get refundEnterReceipt => 'Chek raqamini kiriting';

  @override
  String get refundReceiptNotFound => 'Chek topilmadi';

  @override
  String get refundSelectItems => 'Qaytarish uchun tovarlarni tanlang';

  @override
  String get refundReason => 'Qaytarish sababi';

  @override
  String get refundConfirm => 'Qaytarishni tasdiqlash';

  @override
  String get refundAmount => 'Qaytarish summasi';

  @override
  String get refundComplete => 'Qaytarish bajarildi';

  @override
  String get refundCash => 'Naqd qaytarish';

  @override
  String get refundCard => 'Kartaga qaytarish';

  @override
  String get refundConnectionLostHint =>
      'Terminal kassaga oʻzi qaytadi — ish oʻsha joydan davom etadi';

  @override
  String get refundConnectionLost => 'Kassa bilan aloqa uzildi';

  @override
  String get refundNoItems => 'Qaytarish uchun tovarlar yo\'q';

  @override
  String get refundAlreadyRefunded => 'Tovar qaytarilgan';

  @override
  String get refundPartial => 'Qisman qaytarish';

  @override
  String get shiftTitle => 'Smena';

  @override
  String get shiftOpen => 'Smenani ochish';

  @override
  String get shiftClose => 'Smenani yopish';

  @override
  String get shiftCurrent => 'Joriy smena';

  @override
  String shiftNumber(int number) {
    return 'Smena №: $number';
  }

  @override
  String shiftOpenedAt(String time) {
    return 'Ochildi: $time';
  }

  @override
  String shiftCashier(String name) {
    return 'Kassir: $name';
  }

  @override
  String shiftSalesCount(int count) {
    return 'Sotuvlar: $count';
  }

  @override
  String shiftRefundsCount(int count) {
    return 'Qaytarishlar: $count';
  }

  @override
  String get shiftTotalSales => 'Sotuvlar summasi';

  @override
  String get shiftTotalRefunds => 'Qaytarishlar summasi';

  @override
  String get shiftCashInDrawer => 'Kassada';

  @override
  String get shiftExpected => 'Kutilgan';

  @override
  String get shiftActual => 'Haqiqiy';

  @override
  String get shiftDifference => 'Farq';

  @override
  String get shiftXReport => 'X-hisobot';

  @override
  String get shiftZReport => 'Z-hisobot';

  @override
  String get shiftConfirmClose => 'Smenani yopish kerakmi?';

  @override
  String get shiftAlreadyOpen => 'Smena ochiq';

  @override
  String get shiftNotOpen => 'Smena ochilmagan';

  @override
  String get shiftOpenFirst => 'Avval smenani oching';

  @override
  String get paymentTitle => 'To\'lov';

  @override
  String get paymentCash => 'Naqd';

  @override
  String get paymentCard => 'Karta';

  @override
  String get paymentKaspi => 'Kaspi QR';

  @override
  String get paymentBonus => 'Bonuslar';

  @override
  String get paymentDebt => 'Qarzga';

  @override
  String get paymentInstallment => 'Bo\'lib to\'lash';

  @override
  String get paymentMixed => 'Aralash';

  @override
  String get paymentEnterAmount => 'Summani kiriting';

  @override
  String paymentRemaining(String amount) {
    return 'Qoldi: $amount';
  }

  @override
  String paymentChange(String amount) {
    return 'Qaytim: $amount';
  }

  @override
  String get paymentComplete => 'To\'lov yakunlandi';

  @override
  String get paymentFailed => 'To\'lov xatosi';

  @override
  String get paymentWaitingCard => 'Kartani kutish...';

  @override
  String get paymentWaitingQr => 'QR kutish...';

  @override
  String get paymentInsertCard => 'Kartani joylashtiring';

  @override
  String get paymentScanQr => 'QR skanerlang';

  @override
  String get paymentApproved => 'Tasdiqlandi';

  @override
  String get paymentDeclined => 'Rad etildi';

  @override
  String get paymentReceipt => 'Chek chop etish';

  @override
  String get paymentNoReceipt => 'Cheksiz';

  @override
  String get paymentEmail => 'Email-ga yuborish';

  @override
  String get paymentSms => 'SMS yuborish';

  @override
  String get historyTitle => 'Tarix';

  @override
  String get historyToday => 'Bugun';

  @override
  String get historyYesterday => 'Kecha';

  @override
  String get historyThisWeek => 'Bu hafta';

  @override
  String get historyThisMonth => 'Bu oy';

  @override
  String get historyDateRange => 'Davrni tanlash';

  @override
  String get historyNoSales => 'Davrda sotuvlar yo\'q';

  @override
  String historyReceipt(String number) {
    return 'Chek №$number';
  }

  @override
  String get historyReprint => 'Qayta chop etish';

  @override
  String certificateSlipPrintFailed(String number, String reason) {
    return '$number sertifikat slipi chop etilmadi: $reason';
  }

  @override
  String get historyDetails => 'Batafsil';

  @override
  String get historySale => 'Sotuv';

  @override
  String get historyRefund => 'Qaytarish';

  @override
  String get historyFilter => 'Filtr';

  @override
  String get agentTitle => 'Kontragentlar';

  @override
  String get agentClients => 'Mijozlar';

  @override
  String get agentSuppliers => 'Yetkazib beruvchilar';

  @override
  String get agentSearch => 'Kontragentni qidirish';

  @override
  String get agentAdd => 'Kontragent qo\'shish';

  @override
  String get agentEdit => 'Tahrirlash';

  @override
  String get agentName => 'Nomi/F.I.O.';

  @override
  String get agentPhone => 'Telefon';

  @override
  String get agentEmail => 'Email';

  @override
  String get agentIin => 'STIR';

  @override
  String get agentAddress => 'Manzil';

  @override
  String get agentBalance => 'Balans';

  @override
  String get agentBonusBalance => 'Bonus balansi';

  @override
  String get agentDebt => 'Qarz';

  @override
  String get agentNoAgents => 'Kontragentlar yo\'q';

  @override
  String get agentSaveSuccess => 'Kontragent saqlandi';

  @override
  String get agentDeleteConfirm => 'Kontragentni o\'chirish kerakmi?';

  @override
  String get cashTitle => 'Kassa';

  @override
  String get cashInvestment => 'Kirim';

  @override
  String get cashExpense => 'Chiqim';

  @override
  String get cashBalance => 'Kassa balansi';

  @override
  String get cashEnterAmount => 'Summani kiriting';

  @override
  String get cashReason => 'Asos';

  @override
  String get cashReasonPlaceholder => 'Sababni ko\'rsating';

  @override
  String get cashSuccess => 'Operatsiya bajarildi';

  @override
  String get cashExpenseTypes => 'Chiqim turi';

  @override
  String get cashSalary => 'Ish haqi';

  @override
  String get cashRent => 'Ijara';

  @override
  String get cashUtilities => 'Kommunal';

  @override
  String get cashSupplies => 'Xaridlar';

  @override
  String get cashOther => 'Boshqa';

  @override
  String get discountTitle => 'Chegirma';

  @override
  String get discountPercent => 'Foiz';

  @override
  String get discountFixed => 'Belgilangan';

  @override
  String get discountEnterValue => 'Qiymatni kiriting';

  @override
  String get discountApply => 'Qo\'llash';

  @override
  String get discountRemove => 'Chegirmani olib tashlash';

  @override
  String get discountOnItem => 'Tovarga chegirma';

  @override
  String get discountOnTotal => 'Chekka chegirma';

  @override
  String get discountMaxExceeded => 'Maksimal chegirma oshib ketdi';

  @override
  String get quickProductTitle => 'Tez tovarlar';

  @override
  String get quickProductAdd => 'Tovar qo\'shish';

  @override
  String get quickProductName => 'Nomi';

  @override
  String get quickProductPrice => 'Narxi';

  @override
  String get quickProductCategory => 'Kategoriyasi';

  @override
  String get quickProductSave => 'Saqlash';

  @override
  String get quickProductDelete => 'O\'chirish';

  @override
  String get syncTitle => 'Sinxronizatsiya';

  @override
  String get syncStatus => 'Sinxronizatsiya holati';

  @override
  String syncLastSync(String time) {
    return 'Oxirgi sinxronizatsiya: $time';
  }

  @override
  String get syncNow => 'Sinxronizatsiya qilish';

  @override
  String get syncInProgress => 'Sinxronizatsiya qilinmoqda...';

  @override
  String get syncSuccess => 'Sinxronizatsiya yakunlandi';

  @override
  String get syncFailed => 'Sinxronizatsiya xatosi';

  @override
  String get syncProducts => 'Tovarlar';

  @override
  String get syncPrices => 'Narxlar';

  @override
  String get syncAgents => 'Kontragentlar';

  @override
  String get syncSales => 'Sotuvlar';

  @override
  String syncPending(int count) {
    return 'Yuborishni kutmoqda: $count';
  }

  @override
  String get syncOffline => 'Aloqa yo\'q';

  @override
  String get syncOnline => 'Ulangan';

  @override
  String get printerTitle => 'Printer';

  @override
  String get printerStatus => 'Printer holati';

  @override
  String get printerConnected => 'Ulangan';

  @override
  String get printerDisconnected => 'Uzilgan';

  @override
  String get printerError => 'Printer xatosi';

  @override
  String get printerPaperOut => 'Qog\'oz yo\'q';

  @override
  String get printerConnect => 'Ulash';

  @override
  String get printerDisconnect => 'Uzish';

  @override
  String get printerTest => 'Test chop etish';

  @override
  String get printerSettings => 'Printer sozlamalari';

  @override
  String get printerWidth => 'Chek kengligi';

  @override
  String get additionalTitle => 'Qo\'shimcha';

  @override
  String get additionalSettings => 'Sozlamalar';

  @override
  String get additionalReports => 'Hisobotlar';

  @override
  String get additionalInventory => 'Inventarizatsiya';

  @override
  String get additionalSupply => 'Tovar qabul qilish';

  @override
  String get additionalPriceChange => 'Narxlarni o\'zgartirish';

  @override
  String get additionalBackup => 'Zahira nusxa';

  @override
  String get additionalRestore => 'Tiklash';

  @override
  String get additionalUpdate => 'Yangilash';

  @override
  String get additionalAbout => 'Dastur haqida';

  @override
  String get additionalLicense => 'Litsenziya';

  @override
  String get additionalSupport => 'Qo\'llab-quvvatlash';

  @override
  String get receiptTitle => 'Chek';

  @override
  String get receiptNumber => 'Chek №';

  @override
  String get receiptDate => 'Sana';

  @override
  String get receiptCashier => 'Kassir';

  @override
  String get receiptItems => 'Tovarlar';

  @override
  String get receiptSubtotal => 'Oraliq summa';

  @override
  String get receiptDiscount => 'Chegirma';

  @override
  String get receiptTax => 'QQS';

  @override
  String get receiptTotal => 'JAMI';

  @override
  String get receiptCash => 'Naqd';

  @override
  String get receiptCard => 'Karta';

  @override
  String get receiptChange => 'Qaytim';

  @override
  String get receiptThankYou => 'Xaridingiz uchun rahmat!';

  @override
  String get receiptFiscalNumber => 'Fiskal raqam';

  @override
  String get receiptQrCode => 'Tekshirish uchun QR';

  @override
  String get receiptCopy => 'Chek nusxasi';

  @override
  String get errorUnknown => 'Noma\'lum xato';

  @override
  String get errorNetwork => 'Tarmoq xatosi';

  @override
  String get errorServer => 'Server xatosi';

  @override
  String get errorTimeout => 'Kutish vaqti tugadi';

  @override
  String get errorNotFound => 'Topilmadi';

  @override
  String get errorPermission => 'Ruxsat yo\'q';

  @override
  String get errorDatabase => 'Ma\'lumotlar bazasi xatosi';

  @override
  String get errorValidation => 'Validatsiya xatosi';

  @override
  String get errorRequired => 'Majburiy maydon';

  @override
  String get errorInvalidFormat => 'Noto\'g\'ri format';

  @override
  String errorMinLength(int min) {
    return 'Kamida $min belgi';
  }

  @override
  String errorMaxLength(int max) {
    return 'Ko\'pi bilan $max belgi';
  }

  @override
  String errorMinValue(String min) {
    return 'Kamida $min';
  }

  @override
  String errorMaxValue(String max) {
    return 'Ko\'pi bilan $max';
  }

  @override
  String get errorPrinter => 'Printer xatosi';

  @override
  String get errorFiscal => 'Fiskalizatsiya xatosi';

  @override
  String get errorPayment => 'To\'lov xatosi';

  @override
  String get errorSync => 'Sinxronizatsiya xatosi';

  @override
  String get errorNoInternet => 'Internet aloqasi yo\'q';

  @override
  String get errorTryAgain => 'Qayta urinib ko\'ring';

  @override
  String get helpTitle => 'Yordam';

  @override
  String get helpTips => 'Maslahatlar';

  @override
  String get helpShortcuts => 'Tezkor tugmalar';

  @override
  String get helpRelatedScreens => 'Bog\'liq bo\'limlar';

  @override
  String get helpKey => 'Tugma';

  @override
  String get helpAction => 'Harakat';

  @override
  String get navSale => 'Sotuv';

  @override
  String get navRefund => 'Qaytarish';

  @override
  String get navShift => 'Smena';

  @override
  String get navHistory => 'Tarix';

  @override
  String get navTables => 'Stollar';

  @override
  String get navOrders => 'Buyurtmalar';

  @override
  String get navQueue => 'Navbat';

  @override
  String get navIntake => 'Qabul';

  @override
  String get navAgents => 'Kontragentlar';

  @override
  String get navSupply => 'Qabul qilish';

  @override
  String get navCash => 'Kassa';

  @override
  String get navSettings => 'Sozlamalar';

  @override
  String get navSync => 'Sinxronlash';

  @override
  String get navMore => 'Yana';

  @override
  String get navAdditional => 'Qo\'shimcha';

  @override
  String get navLockScreen => 'Qulflash';

  @override
  String get navMain => 'Asosiy';

  @override
  String get loginEnterSystem => 'Tizimga kirish';

  @override
  String get loginWithoutPin => 'PIN-siz kirish';

  @override
  String get loginShiftOpen => 'Smena ochiq';

  @override
  String get loginShiftClosed => 'Smena yopiq';

  @override
  String get loginShiftUnknown => 'Smena: noma\'lum';

  @override
  String get saleQuickProducts => 'Tez mahsulotlar';

  @override
  String get saleIncrease => 'Oshirish';

  @override
  String get saleDecrease => 'Kamaytirish';

  @override
  String get saleMark => 'Markirovka';

  @override
  String get saleDataMatrix => 'Markirovka (DataMatrix)';

  @override
  String get saleHeld => 'Chek kechiktirildi';

  @override
  String get saleNoDeferredSales => 'Kechiktirilgan cheklar yo\'q';

  @override
  String get saleDeferredListNotPermitted =>
      'Kechiktirilgan cheklar sizga ochiq emas: «chekni kechiktirish» huquqi kerak. Uni administrator huquqlar sozlamalarida beradi; huquqi yoʻq har kimga kassa rad javob beradi.';

  @override
  String get saleDeferNotPermitted =>
      'Chekni kechiktira olmaysiz: «chekni kechiktirish» huquqi kerak. Uni administrator huquqlar sozlamalarida beradi; huquqi yoʻq har kimga kassa rad javob beradi.';

  @override
  String get saleReceiptNo => 'Chek №';

  @override
  String get salePositions => 'Mahsulotlar';

  @override
  String get saleSearchHint => 'Mahsulot qidirish (nomi yoki shtrix-kod)';

  @override
  String get refundWithReceipt => 'CHEK BILAN';

  @override
  String get refundWithoutReceiptUpper => 'CHEKSIZ';

  @override
  String get refundLoadReceipt => 'Chekni yuklash';

  @override
  String get refundSearchProducts => 'Mahsulotlarni qidirish';

  @override
  String get refundSelectAll => 'Hammasini tanlash';

  @override
  String get refundDeselectAll => 'Hammasini olib tashlash';

  @override
  String refundMaxQuantity(String max) {
    return 'Maksimum: $max';
  }

  @override
  String get refundConfirmTitle => 'Qaytarishni tasdiqlang';

  @override
  String refundSelectedItems(int count) {
    return 'Tanlangan mahsulotlar: $count';
  }

  @override
  String get refundSuccessMsg => 'Qaytarish muvaffaqiyatli amalga oshirildi';

  @override
  String get refundSearchHint => 'Qaytarish uchun mahsulot qidirish';

  @override
  String get paymentRefundTitle => 'Qaytarish';

  @override
  String get paymentPayTitle => 'To\'lov';

  @override
  String get paymentRefundBtn => 'QAYTARISH';

  @override
  String get paymentPayBtn => 'TO\'LASH';

  @override
  String get paymentChangeLabel => 'Qaytim:';

  @override
  String get paymentSuccessRefund => 'Qaytarish amalga oshirildi';

  @override
  String get paymentSuccessPay => 'To\'lov muvaffaqiyatli';

  @override
  String get paymentCardType => 'Naqdsiz';

  @override
  String get paymentToPay => 'To\'lashga';

  @override
  String get paymentBonusLabel => 'Bonuslar';

  @override
  String get paymentTotalToPay => 'Jami to\'lash';

  @override
  String get paymentByCard => 'Karta bilan';

  @override
  String get paymentRemainLabel => 'Qoldi';

  @override
  String get shiftBills => 'Kupyuralar';

  @override
  String get shiftTotalAmount => 'Umumiy summa';

  @override
  String get shiftOperations => 'Operatsiyalar';

  @override
  String get shiftOpened => 'Smena ochildi';

  @override
  String get shiftClosed => 'Smena yopildi';

  @override
  String get shiftOverAgeTitle => 'Smena 24 soatdan ortiq ochiq';

  @override
  String get shiftOverAgeMessage =>
      'Sotuv bloklandi. Ishni davom ettirish uchun joriy smenani yopib, yangisini oching.';

  @override
  String get shiftOverAgeCloseAtTill =>
      'Sotuv bloklandi. Ishni davom ettirish uchun smenani kassada yopib, yangisini oching.';

  @override
  String shiftSince(String time) {
    return '$time dan beri';
  }

  @override
  String get shiftSystem => 'Tizim';

  @override
  String get shiftEntered => 'Kiritildi';

  @override
  String get shiftRecounting => 'Kupyuralar bo\'yicha qayta hisoblash';

  @override
  String get shiftManualEntry => 'Qo\'lda summa kiritish';

  @override
  String get shiftCashOps => 'Kassa operatsiyalari';

  @override
  String get shiftOpenAction => 'Smenani ochish';

  @override
  String get shiftCloseAction => 'Smenani yopish';

  @override
  String get historyOperations => 'Operatsiyalar tarixi';

  @override
  String get historyResetFilters => 'Filtrlarni tozalash';

  @override
  String get historyRefresh => 'Yangilash';

  @override
  String get historyNoRecords => 'Yozuvlar yo\'q';

  @override
  String get historyChangeFilters => 'Filtrlarni o\'zgartirib ko\'ring';

  @override
  String get historyEmpty => 'Operatsiyalar tarixi bo\'sh';

  @override
  String get historyFilterTitle => 'Filtrlar';

  @override
  String get historyPeriod => 'Davr';

  @override
  String get historyOpType => 'Operatsiya turi';

  @override
  String get historySearchHint => 'Chek raqami, summa...';

  @override
  String historyType(String type) {
    return 'Turi:';
  }

  @override
  String get historyPrint => 'Chekni chop etish';

  @override
  String agentFound(int count) {
    return 'Topildi: $count';
  }

  @override
  String get agentWithDebt => 'Faqat qarzli';

  @override
  String get agentSearchHint => 'Ism yoki telefon bo\'yicha qidirish...';

  @override
  String get agentNewClient => 'Yangi mijoz';

  @override
  String get agentNameRequired => 'Ism *';

  @override
  String get agentEnterName => 'Mijoz ismini kiriting';

  @override
  String get agentPhoneLabel => 'Telefon';

  @override
  String get agentIinLabel => 'STIR/JSHSHIR';

  @override
  String get agentIinHint => '12 raqam';

  @override
  String get agentDeleteQuestion => 'Mijozni o\'chirish?';

  @override
  String agentDeleteConfirmMsg(String name) {
    return '$name ni o\'chirmoqchimisiz?';
  }

  @override
  String get agentDeleted => 'Mijoz o\'chirildi';

  @override
  String get agentFoundExisting => 'Mijoz topildi';

  @override
  String get supplyTitle => 'Tovar qabul qilish';

  @override
  String get supplySaved => 'Qabul saqlandi';

  @override
  String get supplySaveError => 'Saqlash xatosi';

  @override
  String get supplyCancelQuestion => 'Qabul qilishni bekor qilish?';

  @override
  String get supplyDataLost => 'Barcha kiritilgan ma\'lumotlar yo\'qoladi.';

  @override
  String supplyProducts(int count) {
    return 'Mahsulotlar: $count';
  }

  @override
  String get supplyBarcodeHint => 'Shtrix-kod yoki artikul';

  @override
  String get supplyComment => 'Izoh';

  @override
  String get supplyCommentHint => 'Izoh kiriting...';

  @override
  String get supplyNotFound => 'Mahsulot topilmadi';

  @override
  String get supplySelectSupplier => 'Yetkazuvchini tanlang';

  @override
  String get supplySelectAccount => 'Hisobni tanlang';

  @override
  String supplyBalance(String amount) {
    return 'Balans: $amount';
  }

  @override
  String get supplyPurchasePrice => 'Kirim narxi';

  @override
  String get supplySerialNumbers => 'Seriya raqamlari';

  @override
  String get supplySerialHint => 'S/N kiriting yoki skanerlang';

  @override
  String supplySerialCount(int count, int expected) {
    return '$expected dan $count';
  }

  @override
  String get supplySerialMismatch =>
      'Seriya raqamlari soni miqdorga mos kelmaydi';

  @override
  String get supplyInvalidQty => 'To\'g\'ri miqdorni kiriting';

  @override
  String get supplyInvalidPrice => 'To\'g\'ri narxni kiriting';

  @override
  String get inventoryTitle => 'Inventarizatsiya';

  @override
  String get inventoryFullCount => 'To\'liq inventarizatsiya';

  @override
  String get inventoryFullCountSubtitle =>
      'Skanerlanmagan tovarlar qoldig\'ini nolga tushirish';

  @override
  String get inventoryStart => 'Boshlash';

  @override
  String get inventoryFinish => 'Tugatish';

  @override
  String get inventoryScanHint => 'Shtrix-kodni skanerlang';

  @override
  String get inventoryScanProducts =>
      'Hisoblash uchun mahsulotlarni skanerlang';

  @override
  String get inventoryPressStart =>
      'Inventarizatsiya uchun \"Boshlash\" bosing';

  @override
  String inventoryProductCount(int count) {
    return 'Mahsulotlar: $count';
  }

  @override
  String inventoryDiscrepancies(int count) {
    return 'Nomuvofiqliklar: $count';
  }

  @override
  String get inventoryExpected => 'Kutilgan:';

  @override
  String get inventoryActual => 'Haqiqiy:';

  @override
  String get inventoryProduct => 'Mahsulot';

  @override
  String get inventoryExpectedQty => 'Kutilgan';

  @override
  String get inventoryActualQty => 'Haqiqiy';

  @override
  String get inventoryDiscrepancy => 'Nomuvofiqlik';

  @override
  String get inventoryActualLabel => 'Haqiqiy miqdori';

  @override
  String get inventoryFinishQuestion => 'Inventarizatsiyani tugatish?';

  @override
  String get inventoryCompleted => 'Inventarizatsiya tugadi';

  @override
  String get writeoffTitle => 'Hisobdan chiqarish';

  @override
  String get writeoffReason => 'Sabab';

  @override
  String get writeoffProduct => 'Mahsulot';

  @override
  String get writeoffScanHint => 'Shtrix-kodni skanerlang';

  @override
  String get writeoffCommentHint => 'Majburiy emas';

  @override
  String get writeoffReasonBreakage => 'Sinish';

  @override
  String get writeoffReasonExpired => 'Muddati o\'tgan';

  @override
  String get writeoffReasonDamage => 'Buzilish';

  @override
  String get writeoffReasonLoss => 'Yo\'qolish';

  @override
  String get writeoffReasonOther => 'Boshqa';

  @override
  String get writeoffCancelQuestion => 'Hisobdan chiqarishni bekor qilish?';

  @override
  String get writeoffSaved => 'Hisobdan chiqarish saqlandi';

  @override
  String get settingsTitle => 'Sozlamalar';

  @override
  String get settingsPosInfo => 'Kassa ma\'lumoti';

  @override
  String get settingsPosName => 'Kassa nomi';

  @override
  String get settingsCompany => 'Kompaniya';

  @override
  String get settingsIin => 'STIR/JSHSHIR';

  @override
  String get settingsPosId => 'POS ID';

  @override
  String get settingsStoreId => 'Do\'kon ID';

  @override
  String get settingsNotSpecified => 'Ko\'rsatilmagan';

  @override
  String get settingsAppVersion => 'Ilova versiyasi';

  @override
  String get settingsVersion => 'Versiya';

  @override
  String get settingsPlatform => 'Platforma';

  @override
  String get settingsLanguage => 'Interfeys tili';

  @override
  String get settingsLanguageChanged => 'Til o\'zgartirildi';

  @override
  String get settingsCurrency => 'Valyuta';

  @override
  String get settingsCurrencySymbol => 'Belgi';

  @override
  String get settingsCurrencyCode => 'Kod';

  @override
  String get settingsCountry => 'Mamlakat';

  @override
  String get settingsAdditional => 'Qo\'shimcha sozlamalar';

  @override
  String get settingsTransport => 'Transport';

  @override
  String get settingsTransportDesc => 'Ma\'lumotlarni sinxronlash sozlamalari';

  @override
  String get settingsPrinter => 'Printer';

  @override
  String get settingsPrinterDesc => 'Chek chop etish sozlamalari';

  @override
  String get settingsFiscal => 'Fiskalizatsiya';

  @override
  String get settingsFiscalDesc => 'WebKassa, OFD, QQS';

  @override
  String get settingsTelegram => 'Telegram';

  @override
  String get settingsTelegramDesc => 'Telegram integratsiyasi va kanallar';

  @override
  String get settingsPermissions => 'Ruxsatlar';

  @override
  String get settingsPermissionsDesc => 'Kassirlar uchun ruxsatlar';

  @override
  String get fiscalTitle => 'Fiskaalizatsiya';

  @override
  String get fiscalOperator => 'Fiskal operator';

  @override
  String get fiscalWebkassa => 'WebKassa sozlamalari';

  @override
  String get fiscalTaxpayer => 'Soliq to\'lovchi ma\'lumotlari';

  @override
  String get fiscalVatSettings => 'QQS sozlamalari';

  @override
  String get fiscalVatPayer => 'QQS to\'lovchi';

  @override
  String get fiscalPrintVat => 'Chekda QQS ni chop etish';

  @override
  String get fiscalSaved => 'Sozlamalar saqlandi';

  @override
  String get fiscalSaveError => 'Saqlash xatosi';

  @override
  String get printerSettingsTitle => 'Printer sozlamalari';

  @override
  String get printerConnectionType => 'Ulanish turi';

  @override
  String get printerAddress => 'Printer manzili';

  @override
  String get printerPaperWidth => 'Qog\'oz kengligi';

  @override
  String get printerTesting => 'Sinash';

  @override
  String get printerReady => 'Tayyor';

  @override
  String get printerNotConnected => 'Ulanmagan';

  @override
  String get printerPaperOut2 => 'Qog\'oz yo\'q';

  @override
  String get printerCoverOpen => 'Qopqog\'i ochiq';

  @override
  String get printerPrinting => 'Chop etilmoqda...';

  @override
  String get printerCheckStatus => 'Tekshirilmoqda...';

  @override
  String get printerPrintSuccess => 'Chop etish muvaffaqiyatli';

  @override
  String get paymentNotFiscalized =>
      'Chek fiskallashtirilmadi — toʻlov qayd etildi';

  @override
  String get paymentFiscalModuleAbsent =>
      'Fiskallashtirish moduli mavjud emas — cheklar fiskallashtirilmaydi';

  @override
  String get cashDrawerOpenError => 'Kassa qutisi ochilmadi';

  @override
  String get printerPrintError => 'Chop etish xatosi';

  @override
  String get printerCheckBtn => 'Tekshirish';

  @override
  String get printerTestReceipt => 'Test chek';

  @override
  String get printerPort => 'Port';

  @override
  String get cashOperationTitle => 'Kassa operatsiyasi';

  @override
  String get cashWithdrawal => 'Olish';

  @override
  String get cashCommentRequired => 'Izoh *';

  @override
  String get cashCommentOptional => 'Izoh';

  @override
  String get cashCommentHint => 'Izoh kiriting...';

  @override
  String get cashEnterAmountMsg => 'Summani kiriting';

  @override
  String get cashPositiveOnly => 'Summa musbat bo\'lishi kerak';

  @override
  String get cashInsufficient => 'Kassada mablag\' yetarli emas';

  @override
  String get cashInvalidAmount => 'To\'g\'ri summani kiriting';

  @override
  String get cashInDrawer => 'Kassada:';

  @override
  String get telegramTitle => 'Telegram sozlamalari';

  @override
  String get telegramAuth => 'Avtorizatsiya';

  @override
  String get telegramSync => 'Sinxronlash';

  @override
  String get telegramNotifications => 'Bildirishnomalarni yoqish';

  @override
  String get telegramAutoSync => 'Avtosinxronlash';

  @override
  String get telegramSyncData => 'Ma\'lumotlarni avtomatik sinxronlash';

  @override
  String get telegramSyncInterval => 'Sinxronlash oralig\'i';

  @override
  String get telegramForceSync => 'Majburiy sinxronlash';

  @override
  String get telegramFullSync => 'To\'liq sinxronlash';

  @override
  String get telegramRecreateChannels => 'Kanallarni qayta yaratish';

  @override
  String get telegramLogout => 'Telegram dan chiqish';

  @override
  String get telegramSyncComplete => 'Sinxronlash tugadi';

  @override
  String get telegramSyncError => 'Sinxronlash xatosi';

  @override
  String get telegramLogoutComplete => 'Chiqish amalga oshirildi';

  @override
  String get chatTitle => 'Xodimlar chati';

  @override
  String chatParticipants(int count) {
    return '$count ishtirokchi';
  }

  @override
  String get chatConnected => 'Ulandi';

  @override
  String get chatDisconnected => 'Aloqa yo\'q';

  @override
  String get chatNoMessages => 'Xabarlar yo\'q';

  @override
  String get chatStartConversation => 'Jamoa bilan suhbatlashing';

  @override
  String get chatMessageHint => 'Xabar...';

  @override
  String get chatSearch => 'Qidirish';

  @override
  String get chatSearchHint => 'Qidiruv matnini kiriting...';

  @override
  String get chatMembers => 'Ishtirokchilar';

  @override
  String get chatLinkTelegram => 'Telegram ni ulash';

  @override
  String get chatCopied => 'Nusxalandi';

  @override
  String get chatReply => 'Javob berish';

  @override
  String get chatCopy => 'Nusxalash';

  @override
  String get chatDeleteMsg => 'Xabarni o\'chirish?';

  @override
  String get chatDeleteConfirm =>
      'Xabar barcha ishtirokchilar uchun o\'chiriladi.';

  @override
  String get chatPhoto => 'Foto';

  @override
  String get chatDocument => 'Hujjat';

  @override
  String get chatLocation => 'Joylashuv';

  @override
  String get chatCamera => 'Kamera';

  @override
  String get chatGallery => 'Galereya';

  @override
  String get chatSelectSource => 'Manbani tanlang';

  @override
  String get updateAvailable => 'Yangilanish mavjud';

  @override
  String get updateInProgress => 'Yangilanmoqda...';

  @override
  String updateAutoIn(int seconds) {
    return 'Avtoyagilanish $seconds soniyada';
  }

  @override
  String get updateNowBtn => 'Hozir yangilash';

  @override
  String get updateLater => 'Keyinroq';

  @override
  String get updateSkip => 'O\'tkazib yuborish';

  @override
  String get updateBtn => 'Yangilash';

  @override
  String get storageWarningTitle => 'Diskda joy kam';

  @override
  String get storageWarningMsg =>
      'Kassa barqaror ishlashi uchun kamida 2 GB bo\'shatish tavsiya etiladi.';

  @override
  String get storageUnderstood => 'Tushunarli';

  @override
  String get errorCritical => 'Jiddiy xato';

  @override
  String get errorAppProblem => 'Ilovada muammo yuz berdi';

  @override
  String get errorDescription => 'Xato tavsifi:';

  @override
  String get errorTechnical => 'Texnik tafsilotlar';

  @override
  String get errorRetry => 'Qayta urinish';

  @override
  String get errorOpenFolder => 'Papkani ochish';

  @override
  String get errorOtherVersion => 'Boshqa versiya';

  @override
  String get errorExit => 'Chiqish';

  @override
  String get switchOn => 'Yoqish';

  @override
  String get switchOff => 'O\'chirish';

  @override
  String get keyboardSpace => 'Bo\'sh joy';

  @override
  String get keyboardHide => 'Klaviaturani yashirish';

  @override
  String get keyboardShow => 'Klaviaturani ko\'rsatish';

  @override
  String get commentReceipt => 'Chekka izoh';

  @override
  String get commentReceiptHint => 'Izoh kiriting...';

  @override
  String get productNameLabel => 'Mahsulot nomi';

  @override
  String get productNameHint => 'Nomini kiriting...';

  @override
  String get nothingFound => 'Hech narsa topilmadi';

  @override
  String get datePlaceholder => 'KK.OO.YYYY';

  @override
  String get timePlaceholder => 'SS:DD';

  @override
  String get dateTimePlaceholder => 'KK.OO.YYYY SS:DD';

  @override
  String get selectPeriod => 'Davrni tanlang';

  @override
  String get bonusProgram => 'Bonus dasturi';

  @override
  String get enterPhone => 'Mijoz telefon raqamini kiriting';

  @override
  String get enterSmsCode => 'SMS dagi kodni kiriting';

  @override
  String resendIn(int seconds) {
    return '$seconds soniyadan keyin qayta yuborish';
  }

  @override
  String get resendCode => 'Kodni qayta yuborish';

  @override
  String get availableBonuses => 'Mavjud bonuslar:';

  @override
  String get useBonuses => 'Bonuslarni ishlatish';

  @override
  String get deferredSales => 'Kechiktirilgan sotuvlar';

  @override
  String get noDeferredSales => 'Kechiktirilgan sotuvlar yo\'q';

  @override
  String get fiscalErrors => 'Fiskaalizatsiya xatolari';

  @override
  String get selectAllErrors => 'Hammasini tanlash';

  @override
  String get retrySelected => 'Qayta urinish';

  @override
  String receiptNo(String number) {
    return 'Chek №$number';
  }

  @override
  String get dontAskAgain => 'Qayta so\'ramang';

  @override
  String get deleteTitle => 'O\'chirish';

  @override
  String deleteItemConfirm(String name) {
    return '\"$name\" ni o\'chirmoqchimisiz?';
  }

  @override
  String get exitTitle => 'Chiqish';

  @override
  String get exitConfirm => 'Chiqmoqchimisiz?';

  @override
  String get exitBtn => 'Chiqish';

  @override
  String get valueCannotBeNegative => 'Qiymat manfiy bo\'lishi mumkin emas';

  @override
  String maxPercent(String percent) {
    return 'Maksimum $percent%';
  }

  @override
  String maxAmount(String amount) {
    return 'Maksimum $amount';
  }

  @override
  String get enterValidNumber => 'To\'g\'ri raqamni kiriting';

  @override
  String get discountAmount => 'Chegirma summasi:';

  @override
  String discountLimitPercent(String percent, String source) {
    return '$percent % gacha ruxsat — $source';
  }

  @override
  String discountLimitAmount(String amount, String source) {
    return '$amount gacha ruxsat — $source';
  }

  @override
  String discountApprovalAbove(String percent) {
    return '$percent % dan yuqori katta xodim tasdiqlashi kerak';
  }

  @override
  String get sumLabel => 'Summa';

  @override
  String get enterAmount => 'Summani kiriting';

  @override
  String get amountMustBePositive => 'Summa musbat bo\'lishi kerak';

  @override
  String get notEnoughCashInDrawer => 'Kassada mablag\' yetarli emas';

  @override
  String get enterValidAmount => 'To\'g\'ri summani kiriting';

  @override
  String get inDrawer => 'Kassada:';

  @override
  String get commentOptional => 'Izoh (majburiy emas)';

  @override
  String get operationReason => 'Operatsiya sababi...';

  @override
  String get positions => 'pozitsiyalar';

  @override
  String get enterWeight => 'Og\'irlikni kiriting';

  @override
  String get weightMustBePositive => 'Og\'irlik musbat bo\'lishi kerak';

  @override
  String maxWeightValue(String max, String unit) {
    return 'Maksimum $max $unit';
  }

  @override
  String get unitPcs => 'dona';

  @override
  String get unitKg => 'kg';

  @override
  String lowStorageTooltip(String gb) {
    return 'Joy kam: $gb GB';
  }

  @override
  String storageFree(String gb) {
    return 'Bo\'sh: $gb GB';
  }

  @override
  String get storageRecommendation =>
      'Kassa barqaror ishlashi uchun kamida 2 GB bo\'sh joy tavsiya etiladi.\n\nDiskda joy bo\'shating yoki administratorga murojaat qiling.';

  @override
  String lowStorageBanner(String gb) {
    return 'Bo\'sh joy kam: $gb GB. Barqaror ishlash uchun kamida 2 GB bo\'shatish tavsiya etiladi.';
  }

  @override
  String lowStorageTooltipShort(String gb) {
    return 'Diskda joy kam: $gb GB';
  }

  @override
  String get cashier => 'Kassir:';

  @override
  String get buyer => 'Xaridor:';

  @override
  String receiptHeader(int number) {
    return 'CHEK #$number';
  }

  @override
  String get receiptDiscountItem => 'Chegirma:';

  @override
  String get receiptSubtotalLabel => 'Oraliq summa';

  @override
  String get receiptPayment => 'To\'lov:';

  @override
  String get fiscalMark => 'FB:';

  @override
  String remainingStock(String qty) {
    return 'Qold: $qty';
  }

  @override
  String get tableHeaderName => 'Nomi';

  @override
  String get tableHeaderPrice => 'Narxi';

  @override
  String get tableHeaderQty => 'Miqdori';

  @override
  String get tableHeaderTotal => 'Jami';

  @override
  String get emptyReceipt => 'Chek bo\'sh';

  @override
  String get addProductsViaSearch =>
      'Qidirish orqali tovar qo\'shing\nyoki shtrix-kodni skanerlang';

  @override
  String get addProductsViaSearchShort => 'Qidirish orqali tovar qo\'shing';

  @override
  String get priceLabel => 'Narxi';

  @override
  String get receiptTotalLabel => 'Chek bo\'yicha jami';

  @override
  String get positionsLabel => 'Pozitsiyalar';

  @override
  String get toPayLabel => 'TO\'LASHGA';

  @override
  String get payBtn => 'TO\'LASH';

  @override
  String get totalLabel => 'Jami:';

  @override
  String posAndQty(int positions, String qty) {
    return '$positions poz. / $qty dona';
  }

  @override
  String get modeRetail => 'Chakana';

  @override
  String get modeWholesale => 'ULGURJI';

  @override
  String get quickProducts => 'Tez tovarlar';

  @override
  String get editProduct => 'Tahrirlash';

  @override
  String get labelComment => 'Izoh';

  @override
  String get selectPackage => 'Qadoqni tanlang';

  @override
  String packageQty(String qty) {
    return '$qty dona';
  }

  @override
  String get allBreadcrumb => 'Hammasi';

  @override
  String productPrice(String price) {
    return '$price so\'m';
  }

  @override
  String maxBonusPercent(int percent) {
    return 'Chek summasining $percent% gacha ishlatish mumkin';
  }

  @override
  String get insufficientBonuses => 'Bonuslar yetarli emas';

  @override
  String get enterValidPhone => 'To\'g\'ri telefon raqamini kiriting';

  @override
  String errorsCount(int count) {
    return '$count ta xato';
  }

  @override
  String selectAllCount(int count) {
    return 'Hammasini tanlash ($count)';
  }

  @override
  String retryCount(int count) {
    return 'Qayta urinish ($count)';
  }

  @override
  String receiptHash(int number) {
    return 'Chek #$number';
  }

  @override
  String get enterIntegerNumber => 'Butun sonni kiriting';

  @override
  String enterDigits(int length) {
    return '$length ta raqam kiriting';
  }

  @override
  String get drawerPrimary => 'Asosiy';

  @override
  String get drawerSecondary => 'Qo\'shimcha';

  @override
  String get tooltipMore => 'Yana';

  @override
  String get statusOnline => 'Online';

  @override
  String get statusOffline => 'Offline';

  @override
  String get statusSyncing => 'Sinxronlash...';

  @override
  String get thankYouForPurchase => 'Xaridingiz uchun rahmat!';

  @override
  String get searchProductHint => 'Tovar qidirish (nomi yoki shtrix-kod)';

  @override
  String get actionDefer => 'Keyinga qoldirish';

  @override
  String get actionDeferredList => 'Kechiktirilganlar';

  @override
  String get actionMark => 'Markirovka';

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
  String get actionIncrease => 'Oshirish';

  @override
  String get actionDecrease => 'Kamaytirish';

  @override
  String get restaurantSettings => 'Restoran rejimi';

  @override
  String get restaurantSettingsDesc => 'Stollar, zonalar, servis to\'lovi';

  @override
  String get restaurantOperatingMode => 'Ish rejimi';

  @override
  String get restaurantModeRetail => 'Chakana savdo';

  @override
  String get restaurantModeRetailDesc => 'Do\'konlar uchun standart POS';

  @override
  String get restaurantModeRestaurant => 'Restoran';

  @override
  String get restaurantModeRestaurantDesc =>
      'Stollar, buyurtmalar, servis to\'lovi';

  @override
  String get restaurantModeService => 'Servis';

  @override
  String get restaurantModeServiceDesc => 'Qabul, navbat';

  @override
  String get restaurantZoneManagement => 'Zonalarni boshqarish';

  @override
  String get restaurantZoneAdd => 'Zona qo\'shish';

  @override
  String get restaurantZoneRename => 'Nomini o\'zgartirish';

  @override
  String get restaurantZonePresets => 'Oldindan o\'rnatilgan';

  @override
  String get restaurantZoneHall => 'Zal';

  @override
  String get restaurantZoneTerrace => 'Terrasa';

  @override
  String get restaurantZoneVip => 'VIP';

  @override
  String get restaurantZoneBar => 'Bar';

  @override
  String get restaurantZoneBooth => 'Kabinka';

  @override
  String get restaurantZoneKaraoke => 'Karaoke';

  @override
  String get restaurantZoneVeranda => 'Veranda';

  @override
  String get restaurantZonePrivate => 'Xususiy xona';

  @override
  String get restaurantTableManagement => 'Stollarni boshqarish';

  @override
  String get restaurantTableAdd => 'Stol qo\'shish';

  @override
  String get restaurantTableEdit => 'Stolni tahrirlash';

  @override
  String get restaurantTableName => 'Stol nomi';

  @override
  String get restaurantTableCapacity => 'Sig\'imi';

  @override
  String get restaurantTableZone => 'Zona';

  @override
  String get restaurantTableSortOrder => 'Tartib';

  @override
  String get restaurantTableDeactivate => 'Stolni o\'chirish';

  @override
  String restaurantTableDeactivateConfirm(String name) {
    return '«$name» stolini o\'chirish kerakmi?';
  }

  @override
  String get restaurantServiceCharge => 'Servis to\'lovi';

  @override
  String get restaurantServiceChargeEnabled => 'Servis to\'lovini yoqish';

  @override
  String get restaurantServiceChargePercent => 'Servis to\'lovi foizi';

  @override
  String get restaurantTableFree => 'Bo\'sh';

  @override
  String get restaurantTableOccupied => 'Band';

  @override
  String get restaurantTableReserved => 'Band qilingan';

  @override
  String get restaurantTableDirty => 'Tozalash';

  @override
  String get restaurantOrderDineIn => 'Zalda';

  @override
  String get restaurantOrderTakeout => 'Olib ketish';

  @override
  String get restaurantOrderDelivery => 'Yetkazib berish';

  @override
  String get restaurantAllZones => 'Barcha zonalar';

  @override
  String get restaurantNoTables => 'Stollar yo\'q';

  @override
  String get restaurantNoTablesHint =>
      'Restoran sozlamalarida stollar qo\'shing';

  @override
  String get restaurantGoToSettings => 'Sozlamalarga o\'tish';

  @override
  String get restaurantOrdersEmpty => 'Faol buyurtmalar yo\'q';

  @override
  String restaurantOrderItems(int count) {
    return '$count pozitsiya';
  }

  @override
  String restaurantOrderGuests(int count) {
    return 'Mehmonlar: $count';
  }

  @override
  String restaurantOrderWaiter(String name) {
    return 'Ofitsiant: $name';
  }

  @override
  String restaurantOrderElapsed(int minutes) {
    return '$minutes min';
  }

  @override
  String get restaurantNoOrder => 'Faol buyurtma yo\'q';

  @override
  String get restaurantOpenOrder => 'Buyurtma ochish';

  @override
  String get restaurantCloseOrder => 'Buyurtmani yopish';

  @override
  String get restaurantAddItems => 'Pozitsiya qo\'shish';

  @override
  String get restaurantGoToPayment => 'To\'lovga';

  @override
  String get restaurantTransfer => 'Ko\'chirish';

  @override
  String get restaurantSplitBill => 'Bo\'lish';

  @override
  String get restaurantChangeStatus => 'Statusni o\'zgartirish';

  @override
  String get restaurantSetFree => 'Bo\'sh';

  @override
  String get restaurantSetReserved => 'Band qilish';

  @override
  String get restaurantSetDirty => 'Tozalash kerak';

  @override
  String get restaurantCreateOrder => 'Yangi buyurtma';

  @override
  String get restaurantPartySize => 'Mehmonlar soni';

  @override
  String get restaurantOrderType => 'Buyurtma turi';

  @override
  String get restaurantWaiter => 'Ofitsiant';

  @override
  String get restaurantNote => 'Eslatma';

  @override
  String get restaurantDeliveryAddress => 'Yetkazib berish manzili';

  @override
  String get restaurantDeliveryPhone => 'Telefon';

  @override
  String get restaurantTransferTitle => 'Buyurtmani ko\'chirish';

  @override
  String restaurantTransferCurrent(String table) {
    return 'Joriy: $table';
  }

  @override
  String get restaurantTransferSelectFree => 'Bo\'sh stolni tanlang:';

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
  String get restaurantSplitTitle => 'Hisobni bo\'lish';

  @override
  String get restaurantSplitEvenly => 'Teng';

  @override
  String get restaurantSplitByItems => 'Pozitsiyalar bo\'yicha';

  @override
  String get restaurantSplitGuestCount => 'Mehmonlar soni';

  @override
  String restaurantSplitPerGuest(String amount) {
    return 'Har biriga: $amount';
  }

  @override
  String restaurantSplitGuest(int number) {
    return 'Mehmon $number';
  }

  @override
  String get restaurantSplitApply => 'Qo\'llash';

  @override
  String get restaurantSplitPaymentTitle => 'Mehmonlar bo\'yicha to\'lov';

  @override
  String get restaurantSplitPaymentProceed => 'To\'lovga';

  @override
  String get restaurantPreCheckPrinted => 'Pre-chek printerga yuborildi';

  @override
  String get restaurantPreCheckFailed => 'Pre-chek chop etish xatosi';

  @override
  String get restaurantSubtotal => 'Oraliq summa';

  @override
  String restaurantServiceChargeLine(String percent) {
    return 'Servis to\'lovi ($percent%)';
  }

  @override
  String restaurantOrderNumber(int number) {
    return 'Buyurtma #$number';
  }

  @override
  String restaurantTakeoutNumber(int number) {
    return 'Olib ketish #$number';
  }

  @override
  String restaurantDeliveryNumber(int number) {
    return 'Yetkazib berish #$number';
  }

  @override
  String get restaurantSaved => 'Restoran sozlamalari saqlandi';

  @override
  String get restaurantQuickActions => 'Tez harakatlar';

  @override
  String get restaurantNoItems => 'Mahsulotlar yo\'q';

  @override
  String restaurantTableSeats(int count) {
    return '$count o\'rin';
  }

  @override
  String get restaurantOrderTab => 'Buyurtma';

  @override
  String get restaurantMenuTab => 'Menyu';

  @override
  String restaurantGuestLabel(int number) {
    return 'Mehmon $number';
  }

  @override
  String get restaurantRemoveItem => 'Mahsulotni o\'chirish';

  @override
  String get restaurantPrintPrecheck => 'Oldindan chek';

  @override
  String get restaurantNewTakeout => 'Olib ketish';

  @override
  String get restaurantNewDelivery => 'Yetkazib berish';

  @override
  String get setupSectionOrganization => 'Tashkilot';

  @override
  String get setupSectionContact => 'Aloqa shaxsi';

  @override
  String get setupSectionAddress => 'Manzillar';

  @override
  String get setupSectionCashBox => 'Kassa';

  @override
  String get setupSectionUsers => 'Kim ishlaydi';

  @override
  String get setupSectionSecurity => 'Kod bilan kirish';

  @override
  String get setupSectionScanner => 'Skaner';

  @override
  String get setupSectionScale => 'Tarozi';

  @override
  String get setupSectionDisplay => 'Xaridor displeyi';

  @override
  String get setupSectionTerminal => 'To\'lov terminali';

  @override
  String get setupSectionCashback => 'Naqd pul qaytarish';

  @override
  String get setupTaxIdExplanation =>
      'Soliq raqami har bir chekda chop etiladi va fiskal xizmatga yuboriladi. Bu yerdagi xato faqat soliq organi bilan birinchi solishtirishda ma\'lum bo\'ladi — cheklar xaridorlarga berilgandan keyin.';

  @override
  String get setupFiscalCredentialsExplanation =>
      'Rekvizitlarni fiskal operator beradi. Ular noto\'g\'ri bo\'lsa, cheklar odatdagidek chop etiladi, lekin fiskal xizmatga yetib bormaydi — farq sotuvda emas, solishtirishda ma\'lum bo\'ladi.';

  @override
  String get setupKktNumberExplanation =>
      'KKM raqami kassani operatordagi ro\'yxatdan o\'tishi bilan bog\'laydi. Bu yerdagi xato cheklarni begona kassa nomidan yuboradi va buni kassaning o\'zidan sezib bo\'lmaydi.';

  @override
  String setupStepProgress(int current, int total) {
    return '$current / $total qadam';
  }

  @override
  String get setupStepChecking => 'Tekshirish';

  @override
  String get setupStepTelegram => 'Telegram';

  @override
  String get setupStepCountry => 'Mamlakat';

  @override
  String get setupStepOrganization => 'Tashkilot';

  @override
  String get setupStepVat => 'QQS';

  @override
  String get setupStepUsers => 'Foydalanuvchilar';

  @override
  String get setupStepWorkMode => 'Ish rejimi';

  @override
  String get setupStepPos => 'Kassa';

  @override
  String get setupStepFiscal => 'Fiskalizatsiya';

  @override
  String get setupStepEquipment => 'Uskunalar';

  @override
  String get setupStepTerminals => 'Terminallar';

  @override
  String get setupStepOperatingMode => 'Biznes turi';

  @override
  String get setupStepBusinessRules => 'Qoidalar';

  @override
  String get setupStepSummary => 'Tekshirish';

  @override
  String get setupStepComplete => 'Tayyor';

  @override
  String get setupCheckingSettings => 'Sozlamalar tekshirilmoqda...';

  @override
  String get setupStateUnreadableTitle => 'Kassa javob bermadi';

  @override
  String get setupStateUnreadableBody =>
      'Ustaqol kassa holatini o‘qimaguncha sozlashni boshlamaydi: aks holda u ishlab turgan do‘konni o‘chirib yuborishi mumkin. Kassa ishga tushirilganini va tarmoqda mavjudligini tekshiring.';

  @override
  String get wtUnavailableTitle => 'Kassa bilan aloqa yo‘q';

  @override
  String get wtUnavailableBody =>
      'Terminal ma’lumotlarni faqat WebTransport orqali oladi. Zaxira yo‘l yo‘q: aloqa bo‘lmasa, ko‘rsatadigan narsa yo‘q, eski ma’lumotni yangidek ko‘rsatish esa hech narsa ko‘rsatmaslikdan yomonroq. Kassa ishga tushirilganini tekshiring va qayta urinib ko‘ring.';

  @override
  String wtUnavailableReason(String reason) {
    return 'Sababi: $reason';
  }

  @override
  String get terminalHomeWhoHeader => 'Kim kirdi';

  @override
  String get terminalHomeUserLabel => 'Kassir';

  @override
  String get terminalHomeSaleNote =>
      'Savat, chek raqami va smena kassaga tegishli — terminal chekni ko‘rsatadi va sim orqali buyruq beradi. Chek chop etish, fiskallashtirish va pul qutisi kassada qoladi.';

  @override
  String get wtNotPortedTitle => 'Bu ekran hozircha faqat kassada';

  @override
  String get wtNotPortedBody =>
      'Brauzer terminali ma’lumotlarni sim orqali oladi va ekran bu yerda uning barcha shartnomalari sim ustida ishlay olganda paydo bo‘ladi. Bu hali o‘rganmagan. Uni bo‘sh ko‘rsatgandan ko‘ra, to‘g‘ridan aytgan yaxshiroq.';

  @override
  String wtNotPortedLocation(String location) {
    return 'Yo‘nalish: $location';
  }

  @override
  String get setupWelcomeTitle => 'TelePOS ga xush kelibsiz!';

  @override
  String get setupCountryDescription =>
      'Valyuta va soliqlarni sozlash uchun mamlakatingizni tanlang';

  @override
  String setupPriceExample(String amount) {
    return 'Misol: $amount';
  }

  @override
  String setupVatRateLabel(int rate) {
    return 'QQS: $rate%';
  }

  @override
  String get setupOrganizationTitle => 'Tashkilot ma\'lumotlari';

  @override
  String get setupOrganizationDescription =>
      'Kompaniyangiz haqida ma\'lumot kiriting';

  @override
  String get setupCompanyNameLabel => 'Tashkilot nomi';

  @override
  String get setupCompanyNameHint => 'MChJ \"Mening kompaniyam\"';

  @override
  String setupTaxIdDigits(int length) {
    return '$length ta raqam';
  }

  @override
  String get setupLegalAddressLabel => 'Yuridik manzil';

  @override
  String get setupActualAddressLabel => 'Do\'konning haqiqiy manzili';

  @override
  String get setupOwnerNameLabel => 'Rahbar F.I.O.';

  @override
  String get setupPhoneLabel => 'Telefon';

  @override
  String get setupVatTitle => 'Qo\'shilgan qiymat solig\'i';

  @override
  String get setupVatDescription => 'Tashkilotingizning soliq rejimini tanlang';

  @override
  String get setupVatPayerTitle => 'QQS to\'lovchi';

  @override
  String setupVatPayerRate(int rate) {
    return 'QQS stavkasi: $rate%';
  }

  @override
  String get setupVatPayerRateUnknown => 'QQS stavkasi mamlakatga bog\'liq';

  @override
  String get setupVatPayerDescription =>
      'Cheklarda QQS ajratiladi.\nUmumiy soliq tizimidagi kompaniyalar uchun majburiy.';

  @override
  String get setupVatNonPayerTitle => 'QQS siz';

  @override
  String get setupVatNonPayerSubtitle => 'QQS qo\'llanilmaydi';

  @override
  String get setupVatNonPayerDescription =>
      'Cheklarda QQS ajratilmaydi.\nSoddalashtirilgan tizim yoki patentdagi YaTT uchun.';

  @override
  String get setupWorkModeTitle => 'Ish rejimi';

  @override
  String get setupWorkModeDescription => 'Kassangiz qanday ishlashini tanlang';

  @override
  String get setupAutonomousTitle => 'Avtonom rejim';

  @override
  String get setupAutonomousSubtitle => 'Internetsiz ishlash';

  @override
  String get setupAutonomousDescription =>
      'Kassa to\'liq avtonom ishlaydi.\nMa\'lumotlar faqat mahalliy saqlanadi.\nKassalar orasida sinxronizatsiya yo\'q.';

  @override
  String get setupNetworkTitle => 'Tarmoq rejimi';

  @override
  String get setupNetworkConfigured => 'Telegram sozlangan';

  @override
  String get setupNetworkRequired => 'Telegram talab qilinadi';

  @override
  String get setupNetworkDescription =>
      'Kassalar orasida ma\'lumotlar sinxronizatsiyasi.\nBulutga zaxira nusxa.\nTelegram da hisobotlar va bildirishnomalar.';

  @override
  String get setupNetworkRequiresTelegram =>
      'Tarmoq rejimi uchun Telegram ni sozlash kerak';

  @override
  String get setupOperatingModeTitle => 'Biznes turi';

  @override
  String get setupOperatingModeDescription => 'Biznesingiz turini tanlang';

  @override
  String get setupRetailTitle => 'Chakana kassa';

  @override
  String get setupRetailSubtitle => 'Do\'kon, dorixona, supermarket';

  @override
  String get setupRetailDescription =>
      'Chakana savdo uchun standart POS.\nSotuvlar, qaytarishlar, tovar qabul qilish.\nSmenalar va hisobotlar.';

  @override
  String get setupRestaurantTitle => 'Restoran / Kafe';

  @override
  String get setupRestaurantSubtitle => 'Stollar, buyurtmalar, yetkazib berish';

  @override
  String get setupRestaurantDescription =>
      'Stollar va zalni boshqarish.\nOlib ketish va yetkazib berish.\nHisobni bo\'lish va servis to\'lovi.';

  @override
  String get setupServiceTitle => 'Servis markazi';

  @override
  String get setupServiceSubtitle => 'Ta\'mirlash, xizmatlar, protseduralar';

  @override
  String get setupServiceDescription =>
      'Ta\'mirlash/xizmatga qabul qilish.\nBuyurtma-naryodlar va ish belgilari.\nStatusni kuzatish va topshirish.';

  @override
  String get setupPosConfigTitle => 'Kassa sozlamalari';

  @override
  String get setupPosConfigDescription =>
      'Kassa apparati parametrlarini ko\'rsating';

  @override
  String get setupCashBoxNameLabel => 'Kassa nomi';

  @override
  String get setupCashBoxNameHint => 'Kassa 1';

  @override
  String get setupPosIdLabel => 'Kassa ID';

  @override
  String get setupPrinterConfigTitle => 'Chek printeri';

  @override
  String get setupPaperWidthLabel => 'Qog\'oz kengligi';

  @override
  String get setupPaperWidth58 => '58 mm (32 belgi)';

  @override
  String get setupPaperWidth80 => '80 mm (48 belgi)';

  @override
  String get setupPrinterHeaderLabel => 'Chek sarlavhasi';

  @override
  String get setupPrinterHeaderHint => 'Do\'kon nomi\nManzil';

  @override
  String get setupPrinterFooterLabel => 'Chek pastki qismi';

  @override
  String get setupPrinterFooterHint => 'Xaridingiz uchun rahmat!';

  @override
  String get setupFiscalNotRequired =>
      'Mamlakatingiz uchun fiskalizatsiya talab qilinmaydi';

  @override
  String get setupFiscalDescription => 'Fiskal operatorga ulanishni sozlang';

  @override
  String get setupEnableWebkassa => 'WebKassa ni yoqish';

  @override
  String get setupEnableOfd => 'OFD ni yoqish';

  @override
  String get setupWebkassaDescription =>
      'WebKassa orqali cheklarni fiskalizatsiya qilish (Qozog\'iston)';

  @override
  String get setupOfdDescription =>
      'OFD orqali cheklarni fiskalizatsiya qilish (Rossiya)';

  @override
  String get setupSkipLater => 'O\'tkazib yuborish (keyinroq sozlash)';

  @override
  String get setupWebkassaAccountTitle => 'WebKassa akkaunt';

  @override
  String get setupWebkassaAccountIdLabel => 'Akkaunt ID';

  @override
  String get setupWebkassaAccountIdHint => 'WebKassa dagi ID ingiz';

  @override
  String get setupWebkassaTokenLabel => 'Akkaunt tokeni';

  @override
  String get setupWebkassaTokenHint => 'API token';

  @override
  String get setupWebkassaPosTitle => 'WebKassa kassa';

  @override
  String get setupWebkassaPosIdLabel => 'Kassa ID';

  @override
  String get setupWebkassaPosIdHint => 'WebKassa dagi kassa ID';

  @override
  String get setupWebkassaPosTokenLabel => 'Kassa tokeni';

  @override
  String get setupWebkassaPosTokenHint => 'Kassa tokeni';

  @override
  String get setupWebkassaFactoryNoLabel => 'KKM zavod raqami';

  @override
  String get setupOfdParamsTitle => 'OFD parametrlari';

  @override
  String get setupOfdInnLabel => 'Tashkilot STIR';

  @override
  String get setupOfdKktRegNoLabel => 'KKT ro\'yxat raqami';

  @override
  String get setupOfdFnNoLabel => 'FN raqami';

  @override
  String get setupOfdUrlLabel => 'OFD URL';

  @override
  String get setupEquipmentTitle => 'Uskunalar';

  @override
  String get setupEquipmentDescription => 'Ulangan uskunalarni sozlang';

  @override
  String get setupEquipmentPrinter => 'Chek printeri';

  @override
  String get setupEquipmentScanner => 'Shtrix-kod skaneri';

  @override
  String get setupEquipmentScales => 'Tarozi';

  @override
  String get setupEquipmentCashDrawer => 'Pul qutisi';

  @override
  String get setupEquipmentDisplay => 'Xaridor displeyi';

  @override
  String get setupConnectionTypeLabel => 'Ulanish turi';

  @override
  String get setupConnectionUsb => 'USB';

  @override
  String get setupConnectionBluetooth => 'Bluetooth';

  @override
  String get setupConnectionWifi => 'Wi-Fi / Ethernet';

  @override
  String get setupConnectionSerial => 'COM-port';

  @override
  String get setupConnectionNone => 'Tanlanmagan';

  @override
  String get setupPrinterIpLabel => 'Printer IP-manzili';

  @override
  String get setupPrinterMacLabel => 'Printer MAC-manzili';

  @override
  String get setupPrinterNameLabel => 'Printer nomi';

  @override
  String get setupPrinterNameHint => 'Oshxona printeri';

  @override
  String get setupScannerTypeLabel => 'Skaner turi';

  @override
  String get setupScannerCamera => 'Qurilma kamerasi';

  @override
  String get setupScannerUsb => 'USB-skaner';

  @override
  String get setupScannerBluetooth => 'Bluetooth-skaner';

  @override
  String get setupScalePortLabel => 'COM-port';

  @override
  String get setupBaudRateLabel => 'Tezlik (baud rate)';

  @override
  String get setupCashDrawerConnected => 'Printerga ulangan';

  @override
  String get setupCashDrawerConnectedDesc => 'Printer buyrug\'i bilan ochiladi';

  @override
  String get setupSkip => 'O\'tkazib yuborish';

  @override
  String get setupPaymentTerminalsTitle => 'To\'lov terminallari';

  @override
  String get setupPaymentTerminalsDescription =>
      'To\'lov tizimlari bilan integratsiyani sozlang';

  @override
  String get setupKaspiIpLabel => 'Terminal IP-manzili';

  @override
  String get setupPortLabel => 'Port';

  @override
  String get setupApiUrlLabel => 'API URL';

  @override
  String get setupApiKeyLabel => 'API kalit';

  @override
  String get setupNoTerminalsAvailable =>
      'Mintaqangiz uchun mavjud to\'lov terminallari yo\'q';

  @override
  String get setupBusinessRulesTitle => 'Biznes qoidalari';

  @override
  String get setupBusinessRulesDescription =>
      'Kassa ishlash qoidalarini sozlang';

  @override
  String get setupPermissionsTitle => 'Ruxsatlar';

  @override
  String get setupAllowDiscounts => 'Chegirmalar';

  @override
  String get setupAllowDiscountsDesc =>
      'Chegirmalarni qo\'llashga ruxsat berish';

  @override
  String get setupAllowDebtSales => 'Qarzga sotuv';

  @override
  String get setupAllowDebtSalesDesc => 'Qarzga sotishga ruxsat berish';

  @override
  String get setupAllowPriceEdit => 'Narxlarni tahrirlash';

  @override
  String get setupAllowPriceEditDesc =>
      'Sotuvda narxlarni o\'zgartirishga ruxsat berish';

  @override
  String get setupAllowCashInOut => 'Kassa operatsiyalari';

  @override
  String get setupAllowCashInOutDesc => 'Naqd pul kiritish va chiqarish';

  @override
  String get setupBlockPriceDecrease => 'Narx pasayishini bloklash';

  @override
  String get setupBlockPriceDecreaseDesc =>
      'Belgilangan narxdan past sotishni taqiqlash';

  @override
  String get setupLimitsTitle => 'Limitlar';

  @override
  String get setupAllowBigAmount => 'Katta summalar';

  @override
  String get setupAllowBigAmountDesc =>
      '> 1 000 000 operatsiyalarga ruxsat berish';

  @override
  String get setupCashWithdrawalLimitLabel => 'Naqd pul chiqarish limiti';

  @override
  String get setupCashWithdrawalLimitHelper =>
      'Limitsiz qoldirish uchun bo\'sh qoldiring';

  @override
  String get setupLoyaltyTitle => 'Sodiqlik dasturi';

  @override
  String get setupCashbackLabel => 'Keshbek';

  @override
  String get setupCashbackDesc => 'Bonus hisoblashni yoqish';

  @override
  String get setupCashbackRateLabel => 'Keshbek foizi';

  @override
  String get setupRoundingTitle => 'Yaxlitlash';

  @override
  String get setupDiscountRounding => 'Chegirmalarni yaxlitlash';

  @override
  String get setupWeightRounding => 'Vaznli tovarlarni yaxlitlash';

  @override
  String get setupRoundingNone => 'Yaxlitlashsiz';

  @override
  String get setupRoundingUp1 => '1 gacha (yuqoriga)';

  @override
  String get setupRoundingDown1 => '1 gacha (pastga)';

  @override
  String get setupRoundingUp5 => '5 gacha (yuqoriga)';

  @override
  String get setupRoundingDown5 => '5 gacha (pastga)';

  @override
  String get setupRoundingUp10 => '10 gacha (yuqoriga)';

  @override
  String get setupRoundingDown10 => '10 gacha (pastga)';

  @override
  String get setupFiscalDisablesRounding =>
      'Fiskalizatsiya yoqilganda yaxlitlash avtomatik o\'chiriladi';

  @override
  String get setupUserCreationTitle => 'Foydalanuvchilarni yaratish';

  @override
  String get setupUserCreationDescription =>
      'Kassa bilan ishlash uchun foydalanuvchilar yarating';

  @override
  String get setupAdminLabel => 'ADMINISTRATOR';

  @override
  String get setupAdminSubtitle => 'Kassa egasi';

  @override
  String get setupUserNameLabel => 'Ism';

  @override
  String get setupUserPinLabel => 'PIN';

  @override
  String get setupUserPinConfirmLabel => 'Tasdiqlash';

  @override
  String get setupAdminPinDefault => 'Standart: 0000';

  @override
  String get setupSellerLabel => 'SOTUVCHI';

  @override
  String get setupSellerOptional => 'Ixtiyoriy';

  @override
  String get setupSellerPinDefault => 'Standart: 1111';

  @override
  String get setupAdminPinMismatch => 'Administrator PIN-kodlari mos kelmaydi';

  @override
  String get setupSummaryTitle => 'Ma\'lumotlarni tekshiring';

  @override
  String get setupSummaryDescription =>
      'Hamma narsa to\'g\'ri ko\'rsatilganiga ishonch hosil qiling';

  @override
  String get setupSummaryCountry => 'Mamlakat';

  @override
  String get setupSummaryCurrency => 'Valyuta';

  @override
  String get setupSummaryFormat => 'Format';

  @override
  String get setupSummaryVat => 'QQS';

  @override
  String get setupSummaryTelegram => 'Telegram';

  @override
  String get setupSummaryStatus => 'Holat';

  @override
  String get setupConfigured => 'Sozlangan';

  @override
  String get setupNotConfigured => 'Sozlanmagan';

  @override
  String get setupSummaryOrganization => 'Tashkilot';

  @override
  String get setupSummaryName => 'Nomi';

  @override
  String get setupSummaryAddress => 'Manzil';

  @override
  String get setupSummaryWorkMode => 'Ish rejimi';

  @override
  String get setupSummaryMode => 'Rejim';

  @override
  String get setupSummaryAutonomous => 'Avtonom (tarmoqsiz)';

  @override
  String get setupSummaryNetwork => 'Tarmoq (sinxronizatsiya)';

  @override
  String get setupSummaryPos => 'Kassa';

  @override
  String get setupSummaryId => 'ID';

  @override
  String get setupEnabled => 'Yoqilgan';

  @override
  String get setupDisabled => 'O\'chirilgan';

  @override
  String get setupSummaryFiscalType => 'Turi';

  @override
  String get setupSummaryEquipment => 'Uskunalar';

  @override
  String get setupSummaryPrinter => 'Printer';

  @override
  String get setupSummaryScanner => 'Skaner';

  @override
  String get setupSummaryScales => 'Tarozi';

  @override
  String get setupSummaryCashDrawer => 'Pul qutisi';

  @override
  String get setupSummaryTerminals => 'To\'lov terminallari';

  @override
  String get setupSummaryRules => 'Biznes qoidalari';

  @override
  String get setupSummaryDiscounts => 'Chegirmalar';

  @override
  String get setupSummaryDebtSales => 'Qarzga';

  @override
  String get setupSummaryCashback => 'Keshbek';

  @override
  String get setupSummaryBigAmount => 'Katta summalar';

  @override
  String get setupSummaryUsers => 'Foydalanuvchilar';

  @override
  String get setupSummaryAdmin => 'Administrator';

  @override
  String get setupSummarySeller => 'Sotuvchi';

  @override
  String get setupCompleteTitle => 'Sozlash tugadi!';

  @override
  String get setupCompleteSubtitle => 'Kassa ishlashga tayyor';

  @override
  String get setupStartWork => 'Ishni boshlash';

  @override
  String setupVatPayerSummary(int rate) {
    return 'QQS to\'lovchi ($rate%)';
  }

  @override
  String get setupSummaryWkPosId => 'WK kassa ID';

  @override
  String get setupSummaryOfdInn => 'STIR';

  @override
  String get setupScalesConfigured => 'Sozlangan';

  @override
  String get setupScalesNotConfigured => 'Sozlanmagan';

  @override
  String get setupCashDrawerOn => 'Yoqilgan';

  @override
  String get setupAllowed => 'Ruxsat berilgan';

  @override
  String get setupDenied => 'Taqiqlangan';

  @override
  String get setupAllowedFem => 'Ruxsat berilgan';

  @override
  String get setupDeniedFem => 'Taqiqlangan';

  @override
  String get setupCashbackOff => 'O\'chirilgan';

  @override
  String get setupBigAmountLimit => 'Limit 100 000';

  @override
  String get setupDisplayPortLabel => 'COM-port';

  @override
  String get telegramAuthSkip => 'O\'tkazib yuborish (keyinroq sozlash)';

  @override
  String get telegramInitializing => 'Ishga tushirish';

  @override
  String get telegramErrorTdlib => 'TDLib xatosi';

  @override
  String get telegramAuthLogin => 'Telegram ga kirish';

  @override
  String get telegramAuthCodeStep => 'Tasdiqlash kodi';

  @override
  String get telegramAuth2fa => 'Ikki bosqichli autentifikatsiya';

  @override
  String get telegramRegister => 'Ro\'yxatdan o\'tish';

  @override
  String get telegramSearchingChannels => 'Kanallarni qidirish';

  @override
  String get telegramLoadingData => 'Ma\'lumotlar yuklanmoqda';

  @override
  String get telegramOrgData => 'Tashkilot ma\'lumotlari';

  @override
  String get telegramSetupChannels => 'Kanallarni sozlash';

  @override
  String get telegramSetupEncryption => 'Shifrlashni sozlash';

  @override
  String get telegramSetupComplete => 'Tayyor';

  @override
  String get telegramInitializingLong => 'Telegram ishga tushirilmoqda...';

  @override
  String get telegramConnecting => 'Telegram serverlariga ulanish';

  @override
  String get telegramTdlibNotFound => 'TDLib topilmadi';

  @override
  String get telegramTdlibErrorMessage =>
      'TDLib mahalliy kutubxonasi topilmadi.\nTelegram bilan ishlash uchun tdjson o\'rnatish kerak.';

  @override
  String get telegramForWindows => 'Windows uchun:';

  @override
  String get telegramWindowsInstructions =>
      '1. TDLib ni yuklab oling: github.com/tdlib/td/releases\n2. tdjson.dll ni loyiha ildiziga nusxalang\n3. Yoki C:\\TDLib\\bin\\ ga o\'rnating';

  @override
  String get telegramPhoneAuthTitle => 'Telefon raqami bilan kirish';

  @override
  String get telegramPhoneAuthDescription =>
      'Telegram akkauntingizga bog\'langan telefon raqamini kiriting';

  @override
  String get telegramCountryCodeLabel => 'Mamlakat kodi';

  @override
  String get telegramPhoneNumber => 'Telefon raqami';

  @override
  String get telegramGetCode => 'Kodni olish';

  @override
  String get telegramRefreshQr => 'QR-kodni yangilash';

  @override
  String get telegramSignUp => 'Ro\'yxatdan o\'tish';

  @override
  String get telegramEnterStoreName => 'Do\'kon nomini kiriting';

  @override
  String get telegramInvalidBinIin =>
      'To\'g\'ri STIR/JSHSHIR kiriting (12 ta raqam)';

  @override
  String get telegramInvalidCode => 'To\'g\'ri kodni kiriting';

  @override
  String get telegramEnterPassword => 'Parolni kiriting';

  @override
  String get telegramCodeResent => 'Kod qayta yuborildi';

  @override
  String get telegramEnterName => 'Ismni kiriting';

  @override
  String get telegramManageAccount => 'Akkauntni boshqarish';

  @override
  String get telegramNotificationsSection => 'Bildirishnomalar';

  @override
  String get telegramNotificationsDesc =>
      'Sotuvlar, smenalar va boshqalar haqida bildirishnomalar olish';

  @override
  String get telegramNotifySales => 'Sotuv bildirishnomalari';

  @override
  String get telegramNotifySalesDesc => 'Katta sotuvlar, qaytarishlar';

  @override
  String get telegramNotifyShifts => 'Smena bildirishnomalari';

  @override
  String get telegramNotifyShiftsDesc => 'Smenalar ochilishi va yopilishi';

  @override
  String get telegramNotifyCritical => 'Muhim bildirishnomalar';

  @override
  String get telegramNotifyCriticalDesc => 'Xatolar, OFD bilan muammolar';

  @override
  String get telegramNotifyStock => 'Qoldiq bildirishnomalari';

  @override
  String get telegramNotifyStockDesc => 'Tovar tanqisligi';

  @override
  String get telegramSyncSettings => 'Sinxronizatsiya sozlamalari';

  @override
  String get telegramAutoSyncDesc => 'Ma\'lumotlarni avtomatik sinxronlash';

  @override
  String get telegramSyncInterval1min => '1 daqiqa';

  @override
  String get telegramSyncInterval5min => '5 daqiqa';

  @override
  String get telegramSyncInterval15min => '15 daqiqa';

  @override
  String get telegramSyncInterval30min => '30 daqiqa';

  @override
  String get telegramSyncInterval1hour => '1 soat';

  @override
  String get telegramSystemChannels => 'Tizim kanallari';

  @override
  String get telegramRefresh => 'Yangilash';

  @override
  String get telegramChannelsNotConnected =>
      'Kanallar ulanmagan.\nAvtomatik yaratish uchun Telegram ga kiring.';

  @override
  String telegramChannelsConnected(int connected, int total) {
    return '$total dan $connected ta kanal ulangan';
  }

  @override
  String telegramChannelsLoadError(String error) {
    return 'Kanallarni yuklash xatosi: $error';
  }

  @override
  String get telegramForceSyncDesc => 'Hozir barcha ma\'lumotlarni sinxronlash';

  @override
  String get telegramFullSyncDesc => 'Hammasini qayta sinxronlash';

  @override
  String get telegramRecreateChannelsDesc => 'Tizim kanallarini qayta yaratish';

  @override
  String get telegramLogoutDesc => 'Telegram integratsiyasini o\'chirish';

  @override
  String get telegramFullSyncWarning =>
      'Bu barcha sinxronizatsiya vaqt belgilarini tiklaydi va barcha ma\'lumotlarni qayta yuklaydi. Operatsiya uzoq vaqt olishi mumkin.';

  @override
  String get telegramRecreateChannelsWarning =>
      'Bu amal barcha tizim kanallarini qayta yaratadi. Kanallardagi mavjud ma\'lumotlar yo\'qoladi.';

  @override
  String get telegramLogoutWarning =>
      'Chiqishga ishonchingiz komilmi? Sinxronizatsiya va bildirishnomalar o\'chiriladi.';

  @override
  String get telegramChannelsRecreated => 'Kanallar qayta yaratildi';

  @override
  String get telegramConnectedStatus => 'Ulangan';

  @override
  String get telegramNotConnected => 'Ulanmagan';

  @override
  String get telegramAccountLabel => 'Telegram akkaunt';

  @override
  String get telegramLoginForSync => 'Ma\'lumotlarni sinxronlash uchun kiring';

  @override
  String get channelDescSystemEvents => 'Tizim hodisalari';

  @override
  String get channelDescSales => 'Sotuvlar lentasi';

  @override
  String get channelDescAlerts => 'Muhim bildirishnomalar';

  @override
  String get channelDescReports => 'Hisobotlar va xulosalar';

  @override
  String get channelDescSync => 'Ma\'lumotlar sinxronizatsiyasi';

  @override
  String get channelDescFiscal => 'Fiskal hodisalar';

  @override
  String get channelDescStaffChat => 'Xodimlar chati';

  @override
  String get channelDescDataExchange => 'Ma\'lumot almashish';

  @override
  String get channelDescTerminalStatus => 'Terminal holati';

  @override
  String get channelDescBackup => 'MB zaxira nusxalari';

  @override
  String get chatNoConnectionBanner =>
      'Aloqa yo\'q. Xabarlar tiklanganda yuboriladi.';

  @override
  String get chatLinkTelegramForId =>
      'Chatda identifikatsiya uchun Telegram ni ulang';

  @override
  String chatSendError(String error) {
    return 'Yuborish xatosi: $error';
  }

  @override
  String chatFoundMessages(int count) {
    return '$count ta xabar topildi';
  }

  @override
  String get chatNoResults => 'Hech narsa topilmadi';

  @override
  String get chatCopyUidInstructions =>
      'UID ni boshqa tizimlarda foydalanish uchun nusxalang';

  @override
  String get chatUidExample => 'Masalan: telepos@pos-1';

  @override
  String get chatServiceUnavailable => 'Xizmat mavjud emas';

  @override
  String get chatTelegramLinked => 'Telegram muvaffaqiyatli ulandi';

  @override
  String get additionalLogout => 'Chiqish';

  @override
  String get additionalLockCashier => 'Bloklash';

  @override
  String get additionalPrinterAction => 'Printer';

  @override
  String get additionalPrintLastReceipt => 'Oxirgi chek';

  @override
  String get additionalSyncAction => 'Sinxronizatsiya';

  @override
  String get additionalCheckPrice => 'Narxni tekshirish';

  @override
  String get additionalMinimize => 'Kichraytirish';

  @override
  String get additionalCustomers => 'Xaridorlar';

  @override
  String get additionalUpdateAction => 'Yangilash';

  @override
  String get additionalExtraPrinter => 'Qo\'sh. printer';

  @override
  String get additionalSupplyAction => 'Qabul qilish';

  @override
  String get additionalLanguageAction => 'Til';

  @override
  String get additionalKaspiPos => 'Kaspi POS';

  @override
  String get additionalPrinterEscPos => 'Termoprinter ESC/POS';

  @override
  String get additionalPrinterNotConfigured => 'Printer sozlanmagan';

  @override
  String get additionalPrinterWifi => 'Wi-Fi printer';

  @override
  String get additionalPrinterWifiDesc => 'IP orqali ulanish';

  @override
  String get additionalPrinterBluetooth => 'Bluetooth printer';

  @override
  String get additionalPrinterBluetoothDesc => 'Qurilmalarni qidirish';

  @override
  String get additionalPrinterUsb => 'USB printer';

  @override
  String get additionalPrinterSystem => 'Tizim printeri';

  @override
  String get additionalPrinterDisconnected => 'Printer uzilgan';

  @override
  String get additionalPrinterIpLabel => 'IP';

  @override
  String get additionalPrinterEnterIp => 'IP manzilni kiriting';

  @override
  String additionalPrinterConnecting(String address) {
    return '$address ga ulanmoqda...';
  }

  @override
  String get additionalPrinterConnectingUsb => 'USB printerga ulanmoqda...';

  @override
  String get additionalPrinterNotConnected => 'Printer ulanmagan';

  @override
  String get additionalPrintingLastReceipt => 'Oxirgi chek chop etilmoqda...';

  @override
  String get additionalTestReceiptTitle => '=== TEST CHEK ===';

  @override
  String get additionalReceiptPrinted => 'Chek chop etildi';

  @override
  String additionalPriceSearching(String query) {
    return 'Qidirish: $query';
  }

  @override
  String get additionalMinimizing => 'Oyna kichraytirilmoqda...';

  @override
  String get additionalLatestVersion => 'Sizda oxirgi versiya o\'rnatilgan';

  @override
  String get additionalExtraPrinterTitle => 'Qo\'shimcha printer';

  @override
  String get additionalExtraPrinterUsedFor =>
      'Qo\'shimcha printer quyidagilar uchun ishlatiladi:';

  @override
  String get additionalExtraPrinterLabels => 'Yorliqlarni chop etish';

  @override
  String get additionalExtraPrinterKitchen => 'Oshxonaga chop etish';

  @override
  String get additionalExtraPrinterDuplicate => 'Chek dublikati';

  @override
  String get additionalKaspiPosTitle => 'Kaspi POS';

  @override
  String get additionalKaspiPosDesc =>
      'To\'lovlarni qabul qilish uchun Kaspi terminali.';

  @override
  String get additionalKaspiPosNotConnected => 'Holat: Ulanmagan';

  @override
  String additionalPrinterConnectedName(String name) {
    return 'Printer ulandi: $name';
  }

  @override
  String additionalErrorWithMessage(String message) {
    return 'Xatolik: $message';
  }

  @override
  String get additionalPrinterUsbNotSupported =>
      'USB printerlar qo\'llab-quvvatlanmaydi';

  @override
  String get additionalPrinterUsbConnected => 'USB printer ulandi';

  @override
  String get additionalBarcodeLabel => 'Shtrix-kod';

  @override
  String get additionalBarcodeHint => 'Skanerlang yoki kiriting';

  @override
  String additionalTestReceiptProduct(String number) {
    return 'Tovar $number';
  }

  @override
  String get additionalTestReceiptTotal => 'JAMI:';

  @override
  String get additionalTestReceiptThankYou => 'Xaridingiz uchun rahmat!';

  @override
  String get langRussian => 'Ruscha';

  @override
  String get langEnglish => 'English';

  @override
  String get langKazakh => 'Qozoqcha';

  @override
  String get langKyrgyz => 'Qirg\'izcha';

  @override
  String get langUzbek => 'O\'zbekcha';

  @override
  String get transportFullSyncWarning =>
      'Bu barcha sinxronizatsiya belgilarini tiklaydi va barcha ma\'lumotlarni qayta yuklaydi. Bu uzoq vaqt olishi mumkin. Davom ettirilsinmi?';

  @override
  String get transportSyncAbout => 'Sinxronizatsiya haqida';

  @override
  String transportSyncStateError(String error) {
    return 'Sinxronizatsiya holatini yuklash xatosi: $error';
  }

  @override
  String get transportSyncInfoDialog =>
      'Har bir ma\'lumot turi mustaqil sinxronlanadi. Faqat oxirgi sinxronizatsiyadan keyin o\'zgargan elementlar uzatiladi.\n\nInterval: 5 daqiqa (standart)\nMa\'lumotlar uzatishdan oldin AES-256-GCM bilan shifrlanadi.';

  @override
  String get transportSyncNever => 'Hech qachon';

  @override
  String get transportModeDescription =>
      'Server bilan ma\'lumot almashish usulini tanlang';

  @override
  String get transportModeRest => 'REST API';

  @override
  String get transportModeRestDesc => 'Klassik HTTP/WebSocket ulanish';

  @override
  String get transportModeTelegram => 'Telegram';

  @override
  String get transportModeTelegramDesc => 'Telegram transport sifatida';

  @override
  String get transportModeHybrid => 'Gibrid';

  @override
  String get transportModeHybridDesc => 'Telegram asosiy, REST zaxira sifatida';

  @override
  String get transportModeRecommended => 'Tavsiya etiladi';

  @override
  String transportSyncIntervalMinutes(int minutes) {
    return '$minutes daqiqa';
  }

  @override
  String get transportSyncOnConnectivity => 'Tarmoq tiklanganda sinxronlash';

  @override
  String transportSyncIntervalOption(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes daqiqa',
      one: '$minutes daqiqa',
    );
    return '$_temp0';
  }

  @override
  String get transportEnableQueue => 'Operatsiyalar navbati';

  @override
  String get transportEnableQueueDesc =>
      'Tarmoq yo\'qligida operatsiyalarni buferlashtirish';

  @override
  String get transportMaxQueueSize => 'Navbat hajmi';

  @override
  String transportQueueSizeStatus(int size) {
    return '$size ta operatsiya';
  }

  @override
  String get transportAutoCleanup => 'Avtotozalash';

  @override
  String get transportAutoCleanupDesc =>
      'Tugallangan operatsiyalarni 7 kundan keyin o\'chirish';

  @override
  String get transportNotifyChanges => 'Transport almashishi';

  @override
  String get transportNotifyChangesDesc =>
      'Transport rejimi o\'zgarganda xabar berish';

  @override
  String get transportNotifySyncErrors => 'Sinxronizatsiya xatolari';

  @override
  String get transportNotifySyncErrorsDesc =>
      'Sinxronizatsiya xatolari haqida xabar berish';

  @override
  String get transportNotifyOfflineOnline => 'Aloqa';

  @override
  String get transportNotifyConnectivityDesc =>
      'Ulanish o\'zgarganda xabar berish';

  @override
  String get transportNotifyQueueFull => 'Navbat to\'la';

  @override
  String get transportNotifyQueueFullDesc => 'Navbat to\'lganda xabar berish';

  @override
  String saleErrorInitiation(String error) {
    return 'Sotuvni boshlash xatosi: $error';
  }

  @override
  String get saleErrorNotInitialized => 'Sotuv ishga tushirilmagan';

  @override
  String get saleErrorEmpty => 'Chek bo\'sh';

  @override
  String saleErrorCompletion(String error) {
    return 'Sotuvni yakunlash xatosi: $error';
  }

  @override
  String saleErrorSearch(String error) {
    return 'Qidirish xatosi: $error';
  }

  @override
  String saleErrorDeferred(String error) {
    return 'Chekni kechiktirish xatosi: $error';
  }

  @override
  String get saleErrorDeferredNotFound => 'Kechiktirilgan chek topilmadi';

  @override
  String saleErrorLoadingDeferred(String error) {
    return 'Kechiktirilgan chekni yuklash xatosi: $error';
  }

  @override
  String get paymentCustomerDefault => 'Mijoz';

  @override
  String get paymentErrorFormation =>
      'To\'lovni shakllantirish imkoni bo\'lmadi. Hisob sozlamalarini tekshiring.';

  @override
  String get paymentErrorSaving => 'Sotuvni saqlash xatosi';

  @override
  String paymentErrorProcessing(String error) {
    return 'To\'lovni qayta ishlash xatosi: $error';
  }

  @override
  String paymentAccountDefault(int id) {
    return 'Hisob $id';
  }

  @override
  String refundErrorReceiptNotFound(String number) {
    return '#$number chek topilmadi';
  }

  @override
  String refundErrorLoadingReceipt(String error) {
    return 'Chekni yuklash xatosi: $error';
  }

  @override
  String refundErrorSearch(String error) {
    return 'Qidirish xatosi: $error';
  }

  @override
  String get refundErrorProductNotFound => 'Tovar topilmadi';

  @override
  String get refundErrorNotAuthenticated =>
      'Foydalanuvchi avtorizatsiya qilinmagan';

  @override
  String refundErrorProcessing(String error) {
    return 'Qaytarish xatosi: $error';
  }

  @override
  String shiftErrorLoadingData(String error) {
    return 'Smena ma\'lumotlarini yuklash xatosi: $error';
  }

  @override
  String shiftErrorOpening(String error) {
    return 'Smenani ochish xatosi: $error';
  }

  @override
  String shiftErrorClosing(String error) {
    return 'Smenani yopish xatosi: $error';
  }

  @override
  String shiftErrorPrinting(String error) {
    return 'Z-hisobotni chop etish xatosi: $error';
  }

  @override
  String get cashOpTypeInvestment => 'Kiritish';

  @override
  String get cashOpTypeExpense => 'Chiqim';

  @override
  String get cashOpTypeDividend => 'Olish';

  @override
  String get supplyNoName => 'Nomsiz';

  @override
  String get supplyNoTitle => 'Nomsiz';

  @override
  String get supplyErrorSupplierNotFound => 'Yetkazib beruvchi topilmadi';

  @override
  String supplyErrorSelectingSupplier(String error) {
    return 'Yetkazib beruvchini tanlash xatosi: $error';
  }

  @override
  String get supplyErrorAccountNotFound => 'Hisob topilmadi';

  @override
  String supplyErrorSelectingAccount(String error) {
    return 'Hisobni tanlash xatosi: $error';
  }

  @override
  String supplyErrorAddingProduct(String error) {
    return 'Tovar qo\'shish xatosi: $error';
  }

  @override
  String get supplyErrorProductNotFound => 'Tovar topilmadi';

  @override
  String get supplyErrorMissingFields =>
      'Barcha majburiy maydonlarni to\'ldiring';

  @override
  String supplyErrorSaving(String error) {
    return 'Saqlash xatosi: $error';
  }

  @override
  String historyErrorLoading(String error) {
    return 'Tarixni yuklash xatosi: $error';
  }

  @override
  String get syncTypeProducts => 'Tovarlar';

  @override
  String get syncTypePrices => 'Narxlar';

  @override
  String get syncTypeCategories => 'Kategoriyalar';

  @override
  String get syncTypeAgents => 'Kontragentlar';

  @override
  String get syncTypeConfig => 'Sozlamalar';

  @override
  String get syncTypeSales => 'Sotuvlar';

  @override
  String get syncTypeRefunds => 'Qaytarishlar';

  @override
  String get syncTypeCashOps => 'Kassa operatsiyalari';

  @override
  String get syncTypeShifts => 'Smenalar';

  @override
  String get syncTypeSupplies => 'Qabul qilishlar';

  @override
  String get syncStepPreparing => 'Tayyorlanmoqda...';

  @override
  String syncStepUploading(String type) {
    return 'Yuklash: $type';
  }

  @override
  String syncStepDownloading(String type) {
    return 'Yuklab olish: $type';
  }

  @override
  String get syncCompleted => 'Sinxronizatsiya yakunlandi';

  @override
  String get loginErrorNoUsers => 'Ro\'yxatdan o\'tgan foydalanuvchilar yo\'q';

  @override
  String loginErrorLoadingData(String error) {
    return 'Ma\'lumotlarni yuklash xatosi: $error';
  }

  @override
  String get loginErrorSelectUser => 'Foydalanuvchini tanlang';

  @override
  String get loginErrorIncompletePin =>
      'PIN-kodni kiriting (kamida 4 ta raqam)';

  @override
  String get loginErrorNoRsaKey =>
      'Xato: RSA kalit sozlanmagan. Administratorga murojaat qiling.';

  @override
  String get loginErrorWrongPin => 'Noto\'g\'ri PIN-kod';

  @override
  String get loginErrorSystemTime =>
      'Tizim vaqti noto\'g\'ri. Sana va vaqt sozlamalarini tekshiring.';

  @override
  String get receiptLabelBin => 'STIR:';

  @override
  String get receiptLabelPhone => 'Tel:';

  @override
  String get receiptLabelReceiptNo => 'Chek №:';

  @override
  String get receiptLabelPosId => 'Kassa:';

  @override
  String get receiptLabelDate => 'Sana:';

  @override
  String get receiptLabelCashier => 'Kassir:';

  @override
  String get receiptLabelTable => 'Stol:';

  @override
  String get receiptLabelWaiter => 'Ofitsiant:';

  @override
  String get receiptLabelGuests => 'Mehmonlar:';

  @override
  String get receiptLabelCustomer => 'Mijoz:';

  @override
  String get receiptLabelSubtotal => 'Oraliq summa:';

  @override
  String get receiptLabelDiscount => 'Chegirma:';

  @override
  String get receiptLabelServiceCharge => 'Servis to\'lovi:';

  @override
  String get receiptLabelTotal => 'JAMI:';

  @override
  String receiptLabelVat(String percent) {
    return 'shu jum. QQS $percent%:';
  }

  @override
  String get receiptLabelCash => 'Naqd:';

  @override
  String get receiptLabelCard => 'Karta:';

  @override
  String get receiptLabelChange => 'Qaytim:';

  @override
  String get receiptLabelCheckReceipt => 'Chekni tekshirish:';

  @override
  String get receiptLabelItemName => 'Nomi';

  @override
  String get receiptLabelQty => 'Miqdori';

  @override
  String get receiptLabelPrice => 'Narxi';

  @override
  String get receiptLabelAmount => 'Summasi';

  @override
  String get receiptLabelItemDiscount => 'Chegirma:';

  @override
  String get receiptLabelFiscalBin => 'STIR:';

  @override
  String get receiptLabelFiscalNo => 'FR:';

  @override
  String get receiptLabelFiscalSign => 'FI:';

  @override
  String get receiptLabelVatCertificate => 'QQS:';

  @override
  String get receiptLabelOfflineMode => '*** OFLAYN ***';

  @override
  String get receiptLabelRefundHeader => '*** QAYTARISH ***';

  @override
  String get receiptLabelRefundNo => 'Qaytarish №:';

  @override
  String get receiptLabelReason => 'Sabab:';

  @override
  String get receiptLabelRefundTotal => 'QAYTARISHGA:';

  @override
  String get receiptLabelZReport => 'Z-HISOBOT';

  @override
  String get receiptLabelShiftClosing => 'SMENA YOPILISHI';

  @override
  String get receiptLabelShiftNo => 'Smena №:';

  @override
  String get receiptLabelShiftOpenTime => 'Ochildi:';

  @override
  String get receiptLabelShiftCloseTime => 'Yopildi:';

  @override
  String get receiptLabelSales => 'SOTUVLAR';

  @override
  String get receiptLabelQuantity => 'Miqdori:';

  @override
  String get receiptLabelCashSales => 'Naqd:';

  @override
  String get receiptLabelCardSales => 'Karta:';

  @override
  String get receiptLabelSalesTotal => 'Jami:';

  @override
  String get receiptLabelRefunds => 'QAYTARISHLAR';

  @override
  String get receiptLabelRefundQty => 'Miqdori:';

  @override
  String get receiptLabelRefundAmount => 'Summasi:';

  @override
  String get receiptLabelCashOperations => 'KASSA OPERATSIYALARI';

  @override
  String get receiptLabelInvestments => 'Kiritishlar:';

  @override
  String get receiptLabelExpenses => 'To\'lovlar:';

  @override
  String get receiptLabelRevenue => 'TUSHUM:';

  @override
  String get receiptLabelCashInDrawer => 'KASSADA:';

  @override
  String get receiptLabelXReport => 'X-HISOBOT';

  @override
  String get receiptLabelType => 'Turi:';

  @override
  String get receiptLabelDescription => 'Tavsif:';

  @override
  String get receiptLabelDebtPayment => 'QARZ TO\'LASH';

  @override
  String get receiptLabelPreviousDebt => 'Qarz edi:';

  @override
  String get receiptLabelPaidAmount => 'TO\'LANGAN:';

  @override
  String get receiptLabelRemainingDebt => 'Qoldiq:';

  @override
  String get receiptLabelTestPrint => 'TEST PRINT';

  @override
  String get receiptLabelThankYou => 'Xaridingiz uchun rahmat!';

  @override
  String get receiptLabelSaleReceipt => 'KASSA CHEKI';

  @override
  String get receiptLabelOfflineHeader => '*** OFLAYN REJIM ***';

  @override
  String get receiptLabelVatCertificateTitle => 'QQS guvohnomasi:';

  @override
  String get fiscalErrorBin12Digits =>
      'STIR 12 ta raqamdan iborat bo\'lishi kerak';

  @override
  String get fiscalErrorBinDigitsOnly =>
      'STIR faqat raqamlardan iborat bo\'lishi kerak';

  @override
  String get fiscalErrorFiscalNoRequired => 'Fiskal raqam majburiy';

  @override
  String get fiscalErrorRnkRequired => 'RNK majburiy';

  @override
  String get fiscalErrorZnkRequired => 'ZNK majburiy';

  @override
  String get fiscalErrorVatSerialRequired => 'QQS guvohnoma seriyasi majburiy';

  @override
  String get fiscalErrorVatNumberRequired => 'QQS guvohnoma raqami majburiy';

  @override
  String get telegramTabPhone => 'Telefon orqali';

  @override
  String get telegramTabQr => 'QR-kod';

  @override
  String get telegramQrAuthTitle => 'QR-kod orqali kirish';

  @override
  String get telegramQrAuthDescription =>
      'Telefondagi Telegram ilovasida QR-kodni skanerlang';

  @override
  String get telegramQrTapToGenerate => 'QR-kod yaratish uchun\nbosing';

  @override
  String get telegramQrHowToScan => 'Qanday skanerlash mumkin:';

  @override
  String get telegramQrStep1 => 'Telefonda Telegram ni oching';

  @override
  String get telegramQrStep2 => 'Sozlamalar -> Qurilmalar bo\'limiga o\'ting';

  @override
  String get telegramQrStep3 => '\"Qurilmani ulash\" ni bosing';

  @override
  String get telegramQrStep4 => 'QR-kodni skanerlang';

  @override
  String get telegramEnterCode => 'Kodni kiriting';

  @override
  String telegramCodeSentTo(String phone) {
    return 'Kod Telegram ga yuborildi\n$phone raqamiga';
  }

  @override
  String get telegramCodeLabel => 'Tasdiqlash kodi';

  @override
  String get telegramPasswordDescription =>
      'Telegram akkauntingiz parolini kiriting';

  @override
  String telegramPasswordHint(String hint) {
    return 'Maslahat: $hint';
  }

  @override
  String get telegramPasswordLabel => 'Parol';

  @override
  String get telegramRegistrationDescription =>
      'Bu raqam bilan akkaunt topilmadi.\nYangi Telegram akkauntini yarating.';

  @override
  String get telegramFirstNameLabel => 'Ism';

  @override
  String get telegramLastNameLabel => 'Familiya (ixtiyoriy)';

  @override
  String get telegramLoadingOrgData => 'Tashkilot ma\'lumotlari yuklanmoqda...';

  @override
  String get telegramSearchingExistingChannels =>
      'Mavjud kanallar qidirilmoqda...';

  @override
  String get telegramFoundChannels =>
      'Tashkilot kanallari topildi.\nKonfiguratsiya yuklanmoqda...';

  @override
  String get telegramCheckingChannels =>
      'Kanallar mavjudligi tekshirilmoqda...';

  @override
  String get telegramOrgDataNotLoaded =>
      'Ma\'lumotlarni yuklab bo\'lmadi.\nTashkilotingiz haqida ma\'lumot kiriting.';

  @override
  String get telegramOrgDataFirstRun =>
      'TelePOS ning birinchi ishga tushirilishi.\nTashkilotingiz haqida ma\'lumot kiriting.';

  @override
  String get telegramStoreNameLabel => 'Do\'kon nomi *';

  @override
  String get telegramStoreNameHint => 'Mening do\'konim';

  @override
  String get telegramBinLabel => 'Tashkilot STIR *';

  @override
  String get telegramAddressLabel => 'Manzil (ixtiyoriy)';

  @override
  String get telegramAddressHint => 'Toshkent sh., Namunaviy ko\'ch., 123';

  @override
  String get telegramPosIdLabel => 'Kassa ID';

  @override
  String get telegramOwnerNameLabel => 'Egasining ismi (ixtiyoriy)';

  @override
  String get telegramImportantNote => 'Muhim';

  @override
  String get telegramOrgDataNote =>
      'Bu ma\'lumotlar tizim kanallarini yaratish va kassalar o\'rtasida sinxronlash uchun ishlatiladi. Boshqa qurilmalarda ma\'lumotlar avtomatik yuklanadi.';

  @override
  String get telegramCreatingChannels => 'Tizim kanallari yaratilmoqda...';

  @override
  String get telegramSettingUpEncryption => 'Shifrlash sozlanmoqda...';

  @override
  String get telegramSettingUp => 'Sozlanmoqda...';

  @override
  String get telegramPleaseWait =>
      'Iltimos, kuting.\nBu biroz vaqt olishi mumkin.';

  @override
  String get telegramSetupDone => 'Sozlash yakunlandi!';

  @override
  String get telegramSetupDoneMessage =>
      'Telegram muvaffaqiyatli sozlandi.\nTizim kanallari yaratildi.';

  @override
  String get telegramTermsNotice =>
      '\"Kodni olish\" tugmasini bosish orqali siz Telegram foydalanish shartlariga rozilik bildirasiz';

  @override
  String get telegramActionsSection => 'Amallar';

  @override
  String get chatNotConfigured => 'Chat sozlanmagan';

  @override
  String get chatCanDeleteOwnOnly =>
      'Faqat o\'z xabarlaringizni o\'chirish mumkin';

  @override
  String get chatMessageDeleted => 'Xabar o\'chirildi';

  @override
  String get chatDeleteFailed => 'Xabarni o\'chirib bo\'lmadi';

  @override
  String get chatTelegramNotLinked => 'Telegram ulanmagan';

  @override
  String get chatLinkInstructions =>
      'Xodimlar chatida identifikatsiya qilish uchun Telegram User ID ni kiriting.';

  @override
  String get chatLinkHowTo =>
      'ID ni qanday bilish mumkin:\n1. Telegram da @userinfobot ni oching\n2. /start bosing\n3. \"Id\" maydonidagi raqamni nusxalang';

  @override
  String get chatLinkFailed =>
      'Ulab bo\'lmadi. Ehtimol bu ID allaqachon ishlatilmoqda.';

  @override
  String get chatPhotoSent => 'Foto yuborildi';

  @override
  String get chatPhotoFailed => 'Fotoni yuborib bo\'lmadi';

  @override
  String get chatPhotoError => 'Fotoni tanlashda xato';

  @override
  String get chatPhotoUnavailableWeb =>
      'Veb-versiyada foto yuborish mavjud emas';

  @override
  String get chatDocSent => 'Hujjat yuborildi';

  @override
  String get chatDocFailed => 'Hujjatni yuborib bo\'lmadi';

  @override
  String get chatDocError => 'Hujjatni tanlashda xato';

  @override
  String get chatDocUnavailableWeb =>
      'Veb-versiyada hujjat yuborish mavjud emas';

  @override
  String get chatDocPathError => 'Fayl yo\'lini olib bo\'lmadi';

  @override
  String get chatDocTooLarge => 'Fayl juda katta (maks. 50 MB)';

  @override
  String get chatLocationSent => 'Joylashuv yuborildi';

  @override
  String get chatLocationFailed => 'Joylashuvni yuborib bo\'lmadi';

  @override
  String get chatLocationError => 'Joylashuvni olishda xato';

  @override
  String get chatLocationUnavailableWeb =>
      'Veb-versiyada geolokatsiya mavjud emas';

  @override
  String get chatLocationDenied => 'Geolokatsiyaga kirish taqiqlangan';

  @override
  String get chatLocationDeniedForever =>
      'Geolokatsiyaga kirish butunlay taqiqlangan. Sozlamalardan o\'zgartiring.';

  @override
  String get chatLocationServiceDisabled => 'Qurilmada geolokatsiyani yoqing';

  @override
  String get syncToUpload => 'Yuklashga';

  @override
  String get syncToDownload => 'Yuklab olishga';

  @override
  String get syncDataTypeCol => 'Ma\'lumot turi';

  @override
  String get syncDirectionCol => 'Yo\'nalish';

  @override
  String get syncPendingCol => 'Kutmoqda';

  @override
  String get syncStatusCol => 'Holat';

  @override
  String get syncProgressCol => 'Jarayon';

  @override
  String get syncUpload => 'Yuklash';

  @override
  String get syncDownload => 'Yuklab olish';

  @override
  String syncPendingCount(int count) {
    return 'Kutmoqda: $count';
  }

  @override
  String get syncInfoTelegram =>
      'Ma\'lumotlar kassalar o\'rtasida Telegram orqali sinxronlanadi. Foydalanuvchilar barcha kassalarga umumiy.';

  @override
  String get syncAutoEnabled => 'Ma\'lumotlar avtomatik sinxronlanadi';

  @override
  String get syncManualOnly => 'Faqat qo\'lda sinxronlash';

  @override
  String syncMinutes(int count) {
    return '$count daq';
  }

  @override
  String get agentBinIin => 'STIR/JSHSHIR';

  @override
  String get agentLastOperation => 'Oxirgi operatsiya';

  @override
  String get agentNoAdditionalInfo => 'Qo\'shimcha ma\'lumot yo\'q';

  @override
  String get agentNoDebt => 'Qarz yo\'q';

  @override
  String agentDeletedWithName(String name) {
    return 'Mijoz \"$name\" o\'chirildi';
  }

  @override
  String agentDeleteError(String error) {
    return 'O\'chirish xatosi: $error';
  }

  @override
  String get agentNewCustomer => 'Yangi mijoz';

  @override
  String get agentTypeCustomer => 'Mijoz';

  @override
  String get agentTypeSupplier => 'Yetkazib beruvchi';

  @override
  String get agentNameHint => 'Mijoz ismini kiriting';

  @override
  String get agentBinHint => '12 raqam';

  @override
  String get agentCustomerFound => 'Mijoz topildi';

  @override
  String get agentDeletedPhoneMsg => 'Bu telefon bilan mijoz o\'chirilgan';

  @override
  String get agentRestoreQuestion => 'Tiklashni xohlaysizmi?';

  @override
  String get agentRestore => 'Tiklash';

  @override
  String get kaspiTerminal => 'Kaspi POS Terminal';

  @override
  String get kaspiIpAddress => 'Terminal IP-manzili';

  @override
  String get kaspiInvalidIp => 'IP-manzil formati noto\'g\'ri';

  @override
  String get kaspiPort => 'Port';

  @override
  String get kaspiTesting => 'Tekshirish...';

  @override
  String get kaspiTest => 'TEST';

  @override
  String get kaspiDisconnected => 'Ulanmagan';

  @override
  String get kaspiConnecting => 'Ulanmoqda...';

  @override
  String get kaspiConnected => 'Aloqa o\'rnatildi';

  @override
  String get kaspiNoConnection => 'Aloqa yo\'q';

  @override
  String get kaspiTestPassed => 'Test muvaffaqiyatli';

  @override
  String get kaspiTestFailed => 'Test muvaffaqiyatsiz';

  @override
  String kaspiLatency(String ms) {
    return 'Kechikish: $ms ms';
  }

  @override
  String kaspiTerminalInfo(String info) {
    return 'Terminal: $info';
  }

  @override
  String get splashSubtitle => 'Kassa tizimi';

  @override
  String get splashInitializing => 'Ishga tushirilmoqda...';

  @override
  String get splashLoadingOrg => 'Tashkilot ma\'lumotlari yuklanmoqda...';

  @override
  String get splashEnterPosKey => 'POS kalitini kiriting';

  @override
  String get splashEnterPosKeyMessage =>
      'Kassani faollashtirish uchun administratordan olingan kalitni kiriting.';

  @override
  String get splashPosKeyHint => 'XXXX-XXXX-XXXX-XXXX';

  @override
  String get splashKeyEmpty => 'Kalit bo\'sh bo\'lishi mumkin emas';

  @override
  String get splashKeyTooShort => 'Kalit juda qisqa';

  @override
  String get splashKeyNotEntered => 'Kalit kiritilmadi';

  @override
  String get splashKeyRequiredMessage =>
      'POS kalitsiz ishlay olmaydi. Ilova yopiladi.';

  @override
  String get splashDataCorrupted => 'Ma\'lumotlar buzilgan';

  @override
  String get splashDataCorruptedMessage =>
      'Ilovaning majburiy ma\'lumotlari yo\'q yoki buzilgan.\n\nAmalni tanlang:';

  @override
  String get splashReconfigure => 'Qayta sozlash';

  @override
  String get splashExit => 'Chiqish';

  @override
  String get splashDatabaseError => 'Ma\'lumotlar bazasi xatosi';

  @override
  String get splashDatabaseErrorMessage =>
      'Ma\'lumotlar bazasi buzilgan yoki mavjud emas.\n\nZahira nusxadan tiklashga yoki kassani qayta sozlashga urinib ko\'rishingiz mumkin.';

  @override
  String get splashRestoreFromBackup => 'Zahira nusxadan tiklash';

  @override
  String get splashSyncSuspended => 'Sinxronizatsiya to\'xtatildi';

  @override
  String get splashSyncSuspendedMessage =>
      'Ma\'lumotlarni sinxronizatsiya qilish vaqtincha to\'xtatildi.\n\nKassa avtonom rejimda ishlaydi. Aloqa tiklanganda ma\'lumotlar sinxronizatsiya qilinadi.';

  @override
  String get splashAuthError =>
      'Avtorizatsiya xatosi\n\nKirish tokeni yaroqsiz yoki muddati tugagan.\nYangi kalit olish uchun administratorga murojaat qiling.';

  @override
  String get splashSupportEnded =>
      'Versiya qo\'llab-quvvatlanmaydi\n\nIlovaning bu versiyasi endi qo\'llab-quvvatlanmaydi.\nIltimos, so\'nggi versiyaga yangilang.';

  @override
  String get generalSettingsTitle => 'Sozlamalar';

  @override
  String get generalSettingsPosInfo => 'Kassa haqida ma\'lumot';

  @override
  String get generalSettingsCashBoxName => 'Kassa nomi';

  @override
  String get generalSettingsCompany => 'Kompaniya';

  @override
  String get generalSettingsIinBin => 'STIR';

  @override
  String get generalSettingsPosId => 'POS ID';

  @override
  String get generalSettingsStoreId => 'Do\'kon ID';

  @override
  String get generalSettingsNotSpecified => 'Ko\'rsatilmagan';

  @override
  String get generalSettingsAppVersion => 'Dastur versiyasi';

  @override
  String get generalSettingsVersion => 'Versiya';

  @override
  String get generalSettingsPlatform => 'Platforma';

  @override
  String get generalSettingsLanguage => 'Interfeys tili';

  @override
  String get generalSettingsTheme => 'Bezatish';

  @override
  String get generalSettingsThemeDesc => 'Yorug‘, to‘q yoki tizimdagidek';

  @override
  String get generalSettingsThemeLight => 'Yorug‘';

  @override
  String get generalSettingsThemeDark => 'To‘q';

  @override
  String get generalSettingsThemeSystem => 'Tizimdagidek';

  @override
  String generalSettingsLanguageChanged(String language) {
    return 'Til $language ga o\'zgartirildi';
  }

  @override
  String get generalSettingsCurrency => 'Valyuta';

  @override
  String get generalSettingsCurrencySymbol => 'Belgi';

  @override
  String get generalSettingsCurrencyCode => 'Kod';

  @override
  String get generalSettingsCountry => 'Davlat';

  @override
  String get generalSettingsAdditional => 'Qo\'shimcha sozlamalar';

  @override
  String get generalSettingsTransport => 'Transport';

  @override
  String get generalSettingsTransportSubtitle =>
      'Ma\'lumotlarni sinxronizatsiya sozlamalari';

  @override
  String get generalSettingsPrinter => 'Printer';

  @override
  String get generalSettingsPrinterSubtitle => 'Chek chop etish sozlamalari';

  @override
  String get generalSettingsPermissions => 'Ruxsatlar';

  @override
  String get generalSettingsPermissionsSubtitle => 'Kassirlar uchun ruxsatlar';

  @override
  String get generalSettingsFiscal => 'Fiskalizatsiya';

  @override
  String get generalSettingsFiscalSubtitle => 'WebKassa, OFD, QQS';

  @override
  String get generalSettingsRestaurant => 'Restoran';

  @override
  String get generalSettingsRestaurantSubtitle =>
      'Stollar, zallar, xizmat rejimi';

  @override
  String get generalSettingsTelegram => 'Telegram';

  @override
  String get generalSettingsTelegramSubtitle => 'Aloqa kanallari va botlar';

  @override
  String get generalSettingsPosInfoDesc => 'Kassa nomi, kompaniya, ID';

  @override
  String get generalSettingsVersionDesc => 'Joriy versiya va platforma';

  @override
  String get generalSettingsLanguageDesc => 'Interfeys tilini tanlash';

  @override
  String get generalSettingsCurrencyDesc => 'Valyuta va mamlakat';

  @override
  String get generalSettingsUpdate => 'Yangilash';

  @override
  String get generalSettingsUpdateSubtitle =>
      'Yangilanishlarni tekshirish va o\'rnatish';

  @override
  String get generalSettingsAppUpdate => 'Ilovani yangilash';

  @override
  String get generalSettingsAppUpdateSubtitle =>
      'Kassa ilovasini yangilash (OS yangilanishi bilan adashtirmang)';

  @override
  String get generalSettingsUpdateDesc => 'Joriy versiya va yangilanishlar';

  @override
  String get settingsUpdateTitle => 'Ilovani yangilash';

  @override
  String get settingsUpdateCurrentVersion => 'Joriy versiya';

  @override
  String get settingsUpdateCheckBtn => 'Yangilanishlarni tekshirish';

  @override
  String get settingsUpdateChecking => 'Yangilanishlar tekshirilmoqda...';

  @override
  String get settingsUpdateUpToDate => 'Oxirgi versiya o\'rnatilgan';

  @override
  String settingsUpdateAvailable(String version) {
    return '$version versiyasi mavjud';
  }

  @override
  String get settingsUpdateDownloadBtn => 'Yangilanishni yuklab olish';

  @override
  String settingsUpdateDownloading(String percent) {
    return 'Yuklanmoqda... $percent%';
  }

  @override
  String get settingsUpdateInstallBtn => 'Yangilanishni o\'rnatish';

  @override
  String get settingsUpdateInstalling => 'O\'rnatilmoqda...';

  @override
  String get settingsUpdateFailed => 'Yangilash xatosi';

  @override
  String get settingsUpdateAutoEnabled => 'Har 3 soatda avtomatik tekshirish';

  @override
  String get settingsUpdateCloseShift => 'Yangilashdan oldin smenani yoping';

  @override
  String get settingsUpdateReleaseNotes => 'Yangiliklar';

  @override
  String get countryKazakhstan => 'Qozog\'iston';

  @override
  String get countryRussia => 'Rossiya';

  @override
  String get countryKyrgyzstan => 'Qirg\'iziston';

  @override
  String get countryUzbekistan => 'O\'zbekiston';

  @override
  String get countryUSA => 'AQSH';

  @override
  String get countryTurkmenistan => 'Turkmaniston';

  @override
  String get permEditPrice => 'Narxni tahrirlash';

  @override
  String get permSellInDebt => 'Qarzga sotish';

  @override
  String get permDiscounts => 'Chegirmalar';

  @override
  String get permCashOperations => 'Kassa operatsiyalari';

  @override
  String get permSendToOfd => 'OFD-ga yuborish';

  @override
  String get permCancelPayment => 'To\'lovni bekor qilish';

  @override
  String get permDeferSale => 'Keyinga qoldirilgan sotuv';

  @override
  String get permShowHistory => 'Tarixni ko\'rsatish';

  @override
  String get printerSettingsSaved => 'Sozlamalar saqlandi';

  @override
  String printerSettingsSaveError(String error) {
    return 'Saqlash xatosi: $error';
  }

  @override
  String get printerSettingsPrinting => 'Chop etilmoqda...';

  @override
  String get printerSettingsTestReceipt => 'TEST CHEK';

  @override
  String get printerSettingsWidth => 'Kengligi:';

  @override
  String printerSettingsWidthValue(int width) {
    return '$width belgi';
  }

  @override
  String get printerSettingsType => 'Turi:';

  @override
  String get printerSettingsAddress => 'Manzil:';

  @override
  String get printerSettingsNotSpecifiedAddr => 'Ko\'rsatilmagan';

  @override
  String get printerSettingsPrinterWorks => 'Printer ishlaydi!';

  @override
  String get printerSettingsPrintSuccess => 'Chop etish muvaffaqiyatli';

  @override
  String get printerSettingsPrintError => 'Chop etish xatosi';

  @override
  String get printerSettingsNotConnected => 'Ulanmagan';

  @override
  String get printerSettingsChecking => 'Tekshirilmoqda...';

  @override
  String get printerSettingsReady => 'Tayyor';

  @override
  String get printerSettingsNoPaper => 'Qog\'oz yo\'q';

  @override
  String get printerSettingsCoverOpen => 'Qopqoq ochiq';

  @override
  String get printerSettingsSave => 'Saqlash';

  @override
  String get printerSettingsConnectionType => 'Ulanish turi';

  @override
  String get printerSettingsPrinterAddress => 'Printer manzili';

  @override
  String get printerSettingsPaperWidth => 'Qog\'oz kengligi';

  @override
  String get printerSettingsTesting => 'Testlash';

  @override
  String printerSettingsStatus(String status) {
    return 'Holat: $status';
  }

  @override
  String get printerSettingsCheck => 'Tekshirish';

  @override
  String get printerSettingsTestCheck => 'Test chek';

  @override
  String get printerSettingsPort => 'Port';

  @override
  String get printerSettingsIpAddress => 'Printerning IP manzili';

  @override
  String get printerSettingsMacAddress => 'MAC manzili yoki nomi';

  @override
  String get printerSettingsPrinterName => 'Printer nomi';

  @override
  String get printerSettingsComPort => 'COM port';

  @override
  String get printerSettingsSerialCom => 'Serial (COM)';

  @override
  String get printerSettingsPaperWidth58 => '58mm (32 belgi)';

  @override
  String get printerSettingsPaperWidth80_42 => '80mm (42 belgi)';

  @override
  String get printerSettingsPaperWidth80_48 => '80mm (48 belgi)';

  @override
  String get fiscalSettingsTitle => 'Fiskalizatsiya';

  @override
  String get fiscalSettingsSaved => 'Sozlamalar saqlandi';

  @override
  String fiscalSettingsSaveError(String error) {
    return 'Saqlash xatosi: $error';
  }

  @override
  String get fiscalSettingsSave => 'Saqlash';

  @override
  String get fiscalSettingsOperator => 'Fiskal operator';

  @override
  String get fiscalSettingsWebkassaSettings => 'WebKassa sozlamalari';

  @override
  String get fiscalSettingsTaxpayerInfo => 'Soliq to\'lovchi ma\'lumotlari';

  @override
  String get fiscalSettingsVatSettings => 'QQS sozlamalari';

  @override
  String get fiscalSettingsWebkassaLabel => 'WebKassa';

  @override
  String get fiscalSettingsWebkassaDesc => 'Bulutli fiskal xizmat';

  @override
  String get fiscalSettingsOfdLabel => 'OFD';

  @override
  String get fiscalSettingsOfdDesc => 'Fiskal ma\'lumotlar operatori';

  @override
  String get fiscalSettingsNoneLabel => 'Fiskalizatsiyasiz';

  @override
  String get fiscalSettingsNoneDesc => 'Cheklar OFD-ga yuborilmaydi';

  @override
  String get fiscalSettingsOfdId => 'OFD ID';

  @override
  String get fiscalSettingsOfdIdHint => 'OFD identifikatori';

  @override
  String get fiscalSettingsOfdName => 'OFD nomi';

  @override
  String get fiscalSettingsOfdNameHint => 'WebKassa / OFD.kz';

  @override
  String get fiscalSettingsOfdHost => 'OFD server manzili';

  @override
  String get fiscalSettingsOfdHostHint => 'https://api.webkassa.kz';

  @override
  String get fiscalSettingsWebkassaActive => 'WebKassa faollashtirildi';

  @override
  String get fiscalSettingsWebkassaInactive => 'WebKassa faollashtirilmagan';

  @override
  String get fiscalSettingsCompanyName => 'Nomi';

  @override
  String get fiscalSettingsCashBox => 'Kassa';

  @override
  String get fiscalSettingsVatPayer => 'QQS to\'lovchi';

  @override
  String get fiscalSettingsVatPayerSubtitle =>
      'Tashkilot QQS to\'lovchisi hisoblanadi (12%)';

  @override
  String get fiscalSettingsPrintVat => 'Chekda QQS chop etish';

  @override
  String get fiscalSettingsPrintVatSubtitle =>
      'Chekda QQS summasini ko\'rsatish';

  @override
  String get fiscalOffsetSection => 'Sertifikatlar va avans';

  @override
  String get fiscalOffsetCertificateSale => 'Sertifikat sotilganda chek';

  @override
  String get fiscalOffsetCertificateSaleSubtitle =>
      'Sovg\'a sertifikati sotilganda fiskal chek berish';

  @override
  String get fiscalOffsetLayout => 'Sertifikat yoki avans bilan to\'lov';

  @override
  String get fiscalOffsetLayoutSubtitle =>
      'Hisobga olish summasi OFD chekiga qanday tushadi';

  @override
  String get fiscalOffsetLayoutDiscount => 'Tovarlarga chegirma sifatida';

  @override
  String get fiscalOffsetLayoutSurchargeOnly =>
      'Faqat qo\'shimcha to\'lovga chek';

  @override
  String get fiscalOffsetPrepaymentReceipt => 'Avans qabul qilinganda chek';

  @override
  String get fiscalOffsetPrepaymentReceiptSubtitle =>
      'Xaridor avans kiritganda fiskal chek berish';

  @override
  String get fiscalOffsetSaveError => 'Sozlamani saqlab bo\'lmadi';

  @override
  String get customerPaymentTender => 'Nima bilan qabul qilindi';

  @override
  String get fiscalSettingsVatRate =>
      'QQS stavkasi: 12% (3/28 formulasi bo\'yicha)';

  @override
  String historyProductUcode(String ucode) {
    return 'Tovar #$ucode';
  }

  @override
  String historyRefundProductId(String id) {
    return 'Qaytarish tovari #$id';
  }

  @override
  String historyAccountId(String id) {
    return 'Hisob #$id';
  }

  @override
  String historyLoadError(String error) {
    return 'Yuklash xatosi: $error';
  }

  @override
  String historyReceiptNo(String number) {
    return 'Chek $number';
  }

  @override
  String get historySyncSynced => 'Sinxr.';

  @override
  String get historySyncPending => 'Kutm.';

  @override
  String get historySyncSending => 'Yub.';

  @override
  String get historySyncDeferred => 'Keyin';

  @override
  String get historySyncInProgress => 'Jarayonda';

  @override
  String get historyClient => 'Mijoz';

  @override
  String get historyFiscalization => 'Fiskalizatsiya';

  @override
  String get historyProducts => 'Tovarlar';

  @override
  String get historyPayment => 'To\'lov';

  @override
  String get historyNoProducts => 'Tovarlar yo\'q';

  @override
  String get historyNoPayments => 'To\'lovlar yo\'q';

  @override
  String historyPrintingReceipt(String number) {
    return 'Chekni chop etish $number...';
  }

  @override
  String get historyReceiptPrinted => 'Chek chop etildi';

  @override
  String get historyPrintError => 'Chop etish xatosi';

  @override
  String get historyOperationType => 'Operatsiya turi';

  @override
  String get historyFilterSales => 'Sotuvlar';

  @override
  String get historyFilterRefunds => 'Qaytarishlar';

  @override
  String get historySearchShort => 'Qidirish...';

  @override
  String get historyFilters => 'Filtrlar';

  @override
  String get historyDateFrom => 'Dan';

  @override
  String get historyDateTo => 'Gacha';

  @override
  String get historyReset => 'Tiklash';

  @override
  String get historyApply => 'Qo\'llash';

  @override
  String get historySearchFull => 'Chek raqami, summa bo\'yicha qidirish...';

  @override
  String get historySyncStatus => 'Sinxronizatsiya holati';

  @override
  String get historyReceiptColumn => 'Chek';

  @override
  String get historySyncSyncedFull => 'Sinxronlangan';

  @override
  String get historySyncPendingFull => 'Sinxronizatsiyani kutmoqda';

  @override
  String get historySyncSendingFull => 'Yuborilmoqda';

  @override
  String get historySyncDeferredFull => 'Keyinga qoldirilgan';

  @override
  String get historySyncInProgressFull => 'Jarayonda';

  @override
  String get historyPaymentCash => 'Naqd';

  @override
  String get historyPaymentCard => 'Karta';

  @override
  String get historyPaymentMixed => 'Aralash';

  @override
  String get historyPaymentBonus => 'Bonuslar';

  @override
  String get historyPaymentDebt => 'Qarzga';

  @override
  String get historyPaymentDiscount => 'Chegirma';

  @override
  String get historyPaymentWithDiscount => 'Chegirmali';

  @override
  String get historyOfdFiscalized => 'Fiskallangan';

  @override
  String get historyOfdError => 'Fiskalizatsiya xatosi';

  @override
  String get historyOfdNotFiscalized => 'Fiskallanmagan';

  @override
  String get historyClearFilters => 'Filtrlarni tozalash';

  @override
  String historyRecordsRange(String start, String end, String total) {
    return 'Yozuvlar $start–$end, jami $total';
  }

  @override
  String get historyFirstPage => 'Birinchi sahifa';

  @override
  String get historyPrevious => 'Oldingi';

  @override
  String get historyNextPage => 'Keyingi';

  @override
  String get historyLastPage => 'Oxirgi sahifa';

  @override
  String historyAmount(String amount) {
    return 'Summa: $amount';
  }

  @override
  String historyDate(String date) {
    return 'Sana: $date';
  }

  @override
  String historyPos(String id) {
    return 'POS: $id';
  }

  @override
  String historyClientName(String name) {
    return 'Mijoz: $name';
  }

  @override
  String get historyFiscalYes => 'Ha';

  @override
  String get historyFiscalNo => 'Yo\'q';

  @override
  String get historyFiscalError => 'Xato';

  @override
  String get shiftPrintZReport => 'Z-hisobotni chop etish';

  @override
  String get shiftZReportQueued =>
      'Z-hisobot chop etish navbatiga qabul qilindi. Qog\'oz hozircha yo\'q: printer imkon topganda chiqadi. Vazifa 30 daqiqa kutadi — uni Sozlamalar → Printer bo\'limida ko\'rish mumkin';

  @override
  String get shiftZReportAlreadyQueued =>
      'Z-hisobot allaqachon chop etishga yuborilgan — u ikkinchi marta chop etilmaydi';

  @override
  String get shiftZReportPrintFailed =>
      'Z-hisobotni chop etishga yuborib bo\'lmadi';

  @override
  String get shiftFinishAllSales => 'Barcha sotuvlarni yakunlang';

  @override
  String get shiftCannotClose => 'Smenani yopish mumkin emas';

  @override
  String get shiftOpeningShift => 'Smenani ochish';

  @override
  String get shiftClosingShift => 'Smenani yopish';

  @override
  String get shiftEnterInitialAmount =>
      'Kassadagi boshlang\'ich summani kiriting:';

  @override
  String get shiftDiscrepancyFound => 'Nomuvofiqlik aniqlandi';

  @override
  String shiftDifferenceAmount(String amount) {
    return 'Farq: $amount';
  }

  @override
  String get shiftConfirmCloseQuestion =>
      'Smenani yopishga ishonchingiz komilmi?';

  @override
  String shiftFixedAmount(String amount) {
    return 'Qayd etiladigan summa: $amount KZT';
  }

  @override
  String get shiftCloseWithDiscrepancy => 'Nomuvofiqlik bilan yopish';

  @override
  String get shiftCashierLabel => 'Kassir';

  @override
  String get shiftUnknown => 'Noma\'lum';

  @override
  String get shiftSystemTotal => 'Tizim summasi';

  @override
  String get shiftEnteredTotal => 'Kiritilgan summa';

  @override
  String get shiftCashOperations => 'Kassa operatsiyalari';

  @override
  String get shiftSalesLabel => 'Sotuvlar';

  @override
  String get shiftSalesTotal => 'Sotuvlar summasi';

  @override
  String get shiftCashSales => 'Naqd';

  @override
  String get shiftCardSales => 'Karta';

  @override
  String get shiftRefundsTotal => 'Qaytarishlar';

  @override
  String get shiftShortage => 'Kamomad';

  @override
  String get shiftSurplus => 'Ortiqcha';

  @override
  String get shiftBalances => 'Mos keladi';

  @override
  String get shiftCloseBlocked => 'Yopish bloklangan';

  @override
  String shiftActiveSalesCount(int count) {
    return 'Faol sotuvlar: $count';
  }

  @override
  String shiftPendingSalesCount(int count) {
    return 'Kutilayotgan sotuvlar: $count';
  }

  @override
  String get shiftFinishSalesBeforeClose =>
      'Smenani yopishdan oldin sotuvlarni yakunlang yoki bekor qiling';

  @override
  String get shiftBillsTab => 'Kupyuralar';

  @override
  String get shiftTotalTab => 'Umumiy summa';

  @override
  String get shiftOperationsTab => 'Operatsiyalar';

  @override
  String get shiftAmountTab => 'Summa';

  @override
  String get shiftBillCount => 'Kupyuralar bo\'yicha hisob';

  @override
  String get shiftDifferenceLabel => 'Farq: ';

  @override
  String get supplySupplierRequired => 'Yetkazib beruvchi *';

  @override
  String get supplyPaymentType => 'To\'lov turi';

  @override
  String get supplyFullPayment => 'To\'liq to\'lov';

  @override
  String get supplyAccountDebit => 'Hisobdan yechish';

  @override
  String get supplyConsignment => 'Konsignatsiya';

  @override
  String get supplyDeferredPayment => 'Kechiktirilgan to\'lov';

  @override
  String get supplyPaymentAccountRequired => 'To\'lov hisobi *';

  @override
  String get supplyAddProduct => 'Tovar qo\'shish';

  @override
  String get supplyBarcodeOrSku => 'Shtrixkod yoki artikul';

  @override
  String supplyProductsCount(int count) {
    return 'Tovarlar ($count)';
  }

  @override
  String supplyAmountValue(String amount) {
    return 'Summa: $amount';
  }

  @override
  String get supplyProductNotFound => 'Tovar topilmadi';

  @override
  String get supplyInvalidQuantity => 'To\'g\'ri miqdorni kiriting';

  @override
  String get supplySelectSupplierTitle => 'Yetkazib beruvchini tanlang';

  @override
  String get supplySuppliersNotFound => 'Yetkazib beruvchilar topilmadi';

  @override
  String get supplySelectAccountTitle => 'Hisobni tanlang';

  @override
  String get supplyAccountsNotFound => 'Hisoblar topilmadi';

  @override
  String supplyAccountBalance(String amount) {
    return 'Balans: $amount';
  }

  @override
  String supplyProductNumber(String number) {
    return 'Tovar #$number';
  }

  @override
  String supplyProductCountLabel(int count) {
    return 'Tovarlar: $count';
  }

  @override
  String supplyTotalLabel(String amount) {
    return 'Jami: $amount';
  }

  @override
  String supplySavedSuccess(int count, String amount) {
    return 'Qabul qilish saqlandi. Tovarlar: $count, summa: $amount';
  }

  @override
  String get supplyCancelConfirm => 'Qabul qilishni bekor qilish kerakmi?';

  @override
  String get supplyCancelMessage =>
      'Barcha kiritilgan ma\'lumotlar yo\'qoladi.';

  @override
  String get supplyYesCancel => 'Ha, bekor qilish';

  @override
  String get supplySearchProduct => 'Tovar qidirish...';

  @override
  String get supplyAddProductsHint => 'Qabul qilishga tovarlarni qo\'shing';

  @override
  String get supplyScanOrSearch => 'Shtrixkodni skanerlang yoki tovarni toping';

  @override
  String get refundTotalAmount => 'Qaytarish summasi';

  @override
  String get refundPosLabel => 'Kassa';

  @override
  String refundSelectedOfTotal(String selected, String total) {
    return '$selected / $total';
  }

  @override
  String get refundTotalProducts => 'Barcha tovarlar';

  @override
  String get refundToReturn => 'QAYTARISHGA';

  @override
  String get refundToReturnLabel => 'Qaytarishga:';

  @override
  String get refundAction => 'QAYTARISH';

  @override
  String refundSelectedItemsShort(String selected, String total) {
    return '$selected / $total poz.';
  }

  @override
  String get refundColumnName => 'Nomi';

  @override
  String get refundColumnQty => 'Miqdori';

  @override
  String get refundEmptyHint =>
      'Chekni yuklang yoki tovarlarni qo\'lda qo\'shing';

  @override
  String get refundNoItemsShort => 'Tovarlar yo\'q';

  @override
  String get refundEmptyHintShort =>
      'Chekni yuklang yoki\ntovarlarni qo\'shing';

  @override
  String refundSelectedCount(String count) {
    return 'Tanlangan pozitsiyalar: $count';
  }

  @override
  String refundAmountValue(String amount) {
    return 'Qaytarish summasi: $amount';
  }

  @override
  String get refundSuccess => 'Qaytarish muvaffaqiyatli bajarildi';

  @override
  String get paymentAmountDue => 'To\'lashga';

  @override
  String get paymentTotalDue => 'Jami to\'lashga';

  @override
  String get paymentCashLabel => 'Naqd pul bilan';

  @override
  String get paymentReceived => 'Qabul qilindi';

  @override
  String get paymentRemainingLabel => 'Qoldi';

  @override
  String paymentCardAmount(String amount) {
    return 'Karta bilan to\'lov $amount summaga';
  }

  @override
  String get paymentLoyaltyProgram => 'Sodiqlik dasturi';

  @override
  String get paymentPhoneNumber => 'Telefon raqami';

  @override
  String get paymentAvailableBonus => 'Mavjud bonuslar:';

  @override
  String get paymentUseBonuses => 'Bonuslardan foydalanish';

  @override
  String paymentBonusToDeduct(String amount) {
    return 'Hisobdan chiqarish: $amount bonus';
  }

  @override
  String get paymentSuccessMessage => 'To\'lov muvaffaqiyatli';

  @override
  String get paymentRefundButton => 'QAYTARISH';

  @override
  String get paymentPayButton => 'TO\'LASH';

  @override
  String get syncWidgetRetry => 'Qayta urinish';

  @override
  String syncWidgetLastSync(String time) {
    return 'Oxirgi sinxronizatsiya: $time';
  }

  @override
  String syncWidgetRecordsCount(int count) {
    return '$count yozuv';
  }

  @override
  String get syncWidgetWaiting => 'Kutmoqda';

  @override
  String get syncWidgetSynced => 'Sinxronlangan';

  @override
  String get syncWidgetJustNow => 'hozirgina';

  @override
  String syncWidgetMinutesAgo(int minutes) {
    return '$minutes daq. oldin';
  }

  @override
  String syncWidgetHoursAgo(int hours) {
    return '$hours soat oldin';
  }

  @override
  String syncWidgetDaysAgo(int days) {
    return '$days kun oldin';
  }

  @override
  String get syncWidgetConnecting => 'Serverga ulanmoqda...';

  @override
  String get syncWidgetSyncingProducts => 'Tovarlar sinxronlanmoqda...';

  @override
  String get syncWidgetSyncingSales => 'Sotuvlar sinxronlanmoqda...';

  @override
  String get syncWidgetSyncingAgents => 'Kontragentlar sinxronlanmoqda...';

  @override
  String get syncWidgetSyncingPrices => 'Narxlar sinxronlanmoqda...';

  @override
  String get syncWidgetFinishing => 'Yakunlanmoqda...';

  @override
  String get updateDialogUpdating => 'Yangilanmoqda...';

  @override
  String get updateDialogAvailable => 'Yangilanish mavjud';

  @override
  String updateDialogAutoUpdate(int seconds) {
    return 'Avtomatik yangilash $seconds sek. dan keyin';
  }

  @override
  String get updateDialogUpdateNow => 'Hozir yangilash';

  @override
  String get updateDialogLater => 'Keyinroq';

  @override
  String get updateDialogSkip => 'O\'tkazib yuborish';

  @override
  String get updateDialogUpdate => 'Yangilash';

  @override
  String storeUpdateVersion(String version) {
    return 'Versiya $version';
  }

  @override
  String storeUpdateNewVersionAvailable(String storeName) {
    return 'Ilovaning yangi versiyasi $storeName da mavjud.';
  }

  @override
  String get storeUpdateWhatsNew => 'Yangiliklar:';

  @override
  String get storeUpdateRequired => 'Bu majburiy yangilanish';

  @override
  String storeUpdateGoTo(String storeName) {
    return '$storeName ga o\'tish';
  }

  @override
  String get storeUpdateButton => 'YANGILASH';

  @override
  String get storeUpdateDownloaded => 'Yangilanish yuklandi';

  @override
  String get storeUpdateReadyToInstall =>
      'Yangilanish yuklandi va o\'rnatishga tayyor.\nHozir o\'rnatish kerakmi? Ilova qayta ishga tushiriladi.';

  @override
  String get storeUpdateInstall => 'O\'RNATISH';

  @override
  String get storeUpdateDownloading => 'Yangilanish yuklanmoqda...';

  @override
  String get storeUpdateReadyShort => 'Yangilanish o\'rnatishga tayyor';

  @override
  String get versionConflictTitle => 'Versiyalar ziddiyati';

  @override
  String get versionConflictDescription =>
      'Ilova versiyalarining ziddiyati aniqlandi.';

  @override
  String get versionConflictCurrent => 'Joriy versiya';

  @override
  String get versionConflictFound => 'Topilgan versiya';

  @override
  String get versionConflictChooseAction => 'Amalni tanlang:';

  @override
  String get versionConflictOpenFolder => 'Papkada ochish';

  @override
  String get versionConflictPreviousVersion => 'Oldingi versiya';

  @override
  String get versionConflictContinue => 'Davom etish';

  @override
  String get restoreLoadingBackups => 'Bekaplar yuklanmoqda...';

  @override
  String get restoreSearchingBackups => 'Bekaplari qidirilmoqda...';

  @override
  String restoreLoadError(String error) {
    return 'Yuklash xatosi: $error';
  }

  @override
  String get restoreRestoring => 'Tiklanmoqda...';

  @override
  String get restoreRestoreError => 'Tiklash xatosi';

  @override
  String get restoreRestoreFailed => 'Bekapdan tiklash amalga oshmadi';

  @override
  String get restoreTitle => 'Tiklash';

  @override
  String get restoreChooseMethod => 'Sozlash usulini tanlang';

  @override
  String get restoreSetupNewPos => 'Yangi kassani sozlash';

  @override
  String get restoreNoBackups => 'Bekaplar topilmadi';

  @override
  String get restoreSetupAsNew => 'Kassani yangi qilib sozlang';

  @override
  String get restoreFoundBackups => 'Topilgan bekaplar:';

  @override
  String get agentSearchByNameOrPhone =>
      'Ism yoki telefon bo\'yicha qidirish...';

  @override
  String get agentOnlyWithDebt => 'Faqat qarzi bilan';

  @override
  String get agentTypeTooltip => 'Turi';

  @override
  String agentBinLabel(String bin) {
    return 'STIR: $bin';
  }

  @override
  String agentSelectedMessage(String name) {
    return 'Tanlandi: $name';
  }

  @override
  String agentFoundCount(int count) {
    return 'Topildi: $count';
  }

  @override
  String get agentEnterNameOrPhoneToSearch =>
      'Qidirish uchun ism yoki telefonni kiriting';

  @override
  String get agentNotFound => 'Mijozlar topilmadi';

  @override
  String get agentSearchClients => 'Mijozlarni qidirish';

  @override
  String get agentNotFoundShort => 'Topilmadi';

  @override
  String get agentEnterNameOrPhone => 'Ism yoki telefonni kiriting';

  @override
  String get agentEnterCustomerName => 'Mijoz ismini kiriting';

  @override
  String get agentDeletedCustomerPhone =>
      'Ushbu telefon bilan mijoz o\'chirilgan';

  @override
  String get agentWantRestore => 'Tiklashni xohlaysizmi?';

  @override
  String get agentDeleteCustomerTitle => 'Mijozni o\'chirishmi?';

  @override
  String agentDeleteConfirmMessage(String name) {
    return '\"$name\" o\'chirishga ishonchingiz kommi?';
  }

  @override
  String agentCustomerDeleted(String name) {
    return 'Mijoz \"$name\" o\'chirildi';
  }

  @override
  String get cashOpTitle => 'Kassa operatsiyasi';

  @override
  String get cashOpComment => 'Izoh';

  @override
  String get cashOpCommentRequired => 'Izoh *';

  @override
  String get cashOpCommentHint => 'Izoh kiriting...';

  @override
  String cashOpError(String error) {
    return 'Xato: $error';
  }

  @override
  String get cashOpOperationType => 'Operatsiya turi';

  @override
  String get cashOpExpense => 'Xarajat';

  @override
  String get cashOpDividend => 'Yechib olish';

  @override
  String get saleReceiptTotal => 'Chek bo\'yicha jami';

  @override
  String get salePay => 'TO\'LASH';

  @override
  String get saleTotalColon => 'Jami:';

  @override
  String salePositionsAndQuantity(int count, String qty) {
    return '$count poz. / $qty dona';
  }

  @override
  String get saleWholesale => 'ULGURJI';

  @override
  String get saleRetail => 'Chakana';

  @override
  String get syncPreparing => 'Tayyorlanmoqda...';

  @override
  String refundRefused(String reason) {
    return 'Qaytarish bajarilmadi: $reason';
  }

  @override
  String errorSaveFailed(String details) {
    return 'Saqlash xatosi: $details';
  }

  @override
  String get errorSaveFailedGeneric => 'Saqlash xatosi';

  @override
  String errorLoadFailed(String details) {
    return 'Ma\'lumotlarni yuklash xatosi: $details';
  }

  @override
  String get errorLoadFailedGeneric => 'Ma\'lumotlarni yuklash xatosi';

  @override
  String errorSearchFailed(String details) {
    return 'Qidiruv xatosi: $details';
  }

  @override
  String get errorSearchFailedGeneric => 'Qidiruv xatosi';

  @override
  String get errorUnknownGeneric => 'Noma\'lum xato';

  @override
  String errorRefusalUnknownCode(String code) {
    return 'noma\'lum sabab (kodi $code)';
  }

  @override
  String get errorReasonUnknown => 'noma\'lum sabab';

  @override
  String get errorFillRequired => 'Barcha majburiy maydonlarni to\'ldiring';

  @override
  String get errorNoUsers => 'Ro\'yxatdan o\'tgan foydalanuvchilar yo\'q';

  @override
  String get errorSelectUser => 'Foydalanuvchini tanlang';

  @override
  String get errorPinTooShort => 'PIN kodni kiriting (kamida 4 raqam)';

  @override
  String get errorRsaNotConfigured =>
      'Xato: RSA kalit sozlanmagan. Administratorga murojaat qiling.';

  @override
  String get errorWrongPin => 'Noto\'g\'ri PIN kod';

  @override
  String get errorAmbiguousPin =>
      'Bu PIN kod bir nechta kassirda bir xil. Ismingizni tanlang va shu orqali kiring.';

  @override
  String get errorNoPinSet =>
      'Bu kassir uchun PIN kod o\'rnatilmagan. Uni o\'rnatish uchun administratorga murojaat qiling.';

  @override
  String get errorWalkUpDisabled =>
      'Bu nuqtada ismni tanlamasdan kirish o\'chirilgan. Ro\'yxatdan ismingizni tanlang.';

  @override
  String get errorCredentialUnreadable =>
      'PIN kod yozuvi buzilgan. Administratorga murojaat qiling — qayta kiritish yordam bermaydi.';

  @override
  String get errorAuthUnknown =>
      'Kassa kirish urinishiga javob bera olmadi. Qayta urinib ko\'ring.';

  @override
  String get errorTillNotConfigured =>
      'Kassa hali sozlanmagan — sozlash ustasi tugamaguncha kirish mumkin emas.';

  @override
  String get errorTillNotConfiguredSale =>
      'Kassa sozlanmagan — chekni boshlab bo\'lmaydi. Administratorga murojaat qiling: sozlash ustasidan o\'tish kerak.';

  @override
  String get errorNotAllowed =>
      'Bu amal uchun huquq yetarli emas. Administratorga murojaat qiling.';

  @override
  String get errorNoSaleModule =>
      'Bu kassa chek yurita olmaydi: sotuv moduli yig\'ilmagan. Administratorga murojaat qiling.';

  @override
  String get errorTerminalInBody =>
      'Terminal kassaga noto\'g\'ri murojaat qildi. Ish o\'rnidagi ilovani yangilang.';

  @override
  String get errorWholesaleInStart =>
      'Ulgurji chek bunday boshlanmaydi. Oddiy chek boshlab, ulgurjini alohida tugma bilan yoqing.';

  @override
  String get errorTerminalLimitReached =>
      'Bu kassada terminallarning maksimal soni ro\'yxatga olingan. Joy bo\'shatish uchun administratorga murojaat qiling.';

  @override
  String get errorPairingCodeInvalid =>
      'Bog\'lash kodi mos kelmadi — muddati o\'tgan, allaqachon ishlatilgan yoki noto\'g\'ri kiritilgan. Kassadan yangi kod oling.';

  @override
  String get errorTerminalSecretInvalid =>
      'Bu qurilmaning bog\'lanishi endi amal qilmaydi — terminal kassadan o\'chirilgan bo\'lishi mumkin. Yangi bog\'lash kodini kiriting.';

  @override
  String get errorSessionExpired => 'Sessiya muddati tugadi — qaytadan kiring.';

  @override
  String get errorSessionEnded => 'Sessiyani kassa tugatdi — qaytadan kiring.';

  @override
  String get errorSaleNotInitialized => 'Sotuv ishga tushirilmagan';

  @override
  String get errorReceiptEmpty => 'Chek bo\'sh';

  @override
  String get errorDeferredNotFound => 'Keyinga qoldirilgan chek topilmadi';

  @override
  String get errorCartStale =>
      'Siz terayotganingizda chek o\'zgardi. Ekran yangilandi — oxirgi amalni takrorlang.';

  @override
  String get errorCartWrongReceipt =>
      'Bu chek endi ishda emas. Yangi chek boshlang yoki keyinga qoldirilganini oching.';

  @override
  String get errorCartNotStarted =>
      'Chek hali boshlanmagan. Yangi chek boshlang yoki keyinga qoldirilganini oching.';

  @override
  String get errorLineNotFound =>
      'Bu qator chekda yo\'q. Chekni yangilab, qayta urinib ko\'ring.';

  @override
  String get errorInvalidAmount =>
      'Yaroqsiz qiymat. Summa manfiy bo\'lolmaydi, chegirma esa 100% dan oshmasligi kerak.';

  @override
  String get errorDeferredTaken =>
      'Bu keyinga qoldirilgan chekni boshqa ish o\'rni olib qo\'ygan.';

  @override
  String get errorCartNotEmpty =>
      'Avval joriy chekni yakunlang yoki keyinga qoldiring — uning ustiga boshqasini ochib bo\'lmaydi.';

  @override
  String get errorSaleNotStarted =>
      'Kassa chekni boshlay olmadi va sababini aytmadi. Qayta urinib ko\'ring.';

  @override
  String get errorShiftNotOpen => 'Smena ochilmagan. Smenani kassada oching.';

  @override
  String get errorCardTerminalMisconfigured =>
      'Ushbu ish joyining to\'lov terminali noto\'g\'ri sozlangan. Uskuna sozlamalaridagi bog\'lanishni tekshiring.';

  @override
  String errorReceiptNotFound(String receiptNo) {
    return '#$receiptNo chek topilmadi';
  }

  @override
  String get errorReceiptNotFoundGeneric => 'Chek topilmadi';

  @override
  String get errorNotAuthorized => 'Foydalanuvchi avtorizatsiyalanmagan';

  @override
  String get errorSupplierNotFound => 'Yetkazib beruvchi topilmadi';

  @override
  String get errorAccountNotFound => 'Hisob topilmadi';

  @override
  String errorProductNotFound(String details) {
    return 'Mahsulot topilmadi: $details';
  }

  @override
  String get errorProductNotFoundGeneric => 'Mahsulot topilmadi';

  @override
  String get errorNameRequired => 'Ism majburiy';

  @override
  String get errorNameTooShort => 'Kamida 2 belgi';

  @override
  String get errorPhoneInvalid => 'Telefon formati noto\'g\'ri';

  @override
  String get errorBinInvalid => 'BIN/IIN 12 raqamdan iborat bo\'lishi kerak';

  @override
  String get errorPhoneExists => 'Ushbu telefon raqamli mijoz mavjud';

  @override
  String errorShiftOpenFailed(String details) {
    return 'Smenani ochish xatosi: $details';
  }

  @override
  String get errorShiftOpenFailedGeneric => 'Smenani ochish xatosi';

  @override
  String errorShiftCloseFailed(String details) {
    return 'Smenani yopish xatosi: $details';
  }

  @override
  String get errorShiftCloseFailedGeneric => 'Smenani yopish xatosi';

  @override
  String errorShiftLoadFailed(String details) {
    return 'Smena ma\'lumotlarini yuklash xatosi: $details';
  }

  @override
  String get errorShiftLoadFailedGeneric =>
      'Smena ma\'lumotlarini yuklash xatosi';

  @override
  String get errorPaymentConfig =>
      'To\'lovni yaratib bo\'lmadi. Hisob sozlamalarini tekshiring.';

  @override
  String get errorSaleSaveFailed => 'Sotuvni saqlash xatosi';

  @override
  String get errorInventoryCannotComplete => 'Yakunlab bo\'lmaydi';

  @override
  String get errorNoProducts => 'Hisobdan chiqarish uchun mahsulotlar yo\'q';

  @override
  String get errorSelectCountry => 'Mamlakatni tanlang';

  @override
  String get errorEnterOrgName => 'Tashkilot nomini kiriting';

  @override
  String errorEnterTaxId(String label) {
    return '$label kiriting';
  }

  @override
  String get errorEnterTaxIdGeneric => 'Soliq raqamini kiriting';

  @override
  String errorTaxIdLength(String info) {
    return '$info';
  }

  @override
  String get errorTaxIdLengthGeneric => 'Soliq raqami uzunligi noto\'g\'ri';

  @override
  String get errorEnterPosName => 'Kassa nomini kiriting';

  @override
  String get errorFillWebkassa => 'WebKassa barcha maydonlarini to\'ldiring';

  @override
  String get errorFillOfd => 'OFD barcha maydonlarini to\'ldiring';

  @override
  String get errorEnterKaspiIp => 'Kaspi terminali IP-manzilini kiriting';

  @override
  String get errorEnterAdminName => 'Administrator ismini kiriting';

  @override
  String get errorAdminPinShort =>
      'Administrator PIN kodi kamida 4 raqamdan iborat bo\'lishi kerak';

  @override
  String get errorSellerPinShort =>
      'Sotuvchi PIN kodi kamida 4 raqamdan iborat bo\'lishi kerak';

  @override
  String errorCheckFailed(String details) {
    return 'Tekshirish xatosi: $details';
  }

  @override
  String get errorCheckFailedGeneric => 'Tekshirish xatosi';

  @override
  String get errorTelegramNotInitialized =>
      'TelegramInitializer ishga tushirilmagan';

  @override
  String get errorTelegramAuthNotInitialized =>
      'TelegramAuthService ishga tushirilmagan';

  @override
  String errorPhoneSendFailed(String details) {
    return 'Raqamni yuborish xatosi: $details';
  }

  @override
  String get errorPhoneSendFailedGeneric => 'Raqamni yuborish xatosi';

  @override
  String errorQrAuthFailed(String details) {
    return 'QR avtorizatsiya xatosi: $details';
  }

  @override
  String get errorQrAuthFailedGeneric => 'QR avtorizatsiya xatosi';

  @override
  String errorWrongCode(String details) {
    return 'Noto\'g\'ri kod: $details';
  }

  @override
  String get errorWrongCodeGeneric => 'Noto\'g\'ri kod';

  @override
  String errorWrongPassword(String details) {
    return 'Noto\'g\'ri parol: $details';
  }

  @override
  String get errorWrongPasswordGeneric => 'Noto\'g\'ri parol';

  @override
  String errorRegistrationFailed(String details) {
    return 'Ro\'yxatdan o\'tish xatosi: $details';
  }

  @override
  String get errorRegistrationFailedGeneric => 'Ro\'yxatdan o\'tish xatosi';

  @override
  String errorChannelSearchFailed(String details) {
    return 'Kanallarni qidirish xatosi: $details';
  }

  @override
  String get errorChannelSearchFailedGeneric => 'Kanallarni qidirish xatosi';

  @override
  String errorChannelConnectFailed(String details) {
    return 'Kanallarga ulanish xatosi: $details';
  }

  @override
  String get errorChannelConnectFailedGeneric => 'Kanallarga ulanish xatosi';

  @override
  String errorChannelCreateFailed(String details) {
    return 'Kanallarni yaratish xatosi: $details';
  }

  @override
  String get errorChannelCreateFailedGeneric => 'Kanallarni yaratish xatosi';

  @override
  String get errorFillClientData => 'Mijoz ma\'lumotlarini to\'ldiring';

  @override
  String get shiftCashInvestments => 'Kirimlar';

  @override
  String get shiftCashExpenses => 'Chiqimlar';

  @override
  String get shiftCashDividends => 'Olib chiqishlar';

  @override
  String get shiftNoCashOps => 'Kassa operatsiyalari yo\'q';

  @override
  String get shiftNoCashOpsDescription =>
      'Kirimlar, chiqimlar va olib chiqishlar\nbu yerda ko\'rsatiladi';

  @override
  String shiftMoreItems(int count) {
    return '+$count yana';
  }

  @override
  String get shiftEqualsSystem => '= Tizim';

  @override
  String get shiftBillsTotal => 'Kupyuralar bo\'yicha:';

  @override
  String get receiptInputTitle => 'Chekni qidirish';

  @override
  String get receiptInputNumber => 'Chek raqami';

  @override
  String get receiptInputNumberHint => 'Masalan: 12345';

  @override
  String get receiptInputPos => 'Kassa';

  @override
  String get receiptInputInvalid => 'To\'g\'ri chek raqamini kiriting';

  @override
  String get receiptInputFind => 'Topish';

  @override
  String get paymentDenominations => 'Nominallar';

  @override
  String get paymentExactAmount => 'Qaytarimsiz';

  @override
  String get paymentNumpad => 'Klaviatura';

  @override
  String get paymentIinLabel => 'STIR (ixtiyoriy)';

  @override
  String get paymentIinInvalid => 'Noto\'g\'ri STIR';

  @override
  String get paymentIinHint =>
      'STIR — jismoniy shaxslar uchun, STIR — yuridik shaxslar uchun';

  @override
  String get paymentIinShort => 'STIR';

  @override
  String get paymentTypeCash => 'Naqd';

  @override
  String get paymentTypeCard => 'Naqdsiz';

  @override
  String get paymentTypeMixed => 'Aralash';

  @override
  String get paymentAccount => 'Hisob';

  @override
  String get authNoUsers => 'Ro\'yxatdan o\'tgan foydalanuvchilar yo\'q';

  @override
  String get authNoPin => 'PINsiz';

  @override
  String get authSelectUser => 'Foydalanuvchini tanlang';

  @override
  String get authNoUsersShort => 'Foydalanuvchilar yo\'q';

  @override
  String get authEnterPin => 'PIN-kodni kiriting';

  @override
  String updateVersion(String version) {
    return 'Versiya $version';
  }

  @override
  String get updateWhatsNew => 'Yangiliklar';

  @override
  String get updateFixedIssues => 'Tuzatildi';

  @override
  String get updateSize => 'O\'lchami';

  @override
  String get updateDate => 'Sana';

  @override
  String get updateMandatory => 'Bu majburiy yangilanish';

  @override
  String updateLaterCountdown(int countdown) {
    return 'Keyinroq ($countdown)';
  }

  @override
  String get updateDownloading => 'Yangilanish yuklanmoqda';

  @override
  String get updateDownloadingFile => 'Yangilanish fayli yuklanmoqda...';

  @override
  String get updatePosNow => 'KASSANI YANGILASH';

  @override
  String get serviceAddNote => 'Belgi qo\'shish';

  @override
  String get serviceClientLookup => 'Mijozni qidirish';

  @override
  String serviceOrderDetail(int orderId) {
    return 'Buyurtma-naryad tafsilotlari #$orderId';
  }

  @override
  String get paymentDefaultLabel => 'Standart';

  @override
  String get currencySymbol => '₸';

  @override
  String get serviceIntakeTitle => 'Buyurtma qabul qilish';

  @override
  String get serviceIntakeClient => 'Mijoz';

  @override
  String get serviceIntakeDevice => 'Qurilma / Buyum';

  @override
  String get serviceIntakeServices => 'Xizmatlar';

  @override
  String get serviceIntakeDelivery => 'Yetkazib berish';

  @override
  String get serviceIntakePickup => 'Mijozdan olish';

  @override
  String get serviceIntakeSave => 'Saqlash';

  @override
  String get serviceIntakeCancel => 'Bekor qilish';

  @override
  String get serviceQueueTitle => 'Buyurtma-naryadlar';

  @override
  String get serviceQueueEmpty => 'Buyurtma-naryadlar yo\'q';

  @override
  String get serviceQueueSearch => 'Raqam, mijoz, qurilma bo\'yicha qidirish';

  @override
  String get serviceDetailTitle => 'Buyurtma tafsilotlari';

  @override
  String get serviceDetailInfo => 'Ma\'lumot';

  @override
  String get serviceDetailTimeline => 'Ishlar';

  @override
  String get serviceDetailCost => 'Narx';

  @override
  String get serviceDetailActions => 'Harakatlar';

  @override
  String get serviceStatusIntake => 'Qabul';

  @override
  String get serviceStatusInProgress => 'Ishda';

  @override
  String get serviceStatusCompleted => 'Tayyor';

  @override
  String get serviceStatusClosed => 'Yopiq';

  @override
  String get serviceStatusCancelled => 'Bekor qilingan';

  @override
  String get serviceMarkDiagnostic => 'Diagnostika';

  @override
  String get serviceMarkReplacement => 'Ehtiyot qism almashtirish';

  @override
  String get serviceMarkRepair => 'Ta\'mirlash';

  @override
  String get serviceMarkTesting => 'Sinovdan o\'tkazish';

  @override
  String get serviceMarkOther => 'Boshqa';

  @override
  String get serviceAddMark => 'Ish qo\'shish';

  @override
  String get serviceDeleteMark => 'Belgini o\'chirish';

  @override
  String get serviceMarkDescription => 'Tavsif';

  @override
  String get serviceMarkType => 'Ish turi';

  @override
  String get serviceMarkCost => 'Narx';

  @override
  String get serviceMarkNote => 'Izoh';

  @override
  String get serviceCatalogTitle => 'Xizmatlar katalogi';

  @override
  String get serviceCatalogAdd => 'Xizmat qo\'shish';

  @override
  String get serviceCatalogDuration => 'daq';

  @override
  String get serviceCatalogWarranty => 'Kafolat (kun)';

  @override
  String get serviceCatalogRequiresDevice => 'Qurilma kerak';

  @override
  String get serviceClientNew => 'Yangi mijoz';

  @override
  String get serviceClientPhone => 'Telefon';

  @override
  String get serviceClientName => 'Ism';

  @override
  String get serviceClientAddress => 'Manzil';

  @override
  String get serviceAssignTechnician => 'Usta tayinlash';

  @override
  String get serviceReassignTechnician => 'Ustani qayta tayinlash';

  @override
  String serviceTechnicianAssigned(String name) {
    return 'Usta tayinlandi: $name';
  }

  @override
  String get serviceTechnicianSelect => 'Ustani tanlang';

  @override
  String get servicePrepayment => 'Oldindan to\'lov';

  @override
  String get servicePrepaymentAmount => 'Oldindan to\'lov summasi';

  @override
  String get serviceEstimatedDate => 'Kutilgan sana';

  @override
  String get serviceEstimatedAmount => 'Summa';

  @override
  String get servicePrintLabel => 'QR-yorliq';

  @override
  String get servicePrintReceipt => 'Chek chiqarish';

  @override
  String get serviceProgressConfirm => 'Ishni boshlash';

  @override
  String get serviceCancelConfirm => 'Bekor qilish';

  @override
  String get serviceTotalCost => 'Ish narxi';

  @override
  String get servicePrepaid => 'Oldindan to\'lov';

  @override
  String get serviceRemaining => 'To\'lashga';

  @override
  String get serviceDeliveryAddress => 'Yetkazib berish manzili';

  @override
  String get serviceNeedsPickup => 'Mijozdan olish';

  @override
  String get serviceNeedsDelivery => 'Mijozga yetkazish';

  @override
  String serviceQrFormat(Object id, Object number) {
    return 'TELEPOS:SO:$id:$number';
  }

  @override
  String get serviceOrderCreated => 'Yangi buyurtma';

  @override
  String get serviceOrderUpdated => 'Tahrirlash';

  @override
  String get serviceNoOrders => 'Ma\'lumot yo\'q';

  @override
  String get serviceFilterAll => 'Hammasi';

  @override
  String get navCatalog => 'Katalog';

  @override
  String get catalogTitle => 'Tovarlar katalogi';

  @override
  String get catalogSearch => 'Qidirish';

  @override
  String get catalogSearchHint => 'Nomi yoki shtrixkod';

  @override
  String get catalogFilterAll => 'Hammasi';

  @override
  String get catalogFilterProducts => 'Tovarlar';

  @override
  String get catalogFilterWeighted => 'Og\'irlik';

  @override
  String get catalogFilterServices => 'Xizmatlar';

  @override
  String get catalogFilterPackages => 'To\'plamlar';

  @override
  String get catalogAddProduct => 'Tovar qo\'shish';

  @override
  String get catalogEditProduct => 'Tovarni tahrirlash';

  @override
  String get catalogDeleteProduct => 'Tovarni o\'chirish';

  @override
  String get catalogRestoreProduct => 'Tovarni tiklash';

  @override
  String get catalogProductName => 'Nomi';

  @override
  String get catalogBarcode => 'Shtrixkod';

  @override
  String get catalogType => 'Turi';

  @override
  String get catalogPrice => 'Sotish narxi';

  @override
  String get catalogWholesalePrice => 'Ulgurji narx';

  @override
  String get catalogCategory => 'Kategoriya';

  @override
  String get catalogMeasure => 'O\'lchov birligi';

  @override
  String get catalogQuantity => 'Qoldiq';

  @override
  String get catalogQuickProduct => 'Tezkor tovar';

  @override
  String get catalogAddToQuick => 'Tezkorga qo\'shish';

  @override
  String get catalogRemoveFromQuick => 'Tezkordan olib tashlash';

  @override
  String get catalogNoProducts => 'Tovarlar yo\'q';

  @override
  String get catalogDeleted => 'O\'chirilgan';

  @override
  String catalogConfirmDelete(String name) {
    return '\"$name\" tovarini o\'chirish kerakmi?';
  }

  @override
  String get catalogProductCreated => 'Tovar yaratildi';

  @override
  String get catalogProductUpdated => 'Tovar yangilandi';

  @override
  String get catalogProductDeleted => 'Tovar o\'chirildi';

  @override
  String get catalogProductRestored => 'Tovar tiklandi';

  @override
  String get catalogShowDeleted => 'O\'chirilganlarni ko\'rsatish';

  @override
  String get catalogTypeNormal => 'Oddiy';

  @override
  String get catalogTypeWeight => 'Og\'irlik';

  @override
  String get catalogTypeInner => 'Ichki';

  @override
  String get catalogTypePackage => 'To\'plam';

  @override
  String get catalogTypeService => 'Xizmat';

  @override
  String get catalogMeasurePiece => 'Dona';

  @override
  String get catalogMeasureKg => 'Kilogramm';

  @override
  String get catalogMeasureLiter => 'Litr';

  @override
  String get catalogMeasureMeter => 'Metr';

  @override
  String get catalogNameRequired => 'Nomini kiriting';

  @override
  String get catalogPriceRequired => 'Narxni kiriting';

  @override
  String get catalogPriceInvalid => 'Narx 0 dan katta bo\'lishi kerak';

  @override
  String get catalogBarcodeExists => 'Bu shtrixkodli tovar mavjud';

  @override
  String get catalogCategories => 'Kategoriyalar';

  @override
  String get catalogAllCategories => 'Barcha kategoriyalar';

  @override
  String get catalogNoCategories => 'Kategoriyalar yo\'q';

  @override
  String get catalogQuickProductCategory => 'Tezkor tovar kategoriyasi';

  @override
  String get catalogAddCategory => 'Kategoriya qo\'shish';

  @override
  String get catalogCategoryName => 'Kategoriya nomi';

  @override
  String get catalogManageCategories => 'Kategoriyalarni boshqarish';

  @override
  String get catalogCategoryHasProducts =>
      'O\'chirib bo\'lmaydi: kategoriyada tovarlar bor';

  @override
  String get catalogConfirmDeleteCategory => 'Kategoriyani o\'chirish';

  @override
  String get catalogMenuCategories => 'Menyu kategoriyalari';

  @override
  String get catalogParentCategory => 'Ota kategoriya';

  @override
  String get catalogRootCategory => 'Ildiz (otasiz)';

  @override
  String get telegramErrorPhoneSendFailed => 'Telefonga kod yuborilmadi';

  @override
  String get telegramErrorQrAuthFailed => 'QR-kod orqali avtorizatsiya xatosi';

  @override
  String get telegramErrorWrongCode => 'Tasdiqlash kodi noto\'g\'ri';

  @override
  String get telegramErrorWrongPassword => 'Parol noto\'g\'ri';

  @override
  String get telegramErrorRegistrationFailed => 'Ro\'yxatdan o\'tish xatosi';

  @override
  String get telegramErrorChannelSearchFailed => 'Kanallarni qidirish xatosi';

  @override
  String get telegramErrorChannelConnectFailed => 'Kanallarga ulanish xatosi';

  @override
  String get telegramErrorChannelCreateFailed => 'Kanallarni yaratish xatosi';

  @override
  String get hwSettingsTitle => 'Uskunalar';

  @override
  String get hwSettingsSubtitle => 'Skaner, displey, terminallar';

  @override
  String get terminalServiceTitle => 'Brauzer terminallari';

  @override
  String get terminalServiceSubtitle =>
      'Planshet yoki telefon ish o\'rni sifatida';

  @override
  String get terminalServiceEnable =>
      'Brauzer terminallariga xizmat ko\'rsatish';

  @override
  String get terminalServiceEnabledNote =>
      'Kassa do\'kon tarmog\'ini tinglaydi. Terminallar ulanishi mumkin.';

  @override
  String get terminalServiceDisabledNote =>
      'Kassa faqat o\'zini tinglaydi. Tarmoqqa port ochilmagan, terminallar ulana olmaydi.';

  @override
  String get terminalServiceRestartNote =>
      'O\'zgarish kassa qayta ishga tushirilgandan keyin kuchga kiradi.';

  @override
  String get terminalServiceAddress => 'Terminal uchun manzil';

  @override
  String get terminalServiceAddressHint =>
      'Ushbu manzilni planshet brauzerida oching. Nom ochilmasa, kassaning IP-manzilini tering.';

  @override
  String get pairingTitle => 'Terminalni bog\'lash';

  @override
  String get pairingSubtitle => 'Yangi qurilma uchun kod';

  @override
  String get pairingDisabledNote =>
      'Kassa brauzer terminallariga xizmat ko\'rsatmaydi. Bog\'lash kodini berish uchun xizmatni yoqing.';

  @override
  String get pairingDisabledAction => 'Terminal sozlamalarini ochish';

  @override
  String get pairingAddressLabel => 'Yangi qurilma uchun havola';

  @override
  String get pairingAddressHint =>
      'Ushbu manzilni yangi qurilmada to\'liq tering yoki nusxalang — kod allaqachon unda.';

  @override
  String get pairingLinkPending =>
      'Havola siz kod berganingizdan keyin shu yerda paydo bo\'ladi.';

  @override
  String get pairingRestartNote =>
      'Terminal xizmati sozlamalarda yoqilgan, ammo bu kassa u bilan hali qayta ishga tushirilmagan — manzil javob bermaydi. Kassani qayta ishga tushiring.';

  @override
  String get pairingMint => 'Kod berish';

  @override
  String get pairingMintAgain => 'Yangi kod berish';

  @override
  String get pairingCodeLabel => 'Bog\'lash kodi';

  @override
  String pairingExpiresAt(String time) {
    return '$time gacha amal qiladi';
  }

  @override
  String get pairingOnceNote =>
      'Kod faqat hozir ko\'rsatiladi — bu ekrandan ketsangiz, u yo\'qoladi. Yangi kod berish, agar avvalgisi hali ishlatilmagan bo\'lsa, uni bekor qiladi. Bu kod havolani ochganda sarflanadi — qurilmadagi kirish ekrani keyin alohida, ikkinchi kodni so\'raydi: o\'sha payt yangi kod bering.';

  @override
  String get enrolTitle => 'Terminalni bog\'lash';

  @override
  String get enrolInstructions =>
      'Bu qurilma hali kassaga bog\'lanmagan. Operatordan kassada \"Terminalni bog\'lash\" ekranini ochishni so\'rang va u yerda ko\'rsatilgan kodni kiriting.';

  @override
  String get enrolCodeLabel => 'Bog\'lash kodi';

  @override
  String get enrolSubmit => 'Bog\'lash';

  @override
  String get accountsSettingsTitle => 'To\'lov hisoblar';

  @override
  String get accountsSettingsSubtitle => 'Naqd va karta hisoblar';

  @override
  String get accountsSettingsAdd => 'Hisob qo\'shish';

  @override
  String get accountsSettingsEdit => 'Hisobni tahrirlash';

  @override
  String get accountsSettingsEmpty => 'To\'lov hisoblar sozlanmagan';

  @override
  String get accountsSettingsName => 'Hisob nomi';

  @override
  String get accountsSettingsType => 'Hisob turi';

  @override
  String get accountsSettingsTypePOS => 'Kassa (naqd)';

  @override
  String get accountsSettingsTypeBank => 'Bank (karta)';

  @override
  String get accountsSettingsTypeCash => 'Naqd';

  @override
  String get accountsSettingsTypeSystem => 'Tizim';

  @override
  String get accountsSettingsTypeBonus => 'Bonus';

  @override
  String get accountsSettingsTypeOther => 'Boshqa';

  @override
  String get accountsSettingsBalance => 'Balans';

  @override
  String get accountsSettingsVisible => 'POS';

  @override
  String get accountsSettingsVisibleToPos => 'POS da ko\'rinadi';

  @override
  String get hwSettingsSaved => 'Uskuna sozlamalari saqlandi';

  @override
  String get hwScannerTitle => 'Shtrix-kod skaneri';

  @override
  String get hwScannerMode => 'Skaner rejimi';

  @override
  String get hwScannerModeKeyboard => 'USB / klaviatura (wedge)';

  @override
  String get hwScannerModeSerial => 'Seriyali';

  @override
  String get hwScannerModeCamera => 'Kamera';

  @override
  String get hwScannerModeHint => 'USB skanerlar shu rejimda ishlaydi';

  @override
  String get hwScannerTimeout => 'Taymaut';

  @override
  String get hwScannerMinLength => 'Min. uzunlik';

  @override
  String get hwScannerMaxLength => 'Maks. uzunlik';

  @override
  String get hwDisplayTitle => 'Xaridor displeyi';

  @override
  String get hwDisplayModel => 'Model';

  @override
  String get hwDisplayModelLed8 => 'LED 8 belgi';

  @override
  String get hwDisplayModelVfd20 => 'VFD 20x2';

  @override
  String get hwDisplayPort => 'COM-port';

  @override
  String get hwDisplayBaudRate => 'Tezlik';

  @override
  String get hwDisplayDisabled => 'Xaridor displeyi o\'chirilgan';

  @override
  String get hwDrawerTitle => 'Kassa qutisi';

  @override
  String get hwDrawerMode => 'Ochish rejimi';

  @override
  String get hwDrawerModePrinter => 'Printer orqali';

  @override
  String get hwDrawerModeSerial => 'Seriyali port';

  @override
  String get hwDrawerPort => 'COM-port';

  @override
  String get hwTerminalsTitle => 'To\'lov terminallari';

  @override
  String get hwTerminalIp => 'IP-manzil';

  @override
  String get hwTerminalPort => 'Port';

  @override
  String get hwTerminalMerchantId => 'Merchant ID';

  @override
  String get hwTerminalTerminalId => 'Terminal ID';

  @override
  String get catalogExportCsv => 'CSV eksport';

  @override
  String get catalogImport => 'Import';

  @override
  String get catalogFilterColumn => 'Filtr...';

  @override
  String catalogExportSuccess(String path) {
    return '$path ga eksport qilindi';
  }

  @override
  String get catalogExportFailed => 'Eksport xatosi';

  @override
  String get catalogImportResults => 'Import natijalari';

  @override
  String catalogImportImported(int count) {
    return 'Import qilindi: $count';
  }

  @override
  String catalogImportUpdated(int count) {
    return 'Yangilandi: $count';
  }

  @override
  String catalogImportSkipped(int count) {
    return 'O\'tkazib yuborildi: $count';
  }

  @override
  String get catalogImportErrors => 'Xatolar:';

  @override
  String get catalogTypeConsumable => 'Sarf materiali';

  @override
  String get catalogFilterConsumable => 'Sarf materiallari';

  @override
  String get catalogFilterInner => 'Ichki';

  @override
  String get serviceMarkConsumable => 'Sarf materiali';

  @override
  String get serviceConsumableSearch => 'Tovar / sarf materialini qidirish';

  @override
  String get serviceConsumableSelected => 'Tanlangan tovar';

  @override
  String get serviceQuickServicesTitle => 'Tez xizmatlar';

  @override
  String get serviceQuickServicesEmpty => 'Tez xizmatlar yo\'q';

  @override
  String get serviceIntakeItems => 'Qabul qilinadigan buyumlar';

  @override
  String get serviceItemName => 'Nimani qabul qilasiz (buyum, narsa, qurilma)';

  @override
  String get serviceItemDescription => 'Muammo tavsifi / mijoz istaklari';

  @override
  String get serviceItemSerial => 'Seriya raqami / markirovka';

  @override
  String get serviceItemAdd => 'Buyum qo\'shish';

  @override
  String get serviceItemEmpty => 'Kamida bitta buyum qo\'shing';

  @override
  String serviceItemCount(int count) {
    return '$count dona';
  }

  @override
  String get serviceClientQuickName => 'Mijoz ismi';

  @override
  String get serviceClientQuickPhone => 'Mijoz telefoni';

  @override
  String get serviceClientOrSearch => 'yoki bazadan topish';

  @override
  String get catalogTypeDish => 'Taom';

  @override
  String get catalogFilterDish => 'Taomlar';

  @override
  String get dishCalculation => 'Kalkulyatsiya';

  @override
  String get dishCalculationStub =>
      'Kalkulyatsiya moduli keyinroq mavjud bo\'ladi';

  @override
  String get dishIngredients => 'Ingredientlar';

  @override
  String get serviceConsumablesTitle => 'Sarf normalari';

  @override
  String get serviceConsumablesEmpty => 'Sarf materiallari yo\'q';

  @override
  String get serviceConsumablesAdd => 'Sarf qo\'shish';

  @override
  String get serviceConsumableQuantity => '1 xizmatga soni';

  @override
  String get serviceConsumablesAutoAdded =>
      'Sarf materiallari avtomatik qo\'shildi';

  @override
  String get catalogDescription => 'Tavsif';

  @override
  String get catalogImagePlaceholder => 'Rasm yuklash uchun bosing';

  @override
  String get catalogImageFromGallery => 'Выбрать из галереи';

  @override
  String get catalogImageFromCamera => 'Сделать фото';

  @override
  String get catalogImageRemove => 'Удалить фото';

  @override
  String get catalogImagePickError => 'Не удалось загрузить фото';

  @override
  String get globalRetry => 'Qayta urinish';

  @override
  String get globalRefresh => 'Yangilash';

  @override
  String get globalReset => 'Tozalash';

  @override
  String get globalApply => 'Qoʻllash';

  @override
  String get globalCreate => 'Yaratish';

  @override
  String get stockOpSupply => 'Qabul qilish';

  @override
  String get stockOpMovement => 'Koʻchirish';

  @override
  String get stockOpSupplierReturn => 'Yetkazib beruvchiga qaytarish';

  @override
  String get stockOpMovementShort => 'Koʻch.';

  @override
  String get stockOpReturnShort => 'Qaytarish';

  @override
  String get stockRegistryTitle => 'Ombor amallari';

  @override
  String get stockRegistryAppBarTitle => 'Ombor';

  @override
  String get stockRegistryLoadError => 'Reestrni yuklab boʻlmadi';

  @override
  String get stockRegistryResetFilters => 'Filtrlarni tozalash';

  @override
  String get stockRegistryFilters => 'Filtrlar';

  @override
  String get stockRegistryEmpty => 'Yozuvlar yoʻq';

  @override
  String get stockRegistryEmptyFiltered => 'Filtr parametrlarini oʻzgartiring';

  @override
  String get stockRegistryEmptyCreate => 'Birinchi ombor amalini yarating';

  @override
  String get stockRegistryPeriod => 'Davr';

  @override
  String get stockRegistryOperationType => 'Amal turi';

  @override
  String get stockRegistrySearchHint =>
      'Raqam, kontragent boʻyicha qidirish...';

  @override
  String get stockRegistryDateFrom => 'Dan';

  @override
  String get stockRegistryDateTo => 'Gacha';

  @override
  String get stockRegistryColType => 'Turi';

  @override
  String get stockRegistryColNumber => 'Raqam';

  @override
  String get stockRegistryColCounterparty => 'Kontragent / Ombor';

  @override
  String get stockRegistryColProducts => 'Mahsulotlar';

  @override
  String get stockRegistryColStatus => 'Holat';

  @override
  String get stockSyncDraft => 'Jarayonda';

  @override
  String get stockSyncPending => 'Kutilmoqda';

  @override
  String get stockSyncSending => 'Yuborilmoqda';

  @override
  String get stockSyncSynced => 'Sinx.';

  @override
  String stockRegistryDetailType(String type) {
    return 'Turi: $type';
  }

  @override
  String stockRegistryDetailDate(String date) {
    return 'Sana: $date';
  }

  @override
  String stockRegistryDetailCounterparty(String name) {
    return 'Kontragent: $name';
  }

  @override
  String stockRegistryDetailAmount(String amount) {
    return 'Summa: $amount';
  }

  @override
  String stockRegistryDetailProducts(int count) {
    return 'Mahsulotlar: $count';
  }

  @override
  String stockRegistryDetailComment(String comment) {
    return 'Izoh: $comment';
  }

  @override
  String stockRegistryProductsShort(int count) {
    return '$count dona';
  }

  @override
  String stockRegistryPaginationRange(int from, int to, int total) {
    return '$from–$to / $total';
  }

  @override
  String get stockCreateSupplyTitle => 'Yangi qabul';

  @override
  String get stockCreateSupplySubtitle =>
      'Yetkazib beruvchidan tovar qabul qilish';

  @override
  String get stockCreateMovementSubtitle => 'Omborlar oʻrtasida koʻchirish';

  @override
  String get stockCreateReturnSubtitle =>
      'Tovarni yetkazib beruvchiga qaytarish';

  @override
  String get stockCreateWriteoffSubtitle =>
      'Списание товара (бой, порча, просрочка)';

  @override
  String get stockCreateInventorySubtitle => 'Пересчёт фактических остатков';

  @override
  String get serviceQueueActive => 'Faol';

  @override
  String get serviceScanQrTitle => 'Buyurtma QR kodini skanerlash';

  @override
  String get serviceScanQrHint => 'TELEPOS:SO:... yoki buyurtma raqami';

  @override
  String get serviceIntakePhotos => 'Qabul fotosi';

  @override
  String get serviceIntakePhotosHint =>
      'Qabul qilinayotgan buyumlarni suratga oling';

  @override
  String get expenseTypeOther => 'Boshqa';

  @override
  String get expenseTypeSmallPurchases => 'Mayda xaridlar';

  @override
  String get expenseTypeSalary => 'Maosh';

  @override
  String get expenseTypeUtilities => 'Kommunal';

  @override
  String get expenseTypeCollection => 'Inkassatsiya';

  @override
  String get expenseTypeCustom => 'Maxsus';

  @override
  String get networkTitle => 'Tarmoq va ulanishlar';

  @override
  String get networkUnavailableTitle => 'Faqat TelePOS OS qurilmasida mavjud';

  @override
  String get networkUnavailableDesc =>
      'telepos-sysd tizim demoni topilmadi. Tarmoqni boshqarish faqat POS TelePOS OS qurilmasida ishlaganda mavjud.';

  @override
  String get networkRefresh => 'Yangilash';

  @override
  String get networkSearch => 'Qidirish';

  @override
  String get networkConnect => 'Ulanish';

  @override
  String get networkDisconnect => 'Uzish';

  @override
  String get networkConnected => 'Ulandi';

  @override
  String get networkEthernetTitle => 'Simli tarmoq (Ethernet)';

  @override
  String get networkEthernetDesc =>
      'Kabel ulanishi holati va internetga kirish.';

  @override
  String get networkCableLabel => 'Kabel';

  @override
  String get networkCableConnected => 'Ulandi';

  @override
  String get networkCableNotConnected => 'Ulanmagan';

  @override
  String get networkInternetLabel => 'Internet';

  @override
  String get networkInternetAvailable => 'Mavjud';

  @override
  String get networkInternetUnavailable => 'Kirish yo\'q';

  @override
  String get networkWifiTitle => 'Wi-Fi';

  @override
  String get networkWifiDesc => 'Simsiz tarmoqqa ulanish.';

  @override
  String get networkWifiSearchHint =>
      'Tarmoqlarni topish uchun «Qidirish» tugmasini bosing.';

  @override
  String get networkBluetoothTitle => 'Bluetooth';

  @override
  String get networkBluetoothDesc =>
      'Printerlar, tarozilar va boshqa qurilmalar bilan ulash.';

  @override
  String get networkBluetoothSearchHint =>
      'Qurilmalarni topish uchun «Qidirish» tugmasini bosing.';

  @override
  String get networkBluetoothUnavailableInBrowser =>
      'Brauzerda mavjud emas — Bluetooth faqat kassaning o\'zida sozlanadi.';

  @override
  String networkWifiPasswordTitle(String ssid) {
    return '«$ssid» uchun parol';
  }

  @override
  String get networkWifiPasswordLabel => 'Wi-Fi paroli';

  @override
  String networkConnectedTo(String ssid) {
    return '$ssid tarmog\'iga ulandi';
  }

  @override
  String networkConnectFailed(String ssid) {
    return '$ssid tarmog\'iga ulanib bo\'lmadi';
  }

  @override
  String networkPaired(String device) {
    return 'Ulandi: $device';
  }

  @override
  String get networkPairFailed => 'Ulash amalga oshmadi';

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
  String get applianceTitle => 'Tizim (TelePOS OS)';

  @override
  String get applianceHubSubtitle => 'Tizimni boshqarish, tarmoq, drayverlar';

  @override
  String get applianceUnavailableDesc =>
      'telepos-sysd tizim demoni topilmadi. Ushbu bo\'lim faqat POS TelePOS OS qurilmasida ishlaganda mavjud.';

  @override
  String get applianceNetworkTitle => 'Tarmoq va ulanishlar';

  @override
  String get applianceNetworkDesc =>
      'Wi-Fi, simli tarmoq va Bluetooth. Kirish va sinxronlash uchun kerak.';

  @override
  String get applianceNetworkButton => 'Tarmoqni sozlash';

  @override
  String get applianceDesktopTitle => 'Ish stoli rejimi';

  @override
  String get applianceDesktopDesc =>
      'Ilovalarni o\'rnatish va xizmat ko\'rsatish uchun to\'liq ish stoli.';

  @override
  String get applianceCurrentMode => 'Joriy rejim: ';

  @override
  String get applianceOpenDesktop => 'Ish stolini ochish';

  @override
  String get applianceDesktopUnavailable =>
      'Ushbu yig\'malarda ish stoli mavjud emas.';

  @override
  String get applianceModeKiosk => 'Kassa (POS)';

  @override
  String get applianceModeDesktop => 'Ish stoli';

  @override
  String get applianceDriversTitle => 'Periferiya drayverlari';

  @override
  String get applianceDriversDesc =>
      'Printerlar, tarozilar va to\'lov terminallari drayverlarini ishonchli TelePOS katalogidan o\'rnatish.';

  @override
  String get applianceDriversEmpty => 'Drayverlar katalogi bo\'sh.';

  @override
  String get applianceDriverInstall => 'O\'rnatish';

  @override
  String get applianceDriverRemove => 'O\'chirish';

  @override
  String applianceDriverInstalled(String title) {
    return 'Drayver o\'rnatildi: $title';
  }

  @override
  String applianceDriverRemoved(String title) {
    return 'Drayver o\'chirildi: $title';
  }

  @override
  String applianceError(String message) {
    return 'Xato: $message';
  }

  @override
  String get navNetwork => 'Tarmoq';

  @override
  String get navCollapseMenu => 'Menyuni yig‘ish';

  @override
  String get navExpandMenu => 'Menyuni yoyish';

  @override
  String get languageSwitcherTooltip => 'Til / Язык / Language';

  @override
  String get labelPrinterSettingsTitle => 'Yorliq printeri';

  @override
  String get labelPrinterSettingsSubtitle => 'Narx yorliqlari va shtrix-kodlar';

  @override
  String get labelPrinterLanguage => 'Printer tili';

  @override
  String get labelPrinterSize => 'Yorliq o\'lchami';

  @override
  String get labelPrinterWidthMm => 'Eni, mm';

  @override
  String get labelPrinterHeightMm => 'Balandligi, mm';

  @override
  String get labelPrinterTestSuccess => 'Yorliq bosib chiqarishga yuborildi';

  @override
  String get labelPrinterNotConfigured =>
      'Yorliq printeri sozlanmagan. Sozlamalarda manzilni kiriting.';

  @override
  String get labelTemplatesTitle => 'Yorliq shablonlari';

  @override
  String get labelTemplatesManage => 'Shablonlarni boshqarish';

  @override
  String get labelTemplatesManageSubtitle =>
      'Tartiblarni yaratish va tahrirlash';

  @override
  String get labelTemplatesEmpty => 'Shablonlar topilmadi';

  @override
  String get labelTemplateNew => 'Yangi shablon';

  @override
  String get labelTemplateEdit => 'Shablonni tahrirlash';

  @override
  String get labelTemplateBuiltIn => 'O\'rnatilgan';

  @override
  String get labelMmUnit => 'mm';

  @override
  String get labelTemplateDeleteTitle => 'Shablonni o\'chirish';

  @override
  String labelTemplateDeleteConfirm(String name) {
    return '\"$name\" shabloni o\'chirilsinmi?';
  }

  @override
  String get labelTemplateName => 'Shablon nomi';

  @override
  String get labelTemplateNameRequired => 'Shablon nomini kiriting';

  @override
  String get labelTemplatePreview => 'Oldindan ko\'rish';

  @override
  String get labelTemplateFields => 'Maydonlar';

  @override
  String get labelTemplateAddField => 'Maydon qo\'shish';

  @override
  String get labelTemplateNoFields =>
      'Maydonlar yo\'q. Kamida bitta maydon qo\'shing.';

  @override
  String get labelFieldKind => 'Maydon turi';

  @override
  String get labelFieldText => 'Matn';

  @override
  String get labelFieldFontSize => 'Shrift';

  @override
  String get labelFieldBold => 'Qalin';

  @override
  String get labelFieldKindName => 'Nomi';

  @override
  String get labelFieldKindPrice => 'Narxi';

  @override
  String get labelFieldKindBarcode => 'Shtrix-kod';

  @override
  String get labelFieldKindSku => 'Artikul';

  @override
  String get labelFieldKindDate => 'Sana';

  @override
  String get labelFieldKindText => 'Matn';

  @override
  String get labelPrintTitle => 'Narx yorlig\'ini bosish';

  @override
  String labelPrintBulkTitle(int count) {
    return 'Narx yorliqlarini bosish ($count)';
  }

  @override
  String get labelPrintChooseTemplate => 'Shablonni tanlang';

  @override
  String get labelPrintCopies => 'Nusxalar';

  @override
  String get labelPrintAction => 'Bosish';

  @override
  String labelPrintedCount(int count) {
    return 'Bosildi: $count';
  }

  @override
  String get catalogPrintLabel => 'Narx yorlig\'ini bosish';

  @override
  String get receiptTemplatesTitle => 'Chek shablonlari';

  @override
  String get receiptTemplatesSubtitle =>
      'Chek bezagi: logotip, sarlavha/pastki, BIN, QR, kenglik';

  @override
  String get receiptTemplatesEmpty => 'Shablonlar topilmadi';

  @override
  String get receiptTemplateNew => 'Yangi shablon';

  @override
  String get receiptTemplateEdit => 'Shablonni tahrirlash';

  @override
  String get receiptTemplateBuiltIn => 'O\'rnatilgan';

  @override
  String get receiptTemplateActive => 'Faol';

  @override
  String get receiptTemplateMakeActive => 'Faol qilish';

  @override
  String get receiptTemplateName => 'Shablon nomi';

  @override
  String get receiptTemplateNameRequired => 'Shablon nomini kiriting';

  @override
  String get receiptTemplatePreview => 'Ko\'rib chiqish';

  @override
  String get receiptTemplatePaperWidth => 'Qog\'oz kengligi';

  @override
  String get receiptTemplateContent => 'Chek tarkibi';

  @override
  String get receiptTemplateHeaderFooter => 'Sarlavha va pastki qism';

  @override
  String get receiptTemplateHeaderText => 'Sarlavha matni';

  @override
  String get receiptTemplateFooterText => 'Pastki matn';

  @override
  String get receiptTemplateExtraFooter => 'Qo\'shimcha pastki qatorlar';

  @override
  String get receiptTemplateExtraFooterHint =>
      'Har biri alohida qator (masalan, qaytarish shartlari)';

  @override
  String get receiptTemplateShowBin => 'BIN/IIN bosish';

  @override
  String get receiptTemplateShowAddress => 'Manzilni bosish';

  @override
  String get receiptTemplateShowCashier => 'Kassa/kassirni bosish';

  @override
  String get receiptTemplateShowVat => 'QQS bosish';

  @override
  String get receiptTemplateShowQr => 'Tekshirish havolasini bosish (QR)';

  @override
  String get receiptTemplateShowItemNumbers => 'Pozitsiyalarni raqamlash';

  @override
  String get receiptTemplateShowLogo => 'Logotipni bosish';

  @override
  String get receiptTemplateTestPrint => 'Sinov bosib chiqarish';

  @override
  String get receiptTemplateTestPrintOk => 'Chek namunasi printerga yuborildi';

  @override
  String get receiptTemplateTestPrintFail =>
      'Bosib chiqarish muvaffaqiyatsiz (printerni tekshiring)';

  @override
  String get receiptTemplateDeleteTitle => 'Shablonni o\'chirish';

  @override
  String get receiptTemplateHeaderHint =>
      'Bir necha qator: salomlashuv, aksiya, kontaktlar';

  @override
  String get receiptTemplateFooterHint =>
      'Bir necha qator: minnatdorchilik, qaytarish shartlari, sayt, ijtimoiy tarmoqlar';

  @override
  String get receiptTemplateAlignLeft => 'Chapda';

  @override
  String get receiptTemplateAlignCenter => 'Markazda';

  @override
  String get receiptTemplateAlignRight => 'O\'ngda';

  @override
  String get receiptTemplateBold => 'Qalin';

  @override
  String get receiptTemplateDoubleSize => 'Yirik (ikki barobar o\'lcham)';

  @override
  String get receiptTemplatePaperWidthHint =>
      'Lenta kengligi printer sozlamalarida belgilanadi';

  @override
  String get receiptTemplateMandatoryNote =>
      'Majburiy rekvizitlar — chek raqami, jami, to\'lovlar, QQS, fiskal belgi va QR — har doim sarlavha va pastki qism orasida chop etiladi';

  @override
  String receiptTemplateDeleteConfirm(String name) {
    return '«$name» shablonini o\'chirilsinmi?';
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
      'Bu qurilmada boshqariladigan ekran yo‘q (backlight yo‘q). Yorqinlik va aylantirishni monitorning o‘zida sozlang.';

  @override
  String get sysmRotation => 'Поворот экрана';

  @override
  String get sysmRemoteTitle => 'Удалённая поддержка';

  @override
  String get sysmRemoteDesc =>
      'Временный защищённый доступ для службы поддержки';

  @override
  String get sysmRemoteHelp =>
      '“Qo‘llab-quvvatlashni tiklash” TelePOS qo‘llab-quvvatlash xizmatiga muammoni masofadan hal qilish uchun pristavkaga vaqtinchalik xavfsiz (SSH) ulanish ochadi. Kirish 30 daqiqadan so‘ng avtomatik yopiladi. Faqat qo‘llab-quvvatlash so‘raganda yoqing.';

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
  String get sysmTermGroupDiagnostics => 'Diagnostika';

  @override
  String get sysmTermGroupPrinter => 'Printer';

  @override
  String get sysmTermGroupNetwork => 'Tarmoq';

  @override
  String get sysmTermGroupSystem => 'Tizim';

  @override
  String get sysmTermGroupTime => 'Vaqt';

  @override
  String get sysmTermDiagOsAndDaemon => 'OT va demon versiyasi';

  @override
  String get sysmTermDiagNetworkStatus => 'Tarmoq: holat va manzil';

  @override
  String get sysmTermDiagNetworkConnectivity => 'Tarmoq: ulanish';

  @override
  String get sysmTermDiagHardware => 'Apparat: disk/xotira/printerlar';

  @override
  String get sysmTermPrinterFixAuto => 'Printerni tuzatish (avto)';

  @override
  String get sysmTermPrinterDiag => 'Printer diagnostikasi';

  @override
  String get sysmTermPrinterLoadUsblp => 'usblp modulini yuklash';

  @override
  String get sysmTermPrinterNodesAndPerms => 'Printer tugunlari va ruxsatlar';

  @override
  String get sysmTermPrinterLsusb => 'USB qurilmalar (lsusb)';

  @override
  String get sysmTermPrinterCupsStatus => 'CUPS: holat va navbatlar';

  @override
  String get sysmTermPrinterGiveToKernel => 'Printerni yadroga berish (usblp)';

  @override
  String get sysmTermPrinterTestPrint => '/dev/usb/lp0 ga sinov chop etish';

  @override
  String get sysmTermNetDeviceStatus => 'Qurilmalar holati';

  @override
  String get sysmTermNetIpAddresses => 'IP manzillar';

  @override
  String get sysmTermNetConnectEthernet => 'Ethernet ulash';

  @override
  String get sysmTermNetReload => 'Tarmoqni qayta yuklash';

  @override
  String get sysmTermNetPing => 'Ping 8.8.8.8';

  @override
  String get sysmTermSysDisk => 'Disk';

  @override
  String get sysmTermSysMemory => 'Xotira';

  @override
  String get sysmTermSysSysdStatus => 'telepos-sysd holati';

  @override
  String get sysmTermSysKioskLogs => 'Kiosk jurnallari';

  @override
  String get sysmTermTimeDateTime => 'Sana va vaqt';

  @override
  String get sysmTermTimeNtpSync => 'NTP sinxronlash';

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
      'Hisob-faktura rekvizitlari (ERP, ulanish, token) WebKassa (Fiskalizatsiya) sozlamalaridan olinadi — yagona umumiy konfiguratsiya. Bu yerda alohida ESF rekvizitlarini sozlash shart emas.';

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
      'Ulanish rekvizitlari (login, apiKey, kassa, ERP) WebKassa (Fiskalizatsiya) sozlamalaridan olinadi — yagona umumiy konfiguratsiya.';

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
      'Markirovka kodlarini tekshirish WebKassa orqali amalga oshiriladi. Ulanish rekvizitlari (login, apiKey, kassa, ERP) WebKassa (Fiskalizatsiya) sozlamalaridan olinadi — yagona umumiy konfiguratsiya.';

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
  String get catalogPageFirst => 'Birinchi';

  @override
  String get catalogPagePrev => 'Oldingi';

  @override
  String get catalogPageNext => 'Keyingi';

  @override
  String get catalogPageLast => 'Oxirgi';

  @override
  String get catalogGoToPage => 'Sahifaga o\'tish';

  @override
  String catalogPageOf(int total) {
    return '$total dan sahifa';
  }

  @override
  String get shiftClosedGateTitle => 'Smena yopiq';

  @override
  String get shiftClosedGateMessage =>
      'Operatsiyalarni davom ettirish uchun smenani oching.';

  @override
  String get shiftClosedGateOpen => 'Smenani ochish';

  @override
  String get sysmTerminalPresetsDiag => 'Diagnostika';

  @override
  String get wmsDashboardTitle => 'WMS — Ombor boshqaruvi';

  @override
  String get wmsDashboardTitleShort => 'WMS — Ombor';

  @override
  String get wmsSettings => 'WMS sozlamalari';

  @override
  String get wmsSettingsSubtitle => 'Modullar konfiguratsiyasi';

  @override
  String get wmsModuleWarehouses => 'Omborlar';

  @override
  String get wmsModuleWarehousesSubtitle => 'Omborlar, zonalar, kataklar';

  @override
  String get wmsModuleBatches => 'Partiyalar';

  @override
  String get wmsModuleBatchesSubtitle => 'Partiyali hisob';

  @override
  String get wmsModuleCellStock => 'Katak qoldiqlari';

  @override
  String get wmsModuleCellStockSubtitle => 'Qoldiqlar, joylashtirish, tanlash';

  @override
  String get wmsModuleSerials => 'Seriyali hisob';

  @override
  String get wmsModuleSerialsSubtitle => 'Seriya raqamlari';

  @override
  String get wmsModuleMarking => 'Markirovka';

  @override
  String get wmsModuleMarkingSubtitle => 'Markirovka kodlari';

  @override
  String get wmsModuleClaims => 'Da\'volar';

  @override
  String get wmsModuleClaimsSubtitle => 'Da\'volar va qaytarishlar';

  @override
  String get wmsWarehousesAndCells => 'Omborlar va kataklar';

  @override
  String get wmsWarehouses => 'Omborlar';

  @override
  String get wmsAddWarehouse => 'Ombor qo\'shish';

  @override
  String get wmsNoWarehouses => 'Omborlar yo\'q';

  @override
  String get wmsNoName => 'Nomsiz';

  @override
  String get wmsZones => 'Zonalar';

  @override
  String wmsZonesNamed(String name) {
    return 'Zonalar: $name';
  }

  @override
  String get wmsAddZone => 'Zona qo\'shish';

  @override
  String get wmsSelectWarehouse => 'Omborni tanlang';

  @override
  String get wmsNoZones => 'Zonalar yo\'q';

  @override
  String get wmsCells => 'Kataklar';

  @override
  String wmsCellsNamed(String name) {
    return 'Kataklar: $name';
  }

  @override
  String get wmsGenerate => 'Generatsiya qilish';

  @override
  String get wmsSelectZone => 'Zonani tanlang';

  @override
  String get wmsNoCells => 'Kataklar yo\'q';

  @override
  String get wmsNoAddress => 'Manzilsiz';

  @override
  String get wmsCellBlocked => 'Bloklangan';

  @override
  String wmsCellsCount(int count) {
    return '$count ta katak';
  }

  @override
  String get wmsNewWarehouse => 'Yangi ombor';

  @override
  String get wmsWarehouseCode => 'Ombor kodi';

  @override
  String get wmsName => 'Nomi';

  @override
  String get wmsError => 'Xato';

  @override
  String get wmsCreate => 'Yaratish';

  @override
  String get wmsSelectWarehouseFirst => 'Avval omborni tanlang';

  @override
  String get wmsNewZone => 'Yangi zona';

  @override
  String get wmsZoneCode => 'Zona kodi';

  @override
  String get wmsSelectZoneFirst => 'Avval zonani tanlang';

  @override
  String get wmsGenerateCells => 'Kataklarni generatsiya qilish';

  @override
  String get wmsRows => 'Qatorlar';

  @override
  String get wmsRacks => 'Stellajlar';

  @override
  String get wmsLevels => 'Darajalar';

  @override
  String get wmsBins => 'Kataklar';

  @override
  String get wmsEditWarehouse => 'Omborni tahrirlash';

  @override
  String get wmsAddress => 'Manzil';

  @override
  String get wmsDeleteWarehouseTitle => 'Ombor o\'chirilsinmi?';

  @override
  String wmsDeleteWarehouseConfirm(String name) {
    return '\"$name\" omborini o\'chirmoqchimisiz?';
  }

  @override
  String get wmsCellStockTitle => 'Katak qoldiqlari';

  @override
  String get wmsPlace => 'Joylashtirish';

  @override
  String get wmsPick => 'Tanlash';

  @override
  String get wmsTransfer => 'Ko\'chirish';

  @override
  String get wmsByCell => 'Katak bo\'yicha';

  @override
  String get wmsByProduct => 'Mahsulot bo\'yicha';

  @override
  String get wmsSearchCellHint => 'Katak ID yoki manzilini kiriting...';

  @override
  String get wmsSearchProductHint => 'Mahsulot ucode kiriting...';

  @override
  String get wmsCell => 'Katak';

  @override
  String get wmsProductUcode => 'Mahsulot kodi (ucode)';

  @override
  String get wmsFind => 'Topish';

  @override
  String get wmsEnterCellIdToSearch =>
      'Qoldiqlarni qidirish uchun katak ID kiriting';

  @override
  String get wmsEnterUcodeToSearch => 'Qidirish uchun mahsulot ucode kiriting';

  @override
  String wmsProductLabeled(String value) {
    return 'Mahsulot: $value';
  }

  @override
  String wmsCellLabeled(String value) {
    return 'Katak: $value';
  }

  @override
  String wmsStockSummary(String qty, String reserved, String available) {
    return 'Soni: $qty  |  Zaxira: $reserved  |  Mavjud: $available';
  }

  @override
  String wmsBatchLabeled(String value) {
    return 'Partiya: $value';
  }

  @override
  String get wmsQuantityShort => 'Soni';

  @override
  String get wmsReserved => 'Zaxira';

  @override
  String get wmsAvailable => 'Mavjud';

  @override
  String get wmsBatch => 'Partiya';

  @override
  String get wmsEnterNumericId => 'Raqamli ID kiriting';

  @override
  String get wmsPlaceStockTitle => 'Mahsulotni katakka joylashtirish';

  @override
  String get wmsCellId => 'Katak ID';

  @override
  String get wmsProductUcodeField => 'Mahsulot ucode';

  @override
  String get wmsQuantity => 'Miqdori';

  @override
  String get wmsBatchIdOptional => 'Partiya ID (ixtiyoriy)';

  @override
  String get wmsFillRequiredNumericFields =>
      'Majburiy maydonlarni to\'ldiring (raqamli qiymatlar)';

  @override
  String wmsStockPlaced(String cellId) {
    return 'Mahsulot $cellId katagiga joylashtirildi';
  }

  @override
  String get wmsPlaceError => 'Joylashtirish xatosi';

  @override
  String get wmsPickStockTitle => 'Mahsulotni katakdan tanlash';

  @override
  String get wmsFillAllNumericFields =>
      'Barcha maydonlarni to\'ldiring (raqamli qiymatlar)';

  @override
  String wmsStockPicked(String cellId) {
    return 'Mahsulot $cellId katagidan tanlandi';
  }

  @override
  String get wmsPickError => 'Tanlash xatosi';

  @override
  String get wmsTransferStockTitle => 'Mahsulotni ko\'chirish';

  @override
  String get wmsCellIdFrom => 'Katak ID (qayerdan)';

  @override
  String get wmsCellIdTo => 'Katak ID (qayerga)';

  @override
  String wmsStockTransferred(String from, String to) {
    return 'Mahsulot $from katagidan $to katagiga ko\'chirildi';
  }

  @override
  String get wmsTransferError => 'Ko\'chirish xatosi';

  @override
  String get wmsBatches => 'Partiyalar';

  @override
  String get wmsBatchTrackingTitle => 'Partiyali hisob';

  @override
  String get wmsBatchTabAll => 'Barcha partiyalar';

  @override
  String get wmsBatchTabExpiring => 'Muddati tugayotgan';

  @override
  String get wmsBatchTabExpired => 'Muddati o\'tgan';

  @override
  String get wmsBatchTabQuarantine => 'Karantin';

  @override
  String get wmsNoBatches => 'Partiyalar yo\'q';

  @override
  String get wmsNoExpiringBatches => 'Muddati tugayotgan partiyalar yo\'q';

  @override
  String get wmsNoExpiredBatches => 'Muddati o\'tgan partiyalar yo\'q';

  @override
  String get wmsNoQuarantinedBatches => 'Karantindagi partiyalar yo\'q';

  @override
  String get wmsSearchByUcodeHint => 'Mahsulot ucode bo\'yicha qidirish...';

  @override
  String get wmsNoNumber => 'Raqamsiz';

  @override
  String wmsBatchCardSummary(String ucode, String expiry, String qty) {
    return 'Mahsulot: $ucode  |  Muddati: $expiry  |  Soni: $qty';
  }

  @override
  String get wmsBatchNumber => 'Partiya raqami';

  @override
  String get wmsProduct => 'Mahsulot';

  @override
  String get wmsExpiryDate => 'Yaroqlilik muddati';

  @override
  String get wmsStatus => 'Holat';

  @override
  String get wmsActions => 'Amallar';

  @override
  String get wmsQuarantine => 'Karantin';

  @override
  String get wmsApprove => 'Tasdiqlash';

  @override
  String get wmsStatusQuarantine => 'Karantin';

  @override
  String get wmsStatusExpired => 'Muddati o\'tgan';

  @override
  String get wmsStatusExpiring => 'Muddati tugayapti';

  @override
  String get wmsStatusOk => 'OK';

  @override
  String get wmsMoveToQuarantine => 'Karantinga joylashtirish';

  @override
  String wmsBatchQuarantined(String number) {
    return '$number partiyasi karantinga joylashtirildi';
  }

  @override
  String wmsBatchApproved(String number) {
    return '$number partiyasi tasdiqlandi';
  }

  @override
  String get wmsSearchBatchesByProduct =>
      'Mahsulot bo\'yicha partiyalarni qidirish';

  @override
  String get wmsEnterProductCode => 'Mahsulot kodini kiriting';

  @override
  String get wmsSerialTrackingTitle => 'Seriyali hisob';

  @override
  String get wmsScan => 'Skanerlash';

  @override
  String get wmsSearchBySerialHint => 'Seriya raqami bo\'yicha qidirish...';

  @override
  String get wmsNothingFound => 'Hech narsa topilmadi';

  @override
  String get wmsEnterSerialToSearch =>
      'Qidirish uchun seriya raqamini kiriting';

  @override
  String get wmsRegister => 'Ro\'yxatdan o\'tkazish';

  @override
  String get wmsSelectSerial => 'Seriya raqamini tanlang';

  @override
  String get wmsSerialNumber => 'Seriya raqami';

  @override
  String get wmsLocation => 'Joylashuv';

  @override
  String wmsCellHash(String id) {
    return 'Katak #$id';
  }

  @override
  String get wmsDetails => 'Tafsilotlar';

  @override
  String get wmsMarking => 'Markirovka';

  @override
  String get wmsWarrantyUntil => 'Kafolat muddati';

  @override
  String get wmsNotes => 'Izohlar';

  @override
  String get wmsMovementHistory => 'Harakatlar tarixi';

  @override
  String get wmsNoData => 'Ma\'lumot yo\'q';

  @override
  String get wmsSerialStatusInStock => 'Omborda';

  @override
  String get wmsSerialStatusSold => 'Sotilgan';

  @override
  String get wmsSerialStatusReturned => 'Qaytarilgan';

  @override
  String get wmsSerialStatusWrittenOff => 'Hisobdan chiqarilgan';

  @override
  String get wmsSerialStatusUnknown => 'Noma\'lum';

  @override
  String get wmsScannerUseHardware => 'Skaner: apparat skanerdan foydalaning';

  @override
  String get wmsRegisterSerialTitle => 'Seriya raqamini ro\'yxatdan o\'tkazish';

  @override
  String get wmsSerialRegistered => 'Seriya raqami ro\'yxatdan o\'tkazildi';

  @override
  String get wmsMarkingCodesTitle => 'Markirovka kodlari';

  @override
  String get wmsMarkingAccept => 'Qabul qilish';

  @override
  String get wmsRefresh => 'Yangilash';

  @override
  String get wmsIsMptSettings => 'IS MPT sozlamalari';

  @override
  String get wmsMarkingAcceptTitle => 'Markirovka kodlarini qabul qilish';

  @override
  String get wmsSupplyIdOptional => 'Yetkazib berish ID (ixtiyoriy)';

  @override
  String get wmsMarkingCodesPerLine =>
      'Markirovka kodlari (har qatorda bittadan)';

  @override
  String get wmsAccept => 'Qabul qilish';

  @override
  String get wmsNoCodesEntered => 'Hech qanday kod kiritilmadi';

  @override
  String wmsAcceptedLocally(String count) {
    return 'Mahalliy qabul qilindi: $count (IS MPT — keyinga qoldirildi)';
  }

  @override
  String wmsAccepted(String count) {
    return 'Qabul qilindi: $count';
  }

  @override
  String wmsAcceptError(String error) {
    return 'Qabul qilish xatosi: $error';
  }

  @override
  String wmsMarkingStatusResult(String status) {
    return 'Markirovka kodi holati: $status';
  }

  @override
  String get wmsInCirculation => '(muomalada)';

  @override
  String get wmsIsMptNoConnection =>
      'IS MPT bilan aloqa yo\'q — tekshiruv keyinga qoldirildi';

  @override
  String get wmsVerifyUnavailable =>
      'Tekshiruv mavjud emas (IS MPT sozlanmagan)';

  @override
  String wmsVerifyError(String error) {
    return 'Tekshiruv xatosi: $error';
  }

  @override
  String get wmsNoMarkingCodes => 'Markirovka kodlari yo\'q';

  @override
  String get wmsVerifyStatus => 'Holatni tekshirish (IS MPT)';

  @override
  String get wmsMarkingStatusReceived => 'Qabul qilindi';

  @override
  String get wmsMarkingStatusInStock => 'Omborda';

  @override
  String get wmsMarkingStatusSold => 'Sotilgan';

  @override
  String get wmsMarkingStatusReturned => 'Qaytarildi';

  @override
  String get wmsMarkingStatusRetired => 'Hisobdan chiqarilgan';

  @override
  String get wmsMarkingStatusBlocked => 'Bloklangan';

  @override
  String get wmsClaims => 'Da\'volar';

  @override
  String get wmsClaimTabOpen => 'Ochiq';

  @override
  String get wmsClaimTabInProgress => 'Jarayonda';

  @override
  String get wmsClaimTabResolved => 'Hal qilingan';

  @override
  String get wmsNoOpenClaims => 'Ochiq da\'volar yo\'q';

  @override
  String get wmsNoInProgressClaims => 'Jarayondagi da\'volar yo\'q';

  @override
  String get wmsNoResolvedClaims => 'Hal qilingan da\'volar yo\'q';

  @override
  String get wmsNewClaim => 'Yangi da\'vo';

  @override
  String get wmsNumber => 'Raqam';

  @override
  String get wmsType => 'Turi';

  @override
  String get wmsSeverity => 'Jiddiyligi';

  @override
  String get wmsDate => 'Sana';

  @override
  String get wmsSeverityLow => 'Past';

  @override
  String get wmsSeverityMedium => 'O\'rta';

  @override
  String get wmsSeverityHigh => 'Yuqori';

  @override
  String get wmsSeverityCritical => 'Kritik';

  @override
  String get wmsClaimTypeDefect => 'Nuqson';

  @override
  String get wmsClaimTypeMissort => 'Saralash xatosi';

  @override
  String get wmsClaimTypeShortage => 'Kamomad';

  @override
  String get wmsClaimTypeDamage => 'Shikast';

  @override
  String get wmsClaimTypeOther => 'Boshqa';

  @override
  String get wmsProblemDescription => 'Muammo tavsifi';

  @override
  String get wmsClaimCreated => 'Da\'vo yaratildi';

  @override
  String wmsClaimTitle(String number) {
    return 'Da\'vo $number';
  }

  @override
  String wmsTypeLabeled(String value) {
    return 'Turi: $value';
  }

  @override
  String wmsSeverityLabeled(String value) {
    return 'Jiddiyligi: $value';
  }

  @override
  String wmsDateLabeled(String value) {
    return 'Sana: $value';
  }

  @override
  String get wmsProblemDescriptionLabel => 'Muammo tavsifi:';

  @override
  String get wmsNoDescription => 'Tavsif yo\'q';

  @override
  String get wmsResolutionLabel => 'Yechim:';

  @override
  String get wmsNotSpecified => 'Ko\'rsatilmagan';

  @override
  String get wmsHistoryLabel => 'Tarix:';

  @override
  String get wmsNoRecords => 'Yozuvlar yo\'q';

  @override
  String get wmsResolve => 'Hal qilish';

  @override
  String get wmsResolveClaimTitle => 'Da\'voni hal qilish';

  @override
  String get wmsResolutionNotes => 'Yechim bo\'yicha izohlar';

  @override
  String get wmsClaimResolved => 'Da\'vo hal qilindi';

  @override
  String get setUserManagementTitle => 'Foydalanuvchilar va kirish';

  @override
  String get setUsersTitle => 'Foydalanuvchilar';

  @override
  String get setUsersSubtitle => 'Kirishni boshqarish';

  @override
  String get authSettingsTitle => 'Kirish va sessiya';

  @override
  String get authSettingsSubtitle => 'Kassirsiz kirish va sessiya muddati';

  @override
  String get authSettingsWalkUpTitle => 'Kassirni tanlamasdan kirish';

  @override
  String get authSettingsWalkUpSubtitle =>
      'Bitta PIN ismsiz kirishga ruxsat beradi. Bir nechta kassir bo\'lsa xavfsiz emas: sukut bo\'yicha o\'chirilgan.';

  @override
  String get authSettingsSessionTitle => 'Sessiya muddati';

  @override
  String get authSettingsSessionSubtitle =>
      'Kassir harakatsiz necha daqiqa sessiyada qoladi. Darhol qo\'llaniladi, kassani qayta ishga tushirish shart emas.';

  @override
  String get authSettingsSessionMinutesLabel => 'Daqiqa';

  @override
  String get authSettingsSaved => 'Saqlandi';

  @override
  String get authSettingsInvalidMinutes =>
      '1 dan 1440 gacha butun daqiqa sonini kiriting';

  @override
  String get sessionsTitle => 'Faol sessiyalar';

  @override
  String get sessionsSubtitle => 'Hozir kassada kim bor, tugma bilan tugatish';

  @override
  String get sessionsEmpty => 'Hozir kassada hech kim yo\'q';

  @override
  String sessionsTerminalLabel(String id) {
    return 'Terminal №$id';
  }

  @override
  String sessionsTimes(String issued, String expires) {
    return 'Kirdi $issued · muddati $expires';
  }

  @override
  String get sessionsRevoke => 'Tugatish';

  @override
  String get sessionsRevokeConfirmTitle => 'Sessiya tugatilsinmi?';

  @override
  String sessionsRevokeConfirmBody(String name) {
    return '«$name» kassadan darhol chiqariladi.';
  }

  @override
  String sessionsRevoked(String name) {
    return '«$name» sessiyasi tugatildi';
  }

  @override
  String sessionsRevokeError(String error) {
    return 'Sessiyani tugatib bo\'lmadi: $error';
  }

  @override
  String get setUsersEmpty => 'Foydalanuvchilar yo\'q';

  @override
  String get setAddUser => 'Foydalanuvchi qo\'shish';

  @override
  String setUserNumber(String id) {
    return 'Foydalanuvchi №$id';
  }

  @override
  String get setUserActive => 'Faol';

  @override
  String setUsersLoadError(String error) {
    return 'Xatolik: $error';
  }

  @override
  String get setNewUser => 'Yangi foydalanuvchi';

  @override
  String get setEditUser => 'Tahrirlash';

  @override
  String get setUserTabProfile => 'Profil';

  @override
  String get setUserTabPermissions => 'Ruxsatlar';

  @override
  String get setUserName => 'Ism';

  @override
  String get setUserNameRequired => 'Ism kiriting';

  @override
  String get setUserPinLabel => 'PIN (4-6 raqam)';

  @override
  String get setUserPinRequired => 'PIN kiriting';

  @override
  String get setUserPinMin => 'Kamida 4 raqam';

  @override
  String get setUserPinRange => 'PIN 4-6 raqam bo\'lishi kerak';

  @override
  String get setUserRole => 'Rol';

  @override
  String get setRoleOwner => 'Egasi';

  @override
  String get setRoleAdministrator => 'Administrator';

  @override
  String get setRoleUser => 'Foydalanuvchi';

  @override
  String get setRoleCashier => 'Kassir';

  @override
  String get setUserActiveDesc => 'Foydalanuvchi tizimga kira oladi';

  @override
  String get setUserBlockedDesc => 'Kirish bloklangan';

  @override
  String get setUserOwnerFullAccess => 'Egasida to\'liq kirish bor';

  @override
  String get setUserSelectAll => 'Hammasini tanlash';

  @override
  String get setUserDeselectAll => 'Hammasini bekor qilish';

  @override
  String get setDeleteUserTitle => 'Foydalanuvchi o\'chirilsinmi?';

  @override
  String setDeleteUserConfirm(String name) {
    return '\"$name\" foydalanuvchisi o\'chiriladi. Bu amalni bekor qilib bo\'lmaydi.';
  }

  @override
  String setDeleteUserError(String error) {
    return 'Foydalanuvchini o\'chirib bo\'lmadi: $error';
  }

  @override
  String get setUserNoEncryptionKey =>
      'Shifrlash kaliti sozlanmagan. POS dastlabki sozlamasini yakunlang.';

  @override
  String get setUserPinEncryptFailed => 'PIN ni shifrlab bo\'lmadi';

  @override
  String get setWmsTitle => 'WMS sozlamalari';

  @override
  String get setWmsModules => 'WMS modullari';

  @override
  String get setWmsCellStorage => 'Yacheykali saqlash';

  @override
  String get setWmsCellStorageDesc =>
      'Tovarlarni zona va yacheykalar bo\'yicha manzilli saqlash';

  @override
  String get setWmsBatchTracking => 'Partiyali hisob';

  @override
  String get setWmsBatchTrackingDesc =>
      'Tovarlarni partiyalar bo\'yicha yetkazib berishni kuzatish bilan hisobga olish';

  @override
  String get setWmsSerialTracking => 'Seriyali hisob';

  @override
  String get setWmsSerialTrackingDesc =>
      'Noyob seriya raqamlari bo\'yicha donalab hisob';

  @override
  String get setWmsExpiryControl => 'Yaroqlilik muddatini nazorat qilish';

  @override
  String get setWmsExpiryControlDesc =>
      'Muddat tugashi haqida ogohlantirishlar va avtomatik FEFO tanlash';

  @override
  String get setWmsMarking => 'Markirovka';

  @override
  String get setWmsMarkingDesc =>
      'Majburiy markirovka kodlarini qo\'llab-quvvatlash (DataMatrix, GS1)';

  @override
  String get setWmsWarranty => 'Kafolat hisobi';

  @override
  String get setWmsWarrantyDesc =>
      'Seriya raqamlari bo\'yicha kafolat muddatlarini kuzatish';

  @override
  String get setWmsPickingStrategy => 'Tanlash strategiyasi';

  @override
  String get setWmsPickingStrategyDesc =>
      'Tovarlarni ombordan jo\'natish tartibini belgilaydi';

  @override
  String get setWmsStrategy => 'Strategiya';

  @override
  String get setWmsStrategyFefo =>
      'FEFO — muddati birinchi tugaydi, birinchi chiqadi';

  @override
  String get setWmsStrategyFifo => 'FIFO — birinchi keldi, birinchi chiqdi';

  @override
  String get setWmsStrategyLifo => 'LIFO — oxirgi keldi, birinchi chiqdi';

  @override
  String get setWmsCostMethod => 'Tannarxni hisoblash usuli';

  @override
  String get setWmsCostMethodDesc =>
      'Sotuvda tannarxni hisobdan chiqarish usuli';

  @override
  String get setWmsMethod => 'Usul';

  @override
  String get setWmsCostFifo => 'FIFO — kelish tartibi bo\'yicha';

  @override
  String get setWmsCostLifo => 'LIFO — teskari tartibda';

  @override
  String get setWmsCostAvg => 'O\'rtacha tortilgan qiymat';

  @override
  String get setWmsExpiryWarnDesc =>
      'Muddat tugashidan necha kun oldin ogohlantirish';

  @override
  String setWmsDaysShort(int days) {
    return '$days kun';
  }

  @override
  String get setWmsAbcAnalysis => 'ABC tahlil';

  @override
  String get setWmsAbcDesc =>
      'Tovarlarni aylanma bo\'yicha tasniflash chegaralari';

  @override
  String get setWmsAbcCategoryA => 'A toifa (yuqori aylanma)';

  @override
  String get setWmsAbcCategoryB => 'B toifa (o\'rtacha aylanma)';

  @override
  String get setWmsAbcCategoryC => 'C toifa (past aylanma)';

  @override
  String get setWmsSaved => 'WMS sozlamalari saqlandi';

  @override
  String get setWmsSaveError => 'WMS sozlamalarini saqlab bo\'lmadi';

  @override
  String get setSalesPolicy => 'Sotuv siyosati';

  @override
  String get setSalesPolicyDesc => 'Sotuvda qoldiqlarni nazorat qilish';

  @override
  String get setBlockOversell => 'Qoldiq yetishmaganda sotishni taqiqlash';

  @override
  String get setBlockOversellDesc =>
      'Chekdagi miqdor qoldiqdan oshsa, sotuvni yakunlamaslik (manfiy qoldiqdan himoya)';

  @override
  String get setScreenTouch => 'Ekran va sensorli ekran';

  @override
  String get setScreenTouchDesc => 'Sensorli ekrandagi qulaylik';

  @override
  String get setScrollAssist => 'Sensorli ekrandagi aylantirish tugmalari';

  @override
  String get setScrollAssistDesc =>
      'Sensorli ekranda uzun ro\'yxatlarni (katalog, chek, hisobotlar, ombor) aylantirish uchun ▲/▼ tugmalari';

  @override
  String get setDemoData => 'Demo ma\'lumotlar';

  @override
  String get setDemoDataSubtitle => '12 oylik sotuv';

  @override
  String get setDemoDataDialogContent =>
      'Barcha rejimlar uchun demo ma\'lumotlarni yuklash:\n• Chakana: ~6000 sotuv, yetkazib berishlar, qaytarishlar\n• Restoran: 15 stol, kalkulyatsiyali 29 taom, buyurtmalar\n• Servis: xizmatlar, sarflanadigan materiallar, ish buyurtmalari\n\nYoki toza boshlash uchun barcha ma\'lumotlarni tozalash.';

  @override
  String get setDemoClearAll => 'Hammasini tozalash';

  @override
  String get setDemoLoad => 'Demo yuklash';

  @override
  String get setDemoGenerating => 'Demo ma\'lumotlar yaratilmoqda...';

  @override
  String get setDemoLoadedTitle => 'Demo ma\'lumotlar yuklandi';

  @override
  String get setDemoAlreadyExists =>
      'Ma\'lumotlar allaqachon mavjud. Avval \"Hammasini tozalash\" tugmasini bosing.';

  @override
  String get setClearDataTitle => 'Ma\'lumotlarni tozalash';

  @override
  String get setClearDataContent =>
      'BARCHA ma\'lumotlar o\'chiriladi:\n• Sotuvlar, qaytarishlar, to\'lovlar\n• Tovarlar, toifalar, narxlar\n• Kontragentlar, yetkazib berishlar\n• Buyurtmalar, smenalar, kassa operatsiyalari\n• Restoran stollari, buyurtmalar\n• Servis buyurtmalari\n\nPOS sozlamalari va foydalanuvchilar saqlanadi.\nBu amal qaytarib bo\'lmaydi!';

  @override
  String get setClearDeleteAll => 'Hammasini o\'chirish';

  @override
  String get setClearInProgress => 'Ma\'lumotlar tozalanmoqda...';

  @override
  String get setClearDone => 'Barcha ma\'lumotlar tozalandi';

  @override
  String setGenericError(String error) {
    return 'Xatolik: $error';
  }

  @override
  String get setCorrectionTitle => 'Tuzatish cheki';

  @override
  String get setCorrectionIntro =>
      'Tuzatish cheki ilgari kiritilgan yoki kiritilmagan summani tuzatadi. Sabab va summani ko\'rsating. Agar operator tuzatishni qo\'llab-quvvatlamasa, bu rostgo\'ylik bilan ko\'rsatiladi.';

  @override
  String get setCorrectionReasonLabel => 'Tuzatish sababi';

  @override
  String get setCorrectionReasonHint => 'mas. mustaqil tuzatish';

  @override
  String get setCorrectionAmountLabel => 'Tuzatish summasi, KZT';

  @override
  String get setCorrectionPaymentLabel => 'To\'lov usuli';

  @override
  String get setCorrectionCash => 'Naqd';

  @override
  String get setCorrectionCard => 'Karta';

  @override
  String get setCorrectionSubmit => 'Tuzatish chekini yuborish';

  @override
  String get setCorrectionDefaultName => 'Tuzatish';

  @override
  String get setCorrectionInvalidAmount =>
      'To\'g\'ri tuzatish summasini kiriting (> 0)';

  @override
  String get setCorrectionQueued =>
      'Tuzatish cheki navbatga qo\'yildi (offline)';

  @override
  String get setCorrectionSent => 'Tuzatish cheki yuborildi';

  @override
  String get setCorrectionUnsupported =>
      'Tuzatish chekini joriy operator qo\'llab-quvvatlamaydi';

  @override
  String get setCorrectionNotConfigured => 'Fiskalizatsiya sozlanmagan';

  @override
  String get setCorrectionError => 'Tuzatish cheki xatosi';

  @override
  String get setFiscalConnection => 'Ulanish';

  @override
  String get setFiscalTestMode => 'Test rejimi';

  @override
  String get setFiscalLogin => 'Login';

  @override
  String get setFiscalLoginHint => 'email / telefon';

  @override
  String get setFiscalPassword => 'Parol';

  @override
  String get setFiscalCashboxSerial => 'ZNM (kassa seriya raqami)';

  @override
  String get setFiscalCashboxSerialHint => 'mas. SWK00033717';

  @override
  String get setFiscalRnm => 'RNM (ro\'yxatga olish raqami)';

  @override
  String get setFiscalKeyPath => 'Kalit/sertifikat yo\'li';

  @override
  String get setFiscalOfflineModule => 'Offline modul manzili';

  @override
  String get setFiscalVatRate => 'QQS stavkasi, %';

  @override
  String get dishTabRecipe => 'Retsept';

  @override
  String get dishTabCosting => 'Tannarx';

  @override
  String get dishTabYield => 'Chiqim va KBJU';

  @override
  String get dishVersions => 'Versiyalar';

  @override
  String get dishCostLabel => 'Tannarx';

  @override
  String get dishPriceLabel => 'Narx';

  @override
  String get dishProfitLabel => 'Foyda';

  @override
  String get dishMarkupLabel => 'Ustama';

  @override
  String get dishNoIngredients => 'Ingredientlar yo\'q';

  @override
  String get dishNoIngredientsHint =>
      'Retseptni hisoblash uchun ingredient qo\'shing';

  @override
  String get dishAddIngredient => 'Ingredient qo\'shish';

  @override
  String get dishColIngredient => 'Ingredient';

  @override
  String get dishColGross => 'Brutto';

  @override
  String get dishColColdLoss => 'T.yo\'q.%';

  @override
  String get dishColNet => 'Netto';

  @override
  String get dishColHotLoss => 'Iss.yo\'q.%';

  @override
  String get dishColYield => 'Chiqim';

  @override
  String get dishColCost => 'Narx';

  @override
  String get dishDeleteIngredient => 'Ingredientni o\'chirish';

  @override
  String get dishTotal => 'Jami';

  @override
  String get dishDeleteIngredientTitle => 'Ingredient o\'chirilsinmi?';

  @override
  String dishDeleteIngredientConfirm(String name) {
    return '\"$name\" retseptdan olib tashlansinmi?';
  }

  @override
  String get dishSearchIngredientHint =>
      'Ingredientni nomi yoki shtrix-kodi bo\'yicha qidirish...';

  @override
  String dishCodeOnly(int code) {
    return 'Kod: $code';
  }

  @override
  String dishCodeWithBarcode(int code, int barcode) {
    return 'Kod: $code  |  Shtrix-kod: $barcode';
  }

  @override
  String dishAddTitle(String name) {
    return 'Qo\'shish: $name';
  }

  @override
  String get dishGrossQty => 'Brutto (miqdor)';

  @override
  String get dishColdLossLabel => 'Tayyorlash yo\'qotishi, %';

  @override
  String get dishHotLossLabel => 'Issiqlik ishlovi yo\'qotishi, %';

  @override
  String get dishSeasonCoefficient => 'Mavsumiy koeffitsient';

  @override
  String get dishSeasonStandard => 'Standart (x1.0)';

  @override
  String get dishSeasonWinter => 'Qish (+15%) (x1.15)';

  @override
  String get dishSeasonSummer => 'Yoz (-5%) (x0.95)';

  @override
  String dishEffectiveColdLoss(String value) {
    return 'Samarali tayyorlash yo\'qotishi: $value%';
  }

  @override
  String dishTotalYieldSummary(String cost, String yield) {
    return 'Jami: $cost ₸  |  Chiqim: $yield';
  }

  @override
  String get dishGostNorms => 'GOST normalari';

  @override
  String get dishGostNormsTitle => 'GOST yo\'qotish normalari';

  @override
  String get dishSearchProductHint => 'Mahsulot qidirish...';

  @override
  String get dishReferenceEmpty => 'Ma\'lumotnoma bo\'sh';

  @override
  String get dishGostNotLoaded => 'GOST normalari hali yuklanmagan';

  @override
  String dishGostLossLine(String cold, String hot) {
    return 'Sovuq: $cold%  Issiq: $hot%';
  }

  @override
  String get dishPhotoSection => 'Taom surati';

  @override
  String get dishMissingPricesWarning =>
      'Ba\'zi ingredientlarning xarid narxi yo\'q';

  @override
  String get dishProfitPerServing => 'Porsiyadan foyda';

  @override
  String get dishLossPerServing => 'Porsiyadan zarar';

  @override
  String get dishCostOfDish => 'Taom tannarxi';

  @override
  String get dishSellingPrice => 'Sotuv narxi';

  @override
  String get dishMargin => 'Marja';

  @override
  String get dishNoPhoto => 'Surat yo\'q';

  @override
  String get dishPhotoLoaded => 'Surat yuklandi';

  @override
  String get dishPhotoAddHint => 'Tayyor taom suratini qo\'shing';

  @override
  String get dishCamera => 'Kamera';

  @override
  String get dishGallery => 'Galereya';

  @override
  String get dishPhotoLoadError => 'Suratni yuklab bo\'lmadi';

  @override
  String get dishFoodCost => 'Food cost';

  @override
  String get dishFoodCostExcellent => 'A\'lo';

  @override
  String get dishFoodCostNormal => 'Normal';

  @override
  String get dishFoodCostHigh => 'Yuqori';

  @override
  String get dishServingsCount => 'Porsiyalar soni:';

  @override
  String get dishCostPerServing => 'Porsiya narxi';

  @override
  String get dishPricePerServing => 'Porsiya narxi';

  @override
  String get dishTotalYield => 'Umumiy chiqim';

  @override
  String get dishIngredientsCount => 'Ingredientlar';

  @override
  String get dishKbjuSection => 'Oziq-ovqat qiymati (1 porsiyaga)';

  @override
  String get dishKbjuEmpty => 'KBJU ma\'lumotlari to\'ldirilmagan';

  @override
  String get dishKbjuCalories => 'Kaloriya';

  @override
  String get dishKbjuProteins => 'Oqsillar';

  @override
  String get dishKbjuFats => 'Yog\'lar';

  @override
  String get dishKbjuCarbs => 'Uglevodlar';

  @override
  String dishKcalValue(String value) {
    return '$value kkal';
  }

  @override
  String dishGramValue(String value) {
    return '$value g';
  }

  @override
  String get dishVersionHistory => 'O\'zgarishlar tarixi';

  @override
  String get dishNoVersions => 'Saqlangan versiyalar yo\'q';

  @override
  String dishVersionN(String version) {
    return '$version-versiya';
  }

  @override
  String get dishViewComposition => 'Tarkibni ko\'rish';

  @override
  String get dishRestoreThisVersion => 'Bu versiyani tiklash';

  @override
  String get dishSaveVersion => 'Versiyani saqlash';

  @override
  String dishVersionComposition(String version) {
    return '$version-versiya — tarkibi';
  }

  @override
  String get dishSnapshotUnavailable => 'Tarkib surati mavjud emas';

  @override
  String dishSnapshotIngredientLine(
    String gross,
    String cold,
    String hot,
    String yield,
  ) {
    return 'Brutto: $gross  |  Tayyor.yo\'q.: $cold%  |  Iss.yo\'q.: $hot%  |  Chiqim: $yield';
  }

  @override
  String get dishVersionNotRestorable =>
      'Bu versiyani tiklab bo\'lmaydi (ingredient ma\'lumoti yo\'q), faqat ko\'rish mumkin';

  @override
  String get dishRestoreVersionTitle => 'Versiya tiklansinmi?';

  @override
  String dishRestoreVersionConfirm(String version) {
    return 'Joriy retsept $version-versiya tarkibi bilan almashtiriladi. Davom etilsinmi?';
  }

  @override
  String get dishRestore => 'Tiklash';

  @override
  String dishVersionRestored(String version) {
    return '$version-versiya tiklandi';
  }

  @override
  String get dishRestoreError => 'Versiyani tiklab bo\'lmadi';

  @override
  String dishVersionSummary(int count, String cost) {
    return 'Ingredientlar: $count, tannarx: $cost';
  }

  @override
  String get dishSaveVersionError => 'Retsept versiyasini saqlab bo\'lmadi';

  @override
  String get prodBarcodeAutoHint => 'Avto';

  @override
  String get prodCatalogAttributes => 'Katalog atributlari';

  @override
  String get prodBrand => 'Brend';

  @override
  String get prodManufacturer => 'Ishlab chiqaruvchi';

  @override
  String get prodCountryOfOrigin => 'Kelib chiqish mamlakati';

  @override
  String get prodFiscalAttributes => 'Fiskal atributlar';

  @override
  String get prodVatRate => 'QQS stavkasi';

  @override
  String get prodVatNone => 'QQSsiz';

  @override
  String get prodNtin => 'NTIN';

  @override
  String get prodMarkable => 'Markirovka qilinadi';

  @override
  String get promoTitle => 'Aksiyalar';

  @override
  String get promoSubtitle => '1+1 aksiyalari va xarid uchun sovg\'alar';

  @override
  String get promoNew => 'Yangi aksiya';

  @override
  String promoError(String error) {
    return 'Xato: $error';
  }

  @override
  String get promoEmpty => 'Aksiyalar yo\'q';

  @override
  String get promoEmptyHint => '1+1 yoki Sovg\'a aksiyasini yarating';

  @override
  String get promoTypeGift => 'Sovg\'a';

  @override
  String promoBuyGetFree(int trigger, int reward) {
    return '$trigger sotib ol → $reward bepul';
  }

  @override
  String get promoDefaultName11 => '1+1 aksiyasi';

  @override
  String get promoNameLabel => 'Nomi';

  @override
  String get promoTriggerLabel => 'Trigger mahsulot (nima sotib olish)';

  @override
  String get promoRewardLabel => 'Sovg\'a (nima bepul)';

  @override
  String get promoSaveButton => 'Aksiyani saqlash';

  @override
  String get saleWeighingPlaceItem =>
      'Tortilmoqda... mahsulotni tarozига qoʻying';

  @override
  String get saleWeightReadFailed =>
      'Ogʻirlikni oʻqib boʻlmadi — qoʻlda kiriting';

  @override
  String get salePriceLabelSent => 'Narx yorligʻi chop etishga yuborildi';

  @override
  String get transPrimary => 'Asosiy';

  @override
  String get transSecondary => 'Zaxira';

  @override
  String get transStatusOnline => 'Onlayn';

  @override
  String get transStatusOffline => 'Oflayn';

  @override
  String get transStatusSyncing => 'Sinxronlash';

  @override
  String get transStatusQueued => 'Navbatda';

  @override
  String get transStatusWarning => 'Ogohlantirish';

  @override
  String get transStatusError => 'Xato';

  @override
  String transQueuedCount(int count) {
    return 'navbatda $count';
  }

  @override
  String transFailedCount(int count) {
    return '$count muvaffaqiyatsiz';
  }

  @override
  String transLastSyncAgo(String ago) {
    return 'Soʻnggi sinxronlash: $ago oldin';
  }

  @override
  String get transSyncing => 'Sinxronlash...';

  @override
  String get transSyncNow => 'Hozir sinxronlash';

  @override
  String get transRetryFailed => 'Muvaffaqiyatsizlarni qayta urinish';

  @override
  String get restTips => 'Choychaqa';

  @override
  String get restNoTips => 'Choychaqasiz';

  @override
  String get svcPendingApproval => 'Tasdiqlash kutilmoqda';

  @override
  String get svcApprove => 'Tasdiqlash';

  @override
  String get svcReject => 'Rad etish';

  @override
  String get svcRejected => 'Rad etildi';

  @override
  String get svcQr => 'QR';

  @override
  String get catCollapse => 'Yigʻish';

  @override
  String get repError => 'Xato';

  @override
  String get repNoData => 'Maʼlumot yoʻq';

  @override
  String get repNoDataForPeriod => 'Tanlangan davr uchun maʼlumot yoʻq';

  @override
  String get repKpiLoadError => 'KPI yuklash xatosi';

  @override
  String get repColIndicator => 'Koʻrsatkich';

  @override
  String get repColCount => 'Soni';

  @override
  String get repColSumTenge => 'Summa, ₸';

  @override
  String get repColRow => 'Qator';

  @override
  String get repColTurnoverExclVat => 'Aylanma (QQSsiz)';

  @override
  String get repColVat => 'QQS';

  @override
  String get repColDate => 'Sana';

  @override
  String get repColOperation => 'Operatsiya';

  @override
  String get repColIncome => 'Kirim';

  @override
  String get repColExpense => 'Chiqim';

  @override
  String get repColBalance => 'Qoldiq';

  @override
  String get repColRate => 'Stavka';

  @override
  String get repColGross => 'Brutto';

  @override
  String get repColNet => 'Netto';

  @override
  String get repNoVat => 'QQSsiz';

  @override
  String get repColCounterparty => 'Kontragent';

  @override
  String get repColType => 'Turi';

  @override
  String get repColSaldo => 'Saldo';

  @override
  String get repDebtor => 'Debitor';

  @override
  String get repCreditor => 'Kreditor';

  @override
  String get repColAccount => 'Hisob';

  @override
  String get repColCashier => 'Kassir';

  @override
  String get repColAmount => 'Summa';

  @override
  String get repColProduct => 'Mahsulot';

  @override
  String get repColRevenue => 'Tushum';

  @override
  String get repColCogs => 'Tannarx';

  @override
  String get repColProfit => 'Foyda';

  @override
  String get repColMarginPct => 'Marja %';

  @override
  String get repColReason => 'Sabab';

  @override
  String get repColDocuments => 'Hujjatlar';

  @override
  String get repColCostShort => 'Tannarx';

  @override
  String get repF910Title => '910-shakl — Daromad (soddalashtirilgan)';

  @override
  String repF910Subtitle(String income, String rate, String tax) {
    return 'Soliqqa tortiladigan daromad: $income ₸ • soliq $rate%: $tax ₸';
  }

  @override
  String get repF910RowSalesIncome => 'Sotuvdan daromad';

  @override
  String get repF910RowRefunds => 'Qaytarishlar (minus)';

  @override
  String get repF910RowTaxableIncome => 'Soliqqa tortiladigan daromad';

  @override
  String get repF300Title => '300-shakl — QQS (deklaratsiya)';

  @override
  String repF300Subtitle(String turnover, String vat) {
    return 'Soliqqa tortiladigan aylanma: $turnover ₸ • hisoblangan QQS: $vat ₸';
  }

  @override
  String repF300TaxableTurnoverRate(String rate) {
    return 'Soliqqa tortiladigan aylanma $rate%';
  }

  @override
  String get repF300ZeroRatedTurnover => 'Soliqsiz / 0% aylanma';

  @override
  String get repCashBookTitle => 'Kassa kitobi (KO-4)';

  @override
  String repCashBookSubtitle(String income, String expense, String balance) {
    return 'Kirim: $income • Chiqim: $expense • Qoldiq: $balance ₸';
  }

  @override
  String get repVatPeriodTitle => 'Davr uchun QQS';

  @override
  String repVatPeriodSubtitle(String vat, String base) {
    return 'QQS: $vat ₸ • baza: $base ₸';
  }

  @override
  String get repArApTitle => 'Debitorlik / Kreditorlik';

  @override
  String repArApSubtitle(String receivable, String payable, String saldo) {
    return 'Debitorlik: $receivable • Kreditorlik: $payable • Saldo: $saldo';
  }

  @override
  String get repCashCollectionTitle => 'Inkassatsiya';

  @override
  String repCashCollectionSubtitle(int count, String total) {
    return '$count operatsiya • jami: $total ₸';
  }

  @override
  String get repProfitCogsTitle => 'Foyda / Marja (COGS)';

  @override
  String get repProfitMarginTitle => 'Foyda / Marja';

  @override
  String repProfitMarginSubtitle(String profit, String margin, String note) {
    return 'Foyda: $profit ₸ • marja $margin% • $note';
  }

  @override
  String get repProfitCostRealCogs => 'tannarx: haqiqiy COGS';

  @override
  String get repProfitCostWholesale =>
      'tannarx: ulgurji narx (CalculateCogsUseCase yoʻq)';

  @override
  String get repWriteoffTitle => 'Hisobdan chiqarish';

  @override
  String repWriteoffSubtitle(int count, String total) {
    return '$count hujjat • jami: $total ₸';
  }

  @override
  String get repOrderTypesTitle => 'Buyurtma turlari';

  @override
  String get repOrderTypesSubtitle => 'xizmat turi boʻyicha taqsimot';

  @override
  String get repTableTurnoverTitle => 'Stollar aylanmasi';

  @override
  String get repTableTurnoverSubtitle => 'davr uchun oʻtqazishlar (top-10)';

  @override
  String get repDishPopularityTitle => 'Taomlar mashhurligi';

  @override
  String get repDishPopularitySubtitle => 'sotuvlar soni boʻyicha top-10';

  @override
  String get repFoodCostAnalysisShort => 'Tannarx tahlili';

  @override
  String get repFoodCostAnalysisTitle => 'Tannarx tahlili (Food Cost)';

  @override
  String get repFoodCostAnalysisSubtitle =>
      'yashil <30%, sariq 30-40%, qizil >40%';

  @override
  String get repColDish => 'Taom';

  @override
  String get repColFoodCostPct => 'Food Cost %';

  @override
  String get repTipsByWaiterTitle => 'Ofitsiantlar boʻyicha choychaqa';

  @override
  String get repTipsByWaiterSubtitle => 'choychaqa summasi boʻyicha saralash';

  @override
  String get repColWaiter => 'Ofitsiant';

  @override
  String get repColOrders => 'Buyurtmalar';

  @override
  String get repColTips => 'Choychaqa';

  @override
  String get repColTipsPct => 'Choychaqa %';

  @override
  String get repKpiRestaurantRevenue => 'Restoran tushumi';

  @override
  String get repKpiOrders => 'Buyurtmalar';

  @override
  String get repKpiAvgCheck => 'Oʻrtacha chek';

  @override
  String get repKpiTips => 'Choychaqa';

  @override
  String get repKpiRevenue => 'Tushum';

  @override
  String get repKpiExpenses => 'Xarajatlar';

  @override
  String get repKpiRefunds => 'Qaytarishlar';

  @override
  String get repKpiSales => 'Sotuvlar';

  @override
  String get repSubtitleForPeriod => 'davr uchun';

  @override
  String get repSubtitleTotal => 'jami';

  @override
  String get repSubtitleCashExpenses => 'kassa xarajatlari';

  @override
  String get repSubtitleRefundTotal => 'qaytarish summasi';

  @override
  String get repSubtitleReceipts => 'cheklar';

  @override
  String get repCashFlowTitle => 'Kunlar boʻyicha pul oqimi';

  @override
  String get repCashFlowInvestments => 'Investitsiyalar';

  @override
  String get repCashFlowExpenses => 'Xarajatlar';

  @override
  String get repCashFlowDividends => 'Dividendlar';

  @override
  String repDaysCount(int count) {
    return '$count kun';
  }

  @override
  String get repTopProfitableTitle => 'Top-10 foydali mahsulot';

  @override
  String get repTopProfitableSubtitle => 'absolyut foyda boʻyicha';

  @override
  String get repProductProfitTitle => 'Mahsulotlar rentabelligi';

  @override
  String get repProductProfitSubtitle => 'foyda boʻyicha top-20';

  @override
  String get repRefundTrendTitle => 'Qaytarishlar trendi';

  @override
  String get repSupplierVolumeTitle =>
      'Yetkazib beruvchilar boʻyicha yetkazib berish';

  @override
  String repSuppliersCount(int count) {
    return '$count yetkazib beruvchi';
  }

  @override
  String get repSupplierTableTitle => 'Yetkazib beruvchilar jadvali';

  @override
  String get repSupplierTableSubtitle =>
      'yetkazib berish soni boʻyicha saralash';

  @override
  String get repColSupplier => 'Yetkazib beruvchi';

  @override
  String get repColSupplyCount => 'Yetkazib berish soni';

  @override
  String get repPriceTrendTitle => 'Xarid narxlari dinamikasi';

  @override
  String get repPriceTrendSubtitle =>
      'yetkazib berish soni boʻyicha top-5 mahsulot';

  @override
  String get repNotEnoughDataForChart =>
      'Diagramma uchun maʼlumot yetarli emas';

  @override
  String get repPriceChangesShort => 'Narx oʻzgarishlari';

  @override
  String get repPriceChangesTitle => 'Yetkazib beruvchi narxlari oʻzgarishlari';

  @override
  String get repPriceChangesSubtitle =>
      'xarid narxlarining soʻnggi oʻzgarishlari';

  @override
  String get repColWas => 'Edi';

  @override
  String get repColBecame => 'Boʻldi';

  @override
  String get repColChangePctShort => 'Oʻzg. %';

  @override
  String get repNoSupplierData => 'Yetkazib beruvchilar haqida maʼlumot yoʻq';

  @override
  String get repNoSuppliesForPeriod =>
      'Tanlangan davr uchun yetkazib berishlar topilmadi';

  @override
  String get navWmsDashboard => 'WMS ombor';

  @override
  String get navWmsWarehouses => 'Omborlar';

  @override
  String get navWmsBatches => 'Partiyalar';

  @override
  String get navWmsSerials => 'Seriyalar';

  @override
  String get navWmsCellStock => 'Kataklar';

  @override
  String get navWmsClaims => 'Da\'volar';

  @override
  String get navWmsMarking => 'Markirovka';

  @override
  String get navWmsSettings => 'WMS sozlamalari';

  @override
  String errorInsufficientStock(String name) {
    return 'Qoldiq yetarli emas: $name';
  }

  @override
  String get discountLimitsTitle => 'Chegirma cheklovlari';

  @override
  String get discountLimitsSubtitle =>
      'Kassir qo\'lda qancha chegirma bera oladi';

  @override
  String get discountLimitsIntro =>
      'Rol chegarasi standartni almashtiradi. O\'z qatori yo\'q rol uchun “Standart” amal qiladi. Yuz foiz “cheklovsiz” degani — bu e\'lon qilingan qiymat, bo\'shliq emas.';

  @override
  String get discountLimitsDefaultRow => 'Standart (barcha rollar)';

  @override
  String get discountLimitsMaxPercent => 'Chegara, %';

  @override
  String get discountLimitsApprovalAbove => 'Tasdiq chegarasi, %';

  @override
  String get discountLimitsApprovalHint => 'bo\'sh — talab qilinmaydi';

  @override
  String get discountLimitsInheritHint => 'bo\'sh — standartdek';

  @override
  String get discountLimitsTwoDoors =>
      'Diqqat: savdo siyosatidagi “narxni tushirishni taqiqlash” faqat qator narxini tahrirlashni yopadi. Chegirma 100 % chegarada hamon ruxsat etilgan — hatto bepul qatorgacha. Bu ikki xil eshik; ikkinchisini yopish uchun chegarani yuzdan past qiling.';

  @override
  String get discountLimitsSaved => 'Chegara saqlandi';

  @override
  String get discountLimitsInherited =>
      'Qator olib tashlandi: rol standartni meros qiladi';

  @override
  String get discountLimitsInvalid => 'Chegara — 0 dan 100 gacha son';

  @override
  String get discountLimitsApprovalNotYet =>
      'Katta xodimning tasdig\'i hozircha amalga oshirilmagan: chegaradan oshgan chegirma kod so\'ramay, aytilgan sabab bilan rad etiladi.';

  @override
  String errorDeniedPolicy(String detail) {
    return 'Kassa sozlamalari bilan taqiqlangan: $detail';
  }

  @override
  String errorDeniedLimit(String detail) {
    return 'Chegirma ruxsat etilganidan ko\'proq: $detail';
  }

  @override
  String errorApprovalRequired(String detail) {
    return 'Katta xodimning tasdig\'i kerak: $detail';
  }

  @override
  String get errorBigAmountBlocked =>
      'Sotuv summasi 1 mln ₸ dan oshadi. Kassa sozlamalarida katta summalarga ruxsatni yoqing.';

  @override
  String errorMarkRequired(String name) {
    return 'Markirovka kodi kerak: $name';
  }

  @override
  String get errorOrderNotFound => 'Buyurtma topilmadi';

  @override
  String get errorSerialNotFound => 'Seriya raqami topilmadi';

  @override
  String get errorReceiptFailedPrint => 'Chekni chop etib bo\'lmadi';

  @override
  String get errorDeleteFailed => 'O\'chirib bo\'lmadi';

  @override
  String get errorCancelFailed => 'Bekor qilib bo\'lmadi';

  @override
  String get errorShiftZreportFailed => 'Z-hisobot xatosi';

  @override
  String get errorTransitionFailed => 'Holatni o\'zgartirib bo\'lmadi';

  @override
  String get logJournalTitle => 'Ish jurnali';

  @override
  String get logJournalOpen => 'Jurnalni ochish';

  @override
  String get logJournalCardDesc =>
      'Sana bo\'yicha fayl jurnali: fleshkaga yuklash, tozalash';

  @override
  String get logJournalEmpty => 'Jurnal bo\'sh';

  @override
  String get logJournalPickFolder => 'Yuklash uchun jild (fleshka) tanlang';

  @override
  String get logJournalExport => 'Fleshkaga yuklash';

  @override
  String logJournalExported(int count, String dir) {
    return '$dir ichiga $count ta fayl yuklandi';
  }

  @override
  String logJournalSummary(int count, String size) {
    return 'Fayllar: $count, jami $size';
  }

  @override
  String get logJournalDeleteOld => '7 kundan eski';

  @override
  String logJournalDeletedOld(int count) {
    return '$count ta fayl o\'chirildi';
  }

  @override
  String get logJournalDeleteAllTitle => 'Barcha jurnallar o\'chirilsinmi?';

  @override
  String get logJournalDeleteAllConfirm =>
      'Bugungidan tashqari barcha jurnal fayllari o\'chiriladi. Buni qaytarib bo\'lmaydi.';

  @override
  String get setUserTabPin => 'PIN';

  @override
  String get setUserPinChange => 'PIN o\'zgartirish';

  @override
  String get setUserPinSetHint => 'Kirish uchun PIN o\'rnating (4-6 raqam)';

  @override
  String get setUserPinKeepHint => 'Joriy PINni saqlash uchun bo\'sh qoldiring';

  @override
  String get setUserPinNew => 'Yangi PIN';

  @override
  String get receiptInputRecent => 'So\'nggi cheklar';

  @override
  String get receiptInputNoRecent => 'Hozircha cheklar yo\'q';

  @override
  String get receiptInputRecentUnavailable =>
      'Oxirgi cheklar ro\'yxati bu terminalda mavjud emas — chek raqamini qo\'lda kiriting';

  @override
  String get shiftHistoryTitle => 'Smenalar tarixi';

  @override
  String get shiftHistoryEmpty => 'Yopilgan smenalar hozircha yo\'q';

  @override
  String shiftHistoryShiftNo(int id) {
    return 'Smena №$id';
  }

  @override
  String get shiftHistorySales => 'Sotuvlar';

  @override
  String get shiftHistoryRefunds => 'Qaytarishlar';

  @override
  String get shiftHistoryOpeningCash => 'Boshlang\'ich kassa';

  @override
  String saleExpiredBatchWarning(String name) {
    return 'Diqqat: «$name» mahsulotining partiya muddati o\'tgan';
  }

  @override
  String get setPolicyEditProduct => 'Mahsulotlarni tahrirlashga ruxsat';

  @override
  String get setPolicyEditProductDesc =>
      'Kassir katalogdagi mahsulot kartalarini o\'zgartira oladi';

  @override
  String get setPolicyEditPrice => 'Sotuvda narxni o\'zgartirishga ruxsat';

  @override
  String get setPolicyEditPriceDesc =>
      'Kassir chekdagi pozitsiya narxini qo\'lda o\'zgartira oladi';

  @override
  String get setPolicyDiscounts => 'Chegirmalarga ruxsat';

  @override
  String get setPolicyDiscountsDesc =>
      'Kassir chek pozitsiyalariga chegirma qo\'llashi mumkin';

  @override
  String get setPolicyCashInOut => 'Naqd kirim/chiqimga ruxsat';

  @override
  String get setPolicyCashInOutDesc =>
      'Kassir kassadan naqd pul kiritishi va olishi mumkin';

  @override
  String get setPolicyBigAmount => 'Katta summalarga ruxsat (>1 mln)';

  @override
  String get setPolicyBigAmountDesc =>
      'Operatsiyalardagi 1 000 000 chegarasini olib tashlash';

  @override
  String get setPolicyBlockPriceDecrease =>
      'Narxni karta narxidan past tushirishni taqiqlash';

  @override
  String get setPolicyBlockPriceDecreaseDesc =>
      'Chekdagi narxni mahsulot narxidan past qo\'yib bo\'lmaydi';

  @override
  String get printerAutoDetect => 'Printerni topish';

  @override
  String get printerAutoDetecting => 'Printer qidirilmoqda…';

  @override
  String printerFound(String device) {
    return 'Topildi: $device';
  }

  @override
  String printerFoundWithNote(String device, String note) {
    return 'Topildi: $device — $note';
  }

  @override
  String get printerNotFoundAnyPort =>
      'Printer hech bir portda topilmadi (USB/serial). Kabel va quvvatni tekshiring.';

  @override
  String get printerUsbName => 'USB printer';

  @override
  String get printerSelectDevice => 'Printerni tanlang';

  @override
  String get printerNoAccessGroupLp =>
      'Tugun topildi, lekin ruxsat yo\'q (lp guruhi kerak)';

  @override
  String printerLabelUsb(String path) {
    return 'USB-printer ($path)';
  }

  @override
  String printerLabelSerial(String path) {
    return 'Serial-printer ($path)';
  }

  @override
  String get printerNoAccessGroupLpHint =>
      'Tugun topildi, lekin ruxsat yo\'q (lp guruhi kerak): usermod -aG lp telepos va seansni qayta ishga tushiring.';

  @override
  String printerRawOpenNoPermsHint(String path) {
    return '$path tuguni topildi, lekin ochib bo\'lmaydi — ruxsat yo\'q. Foydalanuvchini lp guruhiga qo\'shing (usermod -aG lp telepos) va seansni/qurilmani qayta ishga tushiring.';
  }

  @override
  String get printerNotFoundNoNode =>
      'Printer topilmadi: na /dev/usb/lp* char-tuguni, na USB-serial port bor. Printer kabeli va quvvatini tekshiring.';

  @override
  String get ownerOnlyTitle => 'Faqat kassa egasiga ochiq';

  @override
  String get ownerOnlyDesc =>
      'Tizim operatsiyalari (qayta yuklash, qayta tiklash, drayverlar, terminal) faqat egasi hisobida ochiq.';

  @override
  String get telegramApiSectionTitle => 'Telegram ilovasi';

  @override
  String get telegramApiSectionDesc =>
      'TelePOS Telegram kalitlarisiz yetkaziladi. my.telegram.org saytida ilova ro\'yxatdan o\'tkazing va quyidagi juftlikni kiriting yoki yig\'ish vaqtida --dart-define orqali bering.';

  @override
  String get telegramApiIdLabel => 'api_id';

  @override
  String get telegramApiHashLabel => 'api_hash';

  @override
  String get telegramApiSave => 'Kalitlarni saqlash';

  @override
  String get telegramApiClear => 'Kalitlarni o\'chirish';

  @override
  String get telegramApiSaved => 'Telegram kalitlari saqlandi';

  @override
  String get telegramApiCleared => 'Telegram kalitlari o\'chirildi';

  @override
  String get telegramApiInvalid =>
      'Raqamli api_id va bo\'sh bo\'lmagan api_hash kiriting';

  @override
  String get telegramApiStatusConfigured => 'Kalitlar berilgan';

  @override
  String get telegramApiStatusMissing => 'Kalitlar berilmagan';

  @override
  String get deviceSearchButton => 'Qidirish';

  @override
  String get deviceSearchTitle => 'Topilgan qurilmalar';

  @override
  String get deviceSearchRunning => 'Qidirilmoqda…';

  @override
  String get deviceSearchEmpty =>
      'Hech narsa topilmadi. Barcha manbalar so\'raldi — qurilma ulanmagan yoki o\'chirilgan.';

  @override
  String get deviceSearchNoValueForField =>
      'Qurilmalar topildi, lekin hech biri bu maydon uchun qiymat bermaydi.';

  @override
  String deviceSearchFailedSources(String sources) {
    return 'Qidiruv bajarilmadi: $sources. Bu “hech narsa ulanmagan” degani emas.';
  }

  @override
  String get deviceSearchUnavailable =>
      'Bu yig\'malada qurilmalarni qidirish mavjud emas.';

  @override
  String deviceSearchFieldFilled(String value) {
    return 'Maydon to\'ldirildi: $value';
  }

  @override
  String get deviceSourceSerialPort => 'Ketma-ket port';

  @override
  String get deviceSourceUsb => 'USB';

  @override
  String get deviceSourceNetwork => 'Tarmoq';

  @override
  String get deviceSourceBluetooth => 'Bluetooth';

  @override
  String get deviceCheckButton => 'Qurilmani tekshirish';

  @override
  String get deviceCheckRunning => 'Tekshirilmoqda…';

  @override
  String get deviceCheckUnavailable =>
      'Bu yig\'malada qurilmani tekshirish mavjud emas.';

  @override
  String get deviceCheckSavedBindingNotice =>
      'Saqlangan bog\'lanish tekshiriladi: qurilmaga bu ekrandagi saqlanmagan o\'zgarishlar emas, yozilgan parametrlar bo\'yicha so\'rov yuboriladi. Yangi bog\'lanish savdolarda ishlashi uchun ilovani qayta ishga tushiring.';

  @override
  String get deviceCheckReasonOk => 'Qurilma javob berdi';

  @override
  String get deviceCheckReasonNotConfigured => 'Qurilma sozlanmagan';

  @override
  String get deviceCheckReasonInvalidBinding => 'Bog\'lanish noto\'g\'ri';

  @override
  String get deviceCheckReasonDriverNotLive =>
      'Bog\'lanish saqlangan, lekin bu yig\'ma bu qurilma bilan ishlay olmaydi';

  @override
  String get deviceCheckReasonConnectionFailed => 'Qurilma javob bermayapti';

  @override
  String get deviceCheckReasonDeviceRefused => 'Qurilma amaldan bosh tortdi';

  @override
  String get deviceCheckReasonNotSupportedOnPlatform =>
      'Bu platformada qo\'llab-quvvatlanmaydi';

  @override
  String get deviceCheckReasonNotImplemented =>
      'Bu sinf uchun tekshirish hali amalga oshirilmagan';

  @override
  String get deviceCheckReasonUnexpectedError => 'Kutilmagan xato';

  @override
  String get scannerRulesTitle => 'Shtrix-kod o\'qish qoidalari';

  @override
  String get scannerRulesSubtitle =>
      'Skaner xususiyatlari emas, o\'rnatish qoidalari: qaysi o\'qilgan qiymat qabul qilinadi.';

  @override
  String get scannerRulesMinLength => 'Shtrix-kodning eng kichik uzunligi';

  @override
  String get scannerRulesMaxLength => 'Shtrix-kodning eng katta uzunligi';

  @override
  String get scannerRulesTimeoutMs => 'Skaner belgilar orasidagi oraliq, ms';

  @override
  String scannerRulesDefaultHint(String value) {
    return 'Bo\'sh — sukut bo\'yicha $value';
  }

  @override
  String scannerRulesNotAnInteger(String value) {
    return '“$value” butun son emas';
  }

  @override
  String get scannerRulesSaved => 'Shtrix-kod o\'qish qoidalari saqlandi';

  @override
  String get printQueueSectionTitle => 'Chop etish navbati';

  @override
  String get printQueueSubtitle =>
      'Nima chop etilishini kutmoqda, nima chop etilmadi va nima uchun.';

  @override
  String get printQueueEmpty => 'Navbat bo‘sh — chop etilmagan cheklar yo‘q.';

  @override
  String get printQueueUnavailable =>
      'Chop etish navbati bu yig‘mada mavjud emas.';

  @override
  String get printQueueUnreadable => 'Chop etish navbatini o‘qib bo‘lmaydi';

  @override
  String get printQueueUnreadableHint =>
      'Bu bo‘sh navbat emas: topshiriqlar chop etilishini kutayotgan bo‘lishi mumkin, ammo ro‘yxatni o‘qib bo‘lmaydi. Xizmat ko‘rsatish talab etiladi.';

  @override
  String get printQueueStateQueued => 'Chop etishni kutmoqda';

  @override
  String get printQueueStatePrinting => 'Chop etilmoqda';

  @override
  String get printQueueStatePrinted => 'Chop etildi';

  @override
  String get printQueueStateFailed => 'Chop etilmadi, qayta uriniladi';

  @override
  String get printQueueStateExpired => 'Muddati o‘tdi, o‘zi qayta urinmaydi';

  @override
  String get printQueueStateCancelled => 'Operator bekor qildi';

  @override
  String printQueueAttempts(int count) {
    return 'Urinishlar: $count';
  }

  @override
  String printQueueDeadline(String moment) {
    return '$moment gacha amal qiladi';
  }

  @override
  String printQueueReason(String reason) {
    return 'Sababi: $reason';
  }

  @override
  String get printQueueRetry => 'Qayta urinish';

  @override
  String get printQueueCancelJob => 'Topshiriqni bekor qilish';

  @override
  String get printQueueExtendTitle => 'Topshiriq muddati qancha uzaytirilsin?';

  @override
  String get printQueueExtend5Minutes => 'Yana 5 daqiqa';

  @override
  String get printQueueExtend30Minutes => 'Yana 30 daqiqa';

  @override
  String get printQueueExtend2Hours => 'Yana 2 soat';

  @override
  String get printQueueRetryAccepted => 'Topshiriq yana navbatda';

  @override
  String get printQueueRetryAlreadyPrinted =>
      'Bu chek allaqachon chop etilgan — ikkinchi marta chop etilmaydi';

  @override
  String get printQueueRetryRejected => 'Qayta urinish amalga oshmadi';

  @override
  String get printQueueCancelTitle => 'Topshiriq bekor qilinsinmi?';

  @override
  String get printQueueCancelBody =>
      'Bekor qilingan topshiriqni chop etib bo‘lmaydi. Xuddi shunday chek kerak bo‘lsa, uni qaytadan chiqarish kerak.';

  @override
  String get printQueueCancelConfirm => 'Topshiriqni bekor qilish';

  @override
  String get printQueueCancelDone => 'Topshiriq bekor qilindi';

  @override
  String get printQueueCancelRefused =>
      'Bu topshiriqni endi bekor qilib bo‘lmaydi: u chop etilmoqda yoki yakunlangan';

  @override
  String get errorPayReceiptNotFound =>
      'Chek endi ishda emas — uni to\'lash mumkin emas. Ekranni yangilab, qaytadan boshlang.';

  @override
  String get errorPayNotOwner =>
      'Bu chekni boshqa ish joyi yuritmoqda — uni bu yerdan to\'lash mumkin emas.';

  @override
  String get errorPaymentAlreadyTaken =>
      'Bu chek allaqachon to\'langan. Kassa pulni ikkinchi marta olmaydi.';

  @override
  String get errorPaymentInsufficient =>
      'Kiritilgan summa chekni qoplamaydi. Summani qaytadan kiriting.';

  @override
  String get errorPaymentAccountMissing =>
      'Kassada bu to\'lov turi uchun hisob yo\'q. Administratorga murojaat qiling.';

  @override
  String get errorPaymentAccountNotAllowed =>
      'Bunday hisob to\'lov uchun taklif qilinmagan. Hisoblar ro\'yxatini yangilab, qaytadan tanlang.';

  @override
  String get errorPaymentUnbalanced =>
      'To\'lov qatorlari summasi chek summasiga to\'g\'ri kelmaydi. To\'lovni qaytadan kiriting.';

  @override
  String get errorPaymentKindInactive =>
      'Bu to\'lov turi kassa sozlamalarida o\'chirilgan. Boshqasini tanlang yoki sozlamalarda yoqing.';

  @override
  String get errorPaymentKindUnknown =>
      'Kassa bunday to\'lov turini bilmaydi. Administratorga murojaat qiling.';

  @override
  String get errorCertificateUnknown =>
      'Bu kassada bunday raqamli sertifikat yo\'q. Raqamni tekshiring.';

  @override
  String get errorCertificatePinWrong =>
      'Sertifikat PIN kodi to\'g\'ri kelmadi. Qaytadan kiriting.';

  @override
  String get errorCertificateRateLimited =>
      'Sertifikatni tekshirishda muvaffaqiyatsiz urinishlar juda ko\'p. Bir necha daqiqa kuting va qaytadan urinib ko\'ring.';

  @override
  String get errorConnectionLost =>
      'Kassa bilan aloqa uzildi. Tarmoqni tekshirib, qaytadan urinib ko\'ring.';

  @override
  String get errorRunIncomplete =>
      'Kassa amalni yakunlamasdan to\'xtatdi. Qaytarishdan oldin kassadagi natijani tekshiring.';

  @override
  String get errorWireMismatch =>
      'Ish joyi va kassa bir-birini tushunmadi — versiyalar mos emas. Sahifani yangilang; yordam bermasa, administratorga murojaat qiling.';

  @override
  String get errorTillFailed =>
      'Kassa amalni bajara olmadi. Qaytadan urinib ko\'ring; xato takrorlansa, administratorga murojaat qiling.';

  @override
  String get errorTerminalChanged =>
      'Siz ish joyini almashtirdingiz — qaytadan kiring.';

  @override
  String get errorUnknownTerminal =>
      'Ish joyi kassaga ulanmagan. Uni ulash kodi bilan qaytadan ulang.';

  @override
  String get errorAlreadyConfigured =>
      'Kassa allaqachon sozlangan — dastlabki sozlash ustasi endi mavjud emas.';

  @override
  String get errorCannotDeleteSelf =>
      'Kassaning o\'z ish joyini o\'chirib bo\'lmaydi.';

  @override
  String get errorNoDrivers =>
      'Kassa uskuna drayverlarisiz yig\'ilgan — qurilmalarni qidirish va tekshirish mavjud emas. Administratorga murojaat qiling.';

  @override
  String get errorNoNetworkModule =>
      'Bu kassa tarmoq sozlamalarini boshqarmaydi — tizim xizmati yo\'q. Administratorga murojaat qiling.';

  @override
  String get errorNoSessionRegistry =>
      'Bu kassa seanslar ro\'yxatini yuritmaydi. Administratorga murojaat qiling.';

  @override
  String get errorNoBackupTransport =>
      'Bu kassada zaxira nusxalar sozlanmagan. Administratorga murojaat qiling.';

  @override
  String get errorBackupNotFound => 'Zaxira nusxa topilmadi.';

  @override
  String get errorCertificatesUnavailable =>
      'Bu kassa sovg\'a sertifikatlarini tarmoq orqali chiqarmaydi. Administratorga murojaat qiling.';

  @override
  String get errorRefundStale =>
      'Buyruq kassaga yetguncha qaytarish o\'zgardi. Amalni takrorlang.';

  @override
  String get errorRefundWrongDraft =>
      'Bu qaytarish qoralamasi endi yo\'q. Qaytarishni qaytadan oching.';

  @override
  String get errorRefundNotStarted =>
      'Qaytarish boshlanmagan — chekni tanlang yoki cheksiz qaytarishni boshlang.';

  @override
  String get errorRefundEmpty =>
      'Qaytarishda birorta qator yo\'q — qaytariladigan narsa yo\'q.';

  @override
  String get errorReceiptAlreadyRefunded =>
      'Bu chek bo\'yicha qaytarish allaqachon qilingan.';

  @override
  String get errorReceiptNotRefundable =>
      'Bu chekni bu yerda qaytarib bo\'lmaydi: to\'lov boshqa kassaning terminali orqali o\'tgan. Qaytarishni to\'lov qilingan joyda rasmiylashtiring.';

  @override
  String get errorLineNotInReceipt =>
      'Bu tovar chekda yo\'q — chek bo\'yicha faqat unda sotilgan narsalar qaytariladi.';

  @override
  String get errorSaleNotCompleted =>
      'Bu chek bo\'yicha sotuv yakunlanmagan — qaytariladigan narsa yo\'q.';

  @override
  String get errorRefundBusy =>
      'Kassada boshqa qaytarish davom etmoqda. Uni yakunlab, qaytadan urinib ko\'ring.';

  @override
  String get errorRefundCannotStart =>
      'Kassa qaytarishni boshlay olmadi va sababini aytmadi. Smena va kassa sozlamalarini tekshiring.';

  @override
  String get errorRefundInstallmentRefused =>
      'Chek muddatli to\'lovga sotilgan — kassa uni qaytarmaydi. Shartnomani bekor qilishni administrator rasmiylashtiradi.';

  @override
  String get errorRefundCashlessUnavailable =>
      'Bu pulni kartaga yoki QR orqali qaytarish kerak, lekin qaytarish vositasi yo\'q: terminal yoki provayder ulanmagan. Kassa bunday qaytarishni tortmadan naqd bermaydi.';

  @override
  String get errorRefundCashlessRefused =>
      'Bank yoki provayder qaytarishni rad etdi. Terminalni tekshirib, qayta urinib ko\'ring — avval qaytarilgani ikkinchi marta qaytarilmaydi.';

  @override
  String get errorRefundKindNotRefundable =>
      'Bu to\'lov turiga qaytarish to\'lov turlari ma\'lumotnomasida taqiqlangan.';

  @override
  String get errorRefundKindUnknown =>
      'Chek ushbu kassa ma\'lumotnomasida yo\'q to\'lov turi bilan to\'langan. Kassa u bo\'yicha qaytarishni amalga oshirmaydi: nima bilan to\'langani noma\'lum, buning uchun naqd pul berilmaydi.';

  @override
  String get refundDestinationsTitle => 'Pul qayerga ketadi';

  @override
  String get refundRouteDrawer => 'Tortmadan naqd';

  @override
  String get refundRouteCard => 'Terminal orqali kartaga';

  @override
  String get refundRouteManual => 'Kassadan tashqari — to\'langan usulda';

  @override
  String get refundRouteProvider => 'QR provayderi orqali';

  @override
  String get refundRouteCertificate =>
      'Yangi sertifikat bilan (eskisi so\'ndirilgan holda qoladi)';

  @override
  String get refundRouteAdvance => 'Xaridorning avans to\'loviga';

  @override
  String get refundRouteBonus => 'Bonus hisobiga';

  @override
  String get refundRouteDebt => 'Xaridor qarzi hisobiga';

  @override
  String get errorCertificateRefundNoSource =>
      'Chek qatori sertifikat bilan qaytariladi, lekin unda sertifikat raqami yo\'q. Kassa u bo\'yicha qaytarishni o\'tkazmaydi: yangi sertifikatni nimaga asoslanib yozish noma\'lum, kassaning majburiyati esa bekorga o\'sardi.';

  @override
  String get errorCertificateCashRefundRefused =>
      'Sertifikat uchun naqd pul bilan qaytarib bo\'lmaydi — naqd pulsiz qaytarish rekvizitlarini ko\'rsating.';

  @override
  String get errorCertificatePaysCertificate =>
      'Sertifikat bilan boshqa sertifikat xaridini to\'lab bo\'lmaydi.';

  @override
  String get errorCreditContractUnknown =>
      'Bunday raqamli muddatli to\'lov shartnomasi yo\'q. Raqamni tekshiring.';

  @override
  String get errorCreditContractNotActive =>
      'Muddatli to\'lov shartnomasi allaqachon to\'langan yoki bekor qilingan — u bo\'yicha to\'lanadigan narsa yo\'q.';

  @override
  String get errorCreditOverpayment =>
      'Summa shartnoma bo\'yicha qoldiqdan ko\'p. Summani tekshiring.';

  @override
  String get errorCreditRepaymentInvalid =>
      'To\'lov summasi noldan katta bo\'lishi kerak.';

  @override
  String get errorCreditAllocationRace =>
      'Aynan shu lahzada shartnoma bo\'yicha boshqa kassadan to\'langan. To\'lovni qaytadan qabul qiling.';

  @override
  String get errorKindTenderCannotDiscount =>
      'Haqiqiy pul olib keladigan to\'lov turini chekda «to\'lov emas» deb e\'lon qilib bo\'lmaydi.';

  @override
  String get errorKindAccountMissing =>
      'To\'lov turiga qabul qiluvchi hisob biriktirilmagan.';

  @override
  String get errorKindCounterpartyRequired =>
      'Keyinga qoldirilgan to\'lov turi nomlangan xaridorni talab qiladi.';

  @override
  String get errorKindProviderRequired =>
      'Provayder (QR) orqali to\'lov turiga provayder kerak.';

  @override
  String get errorKindFiscalKindRequired =>
      'To\'lov turining fiskal talqini ko\'rsatilmagan.';

  @override
  String get errorKindChangeNotATender =>
      'Qaytimni faqat haqiqiy pul olib keladigan tur beradi.';

  @override
  String get errorKindSystemImmutable =>
      'Tizimli to\'lov turining kodi yoki identifikatorini o\'zgartirib ham, boshqa turga berib ham bo\'lmaydi.';

  @override
  String get errorCertificateExpired =>
      'Sertifikat muddati tugagan. Do\'kon egasiga murojaat qiling.';

  @override
  String get errorCertificateExhausted => 'Sertifikatda mablag\' qolmagan.';

  @override
  String get errorCertificateDuplicate =>
      'Bitta sertifikat to\'lovda ikki marta ko\'rsatilgan. Takrorni olib tashlang.';

  @override
  String get errorCertificateRace =>
      'Sertifikat qoldig\'i o\'zgardi. To\'lovni qaytadan bajaring.';

  @override
  String get errorCertificateAccountMissing =>
      'Kassada sertifikatlar bo\'yicha majburiyat hisobi yo\'q. Administratorga murojaat qiling.';

  @override
  String get errorCertificateNumberTaken =>
      'Bunday raqamli sertifikat allaqachon chiqarilgan.';

  @override
  String get errorCertificateNominalInvalid =>
      'Sertifikat qiymati noldan katta bo\'lishi kerak.';

  @override
  String get errorDebtCustomerRequired =>
      'Qarzga sotish xaridorsiz mumkin emas — xaridorni tanlang.';

  @override
  String get errorDebtNotSoldHere =>
      'Bu kassada qarzga savdo qilinmaydi — kreditga sotish kassa sozlamalarida oʻchirilgan.';

  @override
  String get errorDebtAccountMissing =>
      'Xaridorda hisob yo\'q — qarzni yozadigan joy yo\'q.';

  @override
  String get errorBonusAccountMissing =>
      'Xaridorda bonus hisobi yo\'q — bonusni yechish uchun hech narsa yo\'q.';

  @override
  String get errorPrepaymentCustomerRequired =>
      'Avansni hisobga olish uchun xaridor kerak — uni tanlang.';

  @override
  String get errorCreditTermInvalid =>
      'Bo\'lib to\'lashning bunday muddati rasmiylashtirilmaydi';

  @override
  String get errorCreditPrincipalInvalid =>
      'Bo\'lib to\'lash uchun summa yo\'q: chek to\'liq qoplangan';

  @override
  String get errorCreditFeeInvalid => 'Shartnoma bo\'yicha ustama noto\'g\'ri';

  @override
  String get errorCreditSchemeUnknown =>
      'Bunday jadval sxemasini kassa bilmaydi';

  @override
  String get errorCreditOverdue =>
      'Xaridorning boshqa bo\'lib to\'lash shartnomasi muddati o\'tgan';

  @override
  String get errorCreditContractDuplicate =>
      'Bu chekka bo\'lib to\'lash shartnomasi allaqachon rasmiylashtirilgan';

  @override
  String get errorPrepaymentAccountMissing =>
      'Xaridorda hisob yo\'q — unda avans bo\'lishi mumkin emas.';

  @override
  String get errorPrepaymentInsufficient =>
      'Kiritilgan avans yetmadi: u boshqa chek bilan hisobga olingan.';

  @override
  String get errorLoyaltyCustomerUnknown =>
      'Xaridor kartotekada topilmadi. Xaridorni qaytadan tanlang.';

  @override
  String get errorAmountExceedsReceipt =>
      'Summa chek qiymatidan katta. Summani qaytadan kiriting.';

  @override
  String get errorCardChargeUnproven =>
      'Kassa karta orqali to\'lovni tasdiqlamadi. To\'lov terminalini tekshiring.';

  @override
  String get errorPaymentTypeNotAllowed =>
      'Bu to\'lov turi ushbu ish joyida ruxsat etilmagan.';

  @override
  String get errorPaymentsUnavailable =>
      'Bu kassa sim orqali to\'lovni qabul qilmaydi. Administratorga murojaat qiling.';

  @override
  String get errorNoRefundService =>
      'Bu kassa sim orqali qaytarishni amalga oshirmaydi. Administratorga murojaat qiling.';

  @override
  String get errorRefundAbandonIsTillSide =>
      'Qaytarish qoralamasini ish joyi emas, kassa olib tashlaydi.';

  @override
  String get errorNoAnswer =>
      'Kassa javob bermadi. Aloqani tekshirib, qaytadan urinib ko\'ring.';

  @override
  String paymentTypeNotAllowedHere(String type) {
    return '\"$type\" bu ish joyiga ruxsat etilmagan. To‘lov turlari uskuna sozlamalarida o‘zgartiriladi; bosilsa ham kassa ruxsatsiz turni rad etadi.';
  }

  @override
  String paymentTypesLimitedHere(String types) {
    return 'Ish joyi qabul qiladi: $types.';
  }

  @override
  String get paymentDebtNotSoldHere =>
      'Bu kassada qarzga sotilmaydi: kreditga sotish kassa sozlamalarida oʻchirilgan. Tugma bosilsa ham, kassa rad etadi.';

  @override
  String get paymentDebtNotPermitted =>
      'Sizga qarzga sotishga ruxsat yoʻq: «qarzga sotish» huquqi kerak. Uni administrator huquqlar sozlamalarida beradi; huquqi yoʻq har kimga kassa rad javob beradi.';

  @override
  String get saleDiscountNotPermitted =>
      'Sizga chegirma berishga ruxsat yoʻq: «chegirma bilan sotish» huquqi kerak. Uni administrator huquqlar sozlamalarida beradi; huquqi yoʻq har kimga kassa rad javob beradi.';

  @override
  String get paymentDebtPolicyUnknown =>
      'Kassa hozircha bu yerda qarzga sotiladimi yoʻqmi javob bermadi. Kassa bilan aloqani tekshirib, qayta urinib koʻring.';

  @override
  String get paymentOffsetsTitle => 'Avans va sertifikatlar';

  @override
  String get paymentPrepaymentTitle => 'Xaridor avansi';

  @override
  String get paymentPrepaymentNeedsCustomer =>
      'Avansni hisobga olish uchun xaridorni telefon raqami boʻyicha toping.';

  @override
  String get paymentPrepaymentLoading =>
      'Kassa hali qancha avans kiritilganini javob bermadi.';

  @override
  String get paymentPrepaymentNone => 'Xaridorning kiritilgan avansi yoʻq.';

  @override
  String get paymentPrepaymentBalance => 'Oldindan kiritilgan:';

  @override
  String get paymentPrepaymentUse => 'Avansni hisobga olish';

  @override
  String paymentPrepaymentApplied(String amount) {
    return 'Hisobga olinadi: $amount';
  }

  @override
  String get paymentCertificateTitle => 'Sovgʻa sertifikati';

  @override
  String get paymentCertificateNumber => 'Sertifikat raqami';

  @override
  String get paymentCertificatePin => 'PIN, boʻlsa';

  @override
  String get paymentCertificatePresent => 'Tekshirish';

  @override
  String paymentCertificateBalance(String amount) {
    return 'Sertifikatdagi qoldiq: $amount';
  }

  @override
  String paymentCertificateApplied(String amount, String rest) {
    return '$amount yechiladi, $rest qoladi';
  }

  @override
  String get paymentCertificateNotNeeded =>
      'Chek toʻliq yopildi — bu sertifikat kerak boʻlmaydi.';

  @override
  String get unfiscalizedTitle => 'Fiskallashtirilmagan cheklar';

  @override
  String get unfiscalizedEmpty => 'Barcha cheklar fiskallashtirilgan';

  @override
  String get unfiscalizedEmptyHint =>
      'Bu yerda puli olingan, lekin operator hujjat bermagan cheklar paydo bo\'ladi';

  @override
  String unfiscalizedReceiptNo(int number) {
    return 'Chek №$number';
  }

  @override
  String unfiscalizedAgeHours(int hours) {
    return '$hours soat oldin';
  }

  @override
  String get unfiscalizedOverdue => '72 soatlik muddat o\'tib ketdi';

  @override
  String get unfiscalizedRetry => 'Takrorlash';

  @override
  String unfiscalizedRetryDone(String sign) {
    return 'Hujjat olindi: $sign';
  }

  @override
  String unfiscalizedRetryFailed(String message) {
    return 'Operator yana rad etdi: $message';
  }

  @override
  String get unfiscalizedNoDocument =>
      'Qator rad javoblari hujjat olib yura boshlashidan oldin yozilgan: takrorlash uchun hech narsa yo\'q, uni faqat hisobdan chiqarish mumkin';

  @override
  String get unfiscalizedNoOperator =>
      'Fiskal operator sozlanmagan: takrorlashga joy yo\'q';

  @override
  String get unfiscalizedWriteOff => 'Hisobdan chiqarish';

  @override
  String get unfiscalizedWriteOffTitle =>
      'Fiskallashtirilmagan chekni hisobdan chiqarish';

  @override
  String unfiscalizedWriteOffBy(String name) {
    return 'Qaror quyidagi nomga yoziladi: $name';
  }

  @override
  String get unfiscalizedWriteOffReason => 'Hisobdan chiqarish sababi';

  @override
  String get unfiscalizedWriteOffDone =>
      'Chek ko\'rib chiqilgan deb belgilandi';

  @override
  String unfiscalizedWrittenOff(String name, String reason) {
    return '$name hisobdan chiqardi: $reason';
  }

  @override
  String get unfiscalizedUnknownUser => 'noma\'lum foydalanuvchi';

  @override
  String unfiscalizedAtShiftClose(int count, String numbers) {
    return 'Smena fiskallashtirilmagan cheklar bilan yopildi: $count. Raqamlar: $numbers';
  }

  @override
  String documentsOnTheWayAtShiftClose(int count, String numbers) {
    return 'Smena hujjatlari hali operatorda emas: $count (cheklar $numbers). Yopish ularning yuborilishini kutadi; aloqa tiklanmasa, Z-hisobot yuborilmaydi — aks holda operator hisoboti kassa bilan mos kelmaydi.';
  }

  @override
  String qrPaidPartial(String paid, String amount) {
    return 'Оплачено частично: $paid из $amount';
  }

  @override
  String get qrOrphanTitle => 'Деньги без чека';

  @override
  String get qrOrphanHint =>
      'Покупатель заплатил по QR, а чек этими деньгами не закрыт.';

  @override
  String qrOrphanLine(String amount, String provider, String key) {
    return '$amount · $provider · $key';
  }

  @override
  String get qrOrphanAfterGiveUp =>
      'Подтверждение пришло после того, как касса перестала ждать';

  @override
  String get errorQrIntentUnknown =>
      'Kassa bu QR to\'lovini bilmaydi. Chekni yangilang va qayta urinib ko\'ring.';

  @override
  String get errorQrIntentNotPaid =>
      'QR to\'lovini bank hali tasdiqlamadi. Tasdiqni kuting yoki boshqa usulni tanlang.';

  @override
  String errorQrIntentAlreadySettled(String message) {
    return 'Bu pul allaqachon boshqa chekni yopgan: $message';
  }

  @override
  String get paymentQrTitle => 'QR orqali to\'lov';

  @override
  String get paymentQrAmount => 'QR summasi';

  @override
  String get paymentQrStart => 'QR ko\'rsatish';

  @override
  String paymentQrWaiting(int seconds) {
    return 'To\'lov kutilmoqda · $seconds s qoldi';
  }

  @override
  String get paymentQrScanHint => 'Xaridor kodni bank ilovasida skanerlaydi';

  @override
  String get paymentQrCancel => 'Kutishni bekor qilish';

  @override
  String get paymentQrNoLink =>
      'Provayder bilan aloqa yo\'q — kassa so\'rovni o\'zi takrorlaydi';

  @override
  String paymentQrPaid(String amount) {
    return 'QR orqali to\'landi: $amount';
  }

  @override
  String paymentQrPaidAfterCancel(String amount) {
    return 'Xaridor bekor qilishdan oldin to\'lab ulgurdi — $amount shu chekka tushadi';
  }

  @override
  String get paymentQrCancelled => 'Kutish bekor qilindi, provayder tasdiqladi';

  @override
  String get paymentQrPatienceSpent =>
      'Xaridor belgilangan vaqtda to\'lamadi — kassa kutishni to\'xtatdi';

  @override
  String get paymentQrExpired => 'QR kodning muddati provayderda tugadi';

  @override
  String get paymentQrFailed => 'Provayder QR to\'lovini rad etdi';

  @override
  String get paymentQrCancelUnconfirmed =>
      'Bekor qilish tasdiqlanmadi — pul hali kelishi mumkin. Kassa aniqlamaguncha boshqa to\'lovni qabul qilmang.';

  @override
  String get paymentQrRecheck => 'Qayta tekshirish';

  @override
  String get paymentQrRestart => 'Yangi kod';

  @override
  String paymentQrOverReceipt(String amount) {
    return 'QR to\'lovidan $amount chekka sig\'maydi';
  }

  @override
  String get paymentQrNothingToPay =>
      'Chek allaqachon yopilgan — kod ko\'rsatishga hojat yo\'q';

  @override
  String get errorQrNotConfigured => 'Kassada QR provayderi sozlanmagan';

  @override
  String get errorQrNetwork => 'QR provayderi bilan aloqa yo\'q';

  @override
  String get errorQrTimeout => 'QR provayderi o\'z vaqtida javob bermadi';

  @override
  String get errorQrProviderBusy => 'QR provayderi band — kassa takrorlaydi';

  @override
  String get errorQrMalformedReply =>
      'QR provayderi tushunarsiz javob berdi — kassa administratoriga murojaat qiling';

  @override
  String get errorQrUnknownIntent => 'QR provayderi bu to\'lovni bilmaydi';

  @override
  String get errorQrRejected => 'QR provayderi so\'rovni rad etdi';

  @override
  String get errorQrReverseUnsupported => 'QR provayderi pulni qaytara olmaydi';

  @override
  String get errorQrIntentLive =>
      'Bu chekda QR to\'lovi kutilmoqda — yangi kod ko\'rsatishdan oldin uni bekor qiling';

  @override
  String get fiscalReasonNetwork => 'Fiskal operator bilan aloqa yo‘q';

  @override
  String get fiscalReasonOperatorUnavailable => 'Fiskal operator ishlamayapti';

  @override
  String get fiscalReasonTokenExpired =>
      'Operator kassa avtorizatsiyasini qabul qilmadi';

  @override
  String get fiscalReasonRequestNotBuilt =>
      'Operatorga so‘rov tuzilmadi: fiskal sozlamalardagi server manzilini tekshiring';

  @override
  String get fiscalReasonTlsRejected =>
      'Operator bilan himoyalangan ulanish o‘rnatilmadi: server manzilini va kassa soatini tekshiring';

  @override
  String get fiscalReasonClientFault =>
      'Operator bilan almashishda kassa nosozligi';

  @override
  String get fiscalReasonBadCredentials =>
      'Operator logini yoki paroli noto‘g‘ri';

  @override
  String get fiscalReasonCashboxNotFound =>
      'Operator bu kassani topmadi: zavod raqamini tekshiring';

  @override
  String get fiscalReasonCashboxBlocked =>
      'Kassa operator tomonidan bloklangan';

  @override
  String get fiscalReasonOfflineLimitExceeded =>
      'Avtonom hujjatlar chegarasi oshib ketdi';

  @override
  String get fiscalReasonOfflineNotSupported =>
      'Bu kassaga avtonom rejim ruxsat etilmagan';

  @override
  String get fiscalReasonDuplicate =>
      'Hujjat operatorda allaqachon ro‘yxatdan o‘tgan, lekin fiskal belgi kassaga berilmadi — uni operator kabinetidan oling';

  @override
  String get fiscalReasonValidation =>
      'Operator hujjatni rad etdi: summalar yoki ma’lumotlar mos emas';

  @override
  String get fiscalReasonNotEnoughMoney =>
      'Operator ma’lumotiga ko‘ra kassada naqd pul yetarli emas';

  @override
  String get fiscalReasonShiftError => 'Operatorda smena xatosi';

  @override
  String get fiscalReasonUnsupported =>
      'Amal operator tomonidan qo‘llab-quvvatlanmaydi';

  @override
  String get fiscalReasonNotConfigured => 'Fiskallashtirish sozlanmagan';

  @override
  String get fiscalReasonUnknown => 'Operator noma’lum sabab bilan rad etdi';

  @override
  String get fiscalReasonOfflineWindowExpired =>
      '72 soatlik avtonom oyna tugadi — hujjat berilmadi';

  @override
  String get fiscalReasonRowUnreadable =>
      'Navbat qatori shikastlangan: hujjat o‘qilmaydi';

  @override
  String fiscalReasonWithCode(String reason, int code) {
    return '$reason (kod $code)';
  }

  @override
  String fiscalReasonLegacy(String text) {
    return 'Sabab tarjimadan oldin yozilgan: $text';
  }

  @override
  String get fiscalReasonNotRecorded => 'Sabab yozilmagan';

  @override
  String get fiscalReasonPaymentTypeNotAccepted =>
      'To‘lov turi operator tomonidan qabul qilinmaydi: «kredit» va «tara» OFD 2.0.2 protokolidan chiqarilgan';

  @override
  String get errorDeferredListUnavailable =>
      'Kechiktirilgan cheklar ro\'yxati mavjud emas';

  @override
  String errorDeferredListUnavailableReason(String reason) {
    return 'Kechiktirilgan cheklar ro\'yxati mavjud emas: $reason';
  }

  @override
  String get errorRefundSearchUnavailable =>
      'Bu terminalda qaytarish uchun mahsulot qidirish hali ulanmagan';

  @override
  String get errorRefundNothingSelected =>
      'Qoralama o\'zgardi — qaytariladigan narsa yo\'q. Belgilangan qatorlarni tekshiring.';

  @override
  String get errorRefundInvalidAmount =>
      'Bunchani qaytarib bo\'lmaydi: miqdor chek bo\'yicha sotilgandan ko\'p yoki noldan kam bo\'lishi mumkin emas.';

  @override
  String get errorCertificatePinRequired =>
      'Sertifikatda PIN-kod bor. Sertifikatdagi PIN-kodni kiriting.';

  @override
  String get qrSettingsTitle => 'QR orqali to\'lov';

  @override
  String get qrSettingsSubtitle => 'QR provayderi: manzil, kod, kalit, kutish';

  @override
  String get qrSettingsKindTitle => 'QR orqali to\'lov qabul qilish';

  @override
  String get qrSettingsKindSubtitle => 'To\'lov ekranidagi «QR» to\'lov turi';

  @override
  String get qrSettingsUrl => 'Provayder manzili';

  @override
  String get qrSettingsCode => 'Provayder kodi';

  @override
  String get qrSettingsKey => 'Kirish kaliti';

  @override
  String get qrSettingsKeyStoredHint =>
      'Kalit saqlangan. Almashtirish uchun yangisini kiriting';

  @override
  String get qrSettingsKeyEmptyHint => 'Kalit berilmagan';

  @override
  String get qrSettingsClearKey => 'Saqlangan kalitni o\'chirish';

  @override
  String get qrSettingsPatience => 'To\'lovni kutish, soniya';

  @override
  String get qrSettingsSave => 'Saqlash';

  @override
  String get qrSettingsSaved => 'QR sozlamasi saqlandi';

  @override
  String get qrSettingsRemove => 'Sozlamani olib tashlash';

  @override
  String get qrSettingsStatusReady => 'Provayder sozlangan';

  @override
  String get qrSettingsStatusNotConfigured =>
      'Provayder sozlanmagan — QR orqali to\'lov mavjud emas';

  @override
  String get qrSettingsInvalidUrl =>
      'Manzil http:// yoki https:// bilan boshlanishi kerak';

  @override
  String get qrSettingsCodeRequired => 'Provayder kodini kiriting';

  @override
  String qrSettingsInvalidPatience(String min, String max) {
    return 'Kutish — $min soniyadan $max soniyagacha';
  }

  @override
  String get qrSettingsSaveFailed => 'QR sozlamasini saqlab bo\'lmadi';

  @override
  String get qrSettingsTillOnly =>
      'QR provayderini sozlash faqat kassaning o\'zida mavjud';

  @override
  String get installmentTermsTitle => 'Muddatli to\'lov';

  @override
  String get installmentTermsMonths => 'Muddati, oy';

  @override
  String get installmentTermsScheme => 'Jadval turi';

  @override
  String get installmentTermsContinue => 'Davom etish';

  @override
  String get customerPaymentTitle => 'To\'lov qabul qilish / qarzni to\'lash';

  @override
  String customerPaymentCurrentDebt(String amount) {
    return 'Joriy qarz: $amount';
  }

  @override
  String customerPaymentBalance(String amount) {
    return 'Balans: $amount';
  }

  @override
  String get customerPaymentAmount => 'To\'lov summasi';

  @override
  String get customerPaymentAmountInvalid => '0 dan katta summani kiriting';

  @override
  String get customerPaymentFailed => 'To\'lovni o\'tkazishda xato';

  @override
  String get customerPaymentSubmit => 'To\'lov qabul qilish';

  @override
  String get errorPrepaymentAmountInvalid =>
      'Avans summasi noldan katta bo\'lishi kerak. Summani qaytadan kiriting.';

  @override
  String get errorPrepaymentTenderInvalid =>
      'Avans naqd pul, karta yoki QR orqali qabul qilinadi. Boshqa to\'lov turini tanlang.';

  @override
  String get errorPrepaymentTillAccountMissing =>
      'Bu kassada ushbu to\'lov turini qabul qiladigan hisob yo\'q. Qabul hisobini sozlab, qayta urining.';

  @override
  String get errorPrepaymentIntakeFailed =>
      'Avansni qabul qilib bo\'lmadi. Xaridorni tekshiring va qaytadan urinib ko\'ring.';

  @override
  String get errorPrepaymentRefundExceedsBalance =>
      'Xaridor hisobidagi avans siz bermoqchi bo\'lgan summadan kam. Qoldiqni tekshiring va summani kamaytiring.';

  @override
  String get errorPrepaymentRefundKeyMissing =>
      'Avansni qaytarish arizasida takror kaliti yo\'q — kassa takrorni ikkinchi to\'lovdan ajrata olmaydi. Ekranni qaytadan oching va summani yana kiriting.';

  @override
  String get errorPrepaymentRefundFailed =>
      'Avansni qaytarib bo‘lmadi. Xaridorni tekshiring va qayta urinib ko‘ring.';

  @override
  String get errorPrepaymentRefundUnavailable =>
      'Bu kassa xaridor avansini sim orqali qaytarmaydi. Administratorga murojaat qiling.';

  @override
  String get errorPrepaymentIntakeUnavailable =>
      'Bu kassa xaridor avansini sim orqali qabul qilmaydi. Administratorga murojaat qiling.';

  @override
  String get errorPrepaymentIntakeKeyMissing =>
      'Bu avans arizasida takrorlash kaliti yo\'q, shuning uchun kassa takrorlashni ikkinchi to\'lovdan ajrata olmaydi. Ekranni qayta oching va summani qaytadan kiriting.';

  @override
  String get errorQrSetupUnavailable =>
      'Bu kassada QR provayder sozlamasi saqlanmaydi. QR orqali toʻlovni kassaning oʻzida sozlang yoki administratorga murojaat qiling.';

  @override
  String get errorReceiptTemplatesUnavailable =>
      'Bu kassada chek shablonlari saqlanmaydi. Shablonni kassaning oʻzida sozlang yoki administratorga murojaat qiling.';

  @override
  String get errorReceiptTemplateNameless =>
      'Chek shabloni nomga ega boʻlishi shart. Nomini kiriting va qayta saqlang.';

  @override
  String get shiftDeskTitle => 'Smena';

  @override
  String get shiftDeskOverAgeWarning =>
      'Smena 24 soatdan ortiq ochiq — sotuv bloklangan. Uni yoping va yangisini oching.';

  @override
  String shiftDeskOpenedAt(String when) {
    return 'Ochilgan: $when';
  }

  @override
  String get shiftDeskCountedLabel => 'Yashikda sanaldi';

  @override
  String get shiftDeskCountedHint =>
      'Hech kim sanamagan boʻlsa, boʻsh qoldiring — kassa oʻz yakunini oladi.';

  @override
  String get shiftDeskOpeningCashLabel => 'Boshlanishda yashikdagi pul';

  @override
  String get shiftDeskClosedNow => 'Smena yopildi.';

  @override
  String get shiftDeskOpenedNow => 'Smena ochildi.';

  @override
  String get shiftDeskNoShift => 'Kassada ochiq smena yoʻq.';

  @override
  String shiftDeskUnfiscalizedCount(int count) {
    return 'Fiskal hujjatsiz cheklar: $count';
  }

  @override
  String shiftDeskUnfinishedCount(int count) {
    return 'Tugallanmagan cheklar: $count — yopish ularni tozalaydi';
  }

  @override
  String get errorShiftDeskNotOpen =>
      'Bu kassada ochiq smena yoʻq — yopadigan narsa yoʻq.';

  @override
  String get errorShiftDeskAlreadyOpen => 'Bu kassada smena allaqachon ochiq.';

  @override
  String get errorShiftDeskUnavailable =>
      'Bu kassa smenalarni sim orqali yuritmaydi. Smenani kassaning oʻzida yoping yoki administratorga murojaat qiling.';

  @override
  String get errorShiftDeskActorUnknown =>
      'Smenani kassir ochadi, bu soʻrovda kassir atalmagan. Qaytadan kiring.';

  @override
  String get prepaymentIntakeTitle => 'Avans qabul qilish';

  @override
  String get prepaymentIntakeFind => 'Xaridorni topish';

  @override
  String get prepaymentIntakeNotFound => 'Bunday raqamli xaridor topilmadi.';

  @override
  String get prepaymentIntakeSubmit => 'Avansni qabul qilish';

  @override
  String prepaymentIntakeAccepted(String amount) {
    return 'Avans qabul qilindi. Oldindan kiritilgan: $amount';
  }

  @override
  String get prepaymentIntakeFiscalFailed =>
      'Pul qabul qilindi, lekin avansning fiskal cheki yozilmadi.';

  @override
  String get emulatorSettingsTitle => 'O‘rnatilgan emulyatorlar';

  @override
  String get emulatorSettingsHint =>
      'Asboblarni ulamasdan chop etish va diagnostikani tekshirish';

  @override
  String get emulatorReceiptPrinter => 'Chek printeri va pul qutisi';

  @override
  String get emulatorEnabledNote =>
      'Soket ochiq. Kassa unga faqat bog‘lanishdagi manzil orqali yetadi';

  @override
  String get emulatorDisabledNote => 'O‘chiq: soket ochilmagan';

  @override
  String get emulatorAddress => 'Emulyator manzili';

  @override
  String get emulatorAddressHint =>
      'Ushbu IP va portni printer sozlamalariga yozing';

  @override
  String get emulatorBindAction => 'Printer bog‘lanishiga yozish';

  @override
  String get emulatorBindDone => 'Printer bog‘lanishi endi emulyatorga qaraydi';

  @override
  String get emulatorBindingStale =>
      'Printer bog‘lanishi o‘chirilgan emulyatorga qaraydi — chop etish bajarilmaydi';

  @override
  String get emulatorStartFailed => 'Emulyatorni ishga tushirib bo‘lmadi';

  @override
  String get emulatorFiscalOperator => 'Fiskal operator (OFD)';

  @override
  String get emulatorFiscalAddressHint =>
      'Ushbu manzilni fiskal sozlamalardagi «Server manzili» maydoniga yozing';

  @override
  String get emulatorFiscalBindAction => 'Fiskal sozlamalarga yozish';

  @override
  String get emulatorFiscalBindNote =>
      'Emulyator manzili, logini, paroli, kaliti va zavod raqamini yozadi hamda kassani sinov kassasi deb e’lon qiladi. Ro‘yxatga olish raqamiga tegilmaydi';

  @override
  String get emulatorFiscalBindDone =>
      'Fiskal sozlamalar endi emulyatorga qaraydi';

  @override
  String get emulatorFiscalBindingStale =>
      'Fiskal sozlamalar o‘chirilgan emulyatorga qaraydi — fiskallashtirish rad etiladi';

  @override
  String get emulatorFiscalLocalModuleWarning =>
      '«Mahalliy modul» maydoni to‘ldirilgan — u server manzilini bosib ketadi, kassa emulyatorga bormaydi';

  @override
  String get emulatorFiscalBlockedLive =>
      'Kassa jangovar: operator rekvizitlari to‘ldirilgan. Bu yerda OFD emulyatori taqiqlanadi — soxtaga ketgan chek haqiqiydek ko‘rinadi, ammo xaridorga hujjat bermaydi';

  @override
  String get emulatorFiscalBlockedUnknown =>
      'Fiskal sozlamalar o‘qilmadi — OFD emulyatorini yoqib bo‘lmaydi';

  @override
  String get diagnosticsFiscalEmulatorBanner =>
      'Operator manzili shu kompyuterga qaraydi — hujjatlar emulyatorga ketadi va fiskal hisoblanmaydi';

  @override
  String get diagnosticsTitle => 'Uskuna diagnostikasi';

  @override
  String get diagnosticsSubtitle => 'Kassa asboblarga aslida nima yuborgani';

  @override
  String get diagnosticsTabPrinter => 'Printer';

  @override
  String get diagnosticsTabFiscal => 'Fiskallashtirish';

  @override
  String get errorDiagnosticsUnavailable =>
      'Bu kassada diagnostikani so\'raydigan hech kim yo\'q';

  @override
  String get diagnosticsPrinterQueueMissing =>
      'Bu ish o\'rnida chop etish navbati sozlanmagan';

  @override
  String get diagnosticsPrinterNothingSent =>
      'Kassa printerga hozircha hech narsa yubormadi';

  @override
  String diagnosticsAskFailed(String reason) {
    return 'Kassa bu savolga javob bermadi: $reason';
  }

  @override
  String diagnosticsAttempts(int count) {
    return 'urinish $count';
  }

  @override
  String get diagnosticsJobQueued => 'navbatda turibdi';

  @override
  String get diagnosticsJobPrinting => 'chop etilmoqda';

  @override
  String get diagnosticsJobPrinted => 'chop etildi';

  @override
  String get diagnosticsJobFailed => 'chop etilmadi';

  @override
  String get diagnosticsJobExpired => 'muddati o\'tdi';

  @override
  String get diagnosticsJobCancelled => 'bekor qilindi';

  @override
  String get diagnosticsFiscalNotConfigured =>
      'Bu kassada fiskal operator sozlanmagan';

  @override
  String get diagnosticsFiscalAccepted => 'Operator qabul qildi';

  @override
  String get diagnosticsFiscalAcceptedEmpty =>
      'Operator hozircha bironta hujjatni qabul qilmadi';

  @override
  String get diagnosticsFiscalQueued => 'Navbatda';

  @override
  String get diagnosticsFiscalQueuedEmpty =>
      'Navbat bo\'sh — yuborilganlarning hammasini operator qabul qildi';

  @override
  String diagnosticsFiscalSign(String value) {
    return 'Fiskal belgi $value';
  }

  @override
  String diagnosticsFiscalOperatorDoc(String value) {
    return 'operator hujjati $value';
  }

  @override
  String diagnosticsFiscalReceiptNo(String value) {
    return 'chek $value';
  }

  @override
  String get diagnosticsFiscalOffline => 'mustaqil berilgan';

  @override
  String get diagnosticsEmulatorBanner =>
      'Printer bog‘lanishi shu kompyuterga qaraydi — port ortida qog‘oz emas, emulyator';

  @override
  String get diagnosticsTabDrawer => 'Pul qutisi';

  @override
  String get drawerDiagnosticsEmpty =>
      'Kassa ishga tushganidan beri quti biror marta ham ochilmadi';

  @override
  String get drawerDiagnosticsUnavailable =>
      'Bu kassada quti impulslari yozuvi yo\'q — so\'raydigan narsa yo\'q. Bu quti ochilmagan degani emas.';

  @override
  String get drawerDiagnosticsCaveat =>
      'Kassa faqat buyruq qabul qilinganini biladi. Qutining haqiqatan ochilgani haqida ikkala yo‘lda ham qaytar aloqa yo‘q.';

  @override
  String get drawerDiagnosticsAccepted => 'Buyruq qabul qilindi';

  @override
  String get drawerDiagnosticsRefused => 'Buyruq rad etildi';

  @override
  String get drawerDiagnosticsViaSerial => 'ketma-ket port';

  @override
  String get drawerDiagnosticsViaPrinter => 'printer orqali (ESC p)';

  @override
  String get diagnosticsTabScales => 'Tarozi';

  @override
  String get diagnosticsTabDisplay => 'Displey';

  @override
  String get scalesDiagnosticsUnbound =>
      'Bu kassaga tarozi bog‘lanmagan.\nUni uskuna sozlamalarida bog‘lang — shunda bu yerda ko‘rsatkich paydo bo‘ladi.';

  @override
  String get scalesDiagnosticsWeight => 'Tarozi ko‘rsatkichi';

  @override
  String get scalesDiagnosticsSilent => 'Tarozi hali hech narsa yubormadi';

  @override
  String get scalesDiagnosticsStable => 'Og‘irlik barqarorlashdi';

  @override
  String get scalesDiagnosticsSettling => 'Og‘irlik o‘zgarmoqda';

  @override
  String get scalesDiagnosticsOverload => 'Ortiqcha yuk';

  @override
  String get scalesDiagnosticsPort => 'Tarozi porti';

  @override
  String get scalesDiagnosticsBaudSuffix => 'bod';

  @override
  String get scalesDiagnosticsConnected => 'Port ochiq';

  @override
  String get scalesDiagnosticsDisconnected => 'Port yopiq';

  @override
  String get scalesDiagnosticsCaveat =>
      'Bu — asbob yuborgani. Ko‘rsatkich to‘g‘riligini kassa tekshirmaydi, buning uchun tekshiruv bor.';

  @override
  String get displayDiagnosticsEmpty =>
      'Kassa ishga tushganidan beri displeyga hech narsa yuborilmadi';

  @override
  String get displayDiagnosticsUnavailable =>
      'Bu kassada displey satrlari yozuvi yo\'q — so\'raydigan narsa yo\'q. Bu displeyga hech narsa yuborilmagan degani emas.';

  @override
  String get displayDiagnosticsCurrent => 'Hozir displeyda';

  @override
  String get displayDiagnosticsCaveat =>
      'Kassa faqat satr portga ketganini biladi. O‘chgan yoki uzilgan displey bu yerda ishlayotganidan farq qilmaydi.';

  @override
  String get displayDiagnosticsCallPrice => 'narx';

  @override
  String get displayDiagnosticsCallTotal => 'jami';

  @override
  String get displayDiagnosticsCallChange => 'qaytim';

  @override
  String get displayDiagnosticsCallText => 'matn';

  @override
  String get displayDiagnosticsCallWelcome => 'salomlashuv';

  @override
  String get displayDiagnosticsCallClear => 'tozalash';

  @override
  String get emulatorScaleWeight => 'Tovoqdagi og‘irlik';

  @override
  String get emulatorScaleWeightHint =>
      'Emulyator puldi: tarozi kassaga shu sonni yuboradi';

  @override
  String get emulatorQrProvider => 'QR to\'lov provayderi';

  @override
  String get emulatorQrAddressHint =>
      'Bu manzilni QR provayderi sozlamasiga yozing';

  @override
  String get emulatorQrBindAction => 'QR sozlamasiga yozish';

  @override
  String get emulatorQrBindDone => 'QR sozlamasi endi emulyatorga qaraydi';

  @override
  String get emulatorQrBindingStale =>
      'QR sozlamasi o\'chirilgan emulyatorga qaraydi — kod bo\'yicha to\'lov rad etiladi';

  @override
  String get diagnosticsTabPayment => 'To\'lov';

  @override
  String get diagnosticsPaymentEmulatorBanner =>
      'QR provayderi shu kompyuterda: manzil ortida bank emas, emulyator';

  @override
  String get paymentDiagnosticsUnavailable =>
      'Bu ish o\'rnida to\'lov haqida ma\'lumot yo\'q';

  @override
  String get paymentDiagnosticsQrSection => 'QR orqali to\'lov';

  @override
  String get paymentDiagnosticsQrEmpty =>
      'Kassa hozircha bironta to\'lov kodini yaratmadi';

  @override
  String get paymentDiagnosticsQrNotConfigured =>
      'Bu kassada QR provayderi sozlanmagan';

  @override
  String paymentDiagnosticsQrAddress(String address) {
    return 'Provayder: $address';
  }

  @override
  String get paymentDiagnosticsQrUnknown =>
      'Provayderga yuborilgan so\'rov tanalarini kassa saqlamaydi. Ko\'rinadigani — niyatda qolgani: summa, holat, u tomondagi identifikator va rad etish sababi.';

  @override
  String get paymentDiagnosticsTerminalSection => 'To\'lov terminali';

  @override
  String get paymentDiagnosticsTerminalEmpty =>
      'Kassa ishga tushgandan beri to\'lov terminaliga bironta kadr ketmadi';

  @override
  String get paymentDiagnosticsTerminalUnknown =>
      'Terminal jurnali xotirada turadi: qayta ishga tushirishgacha bo\'lgan almashinuvlar saqlanmaydi, terminalning o\'zida bajarilgan amallarni esa kassa umuman ko\'rmaydi.';

  @override
  String get paymentDiagnosticsRequest => 'So\'rov';

  @override
  String get paymentDiagnosticsReply => 'Javob';

  @override
  String get paymentDiagnosticsNoReply => 'Javob bo\'lmadi';

  @override
  String paymentDiagnosticsApproval(String value) {
    return 'Ma\'qullash kodi $value';
  }

  @override
  String paymentDiagnosticsTransaction(String value) {
    return 'tranzaksiya $value';
  }

  @override
  String paymentDiagnosticsRefusal(String value) {
    return 'Rad etildi: $value';
  }

  @override
  String paymentDiagnosticsConfirmations(int count) {
    return 'tasdiqlar soni $count';
  }

  @override
  String get paymentDiagnosticsOrphanMoney => 'cheksiz pul';

  @override
  String get paymentDiagnosticsAfterGiveUp =>
      'kassa kutishni to\'xtatgandan keyin tasdiqlandi';

  @override
  String get paymentDiagnosticsApproved => 'Ma\'qullandi';

  @override
  String get paymentDiagnosticsDeclined => 'Rad etildi';

  @override
  String get paymentDiagnosticsOpPurchase => 'xarid';

  @override
  String get paymentDiagnosticsOpReversal => 'storno';

  @override
  String get paymentDiagnosticsOpRefund => 'qaytarish';

  @override
  String get paymentDiagnosticsOpUnknown => 'noma\'lum turdagi kadr';

  @override
  String get certificateIssueTitle => 'Sovg\'a sertifikatini chiqarish';

  @override
  String get certificateIssueHint =>
      'Qog\'oz uchun pulni sotuv cheki qabul qiladi. Bu yerda qog\'ozga qoldiq ochiladi, kassa majburiyat oladi.';

  @override
  String get certificateIssueNumber => 'Qog\'oz raqami';

  @override
  String get certificateIssueNominal => 'Nominal';

  @override
  String get certificateIssuePin => 'PIN (majburiy emas)';

  @override
  String get certificateIssueExpiresDays =>
      'Amal qilish muddati, kun (majburiy emas)';

  @override
  String get certificateIssueReceipt =>
      'Sotuv chekining raqami (majburiy emas)';

  @override
  String get certificateIssueSubmit => 'Sertifikat chiqarish';

  @override
  String certificateIssueDone(String number, String amount) {
    return '$number sertifikati $amount summaga chiqarildi';
  }

  @override
  String get certificateIssueFailed => 'Sertifikat chiqarilmadi';

  @override
  String get certificateIssueNumberRequired => 'Qog\'oz raqamini kiriting';

  @override
  String get certificateIssueNominalInvalid =>
      'Nominal noldan katta bo\'lishi kerak';

  @override
  String get certificateIssueNotPermitted =>
      'Bu kassirga sertifikat chiqarishga ruxsat yo\'q';

  @override
  String get certificateSlipTitle => 'Slipni qayta chop etish';

  @override
  String get certificateSlipHint =>
      'Chiqarishda slip chop etilmadi — qog\'ozni takroriy slip bo\'yicha berish mumkin.';

  @override
  String get certificateSlipNumber => 'Sertifikat raqami';

  @override
  String get certificateSlipPin => 'PIN, agar bo\'lsa';

  @override
  String get certificateSlipSubmit => 'Slipni chop etish';

  @override
  String certificateSlipDone(String number) {
    return '$number sertifikatining slipi chop etishga yuborildi';
  }

  @override
  String get certificateSlipFailed => 'Slip chop etishga yuborilmadi';

  @override
  String get certificateSlipUnavailable =>
      'Bu kassada slipni chop etadigan qurilma yo\'q';

  @override
  String get prepaymentRefundTitle => 'Avansni qaytarish';

  @override
  String get prepaymentRefundHint =>
      'Xaridor oldindan kiritgan pul qaytariladi. Qarz bu bilan to\'lanmaydi, bonuslarga tegilmaydi.';

  @override
  String prepaymentRefundBalance(String amount) {
    return 'Oldindan kiritilgan: $amount';
  }

  @override
  String get prepaymentRefundNothing =>
      'Xaridor hisobida avans yo\'q — qaytaradigan narsa yo\'q';

  @override
  String get prepaymentRefundAmount => 'Qaytariladigan summa';

  @override
  String get prepaymentRefundTender => 'Nima bilan qaytariladi';

  @override
  String get prepaymentRefundIntake =>
      'Qabul qilish yozuvining raqami (majburiy emas)';

  @override
  String get prepaymentRefundSubmit => 'Avansni qaytarish';

  @override
  String prepaymentRefundDone(String amount) {
    return 'Avans qaytarildi. Hisobda qolgani: $amount';
  }

  @override
  String get prepaymentRefundFailed => 'Avans qaytarilmadi';

  @override
  String get prepaymentRefundAmountInvalid =>
      'Summa noldan katta bo\'lishi kerak';

  @override
  String get prepaymentRefundNotPermitted =>
      'Bu kassirga avansni qaytarishga ruxsat yo\'q';

  @override
  String get prepaymentRefundFiscalFailed =>
      'Pul berildi, lekin avans qaytarimining fiskal cheki yozilmadi.';

  @override
  String get agentRefundPrepayment => 'Avansni qaytarish';
}
