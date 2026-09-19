// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get navReports => 'Отчёты';

  @override
  String get navStock => 'Склад';

  @override
  String get appName => 'TelePOS';

  @override
  String get globalOk => 'ОК';

  @override
  String get globalCancel => 'Отмена';

  @override
  String get globalYes => 'Да';

  @override
  String get globalNo => 'Нет';

  @override
  String get globalSave => 'Сохранить';

  @override
  String get globalNew => 'Новый';

  @override
  String get globalDelete => 'Удалить';

  @override
  String get globalEdit => 'Редактировать';

  @override
  String get globalAdd => 'Добавить';

  @override
  String get globalSearch => 'Поиск';

  @override
  String get globalClose => 'Закрыть';

  @override
  String get globalBack => 'Назад';

  @override
  String get globalNext => 'Далее';

  @override
  String get globalDone => 'Готово';

  @override
  String get globalLoading => 'Загрузка...';

  @override
  String get globalError => 'Ошибка';

  @override
  String get globalSuccess => 'Успешно';

  @override
  String get globalWarning => 'Внимание';

  @override
  String get globalInfo => 'Информация';

  @override
  String get globalConfirm => 'Подтвердить';

  @override
  String get globalClear => 'Очистить';

  @override
  String get globalSelect => 'Выбрать';

  @override
  String get globalAll => 'Все';

  @override
  String get globalNone => 'Нет';

  @override
  String get globalTotal => 'Итого';

  @override
  String get globalAmount => 'Сумма';

  @override
  String get globalQuantity => 'Количество';

  @override
  String get globalPrice => 'Цена';

  @override
  String get globalDiscount => 'Скидка';

  @override
  String get globalDate => 'Дата';

  @override
  String get globalTime => 'Время';

  @override
  String get loginTitle => 'Вход в систему';

  @override
  String get loginPin => 'Введите PIN';

  @override
  String get loginPinHint => '4 цифры';

  @override
  String get loginEnter => 'Войти';

  @override
  String get loginSelectUser => 'Выберите пользователя';

  @override
  String get loginNoUsers => 'Нет пользователей';

  @override
  String get loginWrongPin => 'Неверный PIN';

  @override
  String get loginBlocked => 'Пользователь заблокирован';

  @override
  String get loginSessionExpired => 'Сессия истекла';

  @override
  String get loginShiftRequired => 'Откройте смену для входа';

  @override
  String get loginCashier => 'Кассир';

  @override
  String get loginAdmin => 'Администратор';

  @override
  String get loginManager => 'Менеджер';

  @override
  String get loginLogout => 'Выход';

  @override
  String get loginSwitchUser => 'Сменить пользователя';

  @override
  String get saleTitle => 'Продажа';

  @override
  String get saleNewSale => 'Новая продажа';

  @override
  String get saleAddProduct => 'Добавить товар';

  @override
  String get saleScanBarcode => 'Сканировать штрих-код';

  @override
  String get saleEnterBarcode => 'Введите штрих-код';

  @override
  String get saleProductNotFound => 'Товар не найден';

  @override
  String get saleEmptyCart => 'Корзина пуста';

  @override
  String get saleSubtotal => 'Подытог';

  @override
  String get saleTax => 'НДС';

  @override
  String get saleTotalDiscount => 'Скидка';

  @override
  String get saleToPay => 'К оплате';

  @override
  String saleItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count товаров',
      few: '$count товара',
      one: '$count товар',
    );
    return '$_temp0';
  }

  @override
  String paymentCardChargeUnsettled(String amount) {
    return 'Карта уже проведена на $amount, и эта сумма не попадёт в чек. Отмените операцию на платёжном терминале.';
  }

  @override
  String get saleRemoveItem => 'Удалить товар';

  @override
  String get saleClearCart => 'Очистить корзину';

  @override
  String get saleConfirmClear => 'Очистить корзину?';

  @override
  String get saleProceedPayment => 'Перейти к оплате';

  @override
  String get saleHold => 'Отложить';

  @override
  String get saleRecall => 'Вернуть';

  @override
  String get saleHeldSales => 'Отложенные продажи';

  @override
  String get saleNoHeldSales => 'Нет отложенных продаж';

  @override
  String get saleProductSearch => 'Поиск товаров';

  @override
  String get saleByCategory => 'По категориям';

  @override
  String get saleByName => 'По названию';

  @override
  String get saleByBarcode => 'По штрих-коду';

  @override
  String get saleWeight => 'Вес';

  @override
  String saleWeightKg(String weight) {
    return 'Вес: $weight кг';
  }

  @override
  String get saleEnterWeight => 'Введите вес';

  @override
  String get saleEnterQuantity => 'Введите количество';

  @override
  String get saleEnterPrice => 'Введите цену';

  @override
  String get saleFreePrice => 'Свободная цена';

  @override
  String saleMaxDiscount(String percent) {
    return 'Макс. скидка: $percent%';
  }

  @override
  String get refundTitle => 'Возврат';

  @override
  String get refundNewRefund => 'Новый возврат';

  @override
  String get refundByReceipt => 'По чеку';

  @override
  String get refundWithoutReceipt => 'Без чека';

  @override
  String get refundEnterReceipt => 'Введите номер чека';

  @override
  String get refundReceiptNotFound => 'Чек не найден';

  @override
  String get refundSelectItems => 'Выберите товары для возврата';

  @override
  String get refundReason => 'Причина возврата';

  @override
  String get refundConfirm => 'Подтвердить возврат';

  @override
  String get refundAmount => 'Сумма возврата';

  @override
  String get refundComplete => 'Возврат выполнен';

  @override
  String get refundCash => 'Возврат наличными';

  @override
  String get refundCard => 'Возврат на карту';

  @override
  String get refundConnectionLostHint =>
      'Терминал сам вернётся к кассе — работа продолжится с того же места';

  @override
  String get refundConnectionLost => 'Связь с кассой потеряна';

  @override
  String get refundNoItems => 'Нет товаров для возврата';

  @override
  String get refundAlreadyRefunded => 'Товар уже возвращён';

  @override
  String get refundPartial => 'Частичный возврат';

  @override
  String get shiftTitle => 'Смена';

  @override
  String get shiftOpen => 'Открыть смену';

  @override
  String get shiftClose => 'Закрыть смену';

  @override
  String get shiftCurrent => 'Текущая смена';

  @override
  String shiftNumber(int number) {
    return 'Номер смены: $number';
  }

  @override
  String shiftOpenedAt(String time) {
    return 'Открыта: $time';
  }

  @override
  String shiftCashier(String name) {
    return 'Кассир: $name';
  }

  @override
  String shiftSalesCount(int count) {
    return 'Продаж: $count';
  }

  @override
  String shiftRefundsCount(int count) {
    return 'Возвратов: $count';
  }

  @override
  String get shiftTotalSales => 'Сумма продаж';

  @override
  String get shiftTotalRefunds => 'Сумма возвратов';

  @override
  String get shiftCashInDrawer => 'В кассе';

  @override
  String get shiftExpected => 'Ожидается';

  @override
  String get shiftActual => 'Фактически';

  @override
  String get shiftDifference => 'Разница';

  @override
  String get shiftXReport => 'X-отчёт';

  @override
  String get shiftZReport => 'Z-отчёт';

  @override
  String get shiftConfirmClose => 'Закрыть смену?';

  @override
  String get shiftAlreadyOpen => 'Смена уже открыта';

  @override
  String get shiftNotOpen => 'Смена не открыта';

  @override
  String get shiftOpenFirst => 'Сначала откройте смену';

  @override
  String get paymentTitle => 'Оплата';

  @override
  String get paymentCash => 'Наличные';

  @override
  String get paymentCard => 'Карта';

  @override
  String get paymentKaspi => 'Kaspi QR';

  @override
  String get paymentBonus => 'Бонусы';

  @override
  String get paymentDebt => 'В долг';

  @override
  String get paymentInstallment => 'Рассрочка';

  @override
  String get paymentMixed => 'Смешанная';

  @override
  String get paymentEnterAmount => 'Введите сумму';

  @override
  String paymentRemaining(String amount) {
    return 'Осталось: $amount';
  }

  @override
  String paymentChange(String amount) {
    return 'Сдача: $amount';
  }

  @override
  String get paymentComplete => 'Оплата завершена';

  @override
  String get paymentFailed => 'Ошибка оплаты';

  @override
  String get paymentWaitingCard => 'Ожидание карты...';

  @override
  String get paymentWaitingQr => 'Ожидание QR...';

  @override
  String get paymentInsertCard => 'Вставьте карту';

  @override
  String get paymentScanQr => 'Сканируйте QR';

  @override
  String get paymentApproved => 'Одобрено';

  @override
  String get paymentDeclined => 'Отклонено';

  @override
  String get paymentReceipt => 'Печать чека';

  @override
  String get paymentNoReceipt => 'Без чека';

  @override
  String get paymentEmail => 'Отправить на email';

  @override
  String get paymentSms => 'Отправить SMS';

  @override
  String get historyTitle => 'История';

  @override
  String get historyToday => 'Сегодня';

  @override
  String get historyYesterday => 'Вчера';

  @override
  String get historyThisWeek => 'Эта неделя';

  @override
  String get historyThisMonth => 'Этот месяц';

  @override
  String get historyDateRange => 'Выбрать период';

  @override
  String get historyNoSales => 'Нет продаж за период';

  @override
  String historyReceipt(String number) {
    return 'Чек №$number';
  }

  @override
  String get historyReprint => 'Повторная печать';

  @override
  String certificateSlipPrintFailed(String number, String reason) {
    return 'Слип сертификата $number не напечатался: $reason';
  }

  @override
  String get historyDetails => 'Подробнее';

  @override
  String get historySale => 'Продажа';

  @override
  String get historyRefund => 'Возврат';

  @override
  String get historyFilter => 'Фильтр';

  @override
  String get agentTitle => 'Контрагенты';

  @override
  String get agentClients => 'Клиенты';

  @override
  String get agentSuppliers => 'Поставщики';

  @override
  String get agentSearch => 'Поиск контрагента';

  @override
  String get agentAdd => 'Добавить контрагента';

  @override
  String get agentEdit => 'Редактировать';

  @override
  String get agentName => 'Название/ФИО';

  @override
  String get agentPhone => 'Телефон';

  @override
  String get agentEmail => 'Email';

  @override
  String get agentIin => 'ИИН/БИН';

  @override
  String get agentAddress => 'Адрес';

  @override
  String get agentBalance => 'Баланс';

  @override
  String get agentBonusBalance => 'Бонусный баланс';

  @override
  String get agentDebt => 'Задолженность';

  @override
  String get agentNoAgents => 'Нет контрагентов';

  @override
  String get agentSaveSuccess => 'Контрагент сохранён';

  @override
  String get agentDeleteConfirm => 'Удалить контрагента?';

  @override
  String get cashTitle => 'Касса';

  @override
  String get cashInvestment => 'Внесение';

  @override
  String get cashExpense => 'Выплата';

  @override
  String get cashBalance => 'Баланс кассы';

  @override
  String get cashEnterAmount => 'Введите сумму';

  @override
  String get cashReason => 'Основание';

  @override
  String get cashReasonPlaceholder => 'Укажите причину';

  @override
  String get cashSuccess => 'Операция выполнена';

  @override
  String get cashExpenseTypes => 'Тип расхода';

  @override
  String get cashSalary => 'Зарплата';

  @override
  String get cashRent => 'Аренда';

  @override
  String get cashUtilities => 'Коммунальные';

  @override
  String get cashSupplies => 'Закупки';

  @override
  String get cashOther => 'Прочее';

  @override
  String get discountTitle => 'Скидка';

  @override
  String get discountPercent => 'Процент';

  @override
  String get discountFixed => 'Фиксированная';

  @override
  String get discountEnterValue => 'Введите значение';

  @override
  String get discountApply => 'Применить';

  @override
  String get discountRemove => 'Убрать скидку';

  @override
  String get discountOnItem => 'Скидка на товар';

  @override
  String get discountOnTotal => 'Скидка на чек';

  @override
  String get discountMaxExceeded => 'Превышена максимальная скидка';

  @override
  String get quickProductTitle => 'Быстрые товары';

  @override
  String get quickProductAdd => 'Добавить товар';

  @override
  String get quickProductName => 'Название';

  @override
  String get quickProductPrice => 'Цена';

  @override
  String get quickProductCategory => 'Категория';

  @override
  String get quickProductSave => 'Сохранить';

  @override
  String get quickProductDelete => 'Удалить';

  @override
  String get syncTitle => 'Синхронизация';

  @override
  String get syncStatus => 'Статус синхронизации';

  @override
  String syncLastSync(String time) {
    return 'Последняя синхронизация: $time';
  }

  @override
  String get syncNow => 'Синхронизировать';

  @override
  String get syncInProgress => 'Синхронизация...';

  @override
  String get syncSuccess => 'Синхронизация завершена';

  @override
  String get syncFailed => 'Ошибка синхронизации';

  @override
  String get syncProducts => 'Товары';

  @override
  String get syncPrices => 'Цены';

  @override
  String get syncAgents => 'Контрагенты';

  @override
  String get syncSales => 'Продажи';

  @override
  String syncPending(int count) {
    return 'Ожидают отправки: $count';
  }

  @override
  String get syncOffline => 'Нет подключения';

  @override
  String get syncOnline => 'Подключено';

  @override
  String get printerTitle => 'Принтер';

  @override
  String get printerStatus => 'Статус принтера';

  @override
  String get printerConnected => 'Подключён';

  @override
  String get printerDisconnected => 'Отключён';

  @override
  String get printerError => 'Ошибка принтера';

  @override
  String get printerPaperOut => 'Нет бумаги';

  @override
  String get printerConnect => 'Подключить';

  @override
  String get printerDisconnect => 'Отключить';

  @override
  String get printerTest => 'Тестовая печать';

  @override
  String get printerSettings => 'Настройки принтера';

  @override
  String get printerWidth => 'Ширина чека';

  @override
  String get additionalTitle => 'Дополнительно';

  @override
  String get additionalSettings => 'Настройки';

  @override
  String get additionalReports => 'Отчёты';

  @override
  String get additionalInventory => 'Инвентаризация';

  @override
  String get additionalSupply => 'Приёмка товара';

  @override
  String get additionalPriceChange => 'Изменение цен';

  @override
  String get additionalBackup => 'Резервная копия';

  @override
  String get additionalRestore => 'Восстановление';

  @override
  String get additionalUpdate => 'Обновление';

  @override
  String get additionalAbout => 'О программе';

  @override
  String get additionalLicense => 'Лицензия';

  @override
  String get additionalSupport => 'Поддержка';

  @override
  String get receiptTitle => 'Чек';

  @override
  String get receiptNumber => 'Чек №';

  @override
  String get receiptDate => 'Дата';

  @override
  String get receiptCashier => 'Кассир';

  @override
  String get receiptItems => 'Товары';

  @override
  String get receiptSubtotal => 'Подытог';

  @override
  String get receiptDiscount => 'Скидка';

  @override
  String get receiptTax => 'НДС';

  @override
  String get receiptTotal => 'ИТОГО';

  @override
  String get receiptCash => 'Наличные';

  @override
  String get receiptCard => 'Карта';

  @override
  String get receiptChange => 'Сдача';

  @override
  String get receiptThankYou => 'Спасибо за покупку!';

  @override
  String get receiptFiscalNumber => 'Фискальный номер';

  @override
  String get receiptQrCode => 'QR для проверки';

  @override
  String get receiptCopy => 'Копия чека';

  @override
  String get errorUnknown => 'Неизвестная ошибка';

  @override
  String get errorNetwork => 'Ошибка сети';

  @override
  String get errorServer => 'Ошибка сервера';

  @override
  String get errorTimeout => 'Превышено время ожидания';

  @override
  String get errorNotFound => 'Не найдено';

  @override
  String get errorPermission => 'Нет доступа';

  @override
  String get errorDatabase => 'Ошибка базы данных';

  @override
  String get errorValidation => 'Ошибка валидации';

  @override
  String get errorRequired => 'Обязательное поле';

  @override
  String get errorInvalidFormat => 'Неверный формат';

  @override
  String errorMinLength(int min) {
    return 'Минимум $min символов';
  }

  @override
  String errorMaxLength(int max) {
    return 'Максимум $max символов';
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
  String get errorPrinter => 'Ошибка принтера';

  @override
  String get errorFiscal => 'Ошибка фискализации';

  @override
  String get errorPayment => 'Ошибка оплаты';

  @override
  String get errorSync => 'Ошибка синхронизации';

  @override
  String get errorNoInternet => 'Нет интернет-соединения';

  @override
  String get errorTryAgain => 'Попробуйте снова';

  @override
  String get helpTitle => 'Справка';

  @override
  String get helpTips => 'Советы';

  @override
  String get helpShortcuts => 'Горячие клавиши';

  @override
  String get helpRelatedScreens => 'Связанные разделы';

  @override
  String get helpKey => 'Клавиша';

  @override
  String get helpAction => 'Действие';

  @override
  String get navSale => 'Продажа';

  @override
  String get navRefund => 'Возврат';

  @override
  String get navShift => 'Смена';

  @override
  String get navHistory => 'История';

  @override
  String get navTables => 'Столы';

  @override
  String get navOrders => 'Заказы';

  @override
  String get navQueue => 'Очередь';

  @override
  String get navIntake => 'Приём';

  @override
  String get navAgents => 'Контрагенты';

  @override
  String get navSupply => 'Приёмка';

  @override
  String get navCash => 'Касса';

  @override
  String get navSettings => 'Настройки';

  @override
  String get navSync => 'Синхронизация';

  @override
  String get navMore => 'Ещё';

  @override
  String get navAdditional => 'Дополнительно';

  @override
  String get navLockScreen => 'Блокировка';

  @override
  String get navMain => 'Основное';

  @override
  String get loginEnterSystem => 'Вход в систему';

  @override
  String get loginWithoutPin => 'Войти без PIN';

  @override
  String get loginShiftOpen => 'Смена открыта';

  @override
  String get loginShiftClosed => 'Смена закрыта';

  @override
  String get loginShiftUnknown => 'Смена: неизвестно';

  @override
  String get saleQuickProducts => 'Быстрые товары';

  @override
  String get saleIncrease => 'Увеличить';

  @override
  String get saleDecrease => 'Уменьшить';

  @override
  String get saleMark => 'Маркировка';

  @override
  String get saleDataMatrix => 'Маркировка (DataMatrix)';

  @override
  String get saleHeld => 'Чек отложен';

  @override
  String get saleNoDeferredSales => 'Нет отложенных чеков';

  @override
  String get saleDeferredListNotPermitted =>
      'Отложенные чеки вам не открыты: нужно право «откладывать чек». Его выдаёт администратор в настройках прав; касса откажет любому, у кого его нет.';

  @override
  String get saleDeferNotPermitted =>
      'Отложить чек вам нельзя: нужно право «откладывать чек». Его выдаёт администратор в настройках прав; касса откажет любому, у кого его нет.';

  @override
  String get saleReceiptNo => 'Чек №';

  @override
  String get salePositions => 'Позиций';

  @override
  String get saleSearchHint => 'Поиск товара (название или штрих-код)';

  @override
  String get refundWithReceipt => 'С ЧЕКОМ';

  @override
  String get refundWithoutReceiptUpper => 'БЕЗ ЧЕКА';

  @override
  String get refundLoadReceipt => 'Загрузить чек';

  @override
  String get refundSearchProducts => 'Поиск товаров';

  @override
  String get refundSelectAll => 'Выбрать всё';

  @override
  String get refundDeselectAll => 'Снять всё';

  @override
  String refundMaxQuantity(String max) {
    return 'Максимум: $max';
  }

  @override
  String get refundConfirmTitle => 'Подтвердите возврат';

  @override
  String refundSelectedItems(int count) {
    return 'Выбрано позиций: $count';
  }

  @override
  String get refundSuccessMsg => 'Возврат успешно проведён';

  @override
  String get refundSearchHint => 'Поиск товара для возврата';

  @override
  String get paymentRefundTitle => 'Возврат';

  @override
  String get paymentPayTitle => 'Оплата';

  @override
  String get paymentRefundBtn => 'ВЕРНУТЬ';

  @override
  String get paymentPayBtn => 'ОПЛАТИТЬ';

  @override
  String get paymentChangeLabel => 'Сдача:';

  @override
  String get paymentSuccessRefund => 'Возврат успешно проведён';

  @override
  String get paymentSuccessPay => 'Оплата успешна';

  @override
  String get paymentCardType => 'Безналичная';

  @override
  String get paymentToPay => 'К оплате';

  @override
  String get paymentBonusLabel => 'Бонусы';

  @override
  String get paymentTotalToPay => 'Итого к оплате';

  @override
  String get paymentByCard => 'Картой';

  @override
  String get paymentRemainLabel => 'Осталось';

  @override
  String get shiftBills => 'Купюры';

  @override
  String get shiftTotalAmount => 'Общая сумма';

  @override
  String get shiftOperations => 'Операции';

  @override
  String get shiftOpened => 'Смена открыта';

  @override
  String get shiftClosed => 'Смена закрыта';

  @override
  String get shiftOverAgeTitle => 'Смена открыта более 24 часов';

  @override
  String get shiftOverAgeMessage =>
      'Продажа заблокирована. Закройте текущую смену и откройте новую, чтобы продолжить работу.';

  @override
  String get shiftOverAgeCloseAtTill =>
      'Продажа заблокирована. Закройте смену на кассе и откройте новую, чтобы продолжить работу.';

  @override
  String shiftSince(String time) {
    return 'с $time';
  }

  @override
  String get shiftSystem => 'Система';

  @override
  String get shiftEntered => 'Введено';

  @override
  String get shiftRecounting => 'Пересчёт по купюрам';

  @override
  String get shiftManualEntry => 'Ручной ввод суммы';

  @override
  String get shiftCashOps => 'Кассовые операции';

  @override
  String get shiftOpenAction => 'Открытие смены';

  @override
  String get shiftCloseAction => 'Закрытие смены';

  @override
  String get historyOperations => 'История операций';

  @override
  String get historyResetFilters => 'Сбросить фильтры';

  @override
  String get historyRefresh => 'Обновить';

  @override
  String get historyNoRecords => 'Нет записей';

  @override
  String get historyChangeFilters => 'Попробуйте изменить фильтры';

  @override
  String get historyEmpty => 'История операций пуста';

  @override
  String get historyFilterTitle => 'Фильтры';

  @override
  String get historyPeriod => 'Период';

  @override
  String get historyOpType => 'Тип операции';

  @override
  String get historySearchHint => 'Номер чека, сумма...';

  @override
  String historyType(String type) {
    return 'Тип:';
  }

  @override
  String get historyPrint => 'Печать чека';

  @override
  String agentFound(int count) {
    return 'Найдено: $count';
  }

  @override
  String get agentWithDebt => 'Только с долгом';

  @override
  String get agentSearchHint => 'Поиск по имени или телефону...';

  @override
  String get agentNewClient => 'Новый клиент';

  @override
  String get agentNameRequired => 'Имя *';

  @override
  String get agentEnterName => 'Введите имя клиента';

  @override
  String get agentPhoneLabel => 'Телефон';

  @override
  String get agentIinLabel => 'БИН/ИИН';

  @override
  String get agentIinHint => '12 цифр';

  @override
  String get agentDeleteQuestion => 'Удалить клиента?';

  @override
  String agentDeleteConfirmMsg(String name) {
    return 'Вы уверены, что хотите удалить $name?';
  }

  @override
  String get agentDeleted => 'Клиент удалён';

  @override
  String get agentFoundExisting => 'Клиент найден';

  @override
  String get supplyTitle => 'Приёмка товара';

  @override
  String get supplySaved => 'Приёмка сохранена';

  @override
  String get supplySaveError => 'Ошибка сохранения';

  @override
  String get supplyCancelQuestion => 'Отменить приёмку?';

  @override
  String get supplyDataLost => 'Все введённые данные будут потеряны.';

  @override
  String supplyProducts(int count) {
    return 'Товаров: $count';
  }

  @override
  String get supplyBarcodeHint => 'Штрихкод или артикул';

  @override
  String get supplyComment => 'Комментарий';

  @override
  String get supplyCommentHint => 'Введите комментарий...';

  @override
  String get supplyNotFound => 'Товар не найден';

  @override
  String get supplySelectSupplier => 'Выберите поставщика';

  @override
  String get supplySelectAccount => 'Выберите счёт';

  @override
  String supplyBalance(String amount) {
    return 'Баланс: $amount';
  }

  @override
  String get supplyPurchasePrice => 'Цена прихода';

  @override
  String get supplySerialNumbers => 'Серийные номера';

  @override
  String get supplySerialHint => 'Введите или отсканируйте S/N';

  @override
  String supplySerialCount(int count, int expected) {
    return '$count из $expected';
  }

  @override
  String get supplySerialMismatch =>
      'Число серийных номеров не совпадает с количеством';

  @override
  String get supplyInvalidQty => 'Введите корректное количество';

  @override
  String get supplyInvalidPrice => 'Введите корректную цену';

  @override
  String get inventoryTitle => 'Инвентаризация';

  @override
  String get inventoryFullCount => 'Полная инвентаризация';

  @override
  String get inventoryFullCountSubtitle =>
      'Обнулить остатки непросканированных товаров';

  @override
  String get inventoryStart => 'Начать';

  @override
  String get inventoryFinish => 'Завершить';

  @override
  String get inventoryScanHint => 'Сканируйте штрихкод';

  @override
  String get inventoryScanProducts => 'Сканируйте товары для подсчёта';

  @override
  String get inventoryPressStart => 'Нажмите \"Начать\" для инвентаризации';

  @override
  String inventoryProductCount(int count) {
    return 'Товаров: $count';
  }

  @override
  String inventoryDiscrepancies(int count) {
    return 'Расхождений: $count';
  }

  @override
  String get inventoryExpected => 'Ожид:';

  @override
  String get inventoryActual => 'Факт:';

  @override
  String get inventoryProduct => 'Товар';

  @override
  String get inventoryExpectedQty => 'Ожидаемое';

  @override
  String get inventoryActualQty => 'Фактическое';

  @override
  String get inventoryDiscrepancy => 'Расхождение';

  @override
  String get inventoryActualLabel => 'Фактическое кол-во';

  @override
  String get inventoryFinishQuestion => 'Завершить инвентаризацию?';

  @override
  String get inventoryCompleted => 'Инвентаризация завершена';

  @override
  String get writeoffTitle => 'Списание';

  @override
  String get writeoffReason => 'Причина';

  @override
  String get writeoffProduct => 'Товар';

  @override
  String get writeoffScanHint => 'Сканируйте штрихкод';

  @override
  String get writeoffCommentHint => 'Необязательно';

  @override
  String get writeoffReasonBreakage => 'Бой';

  @override
  String get writeoffReasonExpired => 'Просрочка';

  @override
  String get writeoffReasonDamage => 'Порча';

  @override
  String get writeoffReasonLoss => 'Утеря';

  @override
  String get writeoffReasonOther => 'Прочее';

  @override
  String get writeoffCancelQuestion => 'Отменить списание?';

  @override
  String get writeoffSaved => 'Списание сохранено';

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get settingsPosInfo => 'Информация о кассе';

  @override
  String get settingsPosName => 'Название кассы';

  @override
  String get settingsCompany => 'Компания';

  @override
  String get settingsIin => 'ИИН/БИН';

  @override
  String get settingsPosId => 'ID POS';

  @override
  String get settingsStoreId => 'ID магазина';

  @override
  String get settingsNotSpecified => 'Не указано';

  @override
  String get settingsAppVersion => 'Версия приложения';

  @override
  String get settingsVersion => 'Версия';

  @override
  String get settingsPlatform => 'Платформа';

  @override
  String get settingsLanguage => 'Язык интерфейса';

  @override
  String get settingsLanguageChanged => 'Язык изменён';

  @override
  String get settingsCurrency => 'Валюта';

  @override
  String get settingsCurrencySymbol => 'Символ';

  @override
  String get settingsCurrencyCode => 'Код';

  @override
  String get settingsCountry => 'Страна';

  @override
  String get settingsAdditional => 'Дополнительные настройки';

  @override
  String get settingsTransport => 'Транспорт';

  @override
  String get settingsTransportDesc => 'Настройки синхронизации данных';

  @override
  String get settingsPrinter => 'Принтер';

  @override
  String get settingsPrinterDesc => 'Настройки печати чеков';

  @override
  String get settingsFiscal => 'Фискализация';

  @override
  String get settingsFiscalDesc => 'WebKassa, ОФД, НДС';

  @override
  String get settingsTelegram => 'Telegram';

  @override
  String get settingsTelegramDesc => 'Интеграция и каналы Telegram';

  @override
  String get settingsPermissions => 'Права доступа';

  @override
  String get settingsPermissionsDesc => 'Разрешения для кассиров';

  @override
  String get fiscalTitle => 'Фискализация';

  @override
  String get fiscalOperator => 'Фискальный оператор';

  @override
  String get fiscalWebkassa => 'Настройки WebKassa';

  @override
  String get fiscalTaxpayer => 'Данные налогоплательщика';

  @override
  String get fiscalVatSettings => 'Настройки НДС';

  @override
  String get fiscalVatPayer => 'Плательщик НДС';

  @override
  String get fiscalPrintVat => 'Печатать НДС на чеке';

  @override
  String get fiscalSaved => 'Настройки сохранены';

  @override
  String get fiscalSaveError => 'Ошибка сохранения';

  @override
  String get printerSettingsTitle => 'Настройки принтера';

  @override
  String get printerConnectionType => 'Тип подключения';

  @override
  String get printerAddress => 'Адрес принтера';

  @override
  String get printerPaperWidth => 'Ширина бумаги';

  @override
  String get printerTesting => 'Тестирование';

  @override
  String get printerReady => 'Готов';

  @override
  String get printerNotConnected => 'Не подключен';

  @override
  String get printerPaperOut2 => 'Нет бумаги';

  @override
  String get printerCoverOpen => 'Открыта крышка';

  @override
  String get printerPrinting => 'Печать...';

  @override
  String get printerCheckStatus => 'Проверка...';

  @override
  String get printerPrintSuccess => 'Печать успешна';

  @override
  String get paymentNotFiscalized => 'Чек не фискализован — оплата проведена';

  @override
  String get paymentFiscalModuleAbsent =>
      'Модуль фискализации недоступен — чеки не фискализуются';

  @override
  String get cashDrawerOpenError => 'Денежный ящик не открылся';

  @override
  String get printerPrintError => 'Ошибка печати';

  @override
  String get printerCheckBtn => 'Проверить';

  @override
  String get printerTestReceipt => 'Тестовый чек';

  @override
  String get printerPort => 'Порт';

  @override
  String get cashOperationTitle => 'Кассовая операция';

  @override
  String get cashWithdrawal => 'Изъятие';

  @override
  String get cashCommentRequired => 'Комментарий *';

  @override
  String get cashCommentOptional => 'Комментарий';

  @override
  String get cashCommentHint => 'Введите комментарий...';

  @override
  String get cashEnterAmountMsg => 'Введите сумму';

  @override
  String get cashPositiveOnly => 'Сумма должна быть положительной';

  @override
  String get cashInsufficient => 'Недостаточно денег в кассе';

  @override
  String get cashInvalidAmount => 'Введите корректную сумму';

  @override
  String get cashInDrawer => 'В кассе:';

  @override
  String get telegramTitle => 'Настройки Telegram';

  @override
  String get telegramAuth => 'Авторизация';

  @override
  String get telegramSync => 'Синхронизация';

  @override
  String get telegramNotifications => 'Включить уведомления';

  @override
  String get telegramAutoSync => 'Автосинхронизация';

  @override
  String get telegramSyncData => 'Автоматически синхронизировать данные';

  @override
  String get telegramSyncInterval => 'Интервал синхронизации';

  @override
  String get telegramForceSync => 'Принудительная синхронизация';

  @override
  String get telegramFullSync => 'Полная синхронизация';

  @override
  String get telegramRecreateChannels => 'Пересоздать каналы';

  @override
  String get telegramLogout => 'Выйти из Telegram';

  @override
  String get telegramSyncComplete => 'Синхронизация завершена';

  @override
  String get telegramSyncError => 'Ошибка синхронизации';

  @override
  String get telegramLogoutComplete => 'Выход выполнен';

  @override
  String get chatTitle => 'Чат сотрудников';

  @override
  String chatParticipants(int count) {
    return '$count участников';
  }

  @override
  String get chatConnected => 'Подключено';

  @override
  String get chatDisconnected => 'Нет соединения';

  @override
  String get chatNoMessages => 'Нет сообщений';

  @override
  String get chatStartConversation => 'Начните общение с командой';

  @override
  String get chatMessageHint => 'Сообщение...';

  @override
  String get chatSearch => 'Поиск';

  @override
  String get chatSearchHint => 'Введите текст для поиска...';

  @override
  String get chatMembers => 'Участники';

  @override
  String get chatLinkTelegram => 'Привязать Telegram';

  @override
  String get chatCopied => 'Скопировано';

  @override
  String get chatReply => 'Ответить';

  @override
  String get chatCopy => 'Копировать';

  @override
  String get chatDeleteMsg => 'Удалить сообщение?';

  @override
  String get chatDeleteConfirm =>
      'Сообщение будет удалено для всех участников чата.';

  @override
  String get chatPhoto => 'Фото';

  @override
  String get chatDocument => 'Документ';

  @override
  String get chatLocation => 'Местоположение';

  @override
  String get chatCamera => 'Камера';

  @override
  String get chatGallery => 'Галерея';

  @override
  String get chatSelectSource => 'Выберите источник';

  @override
  String get updateAvailable => 'Доступно обновление';

  @override
  String get updateInProgress => 'Обновление...';

  @override
  String updateAutoIn(int seconds) {
    return 'Автоматическое обновление через $seconds сек';
  }

  @override
  String get updateNowBtn => 'Обновить сейчас';

  @override
  String get updateLater => 'Позже';

  @override
  String get updateSkip => 'Пропустить';

  @override
  String get updateBtn => 'Обновить';

  @override
  String get storageWarningTitle => 'Мало места на диске';

  @override
  String get storageWarningMsg =>
      'Для стабильной работы кассы рекомендуется освободить минимум 2 GB.';

  @override
  String get storageUnderstood => 'Понятно';

  @override
  String get errorCritical => 'Критическая ошибка';

  @override
  String get errorAppProblem => 'Приложение столкнулось с проблемой';

  @override
  String get errorDescription => 'Описание ошибки:';

  @override
  String get errorTechnical => 'Технические детали';

  @override
  String get errorRetry => 'Повторить';

  @override
  String get errorOpenFolder => 'Открыть папку';

  @override
  String get errorOtherVersion => 'Другая версия';

  @override
  String get errorExit => 'Выйти';

  @override
  String get switchOn => 'Вкл';

  @override
  String get switchOff => 'Выкл';

  @override
  String get keyboardSpace => 'Пробел';

  @override
  String get keyboardHide => 'Скрыть клавиатуру';

  @override
  String get keyboardShow => 'Показать клавиатуру';

  @override
  String get commentReceipt => 'Комментарий к чеку';

  @override
  String get commentReceiptHint => 'Введите комментарий...';

  @override
  String get productNameLabel => 'Название товара';

  @override
  String get productNameHint => 'Введите название...';

  @override
  String get nothingFound => 'Ничего не найдено';

  @override
  String get datePlaceholder => 'ДД.ММ.ГГГГ';

  @override
  String get timePlaceholder => 'ЧЧ:ММ';

  @override
  String get dateTimePlaceholder => 'ДД.ММ.ГГГГ ЧЧ:ММ';

  @override
  String get selectPeriod => 'Выберите период';

  @override
  String get bonusProgram => 'Бонусная программа';

  @override
  String get enterPhone => 'Введите номер телефона клиента';

  @override
  String get enterSmsCode => 'Введите код из SMS';

  @override
  String resendIn(int seconds) {
    return 'Повторная отправка через $seconds сек';
  }

  @override
  String get resendCode => 'Отправить код повторно';

  @override
  String get availableBonuses => 'Доступно бонусов:';

  @override
  String get useBonuses => 'Списать бонусов';

  @override
  String get deferredSales => 'Отложенные продажи';

  @override
  String get noDeferredSales => 'Нет отложенных продаж';

  @override
  String get fiscalErrors => 'Ошибки фискализации';

  @override
  String get selectAllErrors => 'Выбрать все';

  @override
  String get retrySelected => 'Повторить';

  @override
  String receiptNo(String number) {
    return 'Чек #$number';
  }

  @override
  String get dontAskAgain => 'Не спрашивать снова';

  @override
  String get deleteTitle => 'Удаление';

  @override
  String deleteItemConfirm(String name) {
    return 'Вы уверены, что хотите удалить \"$name\"?';
  }

  @override
  String get exitTitle => 'Выход';

  @override
  String get exitConfirm => 'Вы уверены, что хотите выйти?';

  @override
  String get exitBtn => 'Выйти';

  @override
  String get valueCannotBeNegative => 'Значение не может быть отрицательным';

  @override
  String maxPercent(String percent) {
    return 'Максимум $percent%';
  }

  @override
  String maxAmount(String amount) {
    return 'Максимум $amount';
  }

  @override
  String get enterValidNumber => 'Введите корректное число';

  @override
  String get discountAmount => 'Сумма скидки:';

  @override
  String discountLimitPercent(String percent, String source) {
    return 'Доступно до $percent % — $source';
  }

  @override
  String discountLimitAmount(String amount, String source) {
    return 'Доступно до $amount — $source';
  }

  @override
  String discountApprovalAbove(String percent) {
    return 'Выше $percent % нужно подтверждение старшего';
  }

  @override
  String get sumLabel => 'Сумма';

  @override
  String get enterAmount => 'Введите сумму';

  @override
  String get amountMustBePositive => 'Сумма должна быть положительной';

  @override
  String get notEnoughCashInDrawer => 'Недостаточно денег в кассе';

  @override
  String get enterValidAmount => 'Введите корректную сумму';

  @override
  String get inDrawer => 'В кассе:';

  @override
  String get commentOptional => 'Комментарий (необязательно)';

  @override
  String get operationReason => 'Причина операции...';

  @override
  String get positions => 'позиций';

  @override
  String get enterWeight => 'Введите вес';

  @override
  String get weightMustBePositive => 'Вес должен быть положительным';

  @override
  String maxWeightValue(String max, String unit) {
    return 'Максимум $max $unit';
  }

  @override
  String get unitPcs => 'шт';

  @override
  String get unitKg => 'кг';

  @override
  String lowStorageTooltip(String gb) {
    return 'Мало места: $gb GB';
  }

  @override
  String storageFree(String gb) {
    return 'Свободно: $gb GB';
  }

  @override
  String get storageRecommendation =>
      'Для стабильной работы кассы рекомендуется иметь минимум 2 GB свободного места.\n\nПожалуйста, освободите место на диске или обратитесь к администратору.';

  @override
  String lowStorageBanner(String gb) {
    return 'Мало свободного места: $gb GB. Рекомендуется освободить минимум 2 GB для стабильной работы.';
  }

  @override
  String lowStorageTooltipShort(String gb) {
    return 'Мало места на диске: $gb GB';
  }

  @override
  String get cashier => 'Кассир:';

  @override
  String get buyer => 'Покупатель:';

  @override
  String receiptHeader(int number) {
    return 'ЧЕК #$number';
  }

  @override
  String get receiptDiscountItem => 'Скидка:';

  @override
  String get receiptSubtotalLabel => 'Подитого';

  @override
  String get receiptPayment => 'Оплата:';

  @override
  String get fiscalMark => 'ФП:';

  @override
  String remainingStock(String qty) {
    return 'Ост: $qty';
  }

  @override
  String get tableHeaderName => 'Название';

  @override
  String get tableHeaderPrice => 'Цена';

  @override
  String get tableHeaderQty => 'Кол-во';

  @override
  String get tableHeaderTotal => 'Итого';

  @override
  String get emptyReceipt => 'Чек пуст';

  @override
  String get addProductsViaSearch =>
      'Добавьте товары через поиск\nили сканируйте штрих-код';

  @override
  String get addProductsViaSearchShort => 'Добавьте товары через поиск';

  @override
  String get priceLabel => 'Цена';

  @override
  String get receiptTotalLabel => 'Итого по чеку';

  @override
  String get positionsLabel => 'Позиций';

  @override
  String get toPayLabel => 'К ОПЛАТЕ';

  @override
  String get payBtn => 'ОПЛАТИТЬ';

  @override
  String get totalLabel => 'Итого:';

  @override
  String posAndQty(int positions, String qty) {
    return '$positions поз. / $qty шт.';
  }

  @override
  String get modeRetail => 'Розница';

  @override
  String get modeWholesale => 'ОПТ';

  @override
  String get quickProducts => 'Быстрые товары';

  @override
  String get editProduct => 'Редактирование';

  @override
  String get labelComment => 'Комментарий';

  @override
  String get selectPackage => 'Выберите фасовку';

  @override
  String packageQty(String qty) {
    return '$qty шт';
  }

  @override
  String get allBreadcrumb => 'Все';

  @override
  String productPrice(String price) {
    return '$price ₸';
  }

  @override
  String maxBonusPercent(int percent) {
    return 'Можно списать до $percent% от суммы чека';
  }

  @override
  String get insufficientBonuses => 'Недостаточно бонусов';

  @override
  String get enterValidPhone => 'Введите корректный номер';

  @override
  String errorsCount(int count) {
    return '$count ошибок';
  }

  @override
  String selectAllCount(int count) {
    return 'Выбрать все ($count)';
  }

  @override
  String retryCount(int count) {
    return 'Повторить ($count)';
  }

  @override
  String receiptHash(int number) {
    return 'Чек #$number';
  }

  @override
  String get enterIntegerNumber => 'Введите целое число';

  @override
  String enterDigits(int length) {
    return 'Введите $length цифры';
  }

  @override
  String get drawerPrimary => 'Основное';

  @override
  String get drawerSecondary => 'Дополнительно';

  @override
  String get tooltipMore => 'Ещё';

  @override
  String get statusOnline => 'Online';

  @override
  String get statusOffline => 'Offline';

  @override
  String get statusSyncing => 'Sync...';

  @override
  String get thankYouForPurchase => 'Спасибо за покупку!';

  @override
  String get searchProductHint => 'Поиск товара (название или штрих-код)';

  @override
  String get actionDefer => 'Отложить';

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
  String get actionIncrease => 'Увеличить';

  @override
  String get actionDecrease => 'Уменьшить';

  @override
  String get restaurantSettings => 'Режим ресторана';

  @override
  String get restaurantSettingsDesc => 'Столы, зоны, сервисный сбор';

  @override
  String get restaurantOperatingMode => 'Режим работы';

  @override
  String get restaurantModeRetail => 'Розничная торговля';

  @override
  String get restaurantModeRetailDesc => 'Стандартный POS для магазинов';

  @override
  String get restaurantModeRestaurant => 'Ресторан';

  @override
  String get restaurantModeRestaurantDesc => 'Столы, заказы, сервисный сбор';

  @override
  String get restaurantModeService => 'Сервис';

  @override
  String get restaurantModeServiceDesc => 'Приём заявок, очередь';

  @override
  String get restaurantZoneManagement => 'Управление зонами';

  @override
  String get restaurantZoneAdd => 'Добавить зону';

  @override
  String get restaurantZoneRename => 'Переименовать';

  @override
  String get restaurantZonePresets => 'Предустановки';

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
  String get restaurantZonePrivate => 'Приватная комната';

  @override
  String get restaurantTableManagement => 'Управление столами';

  @override
  String get restaurantTableAdd => 'Добавить стол';

  @override
  String get restaurantTableEdit => 'Редактировать стол';

  @override
  String get restaurantTableName => 'Название стола';

  @override
  String get restaurantTableCapacity => 'Вместимость';

  @override
  String get restaurantTableZone => 'Зона';

  @override
  String get restaurantTableSortOrder => 'Порядок';

  @override
  String get restaurantTableDeactivate => 'Деактивировать стол';

  @override
  String restaurantTableDeactivateConfirm(String name) {
    return 'Деактивировать стол «$name»?';
  }

  @override
  String get restaurantServiceCharge => 'Сервисный сбор';

  @override
  String get restaurantServiceChargeEnabled => 'Включить сервисный сбор';

  @override
  String get restaurantServiceChargePercent => 'Процент сервисного сбора';

  @override
  String get restaurantTableFree => 'Свободен';

  @override
  String get restaurantTableOccupied => 'Занят';

  @override
  String get restaurantTableReserved => 'Забронирован';

  @override
  String get restaurantTableDirty => 'Убрать';

  @override
  String get restaurantOrderDineIn => 'В зале';

  @override
  String get restaurantOrderTakeout => 'Навынос';

  @override
  String get restaurantOrderDelivery => 'Доставка';

  @override
  String get restaurantAllZones => 'Все зоны';

  @override
  String get restaurantNoTables => 'Нет столов';

  @override
  String get restaurantNoTablesHint => 'Добавьте столы в настройках ресторана';

  @override
  String get restaurantGoToSettings => 'Перейти в настройки';

  @override
  String get restaurantOrdersEmpty => 'Нет активных заказов';

  @override
  String restaurantOrderItems(int count) {
    return '$count позиций';
  }

  @override
  String restaurantOrderGuests(int count) {
    return 'Гостей: $count';
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
  String get restaurantNoOrder => 'Нет активного заказа';

  @override
  String get restaurantOpenOrder => 'Открыть заказ';

  @override
  String get restaurantCloseOrder => 'Закрыть заказ';

  @override
  String get restaurantAddItems => 'Добавить позиции';

  @override
  String get restaurantGoToPayment => 'К оплате';

  @override
  String get restaurantTransfer => 'Перенести';

  @override
  String get restaurantSplitBill => 'Разделить';

  @override
  String get restaurantChangeStatus => 'Изменить статус';

  @override
  String get restaurantSetFree => 'Свободен';

  @override
  String get restaurantSetReserved => 'Забронировать';

  @override
  String get restaurantSetDirty => 'Требует уборки';

  @override
  String get restaurantCreateOrder => 'Новый заказ';

  @override
  String get restaurantPartySize => 'Количество гостей';

  @override
  String get restaurantOrderType => 'Тип заказа';

  @override
  String get restaurantWaiter => 'Официант';

  @override
  String get restaurantNote => 'Примечание';

  @override
  String get restaurantDeliveryAddress => 'Адрес доставки';

  @override
  String get restaurantDeliveryPhone => 'Телефон';

  @override
  String get restaurantTransferTitle => 'Перенос заказа';

  @override
  String restaurantTransferCurrent(String table) {
    return 'Текущий: $table';
  }

  @override
  String get restaurantTransferSelectFree => 'Выберите свободный стол:';

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
  String get restaurantSplitTitle => 'Разделение счёта';

  @override
  String get restaurantSplitEvenly => 'Поровну';

  @override
  String get restaurantSplitByItems => 'По позициям';

  @override
  String get restaurantSplitGuestCount => 'Количество гостей';

  @override
  String restaurantSplitPerGuest(String amount) {
    return 'На каждого: $amount';
  }

  @override
  String restaurantSplitGuest(int number) {
    return 'Гость $number';
  }

  @override
  String get restaurantSplitApply => 'Применить';

  @override
  String get restaurantSplitPaymentTitle => 'Оплата по гостям';

  @override
  String get restaurantSplitPaymentProceed => 'К оплате';

  @override
  String get restaurantPreCheckPrinted => 'Пре-чек отправлен на печать';

  @override
  String get restaurantPreCheckFailed => 'Ошибка печати пре-чека';

  @override
  String get restaurantSubtotal => 'Подитог';

  @override
  String restaurantServiceChargeLine(String percent) {
    return 'Сервисный сбор ($percent%)';
  }

  @override
  String restaurantOrderNumber(int number) {
    return 'Заказ #$number';
  }

  @override
  String restaurantTakeoutNumber(int number) {
    return 'Навынос #$number';
  }

  @override
  String restaurantDeliveryNumber(int number) {
    return 'Доставка #$number';
  }

  @override
  String get restaurantSaved => 'Настройки ресторана сохранены';

  @override
  String get restaurantQuickActions => 'Быстрые действия';

  @override
  String get restaurantNoItems => 'Нет позиций';

  @override
  String restaurantTableSeats(int count) {
    return '$count мест';
  }

  @override
  String get restaurantOrderTab => 'Заказ';

  @override
  String get restaurantMenuTab => 'Меню';

  @override
  String restaurantGuestLabel(int number) {
    return 'Гость $number';
  }

  @override
  String get restaurantRemoveItem => 'Удалить позицию';

  @override
  String get restaurantPrintPrecheck => 'Пречек';

  @override
  String get restaurantNewTakeout => 'Навынос';

  @override
  String get restaurantNewDelivery => 'Доставка';

  @override
  String get setupSectionOrganization => 'Организация';

  @override
  String get setupSectionContact => 'Контактное лицо';

  @override
  String get setupSectionAddress => 'Адреса';

  @override
  String get setupSectionCashBox => 'Касса';

  @override
  String get setupSectionUsers => 'Кто будет работать';

  @override
  String get setupSectionSecurity => 'Вход по коду';

  @override
  String get setupSectionScanner => 'Сканер';

  @override
  String get setupSectionScale => 'Весы';

  @override
  String get setupSectionDisplay => 'Дисплей покупателя';

  @override
  String get setupSectionTerminal => 'Платёжный терминал';

  @override
  String get setupSectionCashback => 'Возврат наличных';

  @override
  String get setupTaxIdExplanation =>
      'Налоговый номер печатается в каждом чеке и уходит в фискальный сервис. Ошибка здесь обнаружится только при первой сверке с налоговой — когда чеки уже выданы покупателям.';

  @override
  String get setupFiscalCredentialsExplanation =>
      'Реквизиты выдаёт фискальный оператор. Пока они неверны, чеки печатаются как обычно, но в фискальный сервис не уходят — расхождение обнаружится при сверке, а не в момент продажи.';

  @override
  String get setupKktNumberExplanation =>
      'Номер ККМ связывает кассу с её регистрацией у оператора. Ошибка в нём отправляет чеки под чужой кассой, и заметить это по самой кассе невозможно.';

  @override
  String setupStepProgress(int current, int total) {
    return 'Шаг $current из $total';
  }

  @override
  String get setupStepChecking => 'Проверка';

  @override
  String get setupStepTelegram => 'Telegram';

  @override
  String get setupStepCountry => 'Страна';

  @override
  String get setupStepOrganization => 'Организация';

  @override
  String get setupStepVat => 'НДС';

  @override
  String get setupStepUsers => 'Пользователи';

  @override
  String get setupStepWorkMode => 'Режим работы';

  @override
  String get setupStepPos => 'Касса';

  @override
  String get setupStepFiscal => 'Фискализация';

  @override
  String get setupStepEquipment => 'Оборудование';

  @override
  String get setupStepTerminals => 'Терминалы';

  @override
  String get setupStepOperatingMode => 'Тип бизнеса';

  @override
  String get setupStepBusinessRules => 'Правила';

  @override
  String get setupStepSummary => 'Проверка';

  @override
  String get setupStepComplete => 'Готово';

  @override
  String get setupCheckingSettings => 'Проверка настроек...';

  @override
  String get setupStateUnreadableTitle => 'Касса не ответила';

  @override
  String get setupStateUnreadableBody =>
      'Мастер не начнёт настройку, пока не прочитает состояние кассы: иначе он может затереть уже работающий магазин. Проверьте, что касса запущена и доступна по сети.';

  @override
  String get wtUnavailableTitle => 'Нет связи с кассой';

  @override
  String get wtUnavailableBody =>
      'Терминал берёт данные только по WebTransport. Запасного пути нет: если соединения нет, показывать нечего, а показать устаревшее как свежее хуже, чем не показать ничего. Проверьте, что касса запущена, и повторите.';

  @override
  String wtUnavailableReason(String reason) {
    return 'Причина: $reason';
  }

  @override
  String get terminalHomeWhoHeader => 'Кто вошёл';

  @override
  String get terminalHomeUserLabel => 'Кассир';

  @override
  String get terminalHomeSaleNote =>
      'Корзиной, номером чека и сменой владеет касса — терминал показывает чек и командует по проводу. Печать чека, фискализация и денежный ящик остаются на кассе.';

  @override
  String get wtNotPortedTitle => 'Этот экран пока только на кассе';

  @override
  String get wtNotPortedBody =>
      'Браузерный терминал берёт данные по проводу, и экран появляется здесь тогда, когда все его договоры научились работать поверх провода. Этот ещё не научился. Показать его пустым было бы хуже, чем сказать прямо.';

  @override
  String wtNotPortedLocation(String location) {
    return 'Маршрут: $location';
  }

  @override
  String get setupWelcomeTitle => 'Добро пожаловать в TelePOS!';

  @override
  String get setupCountryDescription =>
      'Выберите вашу страну для настройки валюты и налогов';

  @override
  String setupPriceExample(String amount) {
    return 'Пример: $amount';
  }

  @override
  String setupVatRateLabel(int rate) {
    return 'НДС: $rate%';
  }

  @override
  String get setupOrganizationTitle => 'Данные организации';

  @override
  String get setupOrganizationDescription =>
      'Введите информацию о вашей компании';

  @override
  String get setupCompanyNameLabel => 'Название организации';

  @override
  String get setupCompanyNameHint => 'ТОО \"Моя компания\"';

  @override
  String setupTaxIdDigits(int length) {
    return '$length цифр';
  }

  @override
  String get setupLegalAddressLabel => 'Юридический адрес';

  @override
  String get setupActualAddressLabel => 'Фактический адрес магазина';

  @override
  String get setupOwnerNameLabel => 'ФИО руководителя';

  @override
  String get setupPhoneLabel => 'Телефон';

  @override
  String get setupVatTitle => 'Налог на добавленную стоимость';

  @override
  String get setupVatDescription =>
      'Выберите режим налогообложения вашей организации';

  @override
  String get setupVatPayerTitle => 'Плательщик НДС';

  @override
  String setupVatPayerRate(int rate) {
    return 'Ставка НДС: $rate%';
  }

  @override
  String get setupVatPayerRateUnknown => 'Ставка НДС зависит от страны';

  @override
  String get setupVatPayerDescription =>
      'В чеках будет выделяться НДС.\nОбязательно для компаний на общей системе налогообложения.';

  @override
  String get setupVatNonPayerTitle => 'Без НДС';

  @override
  String get setupVatNonPayerSubtitle => 'НДС не применяется';

  @override
  String get setupVatNonPayerDescription =>
      'В чеках НДС выделяться не будет.\nДля ИП на упрощённой системе или патенте.';

  @override
  String get setupWorkModeTitle => 'Режим работы';

  @override
  String get setupWorkModeDescription =>
      'Выберите как будет работать ваша касса';

  @override
  String get setupAutonomousTitle => 'Автономный режим';

  @override
  String get setupAutonomousSubtitle => 'Работа без интернета';

  @override
  String get setupAutonomousDescription =>
      'Касса работает полностью автономно.\nДанные хранятся только локально.\nНет синхронизации между кассами.';

  @override
  String get setupNetworkTitle => 'Сетевой режим';

  @override
  String get setupNetworkConfigured => 'Telegram настроен';

  @override
  String get setupNetworkRequired => 'Требуется Telegram';

  @override
  String get setupNetworkDescription =>
      'Синхронизация данных между кассами.\nРезервное копирование в облако.\nОтчёты и уведомления в Telegram.';

  @override
  String get setupNetworkRequiresTelegram =>
      'Для сетевого режима необходимо настроить Telegram';

  @override
  String get setupOperatingModeTitle => 'Тип бизнеса';

  @override
  String get setupOperatingModeDescription => 'Выберите тип вашего бизнеса';

  @override
  String get setupRetailTitle => 'Розничная касса';

  @override
  String get setupRetailSubtitle => 'Магазин, аптека, супермаркет';

  @override
  String get setupRetailDescription =>
      'Стандартный POS для розничной торговли.\nПродажи, возвраты, приёмка товара.\nСмены и отчётность.';

  @override
  String get setupRestaurantTitle => 'Ресторан / Кафе';

  @override
  String get setupRestaurantSubtitle => 'Столы, заказы, доставка';

  @override
  String get setupRestaurantDescription =>
      'Управление столами и залом.\nНавынос и доставка.\nРазделение счёта и сервисный сбор.';

  @override
  String get setupServiceTitle => 'Сервисный центр';

  @override
  String get setupServiceSubtitle => 'Ремонт, услуги, процедуры';

  @override
  String get setupServiceDescription =>
      'Приём в ремонт/обслуживание.\nЗаказ-наряды и отметки работ.\nОтслеживание статуса и выдача.';

  @override
  String get setupPosConfigTitle => 'Настройка кассы';

  @override
  String get setupPosConfigDescription =>
      'Укажите параметры кассового аппарата';

  @override
  String get setupCashBoxNameLabel => 'Название кассы';

  @override
  String get setupCashBoxNameHint => 'Касса 1';

  @override
  String get setupPosIdLabel => 'ID кассы';

  @override
  String get setupPrinterConfigTitle => 'Принтер чеков';

  @override
  String get setupPaperWidthLabel => 'Ширина бумаги';

  @override
  String get setupPaperWidth58 => '58 мм (32 символа)';

  @override
  String get setupPaperWidth80 => '80 мм (48 символов)';

  @override
  String get setupPrinterHeaderLabel => 'Заголовок чека';

  @override
  String get setupPrinterHeaderHint => 'Название магазина\nАдрес';

  @override
  String get setupPrinterFooterLabel => 'Подвал чека';

  @override
  String get setupPrinterFooterHint => 'Спасибо за покупку!';

  @override
  String get setupFiscalNotRequired =>
      'Для вашей страны фискализация не требуется';

  @override
  String get setupFiscalDescription =>
      'Настройте подключение к фискальному оператору';

  @override
  String get setupEnableWebkassa => 'Включить WebKassa';

  @override
  String get setupEnableOfd => 'Включить ОФД';

  @override
  String get setupWebkassaDescription =>
      'Фискализация чеков через WebKassa (Казахстан)';

  @override
  String get setupOfdDescription => 'Фискализация чеков через ОФД (Россия)';

  @override
  String get setupSkipLater => 'Пропустить (настроить позже)';

  @override
  String get setupWebkassaAccountTitle => 'Аккаунт WebKassa';

  @override
  String get setupWebkassaAccountIdLabel => 'ID аккаунта';

  @override
  String get setupWebkassaAccountIdHint => 'Ваш ID в WebKassa';

  @override
  String get setupWebkassaTokenLabel => 'Токен аккаунта';

  @override
  String get setupWebkassaTokenHint => 'API токен';

  @override
  String get setupWebkassaPosTitle => 'Касса WebKassa';

  @override
  String get setupWebkassaPosIdLabel => 'ID кассы';

  @override
  String get setupWebkassaPosIdHint => 'ID кассы в WebKassa';

  @override
  String get setupWebkassaPosTokenLabel => 'Токен кассы';

  @override
  String get setupWebkassaPosTokenHint => 'Токен кассы';

  @override
  String get setupWebkassaFactoryNoLabel => 'Заводской номер ККМ';

  @override
  String get setupOfdParamsTitle => 'Параметры ОФД';

  @override
  String get setupOfdInnLabel => 'ИНН организации';

  @override
  String get setupOfdKktRegNoLabel => 'Рег. номер ККТ';

  @override
  String get setupOfdFnNoLabel => 'Номер ФН';

  @override
  String get setupOfdUrlLabel => 'URL ОФД';

  @override
  String get setupEquipmentTitle => 'Оборудование';

  @override
  String get setupEquipmentDescription => 'Настройте подключённое оборудование';

  @override
  String get setupEquipmentPrinter => 'Принтер чеков';

  @override
  String get setupEquipmentScanner => 'Сканер штрихкодов';

  @override
  String get setupEquipmentScales => 'Весы';

  @override
  String get setupEquipmentCashDrawer => 'Денежный ящик';

  @override
  String get setupEquipmentDisplay => 'Дисплей покупателя';

  @override
  String get setupConnectionTypeLabel => 'Тип подключения';

  @override
  String get setupConnectionUsb => 'USB';

  @override
  String get setupConnectionBluetooth => 'Bluetooth';

  @override
  String get setupConnectionWifi => 'Wi-Fi / Ethernet';

  @override
  String get setupConnectionSerial => 'COM-порт';

  @override
  String get setupConnectionNone => 'Не выбран';

  @override
  String get setupPrinterIpLabel => 'IP-адрес принтера';

  @override
  String get setupPrinterMacLabel => 'MAC-адрес принтера';

  @override
  String get setupPrinterNameLabel => 'Название принтера';

  @override
  String get setupPrinterNameHint => 'Кухонный принтер';

  @override
  String get setupScannerTypeLabel => 'Тип сканера';

  @override
  String get setupScannerCamera => 'Камера устройства';

  @override
  String get setupScannerUsb => 'USB-сканер';

  @override
  String get setupScannerBluetooth => 'Bluetooth-сканер';

  @override
  String get setupScalePortLabel => 'COM-порт';

  @override
  String get setupBaudRateLabel => 'Скорость (baud rate)';

  @override
  String get setupCashDrawerConnected => 'Подключён к принтеру';

  @override
  String get setupCashDrawerConnectedDesc => 'Открывается командой принтера';

  @override
  String get setupSkip => 'Пропустить';

  @override
  String get setupPaymentTerminalsTitle => 'Платёжные терминалы';

  @override
  String get setupPaymentTerminalsDescription =>
      'Настройте интеграцию с платёжными системами';

  @override
  String get setupKaspiIpLabel => 'IP-адрес терминала';

  @override
  String get setupPortLabel => 'Порт';

  @override
  String get setupApiUrlLabel => 'API URL';

  @override
  String get setupApiKeyLabel => 'API ключ';

  @override
  String get setupNoTerminalsAvailable =>
      'Для вашего региона нет доступных платёжных терминалов';

  @override
  String get setupBusinessRulesTitle => 'Бизнес-правила';

  @override
  String get setupBusinessRulesDescription => 'Настройте правила работы кассы';

  @override
  String get setupPermissionsTitle => 'Разрешения';

  @override
  String get setupAllowDiscounts => 'Скидки';

  @override
  String get setupAllowDiscountsDesc => 'Разрешить применение скидок';

  @override
  String get setupAllowDebtSales => 'Продажа в долг';

  @override
  String get setupAllowDebtSalesDesc => 'Разрешить продажу в кредит';

  @override
  String get setupAllowPriceEdit => 'Редактирование цен';

  @override
  String get setupAllowPriceEditDesc => 'Разрешить изменение цен при продаже';

  @override
  String get setupAllowCashInOut => 'Кассовые операции';

  @override
  String get setupAllowCashInOutDesc => 'Внесение и выдача наличных';

  @override
  String get setupBlockPriceDecrease => 'Блокировать снижение цен';

  @override
  String get setupBlockPriceDecreaseDesc =>
      'Запретить продажу ниже установленной цены';

  @override
  String get setupLimitsTitle => 'Лимиты';

  @override
  String get setupAllowBigAmount => 'Крупные суммы';

  @override
  String get setupAllowBigAmountDesc => 'Разрешить операции > 1 000 000';

  @override
  String get setupCashWithdrawalLimitLabel => 'Лимит выдачи наличных';

  @override
  String get setupCashWithdrawalLimitHelper => 'Оставьте пустым для без лимита';

  @override
  String get setupLoyaltyTitle => 'Программа лояльности';

  @override
  String get setupCashbackLabel => 'Кешбэк';

  @override
  String get setupCashbackDesc => 'Включить начисление бонусов';

  @override
  String get setupCashbackRateLabel => 'Процент кешбэка';

  @override
  String get setupRoundingTitle => 'Округление';

  @override
  String get setupDiscountRounding => 'Округление скидок';

  @override
  String get setupWeightRounding => 'Округление весовых товаров';

  @override
  String get setupRoundingNone => 'Без округления';

  @override
  String get setupRoundingUp1 => 'До 1 (вверх)';

  @override
  String get setupRoundingDown1 => 'До 1 (вниз)';

  @override
  String get setupRoundingUp5 => 'До 5 (вверх)';

  @override
  String get setupRoundingDown5 => 'До 5 (вниз)';

  @override
  String get setupRoundingUp10 => 'До 10 (вверх)';

  @override
  String get setupRoundingDown10 => 'До 10 (вниз)';

  @override
  String get setupFiscalDisablesRounding =>
      'При включённой фискализации округление автоматически отключается';

  @override
  String get setupUserCreationTitle => 'Создание пользователей';

  @override
  String get setupUserCreationDescription =>
      'Создайте пользователей для работы с кассой';

  @override
  String get setupAdminLabel => 'АДМИНИСТРАТОР';

  @override
  String get setupAdminSubtitle => 'Владелец кассы';

  @override
  String get setupUserNameLabel => 'Имя';

  @override
  String get setupUserPinLabel => 'PIN';

  @override
  String get setupUserPinConfirmLabel => 'Подтверждение';

  @override
  String get setupAdminPinDefault => 'По умолчанию: 0000';

  @override
  String get setupSellerLabel => 'ПРОДАВЕЦ';

  @override
  String get setupSellerOptional => 'Опционально';

  @override
  String get setupSellerPinDefault => 'По умолчанию: 1111';

  @override
  String get setupAdminPinMismatch => 'PIN-коды администратора не совпадают';

  @override
  String get setupSummaryTitle => 'Проверьте данные';

  @override
  String get setupSummaryDescription => 'Убедитесь, что всё указано верно';

  @override
  String get setupSummaryCountry => 'Страна';

  @override
  String get setupSummaryCurrency => 'Валюта';

  @override
  String get setupSummaryFormat => 'Формат';

  @override
  String get setupSummaryVat => 'НДС';

  @override
  String get setupSummaryTelegram => 'Telegram';

  @override
  String get setupSummaryStatus => 'Статус';

  @override
  String get setupConfigured => 'Настроен';

  @override
  String get setupNotConfigured => 'Не настроен';

  @override
  String get setupSummaryOrganization => 'Организация';

  @override
  String get setupSummaryName => 'Название';

  @override
  String get setupSummaryAddress => 'Адрес';

  @override
  String get setupSummaryWorkMode => 'Режим работы';

  @override
  String get setupSummaryMode => 'Режим';

  @override
  String get setupSummaryAutonomous => 'Автономный (без сети)';

  @override
  String get setupSummaryNetwork => 'Сетевой (синхронизация)';

  @override
  String get setupSummaryPos => 'Касса';

  @override
  String get setupSummaryId => 'ID';

  @override
  String get setupEnabled => 'Включена';

  @override
  String get setupDisabled => 'Отключена';

  @override
  String get setupSummaryFiscalType => 'Тип';

  @override
  String get setupSummaryEquipment => 'Оборудование';

  @override
  String get setupSummaryPrinter => 'Принтер';

  @override
  String get setupSummaryScanner => 'Сканер';

  @override
  String get setupSummaryScales => 'Весы';

  @override
  String get setupSummaryCashDrawer => 'Ден. ящик';

  @override
  String get setupSummaryTerminals => 'Платёжные терминалы';

  @override
  String get setupSummaryRules => 'Бизнес-правила';

  @override
  String get setupSummaryDiscounts => 'Скидки';

  @override
  String get setupSummaryDebtSales => 'В долг';

  @override
  String get setupSummaryCashback => 'Кешбэк';

  @override
  String get setupSummaryBigAmount => 'Крупные суммы';

  @override
  String get setupSummaryUsers => 'Пользователи';

  @override
  String get setupSummaryAdmin => 'Администратор';

  @override
  String get setupSummarySeller => 'Продавец';

  @override
  String get setupCompleteTitle => 'Настройка завершена!';

  @override
  String get setupCompleteSubtitle => 'Касса готова к работе';

  @override
  String get setupStartWork => 'Начать работу';

  @override
  String setupVatPayerSummary(int rate) {
    return 'Плательщик НДС ($rate%)';
  }

  @override
  String get setupSummaryWkPosId => 'ID кассы WK';

  @override
  String get setupSummaryOfdInn => 'ИНН';

  @override
  String get setupScalesConfigured => 'Настроены';

  @override
  String get setupScalesNotConfigured => 'Не настроены';

  @override
  String get setupCashDrawerOn => 'Включён';

  @override
  String get setupAllowed => 'Разрешены';

  @override
  String get setupDenied => 'Запрещены';

  @override
  String get setupAllowedFem => 'Разрешена';

  @override
  String get setupDeniedFem => 'Запрещена';

  @override
  String get setupCashbackOff => 'Отключён';

  @override
  String get setupBigAmountLimit => 'Лимит 100 000';

  @override
  String get setupDisplayPortLabel => 'COM-порт';

  @override
  String get telegramAuthSkip => 'Пропустить (настроить позже)';

  @override
  String get telegramInitializing => 'Инициализация';

  @override
  String get telegramErrorTdlib => 'Ошибка TDLib';

  @override
  String get telegramAuthLogin => 'Вход в Telegram';

  @override
  String get telegramAuthCodeStep => 'Код подтверждения';

  @override
  String get telegramAuth2fa => 'Двухфакторная аутентификация';

  @override
  String get telegramRegister => 'Регистрация';

  @override
  String get telegramSearchingChannels => 'Поиск каналов';

  @override
  String get telegramLoadingData => 'Загрузка данных';

  @override
  String get telegramOrgData => 'Данные организации';

  @override
  String get telegramSetupChannels => 'Настройка каналов';

  @override
  String get telegramSetupEncryption => 'Настройка шифрования';

  @override
  String get telegramSetupComplete => 'Готово';

  @override
  String get telegramInitializingLong => 'Инициализация Telegram...';

  @override
  String get telegramConnecting => 'Подключение к серверам Telegram';

  @override
  String get telegramTdlibNotFound => 'TDLib не найден';

  @override
  String get telegramTdlibErrorMessage =>
      'Нативная библиотека TDLib не найдена.\nДля работы с Telegram необходимо установить tdjson.';

  @override
  String get telegramForWindows => 'Для Windows:';

  @override
  String get telegramWindowsInstructions =>
      '1. Скачайте TDLib: github.com/tdlib/td/releases\n2. Скопируйте tdjson.dll в корень проекта\n3. Или установите в C:\\TDLib\\bin\\';

  @override
  String get telegramPhoneAuthTitle => 'Вход по номеру телефона';

  @override
  String get telegramPhoneAuthDescription =>
      'Введите номер телефона, привязанный к вашему аккаунту Telegram';

  @override
  String get telegramCountryCodeLabel => 'Код страны';

  @override
  String get telegramPhoneNumber => 'Номер телефона';

  @override
  String get telegramGetCode => 'Получить код';

  @override
  String get telegramRefreshQr => 'Обновить QR-код';

  @override
  String get telegramSignUp => 'Зарегистрироваться';

  @override
  String get telegramEnterStoreName => 'Введите название магазина';

  @override
  String get telegramInvalidBinIin => 'Введите корректный БИН/ИИН (12 цифр)';

  @override
  String get telegramInvalidCode => 'Введите корректный код';

  @override
  String get telegramEnterPassword => 'Введите пароль';

  @override
  String get telegramCodeResent => 'Код отправлен повторно';

  @override
  String get telegramEnterName => 'Введите имя';

  @override
  String get telegramManageAccount => 'Управление аккаунтом';

  @override
  String get telegramNotificationsSection => 'Уведомления';

  @override
  String get telegramNotificationsDesc =>
      'Получать уведомления о продажах, сменах и др.';

  @override
  String get telegramNotifySales => 'Уведомления о продажах';

  @override
  String get telegramNotifySalesDesc => 'Крупные продажи, возвраты';

  @override
  String get telegramNotifyShifts => 'Уведомления о сменах';

  @override
  String get telegramNotifyShiftsDesc => 'Открытие и закрытие смен';

  @override
  String get telegramNotifyCritical => 'Критические уведомления';

  @override
  String get telegramNotifyCriticalDesc => 'Ошибки, проблемы с OFD';

  @override
  String get telegramNotifyStock => 'Уведомления об остатках';

  @override
  String get telegramNotifyStockDesc => 'Дефицит товаров';

  @override
  String get telegramSyncSettings => 'Настройки синхронизации';

  @override
  String get telegramAutoSyncDesc => 'Автоматически синхронизировать данные';

  @override
  String get telegramSyncInterval1min => '1 минута';

  @override
  String get telegramSyncInterval5min => '5 минут';

  @override
  String get telegramSyncInterval15min => '15 минут';

  @override
  String get telegramSyncInterval30min => '30 минут';

  @override
  String get telegramSyncInterval1hour => '1 час';

  @override
  String get telegramSystemChannels => 'Системные каналы';

  @override
  String get telegramRefresh => 'Обновить';

  @override
  String get telegramChannelsNotConnected =>
      'Каналы не подключены.\nВойдите в Telegram для автоматического создания.';

  @override
  String telegramChannelsConnected(int connected, int total) {
    return '$connected из $total каналов подключено';
  }

  @override
  String telegramChannelsLoadError(String error) {
    return 'Ошибка загрузки каналов: $error';
  }

  @override
  String get telegramForceSyncDesc => 'Синхронизировать все данные сейчас';

  @override
  String get telegramFullSyncDesc => 'Сбросить и пересинхронизировать всё';

  @override
  String get telegramRecreateChannelsDesc => 'Пересоздать системные каналы';

  @override
  String get telegramLogoutDesc => 'Отключить Telegram интеграцию';

  @override
  String get telegramFullSyncWarning =>
      'Это сбросит все временные метки синхронизации и перезагрузит все данные. Операция может занять продолжительное время.';

  @override
  String get telegramRecreateChannelsWarning =>
      'Это действие пересоздаст все системные каналы. Существующие данные в каналах будут потеряны.';

  @override
  String get telegramLogoutWarning =>
      'Вы уверены, что хотите выйти? Синхронизация и уведомления будут отключены.';

  @override
  String get telegramChannelsRecreated => 'Каналы пересозданы';

  @override
  String get telegramConnectedStatus => 'Подключено';

  @override
  String get telegramNotConnected => 'Не подключено';

  @override
  String get telegramAccountLabel => 'Telegram аккаунт';

  @override
  String get telegramLoginForSync => 'Войдите для синхронизации данных';

  @override
  String get channelDescSystemEvents => 'Системные события';

  @override
  String get channelDescSales => 'Лента продаж';

  @override
  String get channelDescAlerts => 'Критические уведомления';

  @override
  String get channelDescReports => 'Отчёты и сводки';

  @override
  String get channelDescSync => 'Синхронизация данных';

  @override
  String get channelDescFiscal => 'Фискальные события';

  @override
  String get channelDescStaffChat => 'Чат сотрудников';

  @override
  String get channelDescDataExchange => 'Обмен данными';

  @override
  String get channelDescTerminalStatus => 'Статус терминала';

  @override
  String get channelDescBackup => 'Резервные копии БД';

  @override
  String get chatNoConnectionBanner =>
      'Нет соединения. Сообщения будут отправлены при восстановлении.';

  @override
  String get chatLinkTelegramForId =>
      'Привяжите Telegram для идентификации в чате';

  @override
  String chatSendError(String error) {
    return 'Ошибка отправки: $error';
  }

  @override
  String chatFoundMessages(int count) {
    return 'Найдено $count сообщений';
  }

  @override
  String get chatNoResults => 'Ничего не найдено';

  @override
  String get chatCopyUidInstructions =>
      'Скопируйте UID для использования в других системах';

  @override
  String get chatUidExample => 'Например: telepos@pos-1';

  @override
  String get chatServiceUnavailable => 'Сервис недоступен';

  @override
  String get chatTelegramLinked => 'Telegram успешно привязан';

  @override
  String get additionalLogout => 'Выход';

  @override
  String get additionalLockCashier => 'Блокировка';

  @override
  String get additionalPrinterAction => 'Принтер';

  @override
  String get additionalPrintLastReceipt => 'Последний чек';

  @override
  String get additionalSyncAction => 'Синхронизация';

  @override
  String get additionalCheckPrice => 'Проверка цены';

  @override
  String get additionalMinimize => 'Свернуть';

  @override
  String get additionalCustomers => 'Покупатели';

  @override
  String get additionalUpdateAction => 'Обновление';

  @override
  String get additionalExtraPrinter => 'Доп. принтер';

  @override
  String get additionalSupplyAction => 'Приёмка';

  @override
  String get additionalLanguageAction => 'Язык';

  @override
  String get additionalKaspiPos => 'Kaspi POS';

  @override
  String get additionalPrinterEscPos => 'Термопринтер ESC/POS';

  @override
  String get additionalPrinterNotConfigured => 'Принтер не настроен';

  @override
  String get additionalPrinterWifi => 'Wi-Fi принтер';

  @override
  String get additionalPrinterWifiDesc => 'Подключение по IP';

  @override
  String get additionalPrinterBluetooth => 'Bluetooth принтер';

  @override
  String get additionalPrinterBluetoothDesc => 'Поиск устройств';

  @override
  String get additionalPrinterUsb => 'USB принтер';

  @override
  String get additionalPrinterSystem => 'Системный принтер';

  @override
  String get additionalPrinterDisconnected => 'Принтер отключён';

  @override
  String get additionalPrinterIpLabel => 'IP';

  @override
  String get additionalPrinterEnterIp => 'Введите IP адрес';

  @override
  String additionalPrinterConnecting(String address) {
    return 'Подключение к $address...';
  }

  @override
  String get additionalPrinterConnectingUsb => 'Подключение USB принтера...';

  @override
  String get additionalPrinterNotConnected => 'Принтер не подключён';

  @override
  String get additionalPrintingLastReceipt => 'Печать последнего чека...';

  @override
  String get additionalTestReceiptTitle => '=== ТЕСТОВЫЙ ЧЕК ===';

  @override
  String get additionalReceiptPrinted => 'Чек напечатан';

  @override
  String additionalPriceSearching(String query) {
    return 'Поиск: $query';
  }

  @override
  String get additionalMinimizing => 'Сворачивание окна...';

  @override
  String get additionalLatestVersion => 'У вас установлена последняя версия';

  @override
  String get additionalExtraPrinterTitle => 'Дополнительный принтер';

  @override
  String get additionalExtraPrinterUsedFor =>
      'Дополнительный принтер используется для:';

  @override
  String get additionalExtraPrinterLabels => 'Печать этикеток';

  @override
  String get additionalExtraPrinterKitchen => 'Печать на кухню';

  @override
  String get additionalExtraPrinterDuplicate => 'Дубликат чека';

  @override
  String get additionalKaspiPosTitle => 'Kaspi POS';

  @override
  String get additionalKaspiPosDesc => 'Терминал Kaspi для приёма платежей.';

  @override
  String get additionalKaspiPosNotConnected => 'Статус: Не подключён';

  @override
  String additionalPrinterConnectedName(String name) {
    return 'Принтер подключён: $name';
  }

  @override
  String additionalErrorWithMessage(String message) {
    return 'Ошибка: $message';
  }

  @override
  String get additionalPrinterUsbNotSupported =>
      'USB принтеры не поддерживаются';

  @override
  String get additionalPrinterUsbConnected => 'USB принтер подключён';

  @override
  String get additionalBarcodeLabel => 'Штрихкод';

  @override
  String get additionalBarcodeHint => 'Отсканируйте или введите';

  @override
  String additionalTestReceiptProduct(String number) {
    return 'Товар $number';
  }

  @override
  String get additionalTestReceiptTotal => 'ИТОГО:';

  @override
  String get additionalTestReceiptThankYou => 'Спасибо за покупку!';

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
      'Это сбросит все метки синхронизации и перезагрузит все данные. Это может занять продолжительное время. Продолжить?';

  @override
  String get transportSyncAbout => 'О синхронизации';

  @override
  String transportSyncStateError(String error) {
    return 'Ошибка загрузки состояния синхронизации: $error';
  }

  @override
  String get transportSyncInfoDialog =>
      'Каждый тип данных синхронизируется независимо. Передаются только элементы, изменённые после последней синхронизации.\n\nИнтервал: 5 минут (по умолчанию)\nДанные шифруются AES-256-GCM перед передачей.';

  @override
  String get transportSyncNever => 'Никогда';

  @override
  String get transportModeDescription =>
      'Выберите способ обмена данными с сервером';

  @override
  String get transportModeRest => 'REST API';

  @override
  String get transportModeRestDesc => 'Классическое HTTP/WebSocket подключение';

  @override
  String get transportModeTelegram => 'Telegram';

  @override
  String get transportModeTelegramDesc => 'Telegram как транспортный слой';

  @override
  String get transportModeHybrid => 'Гибридный';

  @override
  String get transportModeHybridDesc => 'Telegram основной, REST как резерв';

  @override
  String get transportModeRecommended => 'Рекомендуется';

  @override
  String transportSyncIntervalMinutes(int minutes) {
    return '$minutes минут';
  }

  @override
  String get transportSyncOnConnectivity =>
      'Синхронизировать при восстановлении сети';

  @override
  String transportSyncIntervalOption(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes минут',
      few: '$minutes минуты',
      one: '$minutes минута',
    );
    return '$_temp0';
  }

  @override
  String get transportEnableQueue => 'Очередь операций';

  @override
  String get transportEnableQueueDesc =>
      'Буферизация операций при отсутствии сети';

  @override
  String get transportMaxQueueSize => 'Размер очереди';

  @override
  String transportQueueSizeStatus(int size) {
    return '$size операций';
  }

  @override
  String get transportAutoCleanup => 'Автоочистка';

  @override
  String get transportAutoCleanupDesc =>
      'Удалять завершённые операции через 7 дней';

  @override
  String get transportNotifyChanges => 'Смена транспорта';

  @override
  String get transportNotifyChangesDesc =>
      'Уведомлять при смене режима транспорта';

  @override
  String get transportNotifySyncErrors => 'Ошибки синхронизации';

  @override
  String get transportNotifySyncErrorsDesc =>
      'Уведомлять об ошибках синхронизации';

  @override
  String get transportNotifyOfflineOnline => 'Связь';

  @override
  String get transportNotifyConnectivityDesc =>
      'Уведомлять о смене подключения';

  @override
  String get transportNotifyQueueFull => 'Очередь полна';

  @override
  String get transportNotifyQueueFullDesc =>
      'Уведомлять при заполнении очереди';

  @override
  String saleErrorInitiation(String error) {
    return 'Ошибка инициации продажи: $error';
  }

  @override
  String get saleErrorNotInitialized => 'Продажа не инициализирована';

  @override
  String get saleErrorEmpty => 'Чек пуст';

  @override
  String saleErrorCompletion(String error) {
    return 'Ошибка завершения продажи: $error';
  }

  @override
  String saleErrorSearch(String error) {
    return 'Ошибка поиска: $error';
  }

  @override
  String saleErrorDeferred(String error) {
    return 'Ошибка отложения чека: $error';
  }

  @override
  String get saleErrorDeferredNotFound => 'Отложенный чек не найден';

  @override
  String saleErrorLoadingDeferred(String error) {
    return 'Ошибка загрузки отложенного чека: $error';
  }

  @override
  String get paymentCustomerDefault => 'Клиент';

  @override
  String get paymentErrorFormation =>
      'Не удалось сформировать платёж. Проверьте настройки счетов.';

  @override
  String get paymentErrorSaving => 'Ошибка сохранения продажи';

  @override
  String paymentErrorProcessing(String error) {
    return 'Ошибка обработки платежа: $error';
  }

  @override
  String paymentAccountDefault(int id) {
    return 'Счёт $id';
  }

  @override
  String refundErrorReceiptNotFound(String number) {
    return 'Чек #$number не найден';
  }

  @override
  String refundErrorLoadingReceipt(String error) {
    return 'Ошибка загрузки чека: $error';
  }

  @override
  String refundErrorSearch(String error) {
    return 'Ошибка поиска: $error';
  }

  @override
  String get refundErrorProductNotFound => 'Товар не найден';

  @override
  String get refundErrorNotAuthenticated => 'Пользователь не авторизован';

  @override
  String refundErrorProcessing(String error) {
    return 'Ошибка возврата: $error';
  }

  @override
  String shiftErrorLoadingData(String error) {
    return 'Ошибка загрузки данных смены: $error';
  }

  @override
  String shiftErrorOpening(String error) {
    return 'Ошибка открытия смены: $error';
  }

  @override
  String shiftErrorClosing(String error) {
    return 'Ошибка закрытия смены: $error';
  }

  @override
  String shiftErrorPrinting(String error) {
    return 'Ошибка печати Z-отчёта: $error';
  }

  @override
  String get cashOpTypeInvestment => 'Внесение';

  @override
  String get cashOpTypeExpense => 'Расход';

  @override
  String get cashOpTypeDividend => 'Изъятие';

  @override
  String get supplyNoName => 'Без имени';

  @override
  String get supplyNoTitle => 'Без названия';

  @override
  String get supplyErrorSupplierNotFound => 'Поставщик не найден';

  @override
  String supplyErrorSelectingSupplier(String error) {
    return 'Ошибка выбора поставщика: $error';
  }

  @override
  String get supplyErrorAccountNotFound => 'Счёт не найден';

  @override
  String supplyErrorSelectingAccount(String error) {
    return 'Ошибка выбора счёта: $error';
  }

  @override
  String supplyErrorAddingProduct(String error) {
    return 'Ошибка добавления товара: $error';
  }

  @override
  String get supplyErrorProductNotFound => 'Товар не найден';

  @override
  String get supplyErrorMissingFields => 'Заполните все обязательные поля';

  @override
  String supplyErrorSaving(String error) {
    return 'Ошибка сохранения: $error';
  }

  @override
  String historyErrorLoading(String error) {
    return 'Ошибка загрузки истории: $error';
  }

  @override
  String get syncTypeProducts => 'Товары';

  @override
  String get syncTypePrices => 'Цены';

  @override
  String get syncTypeCategories => 'Категории';

  @override
  String get syncTypeAgents => 'Контрагенты';

  @override
  String get syncTypeConfig => 'Настройки';

  @override
  String get syncTypeSales => 'Продажи';

  @override
  String get syncTypeRefunds => 'Возвраты';

  @override
  String get syncTypeCashOps => 'Кассовые операции';

  @override
  String get syncTypeShifts => 'Смены';

  @override
  String get syncTypeSupplies => 'Приёмки';

  @override
  String get syncStepPreparing => 'Подготовка...';

  @override
  String syncStepUploading(String type) {
    return 'Выгрузка: $type';
  }

  @override
  String syncStepDownloading(String type) {
    return 'Загрузка: $type';
  }

  @override
  String get syncCompleted => 'Синхронизация завершена';

  @override
  String get loginErrorNoUsers => 'Нет зарегистрированных пользователей';

  @override
  String loginErrorLoadingData(String error) {
    return 'Ошибка загрузки данных: $error';
  }

  @override
  String get loginErrorSelectUser => 'Выберите пользователя';

  @override
  String get loginErrorIncompletePin => 'Введите PIN-код (минимум 4 цифры)';

  @override
  String get loginErrorNoRsaKey =>
      'Ошибка: RSA ключ не настроен. Обратитесь к администратору.';

  @override
  String get loginErrorWrongPin => 'Неверный PIN-код';

  @override
  String get loginErrorSystemTime =>
      'Системное время некорректно. Проверьте настройки даты и времени.';

  @override
  String get receiptLabelBin => 'БИН:';

  @override
  String get receiptLabelPhone => 'Тел:';

  @override
  String get receiptLabelReceiptNo => 'Чек №:';

  @override
  String get receiptLabelPosId => 'Касса:';

  @override
  String get receiptLabelDate => 'Дата:';

  @override
  String get receiptLabelCashier => 'Кассир:';

  @override
  String get receiptLabelTable => 'Стол:';

  @override
  String get receiptLabelWaiter => 'Официант:';

  @override
  String get receiptLabelGuests => 'Гостей:';

  @override
  String get receiptLabelCustomer => 'Клиент:';

  @override
  String get receiptLabelSubtotal => 'Подытог:';

  @override
  String get receiptLabelDiscount => 'Скидка:';

  @override
  String get receiptLabelServiceCharge => 'Сервис. сбор:';

  @override
  String get receiptLabelTotal => 'ИТОГО:';

  @override
  String receiptLabelVat(String percent) {
    return 'в т.ч. НДС $percent%:';
  }

  @override
  String get receiptLabelCash => 'Наличные:';

  @override
  String get receiptLabelCard => 'Карта:';

  @override
  String get receiptLabelChange => 'Сдача:';

  @override
  String get receiptLabelCheckReceipt => 'Проверить чек:';

  @override
  String get receiptLabelItemName => 'Наименование';

  @override
  String get receiptLabelQty => 'Кол';

  @override
  String get receiptLabelPrice => 'Цена';

  @override
  String get receiptLabelAmount => 'Сумма';

  @override
  String get receiptLabelItemDiscount => 'Скидка:';

  @override
  String get receiptLabelFiscalBin => 'БИН:';

  @override
  String get receiptLabelFiscalNo => 'ФН:';

  @override
  String get receiptLabelFiscalSign => 'ФП:';

  @override
  String get receiptLabelVatCertificate => 'НДС:';

  @override
  String get receiptLabelOfflineMode => '*** ОФФЛАЙН ***';

  @override
  String get receiptLabelRefundHeader => '*** ВОЗВРАТ ***';

  @override
  String get receiptLabelRefundNo => 'Возврат №:';

  @override
  String get receiptLabelReason => 'Причина:';

  @override
  String get receiptLabelRefundTotal => 'К ВОЗВРАТУ:';

  @override
  String get receiptLabelZReport => 'Z-ОТЧЁТ';

  @override
  String get receiptLabelShiftClosing => 'ЗАКРЫТИЕ СМЕНЫ';

  @override
  String get receiptLabelShiftNo => 'Смена №:';

  @override
  String get receiptLabelShiftOpenTime => 'Открыта:';

  @override
  String get receiptLabelShiftCloseTime => 'Закрыта:';

  @override
  String get receiptLabelSales => 'ПРОДАЖИ';

  @override
  String get receiptLabelQuantity => 'Количество:';

  @override
  String get receiptLabelCashSales => 'Наличные:';

  @override
  String get receiptLabelCardSales => 'Карта:';

  @override
  String get receiptLabelSalesTotal => 'Итого:';

  @override
  String get receiptLabelRefunds => 'ВОЗВРАТЫ';

  @override
  String get receiptLabelRefundQty => 'Количество:';

  @override
  String get receiptLabelRefundAmount => 'Сумма:';

  @override
  String get receiptLabelCashOperations => 'КАССОВЫЕ ОПЕРАЦИИ';

  @override
  String get receiptLabelInvestments => 'Внесения:';

  @override
  String get receiptLabelExpenses => 'Выплаты:';

  @override
  String get receiptLabelRevenue => 'ВЫРУЧКА:';

  @override
  String get receiptLabelCashInDrawer => 'В КАССЕ:';

  @override
  String get receiptLabelXReport => 'X-ОТЧЁТ';

  @override
  String get receiptLabelType => 'Тип:';

  @override
  String get receiptLabelDescription => 'Описание:';

  @override
  String get receiptLabelDebtPayment => 'ПОГАШЕНИЕ ДОЛГА';

  @override
  String get receiptLabelPreviousDebt => 'Долг был:';

  @override
  String get receiptLabelPaidAmount => 'ОПЛАЧЕНО:';

  @override
  String get receiptLabelRemainingDebt => 'Остаток:';

  @override
  String get receiptLabelTestPrint => 'TEST PRINT';

  @override
  String get receiptLabelThankYou => 'Спасибо за покупку!';

  @override
  String get receiptLabelSaleReceipt => 'КАССОВЫЙ ЧЕК';

  @override
  String get receiptLabelOfflineHeader => '*** ОФФЛАЙН РЕЖИМ ***';

  @override
  String get receiptLabelVatCertificateTitle => 'Свидетельство НДС:';

  @override
  String get fiscalErrorBin12Digits => 'БИН должен содержать 12 цифр';

  @override
  String get fiscalErrorBinDigitsOnly => 'БИН должен содержать только цифры';

  @override
  String get fiscalErrorFiscalNoRequired => 'Фискальный номер обязателен';

  @override
  String get fiscalErrorRnkRequired => 'РНК обязателен';

  @override
  String get fiscalErrorZnkRequired => 'ЗНК обязателен';

  @override
  String get fiscalErrorVatSerialRequired =>
      'Серия свидетельства НДС обязательна';

  @override
  String get fiscalErrorVatNumberRequired =>
      'Номер свидетельства НДС обязателен';

  @override
  String get telegramTabPhone => 'По телефону';

  @override
  String get telegramTabQr => 'QR-код';

  @override
  String get telegramQrAuthTitle => 'Вход через QR-код';

  @override
  String get telegramQrAuthDescription =>
      'Отсканируйте QR-код в приложении Telegram на телефоне';

  @override
  String get telegramQrTapToGenerate => 'Нажмите для генерации\nQR-кода';

  @override
  String get telegramQrHowToScan => 'Как отсканировать:';

  @override
  String get telegramQrStep1 => 'Откройте Telegram на телефоне';

  @override
  String get telegramQrStep2 => 'Перейдите в Настройки → Устройства';

  @override
  String get telegramQrStep3 => 'Нажмите \"Подключить устройство\"';

  @override
  String get telegramQrStep4 => 'Отсканируйте QR-код';

  @override
  String get telegramEnterCode => 'Введите код';

  @override
  String telegramCodeSentTo(String phone) {
    return 'Код был отправлен в Telegram на номер\n$phone';
  }

  @override
  String get telegramCodeLabel => 'Код подтверждения';

  @override
  String get telegramPasswordDescription =>
      'Введите пароль от вашего аккаунта Telegram';

  @override
  String telegramPasswordHint(String hint) {
    return 'Подсказка: $hint';
  }

  @override
  String get telegramPasswordLabel => 'Пароль';

  @override
  String get telegramRegistrationDescription =>
      'Аккаунт с этим номером не найден.\nСоздайте новый аккаунт Telegram.';

  @override
  String get telegramFirstNameLabel => 'Имя';

  @override
  String get telegramLastNameLabel => 'Фамилия (необязательно)';

  @override
  String get telegramLoadingOrgData => 'Загрузка данных организации...';

  @override
  String get telegramSearchingExistingChannels =>
      'Поиск существующих каналов...';

  @override
  String get telegramFoundChannels =>
      'Найдены каналы организации.\nЗагрузка конфигурации...';

  @override
  String get telegramCheckingChannels => 'Проверяем наличие каналов...';

  @override
  String get telegramOrgDataNotLoaded =>
      'Не удалось загрузить данные.\nВведите информацию о вашей организации.';

  @override
  String get telegramOrgDataFirstRun =>
      'Первый запуск TelePOS.\nВведите информацию о вашей организации.';

  @override
  String get telegramStoreNameLabel => 'Название магазина *';

  @override
  String get telegramStoreNameHint => 'Мой магазин';

  @override
  String get telegramBinLabel => 'БИН/ИИН организации *';

  @override
  String get telegramAddressLabel => 'Адрес (необязательно)';

  @override
  String get telegramAddressHint => 'г. Алматы, ул. Примерная, 123';

  @override
  String get telegramPosIdLabel => 'ID кассы';

  @override
  String get telegramOwnerNameLabel => 'Имя владельца (необязательно)';

  @override
  String get telegramImportantNote => 'Важно';

  @override
  String get telegramOrgDataNote =>
      'Эти данные будут использоваться для создания системных каналов и синхронизации между кассами. На других устройствах данные загрузятся автоматически.';

  @override
  String get telegramCreatingChannels => 'Создание системных каналов...';

  @override
  String get telegramSettingUpEncryption => 'Настройка шифрования...';

  @override
  String get telegramSettingUp => 'Настройка...';

  @override
  String get telegramPleaseWait =>
      'Пожалуйста, подождите.\nЭто может занять некоторое время.';

  @override
  String get telegramSetupDone => 'Настройка завершена!';

  @override
  String get telegramSetupDoneMessage =>
      'Telegram успешно настроен.\nСистемные каналы созданы.';

  @override
  String get telegramTermsNotice =>
      'Нажимая \"Получить код\", вы соглашаетесь с условиями использования Telegram';

  @override
  String get telegramActionsSection => 'Действия';

  @override
  String get chatNotConfigured => 'Чат не настроен';

  @override
  String get chatCanDeleteOwnOnly => 'Можно удалять только свои сообщения';

  @override
  String get chatMessageDeleted => 'Сообщение удалено';

  @override
  String get chatDeleteFailed => 'Не удалось удалить сообщение';

  @override
  String get chatTelegramNotLinked => 'Telegram не привязан';

  @override
  String get chatLinkInstructions =>
      'Введите ваш Telegram User ID для идентификации в чате сотрудников.';

  @override
  String get chatLinkHowTo =>
      'Как узнать ID:\n1. Откройте @userinfobot в Telegram\n2. Нажмите /start\n3. Скопируйте число из поля \"Id\"';

  @override
  String get chatLinkFailed =>
      'Не удалось привязать. Возможно, этот ID уже используется.';

  @override
  String get chatPhotoSent => 'Фото отправлено';

  @override
  String get chatPhotoFailed => 'Не удалось отправить фото';

  @override
  String get chatPhotoError => 'Ошибка при выборе фото';

  @override
  String get chatPhotoUnavailableWeb => 'Отправка фото недоступна в веб-версии';

  @override
  String get chatDocSent => 'Документ отправлен';

  @override
  String get chatDocFailed => 'Не удалось отправить документ';

  @override
  String get chatDocError => 'Ошибка при выборе документа';

  @override
  String get chatDocUnavailableWeb =>
      'Отправка документов недоступна в веб-версии';

  @override
  String get chatDocPathError => 'Не удалось получить путь к файлу';

  @override
  String get chatDocTooLarge => 'Файл слишком большой (макс. 50 МБ)';

  @override
  String get chatLocationSent => 'Местоположение отправлено';

  @override
  String get chatLocationFailed => 'Не удалось отправить местоположение';

  @override
  String get chatLocationError => 'Ошибка получения местоположения';

  @override
  String get chatLocationUnavailableWeb => 'Геолокация недоступна в веб-версии';

  @override
  String get chatLocationDenied => 'Доступ к геолокации запрещён';

  @override
  String get chatLocationDeniedForever =>
      'Доступ к геолокации запрещён навсегда. Измените в настройках.';

  @override
  String get chatLocationServiceDisabled => 'Включите геолокацию на устройстве';

  @override
  String get syncToUpload => 'К выгрузке';

  @override
  String get syncToDownload => 'К загрузке';

  @override
  String get syncDataTypeCol => 'Тип данных';

  @override
  String get syncDirectionCol => 'Направление';

  @override
  String get syncPendingCol => 'Ожидает';

  @override
  String get syncStatusCol => 'Статус';

  @override
  String get syncProgressCol => 'Прогресс';

  @override
  String get syncUpload => 'Выгрузка';

  @override
  String get syncDownload => 'Загрузка';

  @override
  String syncPendingCount(int count) {
    return 'Ожидает: $count';
  }

  @override
  String get syncInfoTelegram =>
      'Данные синхронизируются между кассами через Telegram. Пользователи общие для всех касс.';

  @override
  String get syncAutoEnabled => 'Данные синхронизируются автоматически';

  @override
  String get syncManualOnly => 'Синхронизация только вручную';

  @override
  String syncMinutes(int count) {
    return '$count мин';
  }

  @override
  String get agentBinIin => 'БИН/ИИН';

  @override
  String get agentLastOperation => 'Последняя операция';

  @override
  String get agentNoAdditionalInfo => 'Нет дополнительной информации';

  @override
  String get agentNoDebt => 'Нет задолженности';

  @override
  String agentDeletedWithName(String name) {
    return 'Клиент \"$name\" удалён';
  }

  @override
  String agentDeleteError(String error) {
    return 'Ошибка удаления: $error';
  }

  @override
  String get agentNewCustomer => 'Новый клиент';

  @override
  String get agentTypeCustomer => 'Клиент';

  @override
  String get agentTypeSupplier => 'Поставщик';

  @override
  String get agentNameHint => 'Введите имя';

  @override
  String get agentBinHint => '12 цифр';

  @override
  String get agentCustomerFound => 'Клиент найден';

  @override
  String get agentDeletedPhoneMsg => 'Клиент с таким телефоном был удалён';

  @override
  String get agentRestoreQuestion => 'Хотите восстановить?';

  @override
  String get agentRestore => 'Восстановить';

  @override
  String get kaspiTerminal => 'Kaspi POS Терминал';

  @override
  String get kaspiIpAddress => 'IP-адрес терминала';

  @override
  String get kaspiInvalidIp => 'Неверный формат IP-адреса';

  @override
  String get kaspiPort => 'Порт';

  @override
  String get kaspiTesting => 'Проверка...';

  @override
  String get kaspiTest => 'ТЕСТ';

  @override
  String get kaspiDisconnected => 'Не подключено';

  @override
  String get kaspiConnecting => 'Подключение...';

  @override
  String get kaspiConnected => 'Соединение установлено';

  @override
  String get kaspiNoConnection => 'Нет соединения';

  @override
  String get kaspiTestPassed => 'Тест пройден';

  @override
  String get kaspiTestFailed => 'Тест не пройден';

  @override
  String kaspiLatency(String ms) {
    return 'Задержка: $ms мс';
  }

  @override
  String kaspiTerminalInfo(String info) {
    return 'Терминал: $info';
  }

  @override
  String get splashSubtitle => 'Система кассового обслуживания';

  @override
  String get splashInitializing => 'Инициализация...';

  @override
  String get splashLoadingOrg => 'Загрузка данных организации...';

  @override
  String get splashEnterPosKey => 'Введите ключ POS';

  @override
  String get splashEnterPosKeyMessage =>
      'Для активации кассы введите ключ, полученный от администратора.';

  @override
  String get splashPosKeyHint => 'XXXX-XXXX-XXXX-XXXX';

  @override
  String get splashKeyEmpty => 'Ключ не может быть пустым';

  @override
  String get splashKeyTooShort => 'Ключ слишком короткий';

  @override
  String get splashKeyNotEntered => 'Ключ не введён';

  @override
  String get splashKeyRequiredMessage =>
      'Без ключа POS работа невозможна. Приложение будет закрыто.';

  @override
  String get splashDataCorrupted => 'Данные повреждены';

  @override
  String get splashDataCorruptedMessage =>
      'Обязательные данные приложения отсутствуют или повреждены.\n\nВыберите действие:';

  @override
  String get splashReconfigure => 'Настроить заново';

  @override
  String get splashExit => 'Выйти';

  @override
  String get splashDatabaseError => 'Ошибка базы данных';

  @override
  String get splashDatabaseErrorMessage =>
      'База данных повреждена или недоступна.\n\nВы можете попробовать восстановить из резервной копии или настроить кассу заново.';

  @override
  String get splashRestoreFromBackup => 'Восстановить из бэкапа';

  @override
  String get splashSyncSuspended => 'Синхронизация приостановлена';

  @override
  String get splashSyncSuspendedMessage =>
      'Синхронизация данных временно приостановлена.\n\nКасса работает в автономном режиме. Данные будут синхронизированы при восстановлении связи.';

  @override
  String get splashAuthError =>
      'Ошибка авторизации\n\nТокен доступа недействителен или истёк.\nОбратитесь к администратору для получения нового ключа.';

  @override
  String get splashSupportEnded =>
      'Версия не поддерживается\n\nЭта версия приложения больше не поддерживается.\nПожалуйста, обновите приложение до последней версии.';

  @override
  String get generalSettingsTitle => 'Настройки';

  @override
  String get generalSettingsPosInfo => 'Информация о кассе';

  @override
  String get generalSettingsCashBoxName => 'Название кассы';

  @override
  String get generalSettingsCompany => 'Компания';

  @override
  String get generalSettingsIinBin => 'ИИН/БИН';

  @override
  String get generalSettingsPosId => 'ID POS';

  @override
  String get generalSettingsStoreId => 'ID магазина';

  @override
  String get generalSettingsNotSpecified => 'Не указано';

  @override
  String get generalSettingsAppVersion => 'Версия приложения';

  @override
  String get generalSettingsVersion => 'Версия';

  @override
  String get generalSettingsPlatform => 'Платформа';

  @override
  String get generalSettingsLanguage => 'Язык интерфейса';

  @override
  String get generalSettingsTheme => 'Оформление';

  @override
  String get generalSettingsThemeDesc => 'Светлая, тёмная или как в системе';

  @override
  String get generalSettingsThemeLight => 'Светлая';

  @override
  String get generalSettingsThemeDark => 'Тёмная';

  @override
  String get generalSettingsThemeSystem => 'Как в системе';

  @override
  String generalSettingsLanguageChanged(String language) {
    return 'Язык изменён на $language';
  }

  @override
  String get generalSettingsCurrency => 'Валюта';

  @override
  String get generalSettingsCurrencySymbol => 'Символ';

  @override
  String get generalSettingsCurrencyCode => 'Код';

  @override
  String get generalSettingsCountry => 'Страна';

  @override
  String get generalSettingsAdditional => 'Дополнительные настройки';

  @override
  String get generalSettingsTransport => 'Транспорт';

  @override
  String get generalSettingsTransportSubtitle =>
      'Настройки синхронизации данных';

  @override
  String get generalSettingsPrinter => 'Принтер';

  @override
  String get generalSettingsPrinterSubtitle => 'Настройки печати чеков';

  @override
  String get generalSettingsPermissions => 'Права доступа';

  @override
  String get generalSettingsPermissionsSubtitle => 'Разрешения для кассиров';

  @override
  String get generalSettingsFiscal => 'Фискализация';

  @override
  String get generalSettingsFiscalSubtitle => 'WebKassa, ОФД, НДС';

  @override
  String get generalSettingsRestaurant => 'Режим работы';

  @override
  String get generalSettingsRestaurantSubtitle => 'Розница, ресторан, сервис';

  @override
  String get generalSettingsTelegram => 'Telegram';

  @override
  String get generalSettingsTelegramSubtitle => 'Каналы связи и боты';

  @override
  String get generalSettingsPosInfoDesc => 'Название кассы, компания, ID';

  @override
  String get generalSettingsVersionDesc => 'Текущая версия и платформа';

  @override
  String get generalSettingsLanguageDesc => 'Выбор языка интерфейса';

  @override
  String get generalSettingsCurrencyDesc => 'Валюта и страна';

  @override
  String get generalSettingsUpdate => 'Обновление';

  @override
  String get generalSettingsUpdateSubtitle => 'Проверка и установка обновлений';

  @override
  String get generalSettingsAppUpdate => 'Обновление приложения';

  @override
  String get generalSettingsAppUpdateSubtitle =>
      'Обновление кассы (не путать с обновлением ОС)';

  @override
  String get generalSettingsUpdateDesc => 'Текущая версия и обновления';

  @override
  String get settingsUpdateTitle => 'Обновление приложения';

  @override
  String get settingsUpdateCurrentVersion => 'Текущая версия';

  @override
  String get settingsUpdateCheckBtn => 'Проверить обновления';

  @override
  String get settingsUpdateChecking => 'Проверка обновлений...';

  @override
  String get settingsUpdateUpToDate => 'Установлена последняя версия';

  @override
  String settingsUpdateAvailable(String version) {
    return 'Доступна версия $version';
  }

  @override
  String get settingsUpdateDownloadBtn => 'Скачать обновление';

  @override
  String settingsUpdateDownloading(String percent) {
    return 'Загрузка... $percent%';
  }

  @override
  String get settingsUpdateInstallBtn => 'Установить обновление';

  @override
  String get settingsUpdateInstalling => 'Установка...';

  @override
  String get settingsUpdateFailed => 'Ошибка обновления';

  @override
  String get settingsUpdateAutoEnabled =>
      'Автоматическая проверка каждые 3 часа';

  @override
  String get settingsUpdateCloseShift => 'Закройте смену перед обновлением';

  @override
  String get settingsUpdateReleaseNotes => 'Что нового';

  @override
  String get countryKazakhstan => 'Казахстан';

  @override
  String get countryRussia => 'Россия';

  @override
  String get countryKyrgyzstan => 'Кыргызстан';

  @override
  String get countryUzbekistan => 'Узбекистан';

  @override
  String get countryUSA => 'США';

  @override
  String get countryTurkmenistan => 'Туркменистан';

  @override
  String get permEditPrice => 'Редактирование цены';

  @override
  String get permSellInDebt => 'Продажа в долг';

  @override
  String get permDiscounts => 'Скидки';

  @override
  String get permCashOperations => 'Кассовые операции';

  @override
  String get permSendToOfd => 'Отправка в ОФД';

  @override
  String get permCancelPayment => 'Отмена платежа';

  @override
  String get permDeferSale => 'Отложенная продажа';

  @override
  String get permShowHistory => 'Показать историю';

  @override
  String get printerSettingsSaved => 'Настройки сохранены';

  @override
  String printerSettingsSaveError(String error) {
    return 'Ошибка сохранения: $error';
  }

  @override
  String get printerSettingsPrinting => 'Печать...';

  @override
  String get printerSettingsTestReceipt => 'ТЕСТОВЫЙ ЧЕК';

  @override
  String get printerSettingsWidth => 'Ширина:';

  @override
  String printerSettingsWidthValue(int width) {
    return '$width символов';
  }

  @override
  String get printerSettingsType => 'Тип:';

  @override
  String get printerSettingsAddress => 'Адрес:';

  @override
  String get printerSettingsNotSpecifiedAddr => 'Не указан';

  @override
  String get printerSettingsPrinterWorks => 'Принтер работает!';

  @override
  String get printerSettingsPrintSuccess => 'Печать успешна';

  @override
  String get printerSettingsPrintError => 'Ошибка печати';

  @override
  String get printerSettingsNotConnected => 'Не подключен';

  @override
  String get printerSettingsChecking => 'Проверка...';

  @override
  String get printerSettingsReady => 'Готов';

  @override
  String get printerSettingsNoPaper => 'Нет бумаги';

  @override
  String get printerSettingsCoverOpen => 'Открыта крышка';

  @override
  String get printerSettingsSave => 'Сохранить';

  @override
  String get printerSettingsConnectionType => 'Тип подключения';

  @override
  String get printerSettingsPrinterAddress => 'Адрес принтера';

  @override
  String get printerSettingsPaperWidth => 'Ширина бумаги';

  @override
  String get printerSettingsTesting => 'Тестирование';

  @override
  String printerSettingsStatus(String status) {
    return 'Статус: $status';
  }

  @override
  String get printerSettingsCheck => 'Проверить';

  @override
  String get printerSettingsTestCheck => 'Тестовый чек';

  @override
  String get printerSettingsPort => 'Порт';

  @override
  String get printerSettingsIpAddress => 'IP адрес принтера';

  @override
  String get printerSettingsMacAddress => 'MAC адрес или имя';

  @override
  String get printerSettingsPrinterName => 'Имя принтера';

  @override
  String get printerSettingsComPort => 'COM порт';

  @override
  String get printerSettingsSerialCom => 'Serial (COM)';

  @override
  String get printerSettingsPaperWidth58 => '58mm (32 символа)';

  @override
  String get printerSettingsPaperWidth80_42 => '80mm (42 символа)';

  @override
  String get printerSettingsPaperWidth80_48 => '80mm (48 символов)';

  @override
  String get fiscalSettingsTitle => 'Фискализация';

  @override
  String get fiscalSettingsSaved => 'Настройки сохранены';

  @override
  String fiscalSettingsSaveError(String error) {
    return 'Ошибка сохранения: $error';
  }

  @override
  String get fiscalSettingsSave => 'Сохранить';

  @override
  String get fiscalSettingsOperator => 'Фискальный оператор';

  @override
  String get fiscalSettingsWebkassaSettings => 'Настройки WebKassa';

  @override
  String get fiscalSettingsTaxpayerInfo => 'Данные налогоплательщика';

  @override
  String get fiscalSettingsVatSettings => 'Настройки НДС';

  @override
  String get fiscalSettingsWebkassaLabel => 'WebKassa';

  @override
  String get fiscalSettingsWebkassaDesc => 'Облачный фискальный сервис';

  @override
  String get fiscalSettingsOfdLabel => 'OFD';

  @override
  String get fiscalSettingsOfdDesc => 'Оператор фискальных данных';

  @override
  String get fiscalSettingsNoneLabel => 'Без фискализации';

  @override
  String get fiscalSettingsNoneDesc => 'Чеки не отправляются в ОФД';

  @override
  String get fiscalSettingsOfdId => 'ID ОФД';

  @override
  String get fiscalSettingsOfdIdHint => 'Идентификатор ОФД';

  @override
  String get fiscalSettingsOfdName => 'Название ОФД';

  @override
  String get fiscalSettingsOfdNameHint => 'WebKassa / ОФД.kz';

  @override
  String get fiscalSettingsOfdHost => 'Адрес сервера ОФД';

  @override
  String get fiscalSettingsOfdHostHint => 'https://api.webkassa.kz';

  @override
  String get fiscalSettingsWebkassaActive => 'WebKassa активирована';

  @override
  String get fiscalSettingsWebkassaInactive => 'WebKassa не активирована';

  @override
  String get fiscalSettingsCompanyName => 'Наименование';

  @override
  String get fiscalSettingsCashBox => 'Касса';

  @override
  String get fiscalSettingsVatPayer => 'Плательщик НДС';

  @override
  String get fiscalSettingsVatPayerSubtitle =>
      'Организация является плательщиком НДС (12%)';

  @override
  String get fiscalSettingsPrintVat => 'Печатать НДС на чеке';

  @override
  String get fiscalSettingsPrintVatSubtitle => 'Отображать сумму НДС в чеке';

  @override
  String get fiscalOffsetSection => 'Сертификаты и аванс';

  @override
  String get fiscalOffsetCertificateSale => 'Чек при продаже сертификата';

  @override
  String get fiscalOffsetCertificateSaleSubtitle =>
      'Выбивать фискальный чек, когда покупают подарочный сертификат';

  @override
  String get fiscalOffsetLayout => 'Оплата сертификатом или авансом';

  @override
  String get fiscalOffsetLayoutSubtitle =>
      'Как сумма зачёта попадает в чек оператора ОФД';

  @override
  String get fiscalOffsetLayoutDiscount => 'Скидкой на товары';

  @override
  String get fiscalOffsetLayoutSurchargeOnly => 'Чек только на доплату';

  @override
  String get fiscalOffsetPrepaymentReceipt => 'Чек при приёме аванса';

  @override
  String get fiscalOffsetPrepaymentReceiptSubtitle =>
      'Выбивать фискальный чек, когда покупатель вносит аванс';

  @override
  String get fiscalOffsetSaveError => 'Не удалось сохранить настройку';

  @override
  String get customerPaymentTender => 'Чем принято';

  @override
  String get fiscalSettingsVatRate =>
      'Ставка НДС: 12% (расчёт по формуле 3/28)';

  @override
  String historyProductUcode(String ucode) {
    return 'Товар #$ucode';
  }

  @override
  String historyRefundProductId(String id) {
    return 'Товар возврата #$id';
  }

  @override
  String historyAccountId(String id) {
    return 'Счёт #$id';
  }

  @override
  String historyLoadError(String error) {
    return 'Ошибка загрузки: $error';
  }

  @override
  String historyReceiptNo(String number) {
    return 'Чек $number';
  }

  @override
  String get historySyncSynced => 'Синхр.';

  @override
  String get historySyncPending => 'Ожид.';

  @override
  String get historySyncSending => 'Отпр.';

  @override
  String get historySyncDeferred => 'Отлож.';

  @override
  String get historySyncInProgress => 'В работе';

  @override
  String get historyClient => 'Клиент';

  @override
  String get historyFiscalization => 'Фискализация';

  @override
  String get historyProducts => 'Товары';

  @override
  String get historyPayment => 'Оплата';

  @override
  String get historyNoProducts => 'Нет товаров';

  @override
  String get historyNoPayments => 'Нет платежей';

  @override
  String historyPrintingReceipt(String number) {
    return 'Печать чека $number...';
  }

  @override
  String get historyReceiptPrinted => 'Чек напечатан';

  @override
  String get historyPrintError => 'Ошибка печати';

  @override
  String get historyOperationType => 'Тип операции';

  @override
  String get historyFilterSales => 'Продажи';

  @override
  String get historyFilterRefunds => 'Возвраты';

  @override
  String get historySearchShort => 'Поиск...';

  @override
  String get historyFilters => 'Фильтры';

  @override
  String get historyDateFrom => 'С';

  @override
  String get historyDateTo => 'По';

  @override
  String get historyReset => 'Сбросить';

  @override
  String get historyApply => 'Применить';

  @override
  String get historySearchFull => 'Поиск по номеру чека, сумме...';

  @override
  String get historySyncStatus => 'Статус синхронизации';

  @override
  String get historyReceiptColumn => 'Чек';

  @override
  String get historySyncSyncedFull => 'Синхронизировано';

  @override
  String get historySyncPendingFull => 'Ожидает синхронизации';

  @override
  String get historySyncSendingFull => 'Отправляется';

  @override
  String get historySyncDeferredFull => 'Отложено';

  @override
  String get historySyncInProgressFull => 'В процессе';

  @override
  String get historyPaymentCash => 'Наличные';

  @override
  String get historyPaymentCard => 'Карта';

  @override
  String get historyPaymentMixed => 'Смешанная';

  @override
  String get historyPaymentBonus => 'Бонусы';

  @override
  String get historyPaymentDebt => 'В долг';

  @override
  String get historyPaymentDiscount => 'Скидка';

  @override
  String get historyPaymentWithDiscount => 'Со скидкой';

  @override
  String get historyOfdFiscalized => 'Фискализирован';

  @override
  String get historyOfdError => 'Ошибка фискализации';

  @override
  String get historyOfdNotFiscalized => 'Не фискализирован';

  @override
  String get historyClearFilters => 'Сбросить фильтры';

  @override
  String historyRecordsRange(String start, String end, String total) {
    return 'Записи $start–$end из $total';
  }

  @override
  String get historyFirstPage => 'Первая страница';

  @override
  String get historyPrevious => 'Предыдущая';

  @override
  String get historyNextPage => 'Следующая';

  @override
  String get historyLastPage => 'Последняя страница';

  @override
  String historyAmount(String amount) {
    return 'Сумма: $amount';
  }

  @override
  String historyDate(String date) {
    return 'Дата: $date';
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
  String get historyFiscalYes => 'Да';

  @override
  String get historyFiscalNo => 'Нет';

  @override
  String get historyFiscalError => 'Ошибка';

  @override
  String get shiftPrintZReport => 'Печать Z-отчёта';

  @override
  String get shiftZReportQueued =>
      'Z-отчёт принят в очередь печати. Бумаги пока нет: она выйдет, когда принтер сможет. Задание ждёт 30 минут — посмотреть его можно в Настройках → Принтер';

  @override
  String get shiftZReportAlreadyQueued =>
      'Z-отчёт уже сдан в печать — второй раз он не печатается';

  @override
  String get shiftZReportPrintFailed => 'Не удалось сдать Z-отчёт в печать';

  @override
  String get shiftFinishAllSales => 'Завершите все продажи';

  @override
  String get shiftCannotClose => 'Невозможно закрыть смену';

  @override
  String get shiftOpeningShift => 'Открытие смены';

  @override
  String get shiftClosingShift => 'Закрытие смены';

  @override
  String get shiftEnterInitialAmount => 'Введите начальную сумму в кассе:';

  @override
  String get shiftDiscrepancyFound => 'Обнаружено расхождение';

  @override
  String shiftDifferenceAmount(String amount) {
    return 'Разница: $amount';
  }

  @override
  String get shiftConfirmCloseQuestion =>
      'Вы уверены, что хотите закрыть смену?';

  @override
  String shiftFixedAmount(String amount) {
    return 'Будет зафиксирована сумма: $amount KZT';
  }

  @override
  String get shiftCloseWithDiscrepancy => 'Закрыть с расхождением';

  @override
  String get shiftCashierLabel => 'Кассир';

  @override
  String get shiftUnknown => 'Неизвестно';

  @override
  String get shiftSystemTotal => 'Ожидается в кассе';

  @override
  String get shiftEnteredTotal => 'Пересчитано';

  @override
  String get shiftCashOperations => 'Кассовые операции';

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
  String get shiftShortage => 'Недостача';

  @override
  String get shiftSurplus => 'Излишек';

  @override
  String get shiftBalances => 'Сходится';

  @override
  String get shiftCloseBlocked => 'Закрытие заблокировано';

  @override
  String shiftActiveSalesCount(int count) {
    return 'Активные продажи: $count';
  }

  @override
  String shiftPendingSalesCount(int count) {
    return 'Отложенные продажи: $count';
  }

  @override
  String get shiftFinishSalesBeforeClose =>
      'Завершите или отмените продажи перед закрытием смены';

  @override
  String get shiftBillsTab => 'Купюры';

  @override
  String get shiftTotalTab => 'Общая сумма';

  @override
  String get shiftOperationsTab => 'Операции';

  @override
  String get shiftAmountTab => 'Сумма';

  @override
  String get shiftBillCount => 'Пересчёт по купюрам';

  @override
  String get shiftDifferenceLabel => 'Разница: ';

  @override
  String get supplySupplierRequired => 'Поставщик *';

  @override
  String get supplyPaymentType => 'Тип оплаты';

  @override
  String get supplyFullPayment => 'Полная оплата';

  @override
  String get supplyAccountDebit => 'Списание со счёта';

  @override
  String get supplyConsignment => 'Консигнация';

  @override
  String get supplyDeferredPayment => 'Отсрочка платежа';

  @override
  String get supplyPaymentAccountRequired => 'Счёт оплаты *';

  @override
  String get supplyAddProduct => 'Добавить товар';

  @override
  String get supplyBarcodeOrSku => 'Штрихкод или артикул';

  @override
  String supplyProductsCount(int count) {
    return 'Товары ($count)';
  }

  @override
  String supplyAmountValue(String amount) {
    return 'Сумма: $amount';
  }

  @override
  String get supplyProductNotFound => 'Товар не найден';

  @override
  String get supplyInvalidQuantity => 'Введите корректное количество';

  @override
  String get supplySelectSupplierTitle => 'Выберите поставщика';

  @override
  String get supplySuppliersNotFound => 'Поставщики не найдены';

  @override
  String get supplySelectAccountTitle => 'Выберите счёт';

  @override
  String get supplyAccountsNotFound => 'Счета не найдены';

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
    return 'Товаров: $count';
  }

  @override
  String supplyTotalLabel(String amount) {
    return 'Итого: $amount';
  }

  @override
  String supplySavedSuccess(int count, String amount) {
    return 'Приёмка сохранена. Товаров: $count, сумма: $amount';
  }

  @override
  String get supplyCancelConfirm => 'Отменить приёмку?';

  @override
  String get supplyCancelMessage => 'Все введённые данные будут потеряны.';

  @override
  String get supplyYesCancel => 'Да, отменить';

  @override
  String get supplySearchProduct => 'Поиск товара...';

  @override
  String get supplyAddProductsHint => 'Добавьте товары в приёмку';

  @override
  String get supplyScanOrSearch => 'Отсканируйте штрихкод или найдите товар';

  @override
  String get refundTotalAmount => 'Сумма возврата';

  @override
  String get refundPosLabel => 'Касса';

  @override
  String refundSelectedOfTotal(String selected, String total) {
    return '$selected из $total';
  }

  @override
  String get refundTotalProducts => 'Всего товаров';

  @override
  String get refundToReturn => 'К ВОЗВРАТУ';

  @override
  String get refundToReturnLabel => 'К возврату:';

  @override
  String get refundAction => 'ВОЗВРАТ';

  @override
  String refundSelectedItemsShort(String selected, String total) {
    return '$selected из $total поз.';
  }

  @override
  String get refundColumnName => 'Название';

  @override
  String get refundColumnQty => 'Кол-во';

  @override
  String get refundEmptyHint => 'Загрузите чек или добавьте товары вручную';

  @override
  String get refundNoItemsShort => 'Нет товаров';

  @override
  String get refundEmptyHintShort => 'Загрузите чек или\nдобавьте товары';

  @override
  String refundSelectedCount(String count) {
    return 'Выбрано позиций: $count';
  }

  @override
  String refundAmountValue(String amount) {
    return 'Сумма возврата: $amount';
  }

  @override
  String get refundSuccess => 'Возврат успешно проведён';

  @override
  String get paymentAmountDue => 'К оплате';

  @override
  String get paymentTotalDue => 'Итого к оплате';

  @override
  String get paymentCashLabel => 'Наличными';

  @override
  String get paymentReceived => 'Получено';

  @override
  String get paymentRemainingLabel => 'Осталось';

  @override
  String paymentCardAmount(String amount) {
    return 'Оплата картой на сумму $amount';
  }

  @override
  String get paymentLoyaltyProgram => 'Программа лояльности';

  @override
  String get paymentPhoneNumber => 'Номер телефона';

  @override
  String get paymentAvailableBonus => 'Доступно бонусов:';

  @override
  String get paymentUseBonuses => 'Использовать бонусы';

  @override
  String paymentBonusToDeduct(String amount) {
    return 'К списанию: $amount бонусов';
  }

  @override
  String get paymentSuccessMessage => 'Оплата успешна';

  @override
  String get paymentRefundButton => 'ВЕРНУТЬ';

  @override
  String get paymentPayButton => 'ОПЛАТИТЬ';

  @override
  String get syncWidgetRetry => 'Повторить';

  @override
  String syncWidgetLastSync(String time) {
    return 'Последняя синхронизация: $time';
  }

  @override
  String syncWidgetRecordsCount(int count) {
    return '$count записей';
  }

  @override
  String get syncWidgetWaiting => 'Ожидает';

  @override
  String get syncWidgetSynced => 'Синхронизировано';

  @override
  String get syncWidgetJustNow => 'только что';

  @override
  String syncWidgetMinutesAgo(int minutes) {
    return '$minutes мин. назад';
  }

  @override
  String syncWidgetHoursAgo(int hours) {
    return '$hours ч. назад';
  }

  @override
  String syncWidgetDaysAgo(int days) {
    return '$days дн. назад';
  }

  @override
  String get syncWidgetConnecting => 'Подключение к серверу...';

  @override
  String get syncWidgetSyncingProducts => 'Синхронизация товаров...';

  @override
  String get syncWidgetSyncingSales => 'Синхронизация продаж...';

  @override
  String get syncWidgetSyncingAgents => 'Синхронизация контрагентов...';

  @override
  String get syncWidgetSyncingPrices => 'Синхронизация цен...';

  @override
  String get syncWidgetFinishing => 'Завершение...';

  @override
  String get updateDialogUpdating => 'Обновление...';

  @override
  String get updateDialogAvailable => 'Доступно обновление';

  @override
  String updateDialogAutoUpdate(int seconds) {
    return 'Автоматическое обновление через $seconds сек';
  }

  @override
  String get updateDialogUpdateNow => 'Обновить сейчас';

  @override
  String get updateDialogLater => 'Позже';

  @override
  String get updateDialogSkip => 'Пропустить';

  @override
  String get updateDialogUpdate => 'Обновить';

  @override
  String storeUpdateVersion(String version) {
    return 'Версия $version';
  }

  @override
  String storeUpdateNewVersionAvailable(String storeName) {
    return 'Новая версия приложения доступна в $storeName.';
  }

  @override
  String get storeUpdateWhatsNew => 'Что нового:';

  @override
  String get storeUpdateRequired => 'Это обязательное обновление';

  @override
  String storeUpdateGoTo(String storeName) {
    return 'Перейти в $storeName';
  }

  @override
  String get storeUpdateButton => 'ОБНОВИТЬ';

  @override
  String get storeUpdateDownloaded => 'Обновление загружено';

  @override
  String get storeUpdateReadyToInstall =>
      'Обновление загружено и готово к установке.\nУстановить сейчас? Приложение будет перезапущено.';

  @override
  String get storeUpdateInstall => 'УСТАНОВИТЬ';

  @override
  String get storeUpdateDownloading => 'Загрузка обновления...';

  @override
  String get storeUpdateReadyShort => 'Обновление готово к установке';

  @override
  String get versionConflictTitle => 'Конфликт версий';

  @override
  String get versionConflictDescription =>
      'Обнаружен конфликт версий приложения.';

  @override
  String get versionConflictCurrent => 'Текущая версия';

  @override
  String get versionConflictFound => 'Найденная версия';

  @override
  String get versionConflictChooseAction => 'Выберите действие:';

  @override
  String get versionConflictOpenFolder => 'Открыть в папке';

  @override
  String get versionConflictPreviousVersion => 'Прежняя версия';

  @override
  String get versionConflictContinue => 'Продолжить';

  @override
  String get restoreLoadingBackups => 'Загрузка бэкапов...';

  @override
  String get restoreSearchingBackups => 'Поиск бэкапов...';

  @override
  String restoreLoadError(String error) {
    return 'Ошибка загрузки: $error';
  }

  @override
  String get restoreRestoring => 'Восстановление...';

  @override
  String get restoreRestoreError => 'Ошибка восстановления';

  @override
  String get restoreRestoreFailed => 'Не удалось восстановить из бэкапа';

  @override
  String get restoreTitle => 'Восстановление';

  @override
  String get restoreChooseMethod => 'Выберите способ настройки';

  @override
  String get restoreSetupNewPos => 'Настроить новую кассу';

  @override
  String get restoreNoBackups => 'Бэкапы не найдены';

  @override
  String get restoreSetupAsNew => 'Настройте кассу как новую';

  @override
  String get restoreFoundBackups => 'Найденные бэкапы:';

  @override
  String get agentSearchByNameOrPhone => 'Поиск по имени или телефону...';

  @override
  String get agentOnlyWithDebt => 'Только с долгом';

  @override
  String get agentTypeTooltip => 'Тип';

  @override
  String agentBinLabel(String bin) {
    return 'БИН: $bin';
  }

  @override
  String agentSelectedMessage(String name) {
    return 'Выбран: $name';
  }

  @override
  String agentFoundCount(int count) {
    return 'Найдено: $count';
  }

  @override
  String get agentEnterNameOrPhoneToSearch =>
      'Введите имя или телефон для поиска';

  @override
  String get agentNotFound => 'Клиенты не найдены';

  @override
  String get agentSearchClients => 'Поиск клиентов';

  @override
  String get agentNotFoundShort => 'Не найдено';

  @override
  String get agentEnterNameOrPhone => 'Введите имя или телефон';

  @override
  String get agentEnterCustomerName => 'Введите имя клиента';

  @override
  String get agentDeletedCustomerPhone => 'Клиент с таким телефоном был удалён';

  @override
  String get agentWantRestore => 'Хотите восстановить?';

  @override
  String get agentDeleteCustomerTitle => 'Удалить клиента?';

  @override
  String agentDeleteConfirmMessage(String name) {
    return 'Вы уверены, что хотите удалить \"$name\"?';
  }

  @override
  String agentCustomerDeleted(String name) {
    return 'Клиент \"$name\" удалён';
  }

  @override
  String get cashOpTitle => 'Кассовая операция';

  @override
  String get cashOpComment => 'Комментарий';

  @override
  String get cashOpCommentRequired => 'Комментарий *';

  @override
  String get cashOpCommentHint => 'Введите комментарий...';

  @override
  String cashOpError(String error) {
    return 'Ошибка: $error';
  }

  @override
  String get cashOpOperationType => 'Тип операции';

  @override
  String get cashOpExpense => 'Расход';

  @override
  String get cashOpDividend => 'Изъятие';

  @override
  String get saleReceiptTotal => 'Итого по чеку';

  @override
  String get salePay => 'ОПЛАТИТЬ';

  @override
  String get saleTotalColon => 'Итого:';

  @override
  String salePositionsAndQuantity(int count, String qty) {
    return '$count поз. / $qty шт.';
  }

  @override
  String get saleWholesale => 'ОПТ';

  @override
  String get saleRetail => 'Розница';

  @override
  String get syncPreparing => 'Подготовка...';

  @override
  String refundRefused(String reason) {
    return 'Возврат не выполнен: $reason';
  }

  @override
  String errorSaveFailed(String details) {
    return 'Ошибка сохранения: $details';
  }

  @override
  String get errorSaveFailedGeneric => 'Ошибка сохранения';

  @override
  String errorLoadFailed(String details) {
    return 'Ошибка загрузки данных: $details';
  }

  @override
  String get errorLoadFailedGeneric => 'Ошибка загрузки данных';

  @override
  String errorSearchFailed(String details) {
    return 'Ошибка поиска: $details';
  }

  @override
  String get errorSearchFailedGeneric => 'Ошибка поиска';

  @override
  String get errorUnknownGeneric => 'Неизвестная ошибка';

  @override
  String errorRefusalUnknownCode(String code) {
    return 'неизвестная причина (код $code)';
  }

  @override
  String get errorReasonUnknown => 'неизвестная причина';

  @override
  String get errorFillRequired => 'Заполните все обязательные поля';

  @override
  String get errorNoUsers => 'Нет зарегистрированных пользователей';

  @override
  String get errorSelectUser => 'Выберите пользователя';

  @override
  String get errorPinTooShort => 'Введите PIN-код (минимум 4 цифры)';

  @override
  String get errorRsaNotConfigured =>
      'Ошибка: RSA ключ не настроен. Обратитесь к администратору.';

  @override
  String get errorWrongPin => 'Неверный PIN-код';

  @override
  String get errorAmbiguousPin =>
      'Этот PIN-код совпадает у нескольких кассиров. Выберите своё имя и войдите по нему.';

  @override
  String get errorNoPinSet =>
      'У этого кассира не задан PIN-код. Обратитесь к администратору, чтобы его установить.';

  @override
  String get errorWalkUpDisabled =>
      'Вход без выбора имени отключён на этой точке. Выберите своё имя из списка.';

  @override
  String get errorCredentialUnreadable =>
      'Запись PIN-кода повреждена. Обратитесь к администратору — набрать код заново не поможет.';

  @override
  String get errorAuthUnknown =>
      'Касса не смогла ответить на попытку входа. Попробуйте ещё раз.';

  @override
  String get errorTillNotConfigured =>
      'Касса ещё не настроена — вход невозможен, пока не пройден мастер настройки.';

  @override
  String get errorTillNotConfiguredSale =>
      'Касса не настроена — чек начать нельзя. Обратитесь к администратору: нужно пройти мастер настройки.';

  @override
  String get errorNotAllowed =>
      'Недостаточно прав для этого действия. Обратитесь к администратору.';

  @override
  String get errorNoSaleModule =>
      'Эта касса не умеет вести чек: модуль продажи не собран. Обратитесь к администратору.';

  @override
  String get errorTerminalInBody =>
      'Терминал обратился к кассе неверно. Обновите приложение на рабочем месте.';

  @override
  String get errorWholesaleInStart =>
      'Оптовый чек так не начинается. Начните обычный чек и включите опт отдельной кнопкой.';

  @override
  String get errorTerminalLimitReached =>
      'На этой кассе уже заведено максимум терминалов. Обратитесь к администратору, чтобы освободить место.';

  @override
  String get errorPairingCodeInvalid =>
      'Код привязки не подошёл — просрочен, уже использован или введён неверно. Получите новый код у оператора кассы.';

  @override
  String get errorTerminalSecretInvalid =>
      'Привязка этого устройства больше не действует — возможно, терминал удалили на кассе. Введите новый код привязки.';

  @override
  String get errorSessionExpired => 'Сеанс истёк — войдите снова.';

  @override
  String get errorSessionEnded => 'Сеанс завершён на кассе — войдите снова.';

  @override
  String get errorSaleNotInitialized => 'Продажа не инициализирована';

  @override
  String get errorReceiptEmpty => 'Чек пуст';

  @override
  String get errorDeferredNotFound => 'Отложенный чек не найден';

  @override
  String get errorCartStale =>
      'Чек изменился, пока вы набирали. Экран обновлён — повторите последнее действие.';

  @override
  String get errorCartWrongReceipt =>
      'Этот чек больше не в работе. Начните новый чек или поднимите отложенный.';

  @override
  String get errorCartNotStarted =>
      'Чек ещё не начат. Начните новый чек или поднимите отложенный.';

  @override
  String get errorLineNotFound =>
      'Этой строки в чеке больше нет. Обновите чек и повторите.';

  @override
  String get errorInvalidAmount =>
      'Недопустимое значение. Сумма не может быть отрицательной, а скидка — больше 100%.';

  @override
  String get errorDeferredTaken =>
      'Этот отложенный чек уже поднят на другом рабочем месте.';

  @override
  String get errorCartNotEmpty =>
      'Сначала завершите или отложите текущий чек — поднять отложенный поверх него нельзя.';

  @override
  String get errorSaleNotStarted =>
      'Касса не смогла начать чек и не назвала причину. Попробуйте ещё раз.';

  @override
  String get errorShiftNotOpen => 'Смена не открыта. Откройте смену на кассе.';

  @override
  String get errorCardTerminalMisconfigured =>
      'Платёжный терминал этого рабочего места настроен неверно. Проверьте привязку в настройках оборудования.';

  @override
  String errorReceiptNotFound(String receiptNo) {
    return 'Чек #$receiptNo не найден';
  }

  @override
  String get errorReceiptNotFoundGeneric => 'Чек не найден';

  @override
  String get errorNotAuthorized => 'Пользователь не авторизован';

  @override
  String get errorSupplierNotFound => 'Поставщик не найден';

  @override
  String get errorAccountNotFound => 'Счёт не найден';

  @override
  String errorProductNotFound(String details) {
    return 'Товар не найден: $details';
  }

  @override
  String get errorProductNotFoundGeneric => 'Товар не найден';

  @override
  String get errorNameRequired => 'Имя обязательно';

  @override
  String get errorNameTooShort => 'Минимум 2 символа';

  @override
  String get errorPhoneInvalid => 'Неверный формат телефона';

  @override
  String get errorBinInvalid => 'БИН/ИИН должен содержать 12 цифр';

  @override
  String get errorPhoneExists => 'Клиент с таким телефоном уже существует';

  @override
  String errorShiftOpenFailed(String details) {
    return 'Ошибка открытия смены: $details';
  }

  @override
  String get errorShiftOpenFailedGeneric => 'Ошибка открытия смены';

  @override
  String errorShiftCloseFailed(String details) {
    return 'Ошибка закрытия смены: $details';
  }

  @override
  String get errorShiftCloseFailedGeneric => 'Ошибка закрытия смены';

  @override
  String errorShiftLoadFailed(String details) {
    return 'Ошибка загрузки данных смены: $details';
  }

  @override
  String get errorShiftLoadFailedGeneric => 'Ошибка загрузки данных смены';

  @override
  String get errorPaymentConfig =>
      'Не удалось сформировать платёж. Проверьте настройки счетов.';

  @override
  String get errorSaleSaveFailed => 'Ошибка сохранения продажи';

  @override
  String get errorInventoryCannotComplete => 'Невозможно завершить';

  @override
  String get errorNoProducts => 'Нет товаров для списания';

  @override
  String get errorSelectCountry => 'Выберите страну';

  @override
  String get errorEnterOrgName => 'Введите название организации';

  @override
  String errorEnterTaxId(String label) {
    return 'Введите $label';
  }

  @override
  String get errorEnterTaxIdGeneric => 'Введите налоговый номер';

  @override
  String errorTaxIdLength(String info) {
    return '$info';
  }

  @override
  String get errorTaxIdLengthGeneric => 'Неверная длина налогового номера';

  @override
  String get errorEnterPosName => 'Введите название кассы';

  @override
  String get errorFillWebkassa => 'Заполните все поля WebKassa';

  @override
  String get errorFillOfd => 'Заполните все поля ОФД';

  @override
  String get errorEnterKaspiIp => 'Введите IP-адрес терминала Kaspi';

  @override
  String get errorEnterAdminName => 'Введите имя администратора';

  @override
  String get errorAdminPinShort =>
      'PIN администратора должен содержать минимум 4 цифры';

  @override
  String get errorSellerPinShort =>
      'PIN продавца должен содержать минимум 4 цифры';

  @override
  String errorCheckFailed(String details) {
    return 'Ошибка проверки: $details';
  }

  @override
  String get errorCheckFailedGeneric => 'Ошибка проверки';

  @override
  String get errorTelegramNotInitialized =>
      'TelegramInitializer не инициализирован';

  @override
  String get errorTelegramAuthNotInitialized =>
      'TelegramAuthService не инициализирован';

  @override
  String errorPhoneSendFailed(String details) {
    return 'Ошибка отправки номера: $details';
  }

  @override
  String get errorPhoneSendFailedGeneric => 'Ошибка отправки номера';

  @override
  String errorQrAuthFailed(String details) {
    return 'Ошибка QR авторизации: $details';
  }

  @override
  String get errorQrAuthFailedGeneric => 'Ошибка QR авторизации';

  @override
  String errorWrongCode(String details) {
    return 'Неверный код: $details';
  }

  @override
  String get errorWrongCodeGeneric => 'Неверный код';

  @override
  String errorWrongPassword(String details) {
    return 'Неверный пароль: $details';
  }

  @override
  String get errorWrongPasswordGeneric => 'Неверный пароль';

  @override
  String errorRegistrationFailed(String details) {
    return 'Ошибка регистрации: $details';
  }

  @override
  String get errorRegistrationFailedGeneric => 'Ошибка регистрации';

  @override
  String errorChannelSearchFailed(String details) {
    return 'Ошибка поиска каналов: $details';
  }

  @override
  String get errorChannelSearchFailedGeneric => 'Ошибка поиска каналов';

  @override
  String errorChannelConnectFailed(String details) {
    return 'Ошибка подключения к каналам: $details';
  }

  @override
  String get errorChannelConnectFailedGeneric => 'Ошибка подключения к каналам';

  @override
  String errorChannelCreateFailed(String details) {
    return 'Ошибка создания каналов: $details';
  }

  @override
  String get errorChannelCreateFailedGeneric => 'Ошибка создания каналов';

  @override
  String get errorFillClientData => 'Заполните данные клиента';

  @override
  String get shiftCashInvestments => 'Внесения';

  @override
  String get shiftCashExpenses => 'Расходы';

  @override
  String get shiftCashDividends => 'Изъятия';

  @override
  String get shiftNoCashOps => 'Нет кассовых операций';

  @override
  String get shiftNoCashOpsDescription =>
      'Внесения, расходы и изъятия\nбудут отображаться здесь';

  @override
  String shiftMoreItems(int count) {
    return '+$count ещё';
  }

  @override
  String get shiftEqualsSystem => '= Система';

  @override
  String get shiftBillsTotal => 'Итого по купюрам:';

  @override
  String get receiptInputTitle => 'Поиск чека';

  @override
  String get receiptInputNumber => 'Номер чека';

  @override
  String get receiptInputNumberHint => 'Например: 12345';

  @override
  String get receiptInputPos => 'Касса';

  @override
  String get receiptInputInvalid => 'Введите корректный номер чека';

  @override
  String get receiptInputFind => 'Найти';

  @override
  String get paymentDenominations => 'Номиналы';

  @override
  String get paymentExactAmount => 'Без сдачи';

  @override
  String get paymentNumpad => 'Клавиатура';

  @override
  String get paymentIinLabel => 'ИИН/БИН (необязательно)';

  @override
  String get paymentIinInvalid => 'Некорректный ИИН/БИН';

  @override
  String get paymentIinHint =>
      'ИИН — для физических лиц, БИН — для юридических';

  @override
  String get paymentIinShort => 'ИИН/БИН';

  @override
  String get paymentTypeCash => 'Наличная';

  @override
  String get paymentTypeCard => 'Безналичная';

  @override
  String get paymentTypeMixed => 'Смешанная';

  @override
  String get paymentAccount => 'Счёт';

  @override
  String get authNoUsers => 'Нет зарегистрированных пользователей';

  @override
  String get authNoPin => 'Без PIN';

  @override
  String get authSelectUser => 'Выберите пользователя';

  @override
  String get authNoUsersShort => 'Нет пользователей';

  @override
  String get authEnterPin => 'Введите PIN-код';

  @override
  String updateVersion(String version) {
    return 'Версия $version';
  }

  @override
  String get updateWhatsNew => 'Что нового';

  @override
  String get updateFixedIssues => 'Исправлено';

  @override
  String get updateSize => 'Размер';

  @override
  String get updateDate => 'Дата';

  @override
  String get updateMandatory => 'Это обязательное обновление';

  @override
  String updateLaterCountdown(int countdown) {
    return 'Позже ($countdown)';
  }

  @override
  String get updateDownloading => 'Загрузка обновления';

  @override
  String get updateDownloadingFile => 'Загрузка файла обновления...';

  @override
  String get updatePosNow => 'ОБНОВИТЬ КАССУ';

  @override
  String get serviceAddNote => 'Добавить отметку';

  @override
  String get serviceClientLookup => 'Поиск клиента';

  @override
  String serviceOrderDetail(int orderId) {
    return 'Детали заказ-наряда #$orderId';
  }

  @override
  String get paymentDefaultLabel => 'По умолчанию';

  @override
  String get currencySymbol => '₸';

  @override
  String get serviceIntakeTitle => 'Приём заказа';

  @override
  String get serviceIntakeClient => 'Клиент';

  @override
  String get serviceIntakeDevice => 'Устройство / Предмет';

  @override
  String get serviceIntakeServices => 'Услуги';

  @override
  String get serviceIntakeDelivery => 'Доставка';

  @override
  String get serviceIntakePickup => 'Забрать у клиента';

  @override
  String get serviceIntakeSave => 'Сохранить';

  @override
  String get serviceIntakeCancel => 'Отмена';

  @override
  String get serviceQueueTitle => 'Заказ-наряды';

  @override
  String get serviceQueueEmpty => 'Нет заказ-нарядов';

  @override
  String get serviceQueueSearch => 'Поиск по номеру, клиенту, устройству';

  @override
  String get serviceDetailTitle => 'Детали заказа';

  @override
  String get serviceDetailInfo => 'Информация';

  @override
  String get serviceDetailTimeline => 'Работы';

  @override
  String get serviceDetailCost => 'Стоимость';

  @override
  String get serviceDetailActions => 'Действия';

  @override
  String get serviceStatusIntake => 'Приём';

  @override
  String get serviceStatusInProgress => 'В работе';

  @override
  String get serviceStatusCompleted => 'Готов';

  @override
  String get serviceStatusClosed => 'Закрыт';

  @override
  String get serviceStatusCancelled => 'Отменён';

  @override
  String get serviceMarkDiagnostic => 'Диагностика';

  @override
  String get serviceMarkReplacement => 'Замена детали';

  @override
  String get serviceMarkRepair => 'Ремонт';

  @override
  String get serviceMarkTesting => 'Тестирование';

  @override
  String get serviceMarkOther => 'Прочее';

  @override
  String get serviceAddMark => 'Добавить работу';

  @override
  String get serviceDeleteMark => 'Удалить отметку';

  @override
  String get serviceMarkDescription => 'Описание';

  @override
  String get serviceMarkType => 'Тип работы';

  @override
  String get serviceMarkCost => 'Стоимость';

  @override
  String get serviceMarkNote => 'Примечание';

  @override
  String get serviceCatalogTitle => 'Каталог услуг';

  @override
  String get serviceCatalogAdd => 'Добавить услугу';

  @override
  String get serviceCatalogDuration => 'мин';

  @override
  String get serviceCatalogWarranty => 'Гарантия (дней)';

  @override
  String get serviceCatalogRequiresDevice => 'Требуется устройство';

  @override
  String get serviceClientNew => 'Новый клиент';

  @override
  String get serviceClientPhone => 'Телефон';

  @override
  String get serviceClientName => 'Имя';

  @override
  String get serviceClientAddress => 'Адрес';

  @override
  String get serviceAssignTechnician => 'Назначить мастера';

  @override
  String get serviceReassignTechnician => 'Переназначить мастера';

  @override
  String serviceTechnicianAssigned(String name) {
    return 'Мастер назначен: $name';
  }

  @override
  String get serviceTechnicianSelect => 'Выберите мастера';

  @override
  String get servicePrepayment => 'Предоплата';

  @override
  String get servicePrepaymentAmount => 'Сумма предоплаты';

  @override
  String get serviceEstimatedDate => 'Ожидаемая дата';

  @override
  String get serviceEstimatedAmount => 'Сумма';

  @override
  String get servicePrintLabel => 'QR-этикетка';

  @override
  String get servicePrintReceipt => 'Печать чека';

  @override
  String get serviceProgressConfirm => 'Начать работу';

  @override
  String get serviceCancelConfirm => 'Отменить';

  @override
  String get serviceTotalCost => 'Стоимость работ';

  @override
  String get servicePrepaid => 'Предоплата';

  @override
  String get serviceRemaining => 'К оплате';

  @override
  String get serviceDeliveryAddress => 'Адрес доставки';

  @override
  String get serviceNeedsPickup => 'Забрать у клиента';

  @override
  String get serviceNeedsDelivery => 'Доставить клиенту';

  @override
  String serviceQrFormat(Object id, Object number) {
    return 'TELEPOS:SO:$id:$number';
  }

  @override
  String get serviceOrderCreated => 'Новый заказ';

  @override
  String get serviceOrderUpdated => 'Редактировать';

  @override
  String get serviceNoOrders => 'Нет данных';

  @override
  String get serviceFilterAll => 'Все';

  @override
  String get navCatalog => 'Каталог';

  @override
  String get catalogTitle => 'Каталог товаров';

  @override
  String get catalogSearch => 'Поиск';

  @override
  String get catalogSearchHint => 'Название или штрихкод';

  @override
  String get catalogFilterAll => 'Все';

  @override
  String get catalogFilterProducts => 'Товары';

  @override
  String get catalogFilterWeighted => 'Весовые';

  @override
  String get catalogFilterServices => 'Услуги';

  @override
  String get catalogFilterPackages => 'Упаковки';

  @override
  String get catalogAddProduct => 'Добавить товар';

  @override
  String get catalogEditProduct => 'Редактировать товар';

  @override
  String get catalogDeleteProduct => 'Удалить товар';

  @override
  String get catalogRestoreProduct => 'Восстановить товар';

  @override
  String get catalogProductName => 'Название';

  @override
  String get catalogBarcode => 'Штрихкод';

  @override
  String get catalogType => 'Тип';

  @override
  String get catalogPrice => 'Цена продажи';

  @override
  String get catalogWholesalePrice => 'Оптовая цена';

  @override
  String get catalogCategory => 'Категория';

  @override
  String get catalogMeasure => 'Единица измерения';

  @override
  String get catalogQuantity => 'Остаток';

  @override
  String get catalogQuickProduct => 'Быстрый товар';

  @override
  String get catalogAddToQuick => 'Добавить в быстрые';

  @override
  String get catalogRemoveFromQuick => 'Убрать из быстрых';

  @override
  String get catalogNoProducts => 'Нет товаров';

  @override
  String get catalogDeleted => 'Удалён';

  @override
  String catalogConfirmDelete(String name) {
    return 'Удалить товар \"$name\"?';
  }

  @override
  String get catalogProductCreated => 'Товар создан';

  @override
  String get catalogProductUpdated => 'Товар обновлён';

  @override
  String get catalogProductDeleted => 'Товар удалён';

  @override
  String get catalogProductRestored => 'Товар восстановлен';

  @override
  String get catalogShowDeleted => 'Показать удалённые';

  @override
  String get catalogTypeNormal => 'Обычный';

  @override
  String get catalogTypeWeight => 'Весовой';

  @override
  String get catalogTypeInner => 'Внутренний';

  @override
  String get catalogTypePackage => 'Упаковка';

  @override
  String get catalogTypeService => 'Услуга';

  @override
  String get catalogMeasurePiece => 'Штука';

  @override
  String get catalogMeasureKg => 'Килограмм';

  @override
  String get catalogMeasureLiter => 'Литр';

  @override
  String get catalogMeasureMeter => 'Метр';

  @override
  String get catalogNameRequired => 'Введите название';

  @override
  String get catalogPriceRequired => 'Введите цену';

  @override
  String get catalogPriceInvalid => 'Цена должна быть больше 0';

  @override
  String get catalogBarcodeExists => 'Товар с таким штрихкодом уже существует';

  @override
  String get catalogCategories => 'Категории';

  @override
  String get catalogAllCategories => 'Все категории';

  @override
  String get catalogNoCategories => 'Нет категорий';

  @override
  String get catalogQuickProductCategory => 'Категория быстрых товаров';

  @override
  String get catalogAddCategory => 'Добавить категорию';

  @override
  String get catalogCategoryName => 'Название категории';

  @override
  String get catalogManageCategories => 'Управление категориями';

  @override
  String get catalogCategoryHasProducts =>
      'Невозможно удалить: в категории есть товары';

  @override
  String get catalogConfirmDeleteCategory => 'Удалить категорию';

  @override
  String get catalogMenuCategories => 'Категории меню';

  @override
  String get catalogParentCategory => 'Родительская категория';

  @override
  String get catalogRootCategory => 'Корневая (без родителя)';

  @override
  String get telegramErrorPhoneSendFailed =>
      'Не удалось отправить код на телефон';

  @override
  String get telegramErrorQrAuthFailed => 'Ошибка авторизации по QR-коду';

  @override
  String get telegramErrorWrongCode => 'Неверный код подтверждения';

  @override
  String get telegramErrorWrongPassword => 'Неверный пароль';

  @override
  String get telegramErrorRegistrationFailed => 'Ошибка регистрации';

  @override
  String get telegramErrorChannelSearchFailed => 'Ошибка поиска каналов';

  @override
  String get telegramErrorChannelConnectFailed =>
      'Ошибка подключения к каналам';

  @override
  String get telegramErrorChannelCreateFailed => 'Ошибка создания каналов';

  @override
  String get hwSettingsTitle => 'Оборудование';

  @override
  String get hwSettingsSubtitle => 'Сканер, дисплей, терминалы';

  @override
  String get terminalServiceTitle => 'Браузерные терминалы';

  @override
  String get terminalServiceSubtitle => 'Планшет или телефон как рабочее место';

  @override
  String get terminalServiceEnable => 'Обслуживать браузерные терминалы';

  @override
  String get terminalServiceEnabledNote =>
      'Касса слушает сеть магазина. Терминалы могут подключиться.';

  @override
  String get terminalServiceDisabledNote =>
      'Касса слушает только саму себя. Порт в сеть не открыт, терминалы подключиться не могут.';

  @override
  String get terminalServiceRestartNote =>
      'Изменение вступит в силу после перезапуска кассы.';

  @override
  String get terminalServiceAddress => 'Адрес для терминала';

  @override
  String get terminalServiceAddressHint =>
      'Откройте этот адрес в браузере планшета. Если имя не открывается, наберите IP-адрес кассы.';

  @override
  String get pairingTitle => 'Привязка терминала';

  @override
  String get pairingSubtitle => 'Код для нового устройства';

  @override
  String get pairingDisabledNote =>
      'Касса не обслуживает браузерные терминалы. Включите обслуживание, чтобы выдать код привязки.';

  @override
  String get pairingDisabledAction => 'Открыть настройки терминалов';

  @override
  String get pairingAddressLabel => 'Ссылка для нового устройства';

  @override
  String get pairingAddressHint =>
      'Наберите или скопируйте этот адрес целиком на новом устройстве — код уже в нём.';

  @override
  String get pairingLinkPending =>
      'Ссылка появится здесь после того, как вы выдадите код.';

  @override
  String get pairingRestartNote =>
      'Обслуживание терминалов включено в настройках, но эта касса ещё не перезапущена с ним — адрес пока не откликнется. Перезапустите кассу.';

  @override
  String get pairingMint => 'Выдать код';

  @override
  String get pairingMintAgain => 'Выдать новый код';

  @override
  String get pairingCodeLabel => 'Код привязки';

  @override
  String pairingExpiresAt(String time) {
    return 'Действует до $time';
  }

  @override
  String get pairingOnceNote =>
      'Код показывается только сейчас — уйдя с этого экрана, вы не увидите его снова. «Выдать новый код» отзывает этот код, если он ещё не использован. Этот код расходуется при открытии ссылки — сам вход на устройстве после этого попросит отдельный второй код: выдайте новый, когда до этого дойдёт дело.';

  @override
  String get enrolTitle => 'Привязка терминала';

  @override
  String get enrolInstructions =>
      'Это устройство ещё не привязано к кассе. Попросите оператора открыть на кассе экран «Привязка терминала» и введите показанный там код.';

  @override
  String get enrolCodeLabel => 'Код привязки';

  @override
  String get enrolSubmit => 'Привязать';

  @override
  String get accountsSettingsTitle => 'Счета оплаты';

  @override
  String get accountsSettingsSubtitle => 'Наличные и карточные счета';

  @override
  String get accountsSettingsAdd => 'Добавить счёт';

  @override
  String get accountsSettingsEdit => 'Редактировать счёт';

  @override
  String get accountsSettingsEmpty => 'Нет настроенных счетов оплаты';

  @override
  String get accountsSettingsName => 'Название счёта';

  @override
  String get accountsSettingsType => 'Тип счёта';

  @override
  String get accountsSettingsTypePOS => 'Касса (наличные)';

  @override
  String get accountsSettingsTypeBank => 'Банк (карта)';

  @override
  String get accountsSettingsTypeCash => 'Наличные';

  @override
  String get accountsSettingsTypeSystem => 'Системный';

  @override
  String get accountsSettingsTypeBonus => 'Бонусный';

  @override
  String get accountsSettingsTypeOther => 'Прочий';

  @override
  String get accountsSettingsBalance => 'Баланс';

  @override
  String get accountsSettingsVisible => 'POS';

  @override
  String get accountsSettingsVisibleToPos => 'Видим в POS';

  @override
  String get hwSettingsSaved => 'Настройки оборудования сохранены';

  @override
  String get hwScannerTitle => 'Сканер штрих-кодов';

  @override
  String get hwScannerMode => 'Режим сканера';

  @override
  String get hwScannerModeKeyboard => 'USB / клавиатура (wedge)';

  @override
  String get hwScannerModeSerial => 'Серийный';

  @override
  String get hwScannerModeCamera => 'Камера';

  @override
  String get hwScannerModeHint => 'USB-сканеры работают в этом режиме';

  @override
  String get hwScannerTimeout => 'Таймаут';

  @override
  String get hwScannerMinLength => 'Мин. длина';

  @override
  String get hwScannerMaxLength => 'Макс. длина';

  @override
  String get hwDisplayTitle => 'Дисплей покупателя';

  @override
  String get hwDisplayModel => 'Модель';

  @override
  String get hwDisplayModelLed8 => 'LED 8 символов';

  @override
  String get hwDisplayModelVfd20 => 'VFD 20x2';

  @override
  String get hwDisplayPort => 'COM-порт';

  @override
  String get hwDisplayBaudRate => 'Скорость';

  @override
  String get hwDisplayDisabled => 'Дисплей покупателя отключён';

  @override
  String get hwDrawerTitle => 'Кассовый ящик';

  @override
  String get hwDrawerMode => 'Режим открытия';

  @override
  String get hwDrawerModePrinter => 'Через принтер';

  @override
  String get hwDrawerModeSerial => 'Серийный порт';

  @override
  String get hwDrawerPort => 'COM-порт';

  @override
  String get hwTerminalsTitle => 'Платёжные терминалы';

  @override
  String get hwTerminalIp => 'IP-адрес';

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
  String get catalogTypeConsumable => 'Расходник';

  @override
  String get catalogFilterConsumable => 'Расходники';

  @override
  String get catalogFilterInner => 'Внутренние';

  @override
  String get serviceMarkConsumable => 'Расходный материал';

  @override
  String get serviceConsumableSearch => 'Поиск товара / расходника';

  @override
  String get serviceConsumableSelected => 'Выбранный товар';

  @override
  String get serviceQuickServicesTitle => 'Быстрые услуги';

  @override
  String get serviceQuickServicesEmpty => 'Нет быстрых услуг';

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
  String get catalogTypeDish => 'Блюдо';

  @override
  String get catalogFilterDish => 'Блюда';

  @override
  String get dishCalculation => 'Калькуляция';

  @override
  String get dishCalculationStub => 'Модуль калькуляции будет доступен позже';

  @override
  String get dishIngredients => 'Ингредиенты';

  @override
  String get serviceConsumablesTitle => 'Нормы расхода';

  @override
  String get serviceConsumablesEmpty => 'Нет расходных материалов';

  @override
  String get serviceConsumablesAdd => 'Добавить расходник';

  @override
  String get serviceConsumableQuantity => 'Кол-во на 1 услугу';

  @override
  String get serviceConsumablesAutoAdded =>
      'Расходники добавлены автоматически';

  @override
  String get catalogDescription => 'Описание';

  @override
  String get catalogImagePlaceholder => 'Нажмите для загрузки фото';

  @override
  String get catalogImageFromGallery => 'Выбрать из галереи';

  @override
  String get catalogImageFromCamera => 'Сделать фото';

  @override
  String get catalogImageRemove => 'Удалить фото';

  @override
  String get catalogImagePickError => 'Не удалось загрузить фото';

  @override
  String get globalRetry => 'Повторить';

  @override
  String get globalRefresh => 'Обновить';

  @override
  String get globalReset => 'Сбросить';

  @override
  String get globalApply => 'Применить';

  @override
  String get globalCreate => 'Создать';

  @override
  String get stockOpSupply => 'Приёмка';

  @override
  String get stockOpMovement => 'Перемещение';

  @override
  String get stockOpSupplierReturn => 'Возврат поставщику';

  @override
  String get stockOpMovementShort => 'Перем.';

  @override
  String get stockOpReturnShort => 'Возврат';

  @override
  String get stockRegistryTitle => 'Складские операции';

  @override
  String get stockRegistryAppBarTitle => 'Склад';

  @override
  String get stockRegistryLoadError => 'Не удалось загрузить реестр';

  @override
  String get stockRegistryResetFilters => 'Сбросить фильтры';

  @override
  String get stockRegistryFilters => 'Фильтры';

  @override
  String get stockRegistryEmpty => 'Нет записей';

  @override
  String get stockRegistryEmptyFiltered => 'Измените параметры фильтра';

  @override
  String get stockRegistryEmptyCreate => 'Создайте первую складскую операцию';

  @override
  String get stockRegistryPeriod => 'Период';

  @override
  String get stockRegistryOperationType => 'Тип операции';

  @override
  String get stockRegistrySearchHint => 'Поиск по номеру, контрагенту...';

  @override
  String get stockRegistryDateFrom => 'С';

  @override
  String get stockRegistryDateTo => 'По';

  @override
  String get stockRegistryColType => 'Тип';

  @override
  String get stockRegistryColNumber => 'Номер';

  @override
  String get stockRegistryColCounterparty => 'Контрагент / Склад';

  @override
  String get stockRegistryColProducts => 'Товары';

  @override
  String get stockRegistryColStatus => 'Статус';

  @override
  String get stockSyncDraft => 'В работе';

  @override
  String get stockSyncPending => 'Ожидает';

  @override
  String get stockSyncSending => 'Отправка';

  @override
  String get stockSyncSynced => 'Синхр.';

  @override
  String stockRegistryDetailType(String type) {
    return 'Тип: $type';
  }

  @override
  String stockRegistryDetailDate(String date) {
    return 'Дата: $date';
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
    return 'Товаров: $count';
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
    return '$from–$to из $total';
  }

  @override
  String get stockCreateSupplyTitle => 'Новая приёмка';

  @override
  String get stockCreateSupplySubtitle => 'Приёмка товара от поставщика';

  @override
  String get stockCreateMovementSubtitle => 'Перемещение между складами';

  @override
  String get stockCreateReturnSubtitle => 'Возврат товара поставщику';

  @override
  String get stockCreateWriteoffSubtitle =>
      'Списание товара (бой, порча, просрочка)';

  @override
  String get stockCreateInventorySubtitle => 'Пересчёт фактических остатков';

  @override
  String get serviceQueueActive => 'Активных';

  @override
  String get serviceScanQrTitle => 'Сканировать QR-метку заказа';

  @override
  String get serviceScanQrHint => 'TELEPOS:SO:... или номер заказа';

  @override
  String get serviceIntakePhotos => 'Фото приёма';

  @override
  String get serviceIntakePhotosHint => 'Сделайте фото принимаемых предметов';

  @override
  String get expenseTypeOther => 'Другое';

  @override
  String get expenseTypeSmallPurchases => 'Закуп мелочей';

  @override
  String get expenseTypeSalary => 'Зарплата';

  @override
  String get expenseTypeUtilities => 'Коммунальные';

  @override
  String get expenseTypeCollection => 'Инкассация';

  @override
  String get expenseTypeCustom => 'Кастомный';

  @override
  String get networkTitle => 'Сеть и подключения';

  @override
  String get networkUnavailableTitle =>
      'Доступно только на устройстве TelePOS OS';

  @override
  String get networkUnavailableDesc =>
      'Системный демон telepos-sysd не обнаружен. Управление сетью работает только когда POS запущен на приставке TelePOS OS.';

  @override
  String get networkRefresh => 'Обновить';

  @override
  String get networkSearch => 'Поиск';

  @override
  String get networkConnect => 'Подключить';

  @override
  String get networkDisconnect => 'Отключить';

  @override
  String get networkConnected => 'Подключено';

  @override
  String get networkEthernetTitle => 'Проводная сеть (Ethernet)';

  @override
  String get networkEthernetDesc =>
      'Статус кабельного подключения и доступ в интернет.';

  @override
  String get networkCableLabel => 'Кабель';

  @override
  String get networkCableConnected => 'Подключён';

  @override
  String get networkCableNotConnected => 'Не подключён';

  @override
  String get networkInternetLabel => 'Интернет';

  @override
  String get networkInternetAvailable => 'Есть доступ';

  @override
  String get networkInternetUnavailable => 'Нет доступа';

  @override
  String get networkWifiTitle => 'Wi-Fi';

  @override
  String get networkWifiDesc => 'Подключение к беспроводной сети.';

  @override
  String get networkWifiSearchHint => 'Нажмите «Поиск», чтобы найти сети.';

  @override
  String get networkBluetoothTitle => 'Bluetooth';

  @override
  String get networkBluetoothDesc =>
      'Сопряжение с принтерами, весами и другими устройствами.';

  @override
  String get networkBluetoothSearchHint =>
      'Нажмите «Поиск», чтобы найти устройства.';

  @override
  String get networkBluetoothUnavailableInBrowser =>
      'Недоступно в браузере — Bluetooth настраивается только на самой кассе.';

  @override
  String networkWifiPasswordTitle(String ssid) {
    return 'Пароль для «$ssid»';
  }

  @override
  String get networkWifiPasswordLabel => 'Пароль Wi-Fi';

  @override
  String networkConnectedTo(String ssid) {
    return 'Подключено к $ssid';
  }

  @override
  String networkConnectFailed(String ssid) {
    return 'Не удалось подключиться к $ssid';
  }

  @override
  String networkPaired(String device) {
    return 'Сопряжено: $device';
  }

  @override
  String get networkPairFailed => 'Не удалось выполнить сопряжение';

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
  String get applianceHubSubtitle => 'Управление системой, сеть, драйверы';

  @override
  String get applianceUnavailableDesc =>
      'Системный демон telepos-sysd не обнаружен. Этот раздел работает только когда POS запущен на приставке TelePOS OS.';

  @override
  String get applianceNetworkTitle => 'Сеть и подключения';

  @override
  String get applianceNetworkDesc =>
      'Wi-Fi, проводная сеть и Bluetooth. Нужны для входа и синхронизации.';

  @override
  String get applianceNetworkButton => 'Настроить сеть';

  @override
  String get applianceDesktopTitle => 'Режим рабочего стола';

  @override
  String get applianceDesktopDesc =>
      'Полноценный рабочий стол для установки приложений и обслуживания.';

  @override
  String get applianceCurrentMode => 'Текущий режим: ';

  @override
  String get applianceOpenDesktop => 'Открыть рабочий стол';

  @override
  String get applianceDesktopUnavailable =>
      'Рабочий стол недоступен в этой сборке.';

  @override
  String get applianceModeKiosk => 'Касса (POS)';

  @override
  String get applianceModeDesktop => 'Рабочий стол';

  @override
  String get applianceDriversTitle => 'Драйверы периферии';

  @override
  String get applianceDriversDesc =>
      'Установка драйверов принтеров, весов и платёжных терминалов из проверенного каталога TelePOS.';

  @override
  String get applianceDriversEmpty => 'Каталог драйверов пуст.';

  @override
  String get applianceDriverInstall => 'Установить';

  @override
  String get applianceDriverRemove => 'Удалить';

  @override
  String applianceDriverInstalled(String title) {
    return 'Драйвер установлен: $title';
  }

  @override
  String applianceDriverRemoved(String title) {
    return 'Драйвер удалён: $title';
  }

  @override
  String applianceError(String message) {
    return 'Ошибка: $message';
  }

  @override
  String get navNetwork => 'Сеть';

  @override
  String get navCollapseMenu => 'Свернуть меню';

  @override
  String get navExpandMenu => 'Развернуть меню';

  @override
  String get languageSwitcherTooltip => 'Язык / Language / Тіл';

  @override
  String get labelPrinterSettingsTitle => 'Принтер этикеток';

  @override
  String get labelPrinterSettingsSubtitle => 'Ценники и штрих-коды';

  @override
  String get labelPrinterLanguage => 'Язык принтера';

  @override
  String get labelPrinterSize => 'Размер этикетки';

  @override
  String get labelPrinterWidthMm => 'Ширина, мм';

  @override
  String get labelPrinterHeightMm => 'Высота, мм';

  @override
  String get labelPrinterTestSuccess => 'Этикетка отправлена на печать';

  @override
  String get labelPrinterNotConfigured =>
      'Принтер этикеток не настроен. Укажите адрес в настройках.';

  @override
  String get labelTemplatesTitle => 'Шаблоны этикеток';

  @override
  String get labelTemplatesManage => 'Управление шаблонами';

  @override
  String get labelTemplatesManageSubtitle =>
      'Создание и редактирование раскладок';

  @override
  String get labelTemplatesEmpty => 'Шаблоны не найдены';

  @override
  String get labelTemplateNew => 'Новый шаблон';

  @override
  String get labelTemplateEdit => 'Редактирование шаблона';

  @override
  String get labelTemplateBuiltIn => 'Встроенный';

  @override
  String get labelMmUnit => 'мм';

  @override
  String get labelTemplateDeleteTitle => 'Удалить шаблон';

  @override
  String labelTemplateDeleteConfirm(String name) {
    return 'Удалить шаблон «$name»?';
  }

  @override
  String get labelTemplateName => 'Название шаблона';

  @override
  String get labelTemplateNameRequired => 'Укажите название шаблона';

  @override
  String get labelTemplatePreview => 'Предпросмотр';

  @override
  String get labelTemplateFields => 'Поля';

  @override
  String get labelTemplateAddField => 'Добавить поле';

  @override
  String get labelTemplateNoFields => 'Нет полей. Добавьте хотя бы одно поле.';

  @override
  String get labelFieldKind => 'Тип поля';

  @override
  String get labelFieldText => 'Текст';

  @override
  String get labelFieldFontSize => 'Шрифт';

  @override
  String get labelFieldBold => 'Жирный';

  @override
  String get labelFieldKindName => 'Название';

  @override
  String get labelFieldKindPrice => 'Цена';

  @override
  String get labelFieldKindBarcode => 'Штрих-код';

  @override
  String get labelFieldKindSku => 'Артикул';

  @override
  String get labelFieldKindDate => 'Дата';

  @override
  String get labelFieldKindText => 'Текст';

  @override
  String get labelPrintTitle => 'Печать ценника';

  @override
  String labelPrintBulkTitle(int count) {
    return 'Печать ценников ($count)';
  }

  @override
  String get labelPrintChooseTemplate => 'Выберите шаблон';

  @override
  String get labelPrintCopies => 'Копий';

  @override
  String get labelPrintAction => 'Печать';

  @override
  String labelPrintedCount(int count) {
    return 'Напечатано: $count';
  }

  @override
  String get catalogPrintLabel => 'Печать ценника';

  @override
  String get receiptTemplatesTitle => 'Шаблоны чеков';

  @override
  String get receiptTemplatesSubtitle =>
      'Оформление чека: логотип, шапка/подвал, БИН, QR, ширина';

  @override
  String get receiptTemplatesEmpty => 'Шаблоны не найдены';

  @override
  String get receiptTemplateNew => 'Новый шаблон';

  @override
  String get receiptTemplateEdit => 'Редактирование шаблона';

  @override
  String get receiptTemplateBuiltIn => 'Встроенный';

  @override
  String get receiptTemplateActive => 'Активный';

  @override
  String get receiptTemplateMakeActive => 'Сделать активным';

  @override
  String get receiptTemplateName => 'Название шаблона';

  @override
  String get receiptTemplateNameRequired => 'Укажите название шаблона';

  @override
  String get receiptTemplatePreview => 'Предпросмотр';

  @override
  String get receiptTemplatePaperWidth => 'Ширина бумаги';

  @override
  String get receiptTemplateContent => 'Содержимое чека';

  @override
  String get receiptTemplateHeaderFooter => 'Шапка и подвал';

  @override
  String get receiptTemplateHeaderText => 'Текст шапки';

  @override
  String get receiptTemplateFooterText => 'Текст подвала';

  @override
  String get receiptTemplateExtraFooter => 'Доп. строки подвала';

  @override
  String get receiptTemplateExtraFooterHint =>
      'По одной строке на каждую (например, условия возврата)';

  @override
  String get receiptTemplateShowBin => 'Печатать БИН/ИИН';

  @override
  String get receiptTemplateShowAddress => 'Печатать адрес';

  @override
  String get receiptTemplateShowCashier => 'Печатать кассу/кассира';

  @override
  String get receiptTemplateShowVat => 'Печатать НДС';

  @override
  String get receiptTemplateShowQr => 'Печатать ссылку проверки (QR)';

  @override
  String get receiptTemplateShowItemNumbers => 'Нумеровать позиции';

  @override
  String get receiptTemplateShowLogo => 'Печатать логотип';

  @override
  String get receiptTemplateTestPrint => 'Тестовая печать';

  @override
  String get receiptTemplateTestPrintOk => 'Образец чека отправлен на печать';

  @override
  String get receiptTemplateTestPrintFail =>
      'Не удалось напечатать (проверьте принтер)';

  @override
  String get receiptTemplateDeleteTitle => 'Удалить шаблон';

  @override
  String get receiptTemplateHeaderHint =>
      'Несколько строк: приветствие, акция, контакты';

  @override
  String get receiptTemplateFooterHint =>
      'Несколько строк: благодарность, условия возврата, сайт, соцсети';

  @override
  String get receiptTemplateAlignLeft => 'Слева';

  @override
  String get receiptTemplateAlignCenter => 'По центру';

  @override
  String get receiptTemplateAlignRight => 'Справа';

  @override
  String get receiptTemplateBold => 'Жирный';

  @override
  String get receiptTemplateDoubleSize => 'Крупный (двойной размер)';

  @override
  String get receiptTemplatePaperWidthHint =>
      'Ширина ленты задаётся в настройках принтера';

  @override
  String get receiptTemplateMandatoryNote =>
      'Обязательные реквизиты — номер чека, итог, оплаты, НДС, фискальный признак и QR — печатаются всегда, между шапкой и подвалом';

  @override
  String receiptTemplateDeleteConfirm(String name) {
    return 'Удалить шаблон «$name»?';
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
      'На этом устройстве нет управляемого экрана (нет подсветки/backlight). Яркость и поворот регулируются на самом мониторе.';

  @override
  String get sysmRotation => 'Поворот экрана';

  @override
  String get sysmRemoteTitle => 'Удалённая поддержка';

  @override
  String get sysmRemoteDesc =>
      'Временный защищённый доступ для службы поддержки';

  @override
  String get sysmRemoteHelp =>
      '«Восстановить поддержку» открывает службе поддержки TelePOS временный защищённый канал (SSH) к приставке, чтобы удалённо решить проблему. Доступ автоматически закрывается через 30 минут. Включайте только по просьбе поддержки.';

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
  String get sysmTermGroupNetwork => 'Сеть';

  @override
  String get sysmTermGroupSystem => 'Система';

  @override
  String get sysmTermGroupTime => 'Время';

  @override
  String get sysmTermDiagOsAndDaemon => 'Версия ОС и демона';

  @override
  String get sysmTermDiagNetworkStatus => 'Сеть: статус и адрес';

  @override
  String get sysmTermDiagNetworkConnectivity => 'Сеть: связность';

  @override
  String get sysmTermDiagHardware => 'Железо: диск/память/принтеры';

  @override
  String get sysmTermPrinterFixAuto => 'Починить принтер (авто)';

  @override
  String get sysmTermPrinterDiag => 'Диагностика принтера';

  @override
  String get sysmTermPrinterLoadUsblp => 'Загрузить модуль usblp';

  @override
  String get sysmTermPrinterNodesAndPerms => 'Узлы принтера и права';

  @override
  String get sysmTermPrinterLsusb => 'USB-устройства (lsusb)';

  @override
  String get sysmTermPrinterCupsStatus => 'CUPS: статус и очереди';

  @override
  String get sysmTermPrinterGiveToKernel => 'Отдать принтер ядру (usblp)';

  @override
  String get sysmTermPrinterTestPrint => 'Тест-печать на /dev/usb/lp0';

  @override
  String get sysmTermNetDeviceStatus => 'Статус устройств';

  @override
  String get sysmTermNetIpAddresses => 'IP-адреса';

  @override
  String get sysmTermNetConnectEthernet => 'Подключить Ethernet';

  @override
  String get sysmTermNetReload => 'Перезагрузить сеть';

  @override
  String get sysmTermNetPing => 'Пинг 8.8.8.8';

  @override
  String get sysmTermSysDisk => 'Диск';

  @override
  String get sysmTermSysMemory => 'Память';

  @override
  String get sysmTermSysSysdStatus => 'Статус telepos-sysd';

  @override
  String get sysmTermSysKioskLogs => 'Логи киоска';

  @override
  String get sysmTermTimeDateTime => 'Дата и время';

  @override
  String get sysmTermTimeNtpSync => 'Синхронизация NTP';

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
  String get catalogPageFirst => 'Первая';

  @override
  String get catalogPagePrev => 'Назад';

  @override
  String get catalogPageNext => 'Вперёд';

  @override
  String get catalogPageLast => 'Последняя';

  @override
  String get catalogGoToPage => 'Перейти к странице';

  @override
  String catalogPageOf(int total) {
    return 'Страница из $total';
  }

  @override
  String get shiftClosedGateTitle => 'Смена закрыта';

  @override
  String get shiftClosedGateMessage =>
      'Откройте смену, чтобы продолжить работу с операциями.';

  @override
  String get shiftClosedGateOpen => 'Открыть смену';

  @override
  String get sysmTerminalPresetsDiag => 'Диагностика';

  @override
  String get wmsDashboardTitle => 'WMS — Управление складом';

  @override
  String get wmsDashboardTitleShort => 'WMS — Склад';

  @override
  String get wmsSettings => 'Настройки WMS';

  @override
  String get wmsSettingsSubtitle => 'Конфигурация модулей';

  @override
  String get wmsModuleWarehouses => 'Склады';

  @override
  String get wmsModuleWarehousesSubtitle => 'Склады, зоны, ячейки';

  @override
  String get wmsModuleBatches => 'Партии';

  @override
  String get wmsModuleBatchesSubtitle => 'Партионный учёт';

  @override
  String get wmsModuleCellStock => 'Остатки по ячейкам';

  @override
  String get wmsModuleCellStockSubtitle => 'Остатки, размещение, отбор';

  @override
  String get wmsModuleSerials => 'Серийный учёт';

  @override
  String get wmsModuleSerialsSubtitle => 'Серийные номера';

  @override
  String get wmsModuleMarking => 'Маркировка';

  @override
  String get wmsModuleMarkingSubtitle => 'Коды маркировки';

  @override
  String get wmsModuleClaims => 'Рекламации';

  @override
  String get wmsModuleClaimsSubtitle => 'Претензии и возвраты';

  @override
  String get wmsWarehousesAndCells => 'Склады и ячейки';

  @override
  String get wmsWarehouses => 'Склады';

  @override
  String get wmsAddWarehouse => 'Добавить склад';

  @override
  String get wmsNoWarehouses => 'Нет складов';

  @override
  String get wmsNoName => 'Без имени';

  @override
  String get wmsZones => 'Зоны';

  @override
  String wmsZonesNamed(String name) {
    return 'Зоны: $name';
  }

  @override
  String get wmsAddZone => 'Добавить зону';

  @override
  String get wmsSelectWarehouse => 'Выберите склад';

  @override
  String get wmsNoZones => 'Нет зон';

  @override
  String get wmsCells => 'Ячейки';

  @override
  String wmsCellsNamed(String name) {
    return 'Ячейки: $name';
  }

  @override
  String get wmsGenerate => 'Генерировать';

  @override
  String get wmsSelectZone => 'Выберите зону';

  @override
  String get wmsNoCells => 'Нет ячеек';

  @override
  String get wmsNoAddress => 'Без адреса';

  @override
  String get wmsCellBlocked => 'Заблокирована';

  @override
  String wmsCellsCount(int count) {
    return '$count ячеек';
  }

  @override
  String get wmsNewWarehouse => 'Новый склад';

  @override
  String get wmsWarehouseCode => 'Код склада';

  @override
  String get wmsName => 'Наименование';

  @override
  String get wmsError => 'Ошибка';

  @override
  String get wmsCreate => 'Создать';

  @override
  String get wmsSelectWarehouseFirst => 'Сначала выберите склад';

  @override
  String get wmsNewZone => 'Новая зона';

  @override
  String get wmsZoneCode => 'Код зоны';

  @override
  String get wmsSelectZoneFirst => 'Сначала выберите зону';

  @override
  String get wmsGenerateCells => 'Генерация ячеек';

  @override
  String get wmsRows => 'Ряды';

  @override
  String get wmsRacks => 'Стеллажи';

  @override
  String get wmsLevels => 'Уровни';

  @override
  String get wmsBins => 'Ячейки';

  @override
  String get wmsEditWarehouse => 'Редактировать склад';

  @override
  String get wmsAddress => 'Адрес';

  @override
  String get wmsDeleteWarehouseTitle => 'Удалить склад?';

  @override
  String wmsDeleteWarehouseConfirm(String name) {
    return 'Вы уверены, что хотите удалить склад \"$name\"?';
  }

  @override
  String get wmsCellStockTitle => 'Остатки по ячейкам';

  @override
  String get wmsPlace => 'Разместить';

  @override
  String get wmsPick => 'Отобрать';

  @override
  String get wmsTransfer => 'Переместить';

  @override
  String get wmsByCell => 'По ячейке';

  @override
  String get wmsByProduct => 'По товару';

  @override
  String get wmsSearchCellHint => 'Введите ID или адрес ячейки...';

  @override
  String get wmsSearchProductHint => 'Введите ucode товара...';

  @override
  String get wmsCell => 'Ячейка';

  @override
  String get wmsProductUcode => 'Код товара (ucode)';

  @override
  String get wmsFind => 'Найти';

  @override
  String get wmsEnterCellIdToSearch => 'Введите ID ячейки для поиска остатков';

  @override
  String get wmsEnterUcodeToSearch => 'Введите ucode товара для поиска';

  @override
  String wmsProductLabeled(String value) {
    return 'Товар: $value';
  }

  @override
  String wmsCellLabeled(String value) {
    return 'Ячейка: $value';
  }

  @override
  String wmsStockSummary(String qty, String reserved, String available) {
    return 'Кол-во: $qty  |  Резерв: $reserved  |  Доступно: $available';
  }

  @override
  String wmsBatchLabeled(String value) {
    return 'Партия: $value';
  }

  @override
  String get wmsQuantityShort => 'Кол-во';

  @override
  String get wmsReserved => 'Резерв';

  @override
  String get wmsAvailable => 'Доступно';

  @override
  String get wmsBatch => 'Партия';

  @override
  String get wmsEnterNumericId => 'Введите числовой ID';

  @override
  String get wmsPlaceStockTitle => 'Разместить товар в ячейке';

  @override
  String get wmsCellId => 'ID ячейки';

  @override
  String get wmsProductUcodeField => 'ucode товара';

  @override
  String get wmsQuantity => 'Количество';

  @override
  String get wmsBatchIdOptional => 'ID партии (необязательно)';

  @override
  String get wmsFillRequiredNumericFields =>
      'Заполните обязательные поля (числовые значения)';

  @override
  String wmsStockPlaced(String cellId) {
    return 'Товар размещён в ячейке $cellId';
  }

  @override
  String get wmsPlaceError => 'Ошибка размещения';

  @override
  String get wmsPickStockTitle => 'Отобрать товар из ячейки';

  @override
  String get wmsFillAllNumericFields =>
      'Заполните все поля (числовые значения)';

  @override
  String wmsStockPicked(String cellId) {
    return 'Товар отобран из ячейки $cellId';
  }

  @override
  String get wmsPickError => 'Ошибка отбора';

  @override
  String get wmsTransferStockTitle => 'Переместить товар';

  @override
  String get wmsCellIdFrom => 'ID ячейки (откуда)';

  @override
  String get wmsCellIdTo => 'ID ячейки (куда)';

  @override
  String wmsStockTransferred(String from, String to) {
    return 'Товар перемещён из ячейки $from в $to';
  }

  @override
  String get wmsTransferError => 'Ошибка перемещения';

  @override
  String get wmsBatches => 'Партии';

  @override
  String get wmsBatchTrackingTitle => 'Партионный учёт';

  @override
  String get wmsBatchTabAll => 'Все партии';

  @override
  String get wmsBatchTabExpiring => 'Истекающие';

  @override
  String get wmsBatchTabExpired => 'Просроченные';

  @override
  String get wmsBatchTabQuarantine => 'Карантин';

  @override
  String get wmsNoBatches => 'Нет партий';

  @override
  String get wmsNoExpiringBatches => 'Нет истекающих партий';

  @override
  String get wmsNoExpiredBatches => 'Нет просроченных партий';

  @override
  String get wmsNoQuarantinedBatches => 'Нет партий на карантине';

  @override
  String get wmsSearchByUcodeHint => 'Поиск по ucode товара...';

  @override
  String get wmsNoNumber => 'Без номера';

  @override
  String wmsBatchCardSummary(String ucode, String expiry, String qty) {
    return 'Товар: $ucode  |  Срок: $expiry  |  Кол-во: $qty';
  }

  @override
  String get wmsBatchNumber => 'Номер партии';

  @override
  String get wmsProduct => 'Товар';

  @override
  String get wmsExpiryDate => 'Срок годности';

  @override
  String get wmsStatus => 'Статус';

  @override
  String get wmsActions => 'Действия';

  @override
  String get wmsQuarantine => 'Карантин';

  @override
  String get wmsApprove => 'Одобрить';

  @override
  String get wmsStatusQuarantine => 'Карантин';

  @override
  String get wmsStatusExpired => 'Просрочено';

  @override
  String get wmsStatusExpiring => 'Истекает';

  @override
  String get wmsStatusOk => 'ОК';

  @override
  String get wmsMoveToQuarantine => 'Поместить в карантин';

  @override
  String wmsBatchQuarantined(String number) {
    return 'Партия $number помещена в карантин';
  }

  @override
  String wmsBatchApproved(String number) {
    return 'Партия $number одобрена';
  }

  @override
  String get wmsSearchBatchesByProduct => 'Поиск партий по товару';

  @override
  String get wmsEnterProductCode => 'Введите код товара';

  @override
  String get wmsSerialTrackingTitle => 'Серийный учёт';

  @override
  String get wmsScan => 'Сканировать';

  @override
  String get wmsSearchBySerialHint => 'Поиск по серийному номеру...';

  @override
  String get wmsNothingFound => 'Ничего не найдено';

  @override
  String get wmsEnterSerialToSearch => 'Введите серийный номер для поиска';

  @override
  String get wmsRegister => 'Зарегистрировать';

  @override
  String get wmsSelectSerial => 'Выберите серийный номер';

  @override
  String get wmsSerialNumber => 'Серийный номер';

  @override
  String get wmsLocation => 'Местоположение';

  @override
  String wmsCellHash(String id) {
    return 'Ячейка #$id';
  }

  @override
  String get wmsDetails => 'Детали';

  @override
  String get wmsMarking => 'Маркировка';

  @override
  String get wmsWarrantyUntil => 'Гарантия до';

  @override
  String get wmsNotes => 'Примечания';

  @override
  String get wmsMovementHistory => 'История движений';

  @override
  String get wmsNoData => 'Нет данных';

  @override
  String get wmsSerialStatusInStock => 'На складе';

  @override
  String get wmsSerialStatusSold => 'Продан';

  @override
  String get wmsSerialStatusReturned => 'Возвращён';

  @override
  String get wmsSerialStatusWrittenOff => 'Списан';

  @override
  String get wmsSerialStatusUnknown => 'Неизвестно';

  @override
  String get wmsScannerUseHardware => 'Сканер: используйте аппаратный сканер';

  @override
  String get wmsRegisterSerialTitle => 'Регистрация серийного номера';

  @override
  String get wmsSerialRegistered => 'Серийный номер зарегистрирован';

  @override
  String get wmsMarkingCodesTitle => 'Коды маркировки';

  @override
  String get wmsMarkingAccept => 'Приёмка';

  @override
  String get wmsRefresh => 'Обновить';

  @override
  String get wmsIsMptSettings => 'Настройки ИС МПТ';

  @override
  String get wmsMarkingAcceptTitle => 'Приёмка кодов маркировки';

  @override
  String get wmsSupplyIdOptional => 'ID поставки (необяз.)';

  @override
  String get wmsMarkingCodesPerLine => 'Коды маркировки (по одному на строку)';

  @override
  String get wmsAccept => 'Принять';

  @override
  String get wmsNoCodesEntered => 'Не введено ни одного кода';

  @override
  String wmsAcceptedLocally(String count) {
    return 'Принято локально: $count (ИС МПТ — отложено)';
  }

  @override
  String wmsAccepted(String count) {
    return 'Принято: $count';
  }

  @override
  String wmsAcceptError(String error) {
    return 'Ошибка приёмки: $error';
  }

  @override
  String wmsMarkingStatusResult(String status) {
    return 'Статус КМ: $status';
  }

  @override
  String get wmsInCirculation => '(в обороте)';

  @override
  String get wmsIsMptNoConnection => 'Нет связи с ИС МПТ — проверка отложена';

  @override
  String get wmsVerifyUnavailable =>
      'Проверка недоступна (ИС МПТ не настроена)';

  @override
  String wmsVerifyError(String error) {
    return 'Ошибка проверки: $error';
  }

  @override
  String get wmsNoMarkingCodes => 'Нет кодов маркировки';

  @override
  String get wmsVerifyStatus => 'Проверить статус (ИС МПТ)';

  @override
  String get wmsMarkingStatusReceived => 'Получен';

  @override
  String get wmsMarkingStatusInStock => 'На складе';

  @override
  String get wmsMarkingStatusSold => 'Продан';

  @override
  String get wmsMarkingStatusReturned => 'Возврат';

  @override
  String get wmsMarkingStatusRetired => 'Списан';

  @override
  String get wmsMarkingStatusBlocked => 'Заблокирован';

  @override
  String get wmsClaims => 'Рекламации';

  @override
  String get wmsClaimTabOpen => 'Открытые';

  @override
  String get wmsClaimTabInProgress => 'В работе';

  @override
  String get wmsClaimTabResolved => 'Решённые';

  @override
  String get wmsNoOpenClaims => 'Нет открытых рекламаций';

  @override
  String get wmsNoInProgressClaims => 'Нет рекламаций в работе';

  @override
  String get wmsNoResolvedClaims => 'Нет решённых рекламаций';

  @override
  String get wmsNewClaim => 'Новая рекламация';

  @override
  String get wmsNumber => 'Номер';

  @override
  String get wmsType => 'Тип';

  @override
  String get wmsSeverity => 'Серьёзность';

  @override
  String get wmsDate => 'Дата';

  @override
  String get wmsSeverityLow => 'Низкая';

  @override
  String get wmsSeverityMedium => 'Средняя';

  @override
  String get wmsSeverityHigh => 'Высокая';

  @override
  String get wmsSeverityCritical => 'Критическая';

  @override
  String get wmsClaimTypeDefect => 'Брак';

  @override
  String get wmsClaimTypeMissort => 'Пересортица';

  @override
  String get wmsClaimTypeShortage => 'Недостача';

  @override
  String get wmsClaimTypeDamage => 'Повреждение';

  @override
  String get wmsClaimTypeOther => 'Другое';

  @override
  String get wmsProblemDescription => 'Описание проблемы';

  @override
  String get wmsClaimCreated => 'Рекламация создана';

  @override
  String wmsClaimTitle(String number) {
    return 'Рекламация $number';
  }

  @override
  String wmsTypeLabeled(String value) {
    return 'Тип: $value';
  }

  @override
  String wmsSeverityLabeled(String value) {
    return 'Серьёзность: $value';
  }

  @override
  String wmsDateLabeled(String value) {
    return 'Дата: $value';
  }

  @override
  String get wmsProblemDescriptionLabel => 'Описание проблемы:';

  @override
  String get wmsNoDescription => 'Нет описания';

  @override
  String get wmsResolutionLabel => 'Решение:';

  @override
  String get wmsNotSpecified => 'Не указано';

  @override
  String get wmsHistoryLabel => 'История:';

  @override
  String get wmsNoRecords => 'Нет записей';

  @override
  String get wmsResolve => 'Решить';

  @override
  String get wmsResolveClaimTitle => 'Решить рекламацию';

  @override
  String get wmsResolutionNotes => 'Заметки по решению';

  @override
  String get wmsClaimResolved => 'Рекламация решена';

  @override
  String get setUserManagementTitle => 'Пользователи и доступ';

  @override
  String get setUsersTitle => 'Пользователи';

  @override
  String get setUsersSubtitle => 'Управление доступом';

  @override
  String get authSettingsTitle => 'Вход и сеанс';

  @override
  String get authSettingsSubtitle => 'Вход без кассира и срок сеанса';

  @override
  String get authSettingsWalkUpTitle => 'Вход без выбора кассира';

  @override
  String get authSettingsWalkUpSubtitle =>
      'Один PIN пускает без имени. Небезопасно при нескольких кассирах: по умолчанию выключено.';

  @override
  String get authSettingsSessionTitle => 'Срок сеанса';

  @override
  String get authSettingsSessionSubtitle =>
      'Сколько минут кассир остаётся в сеансе без действий. Меняется сразу, без перезапуска кассы.';

  @override
  String get authSettingsSessionMinutesLabel => 'Минут';

  @override
  String get authSettingsSaved => 'Сохранено';

  @override
  String get authSettingsInvalidMinutes =>
      'Введите целое число минут от 1 до 1440';

  @override
  String get sessionsTitle => 'Активные сеансы';

  @override
  String get sessionsSubtitle => 'Кто сейчас в кассе, отзыв по кнопке';

  @override
  String get sessionsEmpty => 'Сейчас никто не вошёл в кассу';

  @override
  String sessionsTerminalLabel(String id) {
    return 'Терминал №$id';
  }

  @override
  String sessionsTimes(String issued, String expires) {
    return 'Вошёл $issued · истекает $expires';
  }

  @override
  String get sessionsRevoke => 'Завершить';

  @override
  String get sessionsRevokeConfirmTitle => 'Завершить сеанс?';

  @override
  String sessionsRevokeConfirmBody(String name) {
    return '«$name» будет выведен из кассы немедленно.';
  }

  @override
  String sessionsRevoked(String name) {
    return 'Сеанс «$name» завершён';
  }

  @override
  String sessionsRevokeError(String error) {
    return 'Не удалось завершить сеанс: $error';
  }

  @override
  String get setUsersEmpty => 'Нет пользователей';

  @override
  String get setAddUser => 'Добавить пользователя';

  @override
  String setUserNumber(String id) {
    return 'Пользователь №$id';
  }

  @override
  String get setUserActive => 'Активен';

  @override
  String setUsersLoadError(String error) {
    return 'Ошибка: $error';
  }

  @override
  String get setNewUser => 'Новый пользователь';

  @override
  String get setEditUser => 'Редактирование';

  @override
  String get setUserTabProfile => 'Профиль';

  @override
  String get setUserTabPermissions => 'Права доступа';

  @override
  String get setUserName => 'Имя';

  @override
  String get setUserNameRequired => 'Введите имя';

  @override
  String get setUserPinLabel => 'PIN (4-6 цифр)';

  @override
  String get setUserPinRequired => 'Введите PIN';

  @override
  String get setUserPinMin => 'Минимум 4 цифры';

  @override
  String get setUserPinRange => 'PIN должен быть 4-6 цифр';

  @override
  String get setUserRole => 'Роль';

  @override
  String get setRoleOwner => 'Владелец';

  @override
  String get setRoleAdministrator => 'Администратор';

  @override
  String get setRoleUser => 'Пользователь';

  @override
  String get setRoleCashier => 'Кассир';

  @override
  String get setUserActiveDesc => 'Пользователь может входить в систему';

  @override
  String get setUserBlockedDesc => 'Доступ заблокирован';

  @override
  String get setUserOwnerFullAccess => 'Владелец имеет полный доступ';

  @override
  String get setUserSelectAll => 'Выбрать все';

  @override
  String get setUserDeselectAll => 'Снять все';

  @override
  String get setDeleteUserTitle => 'Удалить пользователя?';

  @override
  String setDeleteUserConfirm(String name) {
    return 'Пользователь «$name» будет удалён. Это действие нельзя отменить.';
  }

  @override
  String setDeleteUserError(String error) {
    return 'Не удалось удалить пользователя: $error';
  }

  @override
  String get setUserNoEncryptionKey =>
      'Не настроен ключ шифрования. Завершите начальную настройку POS.';

  @override
  String get setUserPinEncryptFailed => 'Не удалось зашифровать PIN';

  @override
  String get setWmsTitle => 'Настройки WMS';

  @override
  String get setWmsModules => 'Модули WMS';

  @override
  String get setWmsCellStorage => 'Ячеечное хранение';

  @override
  String get setWmsCellStorageDesc =>
      'Адресное хранение товаров по зонам и ячейкам';

  @override
  String get setWmsBatchTracking => 'Партионный учёт';

  @override
  String get setWmsBatchTrackingDesc =>
      'Учёт товаров по партиям с отслеживанием поставок';

  @override
  String get setWmsSerialTracking => 'Серийный учёт';

  @override
  String get setWmsSerialTrackingDesc =>
      'Поштучный учёт по уникальным серийным номерам';

  @override
  String get setWmsExpiryControl => 'Контроль сроков годности';

  @override
  String get setWmsExpiryControlDesc =>
      'Предупреждения об истечении и автоматический FEFO-подбор';

  @override
  String get setWmsMarking => 'Маркировка';

  @override
  String get setWmsMarkingDesc =>
      'Поддержка обязательных кодов маркировки (DataMatrix, GS1)';

  @override
  String get setWmsWarranty => 'Гарантийный учёт';

  @override
  String get setWmsWarrantyDesc =>
      'Отслеживание гарантийных сроков по серийным номерам';

  @override
  String get setWmsPickingStrategy => 'Стратегия подбора';

  @override
  String get setWmsPickingStrategyDesc =>
      'Определяет порядок отгрузки товаров со склада';

  @override
  String get setWmsStrategy => 'Стратегия';

  @override
  String get setWmsStrategyFefo => 'FEFO — первый истекает, первый уходит';

  @override
  String get setWmsStrategyFifo => 'FIFO — первый пришёл, первый ушёл';

  @override
  String get setWmsStrategyLifo => 'LIFO — последний пришёл, первый ушёл';

  @override
  String get setWmsCostMethod => 'Метод расчёта себестоимости';

  @override
  String get setWmsCostMethodDesc => 'Метод списания себестоимости при продаже';

  @override
  String get setWmsMethod => 'Метод';

  @override
  String get setWmsCostFifo => 'FIFO — по порядку поступления';

  @override
  String get setWmsCostLifo => 'LIFO — по обратному порядку';

  @override
  String get setWmsCostAvg => 'Средневзвешенная стоимость';

  @override
  String get setWmsExpiryWarnDesc =>
      'За сколько дней до истечения предупреждать';

  @override
  String setWmsDaysShort(int days) {
    return '$days дн.';
  }

  @override
  String get setWmsAbcAnalysis => 'ABC-анализ';

  @override
  String get setWmsAbcDesc => 'Пороги классификации товаров по обороту';

  @override
  String get setWmsAbcCategoryA => 'Категория A (высокий оборот)';

  @override
  String get setWmsAbcCategoryB => 'Категория B (средний оборот)';

  @override
  String get setWmsAbcCategoryC => 'Категория C (низкий оборот)';

  @override
  String get setWmsSaved => 'Настройки WMS сохранены';

  @override
  String get setWmsSaveError => 'Не удалось сохранить настройки WMS';

  @override
  String get setSalesPolicy => 'Политика продаж';

  @override
  String get setSalesPolicyDesc => 'Контроль остатков при продаже';

  @override
  String get setBlockOversell => 'Запрет продажи при недостатке остатка';

  @override
  String get setBlockOversellDesc =>
      'Не завершать продажу, если количество в чеке превышает остаток (защита от отрицательного остатка)';

  @override
  String get setScreenTouch => 'Экран и тачскрин';

  @override
  String get setScreenTouchDesc => 'Удобство на сенсорном экране';

  @override
  String get setScrollAssist => 'Кнопки прокрутки на сенсорном экране';

  @override
  String get setScrollAssistDesc =>
      'Экранные кнопки ▲/▼ для прокрутки длинных списков (каталог, чек, отчёты, склад) на тачскрине';

  @override
  String get setDemoData => 'Демо данные';

  @override
  String get setDemoDataSubtitle => '12 месяцев продаж';

  @override
  String get setDemoDataDialogContent =>
      'Загрузить демо данные для всех режимов:\n• Розница: ~6000 продаж, поставки, возвраты\n• Ресторан: 15 столов, 29 блюд с калькуляцией, заказы\n• Сервис: услуги, расходники, заказ-наряды\n\nИли очистить все данные для чистого старта.';

  @override
  String get setDemoClearAll => 'Очистить всё';

  @override
  String get setDemoLoad => 'Загрузить демо';

  @override
  String get setDemoGenerating => 'Генерация демо данных...';

  @override
  String get setDemoLoadedTitle => 'Демо данные загружены';

  @override
  String get setDemoAlreadyExists =>
      'Данные уже существуют. Сначала нажмите «Очистить всё».';

  @override
  String get setClearDataTitle => 'Очистка данных';

  @override
  String get setClearDataContent =>
      'ВСЕ данные будут удалены:\n• Продажи, возвраты, платежи\n• Товары, категории, цены\n• Контрагенты, поставки\n• Заказы, смены, кассовые операции\n• Ресторанные столы, заказы\n• Сервисные заказы\n\nНастройки POS и пользователи сохранятся.\nЭто действие необратимо!';

  @override
  String get setClearDeleteAll => 'Удалить всё';

  @override
  String get setClearInProgress => 'Очистка данных...';

  @override
  String get setClearDone => 'Все данные очищены';

  @override
  String setGenericError(String error) {
    return 'Ошибка: $error';
  }

  @override
  String get setCorrectionTitle => 'Чек коррекции';

  @override
  String get setCorrectionIntro =>
      'Чек коррекции исправляет ранее пробитую или не пробитую сумму. Укажите причину и сумму. Если оператор не поддерживает коррекцию — это будет показано честно.';

  @override
  String get setCorrectionReasonLabel => 'Причина коррекции';

  @override
  String get setCorrectionReasonHint => 'напр. самостоятельная корректировка';

  @override
  String get setCorrectionAmountLabel => 'Сумма коррекции, KZT';

  @override
  String get setCorrectionPaymentLabel => 'Способ оплаты';

  @override
  String get setCorrectionCash => 'Наличные';

  @override
  String get setCorrectionCard => 'Карта';

  @override
  String get setCorrectionSubmit => 'Отправить чек коррекции';

  @override
  String get setCorrectionDefaultName => 'Коррекция';

  @override
  String get setCorrectionInvalidAmount =>
      'Введите корректную сумму коррекции (> 0)';

  @override
  String get setCorrectionQueued =>
      'Чек коррекции поставлен в очередь (offline)';

  @override
  String get setCorrectionSent => 'Чек коррекции отправлен';

  @override
  String get setCorrectionUnsupported =>
      'Чек коррекции не поддерживается текущим оператором';

  @override
  String get setCorrectionNotConfigured => 'Фискализация не настроена';

  @override
  String get setCorrectionError => 'Ошибка чека коррекции';

  @override
  String get setFiscalConnection => 'Подключение';

  @override
  String get setFiscalTestMode => 'Тестовый режим';

  @override
  String get setFiscalLogin => 'Логин';

  @override
  String get setFiscalLoginHint => 'email / телефон';

  @override
  String get setFiscalPassword => 'Пароль';

  @override
  String get setFiscalCashboxSerial => 'ЗНМ (серийный номер кассы)';

  @override
  String get setFiscalCashboxSerialHint => 'напр. SWK00033717';

  @override
  String get setFiscalRnm => 'РНМ (рег. номер машины)';

  @override
  String get setFiscalKeyPath => 'Путь к ключу/сертификату';

  @override
  String get setFiscalOfflineModule => 'Адрес offline-модуля';

  @override
  String get setFiscalVatRate => 'Ставка НДС, %';

  @override
  String get dishTabRecipe => 'Рецептура';

  @override
  String get dishTabCosting => 'Себестоимость';

  @override
  String get dishTabYield => 'Выход и КБЖУ';

  @override
  String get dishVersions => 'Версии';

  @override
  String get dishCostLabel => 'Себестоимость';

  @override
  String get dishPriceLabel => 'Цена';

  @override
  String get dishProfitLabel => 'Прибыль';

  @override
  String get dishMarkupLabel => 'Наценка';

  @override
  String get dishNoIngredients => 'Нет ингредиентов';

  @override
  String get dishNoIngredientsHint =>
      'Добавьте ингредиенты для расчёта рецептуры';

  @override
  String get dishAddIngredient => 'Добавить ингредиент';

  @override
  String get dishColIngredient => 'Ингредиент';

  @override
  String get dishColGross => 'Брутто';

  @override
  String get dishColColdLoss => 'Пот.обр.%';

  @override
  String get dishColNet => 'Нетто';

  @override
  String get dishColHotLoss => 'Пот.т/о%';

  @override
  String get dishColYield => 'Выход';

  @override
  String get dishColCost => 'Стоим.';

  @override
  String get dishDeleteIngredient => 'Удалить ингредиент';

  @override
  String get dishTotal => 'Итого';

  @override
  String get dishDeleteIngredientTitle => 'Удалить ингредиент?';

  @override
  String dishDeleteIngredientConfirm(String name) {
    return 'Удалить \"$name\" из рецептуры?';
  }

  @override
  String get dishSearchIngredientHint =>
      'Поиск ингредиента по названию или штрих-коду...';

  @override
  String dishCodeOnly(int code) {
    return 'Код: $code';
  }

  @override
  String dishCodeWithBarcode(int code, int barcode) {
    return 'Код: $code  |  Штрих-код: $barcode';
  }

  @override
  String dishAddTitle(String name) {
    return 'Добавить: $name';
  }

  @override
  String get dishGrossQty => 'Брутто (кол-во)';

  @override
  String get dishColdLossLabel => 'Потери обработки, %';

  @override
  String get dishHotLossLabel => 'Потери тепл. обработки, %';

  @override
  String get dishSeasonCoefficient => 'Сезонный коэффициент';

  @override
  String get dishSeasonStandard => 'Стандарт (x1.0)';

  @override
  String get dishSeasonWinter => 'Зима (+15%) (x1.15)';

  @override
  String get dishSeasonSummer => 'Лето (-5%) (x0.95)';

  @override
  String dishEffectiveColdLoss(String value) {
    return 'Эффект. потери обработки: $value%';
  }

  @override
  String dishTotalYieldSummary(String cost, String yield) {
    return 'Итого: $cost ₸  |  Выход: $yield';
  }

  @override
  String get dishGostNorms => 'ГОСТ нормы';

  @override
  String get dishGostNormsTitle => 'ГОСТ нормы потерь';

  @override
  String get dishSearchProductHint => 'Поиск продукта...';

  @override
  String get dishReferenceEmpty => 'Справочник пуст';

  @override
  String get dishGostNotLoaded => 'Данные ГОСТ норм ещё не загружены';

  @override
  String dishGostLossLine(String cold, String hot) {
    return 'Хол: $cold%  Тепл: $hot%';
  }

  @override
  String get dishPhotoSection => 'Фото блюда';

  @override
  String get dishMissingPricesWarning =>
      'Некоторые ингредиенты не имеют закупочной цены';

  @override
  String get dishProfitPerServing => 'Прибыль с порции';

  @override
  String get dishLossPerServing => 'Убыток с порции';

  @override
  String get dishCostOfDish => 'Себестоимость блюда';

  @override
  String get dishSellingPrice => 'Цена продажи';

  @override
  String get dishMargin => 'Маржа';

  @override
  String get dishNoPhoto => 'Нет фото';

  @override
  String get dishPhotoLoaded => 'Фото загружено';

  @override
  String get dishPhotoAddHint => 'Добавьте фото готового блюда';

  @override
  String get dishCamera => 'Камера';

  @override
  String get dishGallery => 'Галерея';

  @override
  String get dishPhotoLoadError => 'Не удалось загрузить фото';

  @override
  String get dishFoodCost => 'Фудкост';

  @override
  String get dishFoodCostExcellent => 'Отлично';

  @override
  String get dishFoodCostNormal => 'Нормально';

  @override
  String get dishFoodCostHigh => 'Высокий';

  @override
  String get dishServingsCount => 'Кол-во порций:';

  @override
  String get dishCostPerServing => 'Стоимость порции';

  @override
  String get dishPricePerServing => 'Цена порции';

  @override
  String get dishTotalYield => 'Общий выход';

  @override
  String get dishIngredientsCount => 'Ингредиентов';

  @override
  String get dishKbjuSection => 'Пищевая ценность (КБЖУ на 1 порцию)';

  @override
  String get dishKbjuEmpty => 'Данные КБЖУ не заполнены';

  @override
  String get dishKbjuCalories => 'Калории';

  @override
  String get dishKbjuProteins => 'Белки';

  @override
  String get dishKbjuFats => 'Жиры';

  @override
  String get dishKbjuCarbs => 'Углеводы';

  @override
  String dishKcalValue(String value) {
    return '$value ккал';
  }

  @override
  String dishGramValue(String value) {
    return '$value г';
  }

  @override
  String get dishVersionHistory => 'История изменений';

  @override
  String get dishNoVersions => 'Нет сохранённых версий';

  @override
  String dishVersionN(String version) {
    return 'Версия $version';
  }

  @override
  String get dishViewComposition => 'Просмотреть состав';

  @override
  String get dishRestoreThisVersion => 'Восстановить эту версию';

  @override
  String get dishSaveVersion => 'Сохранить версию';

  @override
  String dishVersionComposition(String version) {
    return 'Версия $version — состав';
  }

  @override
  String get dishSnapshotUnavailable => 'Снимок состава недоступен';

  @override
  String dishSnapshotIngredientLine(
    String gross,
    String cold,
    String hot,
    String yield,
  ) {
    return 'Брутто: $gross  |  Пот.обр.: $cold%  |  Пот.т/о: $hot%  |  Выход: $yield';
  }

  @override
  String get dishVersionNotRestorable =>
      'Эту версию нельзя восстановить (нет данных об ингредиентах), доступен только просмотр';

  @override
  String get dishRestoreVersionTitle => 'Восстановить версию?';

  @override
  String dishRestoreVersionConfirm(String version) {
    return 'Текущая рецептура будет заменена составом версии $version. Продолжить?';
  }

  @override
  String get dishRestore => 'Восстановить';

  @override
  String dishVersionRestored(String version) {
    return 'Восстановлена версия $version';
  }

  @override
  String get dishRestoreError => 'Не удалось восстановить версию';

  @override
  String dishVersionSummary(int count, String cost) {
    return 'Ингредиентов: $count, себестоимость: $cost';
  }

  @override
  String get dishSaveVersionError => 'Не удалось сохранить версию рецепта';

  @override
  String get prodBarcodeAutoHint => 'Авто';

  @override
  String get prodCatalogAttributes => 'Каталожные атрибуты';

  @override
  String get prodBrand => 'Бренд';

  @override
  String get prodManufacturer => 'Производитель';

  @override
  String get prodCountryOfOrigin => 'Страна происхождения';

  @override
  String get prodFiscalAttributes => 'Фискальные атрибуты';

  @override
  String get prodVatRate => 'Ставка НДС';

  @override
  String get prodVatNone => 'Без НДС';

  @override
  String get prodNtin => 'НКТ (НТИН)';

  @override
  String get prodMarkable => 'Подлежит маркировке';

  @override
  String get promoTitle => 'Акции';

  @override
  String get promoSubtitle => 'Акции 1+1 и подарки за покупку';

  @override
  String get promoNew => 'Новая акция';

  @override
  String promoError(String error) {
    return 'Ошибка: $error';
  }

  @override
  String get promoEmpty => 'Нет акций';

  @override
  String get promoEmptyHint => 'Создайте акцию 1+1 или Подарок';

  @override
  String get promoTypeGift => 'Подарок';

  @override
  String promoBuyGetFree(int trigger, int reward) {
    return 'купи $trigger → $reward бесплатно';
  }

  @override
  String get promoDefaultName11 => 'Акция 1+1';

  @override
  String get promoNameLabel => 'Название';

  @override
  String get promoTriggerLabel => 'Товар-триггер (что купить)';

  @override
  String get promoRewardLabel => 'Подарок (что бесплатно)';

  @override
  String get promoSaveButton => 'Сохранить акцию';

  @override
  String get saleWeighingPlaceItem => 'Взвешивание... поместите товар на весы';

  @override
  String get saleWeightReadFailed => 'Не удалось считать вес — введите вручную';

  @override
  String get salePriceLabelSent => 'Ценник отправлен на печать';

  @override
  String get transPrimary => 'Основной';

  @override
  String get transSecondary => 'Резервный';

  @override
  String get transStatusOnline => 'В сети';

  @override
  String get transStatusOffline => 'Не в сети';

  @override
  String get transStatusSyncing => 'Синхронизация';

  @override
  String get transStatusQueued => 'В очереди';

  @override
  String get transStatusWarning => 'Предупреждение';

  @override
  String get transStatusError => 'Ошибка';

  @override
  String transQueuedCount(int count) {
    return '$count в очереди';
  }

  @override
  String transFailedCount(int count) {
    return '$count с ошибкой';
  }

  @override
  String transLastSyncAgo(String ago) {
    return 'Последняя синхронизация: $ago назад';
  }

  @override
  String get transSyncing => 'Синхронизация...';

  @override
  String get transSyncNow => 'Синхронизировать';

  @override
  String get transRetryFailed => 'Повторить неудавшиеся';

  @override
  String get restTips => 'Чаевые';

  @override
  String get restNoTips => 'Без чаевых';

  @override
  String get svcPendingApproval => 'Ожидает согласования';

  @override
  String get svcApprove => 'Согласовать';

  @override
  String get svcReject => 'Отклонить';

  @override
  String get svcRejected => 'Отклонено';

  @override
  String get svcQr => 'QR';

  @override
  String get catCollapse => 'Свернуть';

  @override
  String get repError => 'Ошибка';

  @override
  String get repNoData => 'Нет данных';

  @override
  String get repNoDataForPeriod => 'Нет данных за выбранный период';

  @override
  String get repKpiLoadError => 'Ошибка загрузки KPI';

  @override
  String get repColIndicator => 'Показатель';

  @override
  String get repColCount => 'Кол-во';

  @override
  String get repColSumTenge => 'Сумма, ₸';

  @override
  String get repColRow => 'Строка';

  @override
  String get repColTurnoverExclVat => 'Оборот (без НДС)';

  @override
  String get repColVat => 'НДС';

  @override
  String get repColDate => 'Дата';

  @override
  String get repColOperation => 'Операция';

  @override
  String get repColIncome => 'Приход';

  @override
  String get repColExpense => 'Расход';

  @override
  String get repColBalance => 'Остаток';

  @override
  String get repColRate => 'Ставка';

  @override
  String get repColGross => 'Брутто';

  @override
  String get repColNet => 'Нетто';

  @override
  String get repNoVat => 'Без НДС';

  @override
  String get repColCounterparty => 'Контрагент';

  @override
  String get repColType => 'Тип';

  @override
  String get repColSaldo => 'Сальдо';

  @override
  String get repDebtor => 'Дебитор';

  @override
  String get repCreditor => 'Кредитор';

  @override
  String get repColAccount => 'Счёт';

  @override
  String get repColCashier => 'Кассир';

  @override
  String get repColAmount => 'Сумма';

  @override
  String get repColProduct => 'Товар';

  @override
  String get repColRevenue => 'Выручка';

  @override
  String get repColCogs => 'Себест.';

  @override
  String get repColProfit => 'Прибыль';

  @override
  String get repColMarginPct => 'Маржа %';

  @override
  String get repColReason => 'Причина';

  @override
  String get repColDocuments => 'Документов';

  @override
  String get repColCostShort => 'Себест.';

  @override
  String get repF910Title => 'ф.910 — Доход (упрощёнка)';

  @override
  String repF910Subtitle(String income, String rate, String tax) {
    return 'Облагаемый доход: $income ₸ • налог $rate%: $tax ₸';
  }

  @override
  String get repF910RowSalesIncome => 'Доход с продаж';

  @override
  String get repF910RowRefunds => 'Возвраты (минус)';

  @override
  String get repF910RowTaxableIncome => 'Облагаемый доход';

  @override
  String get repF300Title => 'ф.300 — НДС (декларация)';

  @override
  String repF300Subtitle(String turnover, String vat) {
    return 'Облагаемый оборот: $turnover ₸ • начисленный НДС: $vat ₸';
  }

  @override
  String repF300TaxableTurnoverRate(String rate) {
    return 'Облагаемый оборот $rate%';
  }

  @override
  String get repF300ZeroRatedTurnover => 'Необлагаемый / 0% оборот';

  @override
  String get repCashBookTitle => 'Кассовая книга (КО-4)';

  @override
  String repCashBookSubtitle(String income, String expense, String balance) {
    return 'Приход: $income • Расход: $expense • Остаток: $balance ₸';
  }

  @override
  String get repVatPeriodTitle => 'НДС за период';

  @override
  String repVatPeriodSubtitle(String vat, String base) {
    return 'НДС: $vat ₸ • база: $base ₸';
  }

  @override
  String get repArApTitle => 'Дебиторка / Кредиторка';

  @override
  String repArApSubtitle(String receivable, String payable, String saldo) {
    return 'Дебиторка: $receivable • Кредиторка: $payable • Сальдо: $saldo';
  }

  @override
  String get repCashCollectionTitle => 'Инкассация';

  @override
  String repCashCollectionSubtitle(int count, String total) {
    return '$count операций • всего: $total ₸';
  }

  @override
  String get repProfitCogsTitle => 'Прибыль / Маржа (COGS)';

  @override
  String get repProfitMarginTitle => 'Прибыль / Маржа';

  @override
  String repProfitMarginSubtitle(String profit, String margin, String note) {
    return 'Прибыль: $profit ₸ • маржа $margin% • $note';
  }

  @override
  String get repProfitCostRealCogs => 'себестоимость: реальный COGS';

  @override
  String get repProfitCostWholesale =>
      'себестоимость: оптовая цена (нет CalculateCogsUseCase)';

  @override
  String get repWriteoffTitle => 'Списания';

  @override
  String repWriteoffSubtitle(int count, String total) {
    return '$count документов • всего: $total ₸';
  }

  @override
  String get repOrderTypesTitle => 'Типы заказов';

  @override
  String get repOrderTypesSubtitle => 'распределение по типу обслуживания';

  @override
  String get repTableTurnoverTitle => 'Оборот столов';

  @override
  String get repTableTurnoverSubtitle => 'посадок за период (топ-10)';

  @override
  String get repDishPopularityTitle => 'Популярность блюд';

  @override
  String get repDishPopularitySubtitle => 'топ-10 по количеству продаж';

  @override
  String get repFoodCostAnalysisShort => 'Анализ себестоимости';

  @override
  String get repFoodCostAnalysisTitle => 'Анализ себестоимости (Food Cost)';

  @override
  String get repFoodCostAnalysisSubtitle =>
      'зеленый <30%, желтый 30-40%, красный >40%';

  @override
  String get repColDish => 'Блюдо';

  @override
  String get repColFoodCostPct => 'Food Cost %';

  @override
  String get repTipsByWaiterTitle => 'Чаевые по официантам';

  @override
  String get repTipsByWaiterSubtitle => 'сортировка по сумме чаевых';

  @override
  String get repColWaiter => 'Официант';

  @override
  String get repColOrders => 'Заказы';

  @override
  String get repColTips => 'Чаевые';

  @override
  String get repColTipsPct => 'Чаевые %';

  @override
  String get repKpiRestaurantRevenue => 'Выручка ресторана';

  @override
  String get repKpiOrders => 'Заказы';

  @override
  String get repKpiAvgCheck => 'Средний чек';

  @override
  String get repKpiTips => 'Чаевые';

  @override
  String get repKpiRevenue => 'Выручка';

  @override
  String get repKpiExpenses => 'Расходы';

  @override
  String get repKpiRefunds => 'Возвраты';

  @override
  String get repKpiSales => 'Продажи';

  @override
  String get repSubtitleForPeriod => 'за период';

  @override
  String get repSubtitleTotal => 'всего';

  @override
  String get repSubtitleCashExpenses => 'кассовые расходы';

  @override
  String get repSubtitleRefundTotal => 'сумма возвратов';

  @override
  String get repSubtitleReceipts => 'чеков';

  @override
  String get repCashFlowTitle => 'Денежный поток по дням';

  @override
  String get repCashFlowInvestments => 'Вложения';

  @override
  String get repCashFlowExpenses => 'Расходы';

  @override
  String get repCashFlowDividends => 'Дивиденды';

  @override
  String repDaysCount(int count) {
    return '$count дней';
  }

  @override
  String get repTopProfitableTitle => 'Топ-10 прибыльных товаров';

  @override
  String get repTopProfitableSubtitle => 'по абсолютной прибыли';

  @override
  String get repProductProfitTitle => 'Рентабельность товаров';

  @override
  String get repProductProfitSubtitle => 'топ-20 по прибыли';

  @override
  String get repRefundTrendTitle => 'Тренд возвратов';

  @override
  String get repSupplierVolumeTitle => 'Поставки по поставщикам';

  @override
  String repSuppliersCount(int count) {
    return '$count поставщиков';
  }

  @override
  String get repSupplierTableTitle => 'Таблица поставщиков';

  @override
  String get repSupplierTableSubtitle => 'сортировка по количеству поставок';

  @override
  String get repColSupplier => 'Поставщик';

  @override
  String get repColSupplyCount => 'Кол-во поставок';

  @override
  String get repPriceTrendTitle => 'Динамика закупочных цен';

  @override
  String get repPriceTrendSubtitle => 'топ-5 товаров по количеству поставок';

  @override
  String get repNotEnoughDataForChart => 'Недостаточно данных для графика';

  @override
  String get repPriceChangesShort => 'Изменения цен';

  @override
  String get repPriceChangesTitle => 'Изменения цен поставщиков';

  @override
  String get repPriceChangesSubtitle => 'последние изменения закупочных цен';

  @override
  String get repColWas => 'Было';

  @override
  String get repColBecame => 'Стало';

  @override
  String get repColChangePctShort => 'Изм. %';

  @override
  String get repNoSupplierData => 'Нет данных о поставщиках';

  @override
  String get repNoSuppliesForPeriod =>
      'За выбранный период поставки не найдены';

  @override
  String get navWmsDashboard => 'Склад WMS';

  @override
  String get navWmsWarehouses => 'Склады';

  @override
  String get navWmsBatches => 'Партии';

  @override
  String get navWmsSerials => 'Серии';

  @override
  String get navWmsCellStock => 'Ячейки';

  @override
  String get navWmsClaims => 'Рекламации';

  @override
  String get navWmsMarking => 'Маркировка';

  @override
  String get navWmsSettings => 'Настройки WMS';

  @override
  String errorInsufficientStock(String name) {
    return 'Недостаточно остатка: $name';
  }

  @override
  String get discountLimitsTitle => 'Пределы скидки';

  @override
  String get discountLimitsSubtitle => 'Сколько кассир может уступить вручную';

  @override
  String get discountLimitsIntro =>
      'Предел роли перекрывает умолчание. У роли без своей строки действует «По умолчанию». Сто процентов означает «без предела» — это объявленное значение, а не пустота.';

  @override
  String get discountLimitsDefaultRow => 'По умолчанию (все роли)';

  @override
  String get discountLimitsMaxPercent => 'Предел, %';

  @override
  String get discountLimitsApprovalAbove => 'Подтверждение выше, %';

  @override
  String get discountLimitsApprovalHint => 'пусто — не требуется';

  @override
  String get discountLimitsInheritHint => 'пусто — как по умолчанию';

  @override
  String get discountLimitsTwoDoors =>
      'Внимание: «запретить снижение цены» в политике продаж закрывает только правку цены строки. Скидка при пределе 100 % по-прежнему разрешена — вплоть до строки бесплатно. Это две разные двери; чтобы закрыть вторую, поставьте предел ниже ста.';

  @override
  String get discountLimitsSaved => 'Предел сохранён';

  @override
  String get discountLimitsInherited =>
      'Строка снята: роль наследует умолчание';

  @override
  String get discountLimitsInvalid => 'Предел — число от 0 до 100';

  @override
  String get discountLimitsApprovalNotYet =>
      'Подтверждение старшего пока не реализовано: скидка выше порога отклоняется с названной причиной, а не открывает ввод кода.';

  @override
  String errorDeniedPolicy(String detail) {
    return 'Запрещено настройками кассы: $detail';
  }

  @override
  String errorDeniedLimit(String detail) {
    return 'Скидка больше разрешённой: $detail';
  }

  @override
  String errorApprovalRequired(String detail) {
    return 'Нужно подтверждение старшего: $detail';
  }

  @override
  String get errorBigAmountBlocked =>
      'Сумма продажи превышает 1 млн ₸. Включите разрешение на крупные суммы в настройках кассы.';

  @override
  String errorMarkRequired(String name) {
    return 'Требуется код маркировки: $name';
  }

  @override
  String get errorOrderNotFound => 'Заказ не найден';

  @override
  String get errorSerialNotFound => 'Серийный номер не найден';

  @override
  String get errorReceiptFailedPrint => 'Не удалось напечатать чек';

  @override
  String get errorDeleteFailed => 'Не удалось удалить';

  @override
  String get errorCancelFailed => 'Не удалось отменить';

  @override
  String get errorShiftZreportFailed => 'Ошибка Z-отчёта';

  @override
  String get errorTransitionFailed => 'Не удалось изменить статус';

  @override
  String get logJournalTitle => 'Журнал работы';

  @override
  String get logJournalOpen => 'Открыть журнал';

  @override
  String get logJournalCardDesc =>
      'Файловый журнал работы по датам: выгрузка на флешку, очистка';

  @override
  String get logJournalEmpty => 'Журнал пуст';

  @override
  String get logJournalPickFolder => 'Выберите папку (флешку) для выгрузки';

  @override
  String get logJournalExport => 'Скачать на флешку';

  @override
  String logJournalExported(int count, String dir) {
    return 'Выгружено $count файлов в $dir';
  }

  @override
  String logJournalSummary(int count, String size) {
    return 'Файлов: $count, всего $size';
  }

  @override
  String get logJournalDeleteOld => 'Старше 7 дней';

  @override
  String logJournalDeletedOld(int count) {
    return 'Удалено файлов: $count';
  }

  @override
  String get logJournalDeleteAllTitle => 'Удалить все журналы?';

  @override
  String get logJournalDeleteAllConfirm =>
      'Будут удалены все файлы журнала, кроме сегодняшнего. Действие необратимо.';

  @override
  String get setUserTabPin => 'PIN';

  @override
  String get setUserPinChange => 'Сменить PIN';

  @override
  String get setUserPinSetHint =>
      'Задайте PIN-код (4–6 цифр) для входа пользователя';

  @override
  String get setUserPinKeepHint =>
      'Оставьте пустым, чтобы не менять текущий PIN';

  @override
  String get setUserPinNew => 'Новый PIN';

  @override
  String get receiptInputRecent => 'Последние чеки';

  @override
  String get receiptInputNoRecent => 'Чеков пока нет';

  @override
  String get receiptInputRecentUnavailable =>
      'Список последних чеков на этом терминале недоступен — введите номер чека вручную';

  @override
  String get shiftHistoryTitle => 'История смен';

  @override
  String get shiftHistoryEmpty => 'Закрытых смен пока нет';

  @override
  String shiftHistoryShiftNo(int id) {
    return 'Смена №$id';
  }

  @override
  String get shiftHistorySales => 'Продажи';

  @override
  String get shiftHistoryRefunds => 'Возвраты';

  @override
  String get shiftHistoryOpeningCash => 'Разменный';

  @override
  String saleExpiredBatchWarning(String name) {
    return 'Внимание: у товара «$name» истёк срок годности партии';
  }

  @override
  String get setPolicyEditProduct => 'Разрешить редактирование товаров';

  @override
  String get setPolicyEditProductDesc =>
      'Кассир может изменять карточки товаров в каталоге';

  @override
  String get setPolicyEditPrice => 'Разрешить изменение цены в продаже';

  @override
  String get setPolicyEditPriceDesc =>
      'Кассир может вручную менять цену позиции в чеке';

  @override
  String get setPolicyDiscounts => 'Разрешить скидки';

  @override
  String get setPolicyDiscountsDesc =>
      'Кассир может применять скидки к позициям чека';

  @override
  String get setPolicyCashInOut => 'Разрешить внесение/изъятие наличных';

  @override
  String get setPolicyCashInOutDesc =>
      'Кассир может вносить и изымать наличные из кассы';

  @override
  String get setPolicyBigAmount => 'Разрешить крупные суммы (>1 млн)';

  @override
  String get setPolicyBigAmountDesc =>
      'Снять ограничение в 1 000 000 на операции';

  @override
  String get setPolicyBlockPriceDecrease =>
      'Запретить снижение цены ниже карточки';

  @override
  String get setPolicyBlockPriceDecreaseDesc =>
      'Цену в чеке нельзя установить ниже цены товара';

  @override
  String get printerAutoDetect => 'Найти принтер';

  @override
  String get printerAutoDetecting => 'Поиск принтера…';

  @override
  String printerFound(String device) {
    return 'Найдено: $device';
  }

  @override
  String printerFoundWithNote(String device, String note) {
    return 'Найдено: $device — $note';
  }

  @override
  String get printerNotFoundAnyPort =>
      'Принтер не найден ни на одном порту (USB/serial). Проверьте кабель и питание.';

  @override
  String get printerUsbName => 'USB-принтер';

  @override
  String get printerSelectDevice => 'Выберите принтер';

  @override
  String get printerNoAccessGroupLp =>
      'Узел найден, но нет прав (нужна группа lp)';

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
      'Узел найден, но нет прав (нужна группа lp): usermod -aG lp telepos и перезапуск сессии.';

  @override
  String printerRawOpenNoPermsHint(String path) {
    return 'Узел $path найден, но открыть нельзя — нет прав. Добавьте пользователя в группу lp (usermod -aG lp telepos) и перезапустите сессию/приставку.';
  }

  @override
  String get printerNotFoundNoNode =>
      'Принтер не найден: нет ни одного char-узла /dev/usb/lp* и USB-serial порта. Проверьте кабель и питание принтера.';

  @override
  String get ownerOnlyTitle => 'Доступно только владельцу кассы';

  @override
  String get ownerOnlyDesc =>
      'Системные операции (перезагрузка, сброс, драйверы, терминал) доступны только под учётной записью владельца.';

  @override
  String get telegramApiSectionTitle => 'Приложение Telegram';

  @override
  String get telegramApiSectionDesc =>
      'TelePOS не поставляется с ключами Telegram. Зарегистрируйте приложение на my.telegram.org и введите пару ниже — либо передайте её при сборке через --dart-define.';

  @override
  String get telegramApiIdLabel => 'api_id';

  @override
  String get telegramApiHashLabel => 'api_hash';

  @override
  String get telegramApiSave => 'Сохранить ключи';

  @override
  String get telegramApiClear => 'Удалить ключи';

  @override
  String get telegramApiSaved => 'Ключи Telegram сохранены';

  @override
  String get telegramApiCleared => 'Ключи Telegram удалены';

  @override
  String get telegramApiInvalid =>
      'Укажите числовой api_id и непустой api_hash';

  @override
  String get telegramApiStatusConfigured => 'Ключи заданы';

  @override
  String get telegramApiStatusMissing => 'Ключи не заданы';

  @override
  String get deviceSearchButton => 'Искать';

  @override
  String get deviceSearchTitle => 'Найденные устройства';

  @override
  String get deviceSearchRunning => 'Идёт поиск…';

  @override
  String get deviceSearchEmpty =>
      'Ничего не найдено. Все источники опрошены — устройство не подключено или выключено.';

  @override
  String get deviceSearchNoValueForField =>
      'Устройства найдены, но ни одно не даёт значения для этого поля.';

  @override
  String deviceSearchFailedSources(String sources) {
    return 'Не удалось выполнить поиск: $sources. Это не то же самое, что «ничего не подключено».';
  }

  @override
  String get deviceSearchUnavailable =>
      'Поиск устройств недоступен в этой сборке.';

  @override
  String deviceSearchFieldFilled(String value) {
    return 'Поле заполнено: $value';
  }

  @override
  String get deviceSourceSerialPort => 'Последовательный порт';

  @override
  String get deviceSourceUsb => 'USB';

  @override
  String get deviceSourceNetwork => 'Сеть';

  @override
  String get deviceSourceBluetooth => 'Bluetooth';

  @override
  String get deviceCheckButton => 'Проверить устройство';

  @override
  String get deviceCheckRunning => 'Проверка…';

  @override
  String get deviceCheckUnavailable =>
      'Проверка устройств недоступна в этой сборке.';

  @override
  String get deviceCheckSavedBindingNotice =>
      'Проверяется сохранённая привязка: устройство опрашивается по записанным параметрам, а не по несохранённым изменениям на этом экране. Чтобы новая привязка заработала в продажах, перезапустите приложение.';

  @override
  String get deviceCheckReasonOk => 'Устройство ответило';

  @override
  String get deviceCheckReasonNotConfigured => 'Устройство не настроено';

  @override
  String get deviceCheckReasonInvalidBinding => 'Привязка некорректна';

  @override
  String get deviceCheckReasonDriverNotLive =>
      'Привязка сохранена, но эта сборка не может работать с этим устройством';

  @override
  String get deviceCheckReasonConnectionFailed => 'Устройство не отвечает';

  @override
  String get deviceCheckReasonDeviceRefused => 'Устройство отказало в операции';

  @override
  String get deviceCheckReasonNotSupportedOnPlatform =>
      'Не поддерживается на этой платформе';

  @override
  String get deviceCheckReasonNotImplemented =>
      'Проверка для этого класса ещё не реализована';

  @override
  String get deviceCheckReasonUnexpectedError => 'Непредвиденная ошибка';

  @override
  String get scannerRulesTitle => 'Правила чтения штрихкода';

  @override
  String get scannerRulesSubtitle =>
      'Не свойства сканера, а правила установки: какое прочитанное значение принять.';

  @override
  String get scannerRulesMinLength => 'Минимальная длина штрихкода';

  @override
  String get scannerRulesMaxLength => 'Максимальная длина штрихкода';

  @override
  String get scannerRulesTimeoutMs => 'Промежуток между символами сканера, мс';

  @override
  String scannerRulesDefaultHint(String value) {
    return 'Пусто — по умолчанию $value';
  }

  @override
  String scannerRulesNotAnInteger(String value) {
    return 'Значение «$value» — не целое число';
  }

  @override
  String get scannerRulesSaved => 'Правила чтения штрихкода сохранены';

  @override
  String get printQueueSectionTitle => 'Очередь печати';

  @override
  String get printQueueSubtitle =>
      'Что ждёт печати, что не напечаталось и почему.';

  @override
  String get printQueueEmpty => 'Очередь пуста — непечатанных чеков нет.';

  @override
  String get printQueueUnavailable =>
      'Очередь печати недоступна в этой сборке.';

  @override
  String get printQueueUnreadable => 'Очередь печати не читается';

  @override
  String get printQueueUnreadableHint =>
      'Это не пустая очередь: задания могут ждать печати, но список прочитать нельзя. Требуется обслуживание.';

  @override
  String get printQueueStateQueued => 'Ждёт печати';

  @override
  String get printQueueStatePrinting => 'Печатается';

  @override
  String get printQueueStatePrinted => 'Напечатано';

  @override
  String get printQueueStateFailed => 'Не напечаталось, будет повторено';

  @override
  String get printQueueStateExpired => 'Срок вышел, само повторяться не будет';

  @override
  String get printQueueStateCancelled => 'Отменено оператором';

  @override
  String printQueueAttempts(int count) {
    return 'Попыток: $count';
  }

  @override
  String printQueueDeadline(String moment) {
    return 'Срок до $moment';
  }

  @override
  String printQueueReason(String reason) {
    return 'Причина: $reason';
  }

  @override
  String get printQueueRetry => 'Повторить';

  @override
  String get printQueueCancelJob => 'Отменить задание';

  @override
  String get printQueueExtendTitle => 'На сколько продлить задание?';

  @override
  String get printQueueExtend5Minutes => 'Ещё 5 минут';

  @override
  String get printQueueExtend30Minutes => 'Ещё 30 минут';

  @override
  String get printQueueExtend2Hours => 'Ещё 2 часа';

  @override
  String get printQueueRetryAccepted => 'Задание снова в очереди';

  @override
  String get printQueueRetryAlreadyPrinted =>
      'Этот чек уже напечатан — второй раз он не печатается';

  @override
  String get printQueueRetryRejected => 'Повторить не удалось';

  @override
  String get printQueueCancelTitle => 'Отменить задание?';

  @override
  String get printQueueCancelBody =>
      'Отменённое задание напечатать уже нельзя. Если такой же чек всё-таки нужен, его придётся выбить заново.';

  @override
  String get printQueueCancelConfirm => 'Отменить задание';

  @override
  String get printQueueCancelDone => 'Задание отменено';

  @override
  String get printQueueCancelRefused =>
      'Это задание отменить уже нельзя: оно печатается или уже завершено';

  @override
  String get errorPayReceiptNotFound =>
      'Чек больше не в работе — оплатить его нельзя. Обновите экран и начните заново.';

  @override
  String get errorPayNotOwner =>
      'Этот чек ведёт другое рабочее место — оплатить его отсюда нельзя.';

  @override
  String get errorPaymentAlreadyTaken =>
      'Этот чек уже оплачен. Взять деньги второй раз касса не станет.';

  @override
  String get errorPaymentInsufficient =>
      'Названной суммы не хватает на чек. Назовите сумму заново.';

  @override
  String get errorPaymentAccountMissing =>
      'У кассы нет счёта для этого вида оплаты. Обратитесь к администратору.';

  @override
  String get errorPaymentAccountNotAllowed =>
      'Такой счёт для оплаты не предлагался. Обновите список счетов и выберите заново.';

  @override
  String get errorPaymentUnbalanced =>
      'Сумма строк оплаты не сходится с суммой чека. Наберите оплату заново.';

  @override
  String get errorPaymentKindInactive =>
      'Этот вид оплаты выключен в настройках кассы. Выберите другой или включите его в настройках.';

  @override
  String get errorPaymentKindUnknown =>
      'Касса не знает такого вида оплаты. Обратитесь к администратору.';

  @override
  String get errorCertificateUnknown =>
      'Сертификата с таким номером на этой кассе нет. Проверьте номер.';

  @override
  String get errorCertificatePinWrong =>
      'ПИН сертификата не подошёл. Наберите его заново.';

  @override
  String get errorCertificateRateLimited =>
      'Слишком много неудачных проверок сертификата. Подождите несколько минут и повторите.';

  @override
  String get errorConnectionLost =>
      'Связь с кассой потеряна. Проверьте сеть и повторите.';

  @override
  String get errorRunIncomplete =>
      'Касса прервала операцию, не завершив её. Проверьте на кассе результат, прежде чем повторять.';

  @override
  String get errorWireMismatch =>
      'Рабочее место и касса не поняли друг друга — версии разошлись. Обновите страницу; если не поможет, обратитесь к администратору.';

  @override
  String get errorTillFailed =>
      'Касса не смогла выполнить операцию. Повторите; если ошибка повторится, обратитесь к администратору.';

  @override
  String get errorTerminalChanged =>
      'Вы сменили рабочее место — войдите снова.';

  @override
  String get errorUnknownTerminal =>
      'Рабочее место не привязано к кассе. Привяжите его заново кодом привязки.';

  @override
  String get errorAlreadyConfigured =>
      'Касса уже настроена — мастер первичной настройки больше недоступен.';

  @override
  String get errorCannotDeleteSelf =>
      'Нельзя удалить рабочее место самой кассы.';

  @override
  String get errorNoDrivers =>
      'Касса собрана без драйверов оборудования — поиск и проверка устройств недоступны. Обратитесь к администратору.';

  @override
  String get errorNoNetworkModule =>
      'Эта касса не управляет сетевыми настройками — нет системной службы. Обратитесь к администратору.';

  @override
  String get errorNoSessionRegistry =>
      'Эта касса не ведёт список сеансов. Обратитесь к администратору.';

  @override
  String get errorNoBackupTransport =>
      'Резервные копии на этой кассе не настроены. Обратитесь к администратору.';

  @override
  String get errorBackupNotFound => 'Резервная копия не найдена.';

  @override
  String get errorCertificatesUnavailable =>
      'Эта касса не выпускает подарочные сертификаты по проводу. Обратитесь к администратору.';

  @override
  String get errorRefundStale =>
      'Возврат изменился, пока команда шла на кассу. Повторите действие.';

  @override
  String get errorRefundWrongDraft =>
      'Этого черновика возврата больше нет. Откройте возврат заново.';

  @override
  String get errorRefundNotStarted =>
      'Возврат не начат — выберите чек или начните возврат без чека.';

  @override
  String get errorRefundEmpty =>
      'В возврате нет ни одной строки — возвращать нечего.';

  @override
  String get errorReceiptAlreadyRefunded => 'По этому чеку возврат уже сделан.';

  @override
  String get errorReceiptNotRefundable =>
      'Этот чек нельзя вернуть здесь: оплата прошла через терминал другой кассы. Оформите возврат там, где платили.';

  @override
  String get errorLineNotInReceipt =>
      'Этого товара нет в чеке — по чеку возвращается только проданное в нём.';

  @override
  String get errorSaleNotCompleted =>
      'Продажа по этому чеку не завершена — возвращать нечего.';

  @override
  String get errorRefundBusy =>
      'На кассе уже идёт другой возврат. Завершите его и повторите.';

  @override
  String get errorRefundCannotStart =>
      'Касса не смогла начать возврат и не назвала причину. Проверьте смену и настройку кассы.';

  @override
  String get errorRefundInstallmentRefused =>
      'Чек продан в рассрочку — касса его не возвращает. Расторжение договора оформляет администратор.';

  @override
  String get errorRefundCashlessUnavailable =>
      'Эти деньги надо вернуть на карту или через QR, а вернуть их нечем: терминал или провайдер не подключён. Наличными из ящика касса такой возврат не выдаёт.';

  @override
  String get errorRefundCashlessRefused =>
      'Банк или провайдер отказал в возврате. Проверьте терминал и повторите — уже возвращённое второй раз не вернётся.';

  @override
  String get errorRefundKindNotRefundable =>
      'На этот вид оплаты возврат запрещён в справочнике видов оплаты.';

  @override
  String get errorRefundKindUnknown =>
      'Чек оплачен видом оплаты, которого нет в справочнике этой кассы. Возврат по нему касса не проводит: чем платили — неизвестно, а наличными за это не выдают.';

  @override
  String get refundDestinationsTitle => 'Куда уйдут деньги';

  @override
  String get refundRouteDrawer => 'Наличными из ящика';

  @override
  String get refundRouteCard => 'На карту через терминал';

  @override
  String get refundRouteManual => 'Вне кассы — тем же способом, каким платили';

  @override
  String get refundRouteProvider => 'Через провайдера QR';

  @override
  String get refundRouteCertificate =>
      'Новым сертификатом (старый остаётся погашенным)';

  @override
  String get refundRouteAdvance => 'В аванс покупателя';

  @override
  String get refundRouteBonus => 'На бонусный счёт';

  @override
  String get refundRouteDebt => 'В счёт долга покупателя';

  @override
  String get errorCertificateRefundNoSource =>
      'Строка чека возвращается сертификатом, но номера сертификата у неё нет. Возврат по ней касса не проводит: новую бумажку выписать не от чего, а обязательство кассы выросло бы впустую.';

  @override
  String get errorCertificateCashRefundRefused =>
      'Наличными за сертификат вернуть нельзя — укажите реквизиты для безналичного возврата.';

  @override
  String get errorCertificatePaysCertificate =>
      'Сертификатом нельзя оплатить покупку другого сертификата.';

  @override
  String get errorCreditContractUnknown =>
      'Договора рассрочки с таким номером нет. Проверьте номер.';

  @override
  String get errorCreditContractNotActive =>
      'Договор рассрочки уже погашен или отозван — платить по нему не за что.';

  @override
  String get errorCreditOverpayment =>
      'Сумма больше остатка по договору. Проверьте сумму.';

  @override
  String get errorCreditRepaymentInvalid =>
      'Сумма погашения должна быть больше нуля.';

  @override
  String get errorCreditAllocationRace =>
      'По договору в ту же секунду заплатили с другой кассы. Примите платёж заново.';

  @override
  String get errorKindTenderCannotDiscount =>
      'Вид, приносящий живые деньги, нельзя объявить в чеке «не платежом».';

  @override
  String get errorKindAccountMissing =>
      'Виду оплаты не назначен счёт-получатель.';

  @override
  String get errorKindCounterpartyRequired =>
      'Отложенный вид оплаты требует названного покупателя.';

  @override
  String get errorKindProviderRequired =>
      'Виду оплаты через провайдера (QR) нужен провайдер.';

  @override
  String get errorKindFiscalKindRequired =>
      'У вида оплаты не указана фискальная трактовка.';

  @override
  String get errorKindChangeNotATender =>
      'Сдачу выдаёт только вид, приносящий живые деньги.';

  @override
  String get errorKindSystemImmutable =>
      'Код или идентификатор системного вида оплаты нельзя менять и нельзя занимать другим видом.';

  @override
  String get errorCertificateExpired =>
      'Срок действия сертификата истёк. Обратитесь к владельцу магазина.';

  @override
  String get errorCertificateExhausted => 'На сертификате не осталось средств.';

  @override
  String get errorCertificateDuplicate =>
      'Один и тот же сертификат назван в оплате дважды. Уберите повтор.';

  @override
  String get errorCertificateRace =>
      'Остаток сертификата изменился. Повторите оплату.';

  @override
  String get errorCertificateAccountMissing =>
      'У кассы нет счёта обязательств по сертификатам. Обратитесь к администратору.';

  @override
  String get errorCertificateNumberTaken =>
      'Сертификат с таким номером уже выпущен.';

  @override
  String get errorCertificateNominalInvalid =>
      'Номинал сертификата должен быть больше нуля.';

  @override
  String get errorDebtCustomerRequired =>
      'Продажа в долг без покупателя невозможна — выберите покупателя.';

  @override
  String get errorDebtNotSoldHere =>
      'На этой кассе не торгуют в долг — продажа в кредит выключена в настройках кассы.';

  @override
  String get errorDebtAccountMissing =>
      'У покупателя нет расчётного счёта — долг записать некуда.';

  @override
  String get errorBonusAccountMissing =>
      'У покупателя нет бонусного счёта — списать бонус нечем.';

  @override
  String get errorPrepaymentCustomerRequired =>
      'Зачёт аванса требует покупателя — выберите его.';

  @override
  String get errorCreditTermInvalid =>
      'Такой срок рассрочки касса не оформляет';

  @override
  String get errorCreditPrincipalInvalid =>
      'Рассрочку не на что оформлять: чек покрыт целиком';

  @override
  String get errorCreditFeeInvalid => 'Надбавка по договору задана неверно';

  @override
  String get errorCreditSchemeUnknown => 'Такой схемы графика касса не знает';

  @override
  String get errorCreditOverdue =>
      'У покупателя просрочен другой договор рассрочки';

  @override
  String get errorCreditContractDuplicate =>
      'На этот чек уже оформлен договор рассрочки';

  @override
  String get errorPrepaymentAccountMissing =>
      'У покупателя нет расчётного счёта — аванса на нём быть не может.';

  @override
  String get errorPrepaymentInsufficient =>
      'Внесённого аванса не хватило: его уже зачли другим чеком.';

  @override
  String get errorLoyaltyCustomerUnknown =>
      'Покупатель не найден в картотеке. Выберите покупателя заново.';

  @override
  String get errorAmountExceedsReceipt =>
      'Сумма больше стоимости чека. Назовите сумму заново.';

  @override
  String get errorCardChargeUnproven =>
      'Касса не подтвердила проведение карты. Проверьте платёжный терминал.';

  @override
  String get errorPaymentTypeNotAllowed =>
      'Этот вид оплаты не разрешён на этом рабочем месте.';

  @override
  String get errorPaymentsUnavailable =>
      'Эта касса не принимает оплату по проводу. Обратитесь к администратору.';

  @override
  String get errorNoRefundService =>
      'Эта касса не проводит возврат по проводу. Обратитесь к администратору.';

  @override
  String get errorRefundAbandonIsTillSide =>
      'Черновик возврата снимает касса, а не рабочее место.';

  @override
  String get errorNoAnswer => 'Касса не ответила. Проверьте связь и повторите.';

  @override
  String paymentTypeNotAllowedHere(String type) {
    return '«$type» не разрешена этому рабочему месту. Виды оплаты меняются в настройках оборудования; касса откажет в неразрешённом виде, даже если нажать.';
  }

  @override
  String paymentTypesLimitedHere(String types) {
    return 'Рабочее место принимает: $types.';
  }

  @override
  String get paymentDebtNotSoldHere =>
      'На этой кассе в долг не торгуют: продажа в кредит выключена в настройках кассы. Касса откажет, даже если нажать.';

  @override
  String get paymentDebtNotPermitted =>
      'Продавать в долг вам не разрешено: нужно право «продажа в долг». Его выдаёт администратор в настройках прав; касса откажет любому, у кого его нет.';

  @override
  String get saleDiscountNotPermitted =>
      'Скидку назначать вам не разрешено: нужно право «продажа со скидкой». Его выдаёт администратор в настройках прав; касса откажет любому, у кого его нет.';

  @override
  String get paymentDebtPolicyUnknown =>
      'Касса пока не ответила, торгуют ли здесь в долг. Проверьте связь с кассой и попробуйте ещё раз.';

  @override
  String get paymentOffsetsTitle => 'Аванс и сертификаты';

  @override
  String get paymentPrepaymentTitle => 'Аванс покупателя';

  @override
  String get paymentPrepaymentNeedsCustomer =>
      'Чтобы зачесть аванс, найдите покупателя по номеру телефона.';

  @override
  String get paymentPrepaymentLoading =>
      'Касса ещё не ответила, сколько аванса внесено.';

  @override
  String get paymentPrepaymentNone => 'У покупателя нет внесённого аванса.';

  @override
  String get paymentPrepaymentBalance => 'Внесено вперёд:';

  @override
  String get paymentPrepaymentUse => 'Зачесть аванс';

  @override
  String paymentPrepaymentApplied(String amount) {
    return 'Будет зачтено: $amount';
  }

  @override
  String get paymentCertificateTitle => 'Подарочный сертификат';

  @override
  String get paymentCertificateNumber => 'Номер сертификата';

  @override
  String get paymentCertificatePin => 'ПИН, если есть';

  @override
  String get paymentCertificatePresent => 'Проверить';

  @override
  String paymentCertificateBalance(String amount) {
    return 'Остаток на сертификате: $amount';
  }

  @override
  String paymentCertificateApplied(String amount, String rest) {
    return 'Спишется $amount, останется $rest';
  }

  @override
  String get paymentCertificateNotNeeded =>
      'Чек уже покрыт — этот сертификат не понадобится.';

  @override
  String get unfiscalizedTitle => 'Нефискализованные чеки';

  @override
  String get unfiscalizedEmpty => 'Все чеки фискализованы';

  @override
  String get unfiscalizedEmptyHint =>
      'Здесь появятся чеки, за которые деньги взяты, а документа оператор не выдал';

  @override
  String unfiscalizedReceiptNo(int number) {
    return 'Чек №$number';
  }

  @override
  String unfiscalizedAgeHours(int hours) {
    return '$hours ч назад';
  }

  @override
  String get unfiscalizedOverdue => 'Просрочено окно 72 ч';

  @override
  String get unfiscalizedRetry => 'Повторить';

  @override
  String unfiscalizedRetryDone(String sign) {
    return 'Документ получен: $sign';
  }

  @override
  String unfiscalizedRetryFailed(String message) {
    return 'Оператор снова отказал: $message';
  }

  @override
  String get unfiscalizedNoDocument =>
      'Строка записана до того, как отказы стали нести документ: повторять нечем, её можно только списать';

  @override
  String get unfiscalizedNoOperator =>
      'Фискальный оператор не настроен: повторять некуда';

  @override
  String get unfiscalizedWriteOff => 'Списать';

  @override
  String get unfiscalizedWriteOffTitle => 'Списать нефискализованный чек';

  @override
  String unfiscalizedWriteOffBy(String name) {
    return 'Решение записывается на имя: $name';
  }

  @override
  String get unfiscalizedWriteOffReason => 'Причина списания';

  @override
  String get unfiscalizedWriteOffDone => 'Чек помечен разобранным';

  @override
  String unfiscalizedWrittenOff(String name, String reason) {
    return 'Списал $name: $reason';
  }

  @override
  String get unfiscalizedUnknownUser => 'неизвестный пользователь';

  @override
  String unfiscalizedAtShiftClose(int count, String numbers) {
    return 'Смена закрыта с нефискализованными чеками: $count. Номера: $numbers';
  }

  @override
  String documentsOnTheWayAtShiftClose(int count, String numbers) {
    return 'Документы смены ещё не у оператора: $count (чеки $numbers). Закрытие дождётся их отправки; если связь не вернётся, Z-отчёт не уйдёт — иначе отчёт оператора разойдётся с кассой.';
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
      'Касса не знает этой оплаты по QR. Обновите чек и повторите.';

  @override
  String get errorQrIntentNotPaid =>
      'Оплата по QR ещё не подтверждена банком. Дождитесь подтверждения или выберите другой способ.';

  @override
  String errorQrIntentAlreadySettled(String message) {
    return 'Эти деньги уже закрыли другой чек: $message';
  }

  @override
  String get paymentQrTitle => 'Оплата по QR';

  @override
  String get paymentQrAmount => 'Сумма по QR';

  @override
  String get paymentQrStart => 'Показать QR';

  @override
  String paymentQrWaiting(int seconds) {
    return 'Ждём оплату · осталось $seconds с';
  }

  @override
  String get paymentQrScanHint => 'Покупатель сканирует код в приложении банка';

  @override
  String get paymentQrCancel => 'Отменить ожидание';

  @override
  String get paymentQrNoLink =>
      'Нет связи с провайдером — касса повторяет запрос сама';

  @override
  String paymentQrPaid(String amount) {
    return 'Оплачено по QR: $amount';
  }

  @override
  String paymentQrPaidAfterCancel(String amount) {
    return 'Покупатель успел оплатить до отмены — $amount идёт в этот чек';
  }

  @override
  String get paymentQrCancelled =>
      'Ожидание отменено, провайдер отмену подтвердил';

  @override
  String get paymentQrPatienceSpent =>
      'Покупатель не оплатил за отведённое время — касса перестала ждать';

  @override
  String get paymentQrExpired => 'Срок QR-кода вышел у провайдера';

  @override
  String get paymentQrFailed => 'Провайдер отказал в оплате по QR';

  @override
  String get paymentQrCancelUnconfirmed =>
      'Отмена не подтверждена — деньги ещё могут прийти. Не принимайте другую оплату, пока касса не выяснит.';

  @override
  String get paymentQrRecheck => 'Проверить снова';

  @override
  String get paymentQrRestart => 'Новый код';

  @override
  String paymentQrOverReceipt(String amount) {
    return 'В чек не помещается $amount из оплаченного по QR';
  }

  @override
  String get paymentQrNothingToPay =>
      'Чек уже покрыт — показывать код не на что';

  @override
  String get errorQrNotConfigured => 'Провайдер QR не настроен на кассе';

  @override
  String get errorQrNetwork => 'Нет связи с провайдером QR';

  @override
  String get errorQrTimeout => 'Провайдер QR не ответил вовремя';

  @override
  String get errorQrProviderBusy =>
      'Провайдер QR занят — касса повторит запрос';

  @override
  String get errorQrMalformedReply =>
      'Провайдер QR ответил непонятно — обратитесь к администратору кассы';

  @override
  String get errorQrUnknownIntent => 'Провайдер QR не знает этой оплаты';

  @override
  String get errorQrRejected => 'Провайдер QR отклонил запрос';

  @override
  String get errorQrReverseUnsupported =>
      'Провайдер QR не умеет возвращать деньги';

  @override
  String get errorQrIntentLive =>
      'На этом чеке уже ждёт оплата по QR — отмените её, прежде чем показывать новый код';

  @override
  String get fiscalReasonNetwork => 'Нет связи с фискальным оператором';

  @override
  String get fiscalReasonOperatorUnavailable =>
      'Фискальный оператор недоступен';

  @override
  String get fiscalReasonTokenExpired => 'Оператор не принял авторизацию кассы';

  @override
  String get fiscalReasonRequestNotBuilt =>
      'Запрос к оператору не собран: проверьте адрес сервера в фискальных настройках';

  @override
  String get fiscalReasonTlsRejected =>
      'Защищённое соединение с оператором не установлено: проверьте адрес сервера и часы кассы';

  @override
  String get fiscalReasonClientFault => 'Сбой кассы при обмене с оператором';

  @override
  String get fiscalReasonBadCredentials =>
      'Неверный логин или пароль оператора';

  @override
  String get fiscalReasonCashboxNotFound =>
      'Касса не найдена у оператора: проверьте заводской номер';

  @override
  String get fiscalReasonCashboxBlocked => 'Касса заблокирована оператором';

  @override
  String get fiscalReasonOfflineLimitExceeded =>
      'Превышен лимит автономных документов';

  @override
  String get fiscalReasonOfflineNotSupported =>
      'Автономный режим этой кассе не разрешён';

  @override
  String get fiscalReasonDuplicate =>
      'Документ уже зарегистрирован у оператора, фискальный признак кассе не выдан — возьмите его в кабинете оператора';

  @override
  String get fiscalReasonValidation =>
      'Оператор отклонил документ: суммы или данные не сходятся';

  @override
  String get fiscalReasonNotEnoughMoney =>
      'По данным оператора в кассе недостаточно наличных';

  @override
  String get fiscalReasonShiftError => 'Ошибка смены у оператора';

  @override
  String get fiscalReasonUnsupported => 'Операция не поддерживается оператором';

  @override
  String get fiscalReasonNotConfigured => 'Фискализация не настроена';

  @override
  String get fiscalReasonUnknown => 'Оператор отказал по неизвестной причине';

  @override
  String get fiscalReasonOfflineWindowExpired =>
      'Истекло автономное окно 72 ч — документ не выдан';

  @override
  String get fiscalReasonRowUnreadable =>
      'Строка очереди повреждена: документ не читается';

  @override
  String fiscalReasonWithCode(String reason, int code) {
    return '$reason (код $code)';
  }

  @override
  String fiscalReasonLegacy(String text) {
    return 'Причина записана до перевода: $text';
  }

  @override
  String get fiscalReasonNotRecorded => 'Причина не записана';

  @override
  String get fiscalReasonPaymentTypeNotAccepted =>
      'Вид оплаты не принимается оператором: «кредит» и «тара» исключены протоколом ОФД 2.0.2';

  @override
  String get errorDeferredListUnavailable =>
      'Список отложенных чеков недоступен';

  @override
  String errorDeferredListUnavailableReason(String reason) {
    return 'Список отложенных чеков недоступен: $reason';
  }

  @override
  String get errorRefundSearchUnavailable =>
      'Поиск товара для возврата на этом терминале ещё не подключён';

  @override
  String get errorRefundNothingSelected =>
      'Черновик изменился — возвращать нечего. Проверьте выделенные строки.';

  @override
  String get errorRefundInvalidAmount =>
      'Столько вернуть нельзя: количество не может быть больше проданного по чеку или меньше нуля.';

  @override
  String get errorCertificatePinRequired =>
      'У сертификата есть ПИН. Наберите ПИН с сертификата.';

  @override
  String get qrSettingsTitle => 'Оплата по QR';

  @override
  String get qrSettingsSubtitle =>
      'Провайдер QR/СБП: адрес, код, ключ, ожидание';

  @override
  String get qrSettingsKindTitle => 'Принимать оплату по QR';

  @override
  String get qrSettingsKindSubtitle => 'Вид оплаты «QR» на экране оплаты';

  @override
  String get qrSettingsUrl => 'Адрес провайдера';

  @override
  String get qrSettingsCode => 'Код провайдера';

  @override
  String get qrSettingsKey => 'Ключ доступа';

  @override
  String get qrSettingsKeyStoredHint =>
      'Ключ сохранён. Введите новый, чтобы заменить';

  @override
  String get qrSettingsKeyEmptyHint => 'Ключ не задан';

  @override
  String get qrSettingsClearKey => 'Стереть сохранённый ключ';

  @override
  String get qrSettingsPatience => 'Ожидание оплаты, секунд';

  @override
  String get qrSettingsSave => 'Сохранить';

  @override
  String get qrSettingsSaved => 'Настройка QR сохранена';

  @override
  String get qrSettingsRemove => 'Снять настройку';

  @override
  String get qrSettingsStatusReady => 'Провайдер настроен';

  @override
  String get qrSettingsStatusNotConfigured =>
      'Провайдер не настроен — оплата по QR недоступна';

  @override
  String get qrSettingsInvalidUrl =>
      'Адрес должен начинаться с http:// или https://';

  @override
  String get qrSettingsCodeRequired => 'Укажите код провайдера';

  @override
  String qrSettingsInvalidPatience(String min, String max) {
    return 'Ожидание — от $min до $max секунд';
  }

  @override
  String get qrSettingsSaveFailed => 'Не удалось сохранить настройку QR';

  @override
  String get qrSettingsTillOnly =>
      'Настройка провайдера QR доступна только на самой кассе';

  @override
  String get installmentTermsTitle => 'Рассрочка';

  @override
  String get installmentTermsMonths => 'Срок, месяцев';

  @override
  String get installmentTermsScheme => 'Схема графика';

  @override
  String get installmentTermsContinue => 'Продолжить';

  @override
  String get customerPaymentTitle => 'Принять оплату / погасить долг';

  @override
  String customerPaymentCurrentDebt(String amount) {
    return 'Текущий долг: $amount';
  }

  @override
  String customerPaymentBalance(String amount) {
    return 'Баланс: $amount';
  }

  @override
  String get customerPaymentAmount => 'Сумма оплаты';

  @override
  String get customerPaymentAmountInvalid => 'Введите сумму больше 0';

  @override
  String get customerPaymentFailed => 'Ошибка проведения оплаты';

  @override
  String get customerPaymentSubmit => 'Принять оплату';

  @override
  String get errorPrepaymentAmountInvalid =>
      'Сумма аванса должна быть больше нуля. Наберите сумму заново.';

  @override
  String get errorPrepaymentTenderInvalid =>
      'Аванс принимается наличными, картой или по QR. Выберите другой вид оплаты.';

  @override
  String get errorPrepaymentTillAccountMissing =>
      'У кассы нет счёта для приёма этого вида оплаты. Настройте счёт приёма и повторите.';

  @override
  String get errorPrepaymentIntakeFailed =>
      'Аванс принять не удалось. Проверьте покупателя и повторите.';

  @override
  String get errorPrepaymentRefundExceedsBalance =>
      'Аванса на счёте покупателя меньше, чем вы выдаёте. Проверьте остаток и убавьте сумму.';

  @override
  String get errorPrepaymentRefundKeyMissing =>
      'В заявке на выдачу аванса нет ключа повтора — касса не отличит повтор от второй выдачи. Откройте экран заново и наберите сумму ещё раз.';

  @override
  String get errorPrepaymentRefundFailed =>
      'Аванс выдать не удалось. Проверьте покупателя и повторите.';

  @override
  String get errorPrepaymentRefundUnavailable =>
      'Эта касса не выдаёт аванс покупателя по проводу. Обратитесь к администратору.';

  @override
  String get errorPrepaymentIntakeUnavailable =>
      'Эта касса не принимает аванс покупателя по проводу. Обратитесь к администратору.';

  @override
  String get errorPrepaymentIntakeKeyMissing =>
      'В заявке на приём аванса нет ключа повтора — касса не отличит повтор от второго взноса. Откройте экран заново и наберите сумму ещё раз.';

  @override
  String get errorQrSetupUnavailable =>
      'Эта касса не хранит настройку провайдера QR. Настройте оплату по QR на самой кассе или обратитесь к администратору.';

  @override
  String get errorReceiptTemplatesUnavailable =>
      'Эта касса не хранит шаблонов чека. Настройте шаблон на самой кассе или обратитесь к администратору.';

  @override
  String get errorReceiptTemplateNameless =>
      'У шаблона чека обязано быть название. Наберите его и сохраните ещё раз.';

  @override
  String get shiftDeskTitle => 'Смена';

  @override
  String get shiftDeskOverAgeWarning =>
      'Смена открыта более 24 часов — продажа заблокирована. Закройте её и откройте новую.';

  @override
  String shiftDeskOpenedAt(String when) {
    return 'Открыта: $when';
  }

  @override
  String get shiftDeskCountedLabel => 'Пересчитано в ящике';

  @override
  String get shiftDeskCountedHint =>
      'Оставьте пустым, если не пересчитывали — касса возьмёт свой итог.';

  @override
  String get shiftDeskOpeningCashLabel => 'Деньги в ящике на начало';

  @override
  String get shiftDeskClosedNow => 'Смена закрыта.';

  @override
  String get shiftDeskOpenedNow => 'Смена открыта.';

  @override
  String get shiftDeskNoShift => 'На кассе нет открытой смены.';

  @override
  String shiftDeskUnfiscalizedCount(int count) {
    return 'Чеков без фискального документа: $count';
  }

  @override
  String shiftDeskUnfinishedCount(int count) {
    return 'Незаконченных чеков: $count — закрытие их приберёт';
  }

  @override
  String get errorShiftDeskNotOpen =>
      'На этой кассе нет открытой смены — закрывать нечего.';

  @override
  String get errorShiftDeskAlreadyOpen => 'На этой кассе уже открыта смена.';

  @override
  String get errorShiftDeskUnavailable =>
      'Эта касса не ведёт смен по проводу. Закройте смену на самой кассе или обратитесь к администратору.';

  @override
  String get errorShiftDeskActorUnknown =>
      'Смену открывает кассир, а этой заявке кассира назвать нечем. Войдите заново.';

  @override
  String get prepaymentIntakeTitle => 'Приём аванса';

  @override
  String get prepaymentIntakeFind => 'Найти покупателя';

  @override
  String get prepaymentIntakeNotFound =>
      'Покупатель с таким номером не найден.';

  @override
  String get prepaymentIntakeSubmit => 'Принять аванс';

  @override
  String prepaymentIntakeAccepted(String amount) {
    return 'Аванс принят. Внесено вперёд: $amount';
  }

  @override
  String get prepaymentIntakeFiscalFailed =>
      'Деньги приняты, но фискальный чек аванса не выписан.';

  @override
  String get emulatorSettingsTitle => 'Встроенные эмуляторы';

  @override
  String get emulatorSettingsHint =>
      'Проверить печать и диагностику, не подключая приборов';

  @override
  String get emulatorReceiptPrinter => 'Чековый принтер и денежный ящик';

  @override
  String get emulatorEnabledNote =>
      'Сокет поднят. Касса попадёт на него только по адресу из привязки';

  @override
  String get emulatorDisabledNote => 'Выключен: сокет не открыт';

  @override
  String get emulatorAddress => 'Адрес эмулятора';

  @override
  String get emulatorAddressHint =>
      'Впишите этот IP и порт в настройках принтера';

  @override
  String get emulatorBindAction => 'Вписать в привязку принтера';

  @override
  String get emulatorBindDone => 'Привязка принтера теперь смотрит на эмулятор';

  @override
  String get emulatorBindingStale =>
      'Привязка принтера смотрит на выключенный эмулятор — печать откажет';

  @override
  String get emulatorStartFailed => 'Не удалось поднять эмулятор';

  @override
  String get emulatorFiscalOperator => 'Фискальный оператор (ОФД)';

  @override
  String get emulatorFiscalAddressHint =>
      'Впишите этот адрес в поле «Адрес сервера» фискальных настроек';

  @override
  String get emulatorFiscalBindAction => 'Вписать в фискальные настройки';

  @override
  String get emulatorFiscalBindNote =>
      'Впишет адрес, логин, пароль, ключ и заводской номер эмулятора и объявит кассу испытательной. Регистрационный номер не трогается';

  @override
  String get emulatorFiscalBindDone =>
      'Фискальные настройки теперь смотрят на эмулятор';

  @override
  String get emulatorFiscalBindingStale =>
      'Фискальные настройки смотрят на выключенный эмулятор — фискализация откажет';

  @override
  String get emulatorFiscalLocalModuleWarning =>
      'Заполнено поле «Локальный модуль» — оно перебивает адрес сервера, и касса пойдёт не на эмулятор';

  @override
  String get emulatorFiscalBlockedLive =>
      'Касса боевая: вписаны реквизиты оператора. Эмулятор ОФД здесь запрещён — чек, ушедший в подделку, выглядит настоящим, а документа покупателю не даёт';

  @override
  String get emulatorFiscalBlockedUnknown =>
      'Фискальные настройки не прочитались — включить эмулятор ОФД нельзя';

  @override
  String get diagnosticsFiscalEmulatorBanner =>
      'Адрес оператора ведёт на этот же компьютер — документы уходят в эмулятор и фискальными не являются';

  @override
  String get diagnosticsTitle => 'Диагностика оборудования';

  @override
  String get diagnosticsSubtitle =>
      'Что касса на самом деле отправила приборам';

  @override
  String get diagnosticsTabPrinter => 'Принтер';

  @override
  String get diagnosticsTabFiscal => 'Фискализация';

  @override
  String get errorDiagnosticsUnavailable =>
      'Диагностику на этой кассе спросить не у кого';

  @override
  String get diagnosticsPrinterQueueMissing =>
      'Очередь печати на этом рабочем месте не настроена';

  @override
  String get diagnosticsPrinterNothingSent =>
      'Касса пока ничего не отправляла в принтер';

  @override
  String diagnosticsAskFailed(String reason) {
    return 'Касса не ответила на этот вопрос: $reason';
  }

  @override
  String diagnosticsAttempts(int count) {
    return 'попыток $count';
  }

  @override
  String get diagnosticsJobQueued => 'ждёт очереди';

  @override
  String get diagnosticsJobPrinting => 'печатается';

  @override
  String get diagnosticsJobPrinted => 'напечатано';

  @override
  String get diagnosticsJobFailed => 'не напечатано';

  @override
  String get diagnosticsJobExpired => 'просрочено';

  @override
  String get diagnosticsJobCancelled => 'отменено';

  @override
  String get diagnosticsFiscalNotConfigured =>
      'Фискальный оператор на этой кассе не настроен';

  @override
  String get diagnosticsFiscalAccepted => 'Принято оператором';

  @override
  String get diagnosticsFiscalAcceptedEmpty =>
      'Оператор пока не принял ни одного документа';

  @override
  String get diagnosticsFiscalQueued => 'В очереди';

  @override
  String get diagnosticsFiscalQueuedEmpty =>
      'Очередь пуста — всё, что отправляли, оператор принял';

  @override
  String diagnosticsFiscalSign(String value) {
    return 'Фискальный признак $value';
  }

  @override
  String diagnosticsFiscalOperatorDoc(String value) {
    return 'документ оператора $value';
  }

  @override
  String diagnosticsFiscalReceiptNo(String value) {
    return 'чек $value';
  }

  @override
  String get diagnosticsFiscalOffline => 'выдан автономно';

  @override
  String get diagnosticsEmulatorBanner =>
      'Привязка принтера смотрит на этот же компьютер — за портом эмулятор, а не бумага';

  @override
  String get diagnosticsTabDrawer => 'Ящик';

  @override
  String get drawerDiagnosticsEmpty =>
      'С запуска кассы ящик не открывали ни разу';

  @override
  String get drawerDiagnosticsUnavailable =>
      'Памяти об импульсах ящика на этой кассе нет — спросить нечем. Это не значит, что ящик не открывали.';

  @override
  String get drawerDiagnosticsCaveat =>
      'Касса знает только, приняли ли команду. Открылся ли ящик на самом деле, обратной связи нет ни на одном пути.';

  @override
  String get drawerDiagnosticsAccepted => 'Команда принята';

  @override
  String get drawerDiagnosticsRefused => 'Команда отклонена';

  @override
  String get drawerDiagnosticsViaSerial => 'последовательный порт';

  @override
  String get drawerDiagnosticsViaPrinter => 'через принтер (ESC p)';

  @override
  String get diagnosticsTabScales => 'Весы';

  @override
  String get diagnosticsTabDisplay => 'Дисплей';

  @override
  String get scalesDiagnosticsUnbound =>
      'Весы не привязаны к этой кассе.\nПривяжите их в настройках оборудования — тогда здесь появится показание.';

  @override
  String get scalesDiagnosticsWeight => 'Показание весов';

  @override
  String get scalesDiagnosticsSilent => 'Весы ещё ничего не прислали';

  @override
  String get scalesDiagnosticsStable => 'Вес устоялся';

  @override
  String get scalesDiagnosticsSettling => 'Вес меняется';

  @override
  String get scalesDiagnosticsOverload => 'Перегрузка';

  @override
  String get scalesDiagnosticsPort => 'Порт весов';

  @override
  String get scalesDiagnosticsBaudSuffix => 'бод';

  @override
  String get scalesDiagnosticsConnected => 'Порт открыт';

  @override
  String get scalesDiagnosticsDisconnected => 'Порт закрыт';

  @override
  String get scalesDiagnosticsCaveat =>
      'Это то, что прислал прибор. Верность показаний касса не проверяет — за неё отвечает поверка.';

  @override
  String get displayDiagnosticsEmpty =>
      'С запуска кассы на дисплей ничего не отправляли';

  @override
  String get displayDiagnosticsUnavailable =>
      'Памяти о строках дисплея на этой кассе нет — спросить нечем. Это не значит, что на дисплей ничего не отправляли.';

  @override
  String get displayDiagnosticsCurrent => 'Сейчас на дисплее';

  @override
  String get displayDiagnosticsCaveat =>
      'Касса знает только, что строка ушла в порт. Погасший или отключённый дисплей отсюда неотличим от исправного.';

  @override
  String get displayDiagnosticsCallPrice => 'цена';

  @override
  String get displayDiagnosticsCallTotal => 'итог';

  @override
  String get displayDiagnosticsCallChange => 'сдача';

  @override
  String get displayDiagnosticsCallText => 'текст';

  @override
  String get displayDiagnosticsCallWelcome => 'приветствие';

  @override
  String get displayDiagnosticsCallClear => 'очистка';

  @override
  String get emulatorScaleWeight => 'Вес на чаше';

  @override
  String get emulatorScaleWeightHint =>
      'Пульт эмулятора: это число весы и пришлют кассе';

  @override
  String get emulatorQrProvider => 'Провайдер оплаты по QR';

  @override
  String get emulatorQrAddressHint =>
      'Впишите этот адрес в настройке провайдера QR';

  @override
  String get emulatorQrBindAction => 'Вписать в настройку QR';

  @override
  String get emulatorQrBindDone => 'Настройка QR теперь смотрит на эмулятор';

  @override
  String get emulatorQrBindingStale =>
      'Настройка QR смотрит на выключенный эмулятор — оплата по коду откажет';

  @override
  String get diagnosticsTabPayment => 'Оплата';

  @override
  String get diagnosticsPaymentEmulatorBanner =>
      'Провайдер QR — на этом же компьютере: за адресом эмулятор, а не банк';

  @override
  String get paymentDiagnosticsUnavailable =>
      'Данных об оплате на этом рабочем месте нет';

  @override
  String get paymentDiagnosticsQrSection => 'Оплата по QR';

  @override
  String get paymentDiagnosticsQrEmpty =>
      'Касса пока не заводила ни одного кода оплаты';

  @override
  String get paymentDiagnosticsQrNotConfigured =>
      'Провайдер QR на этой кассе не настроен';

  @override
  String paymentDiagnosticsQrAddress(String address) {
    return 'Провайдер: $address';
  }

  @override
  String get paymentDiagnosticsQrUnknown =>
      'Тела запросов к провайдеру касса не хранит. Видно то, что осело в намерении: сумма, состояние, ид на той стороне и причина отказа.';

  @override
  String get paymentDiagnosticsTerminalSection => 'Терминал оплаты';

  @override
  String get paymentDiagnosticsTerminalEmpty =>
      'С запуска кассы в терминал оплаты не уходило ни одного кадра';

  @override
  String get paymentDiagnosticsTerminalUnknown =>
      'Журнал терминала живёт в памяти: обмены до перезапуска кассы не сохраняются, а операции, проведённые с самого терминала, касса не видит вовсе.';

  @override
  String get paymentDiagnosticsRequest => 'Запрос';

  @override
  String get paymentDiagnosticsReply => 'Ответ';

  @override
  String get paymentDiagnosticsNoReply => 'Ответа не было';

  @override
  String paymentDiagnosticsApproval(String value) {
    return 'Код одобрения $value';
  }

  @override
  String paymentDiagnosticsTransaction(String value) {
    return 'транзакция $value';
  }

  @override
  String paymentDiagnosticsRefusal(String value) {
    return 'Отказ: $value';
  }

  @override
  String paymentDiagnosticsConfirmations(int count) {
    return 'подтверждений $count';
  }

  @override
  String get paymentDiagnosticsOrphanMoney => 'деньги без чека';

  @override
  String get paymentDiagnosticsAfterGiveUp =>
      'подтверждено после того, как касса перестала ждать';

  @override
  String get paymentDiagnosticsApproved => 'Одобрено';

  @override
  String get paymentDiagnosticsDeclined => 'Отказано';

  @override
  String get paymentDiagnosticsOpPurchase => 'покупка';

  @override
  String get paymentDiagnosticsOpReversal => 'сторно';

  @override
  String get paymentDiagnosticsOpRefund => 'возврат';

  @override
  String get paymentDiagnosticsOpUnknown => 'кадр неизвестного вида';

  @override
  String get certificateIssueTitle => 'Выпуск подарочного сертификата';

  @override
  String get certificateIssueHint =>
      'Деньги за бумажку принимает чек продажи. Здесь бумажке заводится остаток, а касса берёт на себя обязательство.';

  @override
  String get certificateIssueNumber => 'Номер бумажки';

  @override
  String get certificateIssueNominal => 'Номинал';

  @override
  String get certificateIssuePin => 'ПИН (необязательно)';

  @override
  String get certificateIssueExpiresDays =>
      'Срок годности в днях (необязательно)';

  @override
  String get certificateIssueReceipt => 'Номер чека продажи (необязательно)';

  @override
  String get certificateIssueSubmit => 'Выпустить сертификат';

  @override
  String certificateIssueDone(String number, String amount) {
    return 'Сертификат $number выпущен на $amount';
  }

  @override
  String get certificateIssueFailed => 'Сертификат не выпущен';

  @override
  String get certificateIssueNumberRequired => 'Впишите номер бумажки';

  @override
  String get certificateIssueNominalInvalid =>
      'Номинал должен быть больше нуля';

  @override
  String get certificateIssueNotPermitted =>
      'Выпуск сертификатов этому кассиру не разрешён';

  @override
  String get certificateSlipTitle => 'Напечатать слип заново';

  @override
  String get certificateSlipHint =>
      'Слип не напечатался при выпуске — бумажку можно выдать по повторному.';

  @override
  String get certificateSlipNumber => 'Номер сертификата';

  @override
  String get certificateSlipPin => 'ПИН, если он есть';

  @override
  String get certificateSlipSubmit => 'Напечатать слип';

  @override
  String certificateSlipDone(String number) {
    return 'Слип сертификата $number отправлен в печать';
  }

  @override
  String get certificateSlipFailed => 'Слип в печать не отправлен';

  @override
  String get certificateSlipUnavailable => 'На этой кассе слип печатать нечем';

  @override
  String get prepaymentRefundTitle => 'Выдача аванса';

  @override
  String get prepaymentRefundHint =>
      'Возвращаются деньги, внесённые покупателем вперёд. Долг этим не гасится, бонусы не трогаются.';

  @override
  String prepaymentRefundBalance(String amount) {
    return 'Внесено вперёд: $amount';
  }

  @override
  String get prepaymentRefundNothing =>
      'Аванса на счёте покупателя нет — выдавать нечего';

  @override
  String get prepaymentRefundAmount => 'Сумма к выдаче';

  @override
  String get prepaymentRefundTender => 'Чем выдать';

  @override
  String get prepaymentRefundIntake => 'Номер проводки приёма (необязательно)';

  @override
  String get prepaymentRefundSubmit => 'Выдать аванс';

  @override
  String prepaymentRefundDone(String amount) {
    return 'Аванс выдан. Осталось на счёте: $amount';
  }

  @override
  String get prepaymentRefundFailed => 'Аванс не выдан';

  @override
  String get prepaymentRefundAmountInvalid => 'Сумма должна быть больше нуля';

  @override
  String get prepaymentRefundNotPermitted =>
      'Выдача аванса этому кассиру не разрешена';

  @override
  String get prepaymentRefundFiscalFailed =>
      'Деньги выданы, но фискальный чек возврата аванса не выписан.';

  @override
  String get agentRefundPrepayment => 'Выдать аванс';
}
